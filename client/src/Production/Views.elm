module Production.Views exposing (..)

{-| Views for the production page.
-}

import App.Types as App
import App.Utils as App
import Config exposing (Config)
import Data.Capsule as Data
import Data.Types as Data
import Data.User exposing (User)
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Keyed
import Html
import Html.Attributes
import Html.Events
import Json.Decode as Decode
import Material.Icons as Icons
import Production.Types as Production exposing (getHeight, getWebcamSettings)
import Simple.Animation as Animation exposing (Animation)
import Simple.Animation.Animated as Animated
import Simple.Animation.Property as P
import Simple.Transition as Transition
import Strings
import Ui.Colors as Colors
import Ui.Elements as Ui
import Ui.Utils as Ui
import Utils


{-| The full view of the page.
-}
view : Config -> User -> Production.Model Data.Capsule Data.Gos -> ( Element App.Msg, Element App.Msg, Element App.Msg )
view config user model =
    ( leftColumn
        config
        user
        model.capsule
        model.gos
        model.gos.webcamSettings
        model.webcamSize
    , rightColumn config user model
    , Element.none
    )


{-| The column with the controls of the production settings.
-}
leftColumn : Config -> User -> Data.Capsule -> Data.Gos -> Maybe Data.WebcamSettings -> Maybe Int -> Element App.Msg
leftColumn config user capsule gos webcamSettings webcamSize =
    let
        --- HELPERS ---
        -- Shortcut for lang
        lang =
            config.clientState.lang

        -- Helper to create section titles
        title : String -> Element App.Msg
        title input =
            Element.text input
                |> Element.el [ Font.size 22, Font.bold ]

        -- Video width if pip
        width : Maybe Int
        width =
            case getWebcamSettings capsule gos of
                Data.Pip { size } ->
                    Just size

                _ ->
                    Nothing

        -- Video opacity
        opacity : Float
        opacity =
            case getWebcamSettings capsule gos of
                Data.Pip pip ->
                    pip.opacity

                Data.Fullscreen fullscreen ->
                    fullscreen.opacity

                _ ->
                    1

        -- True if the gos has a record that contains only audio
        audioOnly : Bool
        audioOnly =
            Maybe.map .size gos.record == Just Nothing

        -- Webcam settings of the gos (or default for capsule if nothing)
        realWebcamSettings : Data.WebcamSettings
        realWebcamSettings =
            webcamSettings |> Maybe.withDefault capsule.defaultWebcamSettings

        -- Gives the anchor if the webcam settings is Pip
        anchor : Maybe Data.Anchor
        anchor =
            case getWebcamSettings capsule gos of
                Data.Pip p ->
                    Just p.anchor

                _ ->
                    Nothing

        -- Attributes to show things as disabled
        disableAttr : List (Element.Attribute App.Msg)
        disableAttr =
            [ Font.color Colors.greyFontDisabled
            , Element.htmlAttribute (Html.Attributes.style "cursor" "not-allowed")
            ]

        -- Gives disable attributes if element is disabled
        disableAttrIf : Bool -> List (Element.Attribute App.Msg)
        disableAttrIf disabled =
            if disabled then
                disableAttr

            else
                []

        -- Gives disable attributes and remove msg if element is disabled
        disableIf :
            Bool
            -> (List (Element.Attribute App.Msg) -> { a | onChange : b -> App.Msg } -> Element App.Msg)
            -> List (Element.Attribute App.Msg)
            -> { a | onChange : b -> App.Msg }
            -> Element App.Msg
        disableIf disabled constructor attributes parameters =
            if disabled then
                constructor (disableAttr ++ attributes) { parameters | onChange = \_ -> App.Noop }

            else
                constructor attributes parameters

        -- Helper to make foldable sections.
        foldable : String -> Element App.Msg -> Element App.Msg -> Element App.Msg
        foldable id sectionTitle content =
            Element.column
                [ Ui.s 10, Ui.wf ]
                [ Ui.navigationElement (Ui.Msg <| App.ProductionMsg <| Production.ToggleFoldable id) [] <|
                    Element.row []
                        [ Element.el
                            [ Element.rotate <| degrees -90
                            , Element.htmlAttribute <| Html.Attributes.id ("foldable-icon-" ++ id)
                            , Element.htmlAttribute <| Html.Attributes.style "transition" "rotate 0.1s ease-out"
                            ]
                            (Ui.icon 24 Icons.expand_more)
                        , sectionTitle
                        ]
                , Element.el [ Ui.wf, Ui.pl 12 ] <|
                    Element.el
                        [ Ui.wf
                        , Border.color Colors.greyBorder
                        , Ui.bl 1
                        , Ui.pl 10
                        , Ui.ab
                        , Element.htmlAttribute <| Html.Attributes.id ("foldable-" ++ id)
                        , Element.htmlAttribute <| Html.Attributes.style "overflow" "hidden"
                        , Element.htmlAttribute <| Html.Attributes.style "transition" "height 0.3s ease-in-out"
                        , Element.htmlAttribute <| Html.Attributes.style "height" "0"
                        ]
                        content
                ]

        --- UI ELEMENTS ---
        -- Reset to default options button
        resetButton =
            Ui.secondary
                []
                { label = Element.text <| Strings.stepsProductionResetOptions lang
                , action =
                    case webcamSettings of
                        Just _ ->
                            Ui.Msg <| App.ProductionMsg Production.ResetOptions

                        Nothing ->
                            Ui.None
                }

        -- Info to show if the grain uses default options.
        resetElement =
            case ( webcamSettings, Maybe.andThen .size gos.record ) of
                ( Just _, _ ) ->
                    Element.none

                ( _, Nothing ) ->
                    Element.none

                _ ->
                    Element.column [ Ui.s 10 ]
                        [ Ui.paragraph [] <| Strings.stepsProductionGrainUsesDefaultProductionOptions lang ++ "."
                        , Ui.paragraph [] <| Strings.stepsProductionChangeOptionsBelow lang ++ "."
                        , Ui.paragraph [] <| Strings.stepsProductionChangeOptionsInOptionsTab lang ++ "."
                        ]

        -- Whether the user wants to include the video inside the slides or not
        useVideo =
            (disableIf <| gos.record == Nothing || audioOnly)
                Input.checkbox
                []
                { checked = gos.record /= Nothing && webcamSettings /= Just Data.Disabled
                , icon = Ui.checkbox (gos.record == Nothing || audioOnly)
                , label = Input.labelRight [ Ui.cy ] <| Element.text <| Strings.stepsProductionUseVideo lang
                , onChange = \_ -> App.ProductionMsg <| Production.WebcamSettingsMsg <| Production.ToggleVideo
                }

        -- Text that explains why the user can't use the video (if they can't)
        useVideoInfo =
            case Maybe.map .size gos.record of
                Nothing ->
                    Ui.paragraph [] <| Strings.stepsProductionCantUseVideoBecauseNoRecord lang ++ "."

                Just Nothing ->
                    Ui.paragraph [] <| Strings.stepsProductionCantUserVideoBecauseAudioOnly lang ++ "."

                _ ->
                    Element.none

        -- Whether the webcam size is disabled
        webcamSizeDisabled =
            gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled

        -- Title to introduce webcam size settings.
        webcamSizeTitle =
            title <| Strings.stepsProductionWebcamSize lang

        -- Helper to set the width of the webcam.
        mkSetWidth disabled x =
            if disabled then
                Ui.None

            else
                Ui.Msg <| App.ProductionMsg <| Production.WebcamSettingsMsg <| Production.SetWidth x

        -- Helper to increment the width of the webcam.
        incrementWidth : Int -> Int
        incrementWidth step =
            let
                maxWidth =
                    gos.record
                        |> Maybe.andThen .size
                        |> Maybe.withDefault ( 1, 1 )
                        |> Tuple.mapBoth toFloat toFloat
                        |> (\( w, h ) -> round <| (w / h) * 1920 / (16 / 9))
            in
            case webcamSize of
                Just x ->
                    x + step

                Nothing ->
                    maxWidth + step

        -- Element to control the webcam size.
        webcamSizeText =
            Element.row []
                [ disableIf webcamSizeDisabled
                    Input.text
                    []
                    { label = Input.labelHidden <| Strings.stepsProductionCustom lang
                    , onChange =
                        \x ->
                            case ( x, String.toInt x ) of
                                ( _, Just y ) ->
                                    App.ProductionMsg <| Production.WebcamSettingsMsg <| Production.SetWidth <| Just y

                                ( "", _ ) ->
                                    App.ProductionMsg <| Production.WebcamSettingsMsg <| Production.SetWidth <| Nothing

                                _ ->
                                    App.ProductionMsg <| Production.WebcamSettingsMsg <| Production.Noop
                    , placeholder = Nothing
                    , text = Maybe.map String.fromInt webcamSize |> Maybe.withDefault ""
                    }
                , Element.column []
                    [ Ui.navigationElement
                        (mkSetWidth webcamSizeDisabled <| Just <| incrementWidth 1)
                        []
                        (Ui.icon 25 Icons.expand_less)
                    , Ui.navigationElement
                        (mkSetWidth webcamSizeDisabled <| Just <| incrementWidth -1)
                        []
                        (Ui.icon 25 Icons.expand_more)
                    ]
                ]

        -- Element to choose the webcam size among small, medium, large, fullscreen
        webcamSizeRadio =
            (disableIf <| gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled)
                Input.radio
                [ Ui.s 10 ]
                { label = Input.labelHidden <| Strings.stepsProductionWebcamSize lang
                , onChange =
                    \x ->
                        if x == Nothing then
                            App.ProductionMsg <| Production.WebcamSettingsMsg <| Production.SetFullscreen

                        else
                            App.ProductionMsg <| Production.WebcamSettingsMsg <| Production.SetWidth <| x
                , options =
                    [ Input.optionWith (Just 200) <| Ui.option (gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled) <| Element.text <| Strings.stepsProductionSmall lang
                    , Input.optionWith (Just 400) <| Ui.option (gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled) <| Element.text <| Strings.stepsProductionMedium lang
                    , Input.optionWith (Just 800) <| Ui.option (gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled) <| Element.text <| Strings.stepsProductionLarge lang
                    , Input.optionWith Nothing <| Ui.option (gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled) <| Element.text <| Strings.stepsProductionFullscreen lang
                    , Input.optionWith (Just 533) <| Ui.option (gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled) <| Element.text <| Strings.stepsProductionCustom lang
                    ]
                , selected =
                    case getWebcamSettings capsule gos of
                        Data.Pip { size } ->
                            if List.member size [ 200, 400, 800 ] then
                                Just <| Just <| size

                            else
                                Just <| Just 533

                        Data.Fullscreen _ ->
                            Just Nothing

                        Data.Disabled ->
                            Nothing
                }

        -- Whether the webcam position is disabled
        webcamPositionDisabled =
            gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled

        -- Title to introduce webcam position settings
        webcamPositionTitle =
            title <| Strings.stepsProductionWebcamPosition lang

        -- Element to choose the webcam position among the four corners
        webcamPositionRadio =
            disableIf webcamPositionDisabled
                Input.radio
                [ Ui.s 10 ]
                { label = Input.labelHidden <| Strings.stepsProductionWebcamPosition lang
                , onChange = \x -> App.ProductionMsg <| Production.WebcamSettingsMsg <| Production.SetAnchor x
                , options =
                    [ Input.optionWith Data.TopLeft <| Ui.option (gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled) <| Element.text <| Strings.stepsProductionTopLeft lang
                    , Input.optionWith Data.TopRight <| Ui.option (gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled) <| Element.text <| Strings.stepsProductionTopRight lang
                    , Input.optionWith Data.BottomLeft <| Ui.option (gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled) <| Element.text <| Strings.stepsProductionBottomLeft lang
                    , Input.optionWith Data.BottomRight <| Ui.option (gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled) <| Element.text <| Strings.stepsProductionBottomRight lang
                    ]
                , selected = anchor
                }

        -- Title other settings.
        moreTitle : Element App.Msg
        moreTitle =
            title <| Strings.stepsProductionMoreSettings lang

        -- Whether the user can control the opacity
        opacityDisabled =
            gos.record == Nothing || audioOnly || webcamSettings == Just Data.Disabled

        -- Title to introduce webcam opacity settings
        opacityTitle =
            Element.el (disableAttrIf opacityDisabled) <|
                Element.text <|
                    Strings.stepsProductionOpacity lang

        -- Slider to control opacity
        opacitySlider =
            Element.row [ Ui.wf, Ui.hf, Ui.s 10 ]
                [ -- Slider for the control
                  disableIf opacityDisabled
                    Input.slider
                    [ Element.behindContent <| Element.el [ Ui.wf, Ui.hpx 2, Ui.cy, Background.color Colors.greyBorder ] Element.none
                    ]
                    { onChange = \x -> App.ProductionMsg <| Production.WebcamSettingsMsg <| Production.SetOpacity x
                    , label = Input.labelHidden <| Strings.stepsProductionOpacity lang
                    , max = 1
                    , min = 0
                    , step = Just 0.1
                    , thumb = Ui.sliderThumb opacityDisabled
                    , value = opacity
                    }
                , -- Text label of the opacity value
                  opacity
                    * 100
                    |> round
                    |> String.fromInt
                    |> (\x -> x ++ "%")
                    |> Element.text
                    |> Element.el (Ui.wfp 1 :: Ui.ab :: disableAttrIf opacityDisabled)
                ]
    in
    Element.column [ Ui.wf, Ui.hf, Ui.s 30, Ui.at, Ui.p 10 ]
        [ Element.column [ Ui.s 10 ]
            [ resetButton
            , resetElement
            ]
        , Element.column [ Ui.s 10 ]
            [ useVideo
            , useVideoInfo
            ]
        , foldable
            "f1"
            webcamSizeTitle
          <|
            Element.column
                [ Ui.s 10, Ui.wf ]
                [ webcamSizeRadio
                , webcamSizeText
                ]
        , foldable
            "f2"
            webcamPositionTitle
          <|
            Element.column
                [ Ui.s 10, Ui.wf ]
                [ webcamPositionRadio
                ]
        , foldable
            "f3"
            moreTitle
          <|
            Element.column
                [ Ui.s 10, Ui.wf ]
                [ Element.column [ Ui.s 10, Ui.wf ]
                    [ opacityTitle
                    , opacitySlider
                    ]
                ]
        ]


