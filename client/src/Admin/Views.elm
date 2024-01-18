module Admin.Views exposing (..)

{-| This module contains the views of the administration pages.
-}

import Admin.Types as Admin
import App.Types as App
import Config exposing (Config)
import Data.Capsule as Data exposing (Capsule)
import Data.Types as Data
import Data.User as Data exposing (User)
import Element exposing (Element)
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Home.Types as Home
import Home.Views as Home
import Route
import Strings
import TimeUtils
import Ui.Colors as Colors
import Ui.Elements as Ui
import Ui.Utils as Ui
import Utils


{-| View function of the administration page.
-}
view : Config -> User -> Admin.Model -> ( Element App.Msg, Element App.Msg )
view config user model =
    let
        ( content, popup ) =
            case model of
                Admin.Users page users form ->
                    ( usersView config page users form, Element.none )

                Admin.Capsules page capsules form ->
                    ( capsulesView config page capsules form, Element.none )

                Admin.UserDetails _ (Just ( u, m )) ->
                    userView config u.inner m

                _ ->
                    ( Element.none, Element.none )
    in
    ( Element.el [ Ui.p 10, Ui.wf, Ui.hf ] content, popup )


{-| View for a single user.
-}
userView : Config -> User -> Home.Model -> ( Element App.Msg, Element App.Msg )
userView config user model =
    let
        ( content, popup ) =
            Home.view (\x -> App.AdminMsg <| Admin.Toggle x) config user model
    in
    ( Element.column [ Ui.s 10, Ui.wf, Ui.hf ]
        [ Element.el [ Ui.cx, Font.size 30, Font.bold, Ui.p 10 ] <| Element.text <| "Projets de \"" ++ user.username ++ "\""
        , content
        ]
    , popup
    )


{-| View for list of users.
-}
usersView : Config -> Int -> List Admin.User -> Admin.UserSearchForm -> Element App.Msg
usersView config page users form =
    let
        lang =
            config.clientState.lang

        header : String -> Element App.Msg
        header content =
            Element.el [ Ui.p 10, Font.bold, Ui.bb 1, Ui.hf, Border.color Colors.greyBorder ] <| Element.text content

        cellElement : Element App.Msg -> Element App.Msg
        cellElement element =
            Element.el [ Ui.p 10, Ui.bb 1, Ui.hf, Border.color Colors.greyBorder ] <| element

        cell : String -> Element App.Msg
        cell content =
            cellElement <| Element.text content

        cellLink : Ui.Action App.Msg -> String -> Element App.Msg
        cellLink action content =
            Ui.navigationElement action [ Ui.p 10, Ui.bb 1, Ui.hf, Border.color Colors.greyBorder ] <| Element.text content

        table : Element App.Msg
        table =
            Element.table [ Border.widthEach { left = 1, top = 1, bottom = 0, right = 1 }, Border.color Colors.greyBorder ]
                { data = users
                , columns =
                    [ { header = header "ID"
                      , width = Element.fill
                      , view = \u -> cell <| String.fromInt u.id
                      }
                    , { header = header <| Strings.uiProfileUsername lang
                      , width = Element.fill
                      , view = \u -> cellLink (Ui.Route <| Route.Admin <| Route.UserDetails u.id) u.inner.username
                      }
                    , { header = header <| Strings.uiProfileEmail lang
                      , width = Element.fill
                      , view = \u -> cell u.inner.email
                      }
                    , { header = header <| Strings.dataUserPlan lang
                      , width = Element.fill
                      , view =
                            \u ->
                                cell <|
                                    case u.inner.plan of
                                        Data.Free ->
                                            "Free"

                                        Data.PremiumLvl1 ->
                                            "Premium Lvl 1"

                                        Data.Admin ->
                                            "Admin"
                      }
                    , { header = header <| "Active"
                      , width = Element.fill
                      , view =
                            \u ->
                                cellElement <|
                                    Input.checkbox []
                                        { onChange = \_ -> App.Noop
                                        , checked = u.activated
                                        , label = Input.labelHidden "activated"
                                        , icon = Ui.checkbox False
                                        }
                      }
                    , { header = header <| Strings.adminRegistrationDate lang
                      , width = Element.fill
                      , view = \u -> cell <| Maybe.withDefault "" <| Maybe.map (TimeUtils.formatTime lang config.clientState.zone) <| u.memberSince
                      }
                    , { header = header <| Strings.adminLastVisit lang
                      , width = Element.fill
                      , view = \u -> cell <| Maybe.withDefault "" <| Maybe.map (TimeUtils.formatTime lang config.clientState.zone) <| u.lastVisited
                      }
                    , { header = header <| Strings.dataCapsuleCapsule lang 2
                      , width = Element.fill
                      , view = \u -> cell <| String.fromInt <| List.length <| List.concatMap .capsules u.inner.projects
                      }
                    , { header = header <| Strings.loginDiskUsage lang ++ " (MiB)"
                      , width = Element.fill
                      , view = \u -> cell <| String.fromInt <| List.sum <| List.map .diskUsage <| List.concatMap .capsules u.inner.projects
                      }
                    ]
                }

        searchForm : Element App.Msg
        searchForm =
            Element.row [ Ui.cx, Ui.s 10 ]
                [ Ui.title "Rechercher un utilisateur"
                , Input.text []
                    { onChange = \x -> App.AdminMsg <| Admin.UsernameChanged x
                    , text = form.username
                    , placeholder = Just (Input.placeholder [] (Element.text "Username"))
                    , label = Input.labelHidden "username"
                    }
                , Input.text []
                    { onChange = \x -> App.AdminMsg <| Admin.EmailChanged x
                    , text = form.email
                    , placeholder = Just (Input.placeholder [] (Element.text "E-mail"))
                    , label = Input.labelHidden "email"
                    }
                , Ui.primary []
                    { label = Element.text "Valider"
                    , action = Ui.Msg <| App.AdminMsg <| Admin.SearchUsers
                    }
                ]
    in
    Element.column [ Ui.s 50, Ui.wf ]
        [ searchForm
        , Element.row [ Ui.cx, Ui.s 10 ]
            [ Ui.link [] { action = Utils.tern (page > 0) (Ui.Route <| Route.Admin <| Route.Users <| page - 1) Ui.None, label = "Précédente" }
            , Ui.title <| "Page " ++ String.fromInt page
            , Ui.link [] { action = Ui.Route <| Route.Admin <| Route.Users <| page + 1, label = "Suivante" }
            ]
        , table
        ]


