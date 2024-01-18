module Data.Capsule exposing
    ( Capsule, emptyCapsule, assetPath, miniaturePath, iframeHtml, Collaborator
    , Gos, gosFromSlides, emptyGos, WebcamSettings(..), defaultWebcamSettings, setWebcamSettingsSize, Fade, defaultFade, Anchor(..), Event, EventType(..), eventTypeToString, updateGos
    , Slide, emptySlide, slidePath, extraPath, capsuleVideoPath, recordPath, pointerPath, gosVideoPath, deleteSlide, deleteExtra, updateSlide, updateSlideInGos
    , Record, emptyRecord
    , encodeCapsule, encodeGos, encodeWebcamSettings, encodeFade, encodeRecord, encodeEvent, encodeEventType, encodeAnchor
    , encodeSlide, encodePair
    , decodeCapsule, decodeGos, decodeWebcamSettings, decodePip, decodeFullscreen, decodeFade, decodeRecord, decodeEvent
    , decodeEventType, decodeAnchor, decodeSlide, decodePair, decodeCollaborator
    , SoundTrack, encodeCapsuleAll, firstRecordPath, removeTrack, trackPath, trackPreviewPath
    )

{-| This module contains all the data related to capsules.


# The capsule type

@docs Capsule, emptyCapsule, assetPath, miniaturePath, iframeHtml, Collaborator


# The GoS (Group of Slides) type

@docs Gos, gosFromSlides, emptyGos, WebcamSettings, defaultWebcamSettings, setWebcamSettingsSize, Fade, defaultFade, Anchor, Event, EventType, eventTypeToString, updateGos


## Slides

@docs Slide, emptySlide, slidePath, extraPath, capsuleVideoPath, recordPath, pointerPath, gosVideoPath, deleteSlide, deleteExtra, updateSlide, updateSlideInGos


## Records

@docs Record, emptyRecord


# Encoders and decoders


## Encoders

@docs encodeCapsule, encodeGos, encodeWebcamSettings, encodeFade, encodeRecord, encodeEvent, encodeEventType, encodeAnchor
@docs encodeSlide, encodePair


## Decoders

@docs decodeCapsule, decodeGos, decodeWebcamSettings, decodePip, decodeFullscreen, decodeFade, decodeRecord, decodeEvent
@docs decodeEventType, decodeAnchor, decodeSlide, decodePair, decodeCollaborator

-}

import Config exposing (Config)
import Data.Types as Data
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Utils exposing (andMap)


{-| This type represents a capsule.
-}
type alias Capsule =
    { id : String
    , name : String
    , project : String
    , role : Data.Role
    , collaborators : List Collaborator
    , videoUploaded : Data.TaskStatus
    , produced : Data.TaskStatus
    , producedHash : Maybe String
    , published : Data.TaskStatus
    , privacy : Data.Privacy
    , structure : List Gos
    , defaultWebcamSettings : WebcamSettings
    , lastModified : Int
    , promptSubtitles : Bool
    , diskUsage : Int
    , duration : Int
    , soundTrack : Maybe SoundTrack
    , outputPresign : Maybe String
    , soundTrackPresign : Maybe String
    , hidden : Bool
    }


{-| This type represents a collaborator of a capsule.
-}
type alias Collaborator =
    { username : String
    , role : Data.Role
    }


{-| Decodes a collaborator.
-}
decodeCollaborator : Decoder Collaborator
decodeCollaborator =
    Decode.map2 Collaborator
        (Decode.field "username" Decode.string)
        (Decode.field "role" Data.decodeRole)


{-| Create an empty capsule.
-}
emptyCapsule : Capsule
emptyCapsule =
    { id = ""
    , name = ""
    , project = ""
    , role = Data.Owner
    , collaborators = []
    , videoUploaded = Data.Idle
    , produced = Data.Idle
    , producedHash = Nothing
    , published = Data.Idle
    , privacy = Data.Private
    , structure = []
    , defaultWebcamSettings = defaultWebcamSettings 0
    , lastModified = 0
    , promptSubtitles = False
    , diskUsage = 0
    , duration = 0
    , soundTrack = Nothing
    , outputPresign = Nothing
    , soundTrackPresign = Nothing
    , hidden = False
    }


