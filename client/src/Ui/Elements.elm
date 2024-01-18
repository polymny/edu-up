module Ui.Elements exposing
    ( primary, primaryGeneric, primaryIcon, secondary, secondaryGeneric, secondaryIcon, link, Action(..), navigationElement, icon, title, animatedEl, spin
    , spinner, spinningSpinner, popup, fixedPopup, checkbox, option, sliderThumb
    , addLinkAttr, errorModal, longText, successModal
    )

{-| This module contains helpers to easily make buttons.

@docs primary, primaryGeneric, primaryIcon, secondary, secondaryGeneric, secondaryIcon, link, Action, navigationElement, icon, title, animatedEl, spin
@docs spinner, spinningSpinner, popup, fixedPopup, checkbox, option, sliderThumb
@docs errorModaln successModal

-}

import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html
import Html.Attributes
import Json.Decode exposing (float, int)
import Material.Icons.Types exposing (Coloring(..), Icon)
import Route exposing (Route)
import Simple.Animation as Animation exposing (Animation)
import Simple.Animation.Animated as Animated
import Simple.Animation.Property as P
import Simple.Transition as Transition
import Svg exposing (Svg, g, svg)
import Svg.Attributes exposing (..)
import Ui.Colors as Colors
import Ui.Utils as Ui


{-| The different actions a button can have.

It can be an url, which means clicking the button will navigate to the url, or it can be a message that the button will
trigger.

-}
type Action msg
    = Route Route
    | NewTab String
    | Download String
    | Msg msg
    | None


{-| Creates a primary button with a generic element.
-}
primaryGeneric : List (Element.Attribute msg) -> List (Element.Attribute msg) -> { label : Element msg, action : Action msg } -> Element msg
primaryGeneric outerAttr innerAttr { label, action } =
    let
        outer =
            outerAttr
                ++ [ Background.color Colors.green2
                   , Border.color Colors.greyBorder
                   , Ui.b 1
                   ]
                ++ (if action == None then
                        [ Background.color <| Colors.alpha 0.1 ]

                    else
                        []
                   )

        inner =
            innerAttr
                ++ [ Font.center
                   , Ui.wf
                   , Ui.hf
                   , Element.mouseOver <| [ Background.color <| Colors.alpha 0.1 ]
                   , Transition.properties
                        [ Transition.backgroundColor 200 []
                        ]
                        |> Element.htmlAttribute
                   ]
                ++ (if action == None then
                        [ Background.color <| Colors.alpha 0.1 ]

                    else
                        []
                   )
    in
    navigationElement action outer (Element.el inner label)


{-| Creates a primary button, with colored background and white text.
-}
primary : List (Element.Attribute msg) -> { label : Element msg, action : Action msg } -> Element msg
primary attr { label, action } =
    let
        outerAttr : List (Element.Attribute msg)
        outerAttr =
            Border.rounded 100 :: attr

        innerAttr : List (Element.Attribute msg)
        innerAttr =
            [ Border.rounded 100, Ui.p 12, Font.bold, Font.color Colors.white ]
    in
    primaryGeneric outerAttr innerAttr { label = label, action = action }


{-| Creates a primary button with an icon.
-}
primaryIcon : List (Element.Attribute msg) -> { icon : Icon msg, tooltip : String, action : Action msg } -> Element msg
primaryIcon attr params =
    let
        outerAttr : List (Element.Attribute msg)
        outerAttr =
            Border.rounded 5 :: Font.color Colors.white :: Ui.tooltip params.tooltip :: attr

        innerAttr : List (Element.Attribute msg)
        innerAttr =
            [ Border.rounded 5, Ui.p 2 ]
    in
    primaryGeneric outerAttr innerAttr { label = icon 22 params.icon, action = params.action }


{-| Creates a secondary button with a generic element.
-}
secondaryGeneric : List (Element.Attribute msg) -> List (Element.Attribute msg) -> { label : Element msg, action : Action msg } -> Element msg
secondaryGeneric outerAttr innerAttr { label, action } =
    let
        outer =
            outerAttr
                ++ [ Background.color Colors.white
                   , Border.color Colors.greyBorder
                   , Ui.b 1
                   ]

        inner =
            innerAttr
                ++ [ Font.center
                   , Ui.wf
                   , Ui.hf
                   , Element.mouseOver <| [ Background.color <| Colors.alpha 0.1 ]
                   , Transition.properties
                        [ Transition.backgroundColor 200 []
                        ]
                        |> Element.htmlAttribute
                   ]
                ++ (if action == None then
                        [ Background.color <| Colors.alpha 0.1 ]

                    else
                        []
                   )
    in
    navigationElement action outer (Element.el inner label)


