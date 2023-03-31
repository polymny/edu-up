module Courses.Types exposing (..)

import Data.Types as Data
import Data.User as Data
import Http exposing (Part)
import RemoteData exposing (WebData)
import Utils


{-| The Msg type for the new course page.
-}
type Msg
    = NoOp
    | NewGroup Utils.Confirmation String
    | EnterPressed
    | EscapePressed
    | ChangeSelectorIndex Int
    | AddParticipant Utils.Confirmation Data.ParticipantRole String
    | RemoveParticipant Data.Participant
    | DeleteGroup Utils.Confirmation Data.Group
    | Response (WebData Data.Group)
    | SelfRemove Utils.Confirmation


{-| The model for the new course page.
-}
type alias Model a =
    { selectedGroup : Maybe a
    , popupType : PopupType
    , selectorIndex : Int
    }


{-| Converts a Model Int in Model Data.Group.
-}
withGroup : Maybe Data.Group -> Model Int -> Model Data.Group
withGroup group model =
    { selectedGroup = group
    , popupType = model.popupType
    , selectorIndex = model.selectorIndex
    }


{-| The type of popup that is currently open.
-}
type PopupType
    = NoPopup
    | NewGroupPopup String
    | DeleteGroupPopup Data.Group
    | AddParticipantPopup Data.ParticipantRole String
    | SelfRemovePopup
    | LastTeacherPopup


{-| The initial model for the new course page.
-}
init : Maybe Int -> Model Int
init id =
    { selectedGroup = id
    , popupType = NoPopup
    , selectorIndex = 0
    }
