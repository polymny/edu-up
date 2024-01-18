port module Preparation.Updates exposing (update, subs)

{-| This module contains the update function for the preparation page.

@docs update, subs

-}

import Api.Capsule as Api
import App.Types as App
import App.Utils as App
import Config exposing (Config)
import Data.Capsule as Data
import Data.User as Data exposing (User)
import Dict exposing (Dict)
import File exposing (File)
import FileValue
import Json.Decode as Decode
import Json.Encode as Encode
import Keyboard
import List.Extra
import Ports
import Preparation.Types as Preparation
import RemoteData
import Utils


{-| The update function of the preparation page.
-}
update : Preparation.Msg -> App.Model -> ( App.Model, Cmd App.Msg )
update msg model =
    let
        ( maybeCapsule, _ ) =
            App.capsuleAndGos model.user model.page
    in
    case ( model.page, maybeCapsule ) of
        ( App.Preparation m, Just capsule ) ->
            case msg of
                Preparation.DnD sMsg ->
                    updateDnD model.user sMsg m model.config
                        |> Tuple.mapFirst (\( x, y ) -> { model | page = App.Preparation x, config = y })

                Preparation.CapsuleUpdate id data ->
                    if model.config.clientState.lastRequest == id + 1 then
                        ( { model | page = App.Preparation { m | capsuleUpdate = data } }, Cmd.none )

                    else
                        ( model, Cmd.none )

                Preparation.DeleteSlide Utils.Request slide ->
                    ( { model
                        | page =
                            App.Preparation
                                { m
                                    | popupType = Preparation.DeleteSlidePopup slide
                                    , displayPopup = True
                                }
                      }
                    , Cmd.none
                    )

                Preparation.DeleteSlide Utils.Cancel _ ->
                    ( { model | page = App.Preparation { m | displayPopup = False } }, Cmd.none )

                Preparation.DeleteSlide Utils.Confirm slide ->
                    let
                        newCapsule =
                            Data.deleteSlide slide capsule

                        ( sync, newConfig ) =
                            ( Api.updateCapsule newCapsule
                                ((\x -> App.PreparationMsg (Preparation.CapsuleUpdate model.config.clientState.lastRequest x))
                                    |> App.orError
                                )
                            , Config.incrementRequest model.config
                            )
                    in
                    ( { model
                        | user = Data.updateUser newCapsule model.user
                        , page = App.Preparation (Preparation.init newCapsule)
                        , config = newConfig
                      }
                    , sync
                    )

                Preparation.DeleteExtra Utils.Request slide ->
                    ( { model
                        | page =
                            App.Preparation
                                { m
                                    | popupType = Preparation.DeleteExtraPopup slide
                                    , displayPopup = True
                                }
                      }
                    , Cmd.none
                    )

                Preparation.DeleteExtra Utils.Cancel _ ->
                    ( { model | page = App.Preparation { m | displayPopup = False } }, Cmd.none )

                Preparation.DeleteExtra Utils.Confirm slide ->
                    let
                        newCapsule =
                            Data.deleteExtra slide capsule

                        ( sync, newConfig ) =
                            ( Api.updateCapsule newCapsule
                                ((\x -> App.PreparationMsg (Preparation.CapsuleUpdate model.config.clientState.lastRequest x))
                                    |> App.orError
                                )
                            , Config.incrementRequest model.config
                            )
                    in
                    ( { model
                        | user = Data.updateUser newCapsule model.user
                        , page = App.Preparation (Preparation.init newCapsule)
                        , config = newConfig
                      }
                    , sync
                    )

                Preparation.Resource sMsg ->
                    let
                        ( newM, cmd, newConfig ) =
                            updateExtra model.user sMsg m model.config
                    in
                    ( { model | page = App.Preparation newM, config = newConfig }, cmd )

                Preparation.EditPrompt slide ->
                    ( { model
                        | page =
                            App.Preparation
                                { m
                                    | popupType = Preparation.EditPromptPopup slide
                                    , displayPopup = True
                                }
                      }
                    , Cmd.none
                    )

                Preparation.PromptChanged Utils.Request slide ->
                    ( { model
                        | page =
                            App.Preparation
                                { m
                                    | popupType = Preparation.EditPromptPopup slide
                                    , displayPopup = True
                                }
                      }
                    , Cmd.none
                    )

                Preparation.PromptChanged Utils.Cancel _ ->
                    ( { model | page = App.Preparation { m | displayPopup = False } }, Cmd.none )

                Preparation.PromptChanged Utils.Confirm slide ->
                    let
                        newCapsule =
                            Data.updateSlide { slide | prompt = fixPrompt slide.prompt } capsule

                        sync =
                            Api.updateCapsule newCapsule
                                ((\x -> App.PreparationMsg (Preparation.CapsuleUpdate model.config.clientState.lastRequest x))
                                    |> App.orError
                                )
                    in
                    ( { model
                        | user = Data.updateUser newCapsule model.user
                        , page = App.Preparation (Preparation.init newCapsule)
                        , config = Config.incrementRequest model.config
                      }
                    , sync
                    )

                Preparation.GoToPreviousSlide currentSlideIndex currentSlide ->
                    let
                        newCapsule =
                            Data.updateSlide { currentSlide | prompt = fixPrompt currentSlide.prompt } capsule

                        sync =
                            Api.updateCapsule newCapsule
                                ((\x -> App.PreparationMsg (Preparation.CapsuleUpdate model.config.clientState.lastRequest x))
                                    |> App.orError
                                )

                        previousSlide =
                            capsule.structure
                                |> List.concatMap .slides
                                |> List.drop (currentSlideIndex - 2)
                                |> List.head
                    in
                    ( { model
                        | config = Config.incrementRequest model.config
                        , page =
                            App.Preparation <|
                                case previousSlide of
                                    Just previousSlidee ->
                                        { m
                                            | popupType = Preparation.EditPromptPopup previousSlidee
                                            , displayPopup = True
                                        }

                                    Nothing ->
                                        { m | displayPopup = False }
                      }
                    , sync
                    )

                Preparation.GoToNextSlide currentSlideIndex currentSlide ->
                    let
                        newCapsule =
                            Data.updateSlide { currentSlide | prompt = fixPrompt currentSlide.prompt } capsule

                        sync =
                            Api.updateCapsule newCapsule
                                ((\x -> App.PreparationMsg (Preparation.CapsuleUpdate model.config.clientState.lastRequest x))
                                    |> App.orError
                                )

                        nextSlide =
                            capsule.structure
                                |> List.concatMap .slides
                                |> List.drop currentSlideIndex
                                |> List.head
                    in
                    ( { model
                        | config = Config.incrementRequest model.config
                        , page =
                            App.Preparation <|
                                case nextSlide of
                                    Just nextSlidee ->
                                        { m
                                            | popupType = Preparation.EditPromptPopup nextSlidee
                                            , displayPopup = True
                                        }

                                    Nothing ->
                                        { m | displayPopup = False }
                      }
                    , sync
                    )

                Preparation.EscapePressed ->
                    if m.displayPopup then
                        case m.popupType of
                            Preparation.ConfirmUpdateCapsulePopup _ ->
                                update Preparation.CancelUpdateCapsule model

                            _ ->
                                ( { model | page = App.Preparation { m | displayPopup = False } }, Cmd.none )

                    else
                        ( model, Cmd.none )

                Preparation.EnterPressed ->
                    if m.displayPopup then
                        case m.popupType of
                            Preparation.NoPopup ->
                                ( model, Cmd.none )

                            Preparation.EditPromptPopup slide ->
                                ( model, Cmd.none )

                            Preparation.DeleteExtraPopup slide ->
                                update (Preparation.DeleteExtra Utils.Confirm slide) model

                            Preparation.DeleteSlidePopup slide ->
                                update (Preparation.DeleteSlide Utils.Confirm slide) model

                            Preparation.ConfirmUpdateCapsulePopup c ->
                                update Preparation.ConfirmUpdateCapsule model

                            Preparation.ChangeSlidePopup f ->
                                -- TODO fix this
                                -- update
                                --     (Preparation.Resource <|
                                --         Preparation.Selected
                                --             f.slide
                                --             f.file
                                --             (Just 0)
                                --     )
                                --     model
                                ( model, Cmd.none )

                            Preparation.ConfirmAddSlide gos ->
                                -- TODO fix this
                                -- let
                                --     ( newModel, newCmd, newConfig ) =
                                --         updateExtra model.user
                                --             (Preparation.Select Utils.Confirm (Preparation.AddSlide gos))
                                --             m
                                --             model.config
                                -- in
                                -- ( { model | config = newConfig, page = App.Preparation newModel }, newCmd )
                                ( model, Cmd.none )

                            Preparation.ConfirmUploadExtraVideo file slide ->
                                ( model, Cmd.none )

                    else
                        ( model, Cmd.none )

                Preparation.ConfirmUpdateCapsule ->
                    if m.displayPopup then
                        case m.popupType of
                            Preparation.ConfirmUpdateCapsulePopup c ->
                                ( { model | page = App.Preparation <| Preparation.init c, config = Config.incrementRequest model.config }
                                , Api.updateCapsule c
                                    ((\x -> App.PreparationMsg (Preparation.CapsuleUpdate model.config.clientState.lastRequest x))
                                        |> App.orError
                                    )
                                )

                            _ ->
                                ( model, Cmd.none )

                    else
                        ( model, Cmd.none )

                Preparation.CancelUpdateCapsule ->
                    ( { model | page = App.Preparation <| Preparation.init capsule }, Cmd.none )

                Preparation.PageClicked pageId ->
                    let
                        modelResource : Preparation.ResourceModel
                        modelResource =
                            m.resource

                        selectedPages : List Int
                        selectedPages =
                            m.resource.selectedPages

                        --  m.selectedPages
                        newSelectedPages : List Int
                        newSelectedPages =
                            if m.resource.onlyOnePage then
                                if List.member pageId selectedPages then
                                    []

                                else
                                    [ pageId ]

                            else if List.member pageId selectedPages then
                                List.filter ((/=) pageId) selectedPages

                            else
                                selectedPages ++ [ pageId ]
                    in
                    ( { model | page = App.Preparation { m | resource = { modelResource | selectedPages = newSelectedPages } } }
                    , Cmd.none
                    )

        _ ->
            ( model, Cmd.none )


