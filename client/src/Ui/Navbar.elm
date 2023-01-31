module Ui.Navbar exposing (navbar, bottombar, leftColumn, addLeftColumn, addLeftAndRightColumn)

{-| This module contains the definition for the nav bar of the polymny app.

@docs navbar, bottombar, leftColumn, addLeftColumn, addLeftAndRightColumn

-}

import App.Types as App
import Config exposing (Config)
import Data.Capsule as Data exposing (Capsule)
import Data.User exposing (User)
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Lang exposing (Lang)
import Material.Icons
import Route exposing (Route)
import Strings
import Ui.Colors as Colors
import Ui.Elements as Ui
import Ui.Graphics as Ui
import Ui.Utils as Ui


{-| This function creates the navbar of the application.
-}
navbar : Maybe Config -> Maybe App.Page -> Maybe User -> Element App.Msg
navbar config page user =
    let
        lang =
            Maybe.map .clientState config |> Maybe.map .lang |> Maybe.withDefault Lang.default

        capsule =
            Maybe.andThen App.getCapsule page
    in
    Element.row
        [ Background.color Colors.green2, Ui.wf ]
        [ Ui.navigationElement (Ui.Route Route.Home) [ Ui.pl 10, Ui.pr 30 ] Ui.logo
        , case ( capsule, page ) of
            ( Just c, Just p ) ->
                navButtons lang c p

            _ ->
                Element.none
        , case user of
            Just u ->
                Element.row [ Font.size 20, Ui.ar, Ui.s 10, Ui.pr 5 ]
                    [ Element.text u.username
                    , Ui.secondary []
                        { action = Ui.Msg App.Logout
                        , label = Strings.loginLogout lang
                        }
                    ]

            _ ->
                Element.none
        ]


{-| This function creates a row with the navigation buttons of the different tabs of a capsule.
-}
navButtons : Lang -> Capsule -> App.Page -> Element msg
navButtons lang capsule page =
    let
        makeButton : Route -> (Lang -> String) -> Element msg
        makeButton route label =
            let
                attr =
                    if Route.compareTab route (Route.fromPage page) then
                        [ Background.color Colors.greyBackground ]

                    else
                        []
            in
            Ui.navigationElement (Ui.Route route) (Ui.hf :: Ui.p 12 :: Font.bold :: attr) (Element.el [ Element.centerY ] (Element.text (label lang)))
    in
    Element.row [ Ui.s 10, Ui.hf ]
        [ makeButton (Route.Preparation capsule.id) Strings.stepsPreparationPrepare
        , makeButton (Route.Acquisition capsule.id 0) Strings.stepsAcquisitionRecord
        , makeButton (Route.Production capsule.id 0) Strings.stepsProductionProduce
        , makeButton (Route.Publication capsule.id) Strings.stepsPublicationPublish
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
                                    , icon = Material.Icons.theaters
                                    , tooltip = ""
                                    }

                            _ ->
                                Element.none
                        , Ui.primaryIcon []
                            { action = Ui.Route (Route.Acquisition capsule.id id)
                            , icon = Material.Icons.videocam
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
