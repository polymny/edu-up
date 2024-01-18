module Preparation.Views exposing (view)

{-| The main view for the preparation page.

@docs view

-}

import App.Types as App
import Config exposing (Config)
import Data.Capsule as Data exposing (Capsule)
import Data.User exposing (User)
import DnDList.Groups
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Keyed
import FileValue
import Html
import Html.Attributes
import Lang exposing (Lang)
import List.Extra
import Material.Icons as Icons
import Preparation.Types as Preparation
import RemoteData
import Simple.Transition as Transition
import Strings
import Ui.Colors as Colors
import Ui.Elements as Ui
import Ui.Utils as Ui
import Utils


{-| The view function for the preparation page.
-}
view : Config -> User -> Preparation.Model Capsule -> ( Element App.Msg, Element App.Msg )
view config user model =
    let
        lang =
            config.clientState.lang

        zoomLevel =
            config.clientConfig.zoomLevel

        inFront : Element App.Msg
        inFront =
            maybeDragSlide model.slideModel model.slides
                |> Maybe.map (\x -> slideView config user model True x (Just x))
                |> Maybe.withDefault Element.none

        popup : Element App.Msg
        popup =
            Element.el
                [ Ui.zIndex 1
                , Ui.wf
                , Ui.hf
                , Element.transparent <| not model.displayPopup
                , Element.htmlAttribute <| Html.Attributes.style "pointer-events" <| Utils.tern model.displayPopup "auto" "none"
                , Transition.properties
                    [ Transition.opacity 200 []
                    ]
                    |> Element.htmlAttribute
                ]
            <|
                case model.popupType of
                    Preparation.NoPopup ->
                        Element.none

                    Preparation.DeleteSlidePopup s ->
                        deleteSlideConfirmPopup lang model s

                    Preparation.DeleteExtraPopup s ->
                        deleteExtraConfirmPopup lang model s

                    Preparation.ChangeSlidePopup f ->
                        selectPageNumberPopup lang model f

                    Preparation.EditPromptPopup s ->
                        promptPopup lang model s

                    Preparation.ConfirmUpdateCapsulePopup c ->
                        confirmUpdateCapsulePopup lang

                    Preparation.ConfirmAddSlide gos ->
                        confirmAddSlidePopup lang gos

                    Preparation.ConfirmUploadExtraVideo file slide ->
                        confirmUploadExtraVideoPopup lang file slide

        groupedSlides : List (NeList Preparation.Slide)
        groupedSlides =
            model.slides
                |> List.Extra.gatherWith (\a b -> a.totalGosId == b.totalGosId)
                |> filterConsecutiveVirtualGos

        zoomBar : Element App.Msg
        zoomBar =
            Element.row [ Ui.ar, Ui.s 10, Element.paddingEach { top = 10, right = 10, left = 0, bottom = 0 } ]
                [ Ui.primaryIcon []
                    { icon = Icons.zoom_out
                    , action = Utils.tern (zoomLevel < 6) (Ui.Msg <| App.ConfigMsg <| Config.ZoomLevelChanged <| zoomLevel + 1) Ui.None
                    , tooltip = Strings.actionsZoomOut lang
                    }
                , Ui.primaryIcon []
                    { icon = Icons.zoom_in
                    , action = Utils.tern (zoomLevel > 2) (Ui.Msg <| App.ConfigMsg <| Config.ZoomLevelChanged <| zoomLevel - 1) Ui.None
                    , tooltip = Strings.actionsZoomIn lang
                    }
                ]
    in
    ( groupedSlides
        |> List.indexedMap (\gosIndex gos -> gosView config user model gos (modBy (List.length groupedSlides) (gosIndex + 1)))
        |> (\x -> zoomBar :: x)
        |> Element.column [ Element.spacing 10, Ui.wf, Ui.hf, Element.inFront inFront ]
    , popup
    )