{-| Creates a primary button, with colored background and white text.
-}
secondary : List (Element.Attribute msg) -> { label : Element msg, action : Action msg } -> Element msg
secondary attr { label, action } =
    let
        outerAttr : List (Element.Attribute msg)
        outerAttr =
            Border.rounded 100 :: Font.color Colors.black :: attr

        innerAttr : List (Element.Attribute msg)
        innerAttr =
            [ Border.rounded 100, Ui.p 12, Font.bold ]
    in
    secondaryGeneric outerAttr innerAttr { label = label, action = action }


{-| Creates a secondary button with an icon.
-}
secondaryIcon : List (Element.Attribute msg) -> { icon : Icon msg, tooltip : String, action : Action msg } -> Element msg
secondaryIcon attr params =
    let
        outerAttr : List (Element.Attribute msg)
        outerAttr =
            Border.rounded 5 :: Font.color Colors.green2 :: Ui.tooltip params.tooltip :: attr

        innerAttr : List (Element.Attribute msg)
        innerAttr =
            [ Ui.p 2 ]
    in
    secondaryGeneric outerAttr innerAttr { label = icon 22 params.icon, action = params.action }


{-| Creates a link, colored and changing color at hover.
-}
link : List (Element.Attribute msg) -> { label : String, action : Action msg } -> Element msg
link attr { label, action } =
    navigationElement action (addLinkAttr attr) (Element.text label)


{-| The attributes of a link.
-}
addLinkAttr : List (Element.Attribute msg) -> List (Element.Attribute msg)
addLinkAttr attr =
    Font.color Colors.green1 :: Element.mouseOver [ Font.color Colors.greyFont ] :: attr


{-| An utility functions to create buttons or link depending on the action.
-}
navigationElement : Action msg -> List (Element.Attribute msg) -> Element msg -> Element msg
navigationElement action attr label =
    let
        newAttr : List (Element.Attribute msg)
        newAttr =
            Element.focused [] :: attr
    in
    case action of
        Route route ->
            Element.link newAttr { url = Route.toUrl route, label = label }

        NewTab url ->
            Element.newTabLink newAttr { url = url, label = label }

        Download url ->
            Element.download newAttr { url = url, label = label }

        Msg msg ->
            Input.button newAttr { onPress = Just msg, label = label }

        None ->
            Element.el
                (newAttr
                    ++ [ Element.htmlAttribute (Html.Attributes.style "cursor" "not-allowed")
                       , Font.color Colors.greyFontDisabled
                       ]
                )
                label


{-| Transforms an icon into an elm-ui element.
-}
icon : Int -> Icon msg -> Element msg
icon size material =
    Element.html (material size Inherit)


{-| Creates a title.
-}
title : String -> Element msg
title content =
    Element.el [ Font.bold, Font.size 20 ] (Element.text content)


{-| Helper to create icons.
-}
makeIcon : List (Svg.Attribute msg) -> List (Svg msg) -> Icon msg
makeIcon attributes nodes size _ =
    let
        sizeAsString =
            String.fromInt size
    in
    svg
        (attributes ++ [ height sizeAsString, width sizeAsString ])
        [ g
            [ fill "currentColor"
            ]
            nodes
        ]


{-| Shortcut for Animated.ui
-}
animatedUi =
    Animated.ui
        { behindContent = Element.behindContent
        , htmlAttribute = Element.htmlAttribute
        , html = Element.html
        }


{-| Creates a spinner.
-}
spinner : Icon msg
spinner =
    makeIcon
        [ viewBox "0 0 24 24" ]
        [ Svg.path [ d "M0 0h24v24H0z", fill "none" ] []
        , Svg.path [ d "M2 12A 10 10 10 1 1 12 22", fill "none", stroke "currentColor", strokeWidth "2" ] []
        ]


{-| Makes an animated Element.el.
-}
animatedEl : Animation -> List (Element.Attribute msg) -> Element msg -> Element msg
animatedEl =
    animatedUi Element.el


{-| An animation to make an element spin.
-}
spin : Animation
spin =
    Animation.fromTo
        { duration = 1000, options = [ Animation.loop, Animation.linear ] }
        [ P.rotate 0 ]
        [ P.rotate 360 ]


{-| A spinning spinner.
-}
spinningSpinner : List (Element.Attribute msg) -> Int -> Element msg
spinningSpinner attr size =
    animatedEl spin attr (icon size spinner)


