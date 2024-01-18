//! This module contains the routes for admin management.

use tokio::fs::remove_dir_all;

use rocket::http::Status;
use rocket::serde::json::{json, Json, Value};
use rocket::State as S;

use serde::{Deserialize, Serialize};

use crate::config::Config;
use crate::db::capsule::Role;
use crate::db::user::{Admin, User};
use crate::storage::Storage;
use crate::{Db, Error, Result};

/// Admin get dashboard
#[get("/admin/dashboard")]
pub async fn get_dashboard(admin: Admin, db: Db) -> Result<Value> {
    admin.do_stats(&db).await
}

/// Admin get pagniated users
#[get("/admin/users/<page>")]
pub async fn get_users(admin: Admin, db: Db, storage: &S<Storage>, page: i32) -> Result<Value> {
    admin.get_users(&db, storage.inner().s3(), page).await
}

/// Admin get search users
#[get("/admin/searchusers?<username>&<email>")]
pub async fn get_search_users(
    admin: Admin,
    db: Db,
    username: Option<String>,
    email: Option<String>,
    storage: &S<Storage>,
) -> Result<Value> {
    if let Some(username) = &username {
        admin
            .search_by_username(&db, storage.inner().s3(), username)
            .await
    } else {
        if let Some(email) = &email {
            admin
                .search_by_email(&db, storage.inner().s3(), email)
                .await
        } else {
            let v: Vec<Value> = vec![];
            Ok(json!(v))
        }
    }
}

/// Admin get user id
#[get("/admin/user/<id>")]
pub async fn get_user(admin: Admin, db: Db, storage: &S<Storage>, id: i32) -> Result<Value> {
    admin.get_user(&db, storage.inner().s3(), id).await
}

/// Admin get pagniated capsules
#[get("/admin/capsules/<page>")]
pub async fn get_capsules(admin: Admin, db: Db, storage: &S<Storage>, page: i32) -> Result<Value> {
    admin.get_capsules(&db, storage.inner().s3(), page).await
}

/// Admin get search capsules
#[get("/admin/searchcapsules?<capsule>&<project>")]
pub async fn get_search_capsules(
    admin: Admin,
    db: Db,
    capsule: Option<String>,
    project: Option<String>,
    storage: &S<Storage>,
) -> Result<Value> {
    if let Some(capsule) = &capsule {
        admin
            .search_by_capsule(&db, storage.inner().s3(), capsule)
            .await
    } else {
        if let Some(project) = &project {
            admin
                .search_by_project(&db, storage.inner().s3(), project)
                .await
        } else {
            let v: Vec<Value> = vec![];
            Ok(json!(v))
        }
    }
}

/// Inviter User form
#[derive(Serialize, Deserialize)]
pub struct InviteUserForm {
    /// The username of the user to invite.
    username: String,

    /// The email address of the user to invite.
    email: String,
}
/// Route to invite user.
#[post("/admin/invite-user", data = "<form>")]
pub async fn request_invite_user(
    admin: Admin,
    db: Db,
    config: &S<Config>,
    form: Json<InviteUserForm>,
) -> Result<()> {
    Ok(admin
        .0
        .request_invitation(form.0.username, form.0.email, &config.mailer, &db, &config)
        .await?)
}

/// The route that deletes a user
#[delete("/admin/user/<id>")]
pub async fn delete_user(_admin: Admin, db: Db, id: i32, config: &S<Config>) -> Result<()> {
    let user = User::get_by_id(id, &db)
        .await?
        .ok_or(Error(Status::NotFound))?;

    let capsules = user.capsules(&db).await?;
    for (capsule, role) in capsules {
        if role == Role::Owner {
            let dir = config.data_path.join(format!("{}", capsule.id));
            remove_dir_all(dir).await?;
            capsule.delete(&db).await?;
        }
    }

    Ok(user.delete(&db).await?)
}
