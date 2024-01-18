//! This module contains the user struct and how it interacts with the database.

use futures::future::try_join_all;

use chrono::{NaiveDateTime, Utc};

use serde::{Deserialize, Serialize};

use ergol::prelude::*;

use rand::distributions::Alphanumeric;
use rand::rngs::OsRng;
use rand::Rng;

use rocket::http::Status;
use rocket::request::{FromRequest, Outcome, Request};
use rocket::serde::json::{json, Value};

use crate::config::Config;
use crate::db::capsule::{capsule, Capsule, Role};
use crate::db::notification::Notification;
use crate::db::session::Session;
use crate::mailer::Mailer;
use crate::s3::S3;
use crate::templates::{
    reset_password_email_html, reset_password_email_plain_text, validation_email_html,
    validation_email_plain_text, validation_invitation_html, validation_invitation_plain_text,
    validation_new_email_html, validation_new_email_plain_text,
};
use crate::websockets::Notifier;
use crate::{Db, Error, Result};

const PAGE_SIZE: usize = 50;

/// The different levels of authorization a user can have.
#[derive(Debug, Copy, Clone, PgEnum, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "snake_case")]
pub enum Plan {
    /// The user just has a free account.
    Free,

    /// The user have a level 1 commercial account
    PremiumLvl1,

    /// The user is an administrator of polymny.
    Admin,
}

/// A user of polymny.
#[ergol]
#[derive(Serialize)]
pub struct User {
    /// The id of the user.
    #[id]
    pub id: i32,

    /// The username through which they will be identified.
    #[unique]
    pub username: String,

    /// The email to contact the user.
    #[unique]
    pub email: String,

    /// The field to use when a user wants to change their email.
    pub secondary_email: Option<String>,

    /// The hash of the user's password.
    ///
    /// If the password is none, it means that the user is not allowed to log in by typing a
    /// password.
    pub hashed_password: Option<String>,

    /// Whether the user is activated or not.
    pub activated: bool,

    /// The activation key of the user.
    #[unique]
    pub activation_key: Option<String>,

    /// The confirm secondary email key of the user.
    #[unique]
    pub secondary_email_key: Option<String>,

    /// The reset password key of the user.
    #[unique]
    pub reset_password_key: Option<String>,

    /// The key to unsubscribe to the newsletter. If none, it means you're not subscribed.
    #[unique]
    pub unsubscribe_key: Option<String>,

    /// The plan of the user.
    pub plan: Plan,

    /// The disk quota of user
    pub disk_quota: i32,

    /// Date where the user has registered for the first time.
    pub member_since: Option<NaiveDateTime>,

    /// Date where the user has last visited.
    pub last_visited: Option<NaiveDateTime>,
}

impl User {
    /// Creates a new user.
    pub async fn new<P: Into<String>, Q: Into<String>, R: Into<String>>(
        username: P,
        email: Q,
        password: Option<R>,
        subscribed: bool,
        mailer: &Option<Mailer>,
        db: &Db,
        config: &Config,
    ) -> Result<User> {
        let username = username.into();
        let email = email.into();

        // Check username constraints
        if username.len() < 4 {
            return Err(Error(Status::BadRequest));
        }

        let by_username = User::get_by_username(&username, db).await;
        let by_email = User::get_by_email(&email, db).await;

        match (by_username, by_email) {
            (Ok(Some(_)), _) | (_, Ok(Some(_))) => return Err(Error(Status::NotFound)),
            _ => (),
        }

        // Hash the password
        let hashed_password = if let Some(pass) = password {
            Some(bcrypt::hash(&pass.into(), bcrypt::DEFAULT_COST)?)
        } else {
            None
        };

        let unsubscribe_key = if subscribed {
            let rng = OsRng {};
            Some(
                rng.sample_iter(&Alphanumeric)
                    .map(char::from)
                    .take(40)
                    .collect::<String>(),
            )
        } else {
            None
        };

        let user = if let Some(mailer) = mailer {
            // Generate activation key
            let rng = OsRng {};
            let activation_key = rng
                .sample_iter(&Alphanumeric)
                .map(char::from)
                .take(40)
                .collect::<String>();

            let activation_url = format!("{}/activate/{}", mailer.root, activation_key);
            let text = validation_email_plain_text(&activation_url);
            let html = validation_email_html(&activation_url);

            mailer.send_mail(&email, String::from("Welcome to Polymny"), text, html)?;

            User::create(
                username,
                email,
                None,
                hashed_password,
                false,
                activation_key,
                None,
                None,
                unsubscribe_key,
                Plan::Free,
                config.quota_disk_free,
                None,
                None,
            )
        } else {
            User::create(
                username,
                email,
                None,
                hashed_password,
                true,
                None,
                None,
                None,
                unsubscribe_key,
                Plan::Free,
                config.quota_disk_free,
                Some(Utc::now().naive_utc()),
                None,
            )
        };

        let user = user.save(&db).await?;
        Ok(user)
    }

