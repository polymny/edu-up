module Api.Capsule exposing
    ( uploadSlideShow, getCapsule, updateCapsule, duplicateCapsule, addSlide, addGos, replaceSlide, produceCapsule
    , produceGos, publishCapsule, unpublishCapsule, uploadTrack, deleteRecord, addCollaborator, removeCollaborator, changeCollaboratorRole
    )

{-| This module contains all the functions to deal with the API of capsules.

@docs uploadSlideShow, getCapsule, updateCapsule, duplicateCapsule, addSlide, addGos, replaceSlide, produceCapsule
@docs produceGos, publishCapsule, unpublishCapsule, uploadTrack, deleteRecord, addCollaborator, removeCollaborator, changeCollaboratorRole

-}

import Api.Utils as Api
import Config
import Data.Capsule as Data
import Data.Types as Data
import File exposing (File)
import FileValue
import Http
import Json.Encode as Encode
import RemoteData exposing (WebData)


{-| Uploads a slideshow to the server, creating a new capsule.
-}
uploadSlideShow :
    { project : String, fileValue : FileValue.File, file : File.File, toMsg : WebData Data.Capsule -> msg }
    -> Cmd msg
uploadSlideShow { project, fileValue, file, toMsg } =
    let
        name =
            fileValue.name
                |> String.split "."
                |> List.reverse
                |> List.drop 1
                |> List.reverse
                |> String.join "."
    in
    Api.postJson
        { url = "/api/new-capsule/" ++ project ++ "/" ++ name ++ "/"
        , body = Http.fileBody file
        , decoder = Data.decodeCapsule
        , toMsg = toMsg
        }


{-| Gets a capsule from the server.
-}
getCapsule : String -> (WebData Data.Capsule -> msg) -> Cmd msg
getCapsule id toMsg =
    Api.getJson
        { url = "/api/capsule/" ++ id
        , body = Http.emptyBody
        , toMsg = toMsg
        , decoder = Data.decodeCapsule
        }


{-| Updates a caspule on the server.
-}
updateCapsule : Data.Capsule -> (WebData () -> msg) -> Cmd msg
updateCapsule capsule toMsg =
    Api.post
        { url = "/api/update-capsule/"
        , body = Http.jsonBody (Data.encodeCapsule capsule)
        , toMsg = toMsg
        }


{-| Adds a slide to a gos.
-}
addSlide : Data.Capsule -> Int -> List Int -> File -> Config.TaskId -> (WebData Data.Capsule -> msg) -> Cmd msg
addSlide capsule gos pages file taskId toMsg =
    let
        pagesStr : String
        pagesStr =
            pages
                |> List.map (\x -> x - 1)
                |> List.map String.fromInt
                |> String.join ","
    in
    Api.postWithTrackerJson ("task-track-" ++ String.fromInt taskId)
        { url = "/api/add-slide/" ++ capsule.id ++ "/" ++ String.fromInt gos ++ "/" ++ pagesStr
        , body = Http.fileBody file
        , decoder = Data.decodeCapsule
        , toMsg = toMsg
        }


{-| Adds a gos to a structure.
-}
addGos : Data.Capsule -> Int -> List Int -> File -> Config.TaskId -> (WebData Data.Capsule -> msg) -> Cmd msg
addGos capsule gos pages file taskId toMsg =
    let
        pagesStr : String
        pagesStr =
            pages
                |> List.map (\x -> x - 1)
                |> List.map String.fromInt
                |> String.join ","
    in
    Api.postWithTrackerJson ("task-track-" ++ String.fromInt taskId)
        { url = "/api/add-gos/" ++ capsule.id ++ "/" ++ String.fromInt gos ++ "/" ++ pagesStr
        , body = Http.fileBody file
        , decoder = Data.decodeCapsule
        , toMsg = toMsg
        }


{-| Replaces a slide.
-}
replaceSlide : Data.Capsule -> Data.Slide -> List Int -> File -> Config.TaskId -> (WebData Data.Capsule -> msg) -> Cmd msg
replaceSlide capsule slide pages file taskId toMsg =
    let
        page : String
        page =
            pages
                |> List.head
                |> Maybe.withDefault 0
                |> (\x -> x - 1)
                |> String.fromInt
    in
    Api.postWithTrackerJson ("task-track-" ++ String.fromInt taskId)
        { url = "/api/replace-slide/" ++ capsule.id ++ "/" ++ slide.uuid ++ "/" ++ page
        , body = Http.fileBody file
        , decoder = Data.decodeCapsule
        , toMsg = toMsg
        }


