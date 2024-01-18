//! This module contains everything that manage the capsule in the database.

use std::collections::HashSet;
use std::default::Default;
use std::path::{Path, PathBuf};

use sha256::digest;

use tokio::fs::{read_dir, remove_file};

use chrono::{NaiveDateTime, Utc};

use ergol::prelude::*;
use ergol::tokio_postgres::types::Json;

use uuid::Uuid;

use serde::{Deserialize, Serialize};

use rocket::http::Status;
use rocket::serde::json::{json, Value};

use crate::db::task_status::{self, TaskStatus};
use crate::db::user::User;
use crate::s3::S3;
use crate::websockets::Notifier;
use crate::{Db, Error, Result, HARSH};

/// The different roles a user can have for a capsule.
#[derive(Debug, Copy, Clone, PgEnum, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "snake_case")]
pub enum Role {
    /// The user has read access to the capsule.
    Read,

    /// The user has write access to the capsule.
    Write,

    /// The user owns the capsule.
    Owner,
}

/// A slide with its prompt.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Slide {
    /// The uuid of the file.
    pub uuid: Uuid,

    /// The uuid of the extra resource if any.
    pub extra: Option<Uuid>,

    /// The prompt associated to the slide.
    pub prompt: String,
}

impl Slide {
    /// Converts the slide to a json format.
    pub async fn to_json(&self, capsule_id: i32, s3: Option<&S3>) -> Result<Value> {
        if let Some(s3) = s3 {
            let key = format!("{}/assets/{}.webp", capsule_id, self.uuid);

            let extra_key = self
                .extra
                .map(|e| format!("{}/assets/{}.mp4", capsule_id, e));

            let extra_presign = if let Some(key) = extra_key {
                Some(s3.get_object_presign(&key).await?)
            } else {
                None
            };

            Ok(json!({
                "uuid": self.uuid,
                "extra": self.extra,
                "prompt": self.prompt,
                "presign": s3.get_object_presign(&key).await?,
                "extra_presign": extra_presign,
            }))
        } else {
            Ok(json!(self))
        }
    }
}

/// The anchor of the webcam.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Anchor {
    /// The top left corner.
    TopLeft,

    /// The top right corner.
    TopRight,

    /// The bottom left corner.
    BottomLeft,

    /// The bottom right corner.
    BottomRight,
}

impl Default for Anchor {
    fn default() -> Anchor {
        Anchor::BottomLeft
    }
}

impl Anchor {
    /// Returns true if the anchor is top.
    pub fn is_top(self) -> bool {
        match self {
            Anchor::TopLeft | Anchor::TopRight => true,
            _ => false,
        }
    }

    /// Returns true if the anchor is left.
    pub fn is_left(self) -> bool {
        match self {
            Anchor::TopLeft | Anchor::BottomLeft => true,
            _ => false,
        }
    }
}

/// The webcam settings for a gos.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
#[serde(tag = "type")]
pub enum WebcamSettings {
    /// The webcam is disabled.
    Disabled,

    /// The webcam is in fullscreen mode.
    Fullscreen {
        /// The opacity of the webcam.
        opacity: f32,

        /// Keying color
        keycolor: Option<String>,
    },

    /// The webcam is at a corner of the screen.
    Pip {
        /// The corner to which the webcam is attached.
        anchor: Anchor,

        /// The opacity of the webcam, between 0 and 1.
        opacity: f32,

        /// The offset from the corner in pixels.
        position: (i32, i32),

        /// The size of the webcam.
        size: (i32, i32),

        /// Keying color
        keycolor: Option<String>,
    },
}

impl Default for WebcamSettings {
    fn default() -> WebcamSettings {
        WebcamSettings::Pip {
            anchor: Anchor::default(),
            size: (533, 400),
            position: (4, 4),
            opacity: 1.0,
            keycolor: None,
        }
    }
}

/// The sound track for a capsule.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct SoundTrack {
    /// The uuid of the file.
    pub uuid: Uuid,

    /// The name of the file.
    pub name: String,

    /// The volume of the sound track.
    pub volume: f32,
}

