module Error.Types exposing (..)

{-| This module helps us show a better UI for error pages.
-}


{-| The model of the error page.
-}
type alias Model =
    { reason : Reason
    }


{-| Initializes a model.
-}
init : Reason -> Model
init reason =
    { reason = reason }


{-| Converts a HTTP error code to a reason.
-}
fromCode : Int -> Reason
fromCode code =
    if code < 400 then
        Unknown

    else if code < 500 then
        NotFound

    else
        ServerError


{-| The reason for the error.
-}
type Reason
    = NotFound
    | ServerError
    | Unknown
