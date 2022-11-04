module Production.Views exposing (..)

import Capsule
import Core.Types as Core
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import FontAwesome as Fa
import Html
import Html.Attributes
import Html.Events
import Json.Decode as Decode
import Lang
import Production.Types as Production
import Route
import Ui.Colors as Colors
import Ui.Utils as Ui
import User exposing (User)
import Utils exposing (isJust)


view : Core.Global -> User -> Production.Model -> ( Element Core.Msg, Maybe (Element Core.Msg) )
view global user model =
    let
        gos : Maybe Capsule.Gos
        gos =
            List.head (List.drop model.gos model.capsule.structure)

        firstSlide : Maybe Capsule.Slide
        firstSlide =
            Maybe.andThen (\x -> List.head x.slides) gos
    in
    case ( gos, firstSlide ) of
        ( Just g, Just s ) ->
            ( Element.row [ Ui.wf, Ui.hf, Element.spacing 10, Element.padding 10 ]
                [ Element.column [ Ui.wfp 1, Ui.hf ] [ leftColumn global user model g ]
                , Element.column [ Ui.wfp 3, Ui.hf ] [ mainView global user model g s ]
                ]
            , Nothing
            )

        _ ->
            ( Element.el [ Ui.wf, Ui.hf ] Element.none, Nothing )


