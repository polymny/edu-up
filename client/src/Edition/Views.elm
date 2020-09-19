module Edition.Views exposing (view)

import Api
import Core.Types as Core
import Edition.Types as Edition
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes
import LoggedIn.Types as LoggedIn
import Preparation.Views as Preparation
import Status
import Ui.Attributes as Attributes
import Ui.Colors as Colors
import Ui.Ui as Ui
import Utils
import Webcam



--view : Core.Global -> Api.Session -> Edition.Model -> Element Core.Msg
--view global _ model =
--    let
--        mainPage =
--            mainView global model
--
--        element =
--            Element.column Ui.mainViewAttributes2
--                [ Utils.headerView "edition" model.details
--                , mainPage
--                ]
--    in
--    Element.row Ui.mainViewAttributes1
--
--[ element ]


view : Core.Global -> Api.Session -> Edition.Model -> Element Core.Msg
view global _ model =
    Element.row [ Element.width Element.fill, Element.height Element.fill, Element.scrollbarY ]
        [ Preparation.leftColumnView model.details
        , centerView global model
        ]


centerView : Core.Global -> Edition.Model -> Element Core.Msg
centerView global model =
    let
        gos =
            List.head (List.drop model.currentGos model.details.structure)
    in
    Element.column [ Element.width (Element.fillPortion 6), Element.height Element.fill ]
        [ -- capsuleProductionView global model
          gosProductionView model gos
        ]


gosProductionView : Edition.Model -> Maybe Api.Gos -> Element Core.Msg
gosProductionView model gos =
    let
        resultView =
            case gos of
                Just g ->
                    Element.row
                        [ Element.width Element.fill
                        , Element.height Element.fill
                        ]
                        [ gosProductionChoicesView model
                        , gosPrevisualisation model
                        ]

                Nothing ->
                    Element.none
    in
    resultView


slidesView : List Api.Slide -> Element Core.Msg
slidesView slides =
    Element.row []
        (List.map (\x -> Element.el [ Element.padding 2 ] <| Element.text <| String.fromInt x.id) slides)


capsuleProductionView : Core.Global -> Edition.Model -> Element Core.Msg
capsuleProductionView global model =
    let
        details =
            model.details

        status =
            model.status

        video =
            case details.video of
                Just x ->
                    Element.el
                        [ Border.color Colors.artEvening
                        , Border.rounded 0
                        , Border.width 2
                        , Element.padding 2
                        , Element.centerX
                        , Element.centerY
                        ]
                    <|
                        Element.html <|
                            htmlVideo x.asset_path

                Nothing ->
                    Element.el [] <| Element.text "Pas de vidéo éditée pour l'instant"

        url_video : Api.Asset -> String
        url_video asset =
            global.videoRoot ++ "/?v=" ++ asset.uuid ++ "/"

        button =
            case ( details.capsule.published, details.video ) of
                ( Api.NotPublished, Just _ ) ->
                    Ui.primaryButton (Just Edition.PublishVideo) "Publier la vidéo"
                        |> Element.map LoggedIn.EditionMsg
                        |> Element.map Core.LoggedInMsg

                ( Api.Publishing, _ ) ->
                    Ui.messageWithSpinner "Publication de vidéo en cours..."

                ( Api.Published, Just v ) ->
                    Element.column
                        (Attributes.boxAttributes
                            ++ [ Element.spacing 20 ]
                        )
                        [ Element.newTabLink
                            [ Element.centerX
                            ]
                            { url = url_video v
                            , label = Ui.primaryButton Nothing "Voir la vidéo publiée"
                            }
                        , Element.text "Lien vers la vidéo publiée : "
                        , Element.el
                            [ Background.color Colors.white
                            , Border.color Colors.whiteDarker
                            , Border.rounded 5
                            , Border.width 1
                            , Element.paddingXY 10 10
                            , Attributes.fontMono
                            ]
                          <|
                            Element.text <|
                                url_video v
                        ]

                ( _, _ ) ->
                    Element.none

        ( element, publishButton ) =
            case status of
                Status.Sent ->
                    ( Ui.messageWithSpinner "Edition automatique en cours", Element.none )

                Status.Success () ->
                    ( video, button )

                Status.Error () ->
                    ( Element.text "Problème rencontré lors de la compostion de la vidéo. Merci de nous contacter", Element.none )

                Status.NotSent ->
                    ( video, button )
    in
    Element.row []
        [ editionOptionView model
        , Element.column
            [ Element.centerX, Element.spacing 20, Element.padding 10 ]
            [ element
            , publishButton
            ]
        ]


