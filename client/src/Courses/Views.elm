module Courses.Views exposing (..)

import App.Types as App
import Config exposing (Config)
import Courses.Types as Courses
import Data.Capsule as Data exposing (emptyCapsule)
import Data.Group as Data
import Data.Types as Data
import Data.User as Data
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html.Attributes exposing (style)
import Lang exposing (Lang)
import Material.Icons as Icons
import RemoteData
import Route
import Simple.Transition as Transition
import Strings
import Ui.Colors as Colors
import Ui.Elements as Ui
import Ui.Utils as Ui
import Utils


{-| The view function of the courses page.
-}
view : Config -> Data.User -> Courses.Model Data.Group -> ( Element App.Msg, Element App.Msg )
view config user model =
    -- Ugly but we do this for now:
    -- if a user is teaching any course, they're registered as teacher and can create new courses.
    let
        isTeacher =
            -- user.groups
            --     |> List.concatMap .participants
            --     |> List.any (\x -> x.username == user.username && x.role == Data.Teacher)
            user.username == "tforgione"
    in
    if isTeacher then
        teacherView config user model

    else
        studentView config user model


{-| This function returns the teacher view of the new course page.
-}
teacherView : Config -> Data.User -> Courses.Model Data.Group -> ( Element App.Msg, Element App.Msg )
teacherView config user model =
    ( Element.column [ Ui.wf, Ui.p 20, Ui.s 20, Ui.hf ]
        [ Element.row [ Ui.wf, Ui.s 20 ]
            [ Ui.secondary []
                { action = Ui.Msg <| App.CoursesMsg <| Courses.NewGroup Utils.Request ""
                , label = Element.text <| Strings.groupsCreateGroup config.clientState.lang
                }
            , Element.el [ Ui.hf, Background.color <| Colors.alpha 0.1, Ui.wpx 1, Ui.ar ] Element.none
            , Element.el [ Ui.wf, Element.scrollbarX ] <|
                Element.row [ Element.scrollbarX, Ui.s 10 ] <|
                    List.map
                        (\g ->
                            model.selectedGroup
                                |> Maybe.map .id
                                |> Maybe.withDefault -1
                                |> (==) g.id
                                |> groupButton g
                        )
                        user.groups
            ]
        , Element.row
            [ Ui.wf
            , Ui.hf
            , Ui.s 20
            , Element.transparent <| model.selectedGroup == Nothing
            , Element.htmlAttribute <|
                Transition.properties [ Transition.opacity 200 [ Transition.easeInOut ] ]
            ]
          <|
            case model.selectedGroup of
                Just group ->
                    [ Element.el [ Ui.wfp 1, Ui.hf ] <|
                        participantLists config user group model.selectorIndex
                    , Element.el [ Ui.wfp 2, Ui.hf ] <|
                        assignmentManager config user model
                    ]

                Nothing ->
                    [ Element.none ]
        ]
    , popup config user model
    )


{-| This function returns the student view of the new course page.
-}
studentView : Config -> Data.User -> Courses.Model Data.Group -> ( Element App.Msg, Element App.Msg )
studentView config user model =
    let
        -- The current assignments of the student
        assignments : List ( Data.Assignment, Maybe ( Data.Answer, Data.Capsule ) )
        assignments =
            user.groups
                |> List.concatMap .assignments
                |> List.filter (\x -> x.state == Data.Working)
                |> List.map
                    (\x ->
                        ( x
                        , x.answers
                            |> List.filterMap (\y -> Data.getCapsuleById y.capsule user |> Maybe.map (\z -> ( y, z )))
                            |> List.head
                        )
                    )
    in
    ( List.map (assignmentView config user) assignments |> Element.column [ Ui.s 10 ] |> Element.el [ Ui.p 10 ]
    , Element.none
    )


