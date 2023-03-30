module NewCourse.Updates exposing (..)

import Api.User as Api
import App.Types as App
import Data.Types as Data
import Data.User as Data
import Keyboard
import NewCourse.Types as NewCourse exposing (PopupType(..))
import NewCourse.Views exposing (popup)
import RemoteData exposing (RemoteData(..))
import Utils


{-| Updates of the new course page.
-}
update : NewCourse.Msg -> App.Model -> ( App.Model, Cmd App.Msg )
update msg model =
    case model.page of
        App.NewCourse m ->
            case msg of
                NewCourse.NoOp ->
                    ( model, Cmd.none )

                NewCourse.SelectGroup group ->
                    ( { model | page = App.NewCourse { m | selectedGroup = Just group } }
                    , Cmd.none
                    )

                NewCourse.NewGroup Utils.Request groupName ->
                    ( { model | page = App.NewCourse { m | popupType = NewCourse.NewGroupPopup groupName } }
                    , Cmd.none
                    )

                NewCourse.NewGroup Utils.Cancel groupName ->
                    ( { model | page = App.NewCourse { m | popupType = NoPopup } }
                    , Cmd.none
                    )

                NewCourse.NewGroup Utils.Confirm groupName ->
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
                            }

                        user : Data.User
                        user =
                            model.user
                    in
                    ( { model
                        | page =
                            App.NewCourse
                                { m
                                    | selectedGroup = Just newGroup
                                    , popupType = NoPopup
                                }
                        , user = { user | groups = newGroup :: user.groups }
                      }
                    , Api.createGroup groupName (App.NewCourseMsg << NewCourse.Response)
                    )

                NewCourse.EnterPressed ->
                    case m.popupType of
                        NoPopup ->
                            ( model, Cmd.none )

                        NewGroupPopup groupName ->
                            update (NewCourse.NewGroup Utils.Confirm groupName) model

                        AddParticipantPopup participantRole participantEmail ->
                            update (NewCourse.AddParticipant Utils.Confirm participantRole participantEmail) model

                        DeleteGroupPopup group ->
                            update (NewCourse.DeleteGroup Utils.Confirm group) model

                        NewCourse.SelfRemovePopup ->
                            update (NewCourse.SelfRemove Utils.Confirm) model

                        NewCourse.LastTeacherPopup ->
                            ( { model | page = App.NewCourse { m | popupType = NewCourse.NoPopup } }
                            , Cmd.none
                            )

                NewCourse.EscapePressed ->
                    case m.popupType of
                        NoPopup ->
                            ( model, Cmd.none )

                        NewGroupPopup groupName ->
                            update (NewCourse.NewGroup Utils.Cancel groupName) model

                        AddParticipantPopup participantRole participantEmail ->
                            update (NewCourse.AddParticipant Utils.Cancel participantRole participantEmail) model

                        DeleteGroupPopup group ->
                            update (NewCourse.DeleteGroup Utils.Cancel group) model

                        NewCourse.SelfRemovePopup ->
                            update (NewCourse.SelfRemove Utils.Cancel) model

                        NewCourse.LastTeacherPopup ->
                            ( { model | page = App.NewCourse { m | popupType = NewCourse.NoPopup } }
                            , Cmd.none
                            )

                NewCourse.ChangeSelectorIndex index ->
                    ( { model | page = App.NewCourse { m | selectorIndex = index } }
                    , Cmd.none
                    )

                NewCourse.AddParticipant Utils.Request participantRole participantEmail ->
                    ( { model
                        | page =
                            App.NewCourse
                                { m
                                    | popupType = NewCourse.AddParticipantPopup participantRole participantEmail
                                }
                      }
                    , Cmd.none
                    )

                NewCourse.AddParticipant Utils.Cancel participantEmail participantRole ->
                    ( { model | page = App.NewCourse { m | popupType = NoPopup } }
                    , Cmd.none
                    )

                NewCourse.AddParticipant Utils.Confirm participantRole participantEmail ->
                    case m.selectedGroup of
                        Just group ->
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
                            ( { model | page = App.NewCourse { m | popupType = NoPopup } }
                            , Api.addParticipant
                                group.id
                                participantEmail
                                participantRole
                                (App.NewCourseMsg << NewCourse.Response)
                            )

                        Nothing ->
                            ( { model | page = App.NewCourse { m | popupType = NoPopup } }
                            , Cmd.none
                            )

                NewCourse.RemoveParticipant participant ->
                    if participant.email == model.user.email then
                        update (NewCourse.SelfRemove Utils.Request) model

                    else
                        case m.selectedGroup of
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
                                ( { model | page = App.NewCourse { m | selectedGroup = Just newGroup } }
                                , Api.removeParticipant
                                    group.id
                                    participant.email
                                    (App.NewCourseMsg << NewCourse.Response)
                                )

                            Nothing ->
                                ( model, Cmd.none )

                NewCourse.DeleteGroup Utils.Request group ->
                    ( { model | page = App.NewCourse { m | popupType = NewCourse.DeleteGroupPopup group } }
                    , Cmd.none
                    )

                NewCourse.DeleteGroup Utils.Cancel group ->
                    ( { model | page = App.NewCourse { m | popupType = NewCourse.NoPopup } }
                    , Cmd.none
                    )

                NewCourse.DeleteGroup Utils.Confirm group ->
                    let
                        user : Data.User
                        user =
                            model.user
                    in
                    case m.selectedGroup of
                        Just selectedGroup ->
                            ( { model
                                | page =
                                    App.NewCourse
                                        { m
                                            | selectedGroup = Nothing
                                            , popupType = NewCourse.NoPopup
                                        }
                                , user =
                                    { user
                                        | groups =
                                            List.filter (\g -> g.id /= group.id) model.user.groups
                                    }
                              }
                            , Api.deleteGroup group.id (App.NewCourseMsg << NewCourse.Response)
                            )

                        Nothing ->
                            ( model, Cmd.none )

                NewCourse.Response (Success group) ->
                    let
                        user : Data.User
                        user =
                            model.user
                    in
                    ( { model
                        | user = { user | groups = updateGroup group user.groups }
                        , page = App.NewCourse { m | selectedGroup = Just group }
                      }
                    , Cmd.none
                    )

                NewCourse.Response _ ->
                    ( model, Cmd.none )

                NewCourse.SelfRemove Utils.Request ->
                    let
                        isLastTeacher : Bool
                        isLastTeacher =
                            case m.selectedGroup of
                                Just selectedGroup ->
                                    selectedGroup.participants
                                        |> List.filter (\p -> p.role == Data.Teacher)
                                        |> List.length
                                        |> (==) 1

                                Nothing ->
                                    False

                        popupType : NewCourse.PopupType
                        popupType =
                            Utils.tern
                                isLastTeacher
                                NewCourse.LastTeacherPopup
                                NewCourse.SelfRemovePopup
                    in
                    ( { model | page = App.NewCourse { m | popupType = popupType } }
                    , Cmd.none
                    )

                NewCourse.SelfRemove Utils.Cancel ->
                    ( { model | page = App.NewCourse { m | popupType = NewCourse.NoPopup } }
                    , Cmd.none
                    )

                NewCourse.SelfRemove Utils.Confirm ->
                    let
                        user : Data.User
                        user =
                            model.user
                    in
                    case m.selectedGroup of
                        Just selectedGroup ->
                            ( { model
                                | page =
                                    App.NewCourse
                                        { m
                                            | selectedGroup = Nothing
                                            , popupType = NewCourse.NoPopup
                                        }
                                , user =
                                    { user
                                        | groups =
                                            List.filter (\g -> g.id /= selectedGroup.id) model.user.groups
                                    }
                              }
                            , Api.removeParticipant selectedGroup.id user.email (\_ -> App.Noop)
                            )

                        Nothing ->
                            ( model, Cmd.none )

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
            App.NewCourseMsg NewCourse.EscapePressed

        "Enter" ->
            App.NewCourseMsg NewCourse.EnterPressed

        _ ->
            App.Noop


{-| Subscriptions of the page.
-}
subs : Sub App.Msg
subs =
    Sub.batch
        [ Keyboard.ups shortcuts ]