gosProductionChoicesView : Edition.Model -> Element Core.Msg
gosProductionChoicesView model =
    let
        p : Api.CapsuleEditionOptions
        p =
            let
                stucture =
                    List.head (List.drop model.currentGos model.details.structure)

                production_choices =
                    case stucture of
                        Just x ->
                            x.production_choices

                        Nothing ->
                            Just Edition.defaultGosProductionChoices
            in
            case production_choices of
                Just x ->
                    x

                Nothing ->
                    Edition.defaultGosProductionChoices

        withVideo =
            p.withVideo

        webcamSize =
            p.webcamSize

        webcamPosition =
            p.webcamPosition

        videoFields =
            [ Input.radio
                [ Element.padding 10
                , Element.spacing 10
                ]
                { onChange = Edition.GosWebcamSizeChanged model.currentGos
                , selected = webcamSize
                , label =
                    Input.labelAbove
                        [ Element.centerX
                        , Font.bold
                        , Element.padding 1
                        ]
                        (Element.text "Taille de l'incrustation webcam:")
                , options =
                    [ Input.option Webcam.Small (Element.text "Petit")
                    , Input.option Webcam.Medium (Element.text "Moyen")
                    , Input.option Webcam.Large (Element.text "Grand")
                    ]
                }
            , Input.radio
                [ Element.padding 10
                , Element.spacing 10
                ]
                { onChange = Edition.GosWebcamPositionChanged model.currentGos
                , selected = webcamPosition
                , label =
                    Input.labelAbove
                        [ Element.centerX
                        , Font.bold
                        , Element.padding 1
                        ]
                        (Element.text "Position de l'incrustation:")
                , options =
                    [ Input.option Webcam.TopLeft (Element.text "En haut à gauche.")
                    , Input.option Webcam.TopRight (Element.text "En haut à droite.")
                    , Input.option Webcam.BottomLeft (Element.text "En bas à gauche.")
                    , Input.option Webcam.BottomRight (Element.text "En bas à droite.")
                    ]
                }
            ]

        commmonFields =
            Input.checkbox []
                { onChange = Edition.GosWithVideoChanged model.currentGos
                , icon = Input.defaultCheckbox
                , checked = withVideo
                , label =
                    Input.labelRight [] <|
                        Element.text <|
                            if withVideo then
                                "L'audio et la vidéo seront utilisés"

                            else
                                "Seul l'audio sera utilisé"
                }

        fields =
            if withVideo then
                commmonFields :: videoFields

            else
                [ commmonFields ]

        header =
            Element.row [ Element.centerX, Font.bold ] [ Element.text "Options d'édition de la vidéo" ]

        form =
            header :: fields
    in
    Element.map Core.LoggedInMsg <|
        Element.map LoggedIn.EditionMsg <|
            Element.column [ Element.alignLeft, Element.padding 10, Element.spacing 30 ]
                form


