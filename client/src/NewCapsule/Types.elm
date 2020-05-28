module NewCapsule.Types exposing (Model, Msg(..), init)

import Api
import Status exposing (Status)


type alias Model =
    { status : Status () ()
    , name : String
    , title : String
    , description : String
    }


init : Model
init =
    Model Status.NotSent "" "" ""


type Msg
    = NameChanged String
    | TitleChanged String
    | DescriptionChanged String
    | Submitted
    | Cancel
    | Success Api.Capsule
