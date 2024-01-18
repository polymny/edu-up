//! This crate is the library for polymny.

#![warn(missing_docs)]

#[macro_use]
extern crate rocket;

pub mod command;
pub mod config;
pub mod db;
pub mod log_fairing;
pub mod mailer;
pub mod openid;
pub mod routes;
pub mod s3;
pub mod storage;
pub mod tasks;
pub mod templates;
pub mod websockets;

use std::env;
use std::error::Error as StdError;
use std::fmt;
use std::fs::OpenOptions;
use std::ops::Deref;
use std::path::Path;
use std::result::Result as StdResult;
use std::sync::Arc;

use lazy_static::lazy_static;

use serde::de;
use serde::{Deserialize, Deserializer, Serialize, Serializer};

use tokio::fs::remove_dir_all;
use tokio::sync::Semaphore;

use lapin::options::{BasicQosOptions, ExchangeDeclareOptions, QueueDeclareOptions};
use lapin::types::FieldTable;
use lapin::{Connection, ConnectionProperties, ExchangeKind};

use ergol::deadpool::managed::Object;
use ergol::tokio_postgres::Error as TpError;
use ergol::{tokio, Pool};

use rocket::fairing::AdHoc;
use rocket::http::Status;
use rocket::request::{FromParam, FromRequest, Outcome, Request};
use rocket::response::{self, Responder};
use rocket::shield::{NoSniff, Permission, Shield};
use rocket::{Ignite, Rocket, State};

use crate::command::{get_size, run_command};
use crate::config::Config;
use crate::db::group::populate_db;
use crate::s3::S3;
use crate::storage::Storage;
use crate::tasks::TaskRunner;
use crate::websockets::{notifier, Notifier, WebSockets};

lazy_static! {
    /// The harsh encoder and decoder for capsule ids.
    pub static ref HARSH: Harsh = {
        let config = Config::from_figment(&rocket::Config::figment());
        let harsh = Harsh(
            harsh::Harsh::builder()
                .salt(config.harsh_secret)
                .length(config.harsh_length)
                .build()
                .unwrap(),
        );
        harsh
    };
}

/// The error type of this library.
#[derive(Debug)]
pub struct Error(pub Status);

/// The result type of this library
pub type Result<T> = StdResult<T, Error>;

impl<'r, 's: 'r> Responder<'r, 's> for Error {
    fn respond_to(self, request: &'r Request) -> response::Result<'s> {
        self.0.respond_to(request)
    }
}

impl fmt::Display for Error {
    fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
        write!(fmt, "errored with status {}", self.0)
    }
}

impl StdError for Error {}

macro_rules! impl_from_error {
    ( $from: ty) => {
        impl From<$from> for Error {
            fn from(_: $from) -> Error {
                Error(Status::InternalServerError)
            }
        }
    };
}

impl_from_error!(std::io::Error);
impl_from_error!(TpError);
impl_from_error!(bcrypt::BcryptError);
impl_from_error!(std::str::Utf8Error);
impl_from_error!(std::num::ParseIntError);

/// A wrapper for a database connection extrated from a pool.
pub struct Db(Object<ergol::pool::Manager>);

impl Db {
    /// Extracts a database from a pool.
    pub async fn from_pool(pool: Pool) -> Result<Db> {
        Ok(Db(pool
            .get()
            .await
            .map_err(|_| Error(Status::InternalServerError))?))
    }
}

impl std::ops::Deref for Db {
    type Target = Object<ergol::pool::Manager>;
    fn deref(&self) -> &Self::Target {
        &*&self.0
    }
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for Db {
    type Error = Error;

    async fn from_request(request: &'r Request<'_>) -> Outcome<Self, Self::Error> {
        let pool = match request.guard::<&State<Pool>>().await {
            Outcome::Success(pool) => pool,
            Outcome::Error(_) => {
                return Outcome::Error((
                    Status::InternalServerError,
                    Error(Status::InternalServerError),
                ))
            }
            Outcome::Forward(s) => return Outcome::Forward(s),
        };

        let db = match pool.get().await {
            Ok(db) => db,
            Err(_) => {
                return Outcome::Error((
                    Status::InternalServerError,
                    Error(Status::InternalServerError),
                ))
            }
        };

        Outcome::Success(Db(db))
    }
}

/// Helper type to retrieve the accepted language from a request.
#[derive(Serialize, Deserialize)]
pub struct Lang(pub String);

#[rocket::async_trait]
impl<'r> FromRequest<'r> for Lang {
    type Error = Error;

