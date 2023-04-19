module Strings exposing (..)

import Lang exposing (Lang)


uiWebSocketWaitRefreshContactAdmin : Lang -> String
uiWebSocketWaitRefreshContactAdmin lang =
    case lang of
        Lang.EnUs ->
            "You can wait or try to refresh the page, or contact the administrator if the problem persists"

        Lang.FrFr ->
            "Vous pouvez patienter ou raffraîchir la page, ou contacter l'administrateur si le problème persiste"


actionsConfirmDeleteSlide : Lang -> String
actionsConfirmDeleteSlide lang =
    case lang of
        Lang.EnUs ->
            "Do you really want to delete this slide"

        Lang.FrFr ->
            "Voulez-vous vraiment supprimer cette planche"


tasksProductionCapsule : Lang -> String
tasksProductionCapsule lang =
    case lang of
        Lang.EnUs ->
            "Production"

        Lang.FrFr ->
            "Production"


actionsGoToNextSlide : Lang -> String
actionsGoToNextSlide lang =
    case lang of
        Lang.EnUs ->
            "Go to the next slide"

        Lang.FrFr ->
            "Aller à la planche suivante"


deviceWebcam : Lang -> String
deviceWebcam lang =
    case lang of
        Lang.EnUs ->
            "Webcam"

        Lang.FrFr ->
            "Webcam"


navigationWatchRecord : Lang -> String
navigationWatchRecord lang =
    case lang of
        Lang.EnUs ->
            "Watch the record"

        Lang.FrFr ->
            "Regarder cet enregistrement"


loginSignUp : Lang -> String
loginSignUp lang =
    case lang of
        Lang.EnUs ->
            "Sign up"

        Lang.FrFr ->
            "S'inscrire"


stepsProductionCustom : Lang -> String
stepsProductionCustom lang =
    case lang of
        Lang.EnUs ->
            "Custom"

        Lang.FrFr ->
            "Personnalisé"


dataCapsuleCapsule : Lang -> Int -> String
dataCapsuleCapsule lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "Capsule"

            else
                "Capsules"


        Lang.FrFr ->
            if n <= 1 then
                "Capsule"

            else
                "Capsules"



dateMonthFebruary : Lang -> String
dateMonthFebruary lang =
    case lang of
        Lang.EnUs ->
            "February"

        Lang.FrFr ->
            "Février"


uiProfileEmail : Lang -> String
uiProfileEmail lang =
    case lang of
        Lang.EnUs ->
            "Email"

        Lang.FrFr ->
            "Adresse email"


uiWarningConfirmDeleteCapsule : Lang -> String
uiWarningConfirmDeleteCapsule lang =
    case lang of
        Lang.EnUs ->
            "Do you really want to delete the capsule"

        Lang.FrFr ->
            "Voulez-vous vraiment supprimer la capsule"


uiTasksClient : Lang -> String
uiTasksClient lang =
    case lang of
        Lang.EnUs ->
            "Client tasks"

        Lang.FrFr ->
            "Tâches client"


stepsConfigErrorSharing : Lang -> String
stepsConfigErrorSharing lang =
    case lang of
        Lang.EnUs ->
            "Error sharing capsule"

        Lang.FrFr ->
            "Erreur lors du partage de la capsule"


configVersion : Lang -> String
configVersion lang =
    case lang of
        Lang.EnUs ->
            "Version"

        Lang.FrFr ->
            "Version"


stepsPreparationPreparation : Lang -> String
stepsPreparationPreparation lang =
    case lang of
        Lang.EnUs ->
            "Preparation"

        Lang.FrFr ->
            "Préparation"


dataCapsuleDeleteCapsule : Lang -> String
dataCapsuleDeleteCapsule lang =
    case lang of
        Lang.EnUs ->
            "Delete capsule"

        Lang.FrFr ->
            "Supprimer la capsule"


stepsProductionProduction : Lang -> String
stepsProductionProduction lang =
    case lang of
        Lang.EnUs ->
            "Production"

        Lang.FrFr ->
            "Production"


stepsProductionActivateFading : Lang -> String
stepsProductionActivateFading lang =
    case lang of
        Lang.EnUs ->
            "Activate fading"

        Lang.FrFr ->
            "Activer le fading"


dataCapsuleRoleRole : Lang -> String
dataCapsuleRoleRole lang =
    case lang of
        Lang.EnUs ->
            "Role"

        Lang.FrFr ->
            "Rôle"


uiProfileProduced : Lang -> Int -> String
uiProfileProduced lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "Produced capsule"

            else
                "Produced capsule"


        Lang.FrFr ->
            if n <= 1 then
                "Capsule produite"

            else
                "Capsules produites"



stepsOptionsStopPreview : Lang -> String
stepsOptionsStopPreview lang =
    case lang of
        Lang.EnUs ->
            "Stop sound track preview"

        Lang.FrFr ->
            "Arrêter l'aperçu"


stepsAcquisitionErrorUploadingRecord : Lang -> String
stepsAcquisitionErrorUploadingRecord lang =
    case lang of
        Lang.EnUs ->
            "Error uploading record, please try again"

        Lang.FrFr ->
            "Échec de l'envoi de l'enregistrement, veuillez recommencer"


stepsAcquisitionRecordPointer : Lang -> String
stepsAcquisitionRecordPointer lang =
    case lang of
        Lang.EnUs ->
            "Record pointer"

        Lang.FrFr ->
            "Enregistrer le pointeur"


dateMonthMarch : Lang -> String
dateMonthMarch lang =
    case lang of
        Lang.EnUs ->
            "March"

        Lang.FrFr ->
            "Mars"


loginDeleteAccount : Lang -> String
loginDeleteAccount lang =
    case lang of
        Lang.EnUs ->
            "Delete account"

        Lang.FrFr ->
            "Supprimer le compte"


stepsProductionTopLeft : Lang -> String
stepsProductionTopLeft lang =
    case lang of
        Lang.EnUs ->
            "Top left corner"

        Lang.FrFr ->
            "En haut à gauche"


stepsPublicationPublishingVideo : Lang -> String
stepsPublicationPublishingVideo lang =
    case lang of
        Lang.EnUs ->
            "Currently publishing video"

        Lang.FrFr ->
            "Publication de la vidéo en cours"


stepsAcquisitionRecording : Lang -> String
stepsAcquisitionRecording lang =
    case lang of
        Lang.EnUs ->
            "Recording"

        Lang.FrFr ->
            "Enregistrement en cours"


stepsOptionsVolume : Lang -> String
stepsOptionsVolume lang =
    case lang of
        Lang.EnUs ->
            "Sound track volume"

        Lang.FrFr ->
            "Volume de la musique de fond"


uiTasksServer : Lang -> String
uiTasksServer lang =
    case lang of
        Lang.EnUs ->
            "Server tasks"

        Lang.FrFr ->
            "Tâches serveur"


actionsZoomIn : Lang -> String
actionsZoomIn lang =
    case lang of
        Lang.EnUs ->
            "Zoom in"

        Lang.FrFr ->
            "Zoomer"


stepsPreparationWhichPage : Lang -> String
stepsPreparationWhichPage lang =
    case lang of
        Lang.EnUs ->
            "Which page of the PDF do you want to use"

        Lang.FrFr ->
            "Quelle page du PDF souhaitez-vous utiliser"


dataCapsulePublished : Lang -> Int -> String
dataCapsulePublished lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "Published"

            else
                "Published"


        Lang.FrFr ->
            if n <= 1 then
                "Publiée"

            else
                "Publiées"



stepsProductionWatchVideo : Lang -> String
stepsProductionWatchVideo lang =
    case lang of
        Lang.EnUs ->
            "Watch video"

        Lang.FrFr ->
            "Regarder la vidéo"


stepsPreparationSelectPdf : Lang -> String
stepsPreparationSelectPdf lang =
    case lang of
        Lang.EnUs ->
            "Select PDF"

        Lang.FrFr ->
            "Choisir un PDF"


configCommit : Lang -> String
configCommit lang =
    case lang of
        Lang.EnUs ->
            "Commit"

        Lang.FrFr ->
            "Commit"


actionsAbortTrack : Lang -> String
actionsAbortTrack lang =
    case lang of
        Lang.EnUs ->
            "Abort track upload"

        Lang.FrFr ->
            "Annuler l'ajout de la musique de fond"