/// A record, with an uuid, a resolution and a duration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Record {
    /// The uuid of the record.
    pub uuid: Uuid,

    /// The uuid of the pointer of the record.
    pub pointer_uuid: Option<Uuid>,

    /// The size of the record, if it contains video.
    pub size: Option<(u32, u32)>,
}

impl Record {
    /// Returns a JSON representation of the record.
    pub async fn to_json(&self, capsule_id: i32, s3: Option<&S3>) -> Result<Value> {
        if let Some(s3) = s3 {
            let record_key = format!("{}/assets/{}.webm", capsule_id, self.uuid);
            let record_presign = s3.get_object_presign(&record_key).await?;
            let miniature_key = format!("{}/assets/{}.webp", capsule_id, self.uuid);
            let miniature_presign = s3.get_object_presign(&miniature_key).await?;

            let pointer_presign = if let Some(uuid) = self.pointer_uuid {
                let pointer_key = format!("{}/assets/{}.webm", capsule_id, uuid);
                Some(s3.get_object_presign(&pointer_key).await?)
            } else {
                None
            };

            Ok(json!({
                "uuid": self.uuid,
                "pointer_uuid": self.pointer_uuid,
                "presign": record_presign,
                "pointer_presign": pointer_presign,
                "size": self.size,
                "miniature_presign": miniature_presign,
            }))
        } else {
            Ok(json!(self))
        }
    }
}

/// The type of a record event.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EventType {
    /// The record started
    Start,

    /// Go to the next slide.
    NextSlide,

    /// Go to the previous slide.
    PreviousSlide,

    /// Go to the next sentence.
    NextSentence,

    /// Start to play extra media.
    Play,

    /// Pauses the extra media.
    Pause,

    /// Seeks at a certain position in the extra media.
    Seek,

    /// Stop the extra media.
    Stop,

    /// The record ended.
    End,
}

/// A record event.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct Event {
    /// The type of the event.
    pub ty: EventType,

    /// The time of the event in ms.
    pub time: i32,

    /// The extra time of the event if there is such a time.
    #[serde(default)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub extra_time: Option<i32>,
}

/// Options for audio/video fade in and fade out
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Fade {
    /// duration of video fade in
    vfadein: Option<i32>,

    /// duration of video fade out
    vfadeout: Option<i32>,

    /// duration of audio fade in
    afadein: Option<i32>,

    /// duration of audio fade out
    afadeout: Option<i32>,
}

impl Fade {
    /// Returns the default fade, which is no fade at all.
    pub fn none() -> Fade {
        Fade {
            vfadein: None,
            vfadeout: None,
            afadein: None,
            afadeout: None,
        }
    }
}

impl Default for Fade {
    fn default() -> Fade {
        Fade::none()
    }
}

/// The different pieces of information that we collect about a gos.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Gos {
    /// The path to the video recorded
    pub record: Option<Record>,

    /// The ids of the slides of the gos.
    pub slides: Vec<Slide>,

    /// The milliseconds where slides transition.
    pub events: Vec<Event>,

    /// The webcam settings of the gos.
    pub webcam_settings: Option<WebcamSettings>,

    /// Video/audio fade options
    #[serde(default)]
    pub fade: Fade,

    /// Produced hash.
    #[serde(default)]
    pub produced_hash: Option<String>,

    /// Production status.
    #[serde(default = "task_status::idle")]
    pub produced: TaskStatus,
}

impl Gos {
    /// Creates a new empty gos.
    pub fn new() -> Gos {
        Gos {
            record: None,
            slides: vec![],
            events: vec![],
            webcam_settings: None,
            fade: Fade::none(),
            produced_hash: None,
            produced: TaskStatus::Idle,
        }
    }

