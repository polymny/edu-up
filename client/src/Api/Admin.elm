module Api.Admin exposing (..)

{-| This module helps us deal with everything user related.
-}

import Admin.Types as Admin
import Api.Utils as Api
import Data.Capsule as Data exposing (Capsule)
import Data.Types as Data
import Data.User as Data
import Http
import Json.Decode as Decode
import RemoteData exposing (WebData)


{-| List the users in the database.
-}
listUsers : Int -> (WebData (List Admin.User) -> msg) -> Cmd msg
listUsers pagination toMsg =
    Api.getJson
        { url = "/api/admin/users/" ++ String.fromInt pagination
        , toMsg = toMsg
        , decoder = Decode.list Admin.decodeUser
        , body = Http.emptyBody
        }


{-| Search users based on their username and or email adress.
-}
searchUsers : String -> String -> (WebData (List Admin.User) -> msg) -> Cmd msg
searchUsers username email toMsg =
    let
        maybeUsername =
            if username == "" then
                Nothing

            else
                Just username

        maybeEmail =
            if email == "" then
                Nothing

            else
                Just email

        query =
            [ Maybe.map (\x -> "username=" ++ x) maybeUsername
            , Maybe.map (\x -> "email=" ++ x) maybeEmail
            ]
                |> List.filterMap (\x -> x)
                |> String.join "&"
    in
    Api.getJson
        { url = "/api/admin/searchusers?" ++ query
        , toMsg = toMsg
        , body = Http.emptyBody
        , decoder = Decode.list Admin.decodeUser
        }


{-| Gets a user from its ID.
-}
getUser : Int -> (WebData Admin.User -> msg) -> Cmd msg
getUser id toMsg =
    Api.getJson
        { url = "/api/admin/user/" ++ String.fromInt id
        , body = Http.emptyBody
        , decoder = Admin.decodeUser
        , toMsg = toMsg
        }


{-| List the capsules in the database.
-}
listCapsules : Int -> (WebData (List Capsule) -> msg) -> Cmd msg
listCapsules pagination toMsg =
    Api.getJson
        { url = "/api/admin/capsules/" ++ String.fromInt pagination
        , toMsg = toMsg
        , decoder = Decode.list Data.decodeCapsule
        , body = Http.emptyBody
        }


{-| Search capsules based on their name and or project.
-}
searchCapsules : String -> String -> (WebData (List Capsule) -> msg) -> Cmd msg
searchCapsules name project toMsg =
    let
        maybeName =
            if name == "" then
                Nothing

            else
                Just name

        maybeProject =
            if project == "" then
                Nothing

            else
                Just project

        query =
            [ Maybe.map (\x -> "capsule=" ++ x) maybeName
            , Maybe.map (\x -> "project=" ++ x) maybeProject
            ]
                |> List.filterMap (\x -> x)
                |> String.join "&"
    in
    Api.getJson
        { url = "/api/admin/searchcapsules?" ++ query
        , toMsg = toMsg
        , body = Http.emptyBody
        , decoder = Decode.list Data.decodeCapsule
        }