dataUserVerifiedUser : Lang -> Int -> String
dataUserVerifiedUser lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "Verified user"

            else
                "Verified users"


        Lang.FrFr ->
            if n <= 1 then
                "Utilisateur vérifié"

            else
                "Utilisateurs vérifiés"



actionsLeaveCapsule : Lang -> String
actionsLeaveCapsule lang =
    case lang of
        Lang.EnUs ->
            "Leave capsule"

        Lang.FrFr ->
            "Ne plus participer à la capsule"


actionsAddCapsule : Lang -> String
actionsAddCapsule lang =
    case lang of
        Lang.EnUs ->
            "Add capsule"

        Lang.FrFr ->
            "Ajouter une capsule"


stepsProductionProducingVideo : Lang -> String
stepsProductionProducingVideo lang =
    case lang of
        Lang.EnUs ->
            "Currently producing video"

        Lang.FrFr ->
            "Production de la vidéo en cours"


actionsEditPrompt : Lang -> String
actionsEditPrompt lang =
    case lang of
        Lang.EnUs ->
            "Edit prompt text"

        Lang.FrFr ->
            "Éditer le texte du prompteur"


actionsDeleteCapsule : Lang -> String
actionsDeleteCapsule lang =
    case lang of
        Lang.EnUs ->
            "Delete capsule"

        Lang.FrFr ->
            "Supprimer la capsule"


uiProfileChangePassword : Lang -> String
uiProfileChangePassword lang =
    case lang of
        Lang.EnUs ->
            "Password"

        Lang.FrFr ->
            "Password"


stepsAcquisitionStopRecord : Lang -> String
stepsAcquisitionStopRecord lang =
    case lang of
        Lang.EnUs ->
            "Stop playing record"

        Lang.FrFr ->
            "Arrêter la lecture"


dataCapsuleProduced : Lang -> Int -> String
dataCapsuleProduced lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "Produced"

            else
                "Produced"


        Lang.FrFr ->
            if n <= 1 then
                "Produite"

            else
                "Produites"



adminDashboard : Lang -> String
adminDashboard lang =
    case lang of
        Lang.EnUs ->
            "Dashboard"

        Lang.FrFr ->
            "Tableau de bord"


stepsOptionsNoTrack : Lang -> String
stepsOptionsNoTrack lang =
    case lang of
        Lang.EnUs ->
            "No track"

        Lang.FrFr ->
            "Pas de musique"


navigationClickHereToGoBackHome : Lang -> String
navigationClickHereToGoBackHome lang =
    case lang of
        Lang.EnUs ->
            "Click here to go back home"

        Lang.FrFr ->
            "Cliquer ici pour retourner à l'accueil"


stepsAcquisitionErrorBindingWebcam : Lang -> String
stepsAcquisitionErrorBindingWebcam lang =
    case lang of
        Lang.EnUs ->
            "Error binding devices"

        Lang.FrFr ->
            "Erreur lors de la connexion aux périphériques"


uiProfileProjectsAndCapsules : Lang -> String
uiProfileProjectsAndCapsules lang =
    case lang of
        Lang.EnUs ->
            "Projects and capsules"

        Lang.FrFr ->
            "Projets et capsules"


stepsAcquisitionHelpThird : Lang -> String
stepsAcquisitionHelpThird lang =
    case lang of
        Lang.EnUs ->
            "If you have multiple slides in the grain, the right arrow will go through the slides of the grain"

        Lang.FrFr ->
            "Si votre grain contient plusieurs planches, la flèche à droite vous permet de progresser de planche en planche"


uiOf : Lang -> String
uiOf lang =
    case lang of
        Lang.EnUs ->
            "of"

        Lang.FrFr ->
            "sur"


uiInfo : Lang -> String
uiInfo lang =
    case lang of
        Lang.EnUs ->
            "Information"

        Lang.FrFr ->
            "Information"


tasksImportCapsule : Lang -> String
tasksImportCapsule lang =
    case lang of
        Lang.EnUs ->
            "Capsule import"

        Lang.FrFr ->
            "Import capsule"


loginConfirmDeleteAccount : Lang -> String
loginConfirmDeleteAccount lang =
    case lang of
        Lang.EnUs ->
            "All your capsules will be deleted, and the published videos will no longer be accessible"

        Lang.FrFr ->
            "Toutes vos capsules seront supprimées, et les vidéos publiées ne seront plus accessibles"


stepsPreparationNewProject : Lang -> String
stepsPreparationNewProject lang =
    case lang of
        Lang.EnUs ->
            "New project"

        Lang.FrFr ->
            "Nouveau projet"


deviceDisabled : Lang -> String
deviceDisabled lang =
    case lang of
        Lang.EnUs ->
            "Disabled"

        Lang.FrFr ->
            "Désactivé"


stepsPreparationSelectProject : Lang -> String
stepsPreparationSelectProject lang =
    case lang of
        Lang.EnUs ->
            "Select a project"

        Lang.FrFr ->
            "Choisir un projet"


stepsAcquisitionHelpFourth : Lang -> String
stepsAcquisitionHelpFourth lang =
    case lang of
        Lang.EnUs ->
            "You can then use the right arrow to end your recording"

        Lang.FrFr ->
            "Vous pouvez ensuite appuyez sur la flèche à droite pour terminer l'enregistrement"


navigationNotFound : Lang -> String
navigationNotFound lang =
    case lang of
        Lang.EnUs ->
            "The page you requested was not found"

        Lang.FrFr ->
            "La page que vous demandez n'a pas été trouvée"


stepsAcquisitionHelpSecond : Lang -> String
stepsAcquisitionHelpSecond lang =
    case lang of
        Lang.EnUs ->
            "If you have a prompt, the right arrow will go through the lines of the prompt"

        Lang.FrFr ->
            "Si vous avez un prompteur, la flèche à droite vous permet de progresser de ligne en ligne"


dateMonthAugust : Lang -> String
dateMonthAugust lang =
    case lang of
        Lang.EnUs ->
            "August"

        Lang.FrFr ->
            "Août"


stepsAcquisitionSavedRecord : Lang -> String
stepsAcquisitionSavedRecord lang =
    case lang of
        Lang.EnUs ->
            "Saved record"

        Lang.FrFr ->
            "Enregistrement sauvegardé"


uiNoWebSocketWillCauseProblems : Lang -> String
uiNoWebSocketWillCauseProblems lang =
    case lang of
        Lang.EnUs ->
            "If the websocket is not working, Polymny Studio won't work correctly"

        Lang.FrFr ->
            "Si la connexion au websocket ne fonctionne pas, l'application ne fonctionnera pas correctement"


uiLoading : Lang -> String
uiLoading lang =
    case lang of
        Lang.EnUs ->
            "Loading"

        Lang.FrFr ->
            "Chargement en cours"


loginUsernameOrEmail : Lang -> String
loginUsernameOrEmail lang =
    case lang of
        Lang.EnUs ->
            "Username or e-mail address"

        Lang.FrFr ->
            "Nom d'utilisateur ou adresse e-mail"


uiStorage : Lang -> String
uiStorage lang =
    case lang of
        Lang.EnUs ->
            "Storage"

        Lang.FrFr ->
            "Stockage"


dataProjectRenameProject : Lang -> String
dataProjectRenameProject lang =
    case lang of
        Lang.EnUs ->
            "Rename project"

        Lang.FrFr ->
            "Renommer le projet"


stepsPreparationDashedLineExplanation : Lang -> String
stepsPreparationDashedLineExplanation lang =
    case lang of
        Lang.EnUs ->
            "Slides separated by a dashed line will be recorded in one go"

        Lang.FrFr ->
            "Les planches séparées par des pointillets seront filmées en une fois"


stepsPreparationDeleteResource : Lang -> String
stepsPreparationDeleteResource lang =
    case lang of
        Lang.EnUs ->
            "Delete resource"

        Lang.FrFr ->
            "Supprimer la ressource"


actionsConfirmRenameProjectWarning : Lang -> String
actionsConfirmRenameProjectWarning lang =
    case lang of
        Lang.EnUs ->
            "Renaming a project renames all its capsules of which you have to write access."

        Lang.FrFr ->
            "Renommer un projet renomme toutes les capsules qui y sont liées dont vous avez le droit de modification."


adminUsers : Lang -> String
adminUsers lang =
    case lang of
        Lang.EnUs ->
            "Users"

        Lang.FrFr ->
            "Utilisateurs"


