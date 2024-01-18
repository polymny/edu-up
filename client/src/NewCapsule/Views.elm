module NewCapsule.Views exposing (view)

{-| This module contains the new caspule page view.

@docs view

-}

import App.Types as App
import Config exposing (Config)
import Data.Capsule as Data
import Data.User as Data exposing (User)
import Element exposing (Element)
import Element.Border as Border
import Element.Input as Input
import Html
import Html.Attributes
import NewCapsule.Types as NewCapsule
import RemoteData
import Strings
import Ui.Colors as Colors
import Ui.Elements as Ui
import Ui.Utils as Ui
import Utils


{-| The view function for the new capsule page.
-}
view : Config -> User -> NewCapsule.Model -> ( Element App.Msg, Element App.Msg )
view config _ model =
    let
        projectInput =
            Input.text []
                { label = Input.labelAbove [] (Ui.title (Strings.dataProjectProjectName config.clientState.lang))
                , text = model.projectName
                , placeholder = Nothing
                , onChange = \x -> App.NewCapsuleMsg (NewCapsule.ProjectChanged x)
                }
                |> Utils.tern model.showProject Element.none

        nameInput =
            Input.text []
                { label = Input.labelAbove [] (Ui.title (Strings.dataCapsuleCapsuleName config.clientState.lang))
                , text = model.capsuleName
                , placeholder = Nothing
                , onChange = \x -> App.NewCapsuleMsg (NewCapsule.NameChanged x)
                }

        bottomBar =
            case ( model.capsuleUpdate, model.renderFinished ) of
                ( RemoteData.NotAsked, True ) ->
                    Element.row [ Ui.wf, Element.spacing 10 ]
                        [ Ui.secondary []
                            { action = Ui.Msg <| App.NewCapsuleMsg <| NewCapsule.Cancel
                            , label = Element.text <| Strings.uiCancel config.clientState.lang
                            }
                        , Ui.secondary [ Element.alignRight ]
                            { action = Ui.Msg <| App.NewCapsuleMsg <| NewCapsule.Submit <| NewCapsule.Preparation
                            , label = Element.text <| Strings.stepsPreparationOrganizeSlides config.clientState.lang
                            }
                        , Ui.primary [ Element.alignRight ]
                            { action = Ui.Msg <| App.NewCapsuleMsg <| NewCapsule.Submit <| NewCapsule.Acquisition
                            , label = Element.text <| Strings.stepsAcquisitionStartRecording config.clientState.lang
                            }
                        ]

                _ ->
                    Ui.animatedEl Ui.spin [ Ui.cx ] (Ui.icon 60 Ui.spinner)
    in
    ( Element.row [ Ui.wf, Ui.hf, Ui.p 10 ]
        [ Element.el [ Ui.wfp 1 ] Element.none
        , Element.column [ Ui.wfp 6, Element.spacing 10, Element.alignTop ]
            [ projectInput, nameInput, slidesView model.structure, bottomBar ]
        , Element.el [ Ui.wfp 1 ] Element.none
        ]
    , Element.none
    )


{-| Shows the slides with the delimiters.
-}
slidesView : List Int -> Element App.Msg
slidesView structure =
    makeView structure
        |> Utils.regroupFixed 10
        |> List.map
            (List.indexedMap
                (\i x ->
                    case ( x, modBy 2 i == 0 ) of
                        ( Just e, _ ) ->
                            e

                        ( _, True ) ->
                            Element.el [ Ui.wf ] Element.none

                        ( _, False ) ->
                            Element.el [ Ui.p 10 ] Element.none
                )
            )
        |> List.map (Element.row [ Ui.wf ])
        |> Element.column [ Element.spacing 10, Ui.wf, Ui.hf, Ui.id "pdf-viewer" ]


makeView : List Int -> List (Element App.Msg)
makeView input =
    makeViewAux [] (List.indexedMap Tuple.pair input) |> List.reverse


makeViewAux : List (Element App.Msg) -> List ( Int, Int ) -> List (Element App.Msg)
makeViewAux acc structure =
    case structure of
        ( i1, h1 ) :: ( i2, h2 ) :: t ->
            makeViewAux (delimiterView i1 h1 h2 :: slideView :: acc) (( i2, h2 ) :: t)

        _ :: [] ->
            slideView :: acc

        [] ->
            acc


{-| Shows a slide of the capsule.
-}
slideView : Element App.Msg
slideView =
    Element.el [ Ui.wf ] <|
        Element.html <|
            Html.canvas
                [ Html.Attributes.class "wf"
                , Html.Attributes.class "hf"
                ]
                []


{-| Show a vertical delimiter between two slides.

If the slides belong to the same grain, the delimiter will be dashed, otherwise, it will be solid.

-}
delimiterView : Int -> Int -> Int -> Element App.Msg
delimiterView index1 grain1 grain2 =
    let
        border =
            if grain1 == grain2 then
                Border.dashed

            else
                Border.solid
    in
    Input.button [ Ui.px 10, Ui.hf ]
        { label = Element.el [ border, Ui.cx, Ui.hf, Ui.bl 2, Border.color Colors.black ] Element.none
        , onPress = Just (App.NewCapsuleMsg (NewCapsule.DelimiterClicked (grain1 == grain2) index1))
        }
