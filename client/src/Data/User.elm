module Data.User exposing
    ( User, decodeUser, isPremium, addCapsule, deleteCapsule, updateUser, sortProjects, getCapsuleById, Project, toggleProject, compareCapsule, compareProject, fixPresign
    , addAssignment, getAssignmentById, getGroupById, updateAssignment
    )

{-| This module contains all the data related to the user.

@docs User, decodeUser, isPremium, addCapsule, deleteCapsule, updateUser, sortProjects, getCapsuleById, Project, toggleProject, compareCapsule, compareProject, fixPresign

-}

import Data.Capsule as Data exposing (Capsule)
import Data.Group as Data
import Data.Types as Data
import Json.Decode as Decode exposing (Decoder)
import List.Extra


{-| This type represents capsules that go together.

It does not mean anything per se, a project is just a string in a capsule, but capsules that have the same string belong
together.

-}
type alias Project =
    { name : String
    , capsules : List Data.Capsule
    , folded : Bool
    }


{-| This type is the mapping of the JSON received by the server.

It needs to be modified and sorted before use.

-}
type alias PrivateUser =
    { username : String
    , email : String
    , plan : Data.Plan
    , capsules : List Capsule
    , quota : Int
    , groups : List Data.Group
    }


{-| JSON decoder for PrivateUser.
-}
decodePrivateUser : Decoder PrivateUser
decodePrivateUser =
    Decode.map6 PrivateUser
        (Decode.field "username" Decode.string)
        (Decode.field "email" Decode.string)
        (Decode.field "plan" Data.decodePlan)
        (Decode.field "capsules" (Decode.list Data.decodeCapsule))
        (Decode.field "disk_quota" Decode.int)
        (Decode.field "groups" (Decode.list Data.decodeGroup))


{-| This type represents a user with all the info we have on them.
-}
type alias User =
    { username : String
    , email : String
    , plan : Data.Plan
    , projects : List Project
    , quota : Int
    , groups : List Data.Group
    }


{-| Returns true if the user have access to premium functionnalities.
-}
isPremium : User -> Bool
isPremium user =
    case user.plan of
        Data.PremiumLvl1 ->
            True

        Data.Admin ->
            True

        _ ->
            False


{-| JSON decoder for user.
-}
decodeUser : Data.SortBy -> Decoder User
decodeUser sortBy =
    decodePrivateUser
        |> Decode.map
            (\user ->
                { username = user.username
                , email = user.email
                , plan = user.plan
                , projects = capsulesToProjects user.capsules |> sortProjects sortBy
                , quota = user.quota
                , groups = user.groups
                }
            )


{-| Utility function to compare capsules based on a sort by.
-}
compareCapsule : Data.SortBy -> Capsule -> Capsule -> Order
compareCapsule { key, ascending } aInput bInput =
    let
        ( a, b ) =
            if ascending then
                ( aInput, bInput )

            else
                ( bInput, aInput )
    in
    case key of
        Data.Name ->
            compare a.name b.name

        Data.LastModified ->
            compare a.lastModified b.lastModified


{-| Utility function to compare projects based on a sort by.
-}
compareProject : Data.SortBy -> Project -> Project -> Order
compareProject { key, ascending } aInput bInput =
    let
        ( a, b ) =
            if ascending then
                ( aInput, bInput )

            else
                ( bInput, aInput )
    in
    case key of
        Data.Name ->
            compare a.name b.name

        Data.LastModified ->
            compare
                (a.capsules |> List.head |> Maybe.map .lastModified |> Maybe.withDefault 0)
                (b.capsules |> List.head |> Maybe.map .lastModified |> Maybe.withDefault 0)


{-| Utility function to group capsules in projects.
-}
capsulesToProjects : List Capsule -> List Project
capsulesToProjects capsules =
    let
        organizedCapsules : List ( Capsule, List Capsule )
        organizedCapsules =
            List.Extra.gatherWith (\x y -> x.project == y.project) capsules

        capsulesToProject : ( Capsule, List Capsule ) -> Project
        capsulesToProject ( h, t ) =
            { name = h.project
            , capsules = h :: t
            , folded = True
            }
    in
    List.map capsulesToProject organizedCapsules