stepsAcquisitionValidateRecord : Lang -> String
stepsAcquisitionValidateRecord lang =
    case lang of
        Lang.EnUs ->
            "Validate record"

        Lang.FrFr ->
            "Valider l'enregistrement"


stepsAcquisitionDetectingDevices : Lang -> String
stepsAcquisitionDetectingDevices lang =
    case lang of
        Lang.EnUs ->
            "Detecting devices"

        Lang.FrFr ->
            "Détection des périphériques en cours"


loginAcceptablePasswordComplexity : Lang -> String
loginAcceptablePasswordComplexity lang =
    case lang of
        Lang.EnUs ->
            "The complexity of the password is acceptable"

        Lang.FrFr ->
            "La complexité du mot de passe est acceptable"


loginTermsOfService : Lang -> String
loginTermsOfService lang =
    case lang of
        Lang.EnUs ->
            "Terms of service"

        Lang.FrFr ->
            "Conditions générales d'utilisation"


stepsAcquisitionBindingWebcam : Lang -> String
stepsAcquisitionBindingWebcam lang =
    case lang of
        Lang.EnUs ->
            "Binding webcam"

        Lang.FrFr ->
            "Connexion à la webcam en cours"


loginInsufficientPasswordComplexity : Lang -> String
loginInsufficientPasswordComplexity lang =
    case lang of
        Lang.EnUs ->
            "The complexity of the password is insufficient"

        Lang.FrFr ->
            "La complexité du mot de passe est insuffisante"


uiWarningConfirmDeleteProject : Lang -> String
uiWarningConfirmDeleteProject lang =
    case lang of
        Lang.EnUs ->
            "Do you really want to delete the project"

        Lang.FrFr ->
            "Voulez-vous vraiment supprimer le projet"


uiProfilePublished : Lang -> Int -> String
uiProfilePublished lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "Published capsule"

            else
                "Published capsules"


        Lang.FrFr ->
            if n <= 1 then
                "Capsule publiée"

            else
                "Capsules publiées"



stepsPreparationErrorUploadingPdf : Lang -> String
stepsPreparationErrorUploadingPdf lang =
    case lang of
        Lang.EnUs ->
            "An error occured while uploading PDF"

        Lang.FrFr ->
            "Une erreur est surevenue lors de l'envoi du PDF"


dataUserUsername : Lang -> String
dataUserUsername lang =
    case lang of
        Lang.EnUs ->
            "Username"

        Lang.FrFr ->
            "Nom d'utilisateur"


stepsPublicationPublishVideo : Lang -> String
stepsPublicationPublishVideo lang =
    case lang of
        Lang.EnUs ->
            "Publish video"

        Lang.FrFr ->
            "Publier la vidéo"


stepsConfigShare : Lang -> String
stepsConfigShare lang =
    case lang of
        Lang.EnUs ->
            "Share"

        Lang.FrFr ->
            "Partager"


stepsPublicationPrivacyPublic : Lang -> String
stepsPublicationPrivacyPublic lang =
    case lang of
        Lang.EnUs ->
            "Public"

        Lang.FrFr ->
            "Publique"


uiTranscoding : Lang -> String
uiTranscoding lang =
    case lang of
        Lang.EnUs ->
            "Transcoding"

        Lang.FrFr ->
            "Transcodage en cours"


stepsProductionWebcamPosition : Lang -> String
stepsProductionWebcamPosition lang =
    case lang of
        Lang.EnUs ->
            "Webcam position"

        Lang.FrFr ->
            "Position de la webcam"


stepsOptionsOptions : Lang -> String
stepsOptionsOptions lang =
    case lang of
        Lang.EnUs ->
            "Options"

        Lang.FrFr ->
            "Options"


navigationRecordGrain : Lang -> String
navigationRecordGrain lang =
    case lang of
        Lang.EnUs ->
            "Record this grain"

        Lang.FrFr ->
            "Enregistrer ce grain"


stepsProductionActivateKeying : Lang -> String
stepsProductionActivateKeying lang =
    case lang of
        Lang.EnUs ->
            "Activate keying"

        Lang.FrFr ->
            "Activer le keying"


stepsAcquisitionAreDevicesAuthorized : Lang -> String
stepsAcquisitionAreDevicesAuthorized lang =
    case lang of
        Lang.EnUs ->
            "Are the webcam and microphone authorized"

        Lang.FrFr ->
            "La webcam et le micro sont-ils bien autorisés"


introWelcomeOnPolymny : Lang -> String
introWelcomeOnPolymny lang =
    case lang of
        Lang.EnUs ->
            "Welcome on Polymny Studio"

        Lang.FrFr ->
            "Bienvenue sur Polymny Studio"


introNoProjectsYet : Lang -> String
introNoProjectsYet lang =
    case lang of
        Lang.EnUs ->
            "It looks like you have no projects yet"

        Lang.FrFr ->
            "On dirait que vous n'avez encore aucun projet"


stepsPreparationInsertNumberGreaterThanZero : Lang -> String
stepsPreparationInsertNumberGreaterThanZero lang =
    case lang of
        Lang.EnUs ->
            "Insert a number greater than zero"

        Lang.FrFr ->
            "Entrez un numéro de page plus grand que zéro"


stepsProductionLarge : Lang -> String
stepsProductionLarge lang =
    case lang of
        Lang.EnUs ->
            "Large"

        Lang.FrFr ->
            "Grande"


uiProfileDeleteAccount : Lang -> String
uiProfileDeleteAccount lang =
    case lang of
        Lang.EnUs ->
            "Delete account"

        Lang.FrFr ->
            "Supprimer le compte"


stepsPreparationReplaceSlideOrAddExternalResource : Lang -> String
stepsPreparationReplaceSlideOrAddExternalResource lang =
    case lang of
        Lang.EnUs ->
            "Replace slide / add external resource"

        Lang.FrFr ->
            "Remplacer la planche / ajouter une ressource externe"


actionsRenameProject : Lang -> String
actionsRenameProject lang =
    case lang of
        Lang.EnUs ->
            "Rename project"

        Lang.FrFr ->
            "Renommer le projet"


dataCapsuleSlide : Lang -> Int -> String
dataCapsuleSlide lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "Slide"

            else
                "Slides"


        Lang.FrFr ->
            if n <= 1 then
                "Planche"

            else
                "Planches"



dataCapsuleRoleOwner : Lang -> String
dataCapsuleRoleOwner lang =
    case lang of
        Lang.EnUs ->
            "Owner"

        Lang.FrFr ->
            "Propriétaire"


tasksExportCapsule : Lang -> String
tasksExportCapsule lang =
    case lang of
        Lang.EnUs ->
            "Capsule export"

        Lang.FrFr ->
            "Export capsule"


configSource : Lang -> String
configSource lang =
    case lang of
        Lang.EnUs ->
            "Source"

        Lang.FrFr ->
            "Source"


stepsProductionKeyColor : Lang -> String
stepsProductionKeyColor lang =
    case lang of
        Lang.EnUs ->
            "Key color"

        Lang.FrFr ->
            "Couleur de keying"


stepsPublicationPublication : Lang -> String
stepsPublicationPublication lang =
    case lang of
        Lang.EnUs ->
            "Publication"

        Lang.FrFr ->
            "Publication"


stepsProductionVideoNotProduced : Lang -> String
stepsProductionVideoNotProduced lang =
    case lang of
        Lang.EnUs ->
            "Video has not been produced yet"

        Lang.FrFr ->
            "La vidéo n'a pas encore été produite"


dateMonthMay : Lang -> String
dateMonthMay lang =
    case lang of
        Lang.EnUs ->
            "May"

        Lang.FrFr ->
            "Mai"


navigationNext : Lang -> String
navigationNext lang =
    case lang of
        Lang.EnUs ->
            "Next"

        Lang.FrFr ->
            "Suivant"


stepsPreparationCreateNewProject : Lang -> String
stepsPreparationCreateNewProject lang =
    case lang of
        Lang.EnUs ->
            "Create a new project"

        Lang.FrFr ->
            "Créer un nouveau projet"


stepsProductionCantUserVideoBecauseAudioOnly : Lang -> String
stepsProductionCantUserVideoBecauseAudioOnly lang =
    case lang of
        Lang.EnUs ->
            "You cannot use the video because the record only contains audio"

        Lang.FrFr ->
            "Vous ne pouvez pas incruster la vidéo car l'enregistrement ne contient que de l'audio"


