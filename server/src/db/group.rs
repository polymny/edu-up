//! This module helps us deal with students groups.

use serde::{Deserialize, Serialize};

use ergol::prelude::*;
use ergol::tokio_postgres::types::Json as EJson;

use rocket::http::Status;
use rocket::serde::json::{json, Value};

use tokio::fs::{copy, create_dir_all, read_dir};

use crate::command::export_slides;
use crate::config::Config;
use crate::db::capsule::{Capsule, Fade, Gos, Role, Slide};
use crate::db::user::User;
use crate::{Db, Error, Result, HARSH};

/// The different levels of authorization a user can have.
#[derive(Debug, Copy, Clone, PgEnum, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "lowercase")]
pub enum ParticipantRole {
    /// A student that participates in a group.
    Student,

    /// A teacher that teaches the students.
    Teacher,
}

/// A group of students.
#[ergol]
pub struct Group {
    /// The id of the group.
    #[id]
    pub id: i32,

    /// The name of the group.
    pub name: String,

    /// The people inside the group.
    #[many_to_many(groups, ParticipantRole)]
    pub participants: User,
}

impl Group {
    /// Serializes the group with its participants.
    pub async fn to_json(&self, db: &Db) -> Result<Value> {
        let participants = self.participants(db).await?;
        let participants = participants
            .into_iter()
            .map(|(user, role)| {
                json!({
                    "username": user.username,
                    "email": user.email,
                    "role": role,
                })
            })
            .collect::<Vec<_>>();

        Ok(json!({
            "id": self.id,
            "name": self.name,
            "participants": participants,
        }))
    }
}

/// An assignment that a teacher will give to a group of students.
#[ergol]
pub struct Assignment {
    /// The id of the assignment.
    #[id]
    pub id: i32,

    /// The criteria for the evaluation of the assignment, seperated by new lines.
    pub criteria: String,

    /// The subject that contains the subject of the assignment.
    #[many_to_one(assignments)]
    pub subject: Capsule,

    /// The subject that will serve as a template for answers.
    #[many_to_one(answers)]
    pub answer_template: Capsule,

    /// The group of users associated with this assignment.
    #[many_to_one(assignments)]
    pub group: Group,
}

impl Assignment {
    /// Creates a new criterion and adds it to the assignment.
    pub async fn add_criterion(&mut self, criterion: &str, db: &Db) -> Result<()> {
        self.criteria += &format!(
            "{}{}",
            if self.criteria.is_empty() { "" } else { "\n" },
            criterion
        );
        self.save(&db).await?;
        Ok(())
    }

    /// Returns a JSON value representing the assignment.
    pub async fn to_json(&self, db: &Db) -> Result<Value> {
        Ok(json!({
            "id": self.id,
            "subject": HARSH.encode(self.subject(&db).await?.id),
            "answer": HARSH.encode(self.answer_template(&db).await?.id),
            "participants": self.group(&db).await?.participants(&db).await?.into_iter().map(|(user, role)| {
                json!({
                    "username": user.username,
                    "email": user.email,
                    "role": role,
                })
            }).collect::<Vec<_>>(),
            "criteria": self.criteria.split("\n").collect::<Vec<_>>(),
        }))
    }
}

/// An answer to an assignment.
#[ergol]
pub struct Answer {
    /// The id of the answer;
    #[id]
    pub id: i32,

    /// The coresponding assignment.
    #[many_to_one(answers)]
    pub assignment: Assignment,

    /// The subject used as an answer.
    #[many_to_one(subject_answers)]
    pub capsule: Capsule,
}

impl Answer {
    /// Returns the owner of the answer.
    pub async fn owner(&self, db: &Db) -> Result<User> {
        for (user, role) in self.capsule(&db).await?.users(&db).await? {
            if role == Role::Owner {
                return Ok(user);
            }
        }

        Err(Error(Status::NotFound))
    }
}

/// An eavluation of an answer.
#[ergol]
pub struct Evaluation {
    /// The id of the evaluation.
    #[id]
    pub id: i32,

    /// The answer being evaluated.
    #[many_to_one(evaluations)]
    pub answer: Answer,

    /// The user performing the evaluation.
    #[many_to_one(evaluations)]
    pub reviewer: User,

    /// The score for each criterion.
    ///
    /// It's a string of integers seperated by new lines.
    pub scores: String,

    /// An optional capsule giving feedback to the assignee.
    #[many_to_one(evaluations)]
    pub capsule: Capsule,
}

