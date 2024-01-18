module App.Utils exposing
    ( init, pageFromRoute
    , capsuleAndGos, capsuleIdFromPage, gosIdFromPage, routeFromPage
    )

{-| This module contains some util functions that should really be in App/Types.elm but that can't be there because elm
doesn't allow circular module imports...

@docs init, pageFromRoute, capsuleFromPage, updatePage

-}

import Acquisition.Types as Acquisition
import Admin.Types as Admin
import Admin.Utils as Admin
import Api.Capsule as Api
import App.Types as App
import Browser.Navigation
import Collaboration.Types as Collaboration
import Config exposing (Config)
import Courses.Types as Courses
import Data.Capsule as Data
import Data.Types as Data
import Data.User as Data exposing (User)
import Error.Types as Error
import Home.Types as Home
import Json.Decode as Decode
import Options.Types as Options
import Preparation.Types as Preparation
import Production.Types as Production
import Profile.Types as Profile
import Publication.Types as Publication
import RemoteData
import Route exposing (Route)
import Task
import Time
import Unlogged.Types as Unlogged
import Url exposing (Url)


{-| Initializes the model for the application
-}
init : Decode.Value -> Url -> Browser.Navigation.Key -> ( App.MaybeModel, Cmd App.MaybeMsg )
init flags url key =
    let
        serverConfig =
            Decode.decodeValue (Decode.field "global" (Decode.field "serverConfig" Config.decodeServerConfig)) flags

        clientConfig =
            Decode.decodeValue (Decode.field "global" (Decode.field "clientConfig" Config.decodeClientConfig)) flags

        clientState =
            Config.initClientState
                (Just key)
                (clientConfig |> Result.toMaybe |> Maybe.andThen .lang)
                (clientConfig |> Result.toMaybe |> Maybe.map .awareOfNewClient |> Maybe.withDefault True)

        sortBy =
            clientConfig |> Result.map .sortBy |> Result.withDefault Config.defaultClientConfig.sortBy

        user =
            Decode.decodeValue (Decode.field "user" (Decode.nullable (Data.decodeUser sortBy))) flags

        route =
            Route.fromUrl url

        ( model, cmd ) =
            case ( serverConfig, clientConfig, user ) of
                ( Ok s, Ok c, Ok (Just u) ) ->
                    let
                        ( page, cm ) =
                            pageFromRoute { serverConfig = s, clientConfig = c, clientState = clientState } u route

                        tasks : List Config.TaskStatus
                        tasks =
                            u.projects
                                |> List.map .capsules
                                |> List.concat
                                |> List.map
                                    (\x ->
                                        let
                                            capsuleProduction : List (Config.TaskId -> Config.Task)
                                            capsuleProduction =
                                                case x.produced of
                                                    Data.Running _ ->
                                                        [ \a -> Config.CapsuleProduction a x.id ]

                                                    _ ->
                                                        []

                                            publication : List (Config.TaskId -> Config.Task)
                                            publication =
                                                case x.published of
                                                    Data.Running _ ->
                                                        [ \a -> Config.Publication a x.id ]

                                                    _ ->
                                                        []

                                            gosProductions : List (Config.TaskId -> Config.Task)
                                            gosProductions =
                                                x.structure
                                                    |> List.foldr
                                                        (\y acc ->
                                                            case y.produced of
                                                                Data.Running _ ->
                                                                    (\a -> Config.GosProduction a x.id 1) :: acc

                                                                -- TODO: Replace 1 by GOS id
                                                                _ ->
                                                                    acc
                                                        )
                                                        []
                                        in
                                        capsuleProduction ++ publication ++ gosProductions
                                    )
                                |> List.concat
                                |> List.indexedMap
                                    (\i makeTaskFromId ->
                                        { task = makeTaskFromId i
                                        , progress = Nothing
                                        , finished = False
                                        , aborted = False
                                        , global = True
                                        }
                                    )
                    in
                    ( App.Logged
                        { config =
                            { serverConfig = s
                            , clientConfig = c
                            , clientState =
                                { clientState
                                    | taskId = tasks |> List.length
                                    , tasks = tasks
                                }
                            }
                        , user = u
                        , page = page
                        }
                    , Cmd.batch [ cm, Task.perform (App.ConfigMsg << Config.ZoneChanged) Time.here ]
                        |> Cmd.map App.LoggedMsg
                    )

                ( Ok s, Ok _, Ok Nothing ) ->
                    let
                        openid =
                            case s.authMethods of
                                [ Config.OpenId { root, client } ] ->
                                    Just ( root, client )

                                _ ->
                                    Nothing
                    in
                    ( App.Unlogged <| Unlogged.init clientState.lang False s.root (Just url) openid
                    , Cmd.none
                    )

                ( Err s, _, _ ) ->
                    ( App.Failure (App.DecodeFailure s), Cmd.none )

                ( _, Err c, _ ) ->
                    ( App.Failure (App.DecodeFailure c), Cmd.none )

                ( _, _, Err u ) ->
                    ( App.Failure (App.DecodeFailure u), Cmd.none )
    in
    ( model, cmd )


{-| Extracts the capsule id the page.
-}
capsuleIdFromPage : App.Page -> Maybe String
capsuleIdFromPage page =
    case page of
        App.Preparation m ->
            Just m.capsule

        App.Acquisition m ->
            Just m.capsule

        App.Production m ->
            Just m.capsule

        App.Publication m ->
            Just m.capsule

        App.Options m ->
            Just m.capsule

        App.Collaboration m ->
            Just m.capsule

        _ ->
            Nothing


{-| Extracts the gos id from the page, if its meaningful.
-}
gosIdFromPage : App.Page -> Maybe Int
gosIdFromPage page =
    case page of
        App.Acquisition m ->
            Just m.gos

        App.Production m ->
            Just m.gos

        _ ->
            Nothing