editionOptionView : Edition.Model -> Element Core.Msg
editionOptionView { status, withVideo, webcamSize, webcamPosition } =
    let
        submitOnEnter =
            case status of
                Status.Sent ->
                    []

                Status.Success () ->
                    []

                _ ->
                    [ Ui.onEnter Edition.OptionsSubmitted ]

        submitButton =
            case status of
                Status.Sent ->
                    Ui.primaryButtonDisabled "en cours ...."

                _ ->
                    Element.el [ Font.center ] <|
                        Ui.primaryButton
                            (Just Edition.OptionsSubmitted)
                            "Valider les options et génerer \n la vidéo de la capsule"

        videoFields =
            [ Input.radio
                [ Element.padding 10
                , Element.spacing 10
                ]
                { onChange = Edition.WebcamSizeChanged
                , selected = Just webcamSize
                , label =
                    Input.labelAbove
                        [ Element.centerX
                        , Font.bold
                        , Element.padding 1
                        ]
                        (Element.text "Taille de l'incrustation webcam:")
                , options =
                    [ Input.option Webcam.Small (Element.text "Petit")
                    , Input.option Webcam.Medium (Element.text "Moyen")
                    , Input.option Webcam.Large (Element.text "Grand")
                    ]
                }
            , Input.radio
                [ Element.padding 10
                , Element.spacing 10
                ]
                { onChange = Edition.WebcamPositionChanged
                , selected = Just webcamPosition
                , label =
                    Input.labelAbove
                        [ Element.centerX
                        , Font.bold
                        , Element.padding 1
                        ]
                        (Element.text "Position de l'incrustation:")
                , options =
                    [ Input.option Webcam.TopLeft (Element.text "En haut à gauche.")
                    , Input.option Webcam.TopRight (Element.text "En haut à droite.")
                    , Input.option Webcam.BottomLeft (Element.text "En bas à gauche.")
                    , Input.option Webcam.BottomRight (Element.text "En bas à droite.")
                    ]
                }
            ]

        commmonFields =
            Input.checkbox []
                { onChange = Edition.WithVideoChanged
                , icon = Input.defaultCheckbox
                , checked = withVideo
                , label =
                    Input.labelRight [] <|
                        Element.text <|
                            if withVideo then
                                "L'audio et la vidéo seront utilisés"

                            else
                                "Seul l'audio sera utilisé"
                }

        fields =
            if withVideo then
                (commmonFields :: videoFields) ++ [ submitButton ]

            else
                [ commmonFields, submitButton ]

        header =
            Element.row [ Element.centerX, Font.bold ] [ Element.text "Options d'édition de la vidéo" ]

        form =
            header :: fields
    in
    Element.map Core.LoggedInMsg <|
        Element.map LoggedIn.EditionMsg <|
            Element.column [ Element.centerX, Element.padding 10, Element.spacing 30 ]
                form


gosPrevisualisation : Edition.Model -> Element Core.Msg
gosPrevisualisation model =
    let
        currentGos : Maybe Api.Gos
        currentGos =
            List.head (List.drop model.currentGos model.details.structure)

        productionChoices : Api.CapsuleEditionOptions
        productionChoices =
            case Maybe.map .production_choices currentGos of
                Just (Just c) ->
                    c

                _ ->
                    Edition.defaultGosProductionChoices

        currentSlide : Maybe Api.Slide
        currentSlide =
            Maybe.withDefault Nothing (Maybe.map (\x -> List.head x.slides) currentGos)

        position : List (Element.Attribute Core.Msg)
        position =
            case ( productionChoices.withVideo, Maybe.withDefault Webcam.BottomLeft productionChoices.webcamPosition ) of
                ( True, Webcam.TopLeft ) ->
                    [ Element.alignTop, Element.alignLeft ]

                ( True, Webcam.TopRight ) ->
                    [ Element.alignTop, Element.alignRight ]

                ( True, Webcam.BottomLeft ) ->
                    [ Element.alignBottom, Element.alignLeft ]

                ( True, Webcam.BottomRight ) ->
                    [ Element.alignBottom, Element.alignRight ]

                _ ->
                    []

        size : Int
        size =
            case ( productionChoices.withVideo, Maybe.withDefault Webcam.Medium productionChoices.webcamSize ) of
                ( True, Webcam.Small ) ->
                    1

                ( True, Webcam.Medium ) ->
                    2

                ( True, Webcam.Large ) ->
                    4

                _ ->
                    0

        inFront : Element Core.Msg
        inFront =
            if productionChoices.withVideo then
                Element.el position
                    (Element.image
                        [ Element.width (Element.px (100 * size)) ]
                        { src = "/dist/silhouette.png", description = "" }
                    )

            else
                Element.none

        currentSlideView : Element Core.Msg
        currentSlideView =
            case currentSlide of
                Just s ->
                    Element.image
                        [ Element.width Element.fill
                        , Element.inFront inFront
                        ]
                        { src = s.asset.asset_path, description = "" }

                _ ->
                    Element.none
    in
    Element.el [ Element.width Element.fill ] currentSlideView


htmlVideo : String -> Html msg
htmlVideo url =
    Html.video
        [ Html.Attributes.controls True
        , Html.Attributes.width 600
        ]
        [ Html.source
            [ Html.Attributes.src url ]
            []
        ]
