//! This module helps us deal with students groups.

use futures::future::try_join_all;

use serde::{Deserialize, Serialize};

use ergol::prelude::*;
use ergol::tokio_postgres::types::Json as EJson;

use rocket::http::Status;
use rocket::serde::json::{json, Value};

use tokio::fs::create_dir_all;

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

        let assignments = self.assignments(db).await?;
        let assignments = assignments
            .iter()
            .map(|assignment| assignment.to_json(db))
            .collect::<Vec<_>>();
        let assignments = try_join_all(assignments).await?;

        Ok(json!({
            "id": self.id,
            "name": self.name,
            "participants": participants,
            "assignments": assignments
        }))
    }
}

/// The state of an assignment.
#[derive(Debug, Copy, Clone, PgEnum, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "lowercase")]
pub enum AssignmentState {
    /// The assignment creation is in progress.
    Preparation,

    /// The assignment creation is finished.
    Prepared,

    /// The students are working on the assignment.
    Working,

    /// The students or the teacher are evaluating the assignment.
    Evaluation,

    /// The assignment is finished.
    Finished,
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

    /// The state of the assignment.
    pub state: AssignmentState,
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
        let answers = self.answers(&db).await?;
        let answers = answers.iter().map(|x| x.to_json(db));
        let answers = futures::future::try_join_all(answers).await?;

        Ok(json!({
            "id": self.id,
            "subject": HARSH.encode(self.subject(&db).await?.id),
            "answer_template": HARSH.encode(self.answer_template(&db).await?.id),
            "group": self.group(&db).await?.id,
            "criteria": self.criteria.split("\n").collect::<Vec<_>>(),
            "state": self.state,
            "answers": answers,
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

    /// Whether the student has finished is answer or not.
    pub finished: bool,
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

    /// Creates a non finished answer.
    pub fn new(assignment: &Assignment, capsule: &Capsule) -> AnswerWithoutId {
        Answer::create(assignment, capsule, false)
    }

    /// JSON representation of the answer.
    pub async fn to_json(&self, db: &Db) -> Result<Value> {
        Ok(json!({
            "id": self.id,
            "capsule": HARSH.encode(self.capsule(db).await?.id),
            "finished": self.finished,
        }))
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
    use crate::db::user::Plan;

    // Find the admin (teacher)
    let mut polymny = User::get_by_username("polymny", &db).await.unwrap().unwrap();
    polymny.username = "tforgione".into();
    polymny.save(&db).await?;

    // Create a bunch of students
    let mut iguernon = User::new("iguernon","iguernon@example.com", "hashed", true, &None, &db, &config).await?;
    let mut tmarceau = User::new("tmarceau","tmarceau@example.com", "hashed", true, &None, &db, &config).await?;
    let mut cbabin = User::new("cbabin",  "cbabin@example.com", "hashed", true, &None, &db, &config).await?;
    let mut lgrignon = User::new("lgrignon","lgrignon@example.com", "hashed", true, &None, &db, &config).await?;
    let mut epaquin = User::new("epaquin", "epaquin@example.com", "hashed", true, &None, &db, &config).await?;
    let mut dsalmons = User::new("dsalmons","dsalmons@example.com", "hashed", true, &None, &db, &config).await?;
    let mut lsacre = User::new("lsacre",  "lsacre@example.com", "hashed", true, &None, &db, &config).await?;
    let mut ysalois = User::new("ysalois", "ysalois@example.com", "hashed", true, &None, &db, &config).await?;
    let mut rseguin = User::new("rseguin", "rseguin@example.com", "hashed", true, &None, &db, &config).await?;
    let mut xbrodeur = User::new("xbrodeur","xbrodeur@example.com", "hashed", true, &None, &db, &config).await?;

    iguernon.plan = Plan::PremiumLvl1; iguernon.save(&db).await?;
    tmarceau.plan = Plan::PremiumLvl1; tmarceau.save(&db).await?;
    cbabin.plan   = Plan::PremiumLvl1; cbabin.save(&db).await?;
    lgrignon.plan = Plan::PremiumLvl1; lgrignon.save(&db).await?;
    epaquin.plan  = Plan::PremiumLvl1; epaquin.save(&db).await?;
    dsalmons.plan = Plan::PremiumLvl1; dsalmons.save(&db).await?;
    lsacre.plan   = Plan::PremiumLvl1; lsacre.save(&db).await?;
    ysalois.plan  = Plan::PremiumLvl1; ysalois.save(&db).await?;
    rseguin.plan  = Plan::PremiumLvl1; rseguin.save(&db).await?;
    xbrodeur.plan = Plan::PremiumLvl1; xbrodeur.save(&db).await?;

    /*
    // Create a few groups
    let group1 = Group::create("Terminale 1").save(&db).await?;
    group1.add_participant(&polymny, ParticipantRole::Teacher, &db).await?;
    group1.add_participant(&iguernon, ParticipantRole::Student, &db).await?;
    group1.add_participant(&tmarceau, ParticipantRole::Student, &db).await?;
    group1.add_participant(&cbabin, ParticipantRole::Student, &db).await?;

    let group2 = Group::create("Terminale 2").save(&db).await?;
    group2.add_participant(&polymny, ParticipantRole::Teacher, &db).await?;
    group2.add_participant(&lgrignon, ParticipantRole::Student, &db).await?;
    group2.add_participant(&epaquin, ParticipantRole::Student, &db).await?;
    group2.add_participant(&dsalmons, ParticipantRole::Student, &db).await?;

    let group3 = Group::create("Première 1").save(&db).await?;
    group3.add_participant(&polymny, ParticipantRole::Teacher, &db).await?;
    group3.add_participant(&lsacre, ParticipantRole::Student, &db).await?;
    group3.add_participant(&ysalois, ParticipantRole::Student, &db).await?;
    group3.add_participant(&rseguin, ParticipantRole::Student, &db).await?;
    group3.add_participant(&xbrodeur, ParticipantRole::Student, &db).await?;

    // Create the subject of the assignment
    let mut subject = Capsule::new("Système 4 équations 4 inconnues", "Sujet", &polymny, &db).await?;

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

    // Create the template for the answer of the assignment
    let mut answer_template = Capsule::new("Système 4 équations 4 inconnues", "Réponse", &polymny, &db).await?;

    let path = config
        .data_path
        .join(format!("{}", answer_template.id))
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

    answer_template.structure = EJson(gos);
    answer_template.set_changed();
    answer_template.save(&db).await?;
    */

    Ok(())
}