    /// Request to change a user's email address.
    pub async fn request_change_email(
        &mut self,
        new_email: String,
        mailer: &Option<Mailer>,
        db: &Db,
    ) -> Result<()> {
        if let Some(mailer) = mailer {
            // Generate activation key
            let rng = OsRng {};
            let activation_key = rng
                .sample_iter(&Alphanumeric)
                .map(char::from)
                .take(40)
                .collect::<String>();

            let activation_url = format!("{}/validate-email/{}", mailer.root, activation_key);
            let text = validation_new_email_plain_text(&activation_url);
            let html = validation_new_email_html(&activation_url);

            mailer.send_mail(&new_email, String::from("Welcome to Polymny"), text, html)?;

            self.secondary_email = Some(new_email);
            self.secondary_email_key = Some(activation_key);
        } else {
            self.email = new_email;
        }

        self.save(&db).await?;
        Ok(())
    }

    /// Validates a user's new email.
    pub async fn validate_change_email(key: String, db: &Db) -> Result<()> {
        let mut user = match User::get_by_secondary_email_key(key, &db).await? {
            Some(u) => u,
            _ => return Err(Error(Status::NotFound)),
        };

        if let Some(new_email) = user.secondary_email.as_ref() {
            user.email = new_email.clone();
            user.secondary_email_key = None;
        }

        user.save(&db).await?;
        Ok(())
    }

    /// Authenticates a user from its username and password.
    pub async fn authenticate(username: &str, password: &str, db: &Db) -> Result<User> {
        let user = User::get_by_username(username, db).await?;

        let user = if let Some(user) = user {
            user
        } else {
            User::get_by_email(username, db)
                .await?
                .ok_or(Error(Status::NotFound))?
        };

        user.test_password(password)?;

        Ok(user)
    }

    /// Updates a password from the change password key.
    pub async fn update_password_by_key(key: &str, new_password: &str, db: &Db) -> Result<()> {
        let mut user = User::get_by_reset_password_key(Some(key.to_string()), &db)
            .await?
            .ok_or(Error(Status::NotFound))?;

        user.set_password(new_password)?;
        user.reset_password_key = None;

        user.save(&db).await?;
        Ok(())
    }

    /// Updates the password with the specified hash.
    pub fn set_password(&mut self, new_password: &str) -> Result<()> {
        self.hashed_password = Some(bcrypt::hash(new_password, bcrypt::DEFAULT_COST)?);
        Ok(())
    }

    /// Tests if the password is correct.
    pub fn test_password(&self, password: &str) -> Result<()> {
        match &self.hashed_password {
            Some(hash) => {
                if !bcrypt::verify(password, &hash)? {
                    Err(Error(Status::Unauthorized))
                } else {
                    Ok(())
                }
            }
            _ => Err(Error(Status::Unauthorized)),
        }
    }

    /// Creates a session for the user and saves it.
    pub async fn save_session(&self, db: &Db) -> Result<Session> {
        // Generate the secret
        let rng = OsRng {};
        let secret = rng
            .sample_iter(&Alphanumeric)
            .map(char::from)
            .take(40)
            .collect::<String>();

        let session = Session::new(secret, self, db).await?;
        Ok(session)
    }

    /// Gets a user from its session key.
    pub async fn get_from_session(secret: &str, db: &Db) -> Result<Option<User>> {
        let session = match Session::get_by_secret(secret, db).await? {
            None => return Ok(None),
            Some(s) => s,
        };
        Ok(Some(session.owner(&db).await?))
    }