{-| JSON encoder for capsule.
-}
encodeCapsule : Capsule -> Encode.Value
encodeCapsule capsule =
    Encode.object
        [ ( "id", Encode.string capsule.id )
        , ( "project", Encode.string capsule.project )
        , ( "name", Encode.string capsule.name )
        , ( "privacy", Data.encodePrivacy capsule.privacy )
        , ( "prompt_subtitles", Encode.bool capsule.promptSubtitles )
        , ( "webcam_settings", encodeWebcamSettings capsule.defaultWebcamSettings )
        , ( "structure", Encode.list encodeGos capsule.structure )
        , ( "sound_track", Maybe.map encodeSoundTrack capsule.soundTrack |> Maybe.withDefault Encode.null )
        ]


{-| JSON encoder for capsule with the produced info.
-}
encodeCapsuleAll : Capsule -> Encode.Value
encodeCapsuleAll capsule =
    Encode.object
        [ ( "id", Encode.string capsule.id )
        , ( "project", Encode.string capsule.project )
        , ( "name", Encode.string capsule.name )
        , ( "privacy", Data.encodePrivacy capsule.privacy )
        , ( "prompt_subtitles", Encode.bool capsule.promptSubtitles )
        , ( "webcam_settings", encodeWebcamSettings capsule.defaultWebcamSettings )
        , ( "structure", Encode.list encodeGosAll capsule.structure )
        , ( "sound_track", Maybe.map encodeSoundTrack capsule.soundTrack |> Maybe.withDefault Encode.null )
        , ( "produced", Encode.bool (capsule.produced /= Data.Idle) )
        , ( "output_presign", Maybe.withDefault Encode.null <| Maybe.map Encode.string capsule.outputPresign )
        , ( "sound_track_presign", Maybe.withDefault Encode.null <| Maybe.map Encode.string capsule.soundTrackPresign )
        ]


{-| JSON decoder for caspule.
-}
decodeCapsule : Decoder Capsule
decodeCapsule =
    Decode.succeed Capsule
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "project" Decode.string)
        |> andMap (Decode.field "role" Data.decodeRole)
        |> andMap (Decode.field "users" (Decode.list decodeCollaborator))
        |> andMap (Decode.field "video_uploaded" Data.decodeTaskStatus)
        |> andMap (Decode.field "produced" Data.decodeTaskStatus)
        |> andMap (Decode.maybe (Decode.field "produced_hash" Decode.string))
        |> andMap (Decode.field "published" Data.decodeTaskStatus)
        |> andMap (Decode.field "privacy" Data.decodePrivacy)
        |> andMap (Decode.field "structure" (Decode.list decodeGos))
        |> andMap (Decode.field "webcam_settings" decodeWebcamSettings)
        |> andMap (Decode.field "last_modified" Decode.int)
        |> andMap (Decode.field "prompt_subtitles" Decode.bool)
        |> andMap (Decode.field "disk_usage" Decode.int)
        |> andMap (Decode.field "duration_ms" Decode.int)
        |> andMap (Decode.maybe (Decode.field "sound_track" decodeSoundTrack))
        |> andMap (Decode.maybe (Decode.field "output_presign" Decode.string))
        |> andMap (Decode.maybe (Decode.field "sound_track_presign" Decode.string))
        |> andMap (Decode.succeed False)


{-| Returns an asset path from its capsule and basename.
-}
assetPath : Capsule -> String -> String
assetPath capsule path =
    "/data/" ++ capsule.id ++ "/assets/" ++ path


{-| Returns the HTML code to embed the video into another web page.
-}
iframeHtml : Config -> Capsule -> String
iframeHtml config capsule =
    "<div style=\"position: relative; width: 100%; padding-top: 56.25%\">\n"
        ++ "    <iframe\n"
        ++ "        allowfullscreen=\"true\"\n"
        ++ "        style=\"position:absolute;top:0;left:0;width:100%;height:100%;\"\n"
        ++ "        src=\""
        ++ config.serverConfig.videoRoot
        ++ "/"
        ++ capsule.id
        ++ "/\"\n"
        ++ "        title=\""
        ++ capsule.name
        ++ "\"\n"
        ++ "    >\n"
        ++ "    </iframe>\n"
        ++ "</div>"