    async fn from_request(request: &'r Request<'_>) -> Outcome<Self, Self::Error> {
        Outcome::Success(Lang(
            request
                .headers()
                .get("accept-language")
                .nth(0)
                .and_then(|x| x.split(",").nth(0))
                .and_then(|x| x.split(";").nth(0))
                .map(String::from)
                .unwrap_or_else(|| String::from("en-US")),
        ))
    }
}

/// Helper type for harsh.
pub struct Harsh(harsh::Harsh);

impl Harsh {
    /// Decodes a harsh id easily.
    pub fn decode<T: Into<String>>(&self, id: T) -> Result<i32> {
        Ok(*self
            .0
            .decode(id.into())
            .map_err(|_| Error(Status::NotFound))?
            .get(0)
            .ok_or(Error(Status::NotFound))? as i32)
    }

    /// Encodes an id.
    pub fn encode(&self, input: i32) -> String {
        self.0.encode(&[input as u64])
    }
}

/// A hash id that can be used in routes.
#[derive(Copy, Clone)]
pub struct HashId(pub i32);

impl HashId {
    /// Returns the hash id.
    pub fn hash(self) -> String {
        HARSH.encode(self.0)
    }

    /// Returns the hash id with a specific harsh code.
    ///
    /// This function is usefull when using polymny as a library, and running binaries outside from
    /// where the Rocket.toml is right.
    pub fn hash_with_secret(self, secret: &str, length: usize) -> Result<String> {
        let harsh = harsh::Harsh::builder()
            .salt(secret)
            .length(length)
            .build()
            .map_err(|_| Error(Status::InternalServerError))?;
        Ok(harsh.encode(&[self.0 as u64]))
    }
}

impl Serialize for HashId {
    fn serialize<S>(&self, serializer: S) -> StdResult<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&HARSH.encode(self.0))
    }
}

impl<'de> Deserialize<'de> for HashId {
    fn deserialize<D>(deserializer: D) -> StdResult<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let s = String::deserialize(deserializer)?;
        Ok(HashId(HARSH.decode(s).map_err(|_| {
            de::Error::custom("failed to decode hashid")
        })?))
    }
}

