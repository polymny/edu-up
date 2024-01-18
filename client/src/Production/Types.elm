module Production.Types exposing (..)

{-| This module contains the production page of the app.
-}

import Data.Capsule as Data exposing (Capsule)


{-| Model type of the production page.
-}
type alias Model a b =
    { capsule : a
    , gos : b
    , webcamPosition : ( Float, Float )
    , webcamSize : Maybe Int -- Nothing means empty string means 1px
    , holdingImage : Maybe ( Int, Float, Float )
    }


{-| Changes the capsule id and the gos id into the real capsule and real gos.
-}
withCapsuleAndGos : Capsule -> Data.Gos -> Model String Int -> Model Capsule Data.Gos
withCapsuleAndGos capsule gos model =
    { capsule = capsule
    , gos = gos
    , webcamPosition = model.webcamPosition
    , webcamSize = model.webcamSize
    , holdingImage = model.holdingImage
    }


{-| Initializes a model from the capsule and gos is.
-}
init : Int -> Capsule -> Maybe ( Model String Int, Cmd Msg )
init gos capsule =
    case List.drop gos capsule.structure of
        head :: _ ->
            let
                maxWidth =
                    head.record
                        |> Maybe.andThen .size
                        |> Maybe.withDefault ( 1, 1 )
                        |> Tuple.mapBoth toFloat toFloat
                        |> (\( w, h ) -> round <| (w / h) * 1920 / (16 / 9))

                ( webcamPosition, webcamSize ) =
                    case ( head.webcamSettings, capsule.defaultWebcamSettings ) of
                        ( Just (Data.Pip { position, size }), _ ) ->
                            ( Tuple.mapBoth toFloat toFloat position, Just size )

                        ( Nothing, Data.Pip { position, size } ) ->
                            ( Tuple.mapBoth toFloat toFloat position, Just size )

                        _ ->
                            ( ( 0.0, 0.0 ), Just maxWidth )
            in
            Just
                ( { capsule = capsule.id
                  , gos = gos
                  , webcamPosition = webcamPosition
                  , webcamSize = webcamSize
                  , holdingImage = Nothing
                  }
                , Cmd.none
                )

        _ ->
            Nothing


{-| Message type of the app.
-}
type Msg
    = ImageMoved Float Float Float Float
    | HoldingImageChanged (Maybe ( Int, Float, Float ))
    | Produce
    | ProduceGos
    | ResetOptions
    | WebcamSettingsMsg WebcamSettingsMsg
    | ToggleFoldable String


{-| All messages that change the webcam settings.
-}
type WebcamSettingsMsg
    = Noop
    | ToggleVideo
    | SetFullscreen
    | SetWidth (Maybe Int) -- Nothing empty string means 1px
    | SetAnchor Data.Anchor
    | SetOpacity Float


{-| Changes the height preserving aspect ratio.
-}
setHeight : Int -> ( Int, Int ) -> Int
setHeight newHeight ( width, height ) =
    width * newHeight // height


{-| Get the height preserving aspect ratio.
-}
getHeight : ( Int, Int ) -> Int -> Int
getHeight ( width, height ) size =
    height * size // width


{-| The ID of the miniature of the webcam.
-}
miniatureId : String
miniatureId =
    "webcam-miniature"


{-| Get webcam settings from the gos and model.
-}
getWebcamSettings : Data.Capsule -> Data.Gos -> Data.WebcamSettings
getWebcamSettings capsule gos =
    let
        -- Get default size
        defaultSize =
            case capsule.defaultWebcamSettings of
                Data.Pip s ->
                    s.size

                _ ->
                    1

        -- Get webcam settings
        webcamSettings =
            case gos.webcamSettings of
                Just s ->
                    s

                Nothing ->
                    -- Create webcam settings from default with good size
                    case capsule.defaultWebcamSettings of
                        Data.Pip s ->
                            Data.Pip
                                { anchor = s.anchor
                                , keycolor = s.keycolor
                                , opacity = s.opacity
                                , position = s.position
                                , size = defaultSize
                                }

                        _ ->
                            capsule.defaultWebcamSettings
    in
    webcamSettings