{-| This type represents a slide of a presentation.
-}
type alias Slide =
    { uuid : String
    , extra : Maybe String
    , prompt : String
    , presign : Maybe String
    , extraPresign : Maybe String
    }


{-| An empty slide.
-}
emptySlide : Slide
emptySlide =
    { uuid = ""
    , extra = Nothing
    , prompt = ""
    , presign = Nothing
    , extraPresign = Nothing
    }


{-| JSON encoder for a slide.
-}
encodeSlide : Slide -> Encode.Value
encodeSlide slide =
    Encode.object
        [ ( "uuid", Encode.string slide.uuid )
        , ( "extra", Maybe.map Encode.string slide.extra |> Maybe.withDefault Encode.null )
        , ( "prompt", Encode.string slide.prompt )
        ]


{-| JSON encoder for all data of a slide.
-}
encodeSlideAll : Slide -> Encode.Value
encodeSlideAll slide =
    Encode.object
        [ ( "uuid", Encode.string slide.uuid )
        , ( "extra", Maybe.map Encode.string slide.extra |> Maybe.withDefault Encode.null )
        , ( "prompt", Encode.string slide.prompt )
        , ( "presign", Maybe.withDefault Encode.null <| Maybe.map Encode.string slide.presign )
        , ( "extra_presign", Maybe.withDefault Encode.null <| Maybe.map Encode.string slide.extra )
        ]


{-| JSON decoder for a slide.
-}
decodeSlide : Decoder Slide
decodeSlide =
    Decode.map5 Slide
        (Decode.field "uuid" Decode.string)
        (Decode.maybe (Decode.field "extra" Decode.string))
        (Decode.field "prompt" Decode.string)
        (Decode.maybe (Decode.field "presign" Decode.string))
        (Decode.maybe (Decode.field "extra_presign" Decode.string))


{-| Returns the path to the image of the slide.
-}
slidePath : Capsule -> Slide -> String
slidePath capsule slide =
    case slide.presign of
        Just u ->
            u

        Nothing ->
            assetPath capsule (slide.uuid ++ ".webp")


{-| Returns the path to the extra resource of a slide.
-}
extraPath : Capsule -> Slide -> Maybe String
extraPath capsule slide =
    case ( slide.extraPresign, slide.extra ) of
        ( Just url, _ ) ->
            Just url

        ( _, Just extra ) ->
            Just <| assetPath capsule (extra ++ ".mp4")

        _ ->
            Nothing


{-| Returns the path the the video record of a gos.
-}
recordPath : Capsule -> Gos -> Maybe String
recordPath capsule gos =
    case ( Maybe.andThen .presign gos.record, gos.record ) of
        ( Just url, _ ) ->
            Just url

        ( _, Just record ) ->
            Just <| assetPath capsule (record.uuid ++ ".webm")

        _ ->
            Nothing


{-| Returns the path to the pointer record of a gos.
-}
pointerPath : Capsule -> Gos -> Maybe String
pointerPath capsule gos =
    case ( Maybe.andThen .pointerPresign gos.record, Maybe.andThen .pointerUuid gos.record ) of
        ( Just url, _ ) ->
            Just url

        ( _, Just pointerUuid ) ->
            Just <| assetPath capsule (pointerUuid ++ ".webm")

        _ ->
            Nothing


{-| Returns the path of the first record of a capsule.
-}
firstRecordPath : Capsule -> Maybe String
firstRecordPath capsule =
    case capsule.structure of
        gos :: goss ->
            case gos.record of
                Just r ->
                    recordPath capsule gos

                Nothing ->
                    firstRecordPath { capsule | structure = goss }

        [] ->
            Nothing


{-| Returns the path to the video file of a produced capsule.

Returns Nothing if the capsule hasn't been produced yet.

-}
capsuleVideoPath : Capsule -> Maybe String
capsuleVideoPath capsule =
    case ( capsule.produced, capsule.producedHash, capsule.outputPresign ) of
        ( Data.Done, _, Just url ) ->
            Just url

        ( Data.Done, Just hash, _ ) ->
            Just ("/data/" ++ capsule.id ++ "/produced/capsule.mp4?v=" ++ hash)

        _ ->
            Nothing