{-| A popup.
-}
popup : String -> Element msg -> Element msg
popup titleText content =
    let
        popupElement : Element msg
        popupElement =
            Element.column
                [ Background.color Colors.green2
                , Ui.r 10
                , Ui.b 1
                , Ui.cy
                , Ui.cx
                , Element.htmlAttribute <| Html.Attributes.style "max-width" "80%"
                , Element.htmlAttribute <| Html.Attributes.style "max-height" "80%"
                , Element.htmlAttribute <| Html.Attributes.style "min-width" "40%"
                , Element.htmlAttribute <| Html.Attributes.style "min-height" "40%"
                , Border.color <| Colors.alphaColor 0.8 Colors.greyFont
                , Border.shadow
                    { offset = ( 0.0, 0.0 )
                    , size = 3.0
                    , blur = 3.0
                    , color = Colors.alpha 0.1
                    }
                , Element.scrollbars
                ]
                [ Element.el [ Ui.p 10, Ui.cx, Font.color Colors.white, Font.bold ] (Element.text titleText)
                , Element.el
                    [ Background.color Colors.greyBackground
                    , Ui.p 10
                    , Ui.r 10
                    , Ui.wf
                    , Ui.hf
                    , Border.shadow
                        { offset = ( 0.0, 0.0 )
                        , size = 3.0
                        , blur = 3.0
                        , color = Colors.alpha 0.1
                        }
                    ]
                    content
                ]
    in
    Element.el
        [ Ui.zIndex 1
        , Ui.wf
        , Ui.hf
        , Background.color (Element.rgba255 0 0 0 0.5)
        ]
        popupElement


{-| A popup with fixed size.
-}
fixedPopup : Int -> String -> Element msg -> Element msg
fixedPopup size titleText content =
    Element.row [ Ui.zIndex 1, Ui.wf, Ui.hf, Background.color (Element.rgba255 0 0 0 0.5), Element.scrollbars ]
        [ Element.el [ Ui.wfp 1 ] Element.none
        , Element.column [ Ui.hf, Ui.wfp size, Element.scrollbars ]
            [ Element.el [ Ui.hfp 1 ] Element.none
            , Element.column
                [ Ui.wf
                , Ui.hfp size
                , Background.color Colors.green2
                , Ui.r 10
                , Ui.b 1
                , Border.color <| Colors.alphaColor 0.8 Colors.greyFont
                , Border.shadow
                    { offset = ( 0.0, 0.0 )
                    , size = 3.0
                    , blur = 3.0
                    , color = Colors.alpha 0.1
                    }
                , Element.scrollbars
                ]
                [ Element.el [ Ui.p 10, Ui.cx, Font.color Colors.white, Font.bold ] (Element.text titleText)
                , Element.el
                    [ Ui.wf
                    , Ui.hf
                    , Background.color Colors.greyBackground
                    , Ui.p 10
                    , Ui.r 10
                    , Element.scrollbars
                    , Border.shadow
                        { offset = ( 0.0, 0.0 )
                        , size = 3.0
                        , blur = 3.0
                        , color = Colors.alpha 0.1
                        }
                    ]
                    content
                ]
            , Element.el [ Ui.hfp 1 ] Element.none
            ]
        , Element.el [ Ui.wfp 1 ] Element.none
        ]


{-| Helper to create an error modal.
-}
errorModal : List (Element.Attribute msg) -> Element msg -> Element msg
errorModal attr input =
    Element.el
        (Border.color Colors.red
            :: Font.color Colors.red
            :: Background.color Colors.redLight
            :: Ui.b 1
            :: Ui.p 10
            :: Ui.r 5
            :: attr
        )
        input


{-| Helper to create a success modal.
-}
successModal : List (Element.Attribute msg) -> Element msg -> Element msg
successModal attr input =
    Element.el
        (Border.color Colors.green2
            :: Font.color Colors.green2
            :: Background.color Colors.greenLight
            :: Ui.b 1
            :: Ui.p 10
            :: Ui.r 5
            :: attr
        )
        input


{-| Displays a long text that can have ellipsis if too long, in which case the full text will be visible from its title
(tooltip).
-}
longText : List (Element.Attribute msg) -> String -> Element msg
longText attr text =
    Html.div
        [ Html.Attributes.style "overflow" "hidden"
        , Html.Attributes.style "text-overflow" "ellipsis"
        , Html.Attributes.class "might-overflow"
        ]
        [ Html.text text ]
        |> Element.html
        |> Element.el
            (Element.htmlAttribute (Html.Attributes.style "overflow" "hidden")
                :: Element.htmlAttribute (Html.Attributes.class "wf")
                :: attr
            )


