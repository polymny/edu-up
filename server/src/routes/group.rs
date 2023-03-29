//! This module contains all the routes for the group and assignment management.

use serde::{Deserialize, Serialize};

use rocket::http::Status;
use rocket::serde::json::{json, Json, Value};

use crate::db::group::{Group, ParticipantRole};
use crate::db::user::User;
use crate::{Db, Error, Result};

/// The data for the new group form.
#[derive(Serialize, Deserialize)]
pub struct NewGroupFrom {
    /// The name of the group.
    pub name: String,
}

/// Route to create a new group of students.
#[post("/new-group", data = "<form>")]
pub async fn new_group(user: User, db: Db, form: Json<NewGroupFrom>) -> Result<Value> {
    let form = form.into_inner();

    let group = Group::create(form.name).save(&db).await?;
    group
        .add_participant(&user, ParticipantRole::Teacher, &db)
        .await?;

    Ok(group.to_json(&db).await?)
}

/// The data for the new group form.
#[derive(Serialize, Deserialize)]
pub struct DeleteGroupFrom {
    /// The id of the group.
    pub group_id: i32,
}

/// Route to create a new group of students.
#[delete("/delete-group", data = "<form>")]
pub async fn delete_group(user: User, db: Db, form: Json<DeleteGroupFrom>) -> Result<()> {
    let form = form.into_inner();

    let group = Group::get_by_id(form.group_id, &db)
        .await?
        .ok_or(Error(Status::BadRequest))?;

    let mut found = false;
    for (participant, role) in group.participants(&db).await? {
        if participant.id == user.id && role == ParticipantRole::Teacher {
            found = true;
        }
    }

    if !found {
        return Err(Error(Status::NotFound));
    }

    group.delete(&db).await?;

    Ok(())
}

/// The data for the add participant form.
#[derive(Serialize, Deserialize)]
pub struct AddParticipantForm {
    /// The id of the group to which you want to add the participant.
    group_id: i32,

    /// The participant to add.
    participant: String,

    /// The role of the participant.
    participant_role: ParticipantRole,
}

/// Route to add a participant to a group of students.
#[post("/add-participant", data = "<form>")]
pub async fn add_participant(user: User, db: Db, form: Json<AddParticipantForm>) -> Result<Value> {
    let form = form.into_inner();

    // Fetch the group
    let group = Group::get_by_id(form.group_id, &db)
        .await?
        .ok_or(Error(Status::InternalServerError))?;

    // Check that the user is a teacher in the group
    let mut found = false;
    for (participant, role) in group.participants(&db).await? {
        if participant.id == user.id && role == ParticipantRole::Teacher {
            found = true;
        }
    }

    if !found {
        return Err(Error(Status::NotFound));
    }

    // Fetch the participant
    let participant = User::get_by_email(form.participant, &db)
        .await?
        .ok_or(Error(Status::NotFound))?;

    // Add the participant
    group
        .add_participant(&participant, form.participant_role, &db)
        .await?;

    Ok(json!({
        "username": participant.username,
        "email": participant.email,
        "role": form.participant_role,
    }))
}

/// The data for the remove participant form.
#[derive(Serialize, Deserialize)]
pub struct RemoveParticipantForm {
    /// The id of the group to which you want to add the participant.
    group_id: i32,

    /// The participant to add.
    participant: String,
}

/// Route to remove a participant to a group of students.
#[delete("/remove-participant", data = "<form>")]
pub async fn remove_participant(
    user: User,
    db: Db,
    form: Json<RemoveParticipantForm>,
) -> Result<()> {
    let form = form.into_inner();

    // Fetch the group
    let group = Group::get_by_id(form.group_id, &db)
        .await?
        .ok_or(Error(Status::InternalServerError))?;

    // Check that the user is a teacher in the group
    let mut found = false;
    let participants = group.participants(&db).await?;
    for (participant, role) in &participants {
        if participant.id == user.id && *role == ParticipantRole::Teacher {
            found = true;
        }
    }

    if !found {
        return Err(Error(Status::NotFound));
    }

    if participants
        .iter()
        .filter(|(_, r)| *r == ParticipantRole::Teacher)
        .count()
        == 1
    {
        // The teacher is trying to remove themself from a group where they are the only teacher.
        // We do not allow that.
        return Err(Error(Status::BadRequest));
    }

    // Fetch the participant
    let participant = User::get_by_email(form.participant, &db)
        .await?
        .ok_or(Error(Status::NotFound))?;

    // Add the participant
    group.remove_participant(&participant, &db).await?;

    Ok(())
}
