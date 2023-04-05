module Courses.Types exposing (..)

import Data.Capsule as Data
import Data.Group as Data
import Data.Types as Data
import Data.User as Data
import RemoteData exposing (WebData)
import Utils


{-| The Msg type for the new course page.
-}
type Msg
    = NewGroup Utils.Confirmation String
    | EnterPressed
    | EscapePressed
    | ChangeSelectorIndex Int
    | AddParticipant Utils.Confirmation Data.ParticipantRole String
    | RemoveParticipant Data.Participant
    | DeleteGroup Utils.Confirmation Data.Group
    | Response (WebData Data.Group)
    | SelfRemove Utils.Confirmation
    | StartNewAssignment
    | SelectCapsule Bool
    | CapsuleClicked String
    | ValidateCapsule Utils.Confirmation String
    | NewCriterion
    | RemoveCriterion Int
    | CriteriaChanged Int String
    | CreateAssignment
    | CreateAssignmentChanged (WebData Data.Assignment)


{-| The model for the new course page.
-}
type alias Model a =
    { selectedGroup : Maybe a
    , popupType : PopupType
    , selectorIndex : Int
    , newAssignmentForm : Maybe NewAssignmentForm
    }


{-| The form to create a new assignment.
-}
type alias NewAssignmentForm =
    { criteria : List String
    , subject : Maybe String
    , answerTemplate : Maybe String
    , submitted : WebData Data.Assignment
    }


initNewAssignmentForm : NewAssignmentForm
initNewAssignmentForm =
    { criteria = []
    , subject = Nothing
    , answerTemplate = Nothing
    , submitted = RemoteData.NotAsked
    }


{-| Converts a Model Int in Model Data.Group.
-}
withGroup : Maybe Data.Group -> Model Int -> Model Data.Group
withGroup group model =
    { selectedGroup = group
    , popupType = model.popupType
    , selectorIndex = model.selectorIndex
    , newAssignmentForm = model.newAssignmentForm
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
    | SelectCapsulePopup SelectCapsuleForm


type alias SelectCapsuleForm =
    { isSubject : Bool
    , capsule : Maybe String
    }


initSelectCapsuleForm : Bool -> SelectCapsuleForm
initSelectCapsuleForm isSubject =
    { isSubject = isSubject
    , capsule = Nothing
    }


{-| The initial model for the new course page.
-}
init : Maybe Int -> Model Int
init id =
    { selectedGroup = id
    , popupType = NoPopup
    , selectorIndex = 0
    , newAssignmentForm = Nothing
    }
