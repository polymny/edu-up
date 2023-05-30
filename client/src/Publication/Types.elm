module Publication.Types exposing (..)

{-| This module holds the types for the publication page.
-}

import Data.Capsule exposing (Capsule)
import Data.Types as Data


type alias Model a =
    { capsule : a
    , popupType : PopupType
    }


type PopupType
    = NoPopup
    | PrivacyPopup
    | IntegrationPopup


withCapsule : Capsule -> Model String -> Model Capsule
withCapsule capsule model =
    { capsule = capsule
    , popupType = model.popupType
    }


init : Capsule -> Model String
init capsule =
    { capsule = capsule.id
    , popupType = NoPopup
    }


type Msg
    = TogglePrivacyPopup
    | SetPrivacy Data.Privacy
    | SetPromptSubtitles Bool
    | PublishVideo
    | UnpublishVideo
    | ToggleIntegrationPopup
