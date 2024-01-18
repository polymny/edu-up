module NewCapsule.Updates exposing
    ( update
    , subs
    )

{-| This module contains the update function for the new capsule page.

@docs update

-}

import Api.Capsule as Api
import Api.User as Api
import App.Types as App
import Data.Capsule as Data
import Data.User as Data
import Home.Types as Home
import Keyboard
import NewCapsule.Types as NewCapsule
import Ports
import Preparation.Types as Preparation
import RemoteData
import Route


{-| The update function of the new capsule page.
-}
update : NewCapsule.Msg -> App.Model -> ( App.Model, Cmd App.Msg )
update msg model =
    case ( model.page, msg ) of
        ( App.NewCapsule m, NewCapsule.NameChanged newName ) ->
            ( mkModel { m | capsuleName = newName } model, Cmd.none )

        ( App.NewCapsule m, NewCapsule.ProjectChanged newName ) ->
            ( mkModel { m | projectName = newName } model, Cmd.none )

        ( App.NewCapsule m, NewCapsule.DelimiterClicked b i ) ->
            ( mkModel { m | structure = NewCapsule.toggle b i m.structure } model, Cmd.none )

        ( App.NewCapsule m, NewCapsule.Submit nextPage ) ->
            let
                changeSlide =
                    Preparation.NewCapsule m.projectName m.capsuleName

                indices =
                    List.repeat m.numPages ()
                        |> List.indexedMap (\i _ -> i + 1)
            in
            ( mkModel { m | nextPage = nextPage, capsuleUpdate = RemoteData.Loading Nothing } model
            , Ports.sendPdf changeSlide m.pdfFile indices Data.emptyCapsule
            )

        ( App.NewCapsule _, NewCapsule.Cancel ) ->
            ( { model | page = App.Home Home.init }, Cmd.none )

        ( App.NewCapsule m, NewCapsule.PdfSent (RemoteData.Success capsule) ) ->
            let
                capsuleSlides : List Data.Slide
                capsuleSlides =
                    List.concatMap .slides capsule.structure

                newCapsule : Data.Capsule
                newCapsule =
                    { capsule | structure = NewCapsule.structureFromUi m.structure capsuleSlides }
            in
            ( { model | user = Data.addCapsule newCapsule model.user }
            , Api.updateCapsule newCapsule (\_ -> App.NewCapsuleMsg <| NewCapsule.Finished newCapsule)
            )

        ( App.NewCapsule m, NewCapsule.Finished c ) ->
            ( model
            , case m.nextPage of
                NewCapsule.Preparation ->
                    Route.push model.config.clientState.key (Route.Preparation c.id)

                NewCapsule.Acquisition ->
                    Route.push model.config.clientState.key (Route.Acquisition c.id 0)
            )

        ( App.NewCapsule m, NewCapsule.RenderFinished ) ->
            ( mkModel { m | renderFinished = True } model, Cmd.none )

        _ ->
            ( model, Cmd.none )


{-| A utility function to easily change the page of the model.
-}
mkModel : NewCapsule.Model -> App.Model -> App.Model
mkModel m model =
    { model | page = App.NewCapsule m }


{-| Keyboard shortcuts of the home page.
-}
shortcuts : Keyboard.RawKey -> App.Msg
shortcuts msg =
    case Keyboard.rawValue msg of
        "Escape" ->
            App.NewCapsuleMsg NewCapsule.Cancel

        "Enter" ->
            App.NewCapsuleMsg <| NewCapsule.Submit NewCapsule.Preparation

        _ ->
            App.Noop


{-| Subscriptions of the page.
-}
subs : Sub App.Msg
subs =
    Sub.batch
        [ Keyboard.ups shortcuts
        , Sub.map (Maybe.withDefault App.Noop) <|
            Ports.pdfSent (\x -> App.NewCapsuleMsg <| NewCapsule.PdfSent <| RemoteData.Success x)
        , Ports.renderFinished (App.NewCapsuleMsg <| NewCapsule.RenderFinished)
        ]