dataCapsuleProgress : Lang -> String
dataCapsuleProgress lang =
    case lang of
        Lang.EnUs ->
            "Progress"

        Lang.FrFr ->
            "Progression"


dataCapsuleHashid : Lang -> String
dataCapsuleHashid lang =
    case lang of
        Lang.EnUs ->
            "Hash id"

        Lang.FrFr ->
            "Hash id"


stepsConfigShareWith : Lang -> String
stepsConfigShareWith lang =
    case lang of
        Lang.EnUs ->
            "Share the capsule with"

        Lang.FrFr ->
            "Partager la capsule avec"


uiError : Lang -> String
uiError lang =
    case lang of
        Lang.EnUs ->
            "Error"

        Lang.FrFr ->
            "Erreur"


uiUploading : Lang -> String
uiUploading lang =
    case lang of
        Lang.EnUs ->
            "Uploading"

        Lang.FrFr ->
            "Envoi en cours"


uiGB : Lang -> String
uiGB lang =
    case lang of
        Lang.EnUs ->
            "GB"

        Lang.FrFr ->
            "Go"


loginAcceptTermsOfService : Lang -> String
loginAcceptTermsOfService lang =
    case lang of
        Lang.EnUs ->
            "I read and accept the terms of service"

        Lang.FrFr ->
            "J'ai lu et j'accepte les conditions générales d'utilisation"


uiTasksNone : Lang -> String
uiTasksNone lang =
    case lang of
        Lang.EnUs ->
            "No tasks"

        Lang.FrFr ->
            "Pas de tâche en cours"


uiConfirm : Lang -> String
uiConfirm lang =
    case lang of
        Lang.EnUs ->
            "Confirm"

        Lang.FrFr ->
            "Valider"


loginNotRegisteredYet : Lang -> String
loginNotRegisteredYet lang =
    case lang of
        Lang.EnUs ->
            "Not registered yet"

        Lang.FrFr ->
            "Pas encore inscrit"


dataCapsuleLastModification : Lang -> String
dataCapsuleLastModification lang =
    case lang of
        Lang.EnUs ->
            "Last modification"

        Lang.FrFr ->
            "Dernière modification"


stepsAcquisitionRecord : Lang -> String
stepsAcquisitionRecord lang =
    case lang of
        Lang.EnUs ->
            "Record"

        Lang.FrFr ->
            "Enregistrer"


uiGoBackToOldClient : Lang -> String
uiGoBackToOldClient lang =
    case lang of
        Lang.EnUs ->
            "Go back to the old version"

        Lang.FrFr ->
            "Retourner à l'ancienne version"


loginSubscribedToTheNewsletter : Lang -> String
loginSubscribedToTheNewsletter lang =
    case lang of
        Lang.EnUs ->
            "Subsribed to the newsletter"

        Lang.FrFr ->
            "Inscrit à la newsletter"


stepsAcquisitionDeleteRecord : Lang -> String
stepsAcquisitionDeleteRecord lang =
    case lang of
        Lang.EnUs ->
            "Delete saved record"

        Lang.FrFr ->
            "Supprimer le record enregistré"


stepsPublicationPrivacyExplainPrivate : Lang -> String
stepsPublicationPrivacyExplainPrivate lang =
    case lang of
        Lang.EnUs ->
            "The video will be visible only by explicitly authorized users"

        Lang.FrFr ->
            "La vidéo ne sera visible que par les utilisateurs explicitement autorisés"


stepsProductionBottomRight : Lang -> String
stepsProductionBottomRight lang =
    case lang of
        Lang.EnUs ->
            "Bottom right corner"

        Lang.FrFr ->
            "En bas à droite"


actionsDeleteExtra : Lang -> String
actionsDeleteExtra lang =
    case lang of
        Lang.EnUs ->
            "Delete extra"

        Lang.FrFr ->
            "Supprimer l'extra"


deviceResolution : Lang -> String
deviceResolution lang =
    case lang of
        Lang.EnUs ->
            "Resolution"

        Lang.FrFr ->
            "Résolution"


stepsProductionProduceGrain : Lang -> String
stepsProductionProduceGrain lang =
    case lang of
        Lang.EnUs ->
            "Produce grain"

        Lang.FrFr ->
            "Produire le grain"


dateMonthApril : Lang -> String
dateMonthApril lang =
    case lang of
        Lang.EnUs ->
            "April"

        Lang.FrFr ->
            "Avril"


loginDriveSpace : Lang -> String
loginDriveSpace lang =
    case lang of
        Lang.EnUs ->
            "Drive space"

        Lang.FrFr ->
            "Espace de stockage"


actionsConfirmDeleteProject : Lang -> String
actionsConfirmDeleteProject lang =
    case lang of
        Lang.EnUs ->
            "Do you really want to delete this project"

        Lang.FrFr ->
            "Voulez vous vraiment supprimer le projet"


stepsAcquisitionInvertSlideAndPrompt : Lang -> String
stepsAcquisitionInvertSlideAndPrompt lang =
    case lang of
        Lang.EnUs ->
            "Invert slide and prompt"

        Lang.FrFr ->
            "Inverser la planche et le prompteur"


loginIncorrectEmailAddress : Lang -> String
loginIncorrectEmailAddress lang =
    case lang of
        Lang.EnUs ->
            "The e-mail address is incorrect"

        Lang.FrFr ->
            "L'adresse e-mail est erronée"


tasksUploadTrack : Lang -> String
tasksUploadTrack lang =
    case lang of
        Lang.EnUs ->
            "Upload track"

        Lang.FrFr ->
            "Téléversement de la musique de fond"


tasksTranscodeExtra : Lang -> String
tasksTranscodeExtra lang =
    case lang of
        Lang.EnUs ->
            "Transcode extra"

        Lang.FrFr ->
            "Transcodage de resources externes"


dataUserNewEmailAddress : Lang -> String
dataUserNewEmailAddress lang =
    case lang of
        Lang.EnUs ->
            "New e-mail address"

        Lang.FrFr ->
            "Nouvelle adresse e-mail"


stepsAcquisitionRecordingStopped : Lang -> String
stepsAcquisitionRecordingStopped lang =
    case lang of
        Lang.EnUs ->
            "Recording stopped"

        Lang.FrFr ->
            "Enregistrement arrété"


stepsProductionCancelProduction : Lang -> String
stepsProductionCancelProduction lang =
    case lang of
        Lang.EnUs ->
            "Cancel production"

        Lang.FrFr ->
            "Annuler la production"


dataUserCurrentEmailAddress : Lang -> String
dataUserCurrentEmailAddress lang =
    case lang of
        Lang.EnUs ->
            "Current e-mail address"

        Lang.FrFr ->
            "Adresse e-mail actuelle"


dataUserPassword : Lang -> String
dataUserPassword lang =
    case lang of
        Lang.EnUs ->
            "Password"

        Lang.FrFr ->
            "Mot de passe"


stepsAcquisitionNonValidatedRecordsWillBeLost : Lang -> String
stepsAcquisitionNonValidatedRecordsWillBeLost lang =
    case lang of
        Lang.EnUs ->
            "Non validated records will be lost"

        Lang.FrFr ->
            "Les enregistrements non validés seront perdus"


stepsProductionResetOptions : Lang -> String
stepsProductionResetOptions lang =
    case lang of
        Lang.EnUs ->
            "Reset options"

        Lang.FrFr ->
            "Réinitialiser les options"


stepsPreparationMaybePageNumberIsIncorrect : Lang -> String
stepsPreparationMaybePageNumberIsIncorrect lang =
    case lang of
        Lang.EnUs ->
            "An error occured while changing the slide, maybe the page number is incorrect"

        Lang.FrFr ->
            "Une erreur est survenue lors du changement de la planche, peut-être que le numéro de page est incorrect"


loginDiskUsage : Lang -> String
loginDiskUsage lang =
    case lang of
        Lang.EnUs ->
            "Size"

        Lang.FrFr ->
            "Taille"


stepsProductionBottomLeft : Lang -> String
stepsProductionBottomLeft lang =
    case lang of
        Lang.EnUs ->
            "Bottom left corner"

        Lang.FrFr ->
            "En bas à gauche"


uiProfile : Lang -> String
uiProfile lang =
    case lang of
        Lang.EnUs ->
            "Profile"

        Lang.FrFr ->
            "Profil"


stepsAcquisitionErrorDetectingDevices : Lang -> String
stepsAcquisitionErrorDetectingDevices lang =
    case lang of
        Lang.EnUs ->
            "Error detecting devices"

        Lang.FrFr ->
            "Erreur lors de la détection les périphériques"