{-| Extracts the capsule and the gos from a user and a page.
-}
capsuleAndGos : Data.User -> App.Page -> ( Maybe Data.Capsule, Maybe Data.Gos )
capsuleAndGos user page =
    let
        maybeCapsule : Maybe Data.Capsule
        maybeCapsule =
            capsuleIdFromPage page
                |> Maybe.andThen (\x -> Data.getCapsuleById x user)

        gosFromCapsule : Data.Capsule -> Maybe Data.Gos
        gosFromCapsule capsule =
            gosIdFromPage page
                |> Maybe.andThen (\x -> List.drop x capsule.structure |> List.head)

        maybeGos : Maybe Data.Gos
        maybeGos =
            Maybe.andThen gosFromCapsule maybeCapsule
    in
    ( maybeCapsule, maybeGos )


{-| Finds a page from the route and the context.
-}
pageFromRoute : Config -> User -> Route -> ( App.Page, Cmd App.Msg )
pageFromRoute _ user route =
    let
        fetchCapsuleIfAdmin : Route -> String -> Cmd App.Msg
        fetchCapsuleIfAdmin r id =
            if user.plan == Data.Admin && Data.getCapsuleById id user == Nothing then
                Api.getCapsule id
                    (\x ->
                        case x of
                            RemoteData.Success c ->
                                App.AddExternalCapsule c r

                            _ ->
                                App.Noop
                    )

            else
                Cmd.none
    in
    case route of
        Route.Home ->
            ( App.Home Home.init, Cmd.none )

        Route.Preparation id ->
            ( Data.getCapsuleById id user
                |> Maybe.map Preparation.init
                |> Maybe.map App.Preparation
                |> (Maybe.withDefault <| App.Error <| Error.init Error.NotFound)
            , fetchCapsuleIfAdmin (Route.Preparation id) id
            )

        Route.Acquisition id gos ->
            Data.getCapsuleById id user
                |> Maybe.andThen (Acquisition.init gos)
                |> Maybe.map (\( a, b ) -> ( App.Acquisition a, Cmd.map App.AcquisitionMsg b ))
                |> Maybe.withDefault ( App.Error <| Error.init Error.NotFound, fetchCapsuleIfAdmin (Route.Acquisition id gos) id )

        Route.Production id gos ->
            Data.getCapsuleById id user
                |> Maybe.andThen (Production.init gos)
                |> Maybe.map (\( a, b ) -> ( App.Production a, Cmd.map App.ProductionMsg b ))
                |> Maybe.withDefault ( App.Error <| Error.init Error.NotFound, fetchCapsuleIfAdmin (Route.Production id gos) id )

        Route.Publication id ->
            ( Data.getCapsuleById id user
                |> Maybe.map Publication.init
                |> Maybe.map App.Publication
                |> (Maybe.withDefault <| App.Error <| Error.init Error.NotFound)
            , fetchCapsuleIfAdmin (Route.Publication id) id
            )

        Route.Options id ->
            ( Data.getCapsuleById id user
                |> Maybe.map Options.init
                |> Maybe.map App.Options
                |> (Maybe.withDefault <| App.Error <| Error.init Error.NotFound)
            , fetchCapsuleIfAdmin (Route.Options id) id
            )

        Route.Collaboration id ->
            ( Data.getCapsuleById id user
                |> Maybe.map Collaboration.init
                |> Maybe.map App.Collaboration
                |> (Maybe.withDefault <| App.Error <| Error.init Error.NotFound)
            , fetchCapsuleIfAdmin (Route.Collaboration id) id
            )

        Route.Profile ->
            ( App.Profile Profile.init, Cmd.none )

        Route.Admin adminRoute ->
            if user.plan == Data.Admin then
                Admin.fromRoute adminRoute |> Tuple.mapFirst App.Admin

            else
                ( App.Error <| Error.init Error.NotFound, Cmd.none )

        Route.NotFound ->
            ( App.Error <| Error.init <| Error.fromCode 404, Cmd.none )

        Route.Courses c ->
            ( App.Courses (Courses.init c), Cmd.none )

        Route.Assignment i ->
            ( Data.getAssignmentById i user
                |> Maybe.map Courses.initWithAssignment
                |> Maybe.map App.Courses
                |> Maybe.withDefault (App.Courses <| Courses.init Nothing)
            , Cmd.none
            )

        _ ->
            ( App.Home Home.init, Cmd.none )


{-| Converts the page to a route.
-}
routeFromPage : App.Page -> Route
routeFromPage page =
    case page of
        App.Home _ ->
            Route.Home

        App.NewCapsule _ ->
            Route.Home

        App.Preparation m ->
            Route.Preparation m.capsule

        App.Acquisition m ->
            Route.Acquisition m.capsule m.gos

        App.Production m ->
            Route.Production m.capsule m.gos

        App.Publication m ->
            Route.Publication m.capsule

        App.Collaboration m ->
            Route.Collaboration m.capsule

        App.Options m ->
            Route.Options m.capsule

        App.Profile _ ->
            Route.Profile

        App.Admin (Admin.Users p _ _) ->
            Route.Admin (Route.Users p)

        App.Admin (Admin.UserDetails id _) ->
            Route.Admin (Route.UserDetails id)

        App.Admin (Admin.Capsules p _ _) ->
            Route.Admin (Route.Capsules p)

        App.Error _ ->
            Route.NotFound

        App.Courses m ->
            case Maybe.map .assignment m.newAssignmentForm of
                Just (Just x) ->
                    Route.Assignment x.group

                _ ->
                    Route.Courses m.selectedGroup