    /// Converts the gos into a JSON.
    pub async fn to_json(&self, capsule_id: i32, s3: Option<&S3>) -> Result<Value> {
        let record = if let Some(record) = &self.record {
            record.to_json(capsule_id, s3).await?
        } else {
            json!(null)
        };

        let slides = if let Some(s3) = s3 {
            let mut out = vec![];
            for slide in &self.slides {
                out.push(slide.to_json(capsule_id, Some(s3)).await?);
            }
            json!(out)
        } else {
            json!(self.slides)
        };

        let produced_presign = match (s3, self.produced_hash.as_ref()) {
            (Some(s3), Some(hash)) => {
                let key = format!("{}/produced/{}.mp4", capsule_id, hash);
                Some(s3.get_object_presign(&key).await?)
            }
            _ => None,
        };

        Ok(json!({
            "record": record,
            "slides": slides,
            "events": self.events,
            "webcam_settings": self.webcam_settings,
            "fade": self.fade,
            "produced_hash": self.produced_hash,
            "produced_presign": produced_presign,
            "produced": self.produced,
        }))
    }
}

/// Privacy settings for a video.
#[derive(PgEnum, Serialize, Deserialize, Debug, PartialEq, Eq, Copy, Clone)]
#[serde(rename_all = "snake_case")]
pub enum Privacy {
    /// Public video.
    Public,

    /// Unlisted video.
    Unlisted,

    /// Private video.
    Private,
}

/// A video capsule.
#[ergol]
#[derive(Clone)]
pub struct Capsule {
    /// The id of the capsule.
    #[id]
    pub id: i32,

    /// The project name.
    pub project: String,

    /// The name of the capsule.
    pub name: String,

    /// The task status of the video upload step.
    pub video_uploaded: TaskStatus,

    /// The pid of video upload transcode if any.
    pub video_uploaded_pid: Option<i32>,

    /// The task status of the edition step.
    pub produced: TaskStatus,

    /// The pid of the production task if any.
    pub production_pid: Option<i32>,

    /// The task status of the publication step.
    pub published: TaskStatus,

    /// The pid of the publication task if any.
    pub publication_pid: Option<i32>,

    /// Whether the video is public, unlisted, or private.
    pub privacy: Privacy,

    /// Whether the prompt should be use as subtitles or not.
    pub prompt_subtitles: bool,

    /// The structure of the capsule.
    pub structure: Json<Vec<Gos>>,

    /// The default webcam settings.
    pub webcam_settings: Json<WebcamSettings>,

    /// The last time the capsule was modified.
    pub last_modified: NaiveDateTime,

    /// Capsule disk usage (in MB)
    pub disk_usage: i32,

    /// duration of produced video in ms
    pub duration_ms: i32,

    /// The sound track of the capsule.
    pub sound_track: Option<Json<SoundTrack>>,

    /// The user that has rights on the capsule.
    #[many_to_many(capsules, Role)]
    pub users: User,

    /// Capsule produced hash.
    pub produced_hash: Option<String>,
}

impl Capsule {
    /// Creates a new capsule.
    pub async fn new<P: Into<String>, Q: Into<String>>(
        project: P,
        name: Q,
        owner: &User,
        db: &Db,
    ) -> Result<Capsule> {
        let project = project.into();
        let name = name.into();

        let capsule = Capsule::create(
            project,
            name,
            TaskStatus::Idle,
            None,
            TaskStatus::Idle,
            None,
            TaskStatus::Idle,
            None,
            Privacy::Public,
            true,
            Json(vec![]),
            Json(WebcamSettings::default()),
            Utc::now().naive_utc(),
            0,
            0,
            None,
            None,
        )
        .save(&db)
        .await?;

        capsule.add_user(owner, Role::Owner, db).await?;

        Ok(capsule)
    }

    /// Sets the last modified to now.
    pub fn set_changed(&mut self) {
        self.last_modified = Utc::now().naive_utc();
    }