adminDeleteUserConfirm : Lang -> String
adminDeleteUserConfirm lang =
    case lang of
        Lang.EnUs ->
            "Do you really want to delete the user"

        Lang.FrFr ->
            "Voulez-vous vraiment supprimer l'utilisateur"


stepsProductionCantUseVideoBecauseNoRecord : Lang -> String
stepsProductionCantUseVideoBecauseNoRecord lang =
    case lang of
        Lang.EnUs ->
            "You cannot use the video because there is no record for this grain"

        Lang.FrFr ->
            "Vous ne pouvez pas incruster la vidéo car il n'y a aucun enregistrement pour ce grain"


introAfterSlidesUploadYouCanRecord : Lang -> String
introAfterSlidesUploadYouCanRecord lang =
    case lang of
        Lang.EnUs ->
            "Once the slides have been uploaded, the recording can start"

        Lang.FrFr ->
            "Une fois la présentation téléchargée, l'enregistrement vidéo des planches pourra débuter"


actionsRenameCapsule : Lang -> String
actionsRenameCapsule lang =
    case lang of
        Lang.EnUs ->
            "Rename capsule"

        Lang.FrFr ->
            "Renommer la capsule"


loginNewPassword : Lang -> String
loginNewPassword lang =
    case lang of
        Lang.EnUs ->
            "New password"

        Lang.FrFr ->
            "Nouveau mot de passe"


dataProjectDeleteProject : Lang -> String
dataProjectDeleteProject lang =
    case lang of
        Lang.EnUs ->
            "Delete project"

        Lang.FrFr ->
            "Supprimer le projet"


loginMailSent : Lang -> String
loginMailSent lang =
    case lang of
        Lang.EnUs ->
            "An e-mail has been sent to you"

        Lang.FrFr ->
            "Un e-mail vous a été envoyé"


dataCapsuleRoleWrite : Lang -> String
dataCapsuleRoleWrite lang =
    case lang of
        Lang.EnUs ->
            "Write"

        Lang.FrFr ->
            "Écriture"


stepsPublicationCopyVideoUrl : Lang -> String
stepsPublicationCopyVideoUrl lang =
    case lang of
        Lang.EnUs ->
            "Copy video URL"

        Lang.FrFr ->
            "Copier l'URL de la vidéo"


loginUsernameAtLeastThreeCharacters : Lang -> String
loginUsernameAtLeastThreeCharacters lang =
    case lang of
        Lang.EnUs ->
            "The username must have at least three characters"

        Lang.FrFr ->
            "Le nom d'utilisateur doit contenir au moins trois caractères"


configLicense : Lang -> String
configLicense lang =
    case lang of
        Lang.EnUs ->
            "License GNU Affero V3"

        Lang.FrFr ->
            "Licence GNU Affero V3"


configLang : Lang -> String
configLang lang =
    case lang of
        Lang.EnUs ->
            "Lang"

        Lang.FrFr ->
            "Langue"


uiProfileChangeEmail : Lang -> String
uiProfileChangeEmail lang =
    case lang of
        Lang.EnUs ->
            "Change email"

        Lang.FrFr ->
            "Adresse email"


adminInviteUser : Lang -> String
adminInviteUser lang =
    case lang of
        Lang.EnUs ->
            "Invite a user"

        Lang.FrFr ->
            "Inviter un utilisateur"


deviceMicrophone : Lang -> String
deviceMicrophone lang =
    case lang of
        Lang.EnUs ->
            "Microphone"

        Lang.FrFr ->
            "Microphone"


uiIconIndicatesWebSocketBroken : Lang -> String
uiIconIndicatesWebSocketBroken lang =
    case lang of
        Lang.EnUs ->
            "This icon indicates that the websocket is disconnected"

        Lang.FrFr ->
            "Cette icone indique que le websocket est déconnecté"


stepsProductionDownloadVideo : Lang -> String
stepsProductionDownloadVideo lang =
    case lang of
        Lang.EnUs ->
            "Download video"

        Lang.FrFr ->
            "Télécharger la vidéo"


loginLogin : Lang -> String
loginLogin lang =
    case lang of
        Lang.EnUs ->
            "Login"

        Lang.FrFr ->
            "Se connecter"


dataCapsuleCapsuleNumber : Lang -> String
dataCapsuleCapsuleNumber lang =
    case lang of
        Lang.EnUs ->
            "Capsule number"

        Lang.FrFr ->
            "Nombre de capsules"


navigationClose : Lang -> String
navigationClose lang =
    case lang of
        Lang.EnUs ->
            "Close"

        Lang.FrFr ->
            "Fermer"


stepsPublicationPublish : Lang -> String
stepsPublicationPublish lang =
    case lang of
        Lang.EnUs ->
            "Publish"

        Lang.FrFr ->
            "Publier"


loginCurrentPassword : Lang -> String
loginCurrentPassword lang =
    case lang of
        Lang.EnUs ->
            "Current password"

        Lang.FrFr ->
            "Mot de passe actuel"


loginPasswordTooShort : Lang -> String
loginPasswordTooShort lang =
    case lang of
        Lang.EnUs ->
            "The password must contain at least 6 characters"

        Lang.FrFr ->
            "Le mot de passe doit contenir au moins 6 caractères"


uiWebSocketNotWorking : Lang -> String
uiWebSocketNotWorking lang =
    case lang of
        Lang.EnUs ->
            "The websocket is disconnected"

        Lang.FrFr ->
            "Le websocket est déconnecté"


dataCapsuleLine : Lang -> Int -> String
dataCapsuleLine lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "Line"

            else
                "Lines"


        Lang.FrFr ->
            if n <= 1 then
                "Ligne"

            else
                "Lignes"



loginNoSuchEmail : Lang -> String
loginNoSuchEmail lang =
    case lang of
        Lang.EnUs ->
            "This e-mail address does not belong to any account"

        Lang.FrFr ->
            "Cette adresse e-mail n'est associée à aucun compte"


loginLogout : Lang -> String
loginLogout lang =
    case lang of
        Lang.EnUs ->
            "Logout"

        Lang.FrFr ->
            "Se déconnecter"


tasksUploadExtra : Lang -> String
tasksUploadExtra lang =
    case lang of
        Lang.EnUs ->
            "Upload extra"

        Lang.FrFr ->
            "Téléversement de resources externes"


loginAccountActivated : Lang -> String
loginAccountActivated lang =
    case lang of
        Lang.EnUs ->
            "Your account has been successfulylly activated"

        Lang.FrFr ->
            "Votre compte a été activé"


uiProfileUsername : Lang -> String
uiProfileUsername lang =
    case lang of
        Lang.EnUs ->
            "Username"

        Lang.FrFr ->
            "Nom d'utilisateur"


navigationSettings : Lang -> String
navigationSettings lang =
    case lang of
        Lang.EnUs ->
            "Settings"

        Lang.FrFr ->
            "Paramètres"


stepsPublicationCancelPublication : Lang -> String
stepsPublicationCancelPublication lang =
    case lang of
        Lang.EnUs ->
            "Cancel publication"

        Lang.FrFr ->
            "Annuler la publication"


dataCapsuleCapsuleName : Lang -> String
dataCapsuleCapsuleName lang =
    case lang of
        Lang.EnUs ->
            "Capsule name"

        Lang.FrFr ->
            "Nom de la capsule"


stepsPreparationReplaceSlide : Lang -> String
stepsPreparationReplaceSlide lang =
    case lang of
        Lang.EnUs ->
            "Replace slide"

        Lang.FrFr ->
            "Remplacer la planche"


stepsPreparationAddSlide : Lang -> String
stepsPreparationAddSlide lang =
    case lang of
        Lang.EnUs ->
            "Add slide"

        Lang.FrFr ->
            "Ajouter une planche"


stepsProductionUseVideo : Lang -> String
stepsProductionUseVideo lang =
    case lang of
        Lang.EnUs ->
            "Use video"

        Lang.FrFr ->
            "Incruster la vidéo"


stepsPublicationPrivacyPrivacySettings : Lang -> String
stepsPublicationPrivacyPrivacySettings lang =
    case lang of
        Lang.EnUs ->
            "Privacy settings"

        Lang.FrFr ->
            "Paramètres de confidentialité"


