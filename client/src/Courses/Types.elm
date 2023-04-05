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
    , newAssignmentForm : Maybe AssignmentForm
    }


{-| The form to create a new assignment.
-}
type alias AssignmentForm =
    { criteria : List String
    , subject : Maybe String
    , answerTemplate : Maybe String
    , submitted : WebData Data.Assignment
    , assignment : Maybe Data.Assignment
    }


initAssignmentForm : Maybe Data.Assignment -> AssignmentForm
initAssignmentForm assignment =
    { criteria = Maybe.map .criteria assignment |> Maybe.withDefault []
    , subject = Maybe.map .subject assignment
    , answerTemplate = Maybe.map .answerTemplate assignment
    , submitted = RemoteData.NotAsked
    , assignment = assignment
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


{-| The initial model for the assignment page.
-}
initWithAssignment : Data.Assignment -> Model Int
initWithAssignment assignment =
    { selectedGroup = Just assignment.group
    , popupType = NoPopup
    , selectorIndex = 0
    , newAssignmentForm = Just <| initAssignmentForm (Just assignment)
    }