{-| Assignment view.
-}
assignmentView : Config -> Data.User -> ( Data.Assignment, Maybe ( Data.Answer, Data.Capsule ) ) -> Element App.Msg
assignmentView config user ( assignment, answer ) =
    let
        lang : Lang
        lang =
            config.clientState.lang

        subjectCapsule : Data.Capsule
        subjectCapsule =
            Data.getCapsuleById assignment.subject user
                |> Maybe.withDefault emptyCapsule

        subjectFirstSlide : Maybe Data.Slide
        subjectFirstSlide =
            subjectCapsule.structure
                |> List.head
                |> Maybe.map .slides
                |> Maybe.andThen List.head

        subjectFirstSlideElement : Element App.Msg
        subjectFirstSlideElement =
            case subjectFirstSlide of
                Just s ->
                    Element.image [ Ui.hpx 200 ]
                        { src = Data.slidePath subjectCapsule s, description = "" }
                        |> Ui.navigationElement
                            (if answer == Nothing then
                                Ui.Route <| Route.Preparation <| subjectCapsule.id

                             else
                                Ui.NewTab <| Maybe.withDefault "" <| Data.capsuleVideoPath subjectCapsule
                            )
                            [ Element.text (Strings.groupsSubject lang)
                                |> Element.el [ Ui.p 5, Ui.at, Ui.al, Background.color Colors.greyBorder, Ui.rbr 5 ]
                                |> Element.inFront
                            , Ui.b 1
                            , Border.color Colors.greyBorder
                            ]

                _ ->
                    Element.none

        assignmentAnswer : Maybe Data.Answer
        assignmentAnswer =
            Maybe.map Tuple.first answer

        answerFinished : Maybe Bool
        answerFinished =
            Maybe.map .finished assignmentAnswer

        answerCapsule : Data.Capsule
        answerCapsule =
            case answer |> Maybe.map Tuple.second of
                Just c ->
                    c

                Nothing ->
                    Data.getCapsuleById assignment.answerTemplate user |> Maybe.withDefault Data.emptyCapsule

        answerFirstSlide : Maybe Data.Slide
        answerFirstSlide =
            answerCapsule.structure
                |> List.head
                |> Maybe.map .slides
                |> Maybe.andThen List.head

        answerFirstSlideElement : Element App.Msg
        answerFirstSlideElement =
            case answerFirstSlide of
                Just s ->
                    Element.image [ Ui.hpx 200 ]
                        { src = Data.slidePath answerCapsule s, description = "" }
                        |> Ui.navigationElement (Ui.Route <| Route.Preparation <| answerCapsule.id)
                            [ Element.text
                                (Utils.tern (answer == Nothing)
                                    (Strings.groupsTemplate lang)
                                    (Strings.groupsAnswer lang)
                                )
                                |> Element.el [ Ui.p 5, Ui.at, Ui.al, Background.color Colors.greyBorder, Ui.rbr 5 ]
                                |> Element.inFront
                            , Ui.b 1
                            , Border.color Colors.greyBorder
                            ]

                _ ->
                    Element.none

        ( statusLabel, statusColor ) =
            case ( answerFinished, assignment.state ) of
                ( Nothing, Data.Preparation ) ->
                    ( Strings.groupsPreparing lang, Colors.greyFont )

                ( Nothing, Data.Prepared ) ->
                    ( Strings.groupsPrepared lang, Colors.blue )

                ( Nothing, Data.Working ) ->
                    ( Strings.groupsOngoing lang, Colors.blue )

                ( Nothing, Data.Evaluation ) ->
                    ( Strings.groupsReviewing lang, Colors.orange )

                ( Nothing, Data.Finished ) ->
                    ( Strings.groupsFinished lang, Colors.green2 )

                ( Just False, _ ) ->
                    ( Strings.groupsOngoing lang, Colors.blue )

                ( Just True, _ ) ->
                    ( Strings.groupsValidated lang, Colors.green2 )
    in
    Element.row
        [ Ui.wf
        , Ui.s 50
        , Ui.b 1
        , Border.color Colors.greyBorder
        , Ui.r 10
        , Element.paddingEach { left = 50, right = 10, top = 10, bottom = 10 }
        , Background.color Colors.white
        ]
        [ Element.el
            [ Ui.p 10
            , Ui.b 1
            , Ui.r 100
            , Ui.wpx 200
            , Border.color Colors.greyBorder
            , Background.color statusColor
            , Font.color Colors.greyBackground
            ]
            (Element.el [ Ui.cx ] <| Element.text statusLabel)
        , Element.column [ Ui.s 10, Ui.wfp 3 ]
            [ Element.row [ Ui.s 10 ]
                [ Element.text <| Lang.colon Strings.groupsSubject lang
                , Element.text <| "[" ++ subjectCapsule.project ++ "]"
                , Element.text subjectCapsule.name
                ]
            , Element.row [ Ui.s 10 ]
                [ Element.text <| Lang.colon Strings.groupsAnswer lang
                , Element.text <| "[" ++ answerCapsule.project ++ "]"
                , Element.text answerCapsule.name
                ]
            , case ( ( assignmentAnswer, answerFinished ), ( assignment.state, assignment.showDetails ) ) of
                ( ( Nothing, Nothing ), ( Data.Preparation, _ ) ) ->
                    Element.row [ Ui.s 10 ]
                        [ Ui.secondary []
                            { label = Element.text <| Strings.groupsEditAssignment lang
                            , action = Ui.Route <| Route.Assignment assignment.id
                            }
                        , Ui.primary []
                            { label = Element.text <| Strings.groupsValidateAssignment lang
                            , action = Ui.Msg <| App.CoursesMsg <| Courses.ValidateAssignment assignment
                            }
                        ]

                ( ( Nothing, Nothing ), ( Data.Working, False ) ) ->
                    let
                        remaining =
                            assignment.answers
                                |> List.filter (\x -> not x.finished)
                                |> List.filterMap (\x -> Data.getCapsuleById x.capsule user)
                                |> List.filterMap (\x -> List.filter (\y -> y.username /= user.username) x.collaborators |> List.head)
                                |> List.map .username

                        content =
                            if List.isEmpty remaining then
                                Strings.groupsAllStudentsHaveFinished lang

                            else
                                remaining
                                    |> String.join ", "
                                    |> (\x -> Strings.groupsWaitingFor lang ++ " " ++ x)
                    in
                    content
                        |> Element.text
                        |> Ui.navigationElement (Ui.Msg <| App.CoursesMsg <| Courses.ToggleDetails assignment) []

                ( ( Nothing, Nothing ), ( Data.Working, True ) ) ->
                    let
                        mapper : Data.Answer -> Element App.Msg
                        mapper a =
                            Element.row [ Ui.s 10 ]
                                [ Data.getCapsuleById a.capsule user
                                    |> Maybe.map .collaborators
                                    |> Maybe.withDefault []
                                    |> List.filter (\y -> y.username /= user.username)
                                    |> List.head
                                    |> Maybe.map .username
                                    |> Maybe.withDefault ""
                                    |> Element.text
                                    |> Element.el [ Ui.wpx 100 ]
                                , Element.el
                                    [ Ui.p 10
                                    , Ui.b 1
                                    , Ui.r 100
                                    , Ui.wpx 200
                                    , Border.color Colors.greyBorder
                                    , Background.color <| Utils.tern a.finished Colors.green2 Colors.blue
                                    , Font.color Colors.greyBackground
                                    ]
                                    (Element.el [ Ui.cx ] <|
                                        Element.text <|
                                            Utils.tern a.finished
                                                (Strings.groupsFinished lang)
                                                (Strings.groupsOngoing lang)
                                    )
                                , case
                                    ( a.finished
                                    , Data.getCapsuleById a.capsule user
                                        |> Maybe.andThen
                                            (\x ->
                                                Data.capsuleVideoPath x
                                            )
                                    )
                                  of
                                    ( True, Just url ) ->
                                        Ui.link []
                                            { action = Ui.NewTab url
                                            , label = Strings.groupsWatchAnswer lang
                                            }

                                    _ ->
                                        Element.none
                                ]
                    in
                    Element.column [ Ui.pt 20, Ui.s 10 ] (Ui.title (Strings.groupsStudentsAnswers lang) :: List.map mapper assignment.answers)

                ( ( Just a, Just False ), _ ) ->
                    Ui.primary []
                        { label = Element.text <| Strings.groupsValidateAssignment lang
                        , action = Ui.Msg <| App.CoursesMsg <| Courses.ValidateAnswer a
                        }

                _ ->
                    Element.none
            ]
        , subjectFirstSlideElement
        , answerFirstSlideElement
        ]