introToStartYouNeedToUploadPdf : Lang -> String
introToStartYouNeedToUploadPdf lang =
    case lang of
        Lang.EnUs ->
            "To start recording, you need to choose a PDF slides from your computer"

        Lang.FrFr ->
            "Pour commencer un enregistrement, il faut choisir une présentation au format PDF sur votre machine"


stepsProductionCurrentProducedVideo : Lang -> String
stepsProductionCurrentProducedVideo lang =
    case lang of
        Lang.EnUs ->
            "Current produced video"

        Lang.FrFr ->
            "Vidéo produite actuelle"


loginPasswordsDontMatch : Lang -> String
loginPasswordsDontMatch lang =
    case lang of
        Lang.EnUs ->
            "The two passwords don't match"

        Lang.FrFr ->
            "Les deux mots de passe ne correspondent pas"


stepsPublicationPrivacyExplainUnlisted : Lang -> String
stepsPublicationPrivacyExplainUnlisted lang =
    case lang of
        Lang.EnUs ->
            "The video will be visible by anyone who knows the URL, Polymny Studio will not share the video's URL"

        Lang.FrFr ->
            "La vidéo ne sera visible que par les personnes connaissant l'URL, Polymny Studio ne partagera pas l'URL de la vidéo"


loginSignUpForTheNewsletter : Lang -> String
loginSignUpForTheNewsletter lang =
    case lang of
        Lang.EnUs ->
            "I sign up to the newsletter"

        Lang.FrFr ->
            "Je m'inscris à la newsletter"


stepsConfigPeople : Lang -> String
stepsConfigPeople lang =
    case lang of
        Lang.EnUs ->
            "People"

        Lang.FrFr ->
            "Collaborateurs"


adminEditUser : Lang -> String
adminEditUser lang =
    case lang of
        Lang.EnUs ->
            "Edit user"

        Lang.FrFr ->
            "Éditer l'utilisateur"


loginForgottenPassword : Lang -> String
loginForgottenPassword lang =
    case lang of
        Lang.EnUs ->
            "Forgotten password"

        Lang.FrFr ->
            "Mot de passe oublié"


loginWrongPassword : Lang -> String
loginWrongPassword lang =
    case lang of
        Lang.EnUs ->
            "The password is incorrect"

        Lang.FrFr ->
            "Le mot de passe est incorrect"


stepsPreparationGoToNextSlide : Lang -> String
stepsPreparationGoToNextSlide lang =
    case lang of
        Lang.EnUs ->
            "Go to the next slide"

        Lang.FrFr ->
            "Aller à la planche suivante"


stepsProductionMedium : Lang -> String
stepsProductionMedium lang =
    case lang of
        Lang.EnUs ->
            "Medium"

        Lang.FrFr ->
            "Moyenne"


stepsAcquisitionPlayRecord : Lang -> String
stepsAcquisitionPlayRecord lang =
    case lang of
        Lang.EnUs ->
            "Play record"

        Lang.FrFr ->
            "Lire l'enregistrement"


stepsProductionFullscreen : Lang -> String
stepsProductionFullscreen lang =
    case lang of
        Lang.EnUs ->
            "Fullscreen"

        Lang.FrFr ->
            "Plein écran"


actionsGoToPreviousSlide : Lang -> String
actionsGoToPreviousSlide lang =
    case lang of
        Lang.EnUs ->
            "Go to the previous slide"

        Lang.FrFr ->
            "Aller à la planche précédente"


uiHelp : Lang -> String
uiHelp lang =
    case lang of
        Lang.EnUs ->
            "Help"

        Lang.FrFr ->
            "Aide"


dateMonthSeptember : Lang -> String
dateMonthSeptember lang =
    case lang of
        Lang.EnUs ->
            "September"

        Lang.FrFr ->
            "Septembre"


loginMustAcceptTermsOfService : Lang -> String
loginMustAcceptTermsOfService lang =
    case lang of
        Lang.EnUs ->
            "You must accept the terms of service"

        Lang.FrFr ->
            "Vous devez accepter les conditions générales d'utilisation"


dataUserEmailAddress : Lang -> String
dataUserEmailAddress lang =
    case lang of
        Lang.EnUs ->
            "E-mail address"

        Lang.FrFr ->
            "Adresse e-mail"


stepsPublicationPrivacyExplainPublic : Lang -> String
stepsPublicationPrivacyExplainPublic lang =
    case lang of
        Lang.EnUs ->
            "The video will be visible by anyone who knows the URL, Polymny Studio may, in the future, share the video's URL via a search engine, a recommendation system, etc"

        Lang.FrFr ->
            "La vidéo sera visible par les personnes connaissant l'URL, Polymny Studio pourrait, dans le futur, partager l'URL de la vidéo via un moteur de recherche, un système de recommandations, etc"


dateMonthJune : Lang -> String
dateMonthJune lang =
    case lang of
        Lang.EnUs ->
            "June"

        Lang.FrFr ->
            "Juin"


stepsOptionsSoundTrack : Lang -> String
stepsOptionsSoundTrack lang =
    case lang of
        Lang.EnUs ->
            "Sound track"

        Lang.FrFr ->
            "Musique de fond"


actionsConfirmDeleteProjectWarning : Lang -> String
actionsConfirmDeleteProjectWarning lang =
    case lang of
        Lang.EnUs ->
            "Deleting a project deletes all its capsules or unsubscribe you from them."

        Lang.FrFr ->
            "Supprimer un projet supprime toutes les capsules qui y sont liées ou vous désabonne de celles-ci."


dataCapsuleProject : Lang -> Int -> String
dataCapsuleProject lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "Project"

            else
                "Projects"


        Lang.FrFr ->
            if n <= 1 then
                "Projet"

            else
                "Projets"



stepsAcquisitionStartRecording : Lang -> String
stepsAcquisitionStartRecording lang =
    case lang of
        Lang.EnUs ->
            "Start recording"

        Lang.FrFr ->
            "Démarrer l'enregistrement"


stepsPublicationPrivacyPrivate : Lang -> String
stepsPublicationPrivacyPrivate lang =
    case lang of
        Lang.EnUs ->
            "Private"

        Lang.FrFr ->
            "Privée"


stepsAcquisitionRecordList : Lang -> Int -> String
stepsAcquisitionRecordList lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "Record"

            else
                "Records"


        Lang.FrFr ->
            if n <= 1 then
                "Enregistrement"

            else
                "Enregistrements"



stepsOptionsReplaceTrack : Lang -> String
stepsOptionsReplaceTrack lang =
    case lang of
        Lang.EnUs ->
            "Replace sound track"

        Lang.FrFr ->
            "Remplacer la musique de fond"


stepsAcquisitionIsWebcamUsed : Lang -> String
stepsAcquisitionIsWebcamUsed lang =
    case lang of
        Lang.EnUs ->
            "Is the webcam used by another software"

        Lang.FrFr ->
            "La webcam est-elle utilisée par un autre logiciel"


stepsProductionOpacity : Lang -> String
stepsProductionOpacity lang =
    case lang of
        Lang.EnUs ->
            "Opacity"

        Lang.FrFr ->
            "Opacité"


actionsExportCapsule : Lang -> String
actionsExportCapsule lang =
    case lang of
        Lang.EnUs ->
            "Export capsule"

        Lang.FrFr ->
            "Exporter la capsule"


actionsDeleteRecord : Lang -> String
actionsDeleteRecord lang =
    case lang of
        Lang.EnUs ->
            "Delete record"

        Lang.FrFr ->
            "Supprimer l'enregistrement"


loginRepeatPassword : Lang -> String
loginRepeatPassword lang =
    case lang of
        Lang.EnUs ->
            "Repeat password"

        Lang.FrFr ->
            "Répétez le mot de passe"


stepsPreparationPrepare : Lang -> String
stepsPreparationPrepare lang =
    case lang of
        Lang.EnUs ->
            "Prepare"

        Lang.FrFr ->
            "Préparer"


tasksPublicationCapsule : Lang -> String
tasksPublicationCapsule lang =
    case lang of
        Lang.EnUs ->
            "Publication"

        Lang.FrFr ->
            "Publication"


stepsPublicationPromptSubtitles : Lang -> String
stepsPublicationPromptSubtitles lang =
    case lang of
        Lang.EnUs ->
            "Use prompt to generate subtitles"

        Lang.FrFr ->
            "Utiliser le prompteur pour générer les sous-titres"


