module Api.User exposing (..)

{-| This module helps us deal with everything user related.
-}

import Api.Utils as Api
import Data.Types as Data
import Data.User as Data exposing (User)
import Http
import Json.Encode as Encode
import RemoteData exposing (WebData)


{-| Login with username and password.
-}
login : Data.SortBy -> String -> String -> (WebData User -> msg) -> Cmd msg
login sortBy username password toMsg =
    Api.postJson
        { url = "/api/login"
        , body =
            Http.jsonBody <|
                Encode.object
                    [ ( "username", Encode.string username )
                    , ( "password", Encode.string password )
                    ]
        , toMsg = toMsg
        , decoder = Data.decodeUser sortBy
        }


{-| Logs out the current user.
-}
logout : msg -> Cmd msg
logout msg =
    Api.post { url = "/api/logout", body = Http.emptyBody, toMsg = \_ -> msg }


{-| Asks the server to authenticate via email to reset a forgotten password.
-}
requestNewPassword : String -> (WebData () -> msg) -> Cmd msg
requestNewPassword email toMsg =
    Api.post
        { url = "/api/request-new-password"
        , toMsg = toMsg
        , body = Http.jsonBody <| Encode.object [ ( "email", Encode.string email ) ]
        }


{-| Tells the server to change the password after a forgotten password.
-}
resetPassword : Data.SortBy -> String -> String -> (WebData User -> msg) -> Cmd msg
resetPassword sortBy key newPassword toMsg =
    Api.postJson
        { url = "/api/change-password"
        , body =
            Http.jsonBody <|
                Encode.object
                    [ ( "key", Encode.string key )
                    , ( "new_password", Encode.string newPassword )
                    ]
        , toMsg = toMsg
        , decoder = Data.decodeUser sortBy
        }


{-| Creates a new Polymny account.
-}
signUp : { a | username : String, email : String, password : String, signUpForNewsletter : Bool } -> (WebData () -> msg) -> Cmd msg
signUp { username, email, password, signUpForNewsletter } toMsg =
    Api.post
        { url = "/api/new-user"
        , body =
            Http.jsonBody <|
                Encode.object
                    [ ( "username", Encode.string username )
                    , ( "email", Encode.string email )
                    , ( "password", Encode.string password )
                    , ( "subscribed", Encode.bool signUpForNewsletter )
                    ]
        , toMsg = toMsg
        }
