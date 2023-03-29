//! This module helps us deal with students groups.

use serde::{Deserialize, Serialize};

use ergol::prelude::*;
use ergol::tokio_postgres::types::Json as EJson;

use rocket::serde::json::{json, Value};

use tokio::fs::create_dir_all;

use crate::command::export_slides;
use crate::config::Config;
use crate::db::capsule::{Capsule, Fade, Gos, Slide};
use crate::db::user::User;
use crate::{Db, Result};

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

    /// The capsule that contains the subject of the assignment.
    #[many_to_one(assignments)]
    pub subject: Capsule,

    /// The capsule that will serve as a template for answers.
    #[many_to_one(answers)]
    pub answer: Capsule,

    /// The group of users associated with this assignment.
    #[many_to_one(assignments)]
    pub participants: Group,
}

impl Assignment {
    /// Creates a new criterion and adds it to the assignment.
    pub async fn add_criterion(&self, criterion: &str, db: &Db) -> Result<Criterion> {
        Ok(Criterion::create(self, criterion).save(&db).await?)
    }

    /// Returns a JSON value representing the assignment.
    pub async fn to_json(&self, db: &Db) -> Result<Value> {
        Ok(json!({
            "id": self.id,
            "subject": self.subject(&db).await?.id,
            "answer": self.answer(&db).await?.id,
            "participants": self.participants(&db).await?.participants(&db).await?.into_iter().map(|(user, role)| {
                json!({
                    "username": user.username,
                    "email": user.email,
                    "role": role,
                })
            }).collect::<Vec<_>>(),
            "criteria": self.criteria(&db).await?.into_iter().map(|x| x.to_json()).collect::<Vec<_>>(),
        }))
    }
}

/// A criterion for student evaluation.
#[ergol]
pub struct Criterion {
    /// The id of the criterion.
    #[id]
    pub id: i32,

    /// The correspoding assignment.
    #[many_to_one(criteria)]
    pub assignment: Assignment,

    /// The content of the criterion.
    pub description: String,
}

impl Criterion {
    /// Returns a JSON representation of the criterion.
    pub fn to_json(&self) -> Value {
        json!({
            "id": self.id,
            "description": self.description,
        })
    }
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
    let mut subject = Capsule::new("Mon projet", "Sujet", &polymny, &db).await?;

    let path = config
        .data_path
        .join(format!("{}", subject.id))
        .join("assets");

    create_dir_all(&path).await?;

    let gos = export_slides(&config, "example/slides.pdf", path, None)?
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
    subject.save(&db).await?;

    // Create the assignment
    let assignment = Assignment::create(&subject, &subject, &group1).save(&db).await?;
    assignment.add_criterion("Respect de la consigne", &db).await?;
    assignment.add_criterion("Clarté du discours", &db).await?;
    assignment.add_criterion("Structuration du propos", &db).await?;
    assignment.add_criterion("Débit", &db).await?;
    assignment.add_criterion("Gestuelle", &db).await?;

    let assignment = Assignment::get_by_id(assignment.id, &db).await?.unwrap();
    println!("{}", assignment.to_json(&db).await?);

    Ok(())
}
