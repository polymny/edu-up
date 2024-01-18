//! This module helps us running commands.

use std::path::Path;
use std::process::{Command, Output};
use std::result::Result as StdResult;

use uuid::Uuid;

use rayon::prelude::*;

use rocket::http::Status;

use crate::config::Config;
use crate::{Error, Result};

/// Runs a specified command.
pub fn run_command(command: &Vec<&str>) -> Result<Output> {
    info!("Running command: {:#?}", command.join(" "));

    let child = Command::new(command[0]).args(&command[1..]).output();
    match &child {
        Err(e) => error!("Command failed: {}", e),
        Ok(o) if !o.status.success() => {
            error!(
                "Command failed with code {}:\n\nSTDOUT\n{}\n\nSTDERR\n{}\n\n",
                o.status,
                String::from_utf8(o.stdout.clone())
                    .unwrap_or_else(|_| String::from("Output was not utf8, couldn't read stdout")),
                String::from_utf8(o.stderr.clone())
                    .unwrap_or_else(|_| String::from("Output was not utf8, couldn't read stderr")),
            );

            return Err(Error(Status::InternalServerError));
        }
        _ => (),
    }

    child.map_err(|_| Error(Status::InternalServerError))
}

/// Runs a specified command.
pub fn run_command_with_output(command: &Vec<&str>) -> Result<Output> {
    info!("Running command: {:#?}", command.join(" "));
    let mut child = Command::new(command[0]);
    let child = child.args(&command[1..]);
    let child = child.spawn()?;

    let child = child.wait_with_output();

    match &child {
        Err(e) => error!("Command failed: {}", e),
        Ok(o) if !o.status.success() => {
            error!(
                "Command failed with code {}:\n\nSTDOUT\n{}\n\nSTDERR\n{}\n\n",
                o.status,
                String::from_utf8(o.stdout.clone())
                    .unwrap_or_else(|_| String::from("Output was not utf8, couldn't read stdout")),
                String::from_utf8(o.stderr.clone())
                    .unwrap_or_else(|_| String::from("Output was not utf8, couldn't read stderr")),
            );

            return Err(Error(Status::InternalServerError));
        }
        _ => (),
    }

    child.map_err(|_| Error(Status::InternalServerError))
}

/// Counts the pages of a PDF file.
pub fn count_pages<P: AsRef<Path>>(input: P) -> Result<u32> {
    let output = run_command(&vec![
        "qpdf",
        "--show-pages",
        input
            .as_ref()
            .to_str()
            .ok_or(Error(Status::InternalServerError))?,
    ])?;

    let mut count = 0;

    for line in std::str::from_utf8(&output.stdout)
        .map_err(|_| Error(Status::InternalServerError))?
        .lines()
    {
        if line.starts_with("page") {
            count += 1;
        }
    }

    Ok(count)
}

/// Exports all slides (or one) from pdf to webp.
pub fn export_slides<P: AsRef<Path>, Q: AsRef<Path> + Send + Sync>(
    config: &Config,
    input: P,
    output: Q,
    page: Option<i32>,
) -> Result<Vec<Uuid>> {
    let pdf_target_size = config.pdf_target_size.clone();
    let pdf_target_density = config.pdf_target_density.clone();
    match page {
        Some(x) => {
            let command_input_path = format!(
                "{}[{}]",
                input
                    .as_ref()
                    .to_str()
                    .ok_or(Error(Status::InternalServerError))?,
                x
            );
            let uuid = Uuid::new_v4();
            let command_output_path = format!(
                "{}/{}.webp",
                output
                    .as_ref()
                    .to_str()
                    .ok_or(Error(Status::InternalServerError))?,
                uuid
            );
            run_command(&vec![
                "../scripts/popy.py",
                "convert",
                "pdf2webp",
                "-i",
                &command_input_path,
                "-o",
                &command_output_path,
                "-d",
                &pdf_target_density.to_string(),
                "-s",
                &pdf_target_size.to_string(),
            ])?;

            Ok(vec![uuid])
        }

        None => {
            let vec: Vec<u32> = (0..count_pages(&input)?).collect();
            let vec_in = vec
                .iter()
                .map(|i| match input.as_ref().to_str() {
                    Some(o) => Ok(format!("{}[{}]", o, i)),
                    _ => Err(Error(Status::InternalServerError)),
                })
                .collect::<StdResult<Vec<_>, _>>()?;

            let result = vec_in
                .par_iter()
                .map(|filepath| {
                    let uuid = Uuid::new_v4();
                    let filepath_out = format!(
                        "{}/{}.webp",
                        output
                            .as_ref()
                            .to_str()
                            .ok_or(Error(Status::InternalServerError))?,
                        uuid
                    );
                    let _res = run_command(&vec![
                        "../scripts/popy.py",
                        "convert",
                        "pdf2webp",
                        "-i",
                        filepath,
                        "-o",
                        &filepath_out,
                        "-d",
                        &pdf_target_density,
                        "-s",
                        &pdf_target_size,
                    ])?;

                    Ok(uuid)
                })
                .collect::<Result<Vec<_>>>()?;

            Ok(result)
        }
    }
}

/// Exports all slides from a zip file to webps.
pub fn export_slides_from_zip<P: AsRef<Path>, Q: AsRef<Path> + Send + Sync>(
    _config: &Config,
    input: P,
    output: Q,
) -> Result<Vec<Uuid>> {
    // Create a temporary directory.
    let uuid = Uuid::new_v4();
    let temp_dir = format!(
        "{}/{}",
        output
            .as_ref()
            .to_str()
            .ok_or(Error(Status::InternalServerError))?,
        uuid
    );

    // Unzip the file.
    run_command(&vec![
        "unzip",
        "-o",
        input
            .as_ref()
            .to_str()
            .ok_or(Error(Status::InternalServerError))?,
        "-d",
        temp_dir.as_str(),
    ])?;

    // Move the files to the output directory with uuid names.
    // TODO: make sure the webps have the right size. Use a popy convert command.
    let files = std::fs::read_dir(temp_dir.as_str())?
        .map(|res| res.map(|e| e.file_name().into_string().unwrap()));
    let nb_files = files.count();

    let mut uuids = vec![];
    for i in 0..nb_files {
        let file_path = format!("{}/{}.webp", temp_dir, i);
        let uuid = Uuid::new_v4();
        let file_path_out = format!(
            "{}/{}.webp",
            output
                .as_ref()
                .to_str()
                .ok_or(Error(Status::InternalServerError))?,
            uuid
        );
        std::fs::rename(file_path, file_path_out)?;
        uuids.push(uuid);
    }

    // Remove the temporary directory.
    std::fs::remove_dir_all(temp_dir)?;

    Ok(uuids)
}

/// Get the size of a path. It can be a file or a directory.
pub fn get_size(path: &Path) -> Result<u64> {
    let mut size = 0;
    if path.is_dir() {
        for entry in std::fs::read_dir(path)? {
            let entry = entry?;
            size += get_size(&entry.path())?;
        }
    } else {
        size += std::fs::metadata(path)?.len();
    }
    Ok(size)
}