{-| Displays a grain.
-}
gosView : Config -> User -> Preparation.Model Capsule -> ( Preparation.Slide, List Preparation.Slide ) -> Int -> Element App.Msg
gosView config user model ( head, gos ) gosIndex =
    let
        lang =
            config.clientState.lang

        isDragging =
            maybeDragSlide model.slideModel model.slides /= Nothing

        gosId =
            if gosIndex == 0 then
                -- Last virtual gos, don't display label
                -1

            else
                gosIndex // 2 + 1

        last =
            neListLast ( head, gos )

        addSlide =
            case ( head.slide, gos ) of
                ( Nothing, [] ) ->
                    -- Virtual gos, the button will create a new gos
                    Ui.primaryIcon [ Ui.cy ]
                        { icon = Icons.add
                        , action = mkUiExtra (Preparation.SelectAddGos Utils.Request (head.totalGosId // 2))
                        , tooltip = Strings.stepsPreparationCreateGrain config.clientState.lang
                        }

                _ ->
                    -- Real gos, the button will add a slide at the end of the gos
                    Ui.primaryIcon [ Ui.cy ]
                        { icon = Icons.add
                        , action = mkUiExtra (Preparation.SelectAddSlides Utils.Request head.gosId)
                        , tooltip = Strings.stepsPreparationAddSlide config.clientState.lang
                        }

        content =
            case ( head.slide, gos, isDragging ) of
                ( Nothing, [], False ) ->
                    -- Virtual gos
                    if gosId > 0 then
                        Element.row [ Ui.p 20, Ui.wf ]
                            [ Element.el [ Ui.wf, Ui.bt 1, Border.color Colors.greyBorder ] Element.none
                            , Element.el [ Ui.px 20 ] <|
                                Element.text <|
                                    Strings.dataCapsuleGrain lang 1
                                        ++ " "
                                        ++ String.fromInt gosId
                            , Element.el [ Ui.wf, Ui.bt 1, Border.color Colors.greyBorder ] Element.none
                            ]

                    else
                        Element.el [ Ui.p 20, Ui.wf ] <|
                            Element.el [ Ui.wf, Ui.bt 1, Border.color Colors.greyBorder ] Element.none

                ( Nothing, [], True ) ->
                    -- Virtual gos
                    Element.none
                        |> Element.el [ Ui.wf, Ui.p 15 ]
                        |> Element.el [ Ui.wf, Ui.bt 1, Border.color (Colors.grey 6), Background.color (Colors.grey 6) ]
                        |> Element.el
                            (Ui.wf
                                :: Ui.p 5
                                :: Ui.id ("slide-" ++ String.fromInt head.totalSlideId)
                                :: slideStyle model.slideModel head.totalSlideId Drop
                            )
                        |> Element.el [ Ui.wf, Ui.id ("gos-" ++ String.fromInt head.totalGosId) ]

                _ ->
                    (head :: gos)
                        |> List.filter (\x -> x.slide /= Nothing)
                        |> Utils.regroupFixed config.clientConfig.zoomLevel
                        |> List.map (List.map (slideView config user model False last))
                        |> List.map (Element.row [ Ui.wf ])
                        |> Element.column [ Ui.wf, Ui.s 10, Ui.id ("gos-" ++ String.fromInt head.totalGosId) ]
    in
    Element.row [ Ui.s 10, Ui.wf, Ui.pr 20 ] [ content, addSlide ]


{-| Displays a slide.
-}
slideView : Config -> User -> Preparation.Model Capsule -> Bool -> Preparation.Slide -> Maybe Preparation.Slide -> Element App.Msg
slideView config _ model ghost default s =
    let
        lang =
            config.clientState.lang
    in
    case ( s, Maybe.andThen .slide s ) of
        ( Just slide, Just dataSlide ) ->
            let
                inFrontLabel =
                    Strings.dataCapsuleSlide lang 1
                        ++ " "
                        ++ String.fromInt (slide.slideId + 1)
                        |> Element.text
                        |> Element.el [ Ui.p 5, Ui.rbr 5, Background.color Colors.greyBorder ]
                        |> Utils.tern ghost Element.none

                inFrontButtons =
                    if ghost then
                        Element.none

                    else
                        Element.row [ Ui.s 10, Ui.p 10, Ui.at, Ui.ar ]
                            [ Ui.primaryIcon []
                                { icon = Icons.speaker_notes
                                , tooltip = Strings.actionsEditPrompt lang
                                , action = mkUiMsg (Preparation.EditPrompt dataSlide)
                                }
                            , Ui.primaryIcon []
                                { icon = Icons.image
                                , tooltip = Strings.stepsPreparationReplaceSlideOrAddExternalResource lang
                                , action = mkUiExtra (Preparation.SelectReplaceSlide Utils.Request dataSlide)
                                }
                            , Ui.primaryIcon []
                                { icon = Icons.delete
                                , tooltip =
                                    if dataSlide.extra == Nothing then
                                        Strings.actionsDeleteSlide lang

                                    else
                                        Strings.actionsDeleteExtra lang
                                , action =
                                    if dataSlide.extra == Nothing then
                                        mkUiMsg (Preparation.DeleteSlide Utils.Request dataSlide)

                                    else
                                        mkUiMsg (Preparation.DeleteExtra Utils.Request dataSlide)
                                }
                            ]

                inFrontPrompt =
                    slide.slide
                        |> Maybe.map .prompt
                        |> Maybe.map (String.split "\n")
                        |> Maybe.andThen List.head
                        |> Maybe.andThen (\x -> Utils.tern (x == "") Nothing (Just x))
                        |> Maybe.map (String.left 30)
                        |> Maybe.map (\x -> String.trim x ++ " ...")
                        |> Maybe.map Element.text
                        |> Maybe.map (Element.el [ Ui.p 5, Ui.r 5, Background.color Colors.greyBorder ])
                        |> Maybe.map (Element.el [ Ui.cx, Ui.ab, Ui.p 5 ])
                        |> Maybe.withDefault Element.none

                slideElement =
                    case Maybe.andThen (Data.extraPath model.capsule) slide.slide of
                        Just path ->
                            Element.Keyed.el
                                (Ui.wf
                                    :: Ui.b 1
                                    :: Border.color Colors.greyBorder
                                    :: Element.inFront inFrontLabel
                                    :: Element.inFront inFrontPrompt
                                    :: slideStyle model.slideModel slide.totalSlideId Drag
                                    ++ slideStyle model.slideModel slide.totalSlideId Drop
                                    ++ Utils.tern ghost (slideStyle model.slideModel slide.totalSlideId Ghost) []
                                )
                            <|
                                ( path
                                , Element.html
                                    (Html.video
                                        [ Html.Attributes.class "wf"
                                        , Html.Attributes.controls True
                                        ]
                                        [ Html.source
                                            [ Html.Attributes.src path
                                            , Html.Attributes.controls True
                                            ]
                                            []
                                        ]
                                    )
                                )

                        _ ->
                            Element.image
                                (Ui.wf
                                    :: Ui.b 1
                                    :: Border.color Colors.greyBorder
                                    :: Element.inFront inFrontLabel
                                    :: Element.inFront inFrontPrompt
                                    :: slideStyle model.slideModel slide.totalSlideId Drag
                                    ++ slideStyle model.slideModel slide.totalSlideId Drop
                                    ++ Utils.tern ghost (slideStyle model.slideModel slide.totalSlideId Ghost) []
                                )
                                { src = Data.slidePath model.capsule dataSlide
                                , description = ""
                                }
            in
            Element.el
                [ Ui.wf
                , Ui.pl 20
                , Ui.id ("slide-" ++ String.fromInt slide.totalSlideId)
                , Element.inFront inFrontButtons
                ]
                slideElement

        ( Just _, _ ) ->
            Element.none

        _ ->
            Element.el (Ui.wf :: Ui.hf :: Ui.pl 20 :: slideStyle model.slideModel default.totalSlideId Drop) Element.none


{-| Popup to confirm the slide deletion.
-}
deleteSlideConfirmPopup : Lang -> Preparation.Model Capsule -> Data.Slide -> Element App.Msg
deleteSlideConfirmPopup lang model s =
    let
        willDestroyRecord : Bool
        willDestroyRecord =
            model.capsule.structure
                |> List.filter (\x -> List.any (\y -> y.uuid == s.uuid) x.slides)
                |> List.head
                |> Maybe.map (\x -> x.record /= Nothing)
                |> Maybe.withDefault False
    in
    Element.column [ Ui.wf, Ui.hf, Ui.s 10 ]
        [ Element.paragraph [ Ui.wf, Ui.cy, Font.center ]
            [ Element.text (Lang.question Strings.actionsConfirmDeleteSlide lang) ]
        , if willDestroyRecord then
            Element.paragraph [ Ui.wf, Ui.cy, Ui.pt 20, Font.center ]
                [ Element.text (Lang.warning Strings.uiWarning lang) ]

          else
            Element.none
        , if willDestroyRecord then
            Element.paragraph [ Ui.wf, Ui.cy, Font.center ]
                [ Element.text (Strings.stepsPreparationDeleteSlideWillBreak lang ++ ".") ]

          else
            Element.none
        , Element.row [ Ui.ab, Ui.ar, Ui.s 10 ]
            [ Ui.secondary []
                { action = mkUiMsg (Preparation.DeleteSlide Utils.Cancel s)
                , label = Element.text <| Strings.uiCancel lang
                }
            , Ui.primary []
                { action = mkUiMsg (Preparation.DeleteSlide Utils.Confirm s)
                , label = Element.text <| Strings.uiConfirm lang
                }
            ]
        ]
        |> Ui.popup (Strings.actionsDeleteSlide lang)


{-| Popup to confirm the extra deletion.
-}
deleteExtraConfirmPopup : Lang -> Preparation.Model Capsule -> Data.Slide -> Element App.Msg
deleteExtraConfirmPopup lang _ s =
    Element.column [ Ui.wf, Ui.hf ]
        [ Element.paragraph [ Ui.wf, Ui.cy, Font.center ]
            [ Element.text (Lang.question Strings.actionsConfirmDeleteExtra lang) ]
        , Element.row [ Ui.ab, Ui.ar, Ui.s 10 ]
            [ Ui.secondary []
                { action = mkUiMsg (Preparation.DeleteExtra Utils.Cancel s)
                , label = Element.text <| Strings.uiCancel lang
                }
            , Ui.primary []
                { action = mkUiMsg (Preparation.DeleteExtra Utils.Confirm s)
                , label = Element.text <| Strings.uiConfirm lang
                }
            ]
        ]
        |> Ui.popup (Strings.actionsDeleteExtra lang)


{-| Popup to input prompt texts.
-}
promptPopup : Lang -> Preparation.Model Capsule -> Data.Slide -> Element App.Msg
promptPopup lang model slide =
    let
        gosIndex =
            model.capsule.structure
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, x ) -> List.any (\y -> y.uuid == slide.uuid) x.slides)
                |> List.head
                |> Maybe.map (\i -> Tuple.first i + 1)
                |> Maybe.withDefault 0

        allSlides =
            model.capsule.structure |> List.concatMap .slides

        slideIndex =
            allSlides
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, x ) -> x.uuid == slide.uuid)
                |> List.head
                |> Maybe.map (\i -> Tuple.first i + 1)
                |> Maybe.withDefault 0

        slidesLength =
            List.length allSlides
    in
    Element.row [ Ui.wf, Ui.hf, Ui.s 10 ]
        [ Element.column [ Ui.wf, Ui.cy, Ui.s 10 ]
            [ Element.image [ Ui.wf, Ui.b 1, Border.color Colors.greyBorder ]
                { description = Strings.dataCapsuleSlide lang 1
                , src = Data.slidePath model.capsule slide
                }
            , Element.row [ Ui.wf ]
                [ Ui.secondaryIcon [ Ui.al ]
                    { icon = Icons.arrow_back
                    , action = Utils.tern (slideIndex <= 1) Ui.None <| Ui.Msg <| App.PreparationMsg <| Preparation.GoToPreviousSlide slideIndex slide
                    , tooltip = Strings.stepsPreparationGoToPreviousSlide lang
                    }
                , Element.row [ Ui.s 10, Ui.cx ]
                    [ Element.text (Strings.dataCapsuleGrain lang 1 ++ " " ++ String.fromInt gosIndex)
                    , Element.text "/"
                    , Element.text (Strings.dataCapsuleSlide lang 1 ++ " " ++ String.fromInt slideIndex)
                    ]
                , Ui.secondaryIcon [ Ui.ar ]
                    { icon = Icons.arrow_forward
                    , action = Utils.tern (slideIndex >= slidesLength) Ui.None <| Ui.Msg <| App.PreparationMsg <| Preparation.GoToNextSlide slideIndex slide
                    , tooltip = Strings.stepsPreparationGoToNextSlide lang
                    }
                ]
            ]
        , Element.column [ Ui.wf, Ui.hf, Ui.s 10 ]
            [ Input.multiline
                [ Ui.wf
                , Ui.hf
                , Element.htmlAttribute <| Html.Attributes.style "pointer-events" <| Utils.tern model.displayPopup "auto" "none"
                ]
                { label = Input.labelHidden (Strings.actionsEditPrompt lang)
                , onChange = \x -> mkMsg (Preparation.PromptChanged Utils.Request { slide | prompt = x })
                , placeholder = Nothing
                , text = slide.prompt
                , spellcheck = False
                }
            , Element.row [ Ui.ar, Ui.s 10 ]
                [ Ui.secondary []
                    { label = Element.text <| Strings.uiCancel lang
                    , action = mkUiMsg (Preparation.PromptChanged Utils.Cancel slide)
                    }
                , Ui.primary []
                    { label = Element.text <| Strings.uiConfirm lang
                    , action = mkUiMsg (Preparation.PromptChanged Utils.Confirm slide)
                    }
                ]
            ]
        ]
        |> Ui.popup (Strings.actionsEditPrompt lang)


