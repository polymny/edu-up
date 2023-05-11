//! This module contains all the tables we need to register statistics about polymny usage.

use chrono::{NaiveDateTime, Utc};

use ergol::prelude::*;

use serde::{Deserialize, Serialize};

use rocket::http::Status;

use crate::{Db, Error, Result};

/// The different types a stat can have.
#[derive(PgEnum, Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum TaskStatType {
    /// A production of a capsule.
    Production,

    /// A publication of a capsule.
    Publication,
}

/// This table records all production and publication, as well as their start date and duration.
#[ergol]
pub struct TaskStat {
    /// The id of the stat.
    #[id]
    pub id: i32,

    /// The type of the task,
    pub ty: TaskStatType,

    /// The moment when the task was trigger.
    pub trigger: NaiveDateTime,

    /// The moment the task started.
    pub start: Option<NaiveDateTime>,

    /// The moment the task ended.
    pub end: Option<NaiveDateTime>,
}

impl TaskStat {
    /// Creates a new stat.
    pub async fn new(ty: TaskStatType, db: &Db) -> Result<TaskStat> {
        TaskStat::create(ty, Utc::now().naive_utc(), None, None)
            .save(&db)
            .await
            .map_err(|_| (Error(Status::InternalServerError)))
    }

    /// Sets the start time of a stat.
    pub async fn start(&mut self, db: &Db) -> Result<()> {
        self.start = Some(Utc::now().naive_utc());
        self.save(&db).await?;
        Ok(())
    }

    /// Sets the end time of a stat.
    pub async fn end(&mut self, db: &Db) -> Result<()> {
        self.end = Some(Utc::now().naive_utc());
        self.save(&db).await?;
        Ok(())
    }
}
