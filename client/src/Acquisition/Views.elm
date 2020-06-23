module Acquisition.Views exposing (view)

import Acquisition.Types as Acquisition
import Api
import Core.Types as Core
import Element exposing (Element)
import Html
import Html.Attributes
import LoggedIn.Types as LoggedIn
import Ui.Ui as Ui
import Utils


view : Core.Global -> Api.Session -> Acquisition.Model -> Element Core.Msg
view _ _ model =
    let
        mainPage =
            mainView model

        element =
            Element.column
                Ui.mainViewAttributes2
                [ Utils.headerView "acquisition" model.details
                , mainPage
                ]
    in
    Element.row Ui.mainViewAttributes1
        [ element ]


mainView : Acquisition.Model -> Element Core.Msg
mainView model =
    let
        nextButton =
            case model.slides of
                Just x ->
                    case List.length x of
                        0 ->
                            Element.none

                        1 ->
                            Element.none

                        _ ->
                            nextSlideButton

                Nothing ->
                    Element.none
    in
    Element.column [ Element.spacing 10, Element.width Element.fill ]
        [ topView model
        , Element.row [ Element.centerX, Element.spacing 10 ] [ recordingButton model.recording, nextButton ]
        , recordingsView model.records model.currentStream
        , uploadView model.details.capsule.id model.gos model.currentStream
        ]


topView : Acquisition.Model -> Element Core.Msg
topView model =
    Element.row [ Element.centerX, Element.width Element.fill, Element.spacing 20 ]
        [ videoView
        , case List.head (List.drop model.currentSlide (Maybe.withDefault [] model.slides)) of
            Just h ->
                Element.image
                    [ Element.width (Element.px 640)
                    , Element.height (Element.px 480)
                    , Element.centerX
                    ]
                    { src = h.asset.asset_path, description = "Slide" }

            _ ->
                Element.none
        ]


videoView : Element Core.Msg
videoView =
    Element.el [ Element.centerX ] (Element.html (Html.video [ Html.Attributes.id elementId ] []))


recordingButton : Bool -> Element Core.Msg
recordingButton recording =
    let
        ( button, text, msg ) =
            if recording then
                ( Ui.stopRecordButton, "Stop recording", Acquisition.StopRecording )

            else
                ( Ui.startRecordButton, "Start recording", Acquisition.StartRecording )
    in
    button (Just (Core.LoggedInMsg (LoggedIn.AcquisitionMsg msg))) text


nextSlideButton : Element Core.Msg
nextSlideButton =
    Ui.simpleButton (Just (Core.LoggedInMsg (LoggedIn.AcquisitionMsg (Acquisition.NextSlide True)))) "Next slide"


recordingsView : List Acquisition.Record -> Int -> Element Core.Msg
recordingsView n current =
    let
        texts : List String
        texts =
            "Webcam" :: List.map (\x -> "Enregistrement " ++ String.fromInt x) (List.range 1 (List.length n))

        msg : Int -> Core.Msg
        msg i =
            Core.LoggedInMsg (LoggedIn.AcquisitionMsg (Acquisition.GoToStream i))
    in
    Element.column [ Element.padding 10, Element.spacing 10 ]
        [ Element.text "Enregistrments : "
        , Element.row [ Element.spacing 10 ]
            (List.indexedMap
                (\i ->
                    \x ->
                        if current == i then
                            Ui.successButton (Just (msg i)) x

                        else
                            Ui.simpleButton (Just (msg i)) x
                )
                texts
            )
        ]


uploadView : Int -> Int -> Int -> Element Core.Msg
uploadView capsuleId gosId stream =
    if stream == 0 then
        Element.none

    else
        Ui.successButton (Just (Acquisition.UploadStream (url capsuleId gosId) stream)) "Valider"
            |> Element.map LoggedIn.AcquisitionMsg
            |> Element.map Core.LoggedInMsg



-- CONSTANTS


url : Int -> Int -> String
url capsuleId gosId =
    "/api/capsule/" ++ String.fromInt capsuleId ++ "/" ++ String.fromInt gosId ++ "/upload_record"


elementId : String
elementId =
    "video"