impl Deref for HashId {
    type Target = i32;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl<'a> FromParam<'a> for HashId {
    type Error = Error;
    fn from_param(param: &'a str) -> Result<Self> {
        Ok(HashId(HARSH.decode(param)?))
    }
}

/// Resets the database.
pub async fn reset_db() {
    color_backtrace::install();

    let config = Config::from_figment(&rocket::Config::figment());
    let pool = ergol::pool(&config.databases.database.url, 32).unwrap();
    let db = Db::from_pool(pool).await.unwrap();

    remove_dir_all(&config.data_path).await.ok();

    ergol_cli::reset(".").await.unwrap();

    use crate::db::user::{Plan, User};

    // Add user only if we're not using openid.
    if config.openid.is_none() {
        let mut user = User::new(
            env::var("POLYMNY_USER").unwrap_or(String::from("polymny")),
            env::var("POLYMNY_EMAIL").unwrap_or(String::from("polymny@example.com")),
            Some(env::var("POLYMNY_PASS").unwrap_or(String::from("hashed"))),
            true,
            &None,
            &db,
            &config,
        )
        .await
        .unwrap();

        user.plan = Plan::Admin;
        user.save(&db).await.unwrap();
    }

    populate_db(&db, &config).await.unwrap();
}

/// Calculate disk usage for each user.
pub async fn user_disk_usage() {
    color_backtrace::install();

    let config = Config::from_figment(&rocket::Config::figment());
    let pool = ergol::pool(&config.databases.database.url, 32).unwrap();
    let db = Db::from_pool(pool).await.unwrap();

    let s3 = config.s3.map(S3::new);

    use crate::db::capsule::Capsule;
    use crate::db::user::Plan;
    use ergol::prelude::*;

    let mut total_used = 0;
    let mut total_freed = 0;

    for mut capsule in Capsule::select().execute(&db).await.unwrap() {
        let owner = capsule.owner(&db).await.unwrap();

        // Skip capsule if it is stored on the other host.
        if config.other_host.is_some() && (owner.plan >= Plan::PremiumLvl1) != config.premium_only {
            continue;
        }

        let old_disk_usage = capsule.disk_usage;

        let new_size = match s3.as_ref() {
            Some(s3) => {
                capsule.garbage_collect_s3(s3).await.unwrap();
                let dir = s3.read_dir(&format!("{}/", capsule.id)).await.unwrap();
                let mut total_size = 0;
                for object in dir.contents().unwrap() {
                    total_size += object.size();
                }
                total_size as i32
            }

            _ => {
                capsule.garbage_collect(&config.data_path).await.unwrap();
                let path = &config.data_path.join(format!("{}", capsule.id));
                let size = get_size(path).unwrap();
                size as i32
            }
        };

        let du = new_size / 1e6 as i32;
        if du != capsule.disk_usage {
            capsule.disk_usage = du;
            capsule.save(&db).await.unwrap();
        }

        let diff = capsule.disk_usage - old_disk_usage;

        total_used += capsule.disk_usage;
        total_freed += diff;

        eprintln!(
            "Cleaned \"{} / {}\" from user \"{}\", current disk usage: {}MB, freed: {}MB",
            capsule.project, capsule.name, owner.username, capsule.disk_usage, diff,
        );
    }

    eprintln!(
        "All cleaned, total disk usage: {}MB, total freed: {}MB",
        total_used, total_freed
    );
}

/// update duration of all capsules
pub async fn update_video_duration() {
    color_backtrace::install();

    let config = Config::from_figment(&rocket::Config::figment());
    let pool = ergol::pool(&config.databases.database.url, 32).unwrap();
    let db = Db::from_pool(pool).await.unwrap();

    use crate::db::capsule::Capsule;
    use ergol::prelude::*;

    let capsules = Capsule::select().execute(&db).await.unwrap();
    for mut capsule in capsules {
        let path = &config
            .data_path
            .join(format!("{}", capsule.id))
            .join("produced")
            .join("capsule.mp4");
        if Path::new(path).exists() {
            let output = run_command(&vec![
                "../scripts/popy.py",
                "duration",
                "-f",
                path.to_str().unwrap(),
            ]);

            match &output {
                Ok(o) => {
                    let line = ((std::str::from_utf8(&o.stdout)
                        .map_err(|_| Error(Status::InternalServerError))
                        .unwrap()
                        .trim()
                        .parse::<f32>()
                        .unwrap())
                        * 1000.) as i32;

                    capsule.duration_ms = line;
                    capsule.save(&db).await.ok();

                    println!(
                        " capsule {:4} {:9.1} s",
                        capsule.id,
                        capsule.duration_ms as f32 / 1000.0
                    );
                }
                Err(_) => error!("Impossible to get duration"),
            };
        }
    }
}

/// Starts the rocket server.
pub async fn rocket() -> StdResult<Rocket<Ignite>, rocket::Error> {
    color_backtrace::install();

    let figment = rocket::Config::figment();
    let config = Config::from_figment(&figment);

    // Logging system
    let rocket = if figment.profile() == "release" {
        use simplelog::*;

        let mut log_config = ConfigBuilder::new();
        log_config.set_max_level(LevelFilter::Off);
        log_config.set_time_level(LevelFilter::Off);
        let log_config = log_config.build();

        let file = OpenOptions::new()
            .append(true)
            .create(true)
            .open(&config.log_path)
            .unwrap();

        let module = vec![String::from(module_path!())];

        WriteLogger::init(LevelFilter::Info, log_config, file, module).unwrap();

        rocket::build().attach(log_fairing::Log::fairing())
    } else {
        rocket::build()
    };

    // Some variables required for app preparation
    let socks = WebSockets::new();
    let socks_task_runner = socks.clone();
    let socks_notifier = socks.clone();
    let socks_rabbitmq = socks.clone();

    let use_s3 = config.s3.is_some();
    let data_path = config.data_path.clone();
    let rabbitmq_url = config.rabbitmq.as_ref().map(|x| x.url.clone());

    // Storage system (whether data is stored on the local disk or on S3)
    let rocket = if let Some(s3) = config.s3 {
        rocket.attach(AdHoc::on_ignite("Storage", |rocket| async move {
            let s3 = S3::new(s3);
            rocket.manage(Storage::S3(s3))
        }))
    } else {
        rocket.attach(AdHoc::on_ignite("Storage", |rocket| async move {
            rocket.manage(Storage::Disk(data_path))
        }))
    };

    let shield = Shield::new()
        .enable(NoSniff::default())
        .enable(Permission::default());

    // Mounting the other attributes and routes
    let rocket = rocket
        .attach(shield)
        .attach(AdHoc::on_ignite("Config", |rocket| async move {
            let config = Config::from_rocket(&rocket);
            rocket.manage(config)
        }))
        .attach(AdHoc::on_ignite("Database", |rocket| async move {
            let config = Config::from_rocket(&rocket);
            let pool = ergol::pool(&config.databases.database.url, 32).unwrap();
            rocket.manage(pool)
        }))
        .attach(AdHoc::on_ignite("Semaphore", |rocket| async move {
            let config = config::Config::from_rocket(&rocket);
            rocket.manage(Arc::new(Semaphore::new(config.concurrent_tasks)))
        }))
        .attach(AdHoc::on_ignite("WebSockets", |rocket| async move {
            rocket.manage(socks)
        }));

    // Task runner and notifier
    // If rabbitmq is enabled, the tasks and the notifications must go through rabbitmq, otherwise
    // they just stay on the local machine
    let rocket = if let Some(rabbitmq) = config.rabbitmq.as_ref() {
        let url = rabbitmq.url.clone();
        let url2 = rabbitmq.url.clone();

        rocket
            .attach(AdHoc::on_ignite("TaskRunner", |rocket| async move {
                let options = ConnectionProperties::default()
                    .with_executor(tokio_executor_trait::Tokio::current())
                    .with_reactor(tokio_reactor_trait::Tokio);

                let connection = Connection::connect(&url, options).await.unwrap();
                let channel = connection.create_channel().await.unwrap();

                channel
                    .basic_qos(1, BasicQosOptions { global: false })
                    .await
                    .unwrap();

                // Declare rabbitmq queue for tasks
                channel
                    .queue_declare(
                        "tasks",
                        QueueDeclareOptions::default(),
                        FieldTable::default(),
                    )
                    .await
                    .unwrap();

                // Declare rabbitmq queue for websockets messages
                channel
                    .exchange_declare(
                        "websockets",
                        ExchangeKind::Fanout,
                        ExchangeDeclareOptions::default(),
                        FieldTable::default(),
                    )
                    .await
                    .unwrap();

                rocket.manage(TaskRunner::from_rabbitmq_channel(channel))
            }))
            .attach(AdHoc::on_ignite("Notifier", |rocket| async move {
                let options = ConnectionProperties::default()
                    .with_executor(tokio_executor_trait::Tokio::current())
                    .with_reactor(tokio_reactor_trait::Tokio);

                let connection = Connection::connect(&url2, options).await.unwrap();
                let channel = connection.create_channel().await.unwrap();
                rocket.manage(Notifier::from_rabbitmq_channel(channel))
            }))
    } else {
        rocket
            .attach(AdHoc::on_ignite("TaskRunner", |rocket| async move {
                let pool = rocket.state::<Pool>().unwrap().clone();
                let config = Config::from_rocket(&rocket);
                rocket.manage(TaskRunner::local(pool, config, socks_task_runner))
            }))
            .attach(AdHoc::on_ignite("Notifier", |rocket| async move {
                rocket.manage(Notifier::from_websockets(socks_notifier))
            }))
    };

    let rocket = rocket.mount(
        "/",
        if config.openid.as_ref().map(|x| x.only) == Some(true) {
            routes![routes::user::openid]
        } else {
            routes![
                routes::user::login_external_cors,
                routes::user::login_external,
            ]
        },
    );

    let rocket = rocket.mount(
        "/",
        routes![
            routes::index_cors,
            routes::index,
            routes::preparation,
            routes::acquisition,
            routes::production,
            routes::publication,
            routes::options,
            routes::profile,
            routes::courses,
            routes::courses_with_group_id,
            routes::admin_dashboard,
            routes::admin_user,
            routes::admin_users,
            routes::admin_capsules,
            routes::capsule_settings,
            routes::capsule_collaborators,
            routes::user::activate,
            routes::user::unsubscribe,
            routes::user::reset_password,
            routes::user::validate_email,
            routes::user::validate_invitation,
            routes::watch::watch,
            routes::watch::watch_asset,
            routes::watch::polymny_video,
            websockets::websocket,
        ],
    );

    // Dynamic routes for S3 published videos
    let rocket = if use_s3 {
        rocket.mount(
            "/",
            routes![routes::watch::manifest, routes::watch::resolution_manifest,],
        )
    } else {
        rocket
    };

    // Api routes
    let rocket = rocket
        .mount("/dist", routes![routes::dist])
        .mount("/data", routes![routes::assets, routes::produced]);

    let rocket = rocket.mount(
        "/api",
        match (
            config.registration_disabled,
            config.openid.as_ref().map(|x| x.only),
        ) {
            // OpenID only : no user creation, no login route, no change email or password
            (_, Some(true)) => routes![],

            // OpenID disabled, registration disabled, only login, forget password, change
            // password, change email routes
            (true, _) => routes![
                routes::user::login,
                routes::user::request_new_password,
                routes::user::request_new_password_cors,
                routes::user::change_password,
                routes::user::request_change_email,
            ],

            // OpenID disabled, registration enabled, all routes
            _ => routes![
                routes::user::new_user_cors,
                routes::user::new_user,
                routes::user::login,
                routes::user::request_new_password,
                routes::user::request_new_password_cors,
                routes::user::change_password,
                routes::user::request_change_email,
            ],
        },
    );

    let rocket = rocket
        .mount(
            "/api",
            routes![
                routes::user::logout,
                routes::user::delete,
                routes::user::request_invitation,
                routes::capsule::get_capsule,
                routes::capsule::empty_capsule,
                routes::capsule::new_capsule,
                routes::capsule::edit_capsule,
                routes::capsule::delete_capsule,
                routes::capsule::delete_project,
                routes::capsule::upload_record,
                routes::capsule::delete_record,
                routes::capsule::upload_pointer,
                routes::capsule::replace_slide,
                routes::capsule::add_slide,
                routes::capsule::add_gos,
                routes::capsule::produce,
                routes::capsule::produce_gos,
                routes::capsule::cancel_production,
                routes::capsule::publish,
                routes::capsule::cancel_publication,
                routes::capsule::unpublish,
                routes::capsule::cancel_video_upload,
                routes::capsule::duplicate,
                routes::capsule::invite,
                routes::capsule::deinvite,
                routes::capsule::change_role,
                routes::capsule::leave,
                routes::capsule::sound_track,
                routes::notification::mark_as_read,
                routes::notification::delete,
                routes::group::new_group,
                routes::group::delete_group,
                routes::group::add_participant,
                routes::group::remove_participant,
                routes::group::new_assignment,
                routes::group::delete_assignment,
                routes::group::validate_assignment,
                routes::group::validate_answer,
                routes::admin::get_dashboard,
                routes::admin::get_users,
                routes::admin::get_search_users,
                routes::admin::get_user,
                routes::admin::get_capsules,
                routes::admin::get_search_capsules,
                routes::admin::request_invite_user,
                routes::admin::delete_user,
            ],
        )
        .register("/", catchers![routes::not_found])
        .ignite()
        .await?;

    // let pool = rocket.state::<Pool>().unwrap();

    // Starts the websocket server
    // tokio::spawn(websocket(socks.clone(), pool.clone()));

    // Monitors rabbitmq exchange to forward notifications from other instances
    if let Some(url) = rabbitmq_url {
        tokio::spawn(notifier(url, socks_rabbitmq));
    }

    rocket.launch().await
}