leftColumn : Core.Global -> User -> Production.Model -> Capsule.Gos -> Element Core.Msg
leftColumn global user model gos =
    let
        webcamSettings =
            case gos.webcamSettings of
                Capsule.Pip w ->
                    w

                _ ->
                    Capsule.defaultPip

        forceDisabled =
            Maybe.andThen .size gos.record == Nothing || isProducing model

        forceDisabledAttr =
            if forceDisabled then
                Ui.disabled

            else
                []

        forceDisableMsg : Core.Msg -> Core.Msg
        forceDisableMsg msg =
            if forceDisabled then
                Core.Noop

            else
                msg

        forceDisableInfo : Element Core.Msg
        forceDisableInfo =
            Element.paragraph forceDisabledAttr
                [ case Maybe.map .size gos.record of
                    Nothing ->
                        Element.text (Lang.cantUseVideoBecauseNoRecord global.lang)

                    Just Nothing ->
                        Element.text (Lang.cantUseVideoBecauseAudioOnly global.lang)

                    _ ->
                        Element.none
                ]

        disabled =
            forceDisabled || gos.webcamSettings == Capsule.Disabled

        disabledAttr =
            if disabled then
                Ui.disabled

            else
                []

        disableMsg : Core.Msg -> Core.Msg
        disableMsg msg =
            if disabled then
                Core.Noop

            else
                msg

        currentOpacity =
            case gos.webcamSettings of
                Capsule.Pip { opacity } ->
                    opacity

                Capsule.Fullscreen { opacity } ->
                    opacity

                _ ->
                    webcamSettings.opacity

        currentdownsampling =
            case gos.record of
                Just r ->
                    case r.downsampling of
                        Just ds ->
                            ds

                        _ ->
                            0.4

                _ ->
                    0.4

        currentKeyColor =
            case gos.webcamSettings of
                Capsule.Pip { keycolor } ->
                    keycolor

                Capsule.Fullscreen { keycolor } ->
                    keycolor

                _ ->
                    Nothing

        width =
            case gos.webcamSettings of
                Capsule.Disabled ->
                    Nothing

                Capsule.Pip { size } ->
                    Just (Tuple.first size)

                Capsule.Fullscreen _ ->
                    Nothing

        keyDisabled =
            User.isPremium user && Maybe.andThen .matted gos.record /= Nothing

        keyDisabledAttr =
            if keyDisabled then
                Ui.disabled

            else
                disabledAttr
    in
    Element.column [ Ui.wf, Ui.hf, Element.spacing 30, Element.paddingXY 10 0, Element.scrollbarY ]
        [ Element.column (Element.spacing 10 :: disabledAttr)
            [ Input.checkbox []
                { checked = gos.webcamSettings /= Capsule.Disabled && Maybe.andThen .size gos.record /= Nothing
                , icon = Input.defaultCheckbox
                , label = Input.labelRight forceDisabledAttr (Element.text (Lang.useVideo global.lang))
                , onChange = \x -> Core.ProductionMsg (Production.SetVideo x) |> forceDisableMsg
                }
            , forceDisableInfo
            ]
        , Input.radio (Element.spacing 10 :: disabledAttr)
            { onChange = \s -> Core.ProductionMsg (Production.WebcamSizeChanged s) |> disableMsg
            , selected =
                case gos.webcamSettings of
                    Capsule.Fullscreen _ ->
                        Just Production.Fullscreen

                    _ ->
                        Just (Production.intToSize webcamSettings.size)
            , label =
                Input.labelAbove
                    (Element.paddingXY 0 10 :: disabledAttr)
                    (Element.column [ Element.spacing 10 ]
                        [ Element.el Ui.formTitle (Element.text (Lang.webcamSize global.lang))
                        , Input.text
                            [ Element.htmlAttribute (Html.Attributes.type_ "number") ]
                            { label = Input.labelHidden (Lang.custom global.lang)
                            , onChange =
                                \v ->
                                    case String.toInt v of
                                        Just val ->
                                            Core.ProductionMsg (Production.WebcamSizeChanged (Production.Custom val)) |> disableMsg

                                        _ ->
                                            Core.Noop
                            , placeholder = Nothing
                            , text = String.fromInt (Maybe.withDefault 0 width)
                            }
                        ]
                    )
            , options =
                [ Input.option Production.Small (Element.text (Lang.small global.lang))
                , Input.option Production.Medium (Element.text (Lang.medium global.lang))
                , Input.option Production.Large (Element.text (Lang.large global.lang))
                , Input.option (Production.Custom (Maybe.withDefault 300 width)) (Element.text (Lang.custom global.lang))
                , Input.option Production.Fullscreen (Element.text (Lang.fullscreen global.lang))
                ]
            }
        , Input.radio (Element.spacing 10 :: disabledAttr)
            { onChange = \s -> Core.ProductionMsg (Production.WebcamAnchorChanged s) |> disableMsg
            , selected = Just webcamSettings.anchor
            , label =
                Input.labelAbove
                    (Element.paddingXY 0 10 :: disabledAttr ++ Ui.formTitle)
                    (Element.text (Lang.webcamAnchor global.lang))
            , options =
                [ Input.option Capsule.TopLeft (Element.text (Lang.topLeft global.lang))
                , Input.option Capsule.TopRight (Element.text (Lang.topRight global.lang))
                , Input.option Capsule.BottomLeft (Element.text (Lang.bottomLeft global.lang))
                , Input.option Capsule.BottomRight (Element.text (Lang.bottomRight global.lang))
                ]
            }
        , Element.row (Ui.wf :: Element.spacing 10 :: disabledAttr)
            [ Input.slider
                [ Element.behindContent
                    (Element.el
                        [ Element.width Element.fill
                        , Element.height (Element.px 2)
                        , Element.centerY
                        , Background.color Colors.grey
                        , Border.rounded 2
                        ]
                        Element.none
                    )
                ]
                { label = Input.labelAbove (disabledAttr ++ Ui.formTitle) (Element.text (Lang.opacity global.lang))
                , min = 0
                , max = 1
                , onChange = \x -> Core.ProductionMsg (Production.WebcamOpacityChanged x) |> disableMsg
                , step = Just 0.1
                , thumb = Input.defaultThumb
                , value = currentOpacity
                }
                |> Element.el [ Ui.wfp 5 ]
            , currentOpacity
                * 100
                |> floor
                |> String.fromInt
                |> (\x -> x ++ "%")
                |> Element.text
                |> Element.el [ Ui.wfp 1, Element.alignBottom ]
            ]
        , if User.isPremium user then
            Element.el (Ui.formTitle ++ disabledAttr) (Element.text (Lang.matting global.lang))

          else
            Element.none
        , if User.isPremium user then
            Input.checkbox disabledAttr
                { checked = Maybe.andThen .matted gos.record /= Nothing && Maybe.andThen .size gos.record /= Nothing
                , icon = Input.defaultCheckbox
                , label = Input.labelRight forceDisabledAttr (Element.text (Lang.activateMatting global.lang))
                , onChange =
                    \_ -> Core.ProductionMsg Production.ToggleMatting |> disableMsg
                }

          else
            Element.none
        , if User.isPremium user then
            Element.row (Ui.wf :: Element.spacing 10 :: disabledAttr)
                [ Input.slider
                    [ Element.behindContent
                        (Element.el
                            [ Element.width Element.fill
                            , Element.height (Element.px 2)
                            , Element.centerY
                            , Background.color Colors.grey
                            , Border.rounded 2
                            ]
                            Element.none
                        )
                    ]
                    { label = Input.labelAbove (disabledAttr ++ Ui.formTitle) (Element.text (Lang.downsampling global.lang))
                    , min = 0.1
                    , max = 1
                    , onChange = \x -> Core.ProductionMsg (Production.DownsamplingChanged x) |> disableMsg
                    , step = Just 0.05
                    , thumb = Input.defaultThumb
                    , value = currentdownsampling
                    }
                    |> Element.el [ Ui.wfp 5 ]
                , currentdownsampling
                    |> (\x -> x * 100)
                    |> round
                    |> toFloat
                    |> (\x -> x / 100)
                    |> String.fromFloat
                    |> (\x ->
                            if String.length x == 1 then
                                x ++ "."

                            else
                                x
                       )
                    |> String.padRight 4 '0'
                    |> Element.text
                    |> Element.el [ Ui.wfp 1, Element.alignBottom ]
                ]

          else
            Element.none
        , if User.isPremium user then
            Element.row (Ui.wf :: Ui.hf :: Element.spacing 10 :: disabledAttr)
                [ case model.capsule.background of
                    Just uuid ->
                        Element.image
                            [ Element.height (Element.px 90)
                            , Element.centerY
                            , Border.width 1
                            , Border.color Colors.greyLighter
                            ]
                            { src = Capsule.assetPath model.capsule (uuid ++ ".png"), description = "" }

                    Nothing ->
                        Element.text (Lang.noBackround global.lang)
                , Element.el [] (newBackgroundButton global model)
                , Ui.iconButton
                    [ Font.color Colors.navbar
                    , Element.padding 5
                    , Background.color Colors.greyLighter
                    , Border.rounded 5
                    ]
                    { onPress = Just (Core.ProductionMsg Production.RequestDeleteBackground |> disableMsg)
                    , icon = Fa.trash
                    , text = Nothing
                    , tooltip = Just (Lang.deleteBackground global.lang)
                    }
                ]

          else
            Element.none
        , if User.isPremium user then
            Element.el (Ui.formTitle ++ keyDisabledAttr) (Element.text (Lang.key global.lang))

          else
            Element.none
        , if User.isPremium user then
            Input.checkbox keyDisabledAttr
                { checked = isJust currentKeyColor
                , icon = Input.defaultCheckbox
                , label = Input.labelRight forceDisabledAttr (Element.text (Lang.activateKeying global.lang))
                , onChange =
                    \_ ->
                        if Maybe.andThen .matted gos.record /= Nothing && Maybe.andThen .size gos.record /= Nothing |> not then
                            Core.ProductionMsg
                                (Production.WebcamKeyColorChanged
                                    (case currentKeyColor of
                                        Just _ ->
                                            Nothing

                                        Nothing ->
                                            Just "#00FF00"
                                    )
                                )
                                |> disableMsg

                        else
                            Core.Noop
                }

          else
            Element.none
        , if User.isPremium user then
            Element.row keyDisabledAttr
                [ Element.el
                    (if isJust currentKeyColor then
                        []

                     else
                        Ui.disabled
                    )
                    (Element.text (Lang.keyColor global.lang))
                , Element.el [ Element.paddingEach { left = 10, right = 0, top = 0, bottom = 0 } ]
                    (Element.html
                        (Html.input
                            [ Html.Attributes.type_ "color"
                            , Html.Attributes.value (Maybe.withDefault "#00FF00" currentKeyColor)
                            , Html.Attributes.disabled (not (isJust currentKeyColor) || isProducing model || keyDisabled)
                            , Html.Events.onInput
                                (\x ->
                                    Core.ProductionMsg
                                        (Production.WebcamKeyColorChanged
                                            (Maybe.map (\_ -> x) currentKeyColor)
                                        )
                                        |> disableMsg
                                )
                            ]
                            []
                        )
                    )
                ]

          else
            Element.none
        , if keyDisabled then
            Element.paragraph Ui.disabled [ Element.text (Lang.keyDisabledBecauseMatting global.lang) ]

          else
            Element.none
        , -- Fading option, not available right now
          -- if User.isPremium user then
          --   let
          --       fade =
          --           gos.fade.vfadein /= Nothing || gos.fade.vfadeout /= Nothing || gos.fade.afadein /= Nothing || gos.fade.afadeout /= Nothing
          --   in
          --   Input.checkbox
          --       []
          --       { checked = fade
          --       , icon = Input.defaultCheckbox
          --       , label = Input.labelRight [] (Element.text (Lang.activateFade global.lang))
          --       , onChange =
          --           \x ->
          --               Core.ProductionMsg
          --                   (Production.FadeChanged
          --                       (if fade then
          --                           { vfadein = Nothing, vfadeout = Nothing, afadein = Nothing, afadeout = Nothing }
          --                        else
          --                           { vfadein = Just 2, vfadeout = Nothing, afadein = Nothing, afadeout = Nothing }
          --                       )
          --                   )
          --       }
          -- else
          Element.el [ Ui.hf ] Element.none

        --Input.text []
        --  { label = Input.labelHidden ""
        --  , onChange = \x -> Core.ProductionMsg (Production.WebcamKeyColorChanged x) |> disableMsg
        --  , placeholder = Just (Input.placeholder [] (Element.text (Lang.keyColor global.lang)))
        --  , text = currentKeyColor
        --  }
        ]