{-| The update function that deals with extra resources.
-}
updateExtra : User -> Preparation.ResourceMsg -> Preparation.Model String -> Config.Config -> ( Preparation.Model String, Cmd App.Msg, Config.Config )
updateExtra user msg model config =
    let
        maybeCapsule =
            Data.getCapsuleById model.capsule user

        modelResource =
            model.resource
    in
    case ( msg, maybeCapsule ) of
        ( Preparation.SelectAddSlides confirmation gosId, Just capsule ) ->
            let
                gosHasRecord =
                    capsule.structure
                        |> List.drop gosId
                        |> List.head
                        |> Maybe.andThen .record
                        |> (\x -> x /= Nothing)
            in
            case ( gosHasRecord, confirmation ) of
                ( _, Utils.Cancel ) ->
                    ( { model | displayPopup = False }
                    , Cmd.none
                    , config
                    )

                ( True, Utils.Request ) ->
                    ( { model | popupType = Preparation.ConfirmAddSlide gosId, displayPopup = True }
                    , Cmd.none
                    , config
                    )

                _ ->
                    ( { model
                        | resource = Preparation.initResource False (Preparation.AddSlide gosId)
                        , displayPopup = False
                      }
                    , selectFilePort [ "image/*", "application/pdf" ]
                    , config
                    )

        ( Preparation.SelectAddGos Utils.Request gosId, Just _ ) ->
            ( { model
                | resource = Preparation.initResource False (Preparation.AddGos gosId)
                , popupType = Preparation.ChangeSlidePopup <| Preparation.AddGos gosId
              }
            , selectFilePort [ "image/*", "application/pdf" ]
            , config
            )

        ( Preparation.SelectReplaceSlide Utils.Request slide, Just _ ) ->
            ( { model
                | resource = Preparation.initResource True (Preparation.ReplaceSlide slide)
                , popupType = Preparation.ChangeSlidePopup <| Preparation.ReplaceSlide slide
              }
            , selectFilePort [ "image/*", "application/pdf", "video/*" ]
            , config
            )

        ( Preparation.SelectedFileReceived Utils.Confirm file, Just capsule ) ->
            case ( String.split "/" file.mime, modelResource.changeSlide ) of
                ( [ "application", "pdf" ], _ ) ->
                    ( { model | resource = { modelResource | file = Just file } }
                    , requestNbPages file
                    , config
                    )

                ( [ "image", _ ], _ ) ->
                    ( model, Ports.sendPdf modelResource.changeSlide file [] capsule, config )

                ( [ "video", _ ], Preparation.ReplaceSlide slide ) ->
                    let
                        elmFile : Maybe File
                        elmFile =
                            Decode.decodeValue File.decoder file.value |> Result.toMaybe

                        cmd : Cmd App.Msg
                        cmd =
                            case elmFile of
                                Just f ->
                                    Api.replaceSlide capsule slide [] f config.clientState.taskId (App.orError mkMsg)

                                _ ->
                                    Cmd.none

                        mkMsg x =
                            App.PreparationMsg <| Preparation.Resource <| Preparation.ChangeSlideUpdated x

                        task : Config.TaskStatus
                        task =
                            { task = Config.TranscodeExtra config.clientState.taskId slide.uuid capsule.id
                            , progress = Just 0.0
                            , finished = False
                            , aborted = False
                            , global = True
                            }

                        ( newConfig, _ ) =
                            Config.update (Config.UpdateTaskStatus task) config
                    in
                    ( model
                    , cmd
                    , newConfig
                    )

                _ ->
                    ( model, Cmd.none, config )

        ( Preparation.SelectedFileReceived Utils.Request file, Just capsule ) ->
            case ( String.split "/" file.mime, modelResource.changeSlide ) of
                ( [ "video", _ ], Preparation.ReplaceSlide slide ) ->
                    -- Check if there is a record in the gos with the slide
                    let
                        hasRecord =
                            capsule.structure
                                |> List.filter (\x -> List.any (\y -> y.uuid == slide.uuid) x.slides)
                                |> List.head
                                |> Maybe.andThen .record
                                |> (/=) Nothing
                    in
                    if hasRecord then
                        -- Show popup
                        ( { model | popupType = Preparation.ConfirmUploadExtraVideo file slide, displayPopup = True }, Cmd.none, config )

                    else
                        -- Directly confirm upload
                        updateExtra user (Preparation.SelectedFileReceived Utils.Confirm file) model config

                _ ->
                    ( model, Cmd.none, config )

        ( Preparation.SelectedFileReceived Utils.Cancel _, Just _ ) ->
            ( { model | displayPopup = False }, Cmd.none, config )

        ( Preparation.NbPagesReceived pages, Just _ ) ->
            ( { model
                | resource = { modelResource | nbPages = pages }
                , displayPopup = True
                , popupType = Preparation.ChangeSlidePopup modelResource.changeSlide
              }
            , Maybe.map Ports.renderPdfForm model.resource.file |> Maybe.withDefault Cmd.none
            , config
            )

        ( Preparation.AddSlides, Just capsule ) ->
            case ( model.resource.file, model.popupType ) of
                ( Just f, Preparation.ChangeSlidePopup c ) ->
                    ( { model | resource = { modelResource | status = RemoteData.Loading Nothing } }
                    , Ports.sendPdf c f model.resource.selectedPages capsule
                    , config
                    )

                _ ->
                    ( model, Cmd.none, config )

        ( Preparation.PdfSent, Just _ ) ->
            ( { model
                | resource = { modelResource | file = Nothing }
                , displayPopup = False
              }
            , Cmd.none
            , config
            )

        ( Preparation.PageCancel, Just _ ) ->
            ( { model | displayPopup = False, changeSlide = RemoteData.NotAsked }, Cmd.none, config )

        ( Preparation.ChangeSlideUpdated (RemoteData.Success c), Just _ ) ->
            let
                cmd : Cmd App.Msg
                cmd =
                    Api.updateCapsule c
                        ((\x -> App.PreparationMsg (Preparation.CapsuleUpdate config.clientState.lastRequest x))
                            |> App.orError
                        )
            in
            ( Preparation.init c, cmd, Config.incrementRequest config )

        ( Preparation.ChangeSlideUpdated d, Just _ ) ->
            ( { model | changeSlide = d }, Cmd.none, config )

        ( Preparation.RenderFinished, Just _ ) ->
            ( { model | resource = { modelResource | renderFinished = True } }, Cmd.none, config )

        _ ->
            ( model, Cmd.none, config )


