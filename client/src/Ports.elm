port module Ports exposing (..)

{-| This module exposes useful ports.
-}

import Data.Capsule as Data
import FileValue
import Json.Decode as Decode
import Json.Encode as Encode
import Preparation.Types as Preparation


{-| Helper to render the pdf in the form.
-}
renderPdfForm : FileValue.File -> Cmd msg
renderPdfForm file =
    renderPdfFormPort (FileValue.encode file)


{-| Port to render the pdf in the form.
-}
port renderPdfFormPort : Encode.Value -> Cmd msg


{-| Helper to received an Msg when the rendering of a PDF has finished.
-}
renderFinished : msg -> Sub msg
renderFinished x =
    renderFinishedPort (\_ -> x)


{-| When the rendering of a PDF has finished.
-}
port renderFinishedPort : (() -> msg) -> Sub msg


{-| Helper to send the pdf file to the server.
-}
sendPdf : Preparation.ChangeSlide -> FileValue.File -> List Int -> Data.Capsule -> Cmd msg
sendPdf ty file pages capsule =
    sendPdfPort ( Preparation.encodeChangeSlide ty, ( FileValue.encode file, pages ), capsule.id )


{-| Port to send the pdf to the server as a zip of webps.
-}
port sendPdfPort : ( Encode.Value, ( Encode.Value, List Int ), String ) -> Cmd msg


{-| Helper for the sub to know when the sending of a PDF is finished.
-}
pdfSent : (Data.Capsule -> msg) -> Sub (Maybe msg)
pdfSent toMsg =
    pdfSentPort
        (\x ->
            case Decode.decodeValue Data.decodeCapsule x of
                Ok y ->
                    Just <| toMsg y

                _ ->
                    Nothing
        )


{-| Sub to know when the sending of a PDF is finished.
-}
port pdfSentPort : (Decode.Value -> msg) -> Sub msg