{-| View for list of capsules.
-}
capsulesView : Config -> Int -> List Capsule -> Admin.CapsuleSearchForm -> Element App.Msg
capsulesView config page capsules form =
    let
        lang =
            config.clientState.lang

        header : String -> Element App.Msg
        header content =
            Element.el [ Ui.p 10, Font.bold, Ui.bb 1, Ui.hf, Border.color Colors.greyBorder ] <| Element.text content

        cellElement : Element App.Msg -> Element App.Msg
        cellElement element =
            Element.el [ Ui.p 10, Ui.bb 1, Ui.hf, Border.color Colors.greyBorder ] <| element

        cell : String -> Element App.Msg
        cell content =
            cellElement <| Element.text content

        cellLink : Ui.Action App.Msg -> String -> Element App.Msg
        cellLink action content =
            Ui.navigationElement action [ Ui.p 10, Ui.bb 1, Ui.hf, Border.color Colors.greyBorder ] <| Element.text content

        table : Element App.Msg
        table =
            Element.table [ Border.widthEach { left = 1, top = 1, bottom = 0, right = 1 }, Border.color Colors.greyBorder ]
                { data = capsules
                , columns =
                    [ { header = header "ID"
                      , width = Element.fill
                      , view = \c -> cell c.id
                      }
                    , { header = header <| Strings.dataCapsuleProject lang 1
                      , width = Element.fill
                      , view = \c -> cellLink (Ui.Route <| Route.Preparation c.id) c.project
                      }
                    , { header = header <| Strings.dataCapsuleCapsuleName lang
                      , width = Element.fill
                      , view = \c -> cellLink (Ui.Route <| Route.Preparation c.id) c.name
                      }
                    , { header = header <| Strings.dataCapsuleRoleOwner lang
                      , width = Element.fill
                      , view =
                            \c ->
                                c.collaborators
                                    |> List.filter (\x -> x.role == Data.Owner)
                                    |> List.head
                                    |> Maybe.map .username
                                    |> Maybe.withDefault ""
                                    |> cell
                      }
                    , { header = header <| Strings.dataCapsuleLastModification lang
                      , width = Element.fill
                      , view = \c -> cell <| TimeUtils.formatTime lang config.clientState.zone c.lastModified
                      }
                    , { header = header <| Strings.dataCapsuleProgress lang
                      , width = Element.fill
                      , view = \c -> cellElement <| Element.row [ Ui.wf, Ui.s 10 ] [ Home.capsuleProgress lang c, Home.progressIcons config c ]
                      }
                    ]
                }

        searchForm : Element App.Msg
        searchForm =
            Element.row [ Ui.cx, Ui.s 10 ]
                [ Ui.title "Rechercher un utilisateur"
                , Input.text []
                    { onChange = \x -> App.AdminMsg <| Admin.CapsuleNameChanged x
                    , text = form.name
                    , placeholder = Just (Input.placeholder [] (Element.text "Capsule name"))
                    , label = Input.labelHidden "capsule name"
                    }
                , Input.text []
                    { onChange = \x -> App.AdminMsg <| Admin.ProjectChanged x
                    , text = form.project
                    , placeholder = Just (Input.placeholder [] (Element.text "E-mail"))
                    , label = Input.labelHidden "project"
                    }
                , Ui.primary []
                    { label = Element.text "Valider"
                    , action = Ui.Msg <| App.AdminMsg <| Admin.SearchCapsules
                    }
                ]
    in
    Element.column [ Ui.s 50, Ui.wf ]
        [ searchForm
        , Element.row [ Ui.cx, Ui.s 10 ]
            [ Ui.link [] { action = Utils.tern (page > 0) (Ui.Route <| Route.Admin <| Route.Capsules <| page - 1) Ui.None, label = "Précédente" }
            , Ui.title <| "Page " ++ String.fromInt page
            , Ui.link [] { action = Ui.Route <| Route.Admin <| Route.Capsules <| page + 1, label = "Suivante" }
            ]
        , table
        ]