{-| Sort the projects and the capsules based on a sort by.
-}
sortProjects : Data.SortBy -> List Project -> List Project
sortProjects sortBy projects =
    projects
        |> List.map (\p -> { p | capsules = List.sortWith (compareCapsule sortBy) p.capsules })
        |> List.sortWith (compareProject sortBy)


{-| Toggles a project.
-}
toggleProject : Project -> User -> User
toggleProject project user =
    let
        mapper : Project -> Project
        mapper p =
            if project.name == p.name then
                { p | folded = not p.folded }

            else
                p
    in
    { user | projects = List.map mapper user.projects }


{-| Function to easily fetch a capsule from its id.
-}
getCapsuleById : String -> User -> Maybe Capsule
getCapsuleById id user =
    getCapsuleByIdAux id user.projects


{-| Auxilary function to help fetch a capsule from its id.
-}
getCapsuleByIdAux : String -> List Project -> Maybe Capsule
getCapsuleByIdAux id projects =
    case projects of
        [] ->
            Nothing

        h :: t ->
            case h.capsules of
                [] ->
                    getCapsuleByIdAux id t

                h2 :: t2 ->
                    if h2.id == id then
                        Just h2

                    else
                        getCapsuleByIdAux id ({ h | capsules = t2 } :: t)


{-| Adds a capsule in a user.
-}
addCapsule : Capsule -> User -> User
addCapsule capsule user =
    { user | projects = addCapsuleAux capsule False [] user.projects }


addCapsuleAux : Capsule -> Bool -> List Project -> List Project -> List Project
addCapsuleAux capsule finished acc input =
    case input of
        [] ->
            if finished then
                acc

            else
                { name = capsule.project, capsules = [ capsule ], folded = False } :: acc

        h :: t ->
            if finished then
                addCapsuleAux capsule True (h :: acc) t

            else if h.name == capsule.project then
                addCapsuleAux capsule True ({ h | capsules = capsule :: h.capsules } :: acc) t

            else
                addCapsuleAux capsule False (h :: acc) t


{-| Deletes a capsule in a user.
-}
deleteCapsule : Capsule -> User -> User
deleteCapsule capsule user =
    let
        projectMapper : Project -> Project
        projectMapper project =
            { project | capsules = List.filter (\c -> c.id /= capsule.id) project.capsules }
    in
    { user
        | projects =
            List.map projectMapper user.projects
                |> List.filter (\x -> not <| List.isEmpty x.capsules)
    }


{-| Updates a capsule in a user.
-}
updateUser : Capsule -> User -> User
updateUser capsule user =
    let
        capsuleMapper : Capsule -> ( Capsule, Bool )
        capsuleMapper c =
            if c.id == capsule.id then
                fixPresign c capsule

            else
                ( c, False )

        projectMapper : Project -> Project
        projectMapper project =
            let
                ( capsules, changed ) =
                    List.map capsuleMapper project.capsules |> List.unzip

                newCapsules =
                    if capsule.project == project.name && not (List.any (\x -> x) changed) then
                        capsule :: project.capsules

                    else
                        capsules
            in
            { project | capsules = newCapsules }
    in
    { user | projects = List.map projectMapper user.projects }


{-| Adds an assignment to a user.
-}
addAssignment : Data.Assignment -> User -> User
addAssignment assignment user =
    let
        updateGroup : Data.Group -> Data.Group
        updateGroup group =
            if group.id == assignment.group then
                { group | assignments = assignment :: group.assignments }

            else
                group
    in
    { user | groups = List.map updateGroup user.groups }


{-| Updates an assignment.
-}
updateAssignment : Data.Assignment -> User -> User
updateAssignment assignment user =
    let
        updateSingleAssignment : Data.Assignment -> Data.Assignment
        updateSingleAssignment a =
            if a.id == assignment.id then
                assignment

            else
                a

        updateGroup : Data.Group -> Data.Group
        updateGroup group =
            { group | assignments = List.map updateSingleAssignment group.assignments }
    in
    { user | groups = List.map updateGroup user.groups }