stepsPreparationOrganizeSlides : Lang -> String
stepsPreparationOrganizeSlides lang =
    case lang of
        Lang.EnUs ->
            "Organize slides"

        Lang.FrFr ->
            "Organiser les planches"


stepsAcquisitionReinitializeDevices : Lang -> String
stepsAcquisitionReinitializeDevices lang =
    case lang of
        Lang.EnUs ->
            "Reinitialize all devices"

        Lang.FrFr ->
            "Réinitialiser tous les périphériques"


loginLoginFailed : Lang -> String
loginLoginFailed lang =
    case lang of
        Lang.EnUs ->
            "Login failed"

        Lang.FrFr ->
            "Connexion echouée"


stepsPreparationDndWillBreak : Lang -> String
stepsPreparationDndWillBreak lang =
    case lang of
        Lang.EnUs ->
            "This change will destroy some of your records"

        Lang.FrFr ->
            "Ce déplacement va détruire certains de vos enregistrements"


stepsProductionProduce : Lang -> String
stepsProductionProduce lang =
    case lang of
        Lang.EnUs ->
            "Produce"

        Lang.FrFr ->
            "Produire"


tasksUnknown : Lang -> String
tasksUnknown lang =
    case lang of
        Lang.EnUs ->
            "Unknown task"

        Lang.FrFr ->
            "Tâche inconnue"


loginResetPassword : Lang -> String
loginResetPassword lang =
    case lang of
        Lang.EnUs ->
            "Reset password"

        Lang.FrFr ->
            "Réinitialiser mon mot de passe"


stepsProductionWebcamSize : Lang -> String
stepsProductionWebcamSize lang =
    case lang of
        Lang.EnUs ->
            "Webcam size"

        Lang.FrFr ->
            "Taille de la webcam"


actionsWatchCapsule : Lang -> String
actionsWatchCapsule lang =
    case lang of
        Lang.EnUs ->
            "Watch the capsule"

        Lang.FrFr ->
            "Regarder la vidéo"


navigationPrevious : Lang -> String
navigationPrevious lang =
    case lang of
        Lang.EnUs ->
            "Previous"

        Lang.FrFr ->
            "Précédent"


uiWarning : Lang -> String
uiWarning lang =
    case lang of
        Lang.EnUs ->
            "Warning"

        Lang.FrFr ->
            "Attention"


stepsOptionsPlayPreview : Lang -> String
stepsOptionsPlayPreview lang =
    case lang of
        Lang.EnUs ->
            "Play sound track preview"

        Lang.FrFr ->
            "Jouer un aperçu de la musique de fond"


loginPasswordChanged : Lang -> String
loginPasswordChanged lang =
    case lang of
        Lang.EnUs ->
            "Password changed"

        Lang.FrFr ->
            "Votre mot de passe a été changé"


stepsConfigExportCapsule : Lang -> String
stepsConfigExportCapsule lang =
    case lang of
        Lang.EnUs ->
            "Export capsule"

        Lang.FrFr ->
            "Exporter la capsule"


dateMonthJanuary : Lang -> String
dateMonthJanuary lang =
    case lang of
        Lang.EnUs ->
            "January"

        Lang.FrFr ->
            "Janvier"


dateMonthNovember : Lang -> String
dateMonthNovember lang =
    case lang of
        Lang.EnUs ->
            "November"

        Lang.FrFr ->
            "Novembre"


loginChangePassword : Lang -> String
loginChangePassword lang =
    case lang of
        Lang.EnUs ->
            "Change password"

        Lang.FrFr ->
            "Changer mon mot de passe"


loginGigabyte : Lang -> String
loginGigabyte lang =
    case lang of
        Lang.EnUs ->
            "GB"

        Lang.FrFr ->
            "Go"


dataCapsuleGrain : Lang -> Int -> String
dataCapsuleGrain lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "Grain"

            else
                "Grains"


        Lang.FrFr ->
            if n <= 1 then
                "Grain"

            else
                "Grains"



loginUnknownError : Lang -> String
loginUnknownError lang =
    case lang of
        Lang.EnUs ->
            "An unknown error occured"

        Lang.FrFr ->
            "Une erreur inconnue s'est produite"


actionsConfirmLeaveCapsule : Lang -> String
actionsConfirmLeaveCapsule lang =
    case lang of
        Lang.EnUs ->
            "Do you really want to leave this capsule"

        Lang.FrFr ->
            "Voulez vous vraiment ne plus participer à la capsule"


uiConnected : Lang -> String
uiConnected lang =
    case lang of
        Lang.EnUs ->
            "Connected"

        Lang.FrFr ->
            "Connecté"


loginAcceptTermsOfServiceBegining : Lang -> String
loginAcceptTermsOfServiceBegining lang =
    case lang of
        Lang.EnUs ->
            "I read and accept the"

        Lang.FrFr ->
            "J'ai lu et j'accepte les"


stepsProductionWatchGrain : Lang -> String
stepsProductionWatchGrain lang =
    case lang of
        Lang.EnUs ->
            "Watch grain"

        Lang.FrFr ->
            "Regarder le grain"


actionsZoomOut : Lang -> String
actionsZoomOut lang =
    case lang of
        Lang.EnUs ->
            "Zoom out"

        Lang.FrFr ->
            "Dézoomer"


stepsProductionKey : Lang -> String
stepsProductionKey lang =
    case lang of
        Lang.EnUs ->
            "Key"

        Lang.FrFr ->
            "Key"


actionsConfirmDeleteRecord : Lang -> String
actionsConfirmDeleteRecord lang =
    case lang of
        Lang.EnUs ->
            "Do you really want to delete this record"

        Lang.FrFr ->
            "Voulez vous vraiment supprimer l'enregistrement"


uiDisconnected : Lang -> String
uiDisconnected lang =
    case lang of
        Lang.EnUs ->
            "Disconnected"

        Lang.FrFr ->
            "Déconnecté"


stepsPublicationUnpublishVideo : Lang -> String
stepsPublicationUnpublishVideo lang =
    case lang of
        Lang.EnUs ->
            "Unpublish video"

        Lang.FrFr ->
            "Dépublier la vidéo"


dataCapsuleRoleRead : Lang -> String
dataCapsuleRoleRead lang =
    case lang of
        Lang.EnUs ->
            "Read"

        Lang.FrFr ->
            "Lecture"


stepsPreparationErrorConvertingPdf : Lang -> String
stepsPreparationErrorConvertingPdf lang =
    case lang of
        Lang.EnUs ->
            "An error occured while reading PDF"

        Lang.FrFr ->
            "Une erreur est survenue lors de la lecture du PDF"


stepsPublicationNotProducedYet : Lang -> String
stepsPublicationNotProducedYet lang =
    case lang of
        Lang.EnUs ->
            "Video has not been produced yet. You will be able to publish it once it is produced."

        Lang.FrFr ->
            "La vidéo n'a pas encore été produite. Vous pouvez la publier uniquement après sa production."


tasksUploadRecord : Lang -> String
tasksUploadRecord lang =
    case lang of
        Lang.EnUs ->
            "Upload record"

        Lang.FrFr ->
            "Téléversement de l'enregistrement"


dataProjectProjectName : Lang -> String
dataProjectProjectName lang =
    case lang of
        Lang.EnUs ->
            "Project name"

        Lang.FrFr ->
            "Nom du projet"


loginFormContainsError : Lang -> Int -> String
loginFormContainsError lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "The form contain an error"

            else
                "The form contains errors"


        Lang.FrFr ->
            if n <= 1 then
                "Le formulaire contient une erreur"

            else
                "Le formulaire contient des erreurs"



actionsConfirmDeleteTrack : Lang -> String
actionsConfirmDeleteTrack lang =
    case lang of
        Lang.EnUs ->
            "Do you really want to delete this track"

        Lang.FrFr ->
            "Voulez vous vraiment supprimer la musique de fond"


stepsPreparationGoToPreviousSlide : Lang -> String
stepsPreparationGoToPreviousSlide lang =
    case lang of
        Lang.EnUs ->
            "Go to the previous slide"

        Lang.FrFr ->
            "Aller à la planche précedente"


stepsAcquisitionAcquisition : Lang -> String
stepsAcquisitionAcquisition lang =
    case lang of
        Lang.EnUs ->
            "Acquisition"

        Lang.FrFr ->
            "Acquisition"


stepsProductionTopRight : Lang -> String
stepsProductionTopRight lang =
    case lang of
        Lang.EnUs ->
            "Top right corner"

        Lang.FrFr ->
            "En haut à droite"