{-| Returns the path to the video file of a produced GOS.

Return Nothing if the GOS hasn't been produced yet.

-}
gosVideoPath : Capsule -> Gos -> Maybe String
gosVideoPath capsule gos =
    case ( gos.produced, gos.producedHash, gos.producedPresign ) of
        ( Data.Done, _, Just url ) ->
            Just url

        ( Data.Done, Just hash, _ ) ->
            Just ("/data/" ++ capsule.id ++ "/produced/" ++ hash ++ ".mp4")

        _ ->
            Nothing


{-| Returns the path to the track of a capsule.

Returns Nothing if the capsule doesn't have a track.

-}
trackPath : Capsule -> Maybe String
trackPath capsule =
    case ( capsule.soundTrackPresign, capsule.soundTrack ) of
        ( Just url, Just _ ) ->
            Just url

        ( _, Just track ) ->
            Just <| assetPath capsule (track.uuid ++ ".m4a")

        _ ->
            Nothing


{-| Returns the path to the track preview of a capsule.

Returns Nothing if the capsule doesn't have a track.

-}
trackPreviewPath : Capsule -> Maybe String
trackPreviewPath capsule =
    case capsule.soundTrack of
        Just _ ->
            Just <| assetPath capsule "trackPreview.m4a"

        _ ->
            Nothing


{-| Removes a specific slide from a capsule.
-}
deleteSlide : Slide -> Capsule -> Capsule
deleteSlide slide capsule =
    let
        gosMapper : Gos -> Gos
        gosMapper gos =
            { gos
                | slides = List.filter (\x -> x.uuid /= slide.uuid) gos.slides
                , record =
                    if List.any (\x -> x.uuid == slide.uuid) gos.slides then
                        Nothing

                    else
                        gos.record
            }

        newStructure : List Gos
        newStructure =
            capsule.structure
                |> List.map gosMapper
                |> List.filter (\x -> x.slides /= [])
    in
    { capsule | structure = newStructure }


{-| Removes a specific extra from a slide.
-}
deleteExtra : Slide -> Capsule -> Capsule
deleteExtra slide capsule =
    let
        gosMapper : Gos -> Gos
        gosMapper gos =
            { gos | record = Nothing, slides = List.map (\x -> Utils.tern (x.uuid == slide.uuid) { x | extra = Nothing } x) gos.slides }
    in
    { capsule | structure = List.map gosMapper capsule.structure }


{-| Updates a specific slide in a gos.
-}
updateSlideInGos : Slide -> Gos -> Gos
updateSlideInGos slide gos =
    { gos | slides = List.map (\x -> Utils.tern (x.uuid == slide.uuid) slide x) gos.slides }


{-| Updates a specific slide in a capsule.
-}
updateSlide : Slide -> Capsule -> Capsule
updateSlide slide capsule =
    { capsule | structure = List.map (updateSlideInGos slide) capsule.structure }


{-| Updates a specific gos in a capsule.
-}
updateGos : Int -> Gos -> Capsule -> Capsule
updateGos id gos capsule =
    let
        newStructure =
            List.take id capsule.structure ++ (gos :: List.drop (id + 1) capsule.structure)
    in
    { capsule | structure = newStructure }


{-| This type represents a record done by a webcam.
-}
type alias Record =
    { uuid : String
    , pointerUuid : Maybe String
    , size : Maybe ( Int, Int )
    , presign : Maybe String
    , pointerPresign : Maybe String
    , miniaturePresign : Maybe String
    }


{-| Returns the path to the miniature of the record.
-}
miniaturePath : Capsule -> Record -> Maybe String
miniaturePath capsule record =
    case ( record.size, record.miniaturePresign ) of
        ( Nothing, _ ) ->
            Nothing

        ( _, Just url ) ->
            Just url

        _ ->
            Just <| assetPath capsule (record.uuid ++ ".webp")


