module Admin.Updates exposing (..)

{-| This module contains the update function for the admin page.
-}

import Admin.Types as Admin
import Api.Admin as Api
import App.Types as App
import Data.User as Data
import Home.Types as Home
import Keyboard
import RemoteData


{-| Update function for the admin page.
-}
update : Admin.Msg -> App.Model -> ( App.Model, Cmd App.Msg )
update msg model =
    case model.page of
        App.Admin m ->
            case ( m, msg ) of
                ( Admin.UserDetails i (Just ( user, m2 )), Admin.Toggle project ) ->
                    let
                        toggled =
                            { user | inner = Data.toggleProject project user.inner }
                    in
                    ( { model | page = App.Admin <| Admin.UserDetails i (Just ( toggled, m2 )) }, Cmd.none )

                ( _, Admin.UsersArrived i users ) ->
                    let
                        form =
                            Admin.getUserSearchForm m |> Maybe.withDefault Admin.emptyUserSearchForm
                    in
                    ( { model | page = App.Admin <| Admin.Users i users form }, Cmd.none )

                ( _, Admin.CapsulesArrived i capsules ) ->
                    let
                        form =
                            Admin.getCapsuleSearchForm m |> Maybe.withDefault Admin.emptyCapsuleSearchForm
                    in
                    ( { model | page = App.Admin <| Admin.Capsules i capsules form }, Cmd.none )

                ( _, Admin.UserArrived i user ) ->
                    ( { model | page = App.Admin <| Admin.UserDetails i (Just ( user, Home.init )) }, Cmd.none )

                ( Admin.Users i users form, Admin.UsernameChanged x ) ->
                    ( { model | page = App.Admin <| Admin.Users i users { form | username = x } }, Cmd.none )

                ( Admin.Users i users form, Admin.EmailChanged x ) ->
                    ( { model | page = App.Admin <| Admin.Users i users { form | email = x } }, Cmd.none )

                ( Admin.Users i _ form, Admin.SearchUsers ) ->
                    ( model
                    , Api.searchUsers form.username
                        form.email
                        ((\x -> x |> RemoteData.map (App.AdminMsg << Admin.UsersArrived i) |> RemoteData.withDefault App.Noop) |> App.orError)
                    )

                ( Admin.Capsules i capsules form, Admin.CapsuleNameChanged x ) ->
                    ( { model | page = App.Admin <| Admin.Capsules i capsules { form | name = x } }, Cmd.none )

                ( Admin.Capsules i capsules form, Admin.ProjectChanged x ) ->
                    ( { model | page = App.Admin <| Admin.Capsules i capsules { form | project = x } }, Cmd.none )

                ( Admin.Capsules i _ form, Admin.SearchCapsules ) ->
                    ( model
                    , Api.searchCapsules form.name
                        form.project
                        ((\x -> x |> RemoteData.map (App.AdminMsg << Admin.CapsulesArrived i) |> RemoteData.withDefault App.Noop) |> App.orError)
                    )

                _ ->
                    ( model, Cmd.none )

        _ ->
            ( model, Cmd.none )


{-| Keyboard shortcuts of the options page.
-}
shortcuts : Admin.Model -> Keyboard.RawKey -> App.Msg
shortcuts model msg =
    case ( model, Keyboard.rawValue msg ) of
        ( Admin.Users _ _ _, "Enter" ) ->
            App.AdminMsg Admin.SearchUsers

        ( Admin.Capsules _ _ _, "Enter" ) ->
            App.AdminMsg Admin.SearchCapsules

        _ ->
            App.Noop


{-| Subscriptions of the page.
-}
subs : Admin.Model -> Sub App.Msg
subs a =
    Keyboard.ups <| shortcuts a
