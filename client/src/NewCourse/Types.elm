module NewCourse.Types exposing (..)

import Data.Types as Data
import Data.User as Data
import Http exposing (Part)
import Utils
import RemoteData exposing (WebData)


{-| The Msg type for the new course page.
-}
type Msg
    = NoOp
    | SelectGroup Data.Group
    | NewGroup Utils.Confirmation String
    | EnterPressed
    | EscapePressed
    | ChangeSelectorIndex Int
    | AddParticipant Utils.Confirmation Data.ParticipantRole String
    | RemoveParticipant Data.Participant
    | DeleteGroup Utils.Confirmation Data.Group
    | Response (WebData (Data.Group))


{-| The model for the new course page.
-}
type alias Model =
    { selectedGroup : Maybe Data.Group
    , popupType : PopupType
    , selectorIndex : Int
    }


{-| The type of popup that is currently open.
-}
type PopupType
    = NoPopup
    | NewGroupPopup String
    | DeleteGroupPopup Data.Group
    | AddParticipantPopup Data.ParticipantRole String


{-| The initial model for the new course page.
-}
init : Model
init =
    { selectedGroup = Nothing
    , popupType = NoPopup
    , selectorIndex = 0
    }