{-| Empty record.
-}
emptyRecord : Record
emptyRecord =
    { uuid = ""
    , pointerUuid = Nothing
    , size = Nothing
    , presign = Nothing
    , pointerPresign = Nothing
    , miniaturePresign = Nothing
    }


{-| JSON encoder for record.
-}
encodeRecord : Maybe Record -> Encode.Value
encodeRecord record =
    case record of
        Just r ->
            Encode.object
                [ ( "uuid", Encode.string r.uuid )
                , ( "pointer_uuid", r.pointerUuid |> Maybe.map Encode.string |> Maybe.withDefault Encode.null )
                , ( "size", r.size |> Maybe.map (encodePair Encode.int) |> Maybe.withDefault Encode.null )
                ]

        Nothing ->
            Encode.null


{-| JSON encoder for all of record data.
-}
encodeRecordAll : Maybe Record -> Encode.Value
encodeRecordAll record =
    case record of
        Just r ->
            Encode.object
                [ ( "uuid", Encode.string r.uuid )
                , ( "pointer_uuid", r.pointerUuid |> Maybe.map Encode.string |> Maybe.withDefault Encode.null )
                , ( "size", r.size |> Maybe.map (encodePair Encode.int) |> Maybe.withDefault Encode.null )
                , ( "presign", Maybe.withDefault Encode.null <| Maybe.map Encode.string r.presign )
                , ( "pointer_presign", Maybe.withDefault Encode.null <| Maybe.map Encode.string r.pointerPresign )
                ]

        Nothing ->
            Encode.null


{-| JSON decoder for record.
-}
decodeRecord : Decoder Record
decodeRecord =
    Decode.map6 Record
        (Decode.field "uuid" Decode.string)
        (Decode.maybe (Decode.field "pointer_uuid" Decode.string))
        (Decode.maybe (Decode.field "size" (decodePair Decode.int)))
        (Decode.maybe (Decode.field "presign" Decode.string))
        (Decode.maybe (Decode.field "pointer_presign" Decode.string))
        (Decode.maybe (Decode.field "miniature_presign" Decode.string))


{-| JSON encoder for any pair.
-}
encodePair : (a -> Encode.Value) -> ( a, a ) -> Encode.Value
encodePair encoder ( x, y ) =
    Encode.list encoder [ x, y ]


{-| JSON decoder for a pair of int.
-}
decodePair : Decoder a -> Decoder ( a, a )
decodePair decoder =
    Decode.map2 Tuple.pair
        (Decode.index 0 decoder)
        (Decode.index 1 decoder)


{-| This type represents the different events that can occur during a record session.
-}
type EventType
    = Start
    | NextSlide
    | PreviousSlide
    | NextSentence
    | Play Int
    | Pause Int
    | Stop
    | End


{-| Converts the event type to a string.
-}
eventTypeToString : EventType -> String
eventTypeToString e =
    case e of
        Start ->
            "start"

        NextSlide ->
            "next_slide"

        PreviousSlide ->
            "previous_slide"

        NextSentence ->
            "next_sentence"

        Play _ ->
            "play"

        Pause _ ->
            "pause"

        Stop ->
            "stop"

        End ->
            "end"


{-| JSON encoder for event types.
-}
encodeEventType : EventType -> Encode.Value
encodeEventType e =
    Encode.string (eventTypeToString e)


{-| JSON decoder for event types.
-}
decodeEventType : Maybe Int -> Decoder EventType
decodeEventType extraTime =
    Decode.string
        |> Decode.andThen
            (\str ->
                case ( str, extraTime ) of
                    ( "start", _ ) ->
                        Decode.succeed Start

                    ( "next_slide", _ ) ->
                        Decode.succeed NextSlide

                    ( "previous_slide", _ ) ->
                        Decode.succeed PreviousSlide

                    ( "next_sentence", _ ) ->
                        Decode.succeed NextSentence

                    ( "play", Just e ) ->
                        Decode.succeed (Play e)

                    ( "play", _ ) ->
                        Decode.fail "Play event must have an extra time"

                    ( "pause", Just e ) ->
                        Decode.succeed (Pause e)

                    ( "pause", _ ) ->
                        Decode.fail "Pause event must have an extra time"

                    ( "stop", _ ) ->
                        Decode.succeed Stop

                    ( "end", _ ) ->
                        Decode.succeed End

                    ( x, _ ) ->
                        Decode.fail <| "Unknown event type: " ++ x
            )