{-| Popup to confirm drag n drop that will destroy records.
-}
confirmUpdateCapsulePopup : Lang -> Element App.Msg
confirmUpdateCapsulePopup lang =
    Element.column [ Ui.wf, Ui.hf, Ui.s 10 ]
        [ Ui.paragraph [ Ui.cx, Ui.cy, Font.center ] (Strings.stepsPreparationDndWillBreak lang ++ ".")
        , Element.row [ Ui.ab, Ui.ar, Ui.s 10 ]
            [ Ui.secondary []
                { label = Element.text <| Strings.uiCancel lang
                , action = mkUiMsg Preparation.CancelUpdateCapsule
                }
            , Ui.primary []
                { label = Element.text <| Strings.uiConfirm lang
                , action = mkUiMsg Preparation.ConfirmUpdateCapsule
                }
            ]
        ]
        |> Ui.popup (Strings.uiWarning lang)


{-| Popup to confirm add slide that will destroy records.
-}
confirmAddSlidePopup : Lang -> Int -> Element App.Msg
confirmAddSlidePopup lang gos =
    Element.column [ Ui.wf, Ui.hf, Ui.s 10 ]
        [ Ui.paragraph [ Ui.cx, Ui.cy, Font.center ] (Strings.stepsPreparationAddSlideWillBreak lang ++ ".")
        , Element.row [ Ui.ab, Ui.ar, Ui.s 10 ]
            [ Ui.secondary []
                { label = Element.text <| Strings.uiCancel lang
                , action = mkUiMsg <| Preparation.Resource <| Preparation.SelectAddSlides Utils.Cancel gos
                }
            , Ui.primary []
                { label = Element.text <| Strings.uiConfirm lang
                , action = mkUiMsg <| Preparation.Resource <| Preparation.SelectAddSlides Utils.Confirm gos
                }
            ]
        ]
        |> Ui.popup (Strings.uiWarning lang)


