module Publication.Updates exposing (..)

{-| This module contains the updates for the publication view.
-}

import Api.Capsule as Api
import App.Types as App
import App.Utils as App
import Config
import Data.Capsule as Data exposing (Capsule)
import Data.Types as Data
import Data.User as Data
import Publication.Types as Publication
import Utils


update : Publication.Msg -> App.Model -> ( App.Model, Cmd App.Msg )
update msg model =
    let
        ( maybeCapsule, _ ) =
            App.capsuleAndGos model.user model.page
    in
    case ( model.page, maybeCapsule ) of
        ( App.Publication m, Just capsule ) ->
            case msg of
                Publication.TogglePrivacyPopup ->
                    let
                        newPopupType : Publication.PopupType
                        newPopupType =
                            Utils.tern
                                (m.popupType == Publication.PrivacyPopup)
                                Publication.NoPopup
                                Publication.PrivacyPopup
                    in
                    ( { model | page = App.Publication { m | popupType = newPopupType } }
                    , Cmd.none
                    )

                Publication.ToggleIntegrationPopup ->
                    let
                        newPopupType : Publication.PopupType
                        newPopupType =
                            Utils.tern
                                (m.popupType == Publication.IntegrationPopup)
                                Publication.NoPopup
                                Publication.IntegrationPopup
                    in
                    ( { model | page = App.Publication { m | popupType = newPopupType } }
                    , Cmd.none
                    )

                Publication.SetPrivacy privacy ->
                    updateModel { capsule | privacy = privacy } model m

                Publication.SetPromptSubtitles promptSubtitles ->
                    updateModel { capsule | promptSubtitles = promptSubtitles } model m

                Publication.PublishVideo ->
                    let
                        taskId : Config.TaskId
                        taskId =
                            model.config.clientState.taskId

                        task : Config.TaskStatus
                        task =
                            { task = Config.Publication taskId m.capsule
                            , progress = Nothing
                            , finished = False
                            , aborted = False
                            , global = True
                            }

                        newConfig : Config.Config
                        newConfig =
                            Tuple.first <| Config.update (Config.UpdateTaskStatus task) model.config
                    in
                    ( { model
                        | user = Data.updateUser { capsule | published = Data.Running Nothing } model.user
                        , config = Config.incrementTaskId newConfig
                      }
                    , Api.publishCapsule capsule ((\_ -> App.Noop) |> App.orError)
                    )

                Publication.UnpublishVideo ->
                    ( { model | user = Data.updateUser { capsule | published = Data.Idle } model.user }
                    , Api.unpublishCapsule capsule ((\_ -> App.Noop) |> App.orError)
                    )

        _ ->
            ( model, Cmd.none )


{-| Changes the current gos in the model.
-}
updateModel : Capsule -> App.Model -> Publication.Model String -> ( App.Model, Cmd App.Msg )
updateModel newCapsule model _ =
    let
        newUser =
            Data.updateUser newCapsule model.user
    in
    ( { model | user = newUser }
    , Api.updateCapsule newCapsule ((\_ -> App.Noop) |> App.orError)
    )
