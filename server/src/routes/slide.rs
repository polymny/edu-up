//! This module contains all the routes related to slides.

use diesel::ExpressionMethods;
use diesel::RunQueryDsl;

use rocket::request::Form;
use rocket_contrib::json::JsonValue;

use crate::db::slide::Slide;
use crate::db::user::User;
use crate::schema::slides;
use crate::{Database, Result};

/// A struct to  update Slides
#[derive(FromForm, AsChangeset, Debug)]
#[table_name = "slides"]
pub struct UpdateSlideForm {
    /// The position of the slide in the slide show
    pub position: i32,

    /// The position of the slide in the GOS.
    pub position_in_gos: Option<i32>,

    /// The GOS associated to slide.
    pub gos: Option<i32>,

    /// The asset associated to slide.
    pub asset_id: Option<i32>,

    /// capsule id
    pub capsule_id: i32,
}

/// The route to get a asset.
#[get("/slide/<id>")]
pub fn get_slide(db: Database, _user: User, id: i32) -> Result<JsonValue> {
    // let (asset, projects) = Asset::get(id, &db)?;
    let slide = Slide::get(id, &db)?;
    Ok(json!(slide))
}

/// The route to get a asset.
#[put("/slide/<slide_id>/move", data = "<move_slide>")]
pub fn move_slide(
    db: Database,
    _user: User,
    slide_id: i32,
    move_slide: Form<UpdateSlideForm>,
) -> Result<JsonValue> {
    // let (asset, projects) = Asset::get(id, &db)?;
    // Ok(json!({ "asset": asset, "projects": projects } ))
    let slide = Slide::get(slide_id, &db)?;
    println!("Move slide : {:#?}", move_slide);

    use crate::schema::slides::dsl::id;
    diesel::update(slides::table)
        .filter(id.eq(slide_id))
        .set(&move_slide.into_inner())
        .execute(&db.0)?;

    Ok(json!(slide))
}