{-| This type represents what events occured and when.
-}
type alias Event =
    { ty : EventType
    , time : Int
    }


{-| JSON encoder for events.
-}
encodeEvent : Event -> Encode.Value
encodeEvent e =
    case e.ty of
        Play extraTime ->
            Encode.object
                [ ( "ty", encodeEventType e.ty )
                , ( "time", Encode.int e.time )
                , ( "extra_time", Encode.int extraTime )
                ]

        Pause extraTime ->
            Encode.object
                [ ( "ty", encodeEventType e.ty )
                , ( "time", Encode.int e.time )
                , ( "extra_time", Encode.int extraTime )
                ]

        _ ->
            Encode.object
                [ ( "ty", encodeEventType e.ty )
                , ( "time", Encode.int e.time )
                ]


{-| JSON decoder for events.
-}
decodeEvent : Decoder Event
decodeEvent =
    Decode.maybe (Decode.field "extra_time" Decode.int)
        |> Decode.andThen
            (\e ->
                Decode.map2 Event
                    (Decode.field "ty" (decodeEventType e))
                    (Decode.field "time" Decode.int)
            )


{-| Anchor to which a record is attached in production.
-}
type Anchor
    = BottomLeft
    | BottomRight
    | TopLeft
    | TopRight


{-| JSON encoder for anchors.
-}
encodeAnchor : Anchor -> Encode.Value
encodeAnchor anchor =
    Encode.string
        (case anchor of
            BottomLeft ->
                "bottom_left"

            BottomRight ->
                "bottom_right"

            TopLeft ->
                "top_left"

            TopRight ->
                "top_right"
        )


{-| JSON decoder for anchors.
-}
decodeAnchor : Decoder Anchor
decodeAnchor =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "bottom_left" ->
                        Decode.succeed BottomLeft

                    "bottom_right" ->
                        Decode.succeed BottomRight

                    "top_left" ->
                        Decode.succeed TopLeft

                    "top_right" ->
                        Decode.succeed TopRight

                    x ->
                        Decode.fail <| "Unknown anchor: " ++ x
            )


{-| The settings of the placement of a webcam in production.
-}
type WebcamSettings
    = Disabled
    | Fullscreen
        { opacity : Float
        , keycolor : Maybe String
        }
    | Pip
        { anchor : Anchor
        , opacity : Float
        , position : ( Int, Int )
        , size : Int
        , keycolor : Maybe String
        }


{-| Sets the size of the webcam settings.

Nothing means fullscreen.

-}
setWebcamSettingsSize : Maybe Int -> WebcamSettings -> WebcamSettings
setWebcamSettingsSize size settings =
    let
        default =
            Maybe.map defaultPip size |> Maybe.withDefault (defaultPip 0)
    in
    case size of
        Just s ->
            case settings of
                Disabled ->
                    defaultWebcamSettings s

                Fullscreen { opacity, keycolor } ->
                    Pip { default | opacity = opacity, keycolor = keycolor }

                Pip pip ->
                    Pip { pip | size = s }

        Nothing ->
            case settings of
                Disabled ->
                    Fullscreen { opacity = default.opacity, keycolor = default.keycolor }

                Fullscreen _ ->
                    settings

                Pip { opacity, keycolor } ->
                    Fullscreen { opacity = opacity, keycolor = keycolor }