{-| This function returns the view of the popup.
-}
popup : Config -> Data.User -> Courses.Model Data.Group -> Element App.Msg
popup config user model =
    let
        lang : Lang
        lang =
            config.clientState.lang
    in
    case model.popupType of
        Courses.NoPopup ->
            Element.none

        Courses.NewGroupPopup groupName ->
            Ui.popup (Strings.groupsNewGroup lang) <|
                Element.column [ Ui.wf, Ui.hf, Ui.p 20 ]
                    [ Input.text
                        [ Ui.wf ]
                        { onChange = App.CoursesMsg << Courses.NewGroup Utils.Request
                        , text = groupName
                        , placeholder = Just <| Input.placeholder [] <| Element.text <| Strings.groupsGroupName lang
                        , label = Input.labelAbove [] <| Ui.title <| Strings.groupsGroupName lang
                        }
                    , Element.row [ Ui.wf, Ui.ab ]
                        [ Ui.secondary []
                            { action = Ui.Msg <| App.CoursesMsg <| Courses.NewGroup Utils.Cancel ""
                            , label = Element.text <| Strings.uiCancel config.clientState.lang
                            }
                        , Ui.primary [ Ui.ar ]
                            { action = Ui.Msg <| App.CoursesMsg <| Courses.NewGroup Utils.Confirm groupName
                            , label = Element.text <| Strings.uiConfirm config.clientState.lang
                            }
                        ]
                    ]

        Courses.AddParticipantPopup participantRole participantEmail ->
            let
                title : String
                title =
                    case participantRole of
                        Data.Student ->
                            Strings.groupsNewStudent lang

                        Data.Teacher ->
                            Strings.groupsNewTeacher lang
            in
            Ui.popup title <|
                Element.column [ Ui.wf, Ui.hf, Ui.p 20 ]
                    [ Input.text
                        [ Ui.wf ]
                        { onChange = App.CoursesMsg << Courses.AddParticipant Utils.Request participantRole
                        , text = participantEmail
                        , placeholder = Just <| Input.placeholder [] <| Element.text "email@example.com"
                        , label = Input.labelAbove [] (Ui.title <| Strings.dataUserEmailAddress lang)
                        }
                    , Element.row [ Ui.wf, Ui.ab ]
                        [ Ui.secondary []
                            { action = Ui.Msg <| App.CoursesMsg <| Courses.AddParticipant Utils.Cancel participantRole ""
                            , label = Element.text <| Strings.uiCancel config.clientState.lang
                            }
                        , Ui.primary [ Ui.ar ]
                            { action = Ui.Msg <| App.CoursesMsg <| Courses.AddParticipant Utils.Confirm participantRole participantEmail
                            , label = Element.text <| Strings.uiConfirm config.clientState.lang
                            }
                        ]
                    ]

        Courses.DeleteGroupPopup group ->
            let
                makeQuestion : Lang -> String
                makeQuestion l =
                    Strings.groupsAreYouSureYouWantToDeleteTheGroup l ++ " " ++ group.name
            in
            Ui.popup (Strings.groupsDeleteGroup lang) <|
                Element.column [ Ui.wf, Ui.hf, Ui.p 20 ]
                    [ Element.text <| Lang.question makeQuestion lang
                    , Element.row [ Ui.wf, Ui.ab ]
                        [ Ui.secondary []
                            { action = Ui.Msg <| App.CoursesMsg <| Courses.DeleteGroup Utils.Cancel group
                            , label = Element.text <| Strings.uiCancel config.clientState.lang
                            }
                        , Ui.primary [ Ui.ar ]
                            { action = Ui.Msg <| App.CoursesMsg <| Courses.DeleteGroup Utils.Confirm group
                            , label = Element.text <| Strings.uiConfirm config.clientState.lang
                            }
                        ]
                    ]

        Courses.SelfRemovePopup ->
            Ui.popup (Strings.groupsLeaveGroup lang) <|
                Element.column [ Ui.wf, Ui.hf, Ui.p 20 ]
                    [ Element.text <| Strings.groupsAreYouSureYouWantToLeaveTheGroup lang
                    , Element.row [ Ui.wf, Ui.ab ]
                        [ Ui.secondary []
                            { action = Ui.Msg <| App.CoursesMsg <| Courses.SelfRemove Utils.Cancel
                            , label = Element.text <| Strings.uiCancel config.clientState.lang
                            }
                        , Ui.primary [ Ui.ar ]
                            { action = Ui.Msg <| App.CoursesMsg <| Courses.SelfRemove Utils.Confirm
                            , label = Element.text <| Strings.uiConfirm config.clientState.lang
                            }
                        ]
                    ]

        Courses.LastTeacherPopup ->
            Ui.popup (Strings.groupsLastTeacher lang) <|
                Element.column [ Ui.wf, Ui.hf, Ui.p 20 ]
                    [ Element.text <| Strings.groupsYouAreTheLastTeacherOfTheGroup lang
                    , Element.text <| Strings.groupsYouCannotLeaveTheGroup lang
                    , Element.text <| Strings.groupsAddOtherTeacherOrDelete lang
                    , Element.row [ Ui.wf, Ui.ab ]
                        [ Ui.primary [ Ui.ar ]
                            { action = Ui.Msg <| App.CoursesMsg <| Courses.SelfRemove Utils.Cancel
                            , label = Element.text <| Strings.uiConfirm config.clientState.lang
                            }
                        ]
                    ]

        Courses.SelectCapsulePopup form ->
            user.projects
                |> List.concatMap .capsules
                |> List.map
                    (\x ->
                        Utils.tern (form.capsule == Just x.id) Ui.primary Ui.secondary [] <|
                            { action = Ui.Msg <| App.CoursesMsg <| Courses.CapsuleClicked x.id
                            , label = Element.text <| x.project ++ " / " ++ x.name
                            }
                    )
                |> Element.column [ Ui.wf, Ui.hf, Ui.s 10 ]
                |> (\x ->
                        Element.column [ Ui.wf, Ui.hf, Ui.p 20 ]
                            [ x
                            , Element.row [ Ui.s 10, Ui.ar ]
                                [ Ui.secondary []
                                    { label = Element.text <| Strings.uiCancel lang
                                    , action = Ui.Msg <| App.CoursesMsg <| Courses.ValidateCapsule Utils.Cancel ""
                                    }
                                , Ui.primary []
                                    { label = Element.text <| Strings.uiConfirm lang
                                    , action =
                                        case form.capsule of
                                            Just c ->
                                                Ui.Msg <| App.CoursesMsg <| Courses.ValidateCapsule Utils.Confirm c

                                            _ ->
                                                Ui.None
                                    }
                                ]
                            ]
                   )
                |> Ui.popup (Strings.groupsSelectCapsule lang)