{-| Creates a checkbox.
-}
checkbox : Bool -> Bool -> Element msg
checkbox disabled checked =
    let
        scale : Float
        scale =
            20.0

        baseWidth : Float
        baseWidth =
            1.8

        baseHeight : Float
        baseHeight =
            1.0

        buttSize : Float
        buttSize =
            1.2

        pos : Float
        pos =
            if checked then
                scale * (baseWidth - baseHeight)

            else
                0.0

        dura : Float
        dura =
            0.2

        duraSvg : Float
        duraSvg =
            0.5

        color1 : Element.Color
        color1 =
            if disabled then
                Element.rgb255 197 235 155

            else
                Colors.green2

        color2 : Element.Color
        color2 =
            if disabled then
                Colors.grey 6

            else
                Colors.grey 5

        color3 : Element.Color
        color3 =
            if disabled then
                Colors.grey 7

            else
                Colors.grey 6
    in
    Element.el [ Ui.px 5, Ui.p (ceiling ((buttSize - baseHeight) * scale + 0.4 * scale)) ] <|
        Element.el
            [ Ui.wpx <| floor (scale * baseWidth)
            , Ui.hpx <| floor (scale * baseHeight)
            , Ui.r <| floor (scale * baseHeight)
            , Element.htmlAttribute <|
                Html.Attributes.style "transition" <|
                    "background "
                        ++ String.fromFloat dura
                        ++ "s ease-in-out"
            , Background.color <|
                if checked then
                    color1

                else
                    color2
            , Element.inFront <|
                Element.el
                    [ Ui.wpx <| floor (scale * buttSize)
                    , Ui.hpx <| floor (scale * buttSize)
                    , Ui.r <| floor (scale * buttSize)
                    , Background.color color3
                    , Border.shadow
                        { offset = ( 0.0, 0.1 * scale )
                        , size = 0.0
                        , blur = 0.3 * scale
                        , color = color2
                        }
                    , Element.focused
                        [ Border.shadow
                            { offset = ( 0.0, 0.0 )
                            , size = 2.0
                            , blur = 2.0
                            , color = color1
                            }
                        ]
                    , Element.moveUp (scale * (buttSize - baseHeight) / 2.0)
                    , Element.moveLeft (scale * (buttSize - baseHeight) / 2.0 - pos)
                    , Element.htmlAttribute <|
                        Html.Attributes.style "transition" <|
                            "transform "
                                ++ String.fromFloat dura
                                ++ "s ease-in-out"
                    ]
                <|
                    Element.html <|
                        Svg.svg
                            [ Svg.Attributes.width <| String.fromFloat (scale * buttSize / 2.0) ++ "px"
                            , Svg.Attributes.height <| String.fromFloat (scale * buttSize / 2.0) ++ "px"
                            , Svg.Attributes.viewBox "0 0 10 10"
                            , Svg.Attributes.fill "none"
                            , Svg.Attributes.transform <|
                                "translate("
                                    ++ String.fromFloat (scale * buttSize / 4.0)
                                    ++ ", "
                                    ++ String.fromFloat (scale * buttSize / 4.0)
                                    ++ ")"
                            ]
                            [ Svg.path
                                [ Svg.Attributes.d "M5,1 L5,1 C2.790861,1 1,2.790861 1,5 L1,5 C1,7.209139 2.790861,9 5,9 L5,9 C7.209139,9 9,7.209139 9,5 L9,5 C9,2.790861 7.209139,1 5,1 L5,9 L5,1 Z"
                                , Svg.Attributes.strokeDashoffset <|
                                    if checked then
                                        "25"

                                    else
                                        "0"
                                , Svg.Attributes.strokeDasharray <|
                                    if checked then
                                        "25.03"

                                    else
                                        "25"
                                , Svg.Attributes.strokeWidth "2"
                                , Svg.Attributes.strokeLinecap "round"
                                , Svg.Attributes.strokeLinejoin "round"
                                , Svg.Attributes.stroke <|
                                    if checked then
                                        Colors.colorToString color1

                                    else
                                        Colors.colorToString color2
                                , Html.Attributes.style "transition" <| "all " ++ String.fromFloat duraSvg ++ "s ease-in-out"
                                ]
                                []
                            ]
            ]
            Element.none


