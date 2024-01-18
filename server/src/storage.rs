//! This module helps us deal with storage.

use std::path::PathBuf;

use crate::s3::S3;

/// A generic object that helps us save files.
pub enum Storage {
    /// Files will be saved and read through an object storage server.
    S3(S3),

    /// Files are saved on a local disk.
    Disk(PathBuf),
}

impl Storage {
    /// Returns true if the storage is an object storage.
    pub fn is_s3(&self) -> bool {
        match self {
            Storage::S3(_) => true,
            _ => false,
        }
    }

    /// Returns true if the storage is on the local disk.
    pub fn is_disk(&self) -> bool {
        match self {
            Storage::Disk(_) => true,
            _ => false,
        }
    }

    /// Returns a ref to the s3 if s3.
    pub fn s3(&self) -> Option<&S3> {
        match self {
            Storage::S3(s3) => Some(s3),
            _ => None,
        }
    }
}
