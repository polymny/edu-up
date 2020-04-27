module Core.Types exposing (..)

import Api
import Json.Decode as Decode
import Log exposing (debug)
import Login.Types as Login
import NewProject.Types as NewProject
import SignUp.Types as SignUp
import Task
import Time


type alias FullModel =
    { global : Global
    , model : Model
    }


init : Decode.Value -> ( FullModel, Cmd Msg )
init flags =
    let
        global =
            { zone = Time.utc, dummy = "" }

        initialCommand =
            Task.perform TimeZoneChanged Time.here
    in
    ( FullModel global (modelFromFlags flags), initialCommand )


modelFromFlags : Decode.Value -> Model
modelFromFlags flags =
    case Decode.decodeValue (Decode.field "page" Decode.string) flags of
        Ok "index" ->
            case Decode.decodeValue Api.decodeSession flags of
                Ok session ->
                    LoggedIn { session = session, page = LoggedInHome }

                Err _ ->
                    Home

        -- Ok "capsule" ->
        --     case ( Decode.decodeValue Api.decodeSession flags, Decode.decodeValue Api.decodeCapsuleDetails flags ) of
        --         ( Ok session, Ok capsule ) ->
        --             LoggedIn (LoggedInModel session (CapsulePage capsule (setupSlides capsule.slides) emptyUploadForm emptyEditPromptContent slideSystem.model gosSystem.model))
        --         ( _, _ ) ->
        --             Home
        Ok ok ->
            let
                _ =
                    debug "Unknown page" ok
            in
            Home

        Err err ->
            let
                _ =
                    debug "Error" err
            in
            Home


type alias Global =
    { zone : Time.Zone
    , dummy : String
    }


initGlobal : Global
initGlobal =
    Global Time.utc ""


type Model
    = Home
    | Login Login.Model
    | SignUp SignUp.Model
    | LoggedIn LoggedInModel


initModel : Model
initModel =
    Home


isLoggedIn : Model -> Bool
isLoggedIn model =
    case model of
        LoggedIn _ ->
            True

        _ ->
            False


type alias LoggedInModel =
    { session : Api.Session
    , page : LoggedInPage
    }


type LoggedInPage
    = LoggedInHome
    | LoggedInNewProject NewProject.Model


type Msg
    = Noop
    | HomeClicked
    | LoginClicked
    | LogoutClicked
    | SignUpClicked
    | NewProjectClicked
    | TimeZoneChanged Time.Zone
    | LoginMsg Login.Msg
    | SignUpMsg SignUp.Msg
    | LoggedInMsg LoggedInMsg


type LoggedInMsg
    = NewProjectMsg NewProject.Msg
