//! This module contains the struct useful for the configuration.

use std::path::PathBuf;

use compile_time_run::run_command_str;

use crate::mailer::Mailer;

/// The config of the server.
pub struct Config {
    /// The path where the data should be saved.
    pub data_path: PathBuf,

    /// The path where the log should be saved.
    pub log_path: PathBuf,

    /// The path where the videos will be published.
    pub videos_path: PathBuf,

    /// The root of the video streaming server.
    pub video_root: String,

    /// Whether the server is in beta mode or not.
    pub beta: bool,

    /// Whether the background matting is enabled or not.
    pub matting_enabled: bool,

    /// The mailer, if any.
    pub mailer: Option<Mailer>,

    /// The version of the crate.
    pub version: &'static str,

    /// The hash of the git commit.
    pub commit: &'static str,
}

impl Config {
    /// Creates the config struct from rocket's configuration.
    pub fn from(config: &rocket::Config) -> Config {
        let data_path = config
            .get_string("data_path")
            .unwrap_or_else(|_| String::from("data"));

        let log_path = config
            .get_string("log_path")
            .unwrap_or_else(|_| String::from("log.txt"));

        let videos_path = config
            .get_string("videos_path")
            .unwrap_or_else(|_| String::from("videos"));

        let video_root = config
            .get_string("video_root")
            .unwrap_or_else(|_| String::from("/"));

        let beta = config.get_bool("beta").unwrap_or(false);
        let matting_enabled = config.get_bool("matting_enabled").unwrap_or(false);

        Config {
            data_path: PathBuf::from(data_path),
            log_path: PathBuf::from(log_path),
            videos_path: PathBuf::from(videos_path),
            video_root,
            beta,
            matting_enabled,
            mailer: Mailer::from_config(config),
            version: env!("CARGO_PKG_VERSION"),
            commit: run_command_str!("git", "rev-parse", "--short", "HEAD"),
        }
    }
}
