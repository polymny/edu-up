module NewProject.Updates exposing (..)

import Api
import Core.Types as Core
import NewProject.Types as NewProject
import Status
import Utils exposing (resultToMsg)


update : Api.Session -> NewProject.Msg -> NewProject.Model -> ( Api.Session, NewProject.Model, Cmd Core.Msg )
update session msg model =
    case msg of
        NewProject.NameChanged newName ->
            ( session, { model | name = newName }, Cmd.none )

        NewProject.Submitted ->
            ( session, { model | status = Status.Sent }, Api.newProject resultToMsg model )

        NewProject.Success project ->
            ( { session | projects = project :: session.projects }
            , { model | status = Status.Success () }
            , Cmd.none
            )


resultToMsg : Result e Api.Project -> Core.Msg
resultToMsg result =
    Utils.resultToMsg (\x -> Core.LoggedInMsg <| Core.NewProjectMsg <| NewProject.Success <| x) (\_ -> Core.Noop) result