    /// Returns a json representation of the user.
    pub async fn to_json(&self, db: &Db, s3: Option<&S3>) -> Result<Value> {
        let capsules = self.capsules(&db).await?;
        let capsules = capsules
            .iter()
            .map(|(capsule, role)| capsule.to_json(*role, db, s3))
            .collect::<Vec<_>>();

        let capsules = try_join_all(capsules).await?;

        let notifications = self
            .notifications(&db)
            .await?
            .iter()
            .map(|x| x.to_json())
            .collect::<Vec<_>>();

        let groups = self.groups(&db).await?;
        let groups = groups
            .iter()
            .map(|(group, _)| {
                group.to_json(&db)
            })
            .collect::<Vec<_>>();

        let groups = try_join_all(groups).await?;

        Ok(json!({
            "username": self.username,
            "email": self.email,
            "capsules": capsules,
            "notifications": notifications,
            "plan": self.plan,
            "disk_quota": self.disk_quota,
            "groups": groups,
        }))
    }

    /// Returns a json representation of the user (for admin).
    pub async fn admin_to_json(&self, db: &Db, s3: Option<&S3>) -> Result<Value> {
        let mut user_json = self.to_json(&db, s3).await?;
        user_json["id"] = json!(self.id);
        user_json["activated"] = json!(self.activated);
        user_json["newsletter_subscribed"] = json!(self.unsubscribe_key.is_some());
        user_json["member_since"] = json!(self.member_since.map(|x| x.timestamp()));
        user_json["last_visited"] = json!(self.last_visited.map(|x| x.timestamp()));

        Ok(user_json)
    }

    /// Requests the user to change its password.
    pub async fn request_change_password(
        &mut self,
        mailer: &Option<Mailer>,
        db: &Db,
    ) -> Result<()> {
        let rng = OsRng {};
        let key = rng
            .sample_iter(&Alphanumeric)
            .map(char::from)
            .take(40)
            .collect::<String>();

        self.reset_password_key = Some(key.clone());
        self.save(&db).await?;

        match mailer {
            Some(mailer) => {
                let activation_url = format!("{}/reset-password/{}", mailer.root, key);
                let text = reset_password_email_plain_text(&activation_url);
                let html = reset_password_email_html(&activation_url);

                dbg!(mailer.send_mail(
                    &self.email,
                    String::from("Reset your Polymny password"),
                    text,
                    html,
                ))?;
            }

            _ => (),
        }

        Ok(())
    }

    /// Gets a capsule by id checking if the user have the sufficient permissions.
    pub async fn get_capsule_with_permission(
        &self,
        id: i32,
        permission: Role,
        db: &Db,
    ) -> Result<(Capsule, Role)> {
        if self.plan == Plan::Admin {
            let capsule = Capsule::get_by_id(id, &db).await?;
            if let Some(capsule) = capsule {
                Ok((capsule, Role::Owner))
            } else {
                Err(Error(Status::NotFound))
            }
        } else {
            Ok(self
                .capsules(&db)
                .await?
                .into_iter()
                .filter(|(x, r)| x.id == id && *r >= permission)
                .nth(0)
                .ok_or(Error(Status::NotFound))?)
        }
    }

    /// Invite a user to join polymny
    pub async fn request_invitation(
        self,
        username: String,
        email: String,
        mailer: &Option<Mailer>,
        db: &Db,
        config: &Config,
    ) -> Result<()> {
        match User::get_by_username(&username, db).await? {
            Some(_) => Err(Error(Status::BadRequest)),
            None => match User::get_by_email(&email, db).await? {
                Some(_) => Err(Error(Status::BadRequest)),
                None => {
                    info!("Ready to send mail");
                    if let Some(mailer) = mailer {
                        // Generate a random password
                        let rng = OsRng {};
                        let hashed_password = bcrypt::hash(
                            rng.sample_iter(&Alphanumeric)
                                .map(char::from)
                                .take(12)
                                .collect::<String>(),
                            bcrypt::DEFAULT_COST,
                        )?;
                        // Generate activation key
                        let rng = OsRng {};
                        let activation_key = rng
                            .sample_iter(&Alphanumeric)
                            .map(char::from)
                            .take(40)
                            .collect::<String>();

                        let rng = OsRng {};
                        let unsubscribe_key = Some(
                            rng.sample_iter(&Alphanumeric)
                                .map(char::from)
                                .take(40)
                                .collect::<String>(),
                        );

                        let activation_url =
                            format!("{}/validate-invitation/{}", mailer.root, &activation_key);
                        let text = validation_invitation_plain_text(&activation_url);
                        let html = validation_invitation_html(&activation_url);

                        mailer.send_mail(&email, String::from("Welcome to Polymny"), text, html)?;

                        User::create(
                            username,
                            &email,
                            None,
                            hashed_password,
                            false,
                            activation_key,
                            None,
                            None,
                            unsubscribe_key,
                            Plan::Free,
                            config.quota_disk_free,
                            None,
                            None,
                        )
                        .save(&db)
                        .await?;

                        Ok(())
                    } else {
                        error!("Impossible to send mail: mailer not set ?");
                        Err(Error(Status::BadRequest))
                    }
                }
            },
        }
    }

