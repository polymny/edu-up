//! This module contains all the routes.

pub mod asset;
pub mod auth;
pub mod capsule;
pub mod loggedin;
pub mod project;
pub mod setup;
pub mod slide;

use std::io::Cursor;
use std::path::PathBuf;

use rocket::http::ContentType;
use rocket::response::{NamedFile, Response};
use rocket::State;

use rocket_contrib::json::JsonValue;

use crate::config::Config;
use crate::db::user::User;
use crate::templates;
use crate::{Database, Result};

fn jsonify_flags(db: &Database, user: &Option<User>, id: i32, page: &str) -> Result<JsonValue> {
    let user_and_projects = if let Some(user) = user.as_ref() {
        Some((user, user.projects(&db)?))
    } else {
        None
    };

    Ok(match user.as_ref().map(|x| x.get_capsule_by_id(id, &db)) {
        Some(Ok(capsule)) => {
            let slide_show = capsule.get_slide_show(&db)?;
            let slides = capsule.get_slides(&db)?;
            let background = capsule.get_background(&db)?;
            let logo = capsule.get_logo(&db)?;
            let video = capsule.get_video(&db)?;

            user_and_projects
                .map(|(user, projects)| {
                    json!({
                        "page":       page,
                        "username":   user.username,
                        "projects":   projects,
                        "capsule" :   capsule,
                        "slide_show": slide_show,
                        "slides":     slides,
                        "background":  background,
                        "logo":        logo,
                        "active_project":"",
                        "structure":   capsule.structure,
                        "video": video,
                    })
                })
                .unwrap_or_else(|| json!(null))
        }

        _ => user_and_projects
            .map(|(user, projects)| {
                json!({
                    "username": user.username,
                    "projects": projects,
                    "page": "index",
                    "active_project": "",
                })
            })
            .unwrap_or_else(|| json!(null)),
    })
}

/// Returns the json for the global info.
fn global(config: &State<Config>) -> JsonValue {
    json!({
        "video_root": config.video_root,
        "beta": config.beta,
        "version": config.version,
        "commit": config.commit,
    })
}

/// Helper to answer the HTML page with the Elm code as well as flags.
fn helper_html<'a>(config: &State<Config>, flags: JsonValue) -> Response<'a> {
    Response::build()
        .header(ContentType::HTML)
        .sized_body(Cursor::new(templates::index_html(helper_json(
            config, flags,
        ))))
        .finalize()
}

/// Helper to answer the JSON info as well as flags.
fn helper_json(config: &State<Config>, flags: JsonValue) -> JsonValue {
    json!({"global": global(config), "flags": flags})
}

macro_rules! make_route {
    ($route: expr, $function: expr, $function_html: ident, $function_json: ident) => {
        #[allow(missing_docs)]
        #[get($route, format = "text/html", rank = 1)]
        pub fn $function_html<'a>(
            config: State<Config>,
            db: Database,
            user: Option<User>,
        ) -> Result<Response<'a>> {
            Ok(helper_html(&config, $function))
        }

        #[allow(missing_docs)]
        #[get($route, format = "application/json", rank = 2)]
        pub fn $function_json<'a>(
            config: State<Config>,
            db: Database,
            user: Option<User>,
        ) -> Result<JsonValue> {
            Ok(helper_json(&config, $function))
        }
    };

    ($route: expr, $param: expr, $ty: ty, $function: expr, $function_html: ident, $function_json: ident) => {
        #[allow(missing_docs)]
        #[get($route, format = "text/html", rank = 1)]
        pub fn $function_html<'a>(
            config: State<Config>,
            db: Database,
            user: Option<User>,
            $param: $ty,
        ) -> Result<Response<'a>> {
            Ok(helper_html(&config, $function))
        }

        #[allow(missing_docs)]
        #[get($route, format = "application/json", rank = 2)]
        pub fn $function_json<'a>(
            config: State<Config>,
            db: Database,
            user: Option<User>,
            $param: $ty,
        ) -> Result<JsonValue> {
            Ok(helper_json(&config, $function))
        }
    };
}

/// The json for the index page.
fn index(db: Database, user: Option<User>) -> Result<JsonValue> {
    let user_and_projects = if let Some(user) = user.as_ref() {
        Some((user, user.projects(&db)?))
    } else {
        None
    };

    Ok(user_and_projects
        .map(|(user, projects)| {
            json!({
                "page": "index",
                "username": user.username,
                "projects": projects,
                "active_project":"",
            })
        })
        .unwrap_or_else(|| json!(null)))
}

make_route!("/", index(db, user)?, index_html, index_json);

make_route!(
    "/capsule/<id>/preparation",
    id,
    i32,
    jsonify_flags(&db, &user, id, "preparation/capsule")?,
    capsule_preparation_html,
    capsule_preparation_json
);

make_route!(
    "/capsule/<id>/acquisition",
    id,
    i32,
    jsonify_flags(&db, &user, id, "acquisition/capsule")?,
    capsule_acquisition_html,
    capsule_acquisition_json
);

make_route!(
    "/capsule/<id>/edition",
    id,
    i32,
    jsonify_flags(&db, &user, id, "edition/capsule")?,
    capsule_edition_html,
    capsule_edition_json
);

/// The route for the setup page, available only when Rocket.toml does not exist yet.
#[get("/")]
pub fn setup<'a>() -> Response<'a> {
    Response::build()
        .header(ContentType::HTML)
        .sized_body(Cursor::new(templates::setup_html()))
        .finalize()
}

/// The route for static files that require authorization.
#[get("/<path..>")]
pub fn data<'a>(path: PathBuf, user: User, config: State<Config>) -> Option<NamedFile> {
    if path.starts_with(user.username) {
        let data_path = config.data_path.join(path);
        NamedFile::open(data_path).ok()
    } else {
        None
    }
}
