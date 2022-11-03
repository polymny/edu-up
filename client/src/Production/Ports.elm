port module Production.Ports exposing (..)

import Json.Decode as Decode


port selectBackground : List String -> Cmd msg


port backgroundSelected : (Decode.Value -> msg) -> Sub msg
