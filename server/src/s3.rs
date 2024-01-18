//! This module contains everything that helps us deal with object storage.

use std::path::Path;

use serde::{Deserialize, Serialize};

use tokio::fs::read_dir;

use aws_types::region::Region;

use aws_credential_types::provider::SharedCredentialsProvider;
use aws_credential_types::Credentials;

use aws_sdk_s3::operation::list_objects_v2::ListObjectsV2Output;
use aws_sdk_s3::primitives::ByteStream;
use aws_sdk_s3::Client;

use rocket::http::ContentType;
use rocket::http::Status;

use crate::{Error, Result};

/// The configuration of the S3 bucket.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    /// S3 key.
    pub key_id: String,

    /// S3 secret key.
    pub secret: String,

    /// S3 endpoint.
    pub endpoint: String,

    /// S3 region.
    pub region: String,

    /// S3 bucket.
    pub bucket: String,
}

/// An object that helps us deal with object storage.
#[derive(Clone)]
pub struct S3 {
    /// The original config that was used.
    pub config: Config,

    /// The client that has been built.
    pub client: Client,
}

impl S3 {
    /// Creates a new S3 from the config.
    pub fn new(config: Config) -> S3 {
        let credentials = Credentials::from_keys(&config.key_id, &config.secret, None);
        let credentials_provider = SharedCredentialsProvider::new(credentials);

        let builder = aws_sdk_s3::Config::builder()
            .endpoint_url(config.endpoint.clone())
            .force_path_style(true)
            .credentials_provider(credentials_provider)
            .region(Region::new(config.region.clone()));

        let s3_config = builder.build();

        let client = Client::from_conf(s3_config);

        S3 { config, client }
    }

    /// Saves an object on the object storage.
    pub async fn upload<P: AsRef<Path>>(
        &self,
        source: P,
        dest: &str,
        mime: ContentType,
    ) -> Result<()> {
        let body = ByteStream::from_path(source)
            .await
            .map_err(|_| Error(Status::InternalServerError))?;

        self.client
            .put_object()
            .bucket(&self.config.bucket)
            .key(dest)
            .content_type(mime.to_string())
            .body(body)
            .send()
            .await
            .map_err(|_| Error(Status::InternalServerError))?;

        Ok(())
    }

    /// Uploads a whole directory on the object storage.
    pub async fn upload_dir<P: AsRef<Path>>(&self, source: P, dest: &str) -> Result<()> {
        let mut dir = read_dir(&source).await?;

        while let Some(entry) = dir.next_entry().await? {
            if let (Ok(ty), Some(name)) = (entry.file_type().await, entry.file_name().to_str()) {
                if ty.is_file() {
                    let content_type = entry
                        .path()
                        .extension()
                        .and_then(|x| x.to_str())
                        .and_then(ContentType::from_extension)
                        .unwrap_or(ContentType::Bytes);

                    self.upload(entry.path(), &format!("{}/{}", dest, name), content_type)
                        .await?;
                }
            }
        }

        Ok(())
    }

    /// Copy an object on the object storage.
    pub async fn copy(&self, source: &str, dest: &str) -> Result<()> {
        self.client
            .copy_object()
            .bucket(&self.config.bucket)
            .copy_source(&format!("{}/{}", self.config.bucket, source))
            .key(dest)
            .send()
            .await
            .map_err(|_| Error(Status::InternalServerError))?;

        Ok(())
    }

    /// Copy a directory on the object storage.
    pub async fn copy_dir(&self, source: &str, dest: &str) -> Result<()> {
        let dir = self.read_dir(source).await?;
        let dir = dir.contents().ok_or(Error(Status::InternalServerError))?;

        for file in dir {
            let source_key = file.key().ok_or(Error(Status::InternalServerError))?;
            let dest_key = source_key.replacen(source, dest, 1);

            self.client
                .copy_object()
                .bucket(&self.config.bucket)
                .copy_source(&format!("{}/{}", self.config.bucket, source_key))
                .key(dest_key)
                .send()
                .await
                .map_err(|_| Error(Status::InternalServerError))?;
        }

        Ok(())
    }

    /// Returns an URL that allows to get the object.
    pub async fn get_object_presign(&self, key: &str) -> Result<String> {
        let presign_config = aws_sdk_s3::presigning::PresigningConfig::builder()
            .expires_in(std::time::Duration::from_secs(3600))
            .build()
            .map_err(|_| Error(Status::InternalServerError))?;

        let p = self
            .client
            .get_object()
            .bucket(&self.config.bucket)
            .key(key)
            .presigned(presign_config)
            .await
            .map_err(|_| Error(Status::InternalServerError))?;

        Ok(p.uri().to_string())
    }

    /// Returns the content of the object.
    pub async fn download(&self, key: &str) -> Result<ByteStream> {
        self.client
            .get_object()
            .bucket(&self.config.bucket)
            .key(key)
            .send()
            .await
            .map(|x| x.body)
            .map_err(|_| Error(Status::InternalServerError))
    }

    /// Removes an object from s3.
    pub async fn remove(&self, key: &str) -> Result<()> {
        self.client
            .delete_object()
            .bucket(&self.config.bucket)
            .key(key)
            .send()
            .await
            .map(|_| ())
            .map_err(|_| Error(Status::InternalServerError))
    }

    /// Reads a "directory" from s3.
    ///
    /// There is no such concept as directory for s3, but since our keys are structured like paths,
    /// with `/` as separators, we can have a read_dir like function that lists the objects that
    /// starts with a specific prefix.
    pub async fn read_dir(&self, prefix: &str) -> Result<ListObjectsV2Output> {
        Ok(self
            .client
            .list_objects_v2()
            .bucket(&self.config.bucket)
            .prefix(prefix)
            .send()
            .await
            .map_err(|_| Error(Status::InternalServerError))?)
    }

    /// Removes a directory from s3.
    pub async fn remove_dir(&self, prefix: &str) -> Result<()> {
        if let Some(dir) = self.read_dir(prefix).await?.contents() {
            for object in dir {
                if let Some(key) = object.key() {
                    self.remove(key).await?;
                }
            }
        }

        Ok(())
    }
}