{-| The update function for the DnD part of the page.
-}
updateDnD : User -> Preparation.DnDMsg -> Preparation.Model String -> Config -> ( ( Preparation.Model String, Config ), Cmd App.Msg )
updateDnD user msg model config =
    let
        maybeCapsule =
            Data.getCapsuleById model.capsule user
    in
    case ( msg, maybeCapsule ) of
        ( Preparation.SlideMoved sMsg, Just capsule ) ->
            let
                pre =
                    Preparation.slideSystem.info model.slideModel

                ( slideModel, slides ) =
                    Preparation.slideSystem.update sMsg model.slideModel model.slides

                post =
                    Preparation.slideSystem.info slideModel

                dropped =
                    pre /= Nothing && post == Nothing

                ( ( broken, newStructure ), newSlides ) =
                    case ( pre, post ) of
                        ( Just _, Nothing ) ->
                            let
                                extracted =
                                    extractStructure slides
                            in
                            ( fixStructure capsule.structure extracted
                            , Preparation.setupSlides { capsule | structure = extracted }
                            )

                        _ ->
                            ( ( False, capsule.structure ), slides )

                ( syncCmd, newConfig ) =
                    if dropped && capsule.structure /= newStructure && not broken then
                        ( Api.updateCapsule
                            { capsule | structure = newStructure }
                            ((\x -> App.PreparationMsg (Preparation.CapsuleUpdate config.clientState.lastRequest x))
                                |> App.orError
                            )
                        , Config.incrementRequest config
                        )

                    else
                        ( Cmd.none, config )

                newCapsule =
                    { capsule | structure = newStructure }
            in
            ( ( { model
                    | slideModel = slideModel
                    , popupType = Utils.tern broken (Preparation.ConfirmUpdateCapsulePopup newCapsule) model.popupType
                    , displayPopup = Utils.tern broken True model.displayPopup
                    , slides = newSlides
                }
              , newConfig
              )
            , Cmd.batch
                [ syncCmd
                , Preparation.slideSystem.commands slideModel
                    |> Cmd.map (\x -> App.PreparationMsg (Preparation.DnD x))
                ]
            )

        _ ->
            ( ( model, config ), Cmd.none )


