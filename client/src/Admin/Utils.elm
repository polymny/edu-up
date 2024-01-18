module Admin.Utils exposing (..)

{-| This module contains utils functions that cannot be written in Types.elm because of circular dependencies.
-}

import Admin.Types as Admin
import Api.Admin as Api
import App.Types as App
import RemoteData
import Route


{-| The initial model for administration.
-}
fromRoute : Route.AdminRoute -> ( Admin.Model, Cmd App.Msg )
fromRoute route =
    case route of
        Route.Users i ->
            ( Admin.Users i [] Admin.emptyUserSearchForm
            , Api.listUsers i
                ((\x -> x |> RemoteData.map (App.AdminMsg << Admin.UsersArrived i) |> RemoteData.withDefault App.Noop) |> App.orError)
            )

        Route.Capsules i ->
            ( Admin.Capsules i [] Admin.emptyCapsuleSearchForm
            , Api.listCapsules i
                ((\x -> x |> RemoteData.map (App.AdminMsg << Admin.CapsulesArrived i) |> RemoteData.withDefault App.Noop) |> App.orError)
            )

        Route.UserDetails id ->
            ( Admin.Users 0 [] Admin.emptyUserSearchForm
            , Api.getUser id
                ((\x -> x |> RemoteData.map (App.AdminMsg << Admin.UserArrived id) |> RemoteData.withDefault App.Noop) |> App.orError)
            )
