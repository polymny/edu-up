module NewCourse.Views exposing (..)

import App.Types as App
import Config exposing (Config)
import Data.Types as Data
import Data.User as Data
import Element exposing (Element)
import Element.Input as Input
import Material.Icons as Icons
import NewCourse.Types as NewCourse
import Strings
import Ui.Elements as Ui
import Ui.Utils as Ui
import Utils


{-| This function returns the view of the new course page.
-}
view : Config -> Data.User -> NewCourse.Model -> ( Element App.Msg, Element App.Msg )
view config user model =
    ( Element.column []
        [ Element.row [ Ui.s 10, Ui.p 10 ] <|
            List.map (\g -> groupButton g (Just g == model.selectedGroup)) user.groups
                ++ [ Ui.secondary []
                        { action = Ui.Msg <| App.NewCourseMsg <| NewCourse.NewGroup Utils.Request ""
                        , label = Ui.icon 18 Icons.add
                        }
                   ]
        , participantList model.selectedGroup
        ]
    , popup config user model
    )


{-| This function returns the view of the popup.
-}
popup : Config -> Data.User -> NewCourse.Model -> Element App.Msg
popup config user model =
    case model.popupType of
        NewCourse.NoPopup ->
            Element.none

        NewCourse.NewGroupPopup groupName ->
            Ui.popup 1 "[Nouveau groupe]" <|
                Element.column [ Ui.wf, Ui.hf ]
                    [ Input.text
                        [ Ui.wf ]
                        { onChange = App.NewCourseMsg << NewCourse.NewGroup Utils.Request
                        , text = groupName
                        , placeholder = Just <| Input.placeholder [] <| Element.text "[Nom du groupe : e.g. 'Terminal 2']"
                        , label = Input.labelAbove [] (Ui.title "[Nom du groupe]")
                        }
                    , Element.row [ Ui.wf, Ui.ab ]
                        [ Ui.secondary []
                            { action = Ui.Msg <| App.NewCourseMsg <| NewCourse.NewGroup Utils.Cancel ""
                            , label = Element.text <| Strings.uiCancel config.clientState.lang
                            }
                        , Ui.primary [ Ui.ar ]
                            { action = Ui.Msg <| App.NewCourseMsg <| NewCourse.NewGroup Utils.Confirm groupName
                            , label = Element.text <| Strings.uiConfirm config.clientState.lang
                            }
                        ]
                    ]


{-| Group button view.
-}
groupButton : Data.Group -> Bool -> Element App.Msg
groupButton group selected =
    let
        action : Ui.Action App.Msg
        action =
            Ui.Msg <| App.NewCourseMsg <| NewCourse.SelectGroup group

        label : Element App.Msg
        label =
            Element.text group.name
    in
    if selected then
        Ui.primary [ Ui.wf ] { action = action, label = label }

    else
        Ui.secondary [ Ui.wf ] { action = action, label = label }


{-| Participant list view.
-}
participantList : Maybe Data.Group -> Element App.Msg
participantList group =
    let
        students : List Data.Participant
        students =
            case group of
                Just g ->
                    g.participants
                        |> List.filter (\p -> p.role == Data.Student)

                Nothing ->
                    []

        teachers : List Data.Participant
        teachers =
            case group of
                Just g ->
                    g.participants
                        |> List.filter (\p -> p.role == Data.Teacher)

                Nothing ->
                    []

        participantView : Data.Participant -> Element App.Msg
        participantView participant =
            Element.text <| participant.username ++ " (" ++ participant.email ++ ")"
    in
    Element.column [ Ui.s 10, Ui.p 10, Ui.at ] <|
        case group of
            Just g ->
                [ Element.text (g.name ++ ":")
                , Element.row [ Ui.s 10, Ui.p 10, Ui.at ] <|
                    [ if not (List.isEmpty students) then
                        Element.column [ Ui.s 10, Ui.p 10, Ui.at ]
                            [ Element.text "Students:"
                            , Element.column [ Ui.s 10, Ui.p 10, Ui.at ] <|
                                List.map participantView students
                            ]

                      else
                        Element.none
                    , if not (List.isEmpty teachers) then
                        Element.column [ Ui.s 10, Ui.p 10, Ui.at ]
                            [ Element.text "Teachers:"
                            , Element.column [ Ui.s 10, Ui.p 10, Ui.at ] <|
                                List.map participantView teachers
                            ]

                      else
                        Element.none
                    ]
                ]

            Nothing ->
                [ Element.text "No group selected" ]