isProducing : Production.Model -> Bool
isProducing model =
    case model.capsule.produced of
        Capsule.Running _ ->
            True

        Capsule.Waiting ->
            True

        _ ->
            False


mainView : Core.Global -> User -> Production.Model -> Capsule.Gos -> Capsule.Slide -> Element Core.Msg
mainView global user model gos slide =
    let
        image : Element Core.Msg
        image =
            case ( gos.slides, slide.extra ) of
                ( _ :: [], Just path ) ->
                    Element.el
                        [ Ui.wf
                        , Element.centerY
                        , Border.width 1
                        , Border.color Colors.greyLighter
                        ]
                        (Element.html
                            (Html.video
                                [ Html.Attributes.controls False, Html.Attributes.class "wf" ]
                                [ Html.source [ Html.Attributes.src (Capsule.assetPath model.capsule (path ++ ".mp4")) ] [] ]
                            )
                        )

                _ ->
                    Element.image
                        [ Ui.wf
                        , Element.centerY
                        , Border.width 1
                        , Border.color Colors.greyLighter
                        ]
                        { src = Capsule.slidePath model.capsule slide, description = "" }

        overlay : Element Core.Msg
        overlay =
            case ( gos.webcamSettings, gos.record ) of
                ( Capsule.Pip s, Just r ) ->
                    let
                        ( ( marginX, marginY ), ( w, h ) ) =
                            ( model.webcamPosition, ( toFloat (Tuple.first s.size), toFloat (Tuple.second s.size) ) )

                        ( x, y ) =
                            case s.anchor of
                                Capsule.TopLeft ->
                                    ( marginX, marginY )

                                Capsule.TopRight ->
                                    ( 1920 - w - marginX, marginY )

                                Capsule.BottomLeft ->
                                    ( marginX, 1080 - h - marginY )

                                Capsule.BottomRight ->
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
                            (Element.htmlAttribute (Html.Attributes.id "webcam-miniature")
                                :: Element.alpha s.opacity
                                :: Ui.wf
                                :: Ui.hf
                                :: (Decode.map3 (\z pageX pageY -> Core.ProductionMsg (Production.HoldingImageChanged (Just ( z, pageX, pageY ))))
                                        (Decode.field "pointerId" Decode.int)
                                        (Decode.field "pageX" Decode.float)
                                        (Decode.field "pageY" Decode.float)
                                        |> Html.Events.on "pointerdown"
                                        |> Element.htmlAttribute
                                   )
                                :: (Decode.succeed (Core.ProductionMsg (Production.HoldingImageChanged Nothing))
                                        |> Html.Events.on "pointerup"
                                        |> Element.htmlAttribute
                                   )
                                :: Element.htmlAttribute
                                    (Html.Events.custom "dragstart"
                                        (Decode.succeed
                                            { message = Core.Noop
                                            , preventDefault = True
                                            , stopPropagation = True
                                            }
                                        )
                                    )
                                :: (case model.capsule.background of
                                        Just path ->
                                            [ path
                                                |> Capsule.assetPath model.capsule
                                                |> (\tmp -> "url(\"" ++ tmp ++ ".png\")")
                                                |> Html.Attributes.style "background-image"
                                                |> Element.htmlAttribute
                                            , Element.htmlAttribute (Html.Attributes.style "background-size" "cover")
                                            , Element.htmlAttribute (Html.Attributes.style "background-position" "center")
                                            ]

                                        _ ->
                                            []
                                   )
                            )
                            { src =
                                if r.matted == Just Capsule.Done then
                                    Capsule.assetPath model.capsule (r.uuid ++ "_matted.png")

                                else
                                    Capsule.assetPath model.capsule (r.uuid ++ ".png")
                            , description = ""
                            }
                        )

                ( Capsule.Fullscreen { opacity }, Just r ) ->
                    Element.el
                        [ Element.alpha opacity
                        , Ui.hf
                        , Ui.wf
                        , ("center / contain content-box no-repeat url('"
                            ++ Capsule.assetPath model.capsule (r.uuid ++ ".png")
                            ++ "')"
                          )
                            |> Html.Attributes.style "background"
                            |> Element.htmlAttribute
                        ]
                        Element.none

                _ ->
                    Element.none

        gosIdString =
            String.fromInt <| model.gos + 1

        produceInfo =
            case ( model.capsule.published, Capsule.videoGosPath model.capsule model.gos ) of
                ( _, Just path ) ->
                    Ui.newTabLink []
                        { label = Element.text (Lang.watchGosVideo global.lang gosIdString)
                        , route = Route.Custom path
                        }

                _ ->
                    Element.none

        produceButton =
            Ui.primaryButton
                { label = Element.text (Lang.produceGosVideo global.lang gosIdString)
                , onPress = Just (Core.ProductionMsg <| Production.ProduceGos model.gos)
                }
    in
    Element.column []
        [ Element.el [ Ui.wf, Element.centerY, Element.inFront overlay, Element.clip ] image
        , Element.row [ Element.alignRight, Element.spacing 10, Element.padding 10 ] [ produceInfo, produceButton ]
        , bottomBar global user model
        ]


