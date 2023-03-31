//! This module contains all the routes for the group and assignment management.

use serde::{Deserialize, Serialize};

use tokio::fs::{copy, create_dir_all, read_dir};

use rocket::http::Status;
use rocket::serde::json::{json, Json, Value};
use rocket::State as S;

use crate::config::Config;
use crate::db::capsule::{Capsule, Role};
use crate::db::group::{Answer, Assignment, Group, ParticipantRole, AssignmentState};
use crate::db::user::User;
use crate::{Db, Error, HashId, Result};

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
pub async fn delete_group(user: User, db: Db, form: Json<DeleteGroupFrom>) -> Result<Value> {
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

    Ok(json!({}))
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

    // Check that the participant is not already in the group
    let participants = group.participants(&db).await?;
    for (p, _) in &participants {
        if p.id == participant.id {
            return Err(Error(Status::BadRequest));
        }
    }

    // Add the participant
    group
        .add_participant(&participant, form.participant_role, &db)
        .await?;

    Ok(group.to_json(&db).await?)
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
) -> Result<Value> {
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

    // Fetch the participant and their role
    let (participant, participant_role) = participants
        .iter()
        .find(|(p, _)| p.email == form.participant)
        .ok_or(Error(Status::NotFound))?;

    if *participant_role == ParticipantRole::Teacher
        && participants
            .iter()
            .filter(|(_, r)| *r == ParticipantRole::Teacher)
            .count()
            == 1
    {
        // The teacher is trying to remove themself from a group where they are the only teacher.
        // We do not allow that.
        return Err(Error(Status::BadRequest));
    }

    // Remove the participant
    group.remove_participant(&participant, &db).await?;

    Ok(group.to_json(&db).await?)
}

/// The data for the remove participant form.
#[derive(Serialize, Deserialize)]
pub struct NewAssignmentForm {
    /// The criteria for evaluation of the assignment.
    pub criteria: Vec<String>,

    /// The subject for the assignment.
    pub subject: HashId,

    /// The template for answering the subject.
    pub answer_template: HashId,

    /// The id of the group to which you want to assign the task.
    pub group_id: i32,
}

/// Create a new assignment for a group.
#[post("/new-assignment", data = "<form>")]
pub async fn new_assignment(user: User, db: Db, form: Json<NewAssignmentForm>) -> Result<Value> {
    let form = form.into_inner();

    let (subject, _) = user
        .get_capsule_with_permission(*form.subject, Role::Write, &db)
        .await?;

    let (answer_template, _) = user
        .get_capsule_with_permission(*form.answer_template, Role::Write, &db)
        .await?;

    let group = Group::get_by_id(form.group_id, &db)
        .await?
        .ok_or(Error(Status::NotFound))?;

    // Check that user is a teacher from the group
    let mut allowed = false;
    for (participant, role) in group.participants(&db).await? {
        if participant.id == user.id && role == ParticipantRole::Teacher {
            allowed = true;
        }
    }

    if !allowed {
        return Err(Error(Status::Forbidden));
    }

    let criteria = form
        .criteria
        .iter()
        .map(|x| x.trim())
        .filter(|x| !x.is_empty())
        .collect::<Vec<_>>()
        .join("\n");

    let assignment = Assignment::create(criteria, subject, answer_template, group, AssignmentState::Preparation)
        .save(&db)
        .await?;

    Ok(assignment.to_json(&db).await?)
}

/// Form for deleting an assignment.
#[derive(Serialize, Deserialize)]
pub struct DeleteAssignmentForm {
    /// The id of the assignment to validate.
    pub assignment_id: i32,
}

/// Validates an assignment and create all the capsules for students based on the template.
#[delete("/delete-assignment", data = "<form>")]
pub async fn delete_assignment(
    user: User,
    db: Db,
    form: Json<ValidateAssignmentForm>,
) -> Result<()> {
    let form = form.into_inner();

    let assignment = Assignment::get_by_id(form.assignment_id, &db)
        .await?
        .ok_or(Error(Status::NotFound))?;

    let participants = assignment.group(&db).await?.participants(&db).await?;

    // Check that user is a teacher from the group
    let mut allowed = false;

    for (participant, role) in &participants {
        if participant.id == user.id && *role == ParticipantRole::Teacher {
            allowed = true;
        }
    }

    if !allowed {
        return Err(Error(Status::Forbidden));
    }

    assignment.delete(&db).await?;

    Ok(())
}

/// Form for validating an assignment.
#[derive(Serialize, Deserialize)]
pub struct ValidateAssignmentForm {
    /// The id of the assignment to validate.
    pub assignment_id: i32,
}

/// Validates an assignment and create all the capsules for students based on the template.
#[post("/validate-assignment", data = "<form>")]
pub async fn validate_assignment(
    user: User,
    db: Db,
    config: &S<Config>,
    form: Json<ValidateAssignmentForm>,
) -> Result<()> {
    let form = form.into_inner();

    let assignment = Assignment::get_by_id(form.assignment_id, &db)
        .await?
        .ok_or(Error(Status::NotFound))?;

    let participants = assignment.group(&db).await?.participants(&db).await?;

    // Check that user is a teacher from the group
    let mut allowed = false;

    for (participant, role) in &participants {
        if participant.id == user.id && *role == ParticipantRole::Teacher {
            allowed = true;
        }
    }

    if !allowed {
        return Err(Error(Status::Forbidden));
    }

    let template = assignment.answer_template(&db).await?;

    // Prepare answers for students
    for (user, role) in participants {
        if role == ParticipantRole::Teacher {
            continue;
        }

        let mut new = Capsule::new(&template.project, format!("{}", template.name), &user, &db)
            .await
            .unwrap();

        new.privacy = template.privacy.clone();
        new.produced = template.produced;
        new.structure = template.structure.clone();
        new.webcam_settings = template.webcam_settings.clone();
        new.sound_track = template.sound_track.clone();
        new.duration_ms = template.duration_ms;

        for dir in ["assets", "tmp", "output"] {
            let orig = config.data_path.join(&format!("{}/{}", template.id, dir));
            let dest = config.data_path.join(&format!("{}/{}", new.id, dir));

            if orig.is_dir() {
                create_dir_all(&dest).await.unwrap();

                let mut iter = read_dir(&orig)
                    .await
                    .map_err(|_| Error(Status::InternalServerError))
                    .unwrap();

                loop {
                    let next = iter
                        .next_entry()
                        .await
                        .map_err(|_| Error(Status::InternalServerError))
                        .unwrap();

                    let next = match next {
                        Some(x) => x,
                        None => break,
                    };

                    let path = next.path();
                    let file_name = path
                        .file_name()
                        .ok_or(Error(Status::InternalServerError))
                        .unwrap();

                    copy(orig.join(&file_name), dest.join(&file_name))
                        .await
                        .map_err(|_| Error(Status::InternalServerError))
                        .unwrap();
                }
            }
        }

        let orig = config
            .data_path
            .join(&format!("{}/output.mp4", template.id));
        let dest = config.data_path.join(&format!("{}/output.mp4", new.id));

        if orig.is_file() {
            copy(orig, dest)
                .await
                .map_err(|_| Error(Status::InternalServerError))
                .unwrap();
        }

        new.set_changed();
        new.save(&db).await.unwrap();

        Answer::create(&assignment, &new).save(&db).await.unwrap();
    }

    Ok(())
}