{-| Creates a radio button.
-}
option : Bool -> Element msg -> Input.OptionState -> Element msg
option disabled label state =
    let
        scale : Float
        scale =
            8.0

        dura : Float
        dura =
            0.3

        color1 : Element.Color
        color1 =
            if disabled then
                Colors.grey 6

            else
                Colors.green2

        color2 : Element.Color
        color2 =
            if disabled then
                Colors.grey 5

            else
                Colors.grey 6

        color3 : Element.Color
        color3 =
            if disabled then
                Colors.grey 7

            else
                Colors.grey 8
    in
    Element.row [ Ui.s 10, Ui.p <| ceiling (0.3 * scale) ]
        [ Element.el
            [ Ui.wpx <| floor <| 2 * scale
            , Ui.hpx <| floor <| 2 * scale
            , Ui.r <| floor scale
            , Background.color color3
            , Element.focused
                [ Border.shadow
                    { offset = ( 0.0, 0.0 )
                    , size = 0.25 * scale
                    , blur = 0.25 * scale
                    , color = color1
                    }
                ]
            , Border.shadow
                { offset = ( 0.0, 0.1 * scale )
                , size = 0.0
                , blur = 0.3 * scale
                , color = color2
                }
            ]
          <|
            Element.html <|
                Svg.svg
                    [ Svg.Attributes.width <| String.fromInt (floor <| 2 * scale) ++ "px"
                    , Svg.Attributes.height <| String.fromInt (floor <| 2 * scale) ++ "px"
                    , Svg.Attributes.viewBox "0 0 10 10"
                    , Svg.Attributes.fill "none"
                    ]
                    [ Svg.circle
                        [ Svg.Attributes.cx "5"
                        , Svg.Attributes.cy "5"
                        , Svg.Attributes.r <|
                            if state == Input.Selected then
                                "1.25"

                            else
                                "4.5"
                        , Svg.Attributes.stroke <| Colors.colorToString color1
                        , Svg.Attributes.strokeWidth <|
                            if state == Input.Selected then
                                "2.5"

                            else
                                "1.0"
                        , Svg.Attributes.strokeLinecap "round"
                        , Svg.Attributes.strokeLinejoin "round"
                        , Html.Attributes.style "transition" <| "all " ++ String.fromFloat dura ++ "s ease-in-out"
                        ]
                        []
                    , Svg.circle
                        [ Svg.Attributes.cx "5"
                        , Svg.Attributes.cy "5"
                        , Svg.Attributes.r "4.5"
                        , Svg.Attributes.stroke <| Colors.colorToString color1
                        , Svg.Attributes.strokeWidth "1.0"
                        , Svg.Attributes.strokeLinecap "round"
                        , Svg.Attributes.strokeLinejoin "round"
                        ]
                        []
                    ]
        , label
        ]


{-| Creates a slider thumb.
-}
sliderThumb : Bool -> Input.Thumb
sliderThumb disabled =
    let
        scale : Float
        scale =
            16.0

        color1 : Element.Color
        color1 =
            if disabled then
                Colors.grey 7

            else
                Colors.grey 6

        color2 : Element.Color
        color2 =
            if disabled then
                Colors.grey 6

            else
                Colors.green2

        color3 : Element.Color
        color3 =
            if disabled then
                Colors.grey 6

            else
                Colors.grey 5
    in
    Input.thumb
        [ Ui.wpx <| floor <| scale
        , Ui.hpx <| floor <| scale
        , Ui.r 8
        , Background.color color1
        , Border.shadow
            { offset = ( 0.0, 2.0 )
            , size = 1.0
            , blur = 6.0
            , color = color3
            }
        , Element.focused
            [ Border.shadow
                { offset = ( 0.0, 0.0 )
                , size = 2.0
                , blur = 2.0
                , color = color2
                }
            ]
        , Element.inFront <|
            Element.html <|
                Svg.svg
                    [ Svg.Attributes.width <| String.fromFloat scale ++ "px"
                    , Svg.Attributes.height <| String.fromFloat scale ++ "px"
                    , Svg.Attributes.viewBox "0 0 10 10"
                    , Svg.Attributes.fill "none"
                    ]
                    [ Svg.path
                        [ Svg.Attributes.d "M5,2 L5,8 L5,2 Z"
                        , Svg.Attributes.strokeWidth "2"
                        , Svg.Attributes.strokeLinecap "round"
                        , Svg.Attributes.strokeLinejoin "round"
                        , Svg.Attributes.stroke <| Colors.colorToString color2
                        ]
                        []
                    ]
        ]