{-| Creates a dummy capsule structure given a list of slides.
-}
extractStructure : List Preparation.Slide -> List Data.Gos
extractStructure slides =
    slides
        |> List.Extra.gatherWith (\a b -> a.totalGosId == b.totalGosId)
        |> List.map (\( a, b ) -> a :: b)
        |> List.map (List.filterMap .slide)
        |> List.filter (\x -> x /= [])
        |> List.map Data.gosFromSlides


{-| Retrieves the information in the structure from the old structure given a structure that contains only slides.

Returns the new structure as well as a boolean indicating if records have been lost.

-}
fixStructure : List Data.Gos -> List Data.Gos -> ( Bool, List Data.Gos )
fixStructure old new =
    let
        -- The dict that associates the list of slides id to the gos in the previous list of gos
        oldGos : Dict (List String) Data.Gos
        oldGos =
            Dict.fromList (List.map (\x -> ( List.map .uuid x.slides, x )) old)

        -- The dict that associates the list of slides id to the gos in the new
        -- list of gos, which doesn't contain any records or other stuff
        newGos : Dict (List String) Data.Gos
        newGos =
            Dict.fromList (List.map (\x -> ( List.map .uuid x.slides, x )) new)

        -- Retrieves the old gos from the new gos, allownig to get the record and other stuff back
        fix : Data.Gos -> Data.Gos
        fix gos =
            case Dict.get (List.map .uuid gos.slides) oldGos of
                Nothing ->
                    gos

                Just x ->
                    x

        -- Retrieves the new gos from the old gos, if not found and the old gos
        -- has records and stuff, it will be lost
        isBroken : Data.Gos -> Bool
        isBroken gos =
            case ( Dict.get (List.map .uuid gos.slides) newGos, gos.record ) of
                -- if not found but the previous gos has a record, the record will be lost
                ( Nothing, Just _ ) ->
                    True

                -- otherwise, everything is fine
                _ ->
                    False

        broken =
            List.any isBroken old

        ret =
            List.map fix new
    in
    ( broken, ret )


