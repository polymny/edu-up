module Ui.Navbar exposing (navbar, bottombar, leftColumn, addLeftColumn, addLeftAndRightColumn)

{-| This module contains the definition for the nav bar of the polymny app.

@docs navbar, bottombar, leftColumn, addLeftColumn, addLeftAndRightColumn

-}

import App.Types as App
import App.Utils as App
import Config exposing (ClientState, Config)
import Data.Capsule as Data exposing (Capsule)
import Data.Types as Data
import Data.User exposing (User)
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html.Attributes
import Lang exposing (Lang)
import Material.Icons as Icons
import Material.Icons.Types as Icons
import Route exposing (Route)
import Simple.Animation as Animation exposing (Animation)
import Simple.Animation.Animated as Animated
import Simple.Animation.Property as P
import Simple.Transition as Transition
import Strings
import Svg
import Svg.Attributes
import Ui.Colors as Colors
import Ui.Elements as Ui
import Ui.Graphics as Ui
import Ui.Utils as Ui
import Utils


{-| This function creates the navbar of the application.
-}
navbar : Maybe Config -> Maybe App.Page -> Maybe User -> Element App.Msg
navbar config page user =
    let
        lang =
            Maybe.map .clientState config |> Maybe.map .lang |> Maybe.withDefault Lang.default

        capsule =
            Maybe.andThen App.capsuleIdFromPage page

        logo =
            case Maybe.map .plan user of
                Just Data.Admin ->
                    Ui.logoRed

                Just Data.PremiumLvl1 ->
                    Ui.logoBlue

                _ ->
                    Ui.logo

        taskProgress : Maybe Float
        taskProgress =
            config
                |> Maybe.map .clientState
                |> Maybe.map .tasks
                |> Maybe.map (List.filter .global)
                |> Maybe.map (List.filterMap .progress)
                |> Maybe.andThen
                    (\p ->
                        if List.isEmpty p then
                            Nothing

                        else
                            Just <| List.sum p / toFloat (List.length p)
                    )
    in
    Element.row
        [ Background.color Colors.green2, Ui.wf ]
        [ Ui.navigationElement (Ui.Route Route.Home) [ Ui.pl 10, Ui.pr 30 ] logo
        , case ( capsule, page ) of
            ( Just c, Just p ) ->
                navButtons lang c p

            _ ->
                Element.none
        , case user of
            Just u ->
                let
                    showPanel : Bool
                    showPanel =
                        config |> Maybe.map (\x -> x.clientState.showTaskPanel) |> Maybe.withDefault False

                    panelButtonColor : Element.Attr decorative msg
                    panelButtonColor =
                        if showPanel then
                            Background.color <| Colors.alphaColor 0.18 Colors.black

                        else
                            Background.color <| Colors.alpha 0.0

                    panelButtonOver : List (Element.Attr decorative msg)
                    panelButtonOver =
                        if showPanel then
                            []

                        else
                            [ Background.color <| Colors.alpha 0.1 ]
                in
                Element.row
                    [ Font.size 20
                    , Ui.ar
                    , Ui.s 10
                    , Ui.hf
                    , Ui.pr 5
                    ]
                    [ Element.el
                        [ Ui.hf
                        , Ui.id "task-panel"
                        , Element.htmlAttribute <| Html.Attributes.tabindex 0
                        , Element.below <| taskPanel <| Maybe.map .clientState <| config
                        , Element.behindContent <| taskGlobalProgress <| Maybe.withDefault 0.0 taskProgress
                        ]
                        (Ui.navigationElement
                            (Ui.Msg <| App.ConfigMsg Config.ToggleTaskPanel)
                            [ Font.color Colors.white
                            , Ui.cy
                            , Ui.r 100
                            , Ui.p 4
                            , panelButtonColor
                            , Element.mouseOver panelButtonOver
                            , Transition.properties
                                [ Transition.backgroundColor 200 []
                                ]
                                |> Element.htmlAttribute
                            ]
                            (Ui.icon 25 Icons.event_note)
                        )
                    , Ui.navigationElement (Ui.Route Route.Settings)
                        [ Font.color Colors.white
                        , Ui.r 100
                        , Ui.p 4
                        , Element.mouseOver [ Background.color <| Colors.alpha 0.1 ]
                        , Transition.properties
                            [ Transition.backgroundColor 200 []
                            ]
                            |> Element.htmlAttribute
                        ]
                      <|
                        Ui.icon 25 Icons.settings
                    , Element.text u.username
                    , Ui.secondary []
                        { action = Ui.Msg App.Logout
                        , label = Element.text <| Strings.loginLogout lang
                        }
                    ]

            _ ->
                Element.none
        ]


