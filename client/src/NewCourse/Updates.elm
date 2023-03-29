module NewCourse.Updates exposing (..)

import App.Types as App
import Data.Types as Data
import Data.User as Data
import Keyboard
import NewCourse.Types as NewCourse exposing (PopupType(..))
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
                    , -- TODO: create group in backend
                      Cmd.none
                    )

                NewCourse.EnterPressed ->
                    case m.popupType of
                        NoPopup ->
                            ( model, Cmd.none )

                        NewGroupPopup groupName ->
                            update (NewCourse.NewGroup Utils.Confirm groupName) model

                        AddParticipantPopup participantRole participantEmail ->
                            update (NewCourse.AddParticipant Utils.Confirm participantRole participantEmail) model

                NewCourse.EscapePressed ->
                    case m.popupType of
                        NoPopup ->
                            ( model, Cmd.none )

                        NewGroupPopup groupName ->
                            update (NewCourse.NewGroup Utils.Cancel groupName) model

                        AddParticipantPopup participantRole participantEmail ->
                            update (NewCourse.AddParticipant Utils.Cancel participantRole participantEmail) model

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

                                newGroup : Data.Group
                                newGroup =
                                    { group | participants = newParticipant :: group.participants }
                            in
                            ( { model
                                | page =
                                    App.NewCourse
                                        { m
                                            | selectedGroup = Just newGroup
                                            , popupType = NoPopup
                                        }
                              }
                            , -- TODO: add participant in backend
                              Cmd.none
                            )

                        Nothing ->
                            ( {model | page = App.NewCourse { m | popupType = NoPopup } }
                            , Cmd.none
                            )

        _ ->
            ( model, Cmd.none )


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