    /// Returns a json representation of the capsule.
    pub async fn to_json(&self, role: Role, db: &Db, s3: Option<&S3>) -> Result<Value> {
        let users = self
            .users(&db)
            .await?
            .into_iter()
            .map(|(x, role)| {
                json!({
                    "username": x.username,
                    "role": role,
                })
            })
            .collect::<Vec<_>>();

        let output_presign = match (s3, self.produced) {
            (Some(s3), TaskStatus::Done) => {
                json!(
                    s3.get_object_presign(&format!("{}/produced/capsule.mp4", self.id))
                        .await?
                )
            }
            _ => {
                json!(null)
            }
        };

        let sound_track_presign = match (s3, self.sound_track.as_ref()) {
            (Some(s3), Some(sound_track)) => {
                json!(
                    s3.get_object_presign(&format!(
                        "{}/assets/{}.m4a",
                        self.id, sound_track.0.uuid
                    ))
                    .await?
                )
            }
            _ => json!(null),
        };

        Ok(json!({
            "id": HARSH.encode(self.id),
            "name": self.name,
            "project": self.project,
            "role": role,
            "video_uploaded": self.video_uploaded,
            "produced": self.produced,
            "produced_hash": self.produced_hash,
            "published": self.published,
            "privacy": self.privacy,
            "structure": if let Some(s3) = s3 {
                {
                    let mut out = vec![];
                    for gos in &self.structure.0 {
                        out.push(gos.to_json(self.id, Some(s3)).await?);
                    }
                    json!(out)
                }
            } else {
                json!(self.structure.0)

            },
            "webcam_settings": self.webcam_settings.0,
            "last_modified": self.last_modified.timestamp(),
            "users": users,
            "prompt_subtitles": self.prompt_subtitles,
            "disk_usage": self.disk_usage,
            "duration_ms": self.duration_ms,
            "sound_track": self.sound_track.as_ref().map(|x| &x.0),
            "output_presign": output_presign,
            "sound_track_presign": sound_track_presign,
        }))
    }

    /// Notify the users that a capsule has been produced.
    pub async fn notify_capsule_production(
        &self,
        id: &str,
        db: &Db,
        sock: &Notifier,
    ) -> Result<()> {
        let text = json!({
            "type": "capsule_production_finished",
            "id": id,
        });

        for (user, _) in self.users(&db).await? {
            sock.write_message(user.id, &text).await?;
        }

        Ok(())
    }

    /// Notify the users that a gos has been produced.
    pub async fn notify_gos_production(
        &self,
        id: &str,
        gos_id: &i32,
        db: &Db,
        sock: &Notifier,
    ) -> Result<()> {
        let text = json!({
            "type": "gos_production_finished",
            "id": id,
            "gos_id": gos_id,
        });

        for (user, _) in self.users(&db).await? {
            sock.write_message(user.id, &text).await?;
        }

        Ok(())
    }

    /// Notify the users that a capsule has been publicated.
    pub async fn notify_publication(&self, id: &str, db: &Db, sock: &Notifier) -> Result<()> {
        let text = json!({
            "type": "capsule_publication_finished",
            "id": id,
        });

        for (user, _) in self.users(&db).await? {
            sock.write_message(user.id, &text).await?;
        }

        Ok(())
    }

    /// Notify the users that a capsule has been publicated.
    pub async fn notify_video_upload(
        &self,
        slide_id: &str,
        capsule_id: &str,
        db: &Db,
        sock: &Notifier,
    ) -> Result<()> {
        let text = json!({
            "type": "video_upload_finished",
            "id": capsule_id,
            "slide_id": slide_id,
        });

        for (user, _) in self.users(&db).await? {
            sock.write_message(user.id, &text).await?;
        }

        Ok(())
    }

    /// Notify the users that the capsule production is progressing.
    pub async fn notify_capsule_production_progress(
        &self,
        id: &str,
        msg: &str,
        db: &Db,
        sock: &Notifier,
    ) -> Result<()> {
        let text = json!({
            "type": "capsule_production_progress",
            "msg": msg.parse::<f32>().map_err(|_|Error(Status::InternalServerError))?,
            "id": id,
        });

        for (user, _) in self.users(&db).await? {
            sock.write_message(user.id, &text).await?;
        }

        Ok(())
    }