{-| Triggers the production of a grain.
-}
produceGos : Data.Capsule -> Int -> (WebData () -> msg) -> Cmd msg
produceGos capsule gosId toMsg =
    Api.post
        { url = "/api/produce-gos/" ++ capsule.id ++ "/" ++ String.fromInt gosId
        , body = Http.emptyBody
        , toMsg = toMsg
        }


{-| Triggers the production of a capsule.
-}
produceCapsule : Data.Capsule -> (WebData () -> msg) -> Cmd msg
produceCapsule capsule toMsg =
    Api.post
        { url = "/api/produce/" ++ capsule.id
        , body = Http.emptyBody
        , toMsg = toMsg
        }


{-| Triggers the publication of a capsule.
-}
publishCapsule : Data.Capsule -> (WebData () -> msg) -> Cmd msg
publishCapsule capsule toMsg =
    Api.post
        { url = "/api/publish/" ++ capsule.id
        , body = Http.emptyBody
        , toMsg = toMsg
        }


{-| Triggers the removal of a publication of a capsule.
-}
unpublishCapsule : Data.Capsule -> (WebData () -> msg) -> Cmd msg
unpublishCapsule capsule toMsg =
    Api.post
        { url = "/api/unpublish/" ++ capsule.id
        , body = Http.emptyBody
        , toMsg = toMsg
        }


{-| Uploads a sound track to the server.
-}
uploadTrack :
    { capsule : Data.Capsule
    , fileValue : FileValue.File
    , file : File.File
    , toMsg : WebData Data.Capsule -> msg
    , taskId : Config.TaskId
    }
    -> Cmd msg
uploadTrack { capsule, fileValue, file, toMsg, taskId } =
    Api.postWithTrackerJson
        ("task-track-" ++ String.fromInt taskId)
        { url = "/api/sound-track/" ++ capsule.id ++ "/" ++ fileValue.name
        , body = Http.fileBody file
        , decoder = Data.decodeCapsule
        , toMsg = toMsg
        }


{-| Delete record from the server.
-}
deleteRecord : Data.Capsule -> Int -> (WebData () -> msg) -> Cmd msg
deleteRecord capsule gosId toMsg =
    Api.delete
        { url = "/api/delete-record/" ++ capsule.id ++ "/" ++ String.fromInt gosId
        , body = Http.emptyBody
        , toMsg = toMsg
        }


{-| Duplicates a capsule.
-}
duplicateCapsule : Data.Capsule -> (WebData Data.Capsule -> msg) -> Cmd msg
duplicateCapsule capsule toMsg =
    Api.postJson
        { url = "/api/duplicate/" ++ capsule.id
        , decoder = Data.decodeCapsule
        , body = Http.emptyBody
        , toMsg = toMsg
        }


{-| Adds a collaborator to a capsule.
-}
addCollaborator : Data.Capsule -> String -> Data.Role -> (WebData () -> msg) -> Cmd msg
addCollaborator capsule username role toMsg =
    Api.post
        { url = "/api/invite/" ++ capsule.id
        , body =
            Http.jsonBody <|
                Encode.object
                    [ ( "username", Encode.string username )
                    , ( "role", Encode.string <| Data.encodeRole role )
                    ]
        , toMsg = toMsg
        }


{-| Removes a collaborator to a capsule.
-}
removeCollaborator : Data.Capsule -> String -> (WebData () -> msg) -> Cmd msg
removeCollaborator capsule username toMsg =
    Api.post
        { url = "/api/deinvite/" ++ capsule.id
        , body = Http.jsonBody <| Encode.object [ ( "username", Encode.string username ) ]
        , toMsg = toMsg
        }


{-| Changes the role of a collaborator.
-}
changeCollaboratorRole : Data.Capsule -> String -> Data.Role -> (WebData () -> msg) -> Cmd msg
changeCollaboratorRole capsule username role toMsg =
    Api.post
        { url = "/api/change-role/" ++ capsule.id
        , body =
            Http.jsonBody <|
                Encode.object
                    [ ( "username", Encode.string username )
                    , ( "role", Encode.string <| Data.encodeRole role )
                    ]
        , toMsg = toMsg
        }