{-| The column with the slide view and the production button.
-}
rightColumn : Config -> User -> Production.Model Data.Capsule Data.Gos -> Element App.Msg
rightColumn config user model =
    let
        lang =
            config.clientState.lang

        miniatureUrl =
            Maybe.andThen (Data.miniaturePath model.capsule) model.gos.record

        -- overlay to show a frame of the record on the slide (if any)
        overlay =
            case ( getWebcamSettings model.capsule model.gos, model.gos.record, miniatureUrl ) of
                ( Data.Pip s, Just r, Just url ) ->
                    let
                        ( ( marginX, marginY ), ( w, h ) ) =
                            ( model.webcamPosition
                            , r.size
                                |> Maybe.withDefault ( 0, 0 )
                                |> (\i -> getHeight i s.size)
                                |> (\i -> ( s.size, i ))
                                |> Tuple.mapBoth toFloat toFloat
                            )

                        ( x, y ) =
                            case s.anchor of
                                Data.TopLeft ->
                                    ( marginX, marginY )

                                Data.TopRight ->
                                    ( 1920 - w - marginX, marginY )

                                Data.BottomLeft ->
                                    ( marginX, 1080 - h - marginY )

                                Data.BottomRight ->
                                    ( 1920 - w - marginX, 1080 - h - marginY )

                        tp =
                            100 * y / 1080

                        lp =
                            100 * x / 1920

                        bp =
                            100 * (1080 - y - h) / 1080

                        rp =
                            100 * (1920 - x - w) / 1920
                    in
                    Element.el
                        [ Element.htmlAttribute (Html.Attributes.style "position" "absolute")
                        , Element.htmlAttribute (Html.Attributes.style "top" (String.fromFloat tp ++ "%"))
                        , Element.htmlAttribute (Html.Attributes.style "left" (String.fromFloat lp ++ "%"))
                        , Element.htmlAttribute (Html.Attributes.style "right" (String.fromFloat rp ++ "%"))
                        , Element.htmlAttribute (Html.Attributes.style "bottom" (String.fromFloat bp ++ "%"))
                        ]
                        (Element.image
                            [ Ui.id Production.miniatureId
                            , Element.alpha s.opacity
                            , Ui.wf
                            , Ui.hf
                            , Decode.map3 (\z pageX pageY -> App.ProductionMsg (Production.HoldingImageChanged (Just ( z, pageX, pageY ))))
                                (Decode.field "pointerId" Decode.int)
                                (Decode.field "pageX" Decode.float)
                                (Decode.field "pageY" Decode.float)
                                |> Html.Events.on "pointerdown"
                                |> Element.htmlAttribute
                            , Decode.succeed (App.ProductionMsg (Production.HoldingImageChanged Nothing))
                                |> Html.Events.on "pointerup"
                                |> Element.htmlAttribute
                            , Element.htmlAttribute
                                (Html.Events.custom "dragstart"
                                    (Decode.succeed
                                        { message = App.Noop
                                        , preventDefault = True
                                        , stopPropagation = True
                                        }
                                    )
                                )
                            ]
                            { src = url
                            , description = ""
                            }
                        )

                ( Data.Fullscreen { opacity }, Just r, Just url ) ->
                    Element.el
                        [ Element.alpha opacity
                        , Ui.hf
                        , Ui.wf
                        , ("center / contain content-box no-repeat url('"
                            ++ url
                            ++ "')"
                          )
                            |> Html.Attributes.style "background"
                            |> Element.htmlAttribute
                        ]
                        Element.none

                _ ->
                    Element.none

        -- The display of the slide
        slide =
            case model.gos.slides of
                h :: _ ->
                    case Data.extraPath model.capsule h of
                        Just extra ->
                            [ Html.source [ Html.Attributes.src extra ] [] ]
                                |> Html.video [ Html.Attributes.class "wf" ]
                                |> Element.html
                                |> (\x -> Element.Keyed.el [ Ui.wf, Ui.b 1, Border.color Colors.greyBorder ] ( extra, x ))

                        _ ->
                            Element.image [ Ui.wf, Ui.b 1, Border.color Colors.greyBorder ]
                                { src = Data.slidePath model.capsule h
                                , description = ""
                                }

                _ ->
                    Element.none

        -- The button to produce the video
        ( produceButton, produceGosButton ) =
            let
                ready2Product : Bool
                ready2Product =
                    case model.capsule.produced of
                        Data.Running _ ->
                            False

                        Data.Waiting ->
                            False

                        _ ->
                            model.capsule.structure
                                |> List.map .produced
                                |> List.map
                                    (\x ->
                                        case x of
                                            Data.Running _ ->
                                                False

                                            Data.Waiting ->
                                                False

                                            _ ->
                                                True
                                    )
                                |> List.all (\x -> x)

                action : App.Msg
                action =
                    Utils.tern
                        ready2Product
                        (App.ProductionMsg Production.Produce)
                        App.Noop

                gosAction : App.Msg
                gosAction =
                    Utils.tern
                        ready2Product
                        (App.ProductionMsg <| Production.ProduceGos)
                        App.Noop

                spinnerElement : Element App.Msg
                spinnerElement =
                    Element.el
                        [ Ui.wf
                        , Ui.hf
                        , Font.color <| Utils.tern ready2Product Colors.transparent Colors.white
                        ]
                    <|
                        Ui.spinningSpinner [ Ui.cx, Ui.cy ] 18

                label : Element App.Msg
                label =
                    Element.el
                        [ Font.color <| Utils.tern ready2Product Colors.white Colors.transparent
                        , Element.inFront spinnerElement
                        ]
                    <|
                        Element.text <|
                            Strings.stepsProductionProduceVideo lang

                gosLabel : Element App.Msg
                gosLabel =
                    Element.el
                        [ Font.color <| Utils.tern ready2Product Colors.white Colors.transparent
                        , Element.inFront spinnerElement
                        ]
                    <|
                        Element.text <|
                            Strings.stepsProductionProduceGrain lang
            in
            ( Ui.primary [ Ui.ar ]
                { action = Ui.Msg <| action
                , label = label
                }
            , Ui.primary [ Ui.ar ]
                { action = Ui.Msg <| gosAction
                , label = gosLabel
                }
            )

        -- The production progress bar
        progressBar : Element App.Msg
        progressBar =
            let
                loadingAnimation : Animation
                loadingAnimation =
                    Animation.steps
                        { startAt = [ P.x -300 ]
                        , options = [ Animation.loop ]
                        }
                        [ Animation.step 1000 [ P.x 300 ]
                        , Animation.wait 100
                        , Animation.step 1000 [ P.x -300 ]
                        , Animation.wait 100
                        ]

                bar : Maybe Float -> Element App.Msg
                bar progress =
                    Element.el
                        [ Ui.p 5
                        , Ui.wpx 300
                        , Ui.hpx 30
                        , Ui.r 20
                        , Ui.ar
                        , Background.color <| Colors.alpha 0.1
                        , Border.shadow
                            { size = 1
                            , blur = 8
                            , color = Colors.alpha 0.1
                            , offset = ( 0, 0 )
                            }
                        ]
                    <|
                        Element.el
                            [ Ui.wf
                            , Element.htmlAttribute <| Html.Attributes.style "overflow" "hidden"
                            , Ui.r 100
                            , Ui.hf
                            ]
                        <|
                            case progress of
                                Just p ->
                                    Element.el
                                        [ Ui.wf
                                        , Ui.hf
                                        , Ui.r 5
                                        , Element.moveLeft (300.0 * (1.0 - p))
                                        , Background.color Colors.green2
                                        , Element.htmlAttribute <|
                                            Transition.properties [ Transition.transform 200 [ Transition.easeInOut ] ]
                                        ]
                                        Element.none

                                Nothing ->
                                    Animated.ui
                                        { behindContent = Element.behindContent
                                        , htmlAttribute = Element.htmlAttribute
                                        , html = Element.html
                                        }
                                        (\attr el -> Element.el attr el)
                                        loadingAnimation
                                        [ Ui.wf, Ui.hf, Ui.r 5, Background.color Colors.green2 ]
                                        Element.none
            in
            case ( model.capsule.produced, model.gos.produced ) of
                ( Data.Running progress, _ ) ->
                    bar progress

                ( _, Data.Running progress ) ->
                    bar progress

                _ ->
                    Element.none

        -- Link to watch the capsule
        capsuleLink =
            case Data.capsuleVideoPath model.capsule of
                Just path ->
                    Ui.link [] { label = Strings.stepsProductionWatchVideo lang, action = Ui.NewTab path }

                _ ->
                    Element.none

        -- Link to watch the GOS.
        gosLink =
            case Data.gosVideoPath model.capsule model.gos of
                Just path ->
                    Ui.link [] { label = Strings.stepsProductionWatchGrain lang, action = Ui.NewTab path }

                _ ->
                    Element.none
    in
    Element.column [ Ui.at, Ui.wf, Element.scrollbarY, Ui.s 10, Ui.p 10 ]
        [ Element.el [ Ui.wf, Ui.cy, Element.inFront overlay, Element.clip ] slide
        , Element.row [ Ui.ar, Ui.s 10 ] [ gosLink, produceGosButton ]
        , Element.row [ Ui.ar, Ui.s 10 ] [ capsuleLink, produceButton ]
        , progressBar
        ]