    /// Sends a notification to the user.
    pub async fn notify(&self, sock: &Notifier, title: &str, message: &str, db: &Db) -> Result<()> {
        let notification =
            Notification::create(title.to_string(), message.to_string(), false, self)
                .save(&db)
                .await?;

        sock.write_message(self.id, &notification.to_json()).await?;

        Ok(())
    }

    /// Gets a user by username or email.
    pub async fn get_by_username_or_email(input: &str, db: &Db) -> Result<Option<User>> {
        match User::get_by_username(input, db).await? {
            Some(u) => Ok(Some(u)),
            None => Ok(User::get_by_email(input, db).await?),
        }
    }
}

#[rocket::async_trait]
impl<'r> FromRequest<'r> for User {
    type Error = Error;

    async fn from_request(request: &'r Request<'_>) -> Outcome<Self, Self::Error> {
        let db = match request.guard::<Db>().await {
            Outcome::Success(db) => db,
            Outcome::Error(x) => return Outcome::Error(x),
            Outcome::Forward(s) => return Outcome::Forward(s),
        };

        let cookie = match request.cookies().get_private("EXAUTH") {
            Some(c) => c,
            _ => return Outcome::Error((Status::Unauthorized, Error(Status::Unauthorized))),
        };

        let mut user = match User::get_from_session(cookie.value(), &db).await {
            Ok(Some(user)) => user,
            _ => return Outcome::Error((Status::Unauthorized, Error(Status::Unauthorized))),
        };

        if !user.activated {
            return Outcome::Error((Status::Unauthorized, Error(Status::Unauthorized)));
        }

        user.last_visited = Some(Utc::now().naive_utc());

        if user.save(&db).await.is_err() {
            return Outcome::Error((
                Status::InternalServerError,
                Error(Status::InternalServerError),
            ));
        }

        Outcome::Success(user)
    }
}

/// An administrator user.
///
/// This is just a wrapper for a user that has admin rights.
pub struct Admin(pub User);

#[rocket::async_trait]
impl<'r> FromRequest<'r> for Admin {
    type Error = Error;
    async fn from_request(request: &'r Request<'_>) -> Outcome<Self, Self::Error> {
        let user = match User::from_request(request).await {
            Outcome::Success(user) => user,
            Outcome::Error(x) => return Outcome::Error(x),
            Outcome::Forward(s) => return Outcome::Forward(s),
        };
        if user.plan != Plan::Admin {
            return Outcome::Error((Status::Forbidden, Error(Status::Forbidden)));
        }
        Outcome::Success(Admin(user))
    }
}

impl Admin {
    /// Returns a json representation of the user.
    pub async fn to_json(&self, db: &Db, s3: Option<&S3>) -> Result<Value> {
        let users = futures::future::join_all(
            User::select()
                .order_by(user::id::descend())
                .limit(50)
                .execute(&db)
                .await?
                .iter()
                .map(|user| user.admin_to_json(db, s3)),
        )
        .await
        .into_iter()
        .collect::<Result<Vec<_>>>()?;

        let capsules = futures::future::join_all(
            Capsule::select()
                .order_by(capsule::id::descend())
                .limit(50)
                .execute(&db)
                .await?
                .iter()
                .map(|capsule| capsule.to_json(Role::Read, db, s3)),
        )
        .await
        .into_iter()
        .collect::<Result<Vec<_>>>()?;

        Ok(json!({ "users": users,
                   "capsules": capsules}))
    }