/// Creates some users in the db.
#[rustfmt::skip]
pub async fn populate_db(db: &Db, config: &Config) -> Result<()> {
    // Find the admin (teacher)
    let polymny = User::get_by_username("polymny", &db).await.unwrap().unwrap();

    // Create a bunch of students
    let iguernon = User::new("iguernon","iguernon@example.com", "hashed", true, &None, &db, &config).await.unwrap();
    let tmarceau = User::new("tmarceau","tmarceau@example.com", "hashed", true, &None, &db, &config).await.unwrap();
    let cbabin = User::new("cbabin",  "cbabin@example.com", "hashed", true, &None, &db, &config).await.unwrap();
    let lgrignon = User::new("lgrignon","lgrignon@example.com", "hashed", true, &None, &db, &config).await.unwrap();
    let epaquin = User::new("epaquin", "epaquin@example.com", "hashed", true, &None, &db, &config).await.unwrap();
    let dsalmons = User::new("dsalmons","dsalmons@example.com", "hashed", true, &None, &db, &config).await.unwrap();
    let lsacre = User::new("lsacre",  "lsacre@example.com", "hashed", true, &None, &db, &config).await.unwrap();
    let ysalois = User::new("ysalois", "ysalois@example.com", "hashed", true, &None, &db, &config).await.unwrap();
    let rseguin = User::new("rseguin", "rseguin@example.com", "hashed", true, &None, &db, &config).await.unwrap();
    let xbrodeur = User::new("xbrodeur","xbrodeur@example.com", "hashed", true, &None, &db, &config).await.unwrap();

    // Create a few groups
    let group1 = Group::create("Terminale 1").save(&db).await.unwrap();
    group1.add_participant(&polymny, ParticipantRole::Teacher, &db).await.unwrap();
    group1.add_participant(&iguernon, ParticipantRole::Student, &db).await.unwrap();
    group1.add_participant(&tmarceau, ParticipantRole::Student, &db).await.unwrap();
    group1.add_participant(&cbabin, ParticipantRole::Student, &db).await.unwrap();

    let group2 = Group::create("Terminale 2").save(&db).await.unwrap();
    group2.add_participant(&polymny, ParticipantRole::Teacher, &db).await.unwrap();
    group2.add_participant(&lgrignon, ParticipantRole::Student, &db).await.unwrap();
    group2.add_participant(&epaquin, ParticipantRole::Student, &db).await.unwrap();
    group2.add_participant(&dsalmons, ParticipantRole::Student, &db).await.unwrap();

    let group3 = Group::create("Première 1").save(&db).await.unwrap();
    group3.add_participant(&polymny, ParticipantRole::Teacher, &db).await.unwrap();
    group3.add_participant(&lsacre, ParticipantRole::Student, &db).await.unwrap();
    group3.add_participant(&ysalois, ParticipantRole::Student, &db).await.unwrap();
    group3.add_participant(&rseguin, ParticipantRole::Student, &db).await.unwrap();
    group3.add_participant(&xbrodeur, ParticipantRole::Student, &db).await.unwrap();

    // Create the subject of the assignment
    let mut subject = Capsule::new("Mon projet", "Sujet", &polymny, &db).await.unwrap();

    let path = config
        .data_path
        .join(format!("{}", subject.id))
        .join("assets");

    create_dir_all(&path).await.unwrap();

    let gos = export_slides(&config, "example/slides.pdf", path, None).unwrap()
        .into_iter()
        .map(|x| Gos {
            record: None,
            slides: vec![Slide {
                uuid: x,
                extra: None,
                prompt: String::new(),
            }],
            events: vec![],
            webcam_settings: None,
            fade: Fade::none(),
        })
        .collect::<Vec<_>>();

    subject.structure = EJson(gos);
    subject.set_changed();
    subject.save(&db).await.unwrap();

    // Create the assignment
    let mut assignment = Assignment::create("", &subject, &subject, &group1).save(&db).await.unwrap();
    assignment.add_criterion("Respect de la consigne", &db).await.unwrap();
    assignment.add_criterion("Clarté du discours", &db).await.unwrap();
    assignment.add_criterion("Structuration du propos", &db).await.unwrap();
    assignment.add_criterion("Débit", &db).await.unwrap();
    assignment.add_criterion("Gestuelle", &db).await.unwrap();

    let assignment = Assignment::get_by_id(assignment.id, &db).await.unwrap().unwrap();
    println!("{}", assignment.to_json(&db).await?);
    let template = assignment.answer_template(&db).await.unwrap();

    // Create answers for each student
    for (user, role) in assignment.group(&db).await.unwrap().participants(&db).await.unwrap() {
        if role == ParticipantRole::Teacher {
            continue;
        }

        let mut new = Capsule::new(
            &template.project,
            format!("{}", template.name),
            &user,
            &db,
        ).await.unwrap();

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
                    .map_err(|_| Error(Status::InternalServerError)).unwrap();

                loop {
                    let next = iter
                        .next_entry()
                        .await
                        .map_err(|_| Error(Status::InternalServerError)).unwrap();

                    let next = match next {
                        Some(x) => x,
                        None => break,
                    };

                    let path = next.path();
                    let file_name = path.file_name().ok_or(Error(Status::InternalServerError)).unwrap();

                    copy(orig.join(&file_name), dest.join(&file_name))
                        .await
                        .map_err(|_| Error(Status::InternalServerError)).unwrap();
                    }
            }
        }

        let orig = config.data_path.join(&format!("{}/output.mp4", template.id));
        let dest = config.data_path.join(&format!("{}/output.mp4", new.id));

        if orig.is_file() {
            copy(orig, dest)
                .await
                .map_err(|_| Error(Status::InternalServerError)).unwrap();
        }

        new.set_changed();
        new.save(&db).await.unwrap();

        Answer::create(&assignment, &new).save(&db).await.unwrap();
    }

    Ok(())
}
