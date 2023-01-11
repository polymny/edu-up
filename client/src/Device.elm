port module Device exposing (..)

{-| This module helps us deal with devices (webcams and microphones).
-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A video device, e.g. a webcam.
-}
type alias Video =
    { deviceId : String
    , groupId : String
    , label : String
    , available : Bool
    , resolutions : List Resolution
    }


{-| Encodes a video device.
-}
encodeVideo : Video -> Encode.Value
encodeVideo video =
    Encode.object
        [ ( "deviceId", Encode.string video.deviceId )
        , ( "groupId", Encode.string video.groupId )
        , ( "label", Encode.string video.label )
        , ( "available", Encode.bool video.available )
        , ( "resolutions", Encode.list encodeResolution video.resolutions )
        ]


{-| Decodes a video device.
-}
decodeVideo : Decoder Video
decodeVideo =
    Decode.map5 Video
        (Decode.field "deviceId" Decode.string)
        (Decode.field "groupId" Decode.string)
        (Decode.field "label" Decode.string)
        (Decode.field "available" Decode.bool)
        (Decode.field "resolutions" (Decode.list decodeResolution))


{-| The resolution of a video device.
-}
type alias Resolution =
    { width : Int
    , height : Int
    }


{-| Formats a resolution as a string, e.g. 1920x1080.
-}
formatResolution : Resolution -> String
formatResolution resolution =
    String.fromInt resolution.width ++ "x" ++ String.fromInt resolution.height


{-| Encodes a resolution of a video device.
-}
encodeResolution : Resolution -> Encode.Value
encodeResolution resolution =
    Encode.object
        [ ( "width", Encode.int resolution.width )
        , ( "height", Encode.int resolution.height )
        ]


{-| Decodes a resolution of a video device.
-}
decodeResolution : Decoder Resolution
decodeResolution =
    Decode.map2 Resolution
        (Decode.field "width" Decode.int)
        (Decode.field "height" Decode.int)


{-| An audio device, e.g. a microphone.
-}
type alias Audio =
    { deviceId : String
    , groupId : String
    , label : String
    , available : Bool
    }


{-| Encodes an audio device.
-}
encodeAudio : Audio -> Encode.Value
encodeAudio audio =
    Encode.object
        [ ( "deviceId", Encode.string audio.deviceId )
        , ( "groupId", Encode.string audio.groupId )
        , ( "label", Encode.string audio.label )
        , ( "available", Encode.bool audio.available )
        ]


{-| Decodes an audio device.
-}
decodeAudio : Decoder Audio
decodeAudio =
    Decode.map4 Audio
        (Decode.field "deviceId" Decode.string)
        (Decode.field "groupId" Decode.string)
        (Decode.field "label" Decode.string)
        (Decode.field "available" Decode.bool)


{-| A complete recording device, with video and audio.
-}
type alias Device =
    { video : Maybe ( Video, Resolution )
    , audio : Maybe Audio
    }


{-| Encodes a tuple (Video, Resolution) into a JSON array.
-}
encodeVideoAndResolution : ( Video, Resolution ) -> Encode.Value
encodeVideoAndResolution ( video, resolution ) =
    Encode.list (\x -> x) [ encodeVideo video, encodeResolution resolution ]


{-| Decodes an array of size two giving a video and a resolution.
-}
decodeVideoAndResolution : Decoder ( Video, Resolution )
decodeVideoAndResolution =
    Decode.map2 Tuple.pair
        (Decode.index 0 decodeVideo)
        (Decode.index 1 decodeResolution)


{-| Encodes a device, with audio and video.
-}
encodeDevice : Device -> Encode.Value
encodeDevice device =
    Encode.object
        [ ( "audio", Maybe.map encodeAudio device.audio |> Maybe.withDefault Encode.null )
        , ( "video", Maybe.map encodeVideoAndResolution device.video |> Maybe.withDefault Encode.null )
        ]