{-| Fixes the empty lines and trailing spaces in a prompt string.
-}
fixPrompt : String -> String
fixPrompt input =
    input
        |> String.split "\n"
        |> List.filter (not << String.isEmpty)
        |> List.map String.trim
        |> String.join "\n"


{-| Keyboard shortcuts of the preparation page.
-}
shortcuts : Keyboard.RawKey -> App.Msg
shortcuts msg =
    case Keyboard.rawValue msg of
        "Escape" ->
            App.PreparationMsg Preparation.EscapePressed

        "Enter" ->
            App.PreparationMsg Preparation.EnterPressed

        _ ->
            App.Noop


{-| Select a file.
-}
port selectFilePort : List String -> Cmd msg


{-| Receives a file that has been selected.
-}
port receiveSelectedFile : (( Encode.Value, Encode.Value ) -> msg) -> Sub msg


{-| Helper to request the number of pages of a PDF file.
-}
requestNbPages : FileValue.File -> Cmd msg
requestNbPages file =
    requestNbPagesPort (FileValue.encode file)


{-| Request the number of pages of a PDF File.
-}
port requestNbPagesPort : Encode.Value -> Cmd msg


{-| Sub to get the number of pages of a PDF file.
-}
port receivedNbPages : (Int -> msg) -> Sub msg


{-| Subscriptions for the prepration view.
-}
subs : Preparation.Model String -> Sub App.Msg
subs model =
    Sub.batch
        [ Sub.batch
            [ Preparation.slideSystem.subscriptions model.slideModel
            , Preparation.gosSystem.subscriptions model.gosModel
            ]
            |> Sub.map Preparation.DnD
            |> Sub.map App.PreparationMsg
        , Keyboard.ups shortcuts
        , receivedNbPages (\x -> App.PreparationMsg <| Preparation.Resource <| Preparation.NbPagesReceived x)
        , receiveSelectedFile
            (\( confirm, file ) ->
                case ( Decode.decodeValue Utils.decodeConfirm confirm, Decode.decodeValue FileValue.decoder file ) of
                    ( Ok x, Ok y ) ->
                        App.PreparationMsg <| Preparation.Resource <| Preparation.SelectedFileReceived x y

                    _ ->
                        App.Noop
            )
        , Sub.map (Maybe.withDefault App.Noop) <|
            Ports.pdfSent (\_ -> App.PreparationMsg <| Preparation.Resource <| Preparation.PdfSent)
        , Ports.renderFinished (App.PreparationMsg <| Preparation.Resource <| Preparation.RenderFinished)
        ]
