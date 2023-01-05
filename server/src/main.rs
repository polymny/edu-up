#[rocket::main]
async fn main() -> Result<(), rocket::Error> {
    let _rocket = polymny::rocket().await?;
    Ok(())
}
