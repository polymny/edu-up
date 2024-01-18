//! This module helps us dealing with openid configuration.

use serde::{Deserialize, Serialize};

use jsonwebtoken::{decode, Algorithm, DecodingKey, Validation};

use rocket::http::Status;
use rocket::serde::json::{json, Value};

use crate::{Error, Result};

/// The configuration for the Open ID server.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OpenId {
    /// Whether other authentication methods than OpenID are allowed.
    pub only: bool,

    /// The root to which polymny can contact the Open ID server.
    pub root: String,

    /// The root publicly accessible of the Open ID server.
    pub public_root: String,

    /// The client ID to connect to Open ID.
    pub client: String,

    /// The client secret to authenticate to Open ID.
    pub secret: String,

    /// The Open ID public key for JWT validation.
    pub validation: String,

    /// The http proxy if required.
    pub http_proxy: Option<String>,

    /// The https proxy if required.
    pub https_proxy: Option<String>,
}

impl OpenId {
    /// Returns the route to the token URI.
    pub fn token_route(&self) -> String {
        format!("{}/protocol/openid-connect/token", self.root)
    }

    /// Returns the Open ID config as a json value.
    pub fn to_json(&self) -> Value {
        json!({
            "only": self.only,
            "root": self.public_root,
            "client": self.client,
        })
    }

    /// Creates the Open ID Token request.
    pub fn token_request<'a, 'b, 'c>(
        &'a self,
        redirect_uri: &'b str,
        code: &'c str,
    ) -> OpenIdTokenRequest<'a, 'a, 'b, 'c> {
        OpenIdTokenRequest {
            grant_type: "authorization_code",
            client_id: &self.client,
            client_secret: &self.secret,
            redirect_uri,
            code,
        }
    }

    /// Gets the access token from a code.
    pub async fn get_access_token(&self, redirect_uri: &str, code: &str) -> Result<Claims> {
        let client = reqwest::Client::builder();

        let client = match self.http_proxy.as_ref() {
            Some(http) => client
                .proxy(reqwest::Proxy::http(http).map_err(|_| Error(Status::InternalServerError))?),
            _ => client,
        };

        let client = match self.https_proxy.as_ref() {
            Some(https) => client.proxy(
                reqwest::Proxy::https(https).map_err(|_| Error(Status::InternalServerError))?,
            ),
            _ => client,
        };

        let client = client
            .build()
            .map_err(|_| Error(Status::InternalServerError))?;

        // Get the access token
        let res = client
            .post(&self.token_route())
            .form(&self.token_request(redirect_uri, code))
            .send()
            .await
            .map_err(|_| Error(Status::InternalServerError))?
            .json::<OpenIdTokenResponse>()
            .await
            .map_err(|_| Error(Status::InternalServerError))?;

        let key = DecodingKey::from_rsa_pem(
            &format!(
                "-----BEGIN PUBLIC KEY-----\n{}\n-----END PUBLIC KEY-----",
                self.validation
            )
            .as_bytes(),
        )
        .map_err(|_| Error(Status::InternalServerError))?;

        // Decode the JWT.
        let mut validation = Validation::new(Algorithm::RS256);
        validation.set_audience(&[self.client.clone()]);

        let token = decode::<Claims>(&res.access_token, &key, &validation);

        let token = token.map_err(|_| Error(Status::InternalServerError))?;

        Ok(token.claims)
    }
}

/// An open id token request.
#[derive(Serialize)]
pub struct OpenIdTokenRequest<'a, 'b, 'c, 'd> {
    /// The grant type, which is always authorization code.
    pub grant_type: &'static str,

    /// The id of the client.
    pub client_id: &'a str,

    /// The secret of the client.
    pub client_secret: &'b str,

    /// The redirect url that was initially given.
    pub redirect_uri: &'c str,

    /// The code given after the redirection.
    pub code: &'d str,
}

/// An open id token response.
#[derive(Deserialize)]
pub struct OpenIdTokenResponse {
    /// The token.
    pub access_token: String,
}

/// What we decode from the JWT.
#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    /// The email of the user.
    pub email: String,

    /// The username of the user.
    #[serde(rename = "preferred_username")]
    pub username: String,
}