{-| Group button view.
-}
groupButton : Data.Group -> Bool -> Element App.Msg
groupButton group selected =
    let
        action : Ui.Action App.Msg
        action =
            Ui.Route <| Route.Courses <| Just group.id

        label : Element App.Msg
        label =
            Element.text group.name
    in
    if selected then
        Ui.primary [] { action = action, label = label }

    else
        Ui.secondary [] { action = action, label = label }


{-| Participant list view.
-}
participantLists : Config -> Data.User -> Data.Group -> Int -> Element App.Msg
participantLists config user group selectorIndex =
    let
        lang : Lang
        lang =
            config.clientState.lang

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
                    (Ui.navigationElement (Ui.Msg <| App.CoursesMsg <| Courses.RemoveParticipant participant) [] <|
                        Element.el
                            [ Element.mouseOver [ Background.color <| Colors.alpha 0.1 ]
                            , Ui.p 5
                            , Ui.r 30
                            , Font.color Colors.green1
                            , Ui.tooltip <| (Strings.groupsRemove lang ++ participant.username)
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
                , Ui.navigationElement (Ui.Msg <| App.CoursesMsg <| Courses.ChangeSelectorIndex 0)
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
                        Element.text (Strings.groupsStudent lang (List.length students))
                , Ui.navigationElement (Ui.Msg <| App.CoursesMsg <| Courses.ChangeSelectorIndex 1)
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
                        Element.text (Strings.groupsTeacher lang (List.length teachers))
                ]
            , Utils.tern
                isTeacher
                (Ui.navigationElement
                    (Ui.Msg <| App.CoursesMsg <| Courses.DeleteGroup Utils.Request group)
                    [ Ui.ar
                    , Font.color <| Colors.alpha 0.5
                    , Element.mouseOver [ Font.color Colors.greyFont ]
                    , Ui.pr 20
                    , Element.htmlAttribute <|
                        Transition.properties [ Transition.color 200 [ Transition.easeInOut ] ]
                    ]
                    (Element.el [] <| Element.text <| Strings.groupsDeleteGroup lang)
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
                            App.CoursesMsg <|
                                Courses.AddParticipant
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
                            , if selectorIndex == 0 then
                                Element.text <| Strings.groupsAddStudent lang

                              else
                                Element.text <| Strings.groupsAddTeacher lang
                            ]
                    ]
                    []
        ]


