//! This module contains the route to watch videos.

use std::io::Cursor;
use std::path::PathBuf;

use tokio::io::{AsyncBufReadExt, BufReader};

use rocket::http::{ContentType, Status};
use rocket::request::Request;
use rocket::response::{self, Responder, Response};
use rocket::State as S;

use crate::config::Config;
use crate::db::capsule::{Capsule, Privacy, Role};
use crate::db::task_status::TaskStatus;
use crate::db::user::Plan;
use crate::db::user::User;
use crate::routes::{Cors, PartialContent, PartialContentResponse};
use crate::storage::Storage;
use crate::templates::video_html;
use crate::{Db, Error, HashId, Result};

/// A custom response type for allowing iframes on the watch route.
pub struct CustomResponse(String);

impl<'r, 'o: 'r> Responder<'r, 'o> for CustomResponse {
    fn respond_to(self, _request: &'r Request<'_>) -> response::Result<'o> {
        Ok(Response::build()
            .sized_body(self.0.len(), Cursor::new(self.0))
            .header(ContentType::HTML)
            .finalize())
    }
}

/// The route that serves HTML to watch videos.
#[get("/v/<capsule_id>", rank = 1)]
pub async fn watch<'a>(
    config: &S<Config>,
    user: Option<User>,
    capsule_id: HashId,
    db: Db,
    storage: &S<Storage>,
) -> Result<CustomResponse> {
    let capsule = Capsule::get_by_id(*capsule_id as i32, &db)
        .await?
        .ok_or(Error(Status::NotFound))?;

    if capsule.published != TaskStatus::Done {
        return Err(Error(Status::NotFound));
    }

    // Check authorization.
    if capsule.privacy == Privacy::Private {
        match user {
            None => return Err(Error(Status::Unauthorized)),
            Some(user) => {
                user.get_capsule_with_permission(*capsule_id, Role::Read, &db)
                    .await?;
            }
        }
    }

    // Check if video is on current host or other host.

    // If there is another host
    let mut host = None;

    if let Some(other_host) = &config.other_host {
        // Look of the owner of the capsule
        let owner = capsule.owner(&db).await?;
        // If premium state doesn't match the owner plan
        if config.premium_only != (owner.plan >= Plan::PremiumLvl1) {
            // Redirect to the other host
            host = Some(other_host.to_string());
        }
    }

    let miniatures_url = if let (Some(s3), None) = (storage.inner().s3(), &host) {
        let mut miniatures_url = vec![];
        // Generate presign for miniatures
        for i in 0..=100 {
            miniatures_url.push(
                s3.get_object_presign(&format!(
                    "{}/published/miniature-{:0>3}.png",
                    *capsule_id, i
                ))
                .await?,
            );
        }
        Some(miniatures_url)
    } else {
        None
    };

    Ok(CustomResponse(video_html(
        &format!(
            "{}/v/{}/manifest.m3u8",
            host.unwrap_or_else(|| String::new()),
            capsule_id.hash()
        ),
        miniatures_url,
    )))
}

/// Generates the manifest for an HLS encoded video stored on S3.
///
/// This route should be mounted only if S3 is used as a storage system.
#[get("/v/<capsule_id>/manifest.m3u8", rank = 1)]
pub async fn manifest(user: Option<User>, capsule_id: HashId, db: Db) -> Result<&'static str> {
    let capsule = Capsule::get_by_id(*capsule_id as i32, &db)
        .await?
        .ok_or(Error(Status::NotFound))?;

    if capsule.published != TaskStatus::Done {
        return Err(Error(Status::NotFound));
    }

    // Check authorization.
    if capsule.privacy == Privacy::Private {
        match user {
            None => return Err(Error(Status::Unauthorized)),
            Some(user) => {
                user.get_capsule_with_permission(*capsule_id, Role::Read, &db)
                    .await?;
            }
        }
    }

    // Generate manifest
    Ok(r#"#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
360p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1400000,RESOLUTION=842x480
480p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720
720p.m3u8"#)
}

/// An enum representing the different resolutions available for an HLS encoded video.
pub enum Resolution {
    /// 360p.
    R360p,

    /// 480p.
    R480p,

    /// 720p.
    R720p,
}

impl Resolution {
    /// Retrieves the resolution from the m3u8 file name.
    pub fn from_m3u8_name(s: &str) -> Option<Resolution> {
        match s {
            "360p.m3u8" => Some(Resolution::R360p),
            "480p.m3u8" => Some(Resolution::R480p),
            "720p.m3u8" => Some(Resolution::R720p),
            _ => None,
        }
    }