    /// Notify the users that the gos production is progressing.
    pub async fn notify_gos_production_progress(
        &self,
        id: &str,
        gos_id: &i32,
        msg: &str,
        db: &Db,
        sock: &Notifier,
    ) -> Result<()> {
        let text = json!({
            "type": "gos_production_progress",
            "msg": msg.parse::<f32>().map_err(|_|Error(Status::InternalServerError))?,
            "id": id,
            "gos_id": gos_id,
        });

        for (user, _) in self.users(&db).await? {
            sock.write_message(user.id, &text).await?;
        }

        Ok(())
    }

    /// Notify the users that a capsule has been produced.
    pub async fn notify_publication_progress(
        &self,
        id: &str,
        msg: &str,
        db: &Db,
        sock: &Notifier,
    ) -> Result<()> {
        let text = json!({
            "type": "capsule_publication_progress",
            "msg": msg.parse::<f32>().map_err(|_|Error(Status::InternalServerError))?,
            "id": id,
        });

        for (user, _) in self.users(&db).await? {
            sock.write_message(user.id, &text).await?;
        }

        Ok(())
    }

    /// Notify the users that a capsule in under production.
    pub async fn notify_video_upload_progress(
        &self,
        slide_id: &str,
        capsule_id: &str,
        msg: &str,
        db: &Db,
        sock: &Notifier,
    ) -> Result<()> {
        let text = json!({
            "type": "video_upload_progress",
            "msg": msg.parse::<f32>().map_err(|_|Error(Status::InternalServerError))?,
            "id": capsule_id,
            "slide_id": slide_id,
        });

        for (user, _) in self.users(&db).await? {
            sock.write_message(user.id, &text).await?;
        }

        Ok(())
    }

    /// Notify the users that the capsule has been changed.
    pub async fn notify_change(&self, db: &Db, sock: &Notifier, s3: Option<&S3>) -> Result<()> {
        let mut json = self.to_json(Role::Read, &db, s3).await?;
        json["type"] = json!("capsule_changed");

        for (user, role) in self.users(&db).await? {
            json["role"] = json!(role);

            sock.write_message(user.id, &json).await?;
        }

        Ok(())
    }

    /// Retrieves the owner of a capsule.
    pub async fn owner(&self, db: &Db) -> Result<User> {
        for (user, role) in self.users(db).await? {
            if role == Role::Owner {
                return Ok(user);
            }
        }

        Err(Error(Status::NotFound))
    }

    /// Removes the useless files of the capsule.
    pub async fn garbage_collect(&self, data_path: &Path) -> Result<()> {
        // Traverse structure and find things to keep
        let mut to_keep = HashSet::new();

        if let Some(track) = self.sound_track.as_ref() {
            to_keep.insert(data_path.join(format!("{}/assets/{}.m4a", self.id, track.0.uuid)));
        }

        for gos in &self.structure.0 {
            if let Some(record) = gos.record.as_ref() {
                to_keep.insert(data_path.join(format!("{}/assets/{}.webm", self.id, record.uuid)));
                to_keep.insert(data_path.join(format!("{}/assets/{}.webp", self.id, record.uuid)));

                if let Some(pointer) = record.pointer_uuid {
                    to_keep.insert(data_path.join(format!("{}/assets/{}.webm", self.id, pointer)));
                }
            }

            for slide in &gos.slides {
                to_keep.insert(data_path.join(format!("{}/assets/{}.webp", self.id, slide.uuid)));

                if let Some(extra) = slide.extra.as_ref() {
                    to_keep.insert(data_path.join(format!("{}/assets/{}.mp4", self.id, extra)));
                }
            }
        }

        // Before garbage collecting, we check if there is a extra resource being transcoded.
        // If there is, we should avoid deleting files without extension, because some of them
        // might be being transcoded.
        let remove_extensionless = self.video_uploaded != TaskStatus::Running;

        // List everything that exists
        let mut exist = HashSet::new();
        let mut iter = read_dir(data_path.join(format!("{}/assets/", self.id))).await?;
        while let Some(entry) = iter.next_entry().await? {
            exist.insert(entry.path());
        }

        // The difference between the two sets are the objects to remove
        let to_remove = exist.difference(&to_keep);

        // Delete everything
        for path in to_remove {
            if remove_extensionless || path.extension().is_some() {
                remove_file(path).await?;
            }
        }

        Ok(())
    }

