module NewCourse.Views exposing (..)

import App.Types as App
import Config exposing (Config)
import Data.Types as Data
import Data.User as Data
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html.Attributes exposing (style)
import Material.Icons as Icons
import NewCourse.Types as NewCourse
import Simple.Transition as Transition
import Strings
import Ui.Colors as Colors
import Ui.Elements as Ui
import Ui.Utils as Ui
import Utils


{-| This function returns the view of the new course page.
-}
view : Config -> Data.User -> NewCourse.Model -> ( Element App.Msg, Element App.Msg )
view config user model =
    ( Element.column [ Ui.wf, Ui.p 20, Ui.s 20, Ui.hf ]
        [ Element.row [ Ui.s 10 ] <|
            List.map
                (\g ->
                    model.selectedGroup
                        |> Maybe.map .id
                        |> Maybe.withDefault -1
                        |> (==) g.id
                        |> groupButton g
                )
                user.groups
                ++ [ Ui.secondary []
                        { action = Ui.Msg <| App.NewCourseMsg <| NewCourse.NewGroup Utils.Request ""
                        , label = Ui.icon 18 Icons.add
                        }
                   ]
        , Element.row [ Ui.wf, Ui.hf ]
            [ Element.el
                [ Ui.wfp 1
                , Ui.hf
                , Element.transparent <| model.selectedGroup == Nothing
                , Element.htmlAttribute <|
                    Transition.properties [ Transition.opacity 200 [ Transition.easeInOut ] ]
                ]
              <|
                case model.selectedGroup of
                    Just group ->
                        participantLists user group model.selectorIndex

                    Nothing ->
                        Element.none
            , Element.el [ Ui.wfp 1, Ui.hf ] Element.none
            ]
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
                Element.column [ Ui.wf, Ui.hf, Ui.p 20 ]
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

        NewCourse.AddParticipantPopup participantRole participantEmail ->
            let
                title : String
                title =
                    case participantRole of
                        Data.Student ->
                            "[Nouvel élève]"

                        Data.Teacher ->
                            "[Nouveau professeur]"
            in
            Ui.popup 1 title <|
                Element.column [ Ui.wf, Ui.hf, Ui.p 20 ]
                    [ Input.text
                        [ Ui.wf ]
                        { onChange = App.NewCourseMsg << NewCourse.AddParticipant Utils.Request participantRole
                        , text = participantEmail
                        , placeholder = Just <| Input.placeholder [] <| Element.text "[exemple@exemple.ex]"
                        , label = Input.labelAbove [] (Ui.title "[Adresse email]")
                        }
                    , Element.row [ Ui.wf, Ui.ab ]
                        [ Ui.secondary []
                            { action = Ui.Msg <| App.NewCourseMsg <| NewCourse.AddParticipant Utils.Cancel participantRole ""
                            , label = Element.text <| Strings.uiCancel config.clientState.lang
                            }
                        , Ui.primary [ Ui.ar ]
                            { action = Ui.Msg <| App.NewCourseMsg <| NewCourse.AddParticipant Utils.Confirm participantRole participantEmail
                            , label = Element.text <| Strings.uiConfirm config.clientState.lang
                            }
                        ]
                    ]

        NewCourse.DeleteGroupPopup group ->
            Ui.popup 1 "[Supprimer le groupe]" <|
                Element.column [ Ui.wf, Ui.hf, Ui.p 20 ]
                    [ Element.text <| "[Êtes-vous sûr de vouloir supprimer le groupe " ++ group.name ++ " ?]"
                    , Element.row [ Ui.wf, Ui.ab ]
                        [ Ui.secondary []
                            { action = Ui.Msg <| App.NewCourseMsg <| NewCourse.DeleteGroup Utils.Cancel group
                            , label = Element.text <| Strings.uiCancel config.clientState.lang
                            }
                        , Ui.primary [ Ui.ar ]
                            { action = Ui.Msg <| App.NewCourseMsg <| NewCourse.DeleteGroup Utils.Confirm group
                            , label = Element.text <| Strings.uiConfirm config.clientState.lang
                            }
                        ]
                    ]

        NewCourse.SelfRemovePopup ->
            Ui.popup 1 "[Quitter le groupe]" <|
                Element.column [ Ui.wf, Ui.hf, Ui.p 20 ]
                    [ Element.text <| "[Êtes-vous sûr de vouloir quitter le groupe ?]"
                    , Element.row [ Ui.wf, Ui.ab ]
                        [ Ui.secondary []
                            { action = Ui.Msg <| App.NewCourseMsg <| NewCourse.SelfRemove Utils.Cancel
                            , label = Element.text <| Strings.uiCancel config.clientState.lang
                            }
                        , Ui.primary [ Ui.ar ]
                            { action = Ui.Msg <| App.NewCourseMsg <| NewCourse.SelfRemove Utils.Confirm
                            , label = Element.text <| Strings.uiConfirm config.clientState.lang
                            }
                        ]
                    ]

        NewCourse.LastTeacherPopup ->
            Ui.popup 1 "[Dernier enseignant]" <|
                Element.column [ Ui.wf, Ui.hf, Ui.p 20 ]
                    [ Element.text <| "[Vous êtes le dernier professeur du groupe.]"
                    , Element.text <| "[Vous ne pouvez pas quitter le groupe.]"
                    , Element.text <| "[ - Veuillez ajouter un autre professeur avant de quitter le groupe.]"
                    , Element.text <| "[Ou]"
                    , Element.text <| "[ - Supprimer le groupe.]"
                    , Element.row [ Ui.wf, Ui.ab ]
                        [ Ui.primary [ Ui.ar ]
                            { action = Ui.Msg <| App.NewCourseMsg <| NewCourse.SelfRemove Utils.Cancel
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
participantLists : Data.User -> Data.Group -> Int -> Element App.Msg
participantLists user group selectorIndex =
    let
        buttonWidth : Int
        buttonWidth =
            150

        roundRadius : Int
        roundRadius =
            10

        isTeacher : Bool
        isTeacher =
            group.participants
                |> List.any (\p -> p.role == Data.Teacher && p.email == user.email)

        students : List Data.Participant
        students =
            group.participants
                |> List.filter (\p -> p.role == Data.Student)

        teachers : List Data.Participant
        teachers =
            group.participants
                |> List.filter (\p -> p.role == Data.Teacher)

        selectorMove : Float
        selectorMove =
            toFloat <| selectorIndex * buttonWidth - roundRadius

        selector : Element msg
        selector =
            Element.row
                [ Element.htmlAttribute <| Html.Attributes.style "position" "absolute"
                , Element.htmlAttribute <| Html.Attributes.style "height" "100%"
                , Ui.zIndex 1
                , Element.moveRight selectorMove
                , Ui.wpx (buttonWidth + 2 * roundRadius)
                , Ui.hf
                , Element.htmlAttribute <|
                    Transition.properties [ Transition.transform 200 [ Transition.easeInOut ] ]
                ]
                [ Element.el
                    [ Ui.hf
                    , Ui.wpx roundRadius
                    , Background.color Colors.greyBackground
                    ]
                  <|
                    Element.el
                        [ Ui.hf
                        , Ui.wpx roundRadius
                        , Ui.rbr roundRadius
                        , Background.color Colors.green2
                        , Border.innerShadow
                            { offset = ( 0.0, -11.0 )
                            , size = -10.0
                            , blur = 10.0
                            , color = Colors.alpha 0.3
                            }
                        ]
                        Element.none
                , Element.el
                    [ Ui.hf
                    , Ui.wf
                    , Ui.rt roundRadius
                    , Background.color Colors.greyBackground
                    ]
                    Element.none
                , Element.el
                    [ Ui.hf
                    , Ui.wpx 10
                    , Background.color Colors.greyBackground
                    ]
                  <|
                    Element.el
                        [ Ui.hf
                        , Ui.wpx 10
                        , Ui.rbl roundRadius
                        , Background.color Colors.green2
                        , Border.innerShadow
                            { offset = ( 0.0, -11.0 )
                            , size = -10.0
                            , blur = 10.0
                            , color = Colors.alpha 0.3
                            }
                        ]
                        Element.none
                ]

        participantView : Data.Participant -> Element App.Msg
        participantView participant =
            Element.row [ Ui.s 10 ]
                [ Utils.tern
                    isTeacher
                    (Ui.navigationElement (Ui.Msg <| App.NewCourseMsg <| NewCourse.RemoveParticipant participant) [] <|
                        Element.el
                            [ Element.mouseOver [ Background.color <| Colors.alpha 0.1 ]
                            , Ui.p 5
                            , Ui.r 30
                            , Font.color Colors.green1
                            , Ui.tooltip <| "[Enlever " ++ participant.username ++ "]"
                            , Element.htmlAttribute <|
                                Transition.properties [ Transition.backgroundColor 200 [ Transition.easeInOut ] ]
                            ]
                        <|
                            Ui.icon 15 Icons.close
                    )
                    Element.none
                , Element.text participant.username
                , Element.text <| "(" ++ participant.email ++ ")"
                ]
    in
    Element.column
        [ Ui.p 20
        , Ui.at
        , Ui.wf
        , Ui.hf
        , Background.color Colors.green2
        , Border.shadow
            { offset = ( 0.0, 0.0 )
            , size = 1
            , blur = 10
            , color = Colors.alpha 0.3
            }
        , Ui.r 10
        ]
        [ Element.row [ Ui.pl (2 * roundRadius), Ui.wf ]
            [ Element.row []
                [ selector
                , Ui.navigationElement (Ui.Msg <| App.NewCourseMsg <| NewCourse.ChangeSelectorIndex 0)
                    [ Ui.wpx buttonWidth
                    , Ui.hf
                    , Ui.py 20
                    , Element.mouseOver
                        [ Background.color <|
                            Colors.alpha <|
                                Utils.tern (selectorIndex == 0) 0.0 0.1
                        ]
                    , Element.htmlAttribute <|
                        Transition.properties [ Transition.backgroundColor 200 [ Transition.easeInOut ] ]
                    , Ui.zIndex 1
                    , Ui.r roundRadius
                    ]
                  <|
                    Element.el
                        [ Ui.cy
                        , Ui.cx
                        , Font.bold
                        ]
                    <|
                        Element.text "[Students:]"
                , Ui.navigationElement (Ui.Msg <| App.NewCourseMsg <| NewCourse.ChangeSelectorIndex 1)
                    [ Ui.wpx buttonWidth
                    , Ui.hf
                    , Ui.py 20
                    , Element.mouseOver
                        [ Background.color <|
                            Colors.alpha <|
                                Utils.tern (selectorIndex == 1) 0.0 0.1
                        ]
                    , Element.htmlAttribute <|
                        Transition.properties [ Transition.backgroundColor 200 [ Transition.easeInOut ] ]
                    , Ui.zIndex 1
                    , Ui.r roundRadius
                    ]
                  <|
                    Element.el
                        [ Ui.cy
                        , Ui.cx
                        , Font.bold
                        ]
                    <|
                        Element.text "[Teachers:]"
                ]
            , Utils.tern
                isTeacher
                (Ui.navigationElement
                    (Ui.Msg <| App.NewCourseMsg <| NewCourse.DeleteGroup Utils.Request group)
                    [ Ui.ar
                    , Font.color <| Colors.alpha 0.5
                    , Element.mouseOver [ Font.color Colors.greyFont ]
                    , Ui.pr 20
                    , Element.htmlAttribute <|
                        Transition.properties [ Transition.color 200 [ Transition.easeInOut ] ]
                    ]
                    (Element.el [] <| Element.text "[Delete group]")
                )
                Element.none
            ]
        , Element.column
            [ Ui.s 20
            , Ui.p 20
            , Ui.at
            , Ui.wf
            , Ui.hf
            , Background.color Colors.greyBackground
            , Ui.r roundRadius
            , Border.shadow
                { offset = ( 0.0, 0.0 )
                , size = 1
                , blur = 10
                , color = Colors.alpha 0.3
                }
            ]
          <|
            (Utils.tern (selectorIndex == 0) students teachers
                |> List.map participantView
                |> List.intersperse
                    (Element.el
                        [ Ui.hpx 1
                        , Ui.wf
                        , Ui.px 10
                        , Background.color <| Colors.alpha 0.1
                        ]
                        Element.none
                    )
            )
                ++ Utils.tern
                    isTeacher
                    [ Ui.navigationElement
                        (Ui.Msg <|
                            App.NewCourseMsg <|
                                NewCourse.AddParticipant
                                    Utils.Request
                                    (Utils.tern (selectorIndex == 0) Data.Student Data.Teacher)
                                    ""
                        )
                        []
                      <|
                        Element.row
                            [ Font.color Colors.green1
                            , Ui.s 10
                            , Ui.p 5
                            , Element.mouseOver [ Font.color <| Colors.black ]
                            , Element.htmlAttribute <|
                                Transition.properties [ Transition.color 200 [ Transition.easeInOut ] ]
                            ]
                            [ Element.el [] <|
                                Ui.icon
                                    18
                                    Icons.add
                            , Element.text <| "[Ajouter un " ++ Utils.tern (selectorIndex == 0) "étudiant" "professeur" ++ "]"
                            ]
                    ]
                    []
        ]
