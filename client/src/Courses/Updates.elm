module Courses.Updates exposing (..)

import Api.Group as Api
import Api.User as Api
import App.Types as App
import Courses.Types as Courses exposing (PopupType(..))
import Data.Group as Data
import Data.Types as Data
import Data.User as Data
import Keyboard
import RemoteData exposing (RemoteData(..))
import Utils


{-| Updates of the new course page.
-}
update : Courses.Msg -> App.Model -> ( App.Model, Cmd App.Msg )
update msg model =
    let
        { user } =
            model
    in
    case model.page of
        App.Courses m ->
            case msg of
                Courses.NewGroup Utils.Request groupName ->
                    ( { model | page = App.Courses { m | popupType = Courses.NewGroupPopup groupName } }
                    , Cmd.none
                    )

                Courses.NewGroup Utils.Cancel _ ->
                    ( { model | page = App.Courses { m | popupType = NoPopup } }
                    , Cmd.none
                    )

                Courses.NewGroup Utils.Confirm groupName ->
                    let
                        selfParticipant : Data.Participant
                        selfParticipant =
                            { username = model.user.username
                            , email = model.user.email
                            , role = Data.Teacher
                            }

                        newGroup : Data.Group
                        newGroup =
                            { id = -1
                            , name = groupName
                            , participants = [ selfParticipant ]
                            , assignments = []
                            }
                    in
                    ( { model
                        | page =
                            App.Courses
                                { m
                                    | selectedGroup = Just newGroup.id
                                    , popupType = NoPopup
                                }
                        , user = { user | groups = newGroup :: user.groups }
                      }
                    , Api.createGroup groupName (App.CoursesMsg << Courses.Response)
                    )

                Courses.EnterPressed ->
                    case m.popupType of
                        NoPopup ->
                            ( model, Cmd.none )

                        NewGroupPopup groupName ->
                            update (Courses.NewGroup Utils.Confirm groupName) model

                        AddParticipantPopup participantRole participantEmail ->
                            update (Courses.AddParticipant Utils.Confirm participantRole participantEmail) model

                        DeleteGroupPopup group ->
                            update (Courses.DeleteGroup Utils.Confirm group) model

                        Courses.SelfRemovePopup ->
                            update (Courses.SelfRemove Utils.Confirm) model

                        Courses.LastTeacherPopup ->
                            ( { model | page = App.Courses { m | popupType = Courses.NoPopup } }
                            , Cmd.none
                            )

                        Courses.SelectCapsulePopup f ->
                            case f.capsule of
                                Just c ->
                                    update (Courses.ValidateCapsule Utils.Confirm c) model

                                _ ->
                                    ( model, Cmd.none )

                Courses.EscapePressed ->
                    case m.popupType of
                        NoPopup ->
                            ( model, Cmd.none )

                        NewGroupPopup groupName ->
                            update (Courses.NewGroup Utils.Cancel groupName) model

                        AddParticipantPopup participantRole participantEmail ->
                            update (Courses.AddParticipant Utils.Cancel participantRole participantEmail) model

                        DeleteGroupPopup group ->
                            update (Courses.DeleteGroup Utils.Cancel group) model

                        Courses.SelfRemovePopup ->
                            update (Courses.SelfRemove Utils.Cancel) model

                        Courses.LastTeacherPopup ->
                            ( { model | page = App.Courses { m | popupType = Courses.NoPopup } }
                            , Cmd.none
                            )

                        Courses.SelectCapsulePopup _ ->
                            update (Courses.ValidateCapsule Utils.Cancel "") model

                Courses.ChangeSelectorIndex index ->
                    ( { model | page = App.Courses { m | selectorIndex = index } }
                    , Cmd.none
                    )

                Courses.AddParticipant Utils.Request participantRole participantEmail ->
                    ( { model
                        | page =
                            App.Courses
                                { m
                                    | popupType = Courses.AddParticipantPopup participantRole participantEmail
                                }
                      }
                    , Cmd.none
                    )

                Courses.AddParticipant Utils.Cancel _ _ ->
                    ( { model | page = App.Courses { m | popupType = NoPopup } }
                    , Cmd.none
                    )

                Courses.AddParticipant Utils.Confirm participantRole participantEmail ->
                    case Maybe.andThen (\x -> Data.getGroupById x model.user) m.selectedGroup of
                        Just group ->
                            -- TODO all this is unused and it scares me
                            let
                                newParticipant : Data.Participant
                                newParticipant =
                                    { username = ""
                                    , email = participantEmail
                                    , role = participantRole
                                    }

                                participantAlreadyInGroup : Bool
                                participantAlreadyInGroup =
                                    List.any
                                        (\p ->
                                            p.email == participantEmail && p.role == participantRole
                                        )
                                        group.participants

                                newGroup : Data.Group
                                newGroup =
                                    Utils.tern
                                        participantAlreadyInGroup
                                        group
                                        { group | participants = newParticipant :: group.participants }
                            in
                            ( { model | page = App.Courses { m | popupType = NoPopup } }
                            , Api.addParticipant
                                group.id
                                participantEmail
                                participantRole
                                (App.CoursesMsg << Courses.Response)
                            )

                        Nothing ->
                            ( { model | page = App.Courses { m | popupType = NoPopup } }
                            , Cmd.none
                            )

                Courses.RemoveParticipant participant ->
                    if participant.email == model.user.email then
                        update (Courses.SelfRemove Utils.Request) model

                    else
                        case Maybe.andThen (\x -> Data.getGroupById x model.user) m.selectedGroup of
                            Just group ->
                                let
                                    newGroup : Data.Group
                                    newGroup =
                                        { group
                                            | participants =
                                                List.filter (\p -> p.email /= participant.email)
                                                    group.participants
                                        }
                                in
                                ( { model | page = App.Courses { m | selectedGroup = Just newGroup.id } }
                                , Api.removeParticipant
                                    group.id
                                    participant.email
                                    (App.CoursesMsg << Courses.Response)
                                )

                            Nothing ->
                                ( model, Cmd.none )

                Courses.DeleteGroup Utils.Request group ->
                    ( { model | page = App.Courses { m | popupType = Courses.DeleteGroupPopup group } }
                    , Cmd.none
                    )

                Courses.DeleteGroup Utils.Cancel group ->
                    ( { model | page = App.Courses { m | popupType = Courses.NoPopup } }
                    , Cmd.none
                    )

                Courses.DeleteGroup Utils.Confirm group ->
                    case m.selectedGroup of
                        Just selectedGroup ->
                            ( { model
                                | page =
                                    App.Courses
                                        { m
                                            | selectedGroup = Nothing
                                            , popupType = Courses.NoPopup
                                        }
                                , user =
                                    { user
                                        | groups =
                                            List.filter (\g -> g.id /= group.id) model.user.groups
                                    }
                              }
                            , Api.deleteGroup group.id (App.CoursesMsg << Courses.Response)
                            )

                        Nothing ->
                            ( model, Cmd.none )

                Courses.Response (Success group) ->
                    ( { model
                        | user = { user | groups = updateGroup group user.groups }
                        , page = App.Courses { m | selectedGroup = Just group.id }
                      }
                    , Cmd.none
                    )

                Courses.Response _ ->
                    ( model, Cmd.none )

                Courses.SelfRemove Utils.Request ->
                    let
                        isLastTeacher : Bool
                        isLastTeacher =
                            case Maybe.andThen (\x -> Data.getGroupById x model.user) m.selectedGroup of
                                Just selectedGroup ->
                                    selectedGroup.participants
                                        |> List.filter (\p -> p.role == Data.Teacher)
                                        |> List.length
                                        |> (==) 1

                                Nothing ->
                                    False

                        popupType : Courses.PopupType
                        popupType =
                            Utils.tern
                                isLastTeacher
                                Courses.LastTeacherPopup
                                Courses.SelfRemovePopup
                    in
                    ( { model | page = App.Courses { m | popupType = popupType } }
                    , Cmd.none
                    )

                Courses.SelfRemove Utils.Cancel ->
                    ( { model | page = App.Courses { m | popupType = Courses.NoPopup } }
                    , Cmd.none
                    )

                Courses.SelfRemove Utils.Confirm ->
                    case m.selectedGroup of
                        Just selectedGroup ->
                            ( { model
                                | page =
                                    App.Courses
                                        { m
                                            | selectedGroup = Nothing
                                            , popupType = Courses.NoPopup
                                        }
                                , user =
                                    { user
                                        | groups =
                                            List.filter (\g -> g.id /= selectedGroup) model.user.groups
                                    }
                              }
                            , Api.removeParticipant selectedGroup user.email (\_ -> App.Noop)
                            )

                        Nothing ->
                            ( model, Cmd.none )

                Courses.StartNewAssignment ->
                    ( { model | page = App.Courses { m | newAssignmentForm = Just <| Courses.initAssignmentForm Nothing } }, Cmd.none )

                Courses.SelectCapsule b ->
                    ( { model | page = App.Courses { m | popupType = SelectCapsulePopup <| Courses.initSelectCapsuleForm b } }
                    , Cmd.none
                    )

                Courses.CapsuleClicked c ->
                    case m.popupType of
                        Courses.SelectCapsulePopup p ->
                            ( { model | page = App.Courses { m | popupType = Courses.SelectCapsulePopup { p | capsule = Just c } } }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Courses.ValidateCapsule Utils.Request _ ->
                    ( model, Cmd.none )

                Courses.ValidateCapsule Utils.Cancel _ ->
                    ( { model | page = App.Courses { m | popupType = Courses.NoPopup } }, Cmd.none )

                Courses.ValidateCapsule Utils.Confirm c ->
                    case ( m.popupType, m.newAssignmentForm ) of
                        ( Courses.SelectCapsulePopup p, Just form ) ->
                            ( { model
                                | page =
                                    App.Courses
                                        { m
                                            | popupType = Courses.NoPopup
                                            , newAssignmentForm =
                                                if p.isSubject then
                                                    Just { form | subject = Just c }

                                                else
                                                    Just { form | answerTemplate = Just c }
                                        }
                              }
                            , Cmd.none
                            )

                        _ ->
                            ( model, Cmd.none )

                Courses.NewCriterion ->
                    case m.newAssignmentForm of
                        Just f ->
                            ( { model | page = App.Courses { m | newAssignmentForm = Just { f | criteria = f.criteria ++ [ "" ] } } }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Courses.RemoveCriterion index ->
                    case m.newAssignmentForm of
                        Just f ->
                            let
                                newCriteria =
                                    List.take index f.criteria ++ List.drop (index + 1) f.criteria
                            in
                            ( { model | page = App.Courses { m | newAssignmentForm = Just { f | criteria = newCriteria } } }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Courses.CriteriaChanged index content ->
                    case m.newAssignmentForm of
                        Just f ->
                            let
                                newCriteria =
                                    List.take index f.criteria ++ (content :: List.drop (index + 1) f.criteria)
                            in
                            ( { model | page = App.Courses { m | newAssignmentForm = Just { f | criteria = newCriteria } } }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Courses.CreateAssignment ->
                    case m.newAssignmentForm of
                        Just f ->
                            case ( m.selectedGroup, f.subject, f.answerTemplate ) of
                                ( Just group, Just subject, Just answerTemplate ) ->
                                    ( { model | page = App.Courses { m | newAssignmentForm = Just { f | submitted = RemoteData.Loading Nothing } } }
                                    , Api.createAssignment group subject answerTemplate f.criteria (App.CoursesMsg << Courses.CreateAssignmentChanged)
                                    )

                                _ ->
                                    ( model, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Courses.CreateAssignmentChanged (RemoteData.Success a) ->
                    ( { model
                        | user = Data.addAssignment a model.user
                        , page = App.Courses { m | newAssignmentForm = Nothing }
                      }
                    , Cmd.none
                    )

                Courses.CreateAssignmentChanged status ->
                    case m.newAssignmentForm of
                        Just f ->
                            ( { model | page = App.Courses { m | newAssignmentForm = Just { f | submitted = status } } }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Courses.ValidateAssignment assignment ->
                    let
                        newAssignment =
                            { assignment | state = Data.Working }

                        newAssignmentForm =
                            Maybe.map (\x -> { x | assignment = Just newAssignment }) m.newAssignmentForm
                    in
                    ( { model
                        | user = Data.updateAssignment newAssignment model.user
                        , page = App.Courses { m | newAssignmentForm = newAssignmentForm }
                      }
                    , Api.validateAssignment assignment.id (\_ -> App.Noop)
                    )

                Courses.ValidateAnswer answer ->
                    let
                        answerMapper : Data.Answer -> Data.Answer
                        answerMapper a =
                            if answer.id == a.id then
                                { answer | finished = True }

                            else
                                a

                        assignmentMapper : Data.Assignment -> Data.Assignment
                        assignmentMapper a =
                            { a | answers = List.map answerMapper a.answers }

                        groupMapper : Data.Group -> Data.Group
                        groupMapper group =
                            { group | assignments = List.map assignmentMapper group.assignments }
                    in
                    ( { model | user = { user | groups = List.map groupMapper user.groups } }
                    , Api.validateAnswer answer.id (\_ -> App.Noop)
                    )

                Courses.ToggleDetails assignment ->
                    let
                        assignmentMapper : Data.Assignment -> Data.Assignment
                        assignmentMapper a =
                            if a.id == assignment.id then
                                { a | showDetails = not a.showDetails }

                            else
                                a

                        groupMapper : Data.Group -> Data.Group
                        groupMapper group =
                            { group | assignments = List.map assignmentMapper group.assignments }
                    in
                    ( { model | user = { user | groups = List.map groupMapper user.groups } }
                    , Cmd.none
                    )

        _ ->
            ( model, Cmd.none )


{-| Update a group in the model.
-}
updateGroup : Data.Group -> List Data.Group -> List Data.Group
updateGroup group groups =
    List.map
        (\g ->
            Utils.tern
                (g.id == group.id || (g.id == -1 && g.name == group.name))
                group
                g
        )
        groups


{-| Keyboard shortcuts of the new course page.
-}
shortcuts : Keyboard.RawKey -> App.Msg
shortcuts msg =
    case Keyboard.rawValue msg of
        "Escape" ->
            App.CoursesMsg Courses.EscapePressed

        "Enter" ->
            App.CoursesMsg Courses.EnterPressed

        _ ->
            App.Noop


{-| Subscriptions of the page.
-}
subs : Sub App.Msg
subs =
    Sub.batch
        [ Keyboard.ups shortcuts ]