{-| Gets a group from its id.
-}
getGroupById : Int -> User -> Maybe Data.Group
getGroupById id user =
    user.groups |> List.filter (\x -> x.id == id) |> List.head


{-| Gets an assignment from its id.
-}
getAssignmentById : Int -> User -> Maybe Data.Assignment
getAssignmentById id user =
    user.groups
        |> List.concatMap .assignments
        |> List.filter (\x -> x.id == id)
        |> List.head


{-| Updates the capsule but keeping the old presign values to avoid redownloading the same files over and over again.
-}
fixPresign : Capsule -> Capsule -> Capsule
fixPresign old new =
    { new
        | outputPresign = fixMaybePresignUrl old.outputPresign new.outputPresign
        , soundTrackPresign = fixMaybePresignUrl old.soundTrackPresign new.soundTrackPresign
        , structure = fixPresignStructure old.structure new.structure
    }


{-| Fix presign structure.
-}
fixPresignStructure : List Data.Gos -> List Data.Gos -> List Data.Gos
fixPresignStructure old new =
    let
        oldSlides =
            List.concatMap .slides old

        gosMapper : Data.Gos -> Data.Gos
        gosMapper current =
            let
                slides =
                    fixPresignSlides oldSlides current.slides

                producedPresign =
                    case List.filter (\x -> x.producedHash == current.producedHash) old |> List.head |> Maybe.map .producedPresign of
                        Just presign ->
                            presign

                        _ ->
                            current.producedPresign

                record =
                    case current.record of
                        Just r ->
                            let
                                ( presign, miniaturePresign ) =
                                    case List.filter (\x -> Maybe.map .uuid x.record == Just r.uuid) old of
                                        h :: _ ->
                                            -- h.record can't be null because its .uuid == Just r.uuid
                                            ( Maybe.andThen .presign h.record, Maybe.andThen .miniaturePresign h.record )

                                        _ ->
                                            ( r.presign, r.miniaturePresign )

                                pointerPresign =
                                    case List.filter (\x -> Maybe.map .pointerUuid x.record == Just r.pointerUuid) old of
                                        h :: _ ->
                                            -- h.record can't be null because its .uuid == Just r.uuid
                                            Maybe.andThen .pointerPresign h.record

                                        _ ->
                                            r.pointerPresign
                            in
                            Just { r | presign = presign, pointerPresign = pointerPresign, miniaturePresign = miniaturePresign }

                        _ ->
                            Nothing
            in
            { current | record = record, slides = slides, producedPresign = producedPresign }
    in
    List.map gosMapper new


{-| Fix presign slides.
-}
fixPresignSlides : List Data.Slide -> List Data.Slide -> List Data.Slide
fixPresignSlides old new =
    let
        slideMapper : Data.Slide -> Data.Slide
        slideMapper current =
            let
                presign =
                    case List.filter (\x -> x.uuid == current.uuid) old of
                        h :: _ ->
                            h.presign

                        _ ->
                            current.presign

                extraPresign =
                    case List.filter (\x -> x.extra == current.extra) old of
                        h :: _ ->
                            h.extraPresign

                        _ ->
                            current.extraPresign
            in
            { current | presign = presign, extraPresign = extraPresign }
    in
    List.map slideMapper new


{-| Helper to easy fix maybe presign urls.
-}
fixMaybePresignUrl : Maybe String -> Maybe String -> Maybe String
fixMaybePresignUrl old new =
    case ( old, new ) of
        ( Just o, Just n ) ->
            Just <| fixPresignUrl o n

        ( _, Just n ) ->
            Just n

        _ ->
            Nothing


{-| Checks two presign URLs and return the correct one.
-}
fixPresignUrl : String -> String -> String
fixPresignUrl old new =
    let
        -- This is the old file url
        oldBaseUrl =
            List.head <| String.split "?" old

        -- This is the new file url
        newBaseUrl =
            List.head <| String.split "?" new

        answerUrl =
            -- If the old file url and new file url are the same, it is the same file, so we want to preserve the
            -- oldPresign
            if oldBaseUrl == newBaseUrl then
                old

            else
                -- Otherwise, it means that it is a new file and we should update it
                new
    in
    answerUrl