bottomBar : Core.Global -> User -> Production.Model -> Element Core.Msg
bottomBar global _ model =
    let
        produceInfo =
            case ( model.capsule.published, Capsule.videoPath model.capsule ) of
                ( Capsule.Done, _ ) ->
                    Ui.newTabLink []
                        { label = Element.text (Lang.watchVideo global.lang)
                        , route = Route.Custom (global.videoRoot ++ "/" ++ model.capsule.id ++ "/")
                        }

                ( _, Just path ) ->
                    Ui.newTabLink []
                        { label = Element.text (Lang.watchVideo global.lang)
                        , route = Route.Custom path
                        }

                _ ->
                    Element.none

        produceButton =
            case model.capsule.produced of
                Capsule.Running msg ->
                    Element.column []
                        [ Element.row [ Element.spacing 10 ]
                            [ Ui.primaryButton
                                { label =
                                    Element.row []
                                        [ Element.text (Lang.producing global.lang)
                                        , Element.el [ Element.paddingEach { left = 10, right = 0, top = 0, bottom = 0 } ]
                                            Ui.spinner
                                        ]
                                , onPress = Nothing
                                }

                            --, Ui.primaryButton
                            --    { label = Element.text (Lang.cancelProduction global.lang)
                            --    , onPress = Just (Core.ProductionMsg Production.CancelProduction)
                            --    }
                            ]
                        , case msg of
                            Just m ->
                                Element.el [ Element.padding 10, Element.width Element.fill, Ui.hf ] (Ui.progressBar m)

                            Nothing ->
                                Element.none
                        ]

                Capsule.Waiting ->
                    Element.column []
                        [ Element.row [ Element.spacing 10, Element.alignRight ]
                            [ Ui.primaryButton
                                { label =
                                    Element.row []
                                        [ Element.text (Lang.waitingMatting global.lang)
                                        , Element.el [ Element.paddingEach { left = 10, right = 0, top = 0, bottom = 0 } ]
                                            Ui.spinner
                                        ]
                                , onPress = Nothing
                                }

                            -- , Ui.primaryButton
                            --     { label = Element.text (Lang.cancelProduction global.lang)
                            --     , onPress = Just (Core.ProductionMsg Production.CancelProduction)
                            --     }
                            ]
                        , Element.el [ Element.padding 10, Element.width Element.fill, Ui.hf ]
                            (Element.text (Lang.waitingMattingMsg global.lang))
                        ]

                _ ->
                    Ui.primaryButton
                        { label = Element.text (Lang.produceVideo global.lang)
                        , onPress = Just (Core.ProductionMsg Production.ProduceVideo)
                        }
    in
    Element.row [ Element.alignRight, Element.spacing 10, Element.padding 10 ] [ produceInfo, produceButton ]


newBackgroundButton : Core.Global -> Production.Model -> Element Core.Msg
newBackgroundButton global model =
    let
        gos =
            List.head (List.drop model.gos model.capsule.structure)

        newBackgroundMsg =
            case gos of
                Just g ->
                    if Maybe.andThen .size g.record == Nothing || g.webcamSettings == Capsule.Disabled || isProducing model then
                        Nothing

                    else
                        Core.ProductionMsg Production.BackgroundUploadRequested |> Just

                _ ->
                    Nothing
    in
    Element.el [ Element.paddingXY 10 0 ]
        (Ui.simpleButton
            { onPress = newBackgroundMsg
            , label = Element.text (Lang.selectBackground global.lang)
            }
        )