    /// Returns the video size of the resolution.
    pub fn size(&self) -> (i32, i32) {
        match self {
            Resolution::R360p => (640, 360),
            Resolution::R480p => (842, 480),
            Resolution::R720p => (1280, 720),
        }
    }

    /// Returns the bitrate of the resolution.
    pub fn bitrate(&self) -> i32 {
        match self {
            Resolution::R360p => 800000,
            Resolution::R480p => 1400000,
            Resolution::R720p => 2800000,
        }
    }

    /// Returns all the resolutions, in order.
    pub fn all() -> [Resolution; 3] {
        [Resolution::R360p, Resolution::R480p, Resolution::R720p]
    }
}

/// Generates the resolution specific manifest for an HLS encoded video stored on S3.
///
/// This route should be mounted only if S3 is used as a storage system.
#[get("/v/<capsule_id>/<res>", rank = 2)]
pub async fn resolution_manifest(
    user: Option<User>,
    capsule_id: HashId,
    res: &str,
    db: Db,
    storage: &S<Storage>,
) -> Result<String> {
    Resolution::from_m3u8_name(res).ok_or(Error(Status::NotFound))?;

    let capsule = Capsule::get_by_id(*capsule_id as i32, &db)
        .await?
        .ok_or(Error(Status::NotFound))?;

    if capsule.published != TaskStatus::Done {
        return Err(Error(Status::NotFound));
    }

    // Check authorization.
    if capsule.privacy == Privacy::Private {
        match user {
            None => return Err(Error(Status::Unauthorized)),
            Some(user) => {
                user.get_capsule_with_permission(*capsule_id, Role::Read, &db)
                    .await?;
            }
        }
    }

    let s3 = storage.inner().s3().unwrap();

    // Fetch st from S3
    let original_manifest = s3
        .download(&format!("{}/published/{}", *capsule_id, res))
        .await?;

    let reader = BufReader::new(original_manifest.into_async_read());
    let mut lines = reader.lines();

    let mut response = String::new();

    loop {
        let line = match lines.next_line().await? {
            Some(line) => line,
            _ => break,
        };

        if !line.starts_with("#") {
            // line is a file path, compute presign for it
            response.push_str(
                &s3.get_object_presign(&format!("{}/published/{}", *capsule_id, line))
                    .await?,
            );
        } else {
            response.push_str(&line);
        }

        response.push('\n');
    }

    Ok(response)
}

/// The route that serves files inside published videos.
#[get("/v/<capsule_id>/<path..>", rank = 3)]
pub async fn watch_asset<'a>(
    user: Option<User>,
    capsule_id: HashId,
    path: PathBuf,
    config: &S<Config>,
    db: Db,
    partial_content: PartialContent,
) -> Cors<Result<PartialContentResponse<'a>>> {
    Cors::new(
        &Some("*".to_string()),
        watch_asset_aux(user, capsule_id, path, config, db, partial_content).await,
    )
}

/// Helper function to the route that serves files inside published videos.
///
/// Makes us able to easily wrap cors.
pub async fn watch_asset_aux<'a>(
    user: Option<User>,
    capsule_id: HashId,
    path: PathBuf,
    config: &S<Config>,
    db: Db,
    partial_content: PartialContent,
) -> Result<PartialContentResponse<'a>> {
    let capsule = Capsule::get_by_id(*capsule_id as i32, &db)
        .await?
        .ok_or(Error(Status::NotFound))?;

    if capsule.published != TaskStatus::Done {
        return Err(Error(Status::NotFound));
    }

    // Check authorization.
    if capsule.privacy == Privacy::Private {
        match user {
            None => return Err(Error(Status::Unauthorized)),
            Some(user) => {
                user.get_capsule_with_permission(*capsule_id, Role::Read, &db)
                    .await?;
            }
        }
    }

    partial_content
        .respond(
            config
                .data_path
                .join(format!("{}", *capsule_id))
                .join("published")
                .join(path),
        )
        .await
}

/// The route for the js file that contains elm-video.
#[get("/v/polymny-video-full.min.js")]
pub async fn polymny_video<'a>(
    partial_content: PartialContent,
) -> Result<PartialContentResponse<'a>> {
    partial_content
        .respond(PathBuf::from("dist").join("polymny-video-full.min.js"))
        .await
}