stepsOptionsUploadTrack : Lang -> String
stepsOptionsUploadTrack lang =
    case lang of
        Lang.EnUs ->
            "Add a sound track"

        Lang.FrFr ->
            "Ajouter une musique de fond"


stepsPreparationCreateGrain : Lang -> String
stepsPreparationCreateGrain lang =
    case lang of
        Lang.EnUs ->
            "Create grain"

        Lang.FrFr ->
            "Créer un grain"


stepsPreparationEnterNewNameForCapsule : Lang -> String
stepsPreparationEnterNewNameForCapsule lang =
    case lang of
        Lang.EnUs ->
            "Enter a new name for the capsule"

        Lang.FrFr ->
            "Entrez un nouveau nom pour la capsule"


stepsAcquisitionHelpFirst : Lang -> String
stepsAcquisitionHelpFirst lang =
    case lang of
        Lang.EnUs ->
            "Use the right arrow on the keyboard to start recording"

        Lang.FrFr ->
            "Appuyez sur la flèche à droite pour commencer l'enregistrement"


stepsPublicationPrivacyUnlisted : Lang -> String
stepsPublicationPrivacyUnlisted lang =
    case lang of
        Lang.EnUs ->
            "Unlisted"

        Lang.FrFr ->
            "Non repértoriée"


adminDeleteUser : Lang -> String
adminDeleteUser lang =
    case lang of
        Lang.EnUs ->
            "Delete user"

        Lang.FrFr ->
            "Supprimer l'utilisateur"


actionsDeleteProject : Lang -> String
actionsDeleteProject lang =
    case lang of
        Lang.EnUs ->
            "Delete project"

        Lang.FrFr ->
            "Supprimer le projet"


stepsAcquisitionRefreshDeviceList : Lang -> String
stepsAcquisitionRefreshDeviceList lang =
    case lang of
        Lang.EnUs ->
            "Refresh device list"

        Lang.FrFr ->
            "Raffraîchir la liste des périphériques"


navigationGoToPolymny : Lang -> String
navigationGoToPolymny lang =
    case lang of
        Lang.EnUs ->
            "Go to Polymny"

        Lang.FrFr ->
            "Aller sur Polymny"


dateMonthOctober : Lang -> String
dateMonthOctober lang =
    case lang of
        Lang.EnUs ->
            "October"

        Lang.FrFr ->
            "Octobre"


stepsAcquisitionToggleMatting : Lang -> String
stepsAcquisitionToggleMatting lang =
    case lang of
        Lang.EnUs ->
            "Use virtual green screen"

        Lang.FrFr ->
            "Utiliser le fond vert virtuel"


dateMonthJuly : Lang -> String
dateMonthJuly lang =
    case lang of
        Lang.EnUs ->
            "July"

        Lang.FrFr ->
            "Juillet"


dataUserPlan : Lang -> String
dataUserPlan lang =
    case lang of
        Lang.EnUs ->
            "Plan"

        Lang.FrFr ->
            "Type d'offre"


loginUsernameOrEmailAlreadyExist : Lang -> String
loginUsernameOrEmailAlreadyExist lang =
    case lang of
        Lang.EnUs ->
            "An account with this username or e-mail address already exists"

        Lang.FrFr ->
            "Un compte avec ce nom d'utilisateur ou cette adresse e-mail existe déjà"


uiCancel : Lang -> String
uiCancel lang =
    case lang of
        Lang.EnUs ->
            "Cancel"

        Lang.FrFr ->
            "Annuler"


stepsOptionsGeneralOptions : Lang -> String
stepsOptionsGeneralOptions lang =
    case lang of
        Lang.EnUs ->
            "General options"

        Lang.FrFr ->
            "Options générales"


loginRequestNewPassword : Lang -> String
loginRequestNewPassword lang =
    case lang of
        Lang.EnUs ->
            "Request new password"

        Lang.FrFr ->
            "Demander un nouveau mot de passe"


stepsAcquisitionReadyForRecording : Lang -> String
stepsAcquisitionReadyForRecording lang =
    case lang of
        Lang.EnUs ->
            "Ready for recording"

        Lang.FrFr ->
            "Prêt à enregistrer"


actionsDeleteTrack : Lang -> String
actionsDeleteTrack lang =
    case lang of
        Lang.EnUs ->
            "Delete track"

        Lang.FrFr ->
            "Supprimer la musique de fond"


loginWrongUsernameOrPassword : Lang -> String
loginWrongUsernameOrPassword lang =
    case lang of
        Lang.EnUs ->
            "The username or the password is incorrec"

        Lang.FrFr ->
            "Le nom d'utilisateur ou le mot de passe est incorrect"


dateMonthDecember : Lang -> String
dateMonthDecember lang =
    case lang of
        Lang.EnUs ->
            "December"

        Lang.FrFr ->
            "Décembre"


actionsDuplicateCapsule : Lang -> String
actionsDuplicateCapsule lang =
    case lang of
        Lang.EnUs ->
            "Duplicate capsule"

        Lang.FrFr ->
            "Dupliquer la capsule"


dataCapsuleAction : Lang -> Int -> String
dataCapsuleAction lang n =
    case lang of
        Lang.EnUs ->
            if n <= 1 then
                "Action"

            else
                "Actions"


        Lang.FrFr ->
            if n <= 1 then
                "Action"

            else
                "Actions"



actionsConfirmDeleteExtra : Lang -> String
actionsConfirmDeleteExtra lang =
    case lang of
        Lang.EnUs ->
            "Do you really want to delete this extra"

        Lang.FrFr ->
            "Voulez-vous vraiment supprimer cet extra"


stepsPublicationPrivacyPrivateVideosNotAvailable : Lang -> String
stepsPublicationPrivacyPrivateVideosNotAvailable lang =
    case lang of
        Lang.EnUs ->
            "This feature is not ready yet: no users except you will be able to watch the video"

        Lang.FrFr ->
            "Cette fonctionnalité n'est pas encore prête : aucun utilisateur ne pourra voir la vidéo à part vous-même"


actionsDeleteSlide : Lang -> String
actionsDeleteSlide lang =
    case lang of
        Lang.EnUs ->
            "Delete slide"

        Lang.FrFr ->
            "Supprimer la planche"


dataCapsuleRenameCapsule : Lang -> String
dataCapsuleRenameCapsule lang =
    case lang of
        Lang.EnUs ->
            "Rename capsule"

        Lang.FrFr ->
            "Renommer la capsule"


introExampleOfPdfFile : Lang -> String
introExampleOfPdfFile lang =
    case lang of
        Lang.EnUs ->
            "For example, a PDF export version of Microsoft PowerPoint or LibreOffice Impress in HD format"

        Lang.FrFr ->
            "Par exemple, un export PDF de Microsoft PowerPoint ou LibreOffice Impress en paysage au format HD"


stepsProductionProduceVideo : Lang -> String
stepsProductionProduceVideo lang =
    case lang of
        Lang.EnUs ->
            "Produce video"

        Lang.FrFr ->
            "Produire la vidéo"


stepsOptionsOptionsExplanation : Lang -> String
stepsOptionsOptionsExplanation lang =
    case lang of
        Lang.EnUs ->
            "Default production options"

        Lang.FrFr ->
            "Options de production par défaut"


actionsConfirmDeleteCapsule : Lang -> String
actionsConfirmDeleteCapsule lang =
    case lang of
        Lang.EnUs ->
            "Do you really want to delete this capsule"

        Lang.FrFr ->
            "Voulez vous vraiment supprimer la capsule"


stepsProductionSmall : Lang -> String
stepsProductionSmall lang =
    case lang of
        Lang.EnUs ->
            "Small"

        Lang.FrFr ->
            "Petite"


navigationError404 : Lang -> String
navigationError404 lang =
    case lang of
        Lang.EnUs ->
            "Error 404"

        Lang.FrFr ->
            "Erreur 404"


dataCapsuleNewCapsule : Lang -> String
dataCapsuleNewCapsule lang =
    case lang of
        Lang.EnUs ->
            "New capsule"

        Lang.FrFr ->
            "Nouvelle capsule"


loginStrongPasswordComplexity : Lang -> String
loginStrongPasswordComplexity lang =
    case lang of
        Lang.EnUs ->
            "The complexity of the password is strong"

        Lang.FrFr ->
            "La complexité du mot de passe est forte"