taskGlobalProgress : Float -> Element App.Msg
taskGlobalProgress value =
    let
        r : Float
        r =
            19

        circumference : Float
        circumference =
            2 * pi * r
    in
    Element.el [ Ui.cx, Ui.cy ] <|
        Element.html <|
            Svg.svg
                [ Svg.Attributes.width "56"
                , Svg.Attributes.height "56"
                ]
                [ Svg.circle
                    [ Svg.Attributes.cx "28"
                    , Svg.Attributes.cy "28"
                    , Html.Attributes.style "transition" "0.35s stroke-dashoffset"
                    , Html.Attributes.style "transform" "rotate(90deg)"
                    , Html.Attributes.style "transform-origin" "50% 50%"
                    , Svg.Attributes.r (String.fromFloat r)
                    , Svg.Attributes.stroke "white"
                    , Svg.Attributes.strokeWidth "4"
                    , Svg.Attributes.fill "transparent"
                    , Svg.Attributes.strokeDasharray (String.fromFloat circumference)
                    , (1.0 - value)
                        * circumference
                        |> String.fromFloat
                        |> Svg.Attributes.strokeDashoffset
                    ]
                    []
                ]


taskPanel : Maybe ClientState -> Element App.Msg
taskPanel clientState =
    let
        lang : Lang
        lang =
            clientState
                |> Maybe.map .lang
                |> Maybe.withDefault Lang.default

        showTaskPanel : Bool
        showTaskPanel =
            clientState
                |> Maybe.map .showTaskPanel
                |> Maybe.withDefault False

        tasks : List Config.TaskStatus
        tasks =
            clientState
                |> Maybe.map .tasks
                |> Maybe.withDefault []

        taskInfo : Config.TaskStatus -> Element App.Msg
        taskInfo taskStatus =
            let
                name : String
                name =
                    case taskStatus.task of
                        Config.UploadRecord _ _ gosId _ ->
                            Strings.tasksUploadRecord lang
                                ++ " ("
                                ++ String.fromInt (gosId + 1)
                                ++ ")"

                        Config.UploadTrack _ _ ->
                            Strings.tasksUploadTrack lang

                        Config.AddGos _ _ ->
                            Strings.tasksUploadExtra lang

                        Config.AddSlide _ _ ->
                            Strings.tasksUploadExtra lang

                        Config.ReplaceSlide _ _ ->
                            Strings.tasksUploadExtra lang

                        Config.ExportCapsule _ _ ->
                            Strings.tasksExportCapsule lang

                        Config.ImportCapsule _ ->
                            Strings.tasksImportCapsule lang

                        Config.Production _ _ ->
                            Strings.tasksProductionCapsule lang

                        Config.Publication _ _ ->
                            Strings.tasksPublicationCapsule lang

                        Config.TranscodeExtra _ _ _ ->
                            Strings.tasksTranscodeExtra lang

                -- _ ->
                --     Strings.tasksUnknown lang
                color : Element.Color
                color =
                    if taskStatus.aborted then
                        Colors.red

                    else if taskStatus.finished then
                        Colors.green2

                    else
                        Colors.orange

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

                bar : Element App.Msg
                bar =
                    case taskStatus.progress of
                        Just progress ->
                            Element.el
                                [ Ui.wf
                                , Ui.hf
                                , Ui.r 5
                                , Element.moveLeft (300.0 * (1.0 - progress))
                                , Background.color color
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
                                [ Ui.wf, Ui.hf, Ui.r 5, Background.color Colors.blue ]
                                Element.none

                icon : Icons.Icon msg
                icon =
                    if taskStatus.finished then
                        Icons.close

                    else
                        Icons.cancel

                action : Ui.Action App.Msg
                action =
                    if taskStatus.finished then
                        Ui.Msg <| App.ConfigMsg <| Config.RemoveTask taskStatus.task

                    else
                        Ui.Msg <| App.ConfigMsg <| Config.AbortTask taskStatus.task
            in
            Element.column [ Ui.s 10 ]
                [ Element.el [ Ui.wf, Ui.bt 1, Border.color <| Colors.alphaColor 0.1 Colors.greyFont ] Element.none
                , Element.el [ Font.size 18 ] <| Element.text name
                , Element.row [ Ui.s 10 ]
                    [ Element.el
                        [ Ui.p 3
                        , Ui.wpx 300
                        , Ui.hpx 12
                        , Ui.r 20
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
                            bar
                    , Ui.navigationElement action
                        [ Ui.r 100
                        , Ui.p 4
                        , Element.mouseOver [ Background.color <| Colors.alpha 0.1 ]
                        , Transition.properties
                            [ Transition.backgroundColor 200 []
                            ]
                            |> Element.htmlAttribute
                        ]
                        (Ui.icon 20 icon)
                    ]
                ]

        clientTasks : List Config.TaskStatus
        clientTasks =
            tasks
                |> List.filter (\t -> Config.isClientTask t)

        serverTasks : List Config.TaskStatus
        serverTasks =
            tasks
                |> List.filter (\t -> Config.isServerTask t)

        noTasksElement : Element App.Msg
        noTasksElement =
            if List.length tasks == 0 then
                Element.el [ Font.bold ] <| Element.text <| Strings.uiTasksNone lang

            else
                Element.none

        clientTasksElement : Element App.Msg
        clientTasksElement =
            if List.length clientTasks > 0 then
                Element.column
                    [ Ui.s 10, Ui.pt 10, Font.bold ]
                    ((Element.text <| Strings.uiTasksClient lang) :: List.map taskInfo clientTasks)

            else
                Element.none

        serverTasksElement : Element App.Msg
        serverTasksElement =
            if List.length serverTasks > 0 then
                Element.column
                    [ Ui.s 10, Ui.pt 10, Font.bold ]
                    ((Element.text <| Strings.uiTasksServer lang) :: List.map taskInfo serverTasks)

            else
                Element.none

        taskView : Element App.Msg
        taskView =
            Element.column
                [ Ui.p 8
                , Ui.s 10
                , Ui.b 1
                , Border.color <| Colors.alphaColor 0.8 Colors.greyFont
                , Border.shadow
                    { offset = ( 0.0, 0.0 )
                    , size = 3.0
                    , blur = 3.0
                    , color = Colors.alpha 0.1
                    }
                , Border.roundEach
                    { bottomLeft = 5
                    , bottomRight = 5
                    , topLeft = 5
                    , topRight = 5
                    }
                , Background.color Colors.white
                ]
                [ noTasksElement, clientTasksElement, serverTasksElement ]
    in
    Element.el
        [ Element.alignRight
        , Element.height <| Element.maximum 300 Element.fill
        , Element.alpha <| Utils.tern showTaskPanel 1.0 0.0
        , Transition.properties
            [ Transition.opacity 200 [] ]
            |> Element.htmlAttribute
        ]
    <|
        Utils.tern showTaskPanel taskView Element.none


{-| This function creates a row with the navigation buttons of the different tabs of a capsule.
-}
navButtons : Lang -> String -> App.Page -> Element msg
navButtons lang capsuleId page =
    let
        buttonWidth : Int
        buttonWidth =
            100

        separator : Element msg
        separator =
            Element.el [ Ui.wpx 1, Ui.hpx 30, Background.color Colors.greyBackground ] Element.none

        makeButton : Route -> String -> Bool -> Element msg
        makeButton route label hoverable =
            let
                attr : List (Element.Attribute msg)
                attr =
                    [ Ui.hf
                    , Ui.wf
                    , Font.bold
                    , Ui.rt 10
                    , Element.mouseOver [ Background.color <| Colors.alphaColor (Utils.tern hoverable 0.1 0.0) Colors.black ]
                    , Transition.properties
                        [ Transition.backgroundColor 200 []
                        ]
                        |> Element.htmlAttribute
                    ]
            in
            Element.column [ Ui.hf, Ui.wpx buttonWidth ]
                [ Element.el [ Ui.hpx 5, Ui.wf ] Element.none
                , Ui.navigationElement (Ui.Route route) attr <| Element.el [ Ui.wf, Font.center ] (Element.text label)
                ]

        selectorIndex : Int
        selectorIndex =
            case page of
                App.Preparation _ ->
                    0

                App.Acquisition _ ->
                    1

                App.Production _ ->
                    2

                App.Publication _ ->
                    3

                App.Options _ ->
                    4

                _ ->
                    -1

        selectorMove : Float
        selectorMove =
            toFloat (selectorIndex * (buttonWidth + 1) - 1)

        selector : Int -> Element msg
        selector index =
            if index == -1 then
                Element.none

            else
                Element.column
                    [ Element.htmlAttribute <| Html.Attributes.style "position" "absolute"
                    , Element.htmlAttribute <| Html.Attributes.style "height" "100%"
                    , Element.moveRight selectorMove
                    , Ui.wpx (buttonWidth + 2)
                    , Element.htmlAttribute <|
                        Transition.properties [ Transition.transform 200 [ Transition.easeInOut ] ]
                    ]
                    [ Element.el [ Ui.hpx 5, Ui.wf ] Element.none
                    , Element.el [ Ui.hf, Ui.wf, Font.bold, Ui.rt 10, Background.color Colors.greyBackground ] Element.none
                    ]
    in
    Element.row [ Ui.hf ]
        [ selector selectorIndex
        , makeButton (Route.Preparation capsuleId) (Strings.stepsPreparationPrepare lang) (selectorIndex /= 0)
        , separator
        , makeButton (Route.Acquisition capsuleId 0) (Strings.stepsAcquisitionRecord lang) (selectorIndex /= 1)
        , separator
        , makeButton (Route.Production capsuleId 0) (Strings.stepsProductionProduce lang) (selectorIndex /= 2)
        , separator
        , makeButton (Route.Publication capsuleId) (Strings.stepsPublicationPublish lang) (selectorIndex /= 3)
        , separator
        , makeButton (Route.Options capsuleId) (Strings.stepsOptionsOptions lang) (selectorIndex /= 4)
        ]


{-| This function creates the bottom bar of the application.
-}
bottombar : Maybe Config -> Element App.MaybeMsg
bottombar config =
    let
        lang =
            Maybe.map (\x -> x.clientState.lang) config |> Maybe.withDefault Lang.default
    in
    Element.row
        [ Background.color (Colors.grey 3)
        , Font.color Colors.greyBackground
        , Ui.wf
        , Ui.s 20
        , Ui.p 15
        , Font.size 16
        , Font.bold
        ]
        [ Ui.link
            [ Element.mouseOver [ Font.color Colors.greyBackground ] ]
            { label = "contacter@polymny.studio"
            , action = Ui.NewTab "mailto:contacter@polymny.studio"
            }
        , Ui.link [ Ui.ar, Element.mouseOver [ Font.color Colors.greyBackground ] ]
            { label = Strings.configLicense lang
            , action = Ui.NewTab "https://github.com/polymny/polymny/blob/master/LICENSE"
            }
        , Ui.link [ Ui.ar, Element.mouseOver [ Font.color Colors.greyBackground ] ]
            { label = Strings.loginTermsOfService lang
            , action = Ui.NewTab "https://polymny.studio/cgu/"
            }
        , Ui.link [ Ui.ar, Element.mouseOver [ Font.color Colors.greyBackground ] ]
            { label = Strings.configSource lang
            , action = Ui.NewTab "https://github.com/polymny/polymny"
            }
        , Ui.link [ Ui.ar, Element.mouseOver [ Font.color Colors.greyBackground ] ]
            { label = Strings.configLang lang ++ " " ++ Lang.flag lang
            , action = Ui.Msg <| App.LoggedMsg <| App.ConfigMsg <| Config.ToggleLangPicker
            }
        , config
            |> Maybe.map .serverConfig
            |> Maybe.map .version
            |> Maybe.map (\x -> Element.text (Strings.configVersion lang ++ " " ++ x))
            |> Maybe.withDefault Element.none
        , config
            |> Maybe.map .serverConfig
            |> Maybe.andThen .commit
            |> Maybe.map (\x -> Element.text (Strings.configCommit lang ++ " " ++ x))
            |> Maybe.withDefault Element.none
        ]


{-| This function creates the left column of the capsule pages, which presents the grains.
-}
leftColumn : Lang -> App.Page -> Capsule -> Maybe Int -> Element msg
leftColumn lang page capsule selectedGos =
    let
        gosView : Int -> Data.Gos -> Element msg
        gosView id gos =
            let
                inFrontLabel =
                    Strings.dataCapsuleGrain lang 1
                        ++ " "
                        ++ String.fromInt (id + 1)
                        |> Element.text
                        |> Element.el [ Ui.p 5, Ui.rbr 5, Background.color Colors.greyBorder, Font.color Colors.greyFont ]

                fillWithLink =
                    Ui.link [ Ui.wf, Ui.hf ] { label = "", action = action }

                inFrontButtons =
                    [ fillWithLink
                    , Element.row [ Ui.p 5, Ui.s 5 ]
                        [ case Data.recordPath capsule gos of
                            Just url ->
                                Ui.primaryIcon []
                                    { action = Ui.NewTab url
                                    , icon = Icons.theaters
                                    , tooltip = ""
                                    }

                            _ ->
                                Element.none
                        , Ui.primaryIcon []
                            { action = Ui.Route (Route.Acquisition capsule.id id)
                            , icon = Icons.videocam
                            , tooltip = ""
                            }
                        ]
                    ]
                        |> Element.row [ Ui.wf, Ui.at ]
                        |> (\x -> Element.column [ Ui.wf, Ui.hf ] [ x, fillWithLink ])

                borderColor =
                    if selectedGos == Just id then
                        Colors.green1

                    else
                        Colors.greyBorder

                action =
                    case page of
                        App.Preparation _ ->
                            id + 1 |> String.fromInt |> (\x -> "#" ++ x) |> Route.Custom |> Ui.Route

                        App.Publication _ ->
                            id + 1 |> String.fromInt |> (\x -> "#" ++ x) |> Route.Custom |> Ui.Route

                        App.Options _ ->
                            Route.Production capsule.id id |> Ui.Route

                        _ ->
                            id + 1 |> String.fromInt |> Route.Custom |> Ui.Route
            in
            Element.image
                [ Ui.wf
                , Ui.b 5
                , Border.color borderColor
                , Element.inFront inFrontLabel
                , Element.inFront inFrontButtons
                ]
                { src = Maybe.map (Data.slidePath capsule) (List.head gos.slides) |> Maybe.withDefault "oops"
                , description = ""
                }
    in
    Element.column
        [ Background.color Colors.greyBackground
        , Ui.p 10
        , Ui.br 1
        , Border.color Colors.greyBorder
        , Ui.s 10
        , Ui.wf
        , Ui.hf
        , Element.scrollbarY
        ]
        (List.indexedMap gosView capsule.structure)


{-| Adds the left column to an already existing element.
-}
addLeftColumn : Lang -> App.Page -> Capsule -> Maybe Int -> ( Element msg, Element msg ) -> ( Element msg, Element msg )
addLeftColumn lang page capsule selectedGos ( element, popup ) =
    ( Element.row [ Ui.wf, Ui.hf, Element.scrollbars ]
        [ Element.el [ Ui.wfp 1, Ui.hf, Element.scrollbarY ] (leftColumn lang page capsule selectedGos)
        , Element.el [ Ui.wfp 5, Ui.hf, Element.scrollbarY ] element
        ]
    , popup
    )


{-| Adds the left column to an already existing element with its own right column.
-}
addLeftAndRightColumn : Lang -> App.Page -> Capsule -> Maybe Int -> ( Element msg, Element msg, Element msg ) -> ( Element msg, Element msg )
addLeftAndRightColumn lang page capsule selectedGos ( element, rightColumn, popup ) =
    ( Element.row [ Ui.wf, Ui.hf, Element.scrollbars ]
        [ Element.el [ Ui.wfp 1, Ui.hf, Element.scrollbarY ] (leftColumn lang page capsule selectedGos)
        , Element.el [ Ui.wfp 4, Ui.hf, Element.scrollbarY ] element
        , Element.el [ Ui.wfp 1, Ui.hf, Element.scrollbarY ] rightColumn
        ]
    , popup
    )
