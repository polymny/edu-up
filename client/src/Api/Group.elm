module Api.Group exposing (..)

import Api.Utils as Api
import Data.Group as Data
import Data.Types as Data
import Http
import Json.Encode as Encode
import RemoteData exposing (WebData)


{-| Request to create a group.
-}
createGroup : String -> (WebData Data.Group -> msg) -> Cmd msg
createGroup groupName toMsg =
    Api.postJson
        { url = "/api/new-group"
        , decoder = Data.decodeGroup
        , body = Http.jsonBody <| Encode.object [ ( "name", Encode.string groupName ) ]
        , toMsg = toMsg
        }


{-| Request to delete a group.
-}
deleteGroup : Int -> (WebData Data.Group -> msg) -> Cmd msg
deleteGroup groupId toMsg =
    Api.deleteJson
        { url = "/api/delete-group/"
        , decoder = Data.decodeGroup
        , body = Http.jsonBody <| Encode.object [ ( "group_id", Encode.int groupId ) ]
        , toMsg = toMsg
        }


{-| Request to add a participant to a group.
-}
addParticipant : Int -> String -> Data.ParticipantRole -> (WebData Data.Group -> msg) -> Cmd msg
addParticipant groupId participantEmail role toMsg =
    Api.postJson
        { url = "/api/add-participant"
        , decoder = Data.decodeGroup
        , body =
            Http.jsonBody <|
                Encode.object
                    [ ( "group_id", Encode.int groupId )
                    , ( "participant", Encode.string participantEmail )
                    , ( "participant_role", Encode.string <| Data.encodeParticipantRole role )
                    ]
        , toMsg = toMsg
        }


{-| Request to remove a participant from a group.
-}
removeParticipant : Int -> String -> (WebData Data.Group -> msg) -> Cmd msg
removeParticipant groupId participantEmail toMsg =
    Api.deleteJson
        { url = "/api/remove-participant"
        , decoder = Data.decodeGroup
        , body =
            Http.jsonBody <|
                Encode.object
                    [ ( "group_id", Encode.int groupId )
                    , ( "participant", Encode.string participantEmail )
                    ]
        , toMsg = toMsg
        }


{-| Creates a new assignment.
-}
createAssignment : Int -> String -> String -> List String -> (WebData Data.Assignment -> msg) -> Cmd msg
createAssignment groupId subject answerTemplate criteria toMsg =
    Api.postJson
        { url = "/api/new-assignment"
        , decoder = Data.decodeAssignment
        , body =
            Http.jsonBody <|
                Encode.object
                    [ ( "subject", Encode.string subject )
                    , ( "answer_template", Encode.string answerTemplate )
                    , ( "group_id", Encode.int groupId )
                    , ( "criteria", Encode.list Encode.string criteria )
                    ]
        , toMsg = toMsg
        }


{-| Validates an assignment.
-}
validateAssignment : Int -> (WebData () -> msg) -> Cmd msg
validateAssignment assignmentId toMsg =
    Api.post
        { url = "/api/validate-assignment"
        , body = Http.jsonBody <| Encode.object [ ( "assignment_id", Encode.int assignmentId ) ]
        , toMsg = toMsg
        }
