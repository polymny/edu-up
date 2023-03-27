//! This module helps us deal with students groups.

use serde::{Deserialize, Serialize};

use ergol::prelude::*;

use crate::db::user::User;

/// The different levels of authorization a user can have.
#[derive(Debug, Copy, Clone, PgEnum, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
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
