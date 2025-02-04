module Error.Views exposing (view)

{-| This module contains the view of the error page.
-}

import App.Types as App
import Config exposing (Config)
import Data.User exposing (User)
import Element exposing (Element)
import Element.Font as Font
import Error.Types as Error
import Route
import Strings
import Ui.Elements as Ui
import Ui.Utils as Ui


{-| Main view function for the error page.
-}
view : Config -> User -> Error.Model -> ( Element App.Msg, Element App.Msg )
view config user model =
    let
        lang =
            config.clientState.lang

        errorElement =
            case model.reason of
                Error.NotFound ->
                    Element.column [ Ui.s 20 ]
                        [ Element.el [ Font.size 40, Font.bold ] <| Element.text <| Strings.errorNotFoundPageNotFound lang ++ "."
                        , Ui.link []
                            { action = Ui.Route Route.Home
                            , label = Strings.navigationClickHereToGoBackHome lang ++ "."
                            }
                        ]

                Error.ServerError ->
                    Element.column [ Ui.s 20 ]
                        [ Ui.paragraph [ Font.size 40, Font.bold ] <| Strings.errorServerErrorTechnicalDifficulties lang ++ "."
                        , Element.paragraph [] <|
                            [ Ui.link [ Font.bold ]
                                { action = Ui.Msg <| App.ExternalUrl ""
                                , label = Strings.errorServerErrorTryRefreshingByClickingHere lang ++ "."
                                }
                            ]
                        , Element.paragraph []
                            [ Element.text <| Strings.errorServerErrorProblemPersists lang ++ " "
                            , Ui.link [ Font.bold ]
                                { label = "contacter@polymny.studio"
                                , action = Ui.Route <| Route.Custom "mailto:contacter@polymny.studio"
                                }
                            , Element.text "."
                            ]
                        ]

                _ ->
                    Element.none

        content =
            Element.el [ Ui.cx, Ui.p 50 ] errorElement
    in
    ( content, Element.none )