    /// Removes the useless objects from the S3 storage.
    pub async fn garbage_collect_s3(&self, s3: &S3) -> Result<()> {
        // Traverse structure and find things to keep
        let mut to_keep = HashSet::new();

        if let Some(track) = self.sound_track.as_ref() {
            to_keep.insert(format!("{}/assets/{}.m4a", self.id, track.0.uuid));
        }

        for gos in &self.structure.0 {
            if let Some(record) = gos.record.as_ref() {
                to_keep.insert(format!("{}/assets/{}.webm", self.id, record.uuid));
                to_keep.insert(format!("{}/assets/{}.webp", self.id, record.uuid));

                if let Some(pointer) = record.pointer_uuid {
                    to_keep.insert(format!("{}/assets/{}.webm", self.id, pointer));
                }
            }

            for slide in &gos.slides {
                to_keep.insert(format!("{}/assets/{}.webp", self.id, slide.uuid));

                if let Some(extra) = slide.extra.as_ref() {
                    to_keep.insert(format!("{}/assets/{}.mp4", self.id, extra));
                }
            }
        }

        // Before garbage collecting, we check if there is a extra resource being transcoded.
        // If there is, we should avoid deleting files without extension, because some of them
        // might be being transcoded.
        let remove_extensionless = self.video_uploaded != TaskStatus::Running;

        // List everything that exists
        let mut exist = HashSet::new();
        let dir = s3.read_dir(&format!("{}/assets/", self.id)).await?;

        for object in dir.contents().ok_or(Error(Status::InternalServerError))? {
            let key = object.key().ok_or(Error(Status::InternalServerError))?;
            exist.insert(key.to_string());
        }

        // The difference between the two sets are the objects to remove
        let to_remove = exist.difference(&to_keep);

        // Delete everything
        for key in to_remove {
            if remove_extensionless || PathBuf::from(key).extension().is_some() {
                s3.remove(key).await?;
            }
        }

        Ok(())
    }

    /// Returns the information of the capsule to send to popy.
    pub fn popy(&self) -> PopyCapsule {
        let mut clone = self.clone();

        for gos in &mut clone.structure.0 {
            if gos.webcam_settings.is_none() {
                gos.webcam_settings = Some(clone.webcam_settings.0.clone());
            }

            gos.produced = TaskStatus::Idle;
        }

        PopyCapsule {
            structure: clone.structure.0,
            soundtrack: clone.sound_track.as_ref().map(|x| x.0.clone()),
            produced_hash: clone.produced_hash,
        }
    }
}

/// Util type to help us communicate with popy.
#[derive(Serialize)]
pub struct PopyCapsule {
    /// The structure of the capsule as popy expects it.
    structure: Vec<Gos>,

    /// The sound track of the capsule as popy expects it.
    soundtrack: Option<SoundTrack>,

    /// The produced hash of the capsule.
    produced_hash: Option<String>,
}

impl PopyCapsule {
    /// Returns the JSON representation of the popy info as a string.
    pub fn to_string(&self) -> String {
        json!(self).to_string()
    }

    /// Refreshes and returns the hash of the specified gos.
    pub fn refresh_gos_hash(&mut self, id: usize) -> Option<String> {
        let mut json = json!(self.structure.get(id)?);
        json["produced_hash"] = json!(null);
        let hash = digest(json.to_string());
        self.structure.get_mut(id)?.produced_hash = Some(hash.clone());
        Some(hash)
    }

    /// Refreshes and returns the hash of the capsule.
    pub fn refresh_hash(&mut self) -> String {
        let mut json = json!(self);
        json["produced_hash"] = json!(null);
        let hash = digest(json.to_string());
        self.produced_hash = Some(hash.clone());
        hash
    }
}