{-| Decodes a device, with audio and video.
-}
decodeDevice : Decoder Device
decodeDevice =
    Decode.map2 Device
        (Decode.field "video" (Decode.nullable decodeVideoAndResolution))
        (Decode.field "audio" (Decode.nullable decodeAudio))


{-| Every existing device on the client.
-}
type alias Devices =
    { video : List Video
    , audio : List Audio
    }


{-| Encodes many devices.
-}
encodeDevices : Devices -> Encode.Value
encodeDevices devices =
    Encode.object
        [ ( "video", Encode.list encodeVideo devices.video )
        , ( "audio", Encode.list encodeAudio devices.audio )
        ]


{-| Decodes many devices.
-}
decodeDevices : Decoder Devices
decodeDevices =
    Decode.map2 Devices
        (Decode.field "video" (Decode.list decodeVideo))
        (Decode.field "audio" (Decode.list decodeAudio))


{-| Merges two sets of devices.

The first set needs to be the set that has been detected previously, the second set is the set detected currently.

-}
mergeDevices : Devices -> Devices -> Devices
mergeDevices old new =
    let
        -- Updates the state of the video device (sets the available flag depending on if its has been currently
        -- detected).
        updateVideo : Video -> Video
        updateVideo video =
            case List.filter (\x -> x.deviceId == video.deviceId) new.video of
                [] ->
                    { video | available = False }

                _ ->
                    { video | available = True }

        -- Same thing with audio
        updateAudio : Audio -> Audio
        updateAudio audio =
            case List.filter (\x -> x.deviceId == audio.deviceId) new.audio of
                [] ->
                    { audio | available = False }

                _ ->
                    { audio | available = True }

        oldVideos =
            List.map updateVideo old.video

        oldAudios =
            List.map updateAudio old.audio

        -- Filters the new video devices that are already in the old video devices.
        filterNewVideo : Video -> Bool
        filterNewVideo video =
            List.all (\x -> x.deviceId /= video.deviceId) old.video

        -- Same for audio.
        filterNewAudio : Audio -> Bool
        filterNewAudio audio =
            List.all (\x -> x.deviceId /= audio.deviceId) old.audio

        newVideos =
            List.filter filterNewVideo new.video

        newAudios =
            List.filter filterNewAudio new.audio
    in
    { video = oldVideos ++ newVideos
    , audio = oldAudios ++ newAudios
    }


{-| Finds the right device to use given a device configuration.
-}
getDevice : Devices -> Maybe Device -> Device
getDevice devices untrustedPreferredDevice =
    let
        preferredDevice =
            Maybe.map (updateAvailable devices) untrustedPreferredDevice

        audio : Maybe Audio
        audio =
            case Maybe.map .audio preferredDevice of
                Just (Just a) ->
                    if a.available then
                        Just a

                    else
                        devices.audio
                            |> List.filter .available
                            |> List.head

                Just Nothing ->
                    Nothing

                _ ->
                    devices.audio
                        |> List.filter .available
                        |> List.head

        -- Finds the resolution of a video if a resolution is avaible, returns Nothing otherwise.
        findResolution : Video -> Maybe ( Video, Resolution )
        findResolution inputVideo =
            List.head inputVideo.resolutions |> Maybe.map (\resolution -> ( inputVideo, resolution ))

        video : Maybe ( Video, Resolution )
        video =
            case Maybe.map .video preferredDevice of
                Just (Just ( v, r )) ->
                    if v.available then
                        Just ( v, r )

                    else
                        devices.video
                            |> List.filter .available
                            |> List.head
                            |> Maybe.andThen findResolution

                Just Nothing ->
                    Nothing

                _ ->
                    devices.video
                        |> List.filter .available
                        |> List.head
                        |> Maybe.andThen findResolution
    in
    { audio = audio, video = video }