{-| Popup to confirm upload extra video that will destroy records.
-}
confirmUploadExtraVideoPopup : Lang -> FileValue.File -> Data.Slide -> Element App.Msg
confirmUploadExtraVideoPopup lang file _ =
    Element.column [ Ui.wf, Ui.hf, Ui.s 10 ]
        [ Ui.paragraph [ Ui.cx, Ui.cy, Font.center ] (Strings.stepsPreparationAddExtraResourceWillBreak lang ++ ".")
        , Element.row [ Ui.ab, Ui.ar, Ui.s 10 ]
            [ Ui.secondary []
                { label = Element.text <| Strings.uiCancel lang
                , action = mkUiMsg <| Preparation.Resource <| Preparation.SelectedFileReceived Utils.Cancel file
                }
            , Ui.primary []
                { label = Element.text <| Strings.uiConfirm lang
                , action = mkUiMsg <| Preparation.Resource <| Preparation.SelectedFileReceived Utils.Confirm file
                }
            ]
        ]
        |> Ui.popup (Strings.uiWarning lang)


{-| Popup to select the page number when uploading a slide.
-}
selectPageNumberPopup : Lang -> Preparation.Model Capsule -> Preparation.ChangeSlide -> Element App.Msg
selectPageNumberPopup lang model f =
    let
        title =
            case f of
                Preparation.NewCapsule _ _ ->
                    -- This will never happen : new capsule is only used in the NewCapsule route
                    \_ -> ""

                Preparation.ReplaceSlide _ ->
                    Strings.stepsPreparationReplaceSlideOrAddExternalResource

                Preparation.AddSlide _ ->
                    Strings.stepsPreparationAddSlide

                Preparation.AddGos _ ->
                    Strings.stepsPreparationCreateGrain

        nbPages =
            model.resource.nbPages

        textLabel : Element App.Msg
        textLabel =
            Element.text <|
                Lang.question Strings.stepsPreparationWhichPage lang

        buttonBar =
            Element.row [ Ui.ab, Ui.ar, Ui.s 10 ]
                (case ( model.resource.status, model.resource.renderFinished ) of
                    ( RemoteData.Loading _, _ ) ->
                        [ Ui.primary [] { action = Ui.None, label = Ui.spinningSpinner [] 24 } ]

                    ( _, False ) ->
                        [ Ui.primary [] { action = Ui.None, label = Ui.spinningSpinner [] 24 } ]

                    _ ->
                        [ Ui.secondary []
                            { action = mkUiExtra Preparation.PageCancel
                            , label = Element.text <| Strings.uiCancel lang
                            }
                        , if List.isEmpty model.resource.selectedPages then
                            Ui.primary []
                                { action = Ui.None
                                , label = Element.text <| Strings.uiConfirm lang
                                }

                          else
                            Ui.primary []
                                { action = mkUiExtra Preparation.AddSlides
                                , label = Element.text <| Strings.uiConfirm lang
                                }
                        ]
                )

        -- PDF viewer.
        maxCol : Int
        maxCol =
            4

        visibleRow : Int
        visibleRow =
            3

        nbCol : Int
        nbCol =
            min maxCol ((nbPages + 1) // visibleRow + 1)

        nbRow : Int
        nbRow =
            ceiling (toFloat nbPages / toFloat nbCol)

        range : List Int
        range =
            List.range 1 nbPages ++ List.repeat (nbCol * nbRow - nbPages) 0

        pageElement : Int -> Element App.Msg
        pageElement pageId =
            if pageId > 0 then
                let
                    action : Ui.Action App.Msg
                    action =
                        Ui.Msg <| App.PreparationMsg <| Preparation.PageClicked pageId

                    selectionAttributes : List (Html.Attribute App.Msg)
                    selectionAttributes =
                        if List.member pageId model.resource.selectedPages then
                            [ Html.Attributes.style "border" ("3px solid " ++ Colors.colorToString Colors.green1) ]

                        else
                            [ Html.Attributes.style "border" "1px solid #ddd"
                            , Html.Attributes.style "margin" "2px"
                            ]

                    positionIndex : Maybe Int
                    positionIndex =
                        List.indexedMap (\i x -> ( i, x )) model.resource.selectedPages
                            |> List.filter (\( _, x ) -> x == pageId)
                            |> List.head
                            |> Maybe.map Tuple.first

                    numberElement : Element App.Msg
                    numberElement =
                        if List.member pageId model.resource.selectedPages && not model.resource.onlyOnePage then
                            Element.el
                                [ Font.color Colors.green1
                                , Element.htmlAttribute <| Html.Attributes.style "margin" "20px"
                                , Element.htmlAttribute <| Html.Attributes.style "width" "1em"
                                , Element.htmlAttribute <| Html.Attributes.style "height" "1em"
                                , Background.color <| Colors.alphaColor 0.4 Colors.white
                                , Border.rounded 1000
                                , Border.shadow
                                    { offset = ( 0.0, 0.0 )
                                    , size = 5.0
                                    , blur = 4.0
                                    , color = Colors.alphaColor 0.4 Colors.white
                                    }
                                ]
                            <|
                                Element.el [ Ui.cx, Ui.cy ] <|
                                    Element.text <|
                                        String.fromInt <|
                                            Maybe.withDefault 0 positionIndex
                                                + 1

                        else
                            Element.none
                in
                Ui.navigationElement action [ Ui.wf, Element.inFront numberElement ] <|
                    Element.html <|
                        Html.canvas
                            (Html.Attributes.class "wf"
                                :: Html.Attributes.class "hf"
                                :: selectionAttributes
                            )
                            []

            else
                Element.el [ Ui.wf ] Element.none

        pagesElement : List (Element App.Msg)
        pagesElement =
            List.map pageElement range

        split : Int -> List a -> List (List a)
        split i list =
            case List.take i list of
                [] ->
                    []

                listHead ->
                    listHead :: split i (List.drop i list)

        pagesMatrix : List (List (Element App.Msg))
        pagesMatrix =
            split nbCol pagesElement

        pageLine : List (Element App.Msg) -> Element App.Msg
        pageLine pages =
            Element.row
                [ Ui.wf
                , Ui.hf
                , Element.spacing 10
                ]
                pages

        pageColumn : List (List (Element App.Msg)) -> Element App.Msg
        pageColumn pages =
            Element.column
                [ Ui.wf
                , Ui.hf
                , Element.spacing 20
                , Element.htmlAttribute <| Html.Attributes.id "pdf-viewer"
                , Element.scrollbarY
                , Ui.b 1
                , Border.color Colors.greyBorder
                , Ui.p 10
                ]
            <|
                List.map pageLine pages

        canvases : Element App.Msg
        canvases =
            pageColumn pagesMatrix
    in
    Element.column [ Ui.wf, Ui.hf, Element.spacing 10, Element.scrollbarY ]
        [ textLabel
        , canvases
        , buttonBar
        ]
        |> Ui.fixedPopup 5 (title lang)


{-| Finds whether a slide is being dragged.
-}
maybeDragSlide : DnDList.Groups.Model -> List Preparation.Slide -> Maybe Preparation.Slide
maybeDragSlide model slides =
    Preparation.slideSystem.info model
        |> Maybe.andThen (\{ dragIndex } -> slides |> List.drop dragIndex |> List.head)


{-| A helper type to help us deal with the DnD events.
-}
type DragOptions
    = Drag
    | Drop
    | Ghost
    | None


{-| A function that gives the corresponding attributes for slides.
-}
slideStyle : DnDList.Groups.Model -> Int -> DragOptions -> List (Element.Attribute App.Msg)
slideStyle model totalSlideId options =
    (case options of
        Drag ->
            Preparation.slideSystem.dragEvents totalSlideId ("slide-" ++ String.fromInt totalSlideId)

        Drop ->
            Preparation.slideSystem.dropEvents totalSlideId ("slide-" ++ String.fromInt totalSlideId)

        Ghost ->
            Preparation.slideSystem.ghostStyles model

        None ->
            []
    )
        |> List.map Element.htmlAttribute
        |> List.map (Element.mapAttribute mkDnD)


{-| An alias to easily describe non empty lists.
-}
type alias NeList a =
    ( a, List a )


{-| A helper to remove consecutive virtual gos.
-}
filterConsecutiveVirtualGos : List (NeList Preparation.Slide) -> List (NeList Preparation.Slide)
filterConsecutiveVirtualGos input =
    filterConsecutiveVirtualGosAux [] input |> List.reverse


{-| Auxilary function to help write filterConsecutiveVirtualGos.
-}
filterConsecutiveVirtualGosAux : List (NeList Preparation.Slide) -> List (NeList Preparation.Slide) -> List (NeList Preparation.Slide)
filterConsecutiveVirtualGosAux acc input =
    case input of
        [] ->
            acc

        h :: [] ->
            h :: acc

        ( h1, [] ) :: ( h2, [] ) :: t ->
            if h1.slide == Nothing && h2.slide == Nothing then
                filterConsecutiveVirtualGosAux acc (( h2, [] ) :: t)

            else
                filterConsecutiveVirtualGosAux (( h1, [] ) :: acc) (( h2, [] ) :: t)

        h1 :: h2 :: t ->
            filterConsecutiveVirtualGosAux (h1 :: acc) (h2 :: t)


{-| Gets the last element of a non empty list.
-}
neListLast : NeList a -> a
neListLast ( h, t ) =
    case t of
        [] ->
            h

        h1 :: t1 ->
            neListLast ( h1, t1 )


{-| Easily creates a preparation msg.
-}
mkMsg : Preparation.Msg -> App.Msg
mkMsg msg =
    App.PreparationMsg msg


{-| Easily creates a dnd msg.
-}
mkDnD : Preparation.DnDMsg -> App.Msg
mkDnD msg =
    App.PreparationMsg (Preparation.DnD msg)


{-| Easily creates a extra msg.
-}
mkExtra : Preparation.ResourceMsg -> App.Msg
mkExtra msg =
    App.PreparationMsg (Preparation.Resource msg)


{-| Easily creates the Ui.Msg for preparation msg.
-}
mkUiMsg : Preparation.Msg -> Ui.Action App.Msg
mkUiMsg msg =
    mkMsg msg |> Ui.Msg


{-| Easily creates the Ui.Msg for extra msg.
-}
mkUiExtra : Preparation.ResourceMsg -> Ui.Action App.Msg
mkUiExtra msg =
    mkExtra msg |> Ui.Msg
