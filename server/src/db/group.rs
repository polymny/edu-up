//! This module helps us deal with students groups.

use serde::{Deserialize, Serialize};

use ergol::prelude::*;

use rocket::serde::json::{json, Value};

use crate::config::Config;
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
        let participants = participants.into_iter().map(|(user, role)| {
            json!({
                "username": user.username,
                "email": user.email,
                "role": role,
            })
        }).collect::<Vec<_>>();

        Ok(json!({
            "name": self.name,
            "participants": participants,
        }))
    }
}

/// Creates some users in the db.
#[rustfmt::skip]
pub async fn populate_db(db: &Db, config: &Config) -> Result<()> {
    let polymny = User::get_by_username("polymny", &db).await.unwrap().unwrap();

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

    Ok(())
}