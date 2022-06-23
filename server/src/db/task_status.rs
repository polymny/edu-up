//! This module contains the task status enum, representing the different steps where a task can
//! be.

use ergol::prelude::*;

use serde::{Deserialize, Serialize};

/// The different states in which a task can be.
#[derive(PgEnum, Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum TaskStatus {
    /// The task should not be run.
    Disabled,

    /// Waiting to start.
    Idle,

    /// Running, but not finished.
    Running,

    /// Finished.
    Done,
}
