module Route exposing
    ( Route(..), toUrl, compareTab, fromUrl, push
    , AdminRoute(..)
    )

{-| This module contains the type definition of the routes of the app, and the utility functions to manipulate routes.

@docs Route, toUrl, compareTab, fromUrl, push

-}

import Browser.Navigation
import Url
import Utils


{-| This type represents the different routes of our application.
-}
type Route
    = Home
    | Preparation String
    | Acquisition String Int
    | Production String Int
    | Publication String
    | Collaboration String
    | Options String
    | Profile
    | Courses (Maybe Int)
    | Assignment Int
    | Admin AdminRoute
    | NotFound
    | Custom String


{-| This type represents the different administration routes.
-}
type AdminRoute
    = Users Int
    | Capsules Int
    | UserDetails Int


{-| Converts the route to the string representing the URL of the route. The NotFound route will redirect to Home.
-}
toUrl : Route -> String
toUrl route =
    case route of
        Home ->
            "/"

        Preparation s ->
            "/capsule/preparation/" ++ s

        Acquisition s i ->
            "/capsule/acquisition/" ++ s ++ "/" ++ String.fromInt (i + 1)

        Production s i ->
            "/capsule/production/" ++ s ++ "/" ++ String.fromInt (i + 1)

        Publication s ->
            "/capsule/publication/" ++ s

        Options s ->
            "/capsule/options/" ++ s

        Collaboration s ->
            "/capsule/collaboration/" ++ s

        Profile ->
            "/profile"

        Courses Nothing ->
            "/courses"

        Courses (Just groupId) ->
            "/courses/" ++ String.fromInt groupId

        Assignment id ->
            "/assignments/" ++ String.fromInt id

        Admin (Users i) ->
            "/admin/users/" ++ String.fromInt i

        Admin (UserDetails i) ->
            "/admin/user/" ++ String.fromInt i

        Admin (Capsules i) ->
            "/admin/capsules/" ++ String.fromInt i

        NotFound ->
            "/"

        Custom url ->
            url


{-| Tries to convert a URL to the corresponding route. Returns NotFound if the route wasn't found.
-}
fromUrl : Url.Url -> Route
fromUrl url =
    let
        tmp =
            String.split "/" url.path |> List.drop 1

        rev =
            List.reverse tmp

        -- this allows for trailing slash
        split =
            case List.head rev of
                Just x ->
                    if x == "" then
                        List.drop 1 rev |> List.reverse

                    else
                        List.reverse rev

                _ ->
                    tmp
    in
    case split of
        [] ->
            Home

        "capsule" :: "preparation" :: id :: [] ->
            Preparation id

        "capsule" :: "acquisition" :: id :: gos :: [] ->
            String.toInt gos
                |> Maybe.map (\gosId -> Acquisition id (gosId - 1))
                |> Maybe.withDefault NotFound

        "capsule" :: "production" :: id :: gos :: [] ->
            String.toInt gos
                |> Maybe.map (\gosId -> Production id (gosId - 1))
                |> Maybe.withDefault NotFound

        "capsule" :: "publication" :: id :: [] ->
            Publication id

        "capsule" :: "options" :: id :: [] ->
            Options id

        "capsule" :: "collaboration" :: id :: [] ->
            Collaboration id

        "profile" :: [] ->
            Profile

        "courses" :: [] ->
            Courses Nothing

        "courses" :: id :: [] ->
            String.toInt id
                |> Maybe.map (\i -> Courses (Just i))
                |> Maybe.withDefault (Courses Nothing)

        "assignments" :: id :: [] ->
            String.toInt id
                |> Maybe.map (\i -> Assignment i)
                |> Maybe.withDefault (Courses Nothing)

        "admin" :: "users" :: p :: [] ->
            String.toInt p
                |> Maybe.map (\x -> Utils.tern (x >= 0) (Admin (Users x)) NotFound)
                |> Maybe.withDefault NotFound

        "admin" :: "capsules" :: p :: [] ->
            String.toInt p
                |> Maybe.map (\x -> Utils.tern (x >= 0) (Admin (Capsules x)) NotFound)
                |> Maybe.withDefault NotFound

        "admin" :: "user" :: p :: [] ->
            String.toInt p
                |> Maybe.map (\x -> Admin (UserDetails x))
                |> Maybe.withDefault NotFound

        _ ->
            NotFound


{-| Checks if the tab of the routes are the same.
-}
compareTab : Route -> Route -> Bool
compareTab r1 r2 =
    case ( r1, r2 ) of
        ( Home, Home ) ->
            True

        ( Preparation _, Preparation _ ) ->
            True

        ( Acquisition _ _, Acquisition _ _ ) ->
            True

        ( Production _ _, Production _ _ ) ->
            True

        ( Publication _, Publication _ ) ->
            True

        ( Options _, Options _ ) ->
            True

        ( Collaboration _, Collaboration _ ) ->
            True

        ( Profile, Profile ) ->
            True

        ( Courses _, Courses _ ) ->
            True

        ( Assignment _, Assignment _ ) ->
            True

        ( Admin (Users _), Admin (Users _) ) ->
            True

        ( Admin (Capsules _), Admin (Capsules _) ) ->
            True

        _ ->
            False


{-| Go to the corresponding page.
-}
push : Maybe Browser.Navigation.Key -> Route -> Cmd msg
push key route =
    case key of
        Just k ->
            Browser.Navigation.pushUrl k (toUrl route)

        _ ->
            Cmd.none