{-| Encodes the video device as an object representing the attributes that can be given to JavaScript in order to bind
the device.
-}
encodeVideoSettings : Maybe ( Video, Resolution ) -> Encode.Value
encodeVideoSettings video =
    case video of
        Just ( v, r ) ->
            Encode.object
                [ ( "deviceId", Encode.object [ ( "exact", Encode.string v.deviceId ) ] )
                , ( "width", Encode.object [ ( "exact", Encode.int r.width ) ] )
                , ( "height", Encode.object [ ( "exact", Encode.int r.height ) ] )
                ]

        _ ->
            Encode.bool False


{-| Encodes the audio device as an object representing the attributes that can be given to JavaScript in order to bind
the device.
-}
encodeAudioSettings : Maybe Audio -> Encode.Value
encodeAudioSettings audio =
    case audio of
        Just a ->
            Encode.object [ ( "deviceId", Encode.object [ ( "exact", Encode.string a.deviceId ) ] ) ]

        _ ->
            Encode.bool False


{-| Encodes the device as an object representing the attributes that can be given to JavaScript in order to bind the
device.
-}
encodeDeviceSettings : Device -> Encode.Value
encodeDeviceSettings device =
    Encode.object
        [ ( "video", encodeVideoSettings device.video )
        , ( "audio", encodeAudioSettings device.audio )
        ]


{-| Encode the recording settings of the device as an object that can be given to JavaScript in order to record the
device.
-}
encodeRecordingSettings : Device -> Encode.Value
encodeRecordingSettings device =
    case ( device.video, device.audio ) of
        ( Just _, Just _ ) ->
            Encode.object
                [ ( "videoBitsPerSecond", Encode.int 2500000 )
                , ( "audioBitsPerSecond", Encode.int 128000 )
                , ( "mimeType", Encode.string "video/webm;codecs=opus,vp8" )
                ]

        ( Nothing, Just _ ) ->
            Encode.object
                [ ( "audioBitsPerSecond", Encode.int 128000 )
                , ( "mimeType", Encode.string "video/webm;codecs=opus" )
                ]

        ( Just _, Nothing ) ->
            Encode.object
                [ ( "videoBitsPerSecond", Encode.int 2500000 )
                , ( "mimeType", Encode.string "video/webm;codecs=vp8" )
                ]

        _ ->
            Encode.object []


{-| Encodes the full settings that can be given to JavaScript in order to bind the device and setup the recording.
-}
encodeSettings : Device -> Encode.Value
encodeSettings device =
    Encode.object
        [ ( "device", encodeDeviceSettings device )
        , ( "recording", encodeRecordingSettings device )
        ]


{-| Changes the available flag of the device depending on whether or not it is detected in the devices list.
-}
updateAvailable : Devices -> Device -> Device
updateAvailable devices device =
    let
        a =
            case device.audio of
                Just audio ->
                    case List.filter (\x -> x.deviceId == audio.deviceId) devices.audio of
                        [] ->
                            Just { audio | available = False }

                        h :: _ ->
                            Just h

                Nothing ->
                    Nothing

        v =
            case device.video of
                Just ( video, resolution ) ->
                    case List.filter (\x -> x.deviceId == video.deviceId) devices.video of
                        [] ->
                            Just ( { video | available = False }, resolution )

                        h :: _ ->
                            Just ( { video | available = h.available }, resolution )

                Nothing ->
                    Nothing
    in
    { audio = a, video = v }


{-| Triggers a full detection of every device.
-}
port detectDevicesPort : () -> Cmd msg


detectDevices : Cmd msg
detectDevices =
    detectDevicesPort ()


{-| Port where the javascript send the detected devices after detectDevices.
-}
port detectDevicesResponse : (Encode.Value -> msg) -> Sub msg


{-| Binds a device.
-}
bindDevice : Device -> Cmd msg
bindDevice device =
    bindDevicePort (encodeSettings device)


{-| Port where the device is bound.
-}
port bindDevicePort : Encode.Value -> Cmd msg
