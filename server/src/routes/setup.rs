//! This module contains the routes that we use to setup and generate the Rocket.toml.

use std::fs::File;
use std::io::Write;
use std::process::Command;

use diesel::pg::PgConnection;
use diesel::Connection;

use rocket::request::Form;

use crate::mailer::Mailer;
use crate::templates::{TEST_EMAIL_HTML, TEST_EMAIL_PLAIN_TEXT};

use crate::Result;

/// A struct that verifies the form for the database check route.
#[derive(FromForm)]
pub struct DatabaseTestForm {
    /// The hostname of the database.
    hostname: String,

    /// The username of the user that connects to the database.
    username: String,

    /// The password of the user that connects to the database.
    password: String,

    /// The name of the database.
    name: String,
}

/// Tests a database connection from its credentials.
#[post("/test-database", data = "<form>")]
pub fn test_database(form: Form<DatabaseTestForm>) -> Result<()> {
    // Build postgres url from credentials
    let url = format!(
        "postgres://{}:{}@{}/{}",
        form.username, form.password, form.hostname, form.name,
    );

    // Try to connect to the database
    PgConnection::establish(&url)?;

    // If we reach here, it is a success
    Ok(())
}

/// A struct that verifies the form for the mailer check route.
#[derive(FromForm)]
pub struct MailerTestForm {
    /// The hostname of the SMTP server.
    hostname: String,

    /// The username of the user that connects to the mail server.
    username: String,

    /// The password of the user that connects to the mail server.
    password: String,

    /// The recipient of the test mail.
    recipient: String,
}

/// Tests the mail configuration.
#[post("/test-mailer", data = "<form>")]
pub fn test_mailer(form: Form<MailerTestForm>) -> Result<()> {
    let mailer = Mailer::new(
        true,
        String::from(""),
        form.0.hostname,
        form.0.username,
        form.0.password,
    );

    mailer.send_mail(
        &form.0.recipient,
        String::from("Test mail from preparation"),
        String::from(TEST_EMAIL_PLAIN_TEXT),
        String::from(TEST_EMAIL_HTML),
    )?;

    Ok(())
}

/// A struct that contains the whole configuration.
#[derive(FromForm)]
pub struct ConfigForm {
    /// The hostname of the database.
    database_hostname: String,

    /// The username of the user that connects to the database.
    database_username: String,

    /// The password of the user that connects to the database.
    database_password: String,

    /// The name of the database.
    database_name: String,

    /// The hostname of the SMTP server.
    mailer_hostname: String,

    /// The username of the user that connects to the mail server.
    mailer_username: String,

    /// The password of the user that connects to the mail server.
    mailer_password: String,

    /// The recipient of the test mail.
    mailer_recipient: String,
}

/// The routes that sets the configuration.
#[post("/setup-config", data = "<form>")]
pub fn setup_config(form: Form<ConfigForm>) -> Result<()> {
    let key = String::from_utf8(
        Command::new("openssl")
            .arg("rand")
            .arg("-base64")
            .arg("32")
            .output()
            .expect("failed to execute process")
            .stdout,
    )
    .expect("failed to get key");

    let toml = format!(
        r#"[global]
root = "{root}"
secret_key = "{secret_key}"

[global.databases.database]
url = "postgres://{database_username}:{database_password}:{database_hostname}/{database_name}"
"#,
        root = "http://localhost:8000",
        secret_key = key,
        database_username = form.database_username,
        database_password = form.database_password,
        database_hostname = form.database_hostname,
        database_name = form.database_name,
    );

    let mut file = File::create("Rocket.toml")?;
    file.write_all(toml.as_bytes())?;

    Ok(())
}