{-| The view to create a new course.
-}
assignmentManager : Config -> Data.User -> Courses.Model Data.Group -> Element App.Msg
assignmentManager config user model =
    let
        lang : Lang
        lang =
            config.clientState.lang

        isTeacher : Bool
        isTeacher =
            model.selectedGroup
                |> Maybe.map .participants
                |> Maybe.map (List.any (\p -> p.role == Data.Teacher && p.email == user.email))
                |> Maybe.withDefault False

        inPreparation : List Data.Assignment
        inPreparation =
            model.selectedGroup
                |> Maybe.map .assignments
                |> Maybe.map (List.filter (\a -> a.state == Data.Preparation || a.state == Data.Prepared))
                |> Maybe.withDefault []

        workInProgress : List Data.Assignment
        workInProgress =
            model.selectedGroup
                |> Maybe.map .assignments
                |> Maybe.map (List.filter (\a -> a.state == Data.Working))
                |> Maybe.withDefault []

        finished : List Data.Assignment
        finished =
            model.selectedGroup
                |> Maybe.map .assignments
                |> Maybe.map (List.filter (\a -> a.state == Data.Evaluation || a.state == Data.Finished))
                |> Maybe.withDefault []

        header : String -> Element App.Msg
        header string =
            Element.row [ Ui.wf, Ui.s 10 ]
                [ Element.el [ Ui.wf, Ui.hpx 1, Background.color <| Colors.alpha 0.1, Ui.px 10 ] Element.none
                , Element.text string
                , Element.el [ Ui.wf, Ui.hpx 1, Background.color <| Colors.alpha 0.1, Ui.px 10 ] Element.none
                ]

        inPreparationView : Element App.Msg
        inPreparationView =
            if List.isEmpty inPreparation || not isTeacher then
                Element.none

            else
                List.map (\x -> assignmentView config user ( x, Nothing )) inPreparation
                    -- |> (\x -> header "[In preparation]" :: x)
                    |> Element.column [ Ui.s 30, Ui.wf ]

        workInProgressView : Element App.Msg
        workInProgressView =
            if List.isEmpty workInProgress then
                Element.none

            else
                List.map (\x -> assignmentView config user ( x, Nothing )) workInProgress
                    -- |> (\x -> header "[Work in progress]" :: x)
                    |> Element.column [ Ui.s 30, Ui.wf ]

        finishedView : Element App.Msg
        finishedView =
            -- if List.isEmpty finished then
            --     Element.none
            -- else
            --     (Element.row [ Ui.wf ]
            --         [ Element.el [ Ui.wf, Ui.hpx 1, Background.color <| Colors.alpha 0.1, Ui.p 10 ] Element.none
            --         , Element.text "[Finished]"
            --         , Element.el [ Ui.wf, Ui.hpx 1, Background.color <| Colors.alpha 0.1, Ui.p 10 ] Element.none
            --         ]
            --         :: List.map
            --             assignmentView
            --             finished
            --     )
            --         |> List.intersperse (Element.el [ Ui.wf, Ui.hpx 1, Background.color <| Colors.alpha 0.1, Ui.p 10 ] Element.none)
            --         |> Element.column []
            Element.none

        newAssignmentButton : Element App.Msg
        newAssignmentButton =
            Ui.navigationElement
                (Ui.Msg <| App.CoursesMsg <| Courses.StartNewAssignment)
                [ Font.color Colors.green1 ]
                (Element.text <| "+ " ++ Strings.groupsCreateNewAssignment lang)

        subjectCapsuleSelect : Maybe String -> Element App.Msg
        subjectCapsuleSelect capsuleId =
            Element.column
                [ Ui.s 10 ]
                [ Element.el [ Font.bold ] <| Element.text <| Strings.groupsSelectSubjectCapsule lang
                , Element.row
                    [ Ui.s 10 ]
                    [ Maybe.andThen (\x -> Data.getCapsuleById x user) capsuleId
                        |> Maybe.map (\x -> x.project ++ " / " ++ x.name)
                        |> Maybe.withDefault (Strings.groupsSelectCapsule lang)
                        |> Element.text
                    , Ui.primary [ Ui.s 10 ]
                        { label = Element.text <| Strings.groupsSelect lang
                        , action = Ui.Msg <| App.CoursesMsg <| Courses.SelectCapsule True
                        }
                    ]
                ]

        answerTemplateCapsuleSelect : Maybe String -> Element App.Msg
        answerTemplateCapsuleSelect capsuleId =
            Element.column
                [ Ui.s 10 ]
                [ Element.el [ Font.bold ] <| Element.text <| Strings.groupsSelectTemplateCapsule lang
                , Element.row
                    [ Ui.s 10 ]
                    [ Maybe.andThen (\x -> Data.getCapsuleById x user) capsuleId
                        |> Maybe.map (\x -> x.project ++ " / " ++ x.name)
                        |> Maybe.withDefault (Strings.groupsSelectCapsule lang)
                        |> Element.text
                    , Ui.primary [ Ui.s 10 ]
                        { label = Element.text (Strings.groupsSelect lang)
                        , action = Ui.Msg <| App.CoursesMsg <| Courses.SelectCapsule False
                        }
                    ]
                ]

        criteriaEdition : List String -> Element App.Msg
        criteriaEdition criteria =
            Element.column [ Ui.s 10 ]
                [ Element.el [ Font.bold ] <| Element.text <| Strings.groupsDefineReviewingCriteria lang
                , Element.column [ Ui.s 10 ] <|
                    List.indexedMap
                        (\i x ->
                            Element.row [ Ui.s 10 ]
                                [ Ui.navigationElement (Ui.Msg <| App.CoursesMsg <| Courses.RemoveCriterion i) [] <|
                                    Element.el
                                        [ Element.mouseOver [ Background.color <| Colors.alpha 0.1 ]
                                        , Ui.p 5
                                        , Ui.r 30
                                        , Font.color Colors.green1
                                        , Ui.tooltip <| Strings.groupsRemove lang
                                        , Element.htmlAttribute <|
                                            Transition.properties [ Transition.backgroundColor 200 [ Transition.easeInOut ] ]
                                        ]
                                    <|
                                        Ui.icon 15 Icons.close
                                , Input.text []
                                    { label = Input.labelHidden <| Strings.groupsCriterion lang 1
                                    , onChange = \m -> App.CoursesMsg <| Courses.CriteriaChanged i m
                                    , placeholder = Nothing
                                    , text = x
                                    }
                                ]
                        )
                        criteria
                , Ui.navigationElement (Ui.Msg <| App.CoursesMsg <| Courses.NewCriterion) [] <|
                    Element.row
                        [ Font.color Colors.green1
                        , Ui.s 10
                        , Ui.p 5
                        , Element.mouseOver [ Font.color <| Colors.black ]
                        , Element.htmlAttribute <|
                            Transition.properties [ Transition.color 200 [ Transition.easeInOut ] ]
                        ]
                        [ Element.el [] <| Ui.icon 18 Icons.add
                        , Element.text <| Strings.groupsAddCriterion lang
                        ]
                ]

        createAssignmentButton : Courses.AssignmentForm -> Element App.Msg
        createAssignmentButton f =
            let
                action =
                    case ( f.submitted, f.assignment, f.subject /= Nothing && f.answerTemplate /= Nothing && not (List.any String.isEmpty f.criteria) ) of
                        ( RemoteData.Loading _, _, _ ) ->
                            Ui.None

                        ( _, Nothing, True ) ->
                            Ui.Msg <| App.CoursesMsg <| Courses.CreateAssignment

                        ( _, Just a, True ) ->
                            -- Update assignment a
                            Ui.None

                        _ ->
                            Ui.None
            in
            Ui.primary []
                { action = action
                , label =
                    case ( f.submitted, f.assignment ) of
                        ( RemoteData.Loading _, _ ) ->
                            Ui.spinningSpinner [] 25

                        ( _, Nothing ) ->
                            Element.text <| Strings.groupsCreateAssignment lang

                        ( _, Just _ ) ->
                            Element.text <| Strings.groupsUpdateAssignment lang
                }

        startAssignmentButton : Data.Assignment -> Element App.Msg
        startAssignmentButton a =
            case a.state of
                Data.Preparation ->
                    Ui.primary []
                        { label = Element.text <| Strings.groupsStartAssignment lang
                        , action = Ui.Msg <| App.CoursesMsg <| Courses.ValidateAssignment a
                        }

                _ ->
                    Element.none
    in
    Element.column [ Ui.wf, Ui.s 30 ] <|
        case model.newAssignmentForm of
            Nothing ->
                [ newAssignmentButton
                , inPreparationView
                , workInProgressView
                , finishedView
                ]

            Just f ->
                [ subjectCapsuleSelect f.subject
                , answerTemplateCapsuleSelect f.answerTemplate
                , criteriaEdition f.criteria
                , createAssignmentButton f
                , Maybe.map startAssignmentButton f.assignment |> Maybe.withDefault Element.none
                ]
