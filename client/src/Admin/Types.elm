module Admin.Types exposing (..)

{-| This module contains all the administration pages.
-}

import Data.Capsule as Data exposing (Capsule)
import Data.Types as Data
import Data.User as Data
import Home.Types as Home
import Json.Decode as Decode exposing (Decoder)


{-| The different administration pages on which an admin can go.
-}
type Model
    = Users Int (List User) UserSearchForm
    | Capsules Int (List Capsule) CapsuleSearchForm
    | UserDetails Int (Maybe ( User, Home.Model ))


{-| Message type for the admin page.
-}
type Msg
    = UsersArrived Int (List User)
    | CapsulesArrived Int (List Capsule)
    | UserArrived Int User
    | Toggle Data.Project
    | UsernameChanged String
    | EmailChanged String
    | SearchUsers
    | CapsuleNameChanged String
    | ProjectChanged String
    | SearchCapsules


{-| The form to search for users.
-}
type alias UserSearchForm =
    { username : String, email : String }


{-| The default user search form.
-}
emptyUserSearchForm : UserSearchForm
emptyUserSearchForm =
    { username = "", email = "" }


{-| Extracts the user search form from a model, if it exists.
-}
getUserSearchForm : Model -> Maybe UserSearchForm
getUserSearchForm model =
    case model of
        Users _ _ a ->
            Just a

        _ ->
            Nothing


{-| The form to search for capsules.
-}
type alias CapsuleSearchForm =
    { name : String, project : String }


{-| The default capsule search form.
-}
emptyCapsuleSearchForm : CapsuleSearchForm
emptyCapsuleSearchForm =
    { name = "", project = "" }


{-| Extracts the capsule search form from a model, if it exists.
-}
getCapsuleSearchForm : Model -> Maybe CapsuleSearchForm
getCapsuleSearchForm model =
    case model of
        Capsules _ _ a ->
            Just a

        _ ->
            Nothing


{-| Users that will be fetched from the admin API.
-}
type alias User =
    { id : Int
    , activated : Bool
    , newsletterSubscribed : Bool
    , inner : Data.User
    , memberSince : Maybe Int
    , lastVisited : Maybe Int
    }


{-| Converts a user received from the server to our users.
-}
fromRealUser : Int -> Bool -> Bool -> Maybe Int -> Maybe Int -> Data.User -> User
fromRealUser id activated newsletterSubscribed memberSince lastVisited inner =
    { id = id
    , activated = activated
    , newsletterSubscribed = newsletterSubscribed
    , memberSince = memberSince
    , lastVisited = lastVisited
    , inner = inner
    }


{-| Decoder for users from the server.
-}
decodeUser : Decoder User
decodeUser =
    Decode.map6 fromRealUser
        (Decode.field "id" Decode.int)
        (Decode.field "activated" Decode.bool)
        (Decode.field "newsletter_subscribed" Decode.bool)
        (Decode.field "member_since" (Decode.maybe Decode.int))
        (Decode.field "last_visited" (Decode.maybe Decode.int))
        (Data.decodeUser { key = Data.Name, ascending = False })
