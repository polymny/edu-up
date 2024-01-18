module NewCapsule.Types exposing (Model, NextPage(..), Msg(..), Slide, init, prepare, structureFromUi, toggle)

{-| This module contains the types for the page the users land when they upload a slideshow.

@docs Model, NextPage, Msg, Slide, init, prepare, structureFromUi, toggle

-}

import Data.Capsule as Data
import FileValue
import Lang exposing (Lang)
import List.Extra
import Ports
import RemoteData exposing (WebData)
import Strings
import Triplet
import Utils


{-| The model of the new capsule page.
-}
type alias Model =
    { structure : List Int
    , capsuleUpdate : WebData ()
    , projectName : String
    , capsuleName : String
    , showProject : Bool
    , pdfFile : FileValue.File
    , numPages : Int
    , nextPage : NextPage
    , renderFinished : Bool
    }


{-| Whether the user clicked on preparation or acquisition.
-}
type NextPage
    = Preparation
    | Acquisition


{-| Local type for slide.

The first int is the index of the slide, the second is the index of the grain.

-}
type alias Slide =
    ( Int, Int, Data.Slide )


{-| An init function to easily create a model for the new capsule page.
-}
init : Lang -> Maybe String -> String -> FileValue.File -> Int -> ( Model, Cmd Msg )
init lang projectName capsuleName pdfFile numPages =
    ( { projectName = projectName |> Maybe.withDefault (Strings.stepsPreparationNewProject lang)
      , capsuleName = capsuleName
      , showProject = projectName /= Nothing
      , capsuleUpdate = RemoteData.NotAsked
      , pdfFile = pdfFile
      , numPages = numPages
      , structure = List.indexedMap (\i _ -> i) <| List.repeat numPages ()
      , nextPage = Preparation
      , renderFinished = False
      }
    , Ports.renderPdfForm pdfFile
    )


{-| Prepares the capsule for easily accessing the first step of preparation.
-}
prepare : Data.Capsule -> List Slide
prepare capsule =
    List.indexedMap (\i s -> ( i, i, s )) (List.concat (List.map .slides capsule.structure))


{-| Toggles a delimiter easily.

Between each slides, there is a delimiter. The user can click on the delimiter to change its style: it can either be a
solid delimiter which indicates that the two slides belong to two different grains, which means that the slide after the
delimiter belongs to another grain, or it can be a dashed delimiter, which means that the two slides belong to the same
grain.

This function changes the state of a delimiter, and updates the indices of grains.

The boolean attribute must be true if the two slides belong to the same grain and need to be separated.

The integer attribute is the index of the delimiter (an index of 0 means a delimiter between slides 0 and 1).

-}
toggle : Bool -> Int -> List Int -> List Int
toggle split delimiter input =
    toggleAux [] split delimiter input |> List.reverse


{-| Auxilary function to help toggle function.

Delimiter being -1 means that the index has been reached and that the gos indices must be updated.

-}
toggleAux : List Int -> Bool -> Int -> List Int -> List Int
toggleAux acc split delimiter input =
    case input of
        h1 :: h2 :: t ->
            if delimiter == -1 then
                -- If split is true, it means that the two slides belong to the same grain, and must be separated. We do
                -- that by adding 1 to every gos index after have reached the delimiter index.
                -- Otherwise, it means that the two slides belong to different grain, and must be regrouped
                -- together. It means that we need to remove 1 from all gos indices after having reached the delimiter
                -- index.
                toggleAux ((h1 + Utils.tern split 1 -1) :: acc) split delimiter (h2 :: t)

            else
                -- We haven't find the delimiter yet, so we keep searching.
                toggleAux (h1 :: acc) split (delimiter - 1) (h2 :: t)

        h :: [] ->
            if delimiter == -1 then
                h + Utils.tern split 1 -1 :: acc

            else
                h :: acc

        _ ->
            []


{-| Creates the list of gos from the list of slides.

The caspule contains the structure, which is a List of Data.Gos. In the model of this page, we only have the List Int
which contains the index of the gos of each slide, because it makes it really easier for both the view and the update.

This function allows to retrieve the structure of the capsule from the List Int and List Data.Slide.

-}
structureFromUi : List Int -> List Data.Slide -> List Data.Gos
structureFromUi structure slides =
    List.map2 (\x y -> ( x, y )) structure slides
        |> List.Extra.groupWhile (\x y -> Tuple.first x == Tuple.first y)
        |> List.map (\( h, t ) -> Data.gosFromSlides <| List.map Tuple.second (h :: t))


{-| The message type for the new capsule page.
-}
type Msg
    = NameChanged String
    | ProjectChanged String
    | DelimiterClicked Bool Int
    | Submit NextPage
    | Cancel
    | PdfSent (WebData Data.Capsule)
    | Finished Data.Capsule
    | RenderFinished