    /// Dummy stats functions
    pub async fn do_stats(&self, _db: &Db) -> Result<Value> {
        Ok(json!({ "stats": "some stats"}))
    }

    /// Returns a paged representation users.
    pub async fn get_users(&self, db: &Db, s3: Option<&S3>, page: i32) -> Result<Value> {
        if page < 0 {
            let users: Vec<User> = vec![];
            return Ok(json!(users));
        }

        let users = futures::future::join_all(
            User::select()
                .order_by(user::id::descend())
                .limit(PAGE_SIZE)
                .offset((page as usize) * PAGE_SIZE)
                .execute(&db)
                .await?
                .iter()
                .map(|user| user.admin_to_json(db, s3)),
        )
        .await
        .into_iter()
        .collect::<Result<Vec<_>>>()?;

        Ok(json!(users))
    }

    /// Search by username.
    pub async fn search_by_username(
        &self,
        db: &Db,
        s3: Option<&S3>,
        search: &str,
    ) -> Result<Value> {
        let users = futures::future::join_all(
            User::select()
                .filter(user::username::like(format!("%{}%", search.to_string())))
                .order_by(user::id::descend())
                .execute(&db)
                .await?
                .iter()
                .map(|user| user.admin_to_json(db, s3)),
        )
        .await
        .into_iter()
        .collect::<Result<Vec<_>>>()?;

        Ok(json!(users))
    }

    /// Search by email.
    pub async fn search_by_email(&self, db: &Db, s3: Option<&S3>, search: &str) -> Result<Value> {
        let users = futures::future::join_all(
            User::select()
                .filter(user::email::like(format!("%{}%", search.to_string())))
                .order_by(user::id::descend())
                .execute(&db)
                .await?
                .iter()
                .map(|user| user.admin_to_json(db, s3)),
        )
        .await
        .into_iter()
        .collect::<Result<Vec<_>>>()?;

        Ok(json!(users))
    }

    /// Returns a user for admin in json fomat.
    pub async fn get_user(&self, db: &Db, s3: Option<&S3>, id: i32) -> Result<Value> {
        let user = User::get_by_id(id, db)
            .await?
            .ok_or(Error(Status::NotFound))?;

        let user = user.admin_to_json(db, s3).await?;

        Ok(json!(user))
    }

    /// Returns a paginated representation of capsules.
    pub async fn get_capsules(&self, db: &Db, s3: Option<&S3>, page: i32) -> Result<Value> {
        let capsules = futures::future::join_all(
            Capsule::select()
                .order_by(capsule::last_modified::descend())
                .limit(PAGE_SIZE)
                .offset((page as usize) * PAGE_SIZE)
                .execute(&db)
                .await?
                .iter()
                .map(|capsule| capsule.to_json(Role::Read, db, s3)),
        )
        .await
        .into_iter()
        .collect::<Result<Vec<_>>>()?;

        Ok(json!(capsules))
    }

    /// Search by capsules.
    pub async fn search_by_capsule(&self, db: &Db, s3: Option<&S3>, search: &str) -> Result<Value> {
        let capsules = futures::future::join_all(
            Capsule::select()
                .filter(capsule::name::like(format!("%{}%", search.to_string())))
                .order_by(capsule::last_modified::descend())
                .execute(&db)
                .await?
                .iter()
                .map(|capsule| capsule.to_json(Role::Read, db, s3)),
        )
        .await
        .into_iter()
        .collect::<Result<Vec<_>>>()?;

        Ok(json!(capsules))
    }

    /// Search by project.
    pub async fn search_by_project(&self, db: &Db, s3: Option<&S3>, search: &str) -> Result<Value> {
        let capsules = futures::future::join_all(
            Capsule::select()
                .filter(capsule::project::like(format!("%{}%", search.to_string())))
                .order_by(capsule::last_modified::descend())
                .execute(&db)
                .await?
                .iter()
                .map(|capsule| capsule.to_json(Role::Read, db, s3)),
        )
        .await
        .into_iter()
        .collect::<Result<Vec<_>>>()?;

        Ok(json!(capsules))
    }
}