{-| JSON encoder for webcam settings.
-}
encodeWebcamSettings : WebcamSettings -> Encode.Value
encodeWebcamSettings settings =
    case settings of
        Disabled ->
            Encode.object [ ( "type", Encode.string "disabled" ) ]

        Fullscreen { opacity, keycolor } ->
            Encode.object
                [ ( "type", Encode.string "fullscreen" )
                , ( "opacity", Encode.float opacity )
                , ( "keycolor", Maybe.withDefault Encode.null (Maybe.map Encode.string keycolor) )
                ]

        Pip { anchor, position, size, opacity, keycolor } ->
            Encode.object
                [ ( "type", Encode.string "pip" )
                , ( "anchor", encodeAnchor anchor )
                , ( "position", encodePair Encode.int position )
                , ( "size", Encode.list Encode.int [ size, 9 * size // 16 ] )
                , ( "opacity", Encode.float opacity )
                , ( "keycolor", Maybe.withDefault Encode.null (Maybe.map Encode.string keycolor) )
                ]


{-| JSON decoder for the Pip attributes of webcam settings.
-}
decodePip : Decoder { anchor : Anchor, opacity : Float, position : ( Int, Int ), size : Int, keycolor : Maybe String }
decodePip =
    Decode.map5 (\a o p s k -> { anchor = a, opacity = o, position = p, size = s, keycolor = k })
        (Decode.field "anchor" decodeAnchor)
        (Decode.field "opacity" Decode.float)
        (Decode.field "position" (decodePair Decode.int))
        (Decode.field "size" (Decode.map Tuple.first (decodePair Decode.int)))
        (Decode.maybe (Decode.field "keycolor" Decode.string))


{-| Default pip settings.
-}
defaultPip :
    Int
    ->
        { anchor : Anchor
        , keycolor : Maybe a
        , opacity : Float
        , position : ( Int, Int )
        , size : Int
        }
defaultPip size =
    { anchor = BottomLeft
    , keycolor = Nothing
    , opacity = 1.0
    , position = ( 0, 0 )
    , size = size
    }


{-| Default webcam settings.
-}
defaultWebcamSettings : Int -> WebcamSettings
defaultWebcamSettings size =
    Pip
        { anchor = BottomLeft
        , keycolor = Nothing
        , opacity = 1.0
        , position = ( 0, 0 )
        , size = size
        }


{-| JSON decoder for the fullscreen attributs of webcam settings.
-}
decodeFullscreen : Decoder { opacity : Float, keycolor : Maybe String }
decodeFullscreen =
    Decode.map2 (\o k -> { opacity = o, keycolor = k })
        (Decode.field "opacity" Decode.float)
        (Decode.maybe (Decode.field "keycolor" Decode.string))


{-| JSON decoder for webcam settings.
-}
decodeWebcamSettings : Decoder WebcamSettings
decodeWebcamSettings =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\x ->
                case x of
                    "disabled" ->
                        Decode.succeed Disabled

                    "fullscreen" ->
                        Decode.map Fullscreen decodeFullscreen

                    "pip" ->
                        Decode.map Pip decodePip

                    _ ->
                        Decode.fail ("Unknown webcam settings type " ++ x)
            )


{-| This type represents the different types of fading that have been activated on video record.
-}
type alias Fade =
    { vfadein : Maybe Int
    , vfadeout : Maybe Int
    , afadein : Maybe Int
    , afadeout : Maybe Int
    }


{-| JSON encoder for fade attributes.
-}
encodeFade : Fade -> Encode.Value
encodeFade f =
    Encode.object
        [ ( "vfadein", Maybe.withDefault Encode.null (Maybe.map Encode.int f.vfadein) )
        , ( "vfadeout", Maybe.withDefault Encode.null (Maybe.map Encode.int f.vfadeout) )
        , ( "afadein", Maybe.withDefault Encode.null (Maybe.map Encode.int f.afadein) )
        , ( "afadeout", Maybe.withDefault Encode.null (Maybe.map Encode.int f.afadeout) )
        ]


{-| JSON decoder for fade attributes.
-}
decodeFade : Decoder Fade
decodeFade =
    Decode.map4 Fade
        (Decode.maybe (Decode.field "vfadein" Decode.int))
        (Decode.maybe (Decode.field "vfadeout" Decode.int))
        (Decode.maybe (Decode.field "afadein" Decode.int))
        (Decode.maybe (Decode.field "afadeout" Decode.int))


{-| The default fade which is no fade at all.
-}
defaultFade : Fade
defaultFade =
    { vfadein = Nothing
    , vfadeout = Nothing
    , afadein = Nothing
    , afadeout = Nothing
    }


{-| This type represents a group of slides (GoS).
-}
type alias Gos =
    { record : Maybe Record
    , slides : List Slide
    , events : List Event
    , webcamSettings : Maybe WebcamSettings
    , fade : Fade
    , producedHash : Maybe String
    , producedPresign : Maybe String
    , produced : Data.TaskStatus
    }


{-| This is an empty GOS.
-}
emptyGos : Gos
emptyGos =
    { record = Nothing
    , slides = []
    , events = []
    , webcamSettings = Nothing
    , fade = defaultFade
    , producedHash = Nothing
    , producedPresign = Nothing
    , produced = Data.Idle
    }


{-| JSON encoder for gos.
-}
encodeGos : Gos -> Encode.Value
encodeGos gos =
    Encode.object
        [ ( "record", encodeRecord gos.record )
        , ( "slides", Encode.list encodeSlide gos.slides )
        , ( "events", Encode.list encodeEvent gos.events )
        , ( "webcam_settings"
          , case gos.webcamSettings of
                Just ws ->
                    encodeWebcamSettings ws

                Nothing ->
                    Encode.null
          )
        , ( "fade", encodeFade gos.fade )
        , ( "produced_hash", Maybe.map Encode.string gos.producedHash |> Maybe.withDefault Encode.null )
        , ( "produced", Data.encodeTaskStatus gos.produced )
        ]


{-| JSON encoder for all data of gos.
-}
encodeGosAll : Gos -> Encode.Value
encodeGosAll gos =
    Encode.object
        [ ( "record", encodeRecordAll gos.record )
        , ( "slides", Encode.list encodeSlideAll gos.slides )
        , ( "events", Encode.list encodeEvent gos.events )
        , ( "webcam_settings"
          , case gos.webcamSettings of
                Just ws ->
                    encodeWebcamSettings ws

                Nothing ->
                    Encode.null
          )
        , ( "fade", encodeFade gos.fade )
        , ( "produced_hash", Maybe.map Encode.string gos.producedHash |> Maybe.withDefault Encode.null )
        , ( "produced", Data.encodeTaskStatus gos.produced )
        , ( "produced_presign", Maybe.withDefault Encode.null <| Maybe.map Encode.string gos.producedPresign )
        ]


{-| JSON decoder for gos.
-}
decodeGos : Decoder Gos
decodeGos =
    Decode.map8 Gos
        (Decode.maybe (Decode.field "record" decodeRecord))
        (Decode.field "slides" (Decode.list decodeSlide))
        (Decode.field "events" (Decode.list decodeEvent))
        (Decode.maybe (Decode.field "webcam_settings" decodeWebcamSettings))
        (Decode.field "fade" decodeFade)
        (Decode.maybe (Decode.field "produced_hash" Decode.string))
        (Decode.maybe (Decode.field "produced_presign" Decode.string))
        (Decode.field "produced" Data.decodeTaskStatus)


{-| Creates a gos from only slides.
-}
gosFromSlides : List Slide -> Gos
gosFromSlides slides =
    { record = Nothing
    , slides = slides
    , events = []
    , webcamSettings = Nothing
    , fade = defaultFade
    , producedHash = Nothing
    , producedPresign = Nothing
    , produced = Data.Idle
    }


{-| This type represents a sound track.
-}
type alias SoundTrack =
    { uuid : String
    , name : String
    , volume : Float
    }


{-| JSON encoder for sound track.
-}
encodeSoundTrack : SoundTrack -> Encode.Value
encodeSoundTrack st =
    Encode.object
        [ ( "uuid", Encode.string st.uuid )
        , ( "name", Encode.string st.name )
        , ( "volume", Encode.float st.volume )
        ]


{-| JSON decoder for sound track.
-}
decodeSoundTrack : Decoder SoundTrack
decodeSoundTrack =
    Decode.map3 SoundTrack
        (Decode.field "uuid" Decode.string)
        (Decode.field "name" Decode.string)
        (Decode.field "volume" Decode.float)


{-| Remove the sound track from the capsule.
-}
removeTrack : Capsule -> Capsule
removeTrack capsule =
    { capsule | soundTrack = Nothing }
