module Data.Group exposing (..)

import Data.Types as Data
import Json.Decode as Decode exposing (Decoder)


{-| This type represents a group with all the info we have on it.
-}
type alias Group =
    { id : Int
    , name : String
    , participants : List Participant
    , assignments : List Assignment
    }


{-| JSON decoder for group.
-}
decodeGroup : Decoder Group
decodeGroup =
    Decode.map4 Group
        (Decode.field "id" Decode.int)
        (Decode.field "name" Decode.string)
        (Decode.field "participants" (Decode.list decodeParticipant))
        (Decode.field "assignments" (Decode.list decodeAssignment))


{-| JSON decoder for participant.
-}
decodeParticipant : Decoder Participant
decodeParticipant =
    Decode.map3 Participant
        (Decode.field "username" Decode.string)
        (Decode.field "email" Decode.string)
        (Decode.field "role" Data.decodeGroupRole)


{-| This type represents a participant with all the info we have on it.
-}
type alias Participant =
    { username : String
    , email : String
    , role : Data.ParticipantRole
    }


{-| This type represents an assignment.
-}
type alias Assignment =
    { id : Int
    , criteria : List String
    , subject : String
    , answerTemplate : String
    , answers : List Answer
    , group : Int
    , state : AssignmentState
    , showDetails : Bool
    }


{-| JSON decoder for assignment.
-}
decodeAssignment : Decoder Assignment
decodeAssignment =
    Decode.map8 Assignment
        (Decode.field "id" Decode.int)
        (Decode.field "criteria" (Decode.list Decode.string))
        (Decode.field "subject" Decode.string)
        (Decode.field "answer_template" Decode.string)
        (Decode.field "answers" <| Decode.list decodeAnswer)
        (Decode.field "group" Decode.int)
        (Decode.field "state" decodeAssignmentState)
        (Decode.succeed False)


{-| This type represents the state of an assignment.
-}
type AssignmentState
    = Preparation
    | Prepared
    | Working
    | Evaluation
    | Finished


{-| JSON decoder for assignment state.
-}
decodeAssignmentState : Decoder AssignmentState
decodeAssignmentState =
    Decode.string
        |> Decode.andThen
            (\state ->
                case state of
                    "preparation" ->
                        Decode.succeed Preparation

                    "prepared" ->
                        Decode.succeed Prepared

                    "working" ->
                        Decode.succeed Working

                    "evaluation" ->
                        Decode.succeed Evaluation

                    "finished" ->
                        Decode.succeed Finished

                    _ ->
                        Decode.fail ("Unknown assignment state: " ++ state)
            )


{-| An answer to an assignment.
-}
type alias Answer =
    { id : Int
    , capsule : String
    , finished : Bool
    }


{-| JSON decoder for answer.
-}
decodeAnswer : Decoder Answer
decodeAnswer =
    Decode.map3 Answer
        (Decode.field "id" Decode.int)
        (Decode.field "capsule" Decode.string)
        (Decode.field "finished" Decode.bool)
