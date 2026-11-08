// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get languageName => 'Français';

  @override
  String get appTitle => 'TimeLog';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get add => 'Ajouter';

  @override
  String get close => 'Fermer';

  @override
  String get ok => 'OK';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get optional => 'facultatif';

  @override
  String get deleteConfirmTitle => 'Supprimer ?';

  @override
  String get deleteConfirmMessage => 'Cette action est irréversible.';

  @override
  String get saved => 'Enregistré';

  @override
  String errorMessage(String message) {
    return 'Erreur : $message';
  }

  @override
  String get nothingHere => 'Rien pour le moment';

  @override
  String get untitled => 'Sans titre';

  @override
  String get periodDay => 'Jour';

  @override
  String get periodWeek => 'Semaine';

  @override
  String get periodMonth => 'Mois';

  @override
  String get periodYear => 'Année';

  @override
  String weekNumber(int number) {
    return 'Semaine $number';
  }

  @override
  String get menuHours => 'Heures';

  @override
  String get menuJournal => 'Journal de travail';

  @override
  String get menuNotes => 'Notes';

  @override
  String get menuCategories => 'Catégories';

  @override
  String get menuSettings => 'Paramètres';

  @override
  String get menuExport => 'Export / sauvegarde';

  @override
  String get menuAbout => 'À propos';

  @override
  String get arrival => 'Arrivée';

  @override
  String get lunchStart => 'Début pause midi';

  @override
  String get lunchEnd => 'Fin pause midi';

  @override
  String get departure => 'Départ';

  @override
  String get morning => 'Matin';

  @override
  String get afternoon => 'Après-midi';

  @override
  String get lunchBreak => 'Pause midi';

  @override
  String get worked => 'Travaillé';

  @override
  String get target => 'Objectif';

  @override
  String get balance => 'Solde';

  @override
  String get totalBalance => 'Solde total';

  @override
  String get clockIn => 'Pointer';

  @override
  String get dayComplete => 'Journée complète';

  @override
  String get dayType => 'Type de journée';

  @override
  String get dayTypeWork => 'Travail';

  @override
  String get dayTypeVacation => 'Vacances';

  @override
  String get dayTypeSick => 'Maladie / accident';

  @override
  String get dayTypeHoliday => 'Jour férié';

  @override
  String get dayTypeCompensation => 'Récupération d\'heures';

  @override
  String get comment => 'Commentaire';

  @override
  String get clearTime => 'Effacer';

  @override
  String get noEntry => 'Aucune saisie';

  @override
  String get deleteDay => 'Supprimer cette journée';

  @override
  String get timeOrderError => 'Les heures doivent être dans l\'ordre chronologique.';

  @override
  String get daysWorked => 'Jours travaillés';

  @override
  String get tapToSet => 'Toucher pour saisir';

  @override
  String get journalModeAdd => 'Ajout';

  @override
  String get journalModeView => 'Consultation';

  @override
  String get newEntry => 'Nouvel enregistrement';

  @override
  String get editEntry => 'Modifier l\'enregistrement';

  @override
  String get title => 'Titre';

  @override
  String get content => 'Contenu';

  @override
  String get markdownHint => 'Markdown accepté : **gras**, *italique*, # titre, - liste';

  @override
  String get duration => 'Temps passé';

  @override
  String get noDuration => 'Non renseigné';

  @override
  String get category => 'Catégorie';

  @override
  String get noCategory => 'Sans catégorie';

  @override
  String get allCategories => 'Toutes les catégories';

  @override
  String get date => 'Date';

  @override
  String get write => 'Écrire';

  @override
  String get preview => 'Aperçu';

  @override
  String totalDuration(String duration) {
    return 'Temps total : $duration';
  }

  @override
  String get entriesOfDay => 'Enregistrements du jour';

  @override
  String get saveAndNew => 'Enregistrer et ajouter un autre';

  @override
  String get entryAdded => 'Enregistrement ajouté';

  @override
  String get titleOrContentRequired => 'Veuillez saisir un titre ou un contenu.';

  @override
  String get newNote => 'Nouvelle note';

  @override
  String get editNote => 'Note';

  @override
  String get noteText => 'Texte';

  @override
  String get addPhoto => 'Photo';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get choosePhoto => 'Choisir une image';

  @override
  String get addAudio => 'Audio';

  @override
  String get addDrawing => 'Dessin';

  @override
  String get addDocument => 'Document';

  @override
  String get attachments => 'Pièces jointes';

  @override
  String get searchNotesHint => 'Rechercher texte, titre, fichier, catégorie…';

  @override
  String get recording => 'Enregistrement…';

  @override
  String get audioRecorder => 'Enregistrement audio';

  @override
  String get startRecording => 'Démarrer l\'enregistrement';

  @override
  String get stopRecording => 'Arrêter et enregistrer';

  @override
  String get micPermissionDenied => 'L\'accès au micro a été refusé.';

  @override
  String get drawingTitle => 'Dessin';

  @override
  String get undo => 'Annuler';

  @override
  String get clearDrawing => 'Tout effacer';

  @override
  String get eraser => 'Gomme';

  @override
  String get open => 'Ouvrir';

  @override
  String get rename => 'Renommer';

  @override
  String get fileName => 'Nom du fichier';

  @override
  String get saveToDevice => 'Enregistrer une copie';

  @override
  String get play => 'Lire';

  @override
  String get pause => 'Pause';

  @override
  String get noResults => 'Aucun résultat';

  @override
  String cannotOpenFile(String message) {
    return 'Impossible d\'ouvrir ce fichier : $message';
  }

  @override
  String get categoryName => 'Nom';

  @override
  String get categoryColor => 'Couleur';

  @override
  String get newCategory => 'Nouvelle catégorie';

  @override
  String get editCategory => 'Modifier la catégorie';

  @override
  String get noCategories => 'Aucune catégorie. Créez-en une avec le bouton +.';

  @override
  String get categoryDeleteMessage =>
      'Les enregistrements et notes de cette catégorie seront conservés, sans catégorie.';

  @override
  String get nameRequired => 'Veuillez saisir un nom.';

  @override
  String get manageCategories => 'Gérer les catégories';

  @override
  String get sectionAppearance => 'Apparence';

  @override
  String get theme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get accentColor => 'Couleur d\'accent';

  @override
  String get sectionGeneral => 'Général';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Langue du système';

  @override
  String get firstDayOfWeek => 'Premier jour de la semaine';

  @override
  String get timeFormat => 'Format de l\'heure';

  @override
  String get format24h => '24 heures';

  @override
  String get format12h => '12 heures (AM/PM)';

  @override
  String get sectionHours => 'Temps de travail';

  @override
  String get dailyTarget => 'Objectif journalier';

  @override
  String get workDays => 'Jours travaillés';

  @override
  String get trackingStart => 'Calculer le solde depuis le';

  @override
  String get sectionData => 'Données';

  @override
  String get exportTitle => 'Export / sauvegarde';

  @override
  String get exportFormat => 'Format';

  @override
  String get exportWhat => 'Données à exporter';

  @override
  String get includeAttachments => 'Inclure les fichiers joints (photos, audio, …)';

  @override
  String get exportButton => 'Exporter';

  @override
  String get exportDone => 'Export enregistré';

  @override
  String get exportCsvInfo => 'CSV : un fichier par type de données, regroupés dans une archive ZIP.';

  @override
  String get exportJsonInfo => 'JSON : un seul fichier, qui peut aussi servir à restaurer une sauvegarde.';

  @override
  String get importBackup => 'Restaurer une sauvegarde JSON';

  @override
  String get importConfirm => 'Toutes les données actuelles seront remplacées par la sauvegarde. Continuer ?';

  @override
  String get importDone => 'Sauvegarde restaurée';

  @override
  String get settingsData => 'Paramètres';

  @override
  String get aboutText =>
      'TimeLog vous aide à suivre vos heures de travail, tenir un journal de travail et conserver des notes avec photos, audio, dessins et documents. Toutes les données restent sur votre appareil dans une base SQLite.';

  @override
  String get hoursMinutes => 'Heures et minutes';

  @override
  String get absencePart => 'L\'absence concerne';

  @override
  String get absenceFull => 'Journée entière';

  @override
  String get absenceMorning => 'Matin';

  @override
  String get absenceAfternoon => 'Après-midi';

  @override
  String get absenceCustom => 'Durée personnalisée';

  @override
  String get absenceDuration => 'Durée de l\'absence';

  @override
  String get partialAbsenceHint => 'Saisissez vos heures pour la partie de la journée travaillée.';

  @override
  String get notCredited => 'non crédité (pris sur le solde)';

  @override
  String get totalCounted => 'Total compté';

  @override
  String get addAbsence => 'Absence sur plusieurs jours';

  @override
  String get absencePeriod => 'Choisir les dates';

  @override
  String get apply => 'Appliquer';

  @override
  String get onlyWorkDaysInfo => 'Seuls les jours travaillés sont modifiés. Les heures déjà saisies sont conservées.';

  @override
  String absenceApplied(int count) {
    return '$count jour(s) mis à jour';
  }

  @override
  String fullDayAbsence(String type) {
    return 'Absence toute la journée : $type';
  }

  @override
  String get menuVacation => 'Vacances';

  @override
  String get bookVacation => 'Poser des vacances';

  @override
  String get vacationRemaining => 'Vacances restantes';

  @override
  String get vacationEntitlement => 'Droit aux vacances de l\'année';

  @override
  String get vacationDefaultHint => 'Valeur par défaut des paramètres, toucher pour modifier cette année';

  @override
  String get vacationCarryOver => 'Report de l\'année précédente';

  @override
  String vacationUsePrevious(int year, String days) {
    return 'Reprendre le solde de $year : $days j';
  }

  @override
  String get vacationTaken => 'Pris';

  @override
  String get vacationPlanned => 'Planifiés';

  @override
  String get vacationList => 'Vacances de l\'année';

  @override
  String get vacationExceeded => 'Plus de vacances posées que disponibles.';

  @override
  String get vacationDaysPerYear => 'Jours de vacances par an';

  @override
  String daysCount(String days) {
    return '$days j';
  }

  @override
  String workDaysInRange(int count) {
    return '$count jour(s) travaillé(s) dans cette période';
  }

  @override
  String vacationPreview(String days, String left) {
    return 'Utilise $days jour(s) de vacances · restant ensuite : $left';
  }

  @override
  String get toolPen => 'Stylo';

  @override
  String get toolLine => 'Trait droit';

  @override
  String get toolArrow => 'Flèche';

  @override
  String get toolRect => 'Rectangle';

  @override
  String get toolCircle => 'Cercle';

  @override
  String get toolArc => 'Arc de cercle';

  @override
  String get toolFill => 'Remplissage de zone';

  @override
  String get toolObjectEraser => 'Gomme à objets';

  @override
  String get arcHint => 'Faites glisser le point pour courber l\'arc';

  @override
  String get pressureSim => 'Pression simulée : plus le trait est rapide, plus il est fin';

  @override
  String get pressureShort => 'Pression';

  @override
  String get redo => 'Rétablir';

  @override
  String get discardDrawingTitle => 'Quitter sans enregistrer ?';

  @override
  String get discardDrawingMessage =>
      'Les modifications du dessin seront perdues. Pour les garder, utilisez le bouton ✓ en haut à droite.';

  @override
  String get discardDrawing => 'Quitter sans enregistrer';

  @override
  String get keepDrawing => 'Continuer à dessiner';

  @override
  String get author => 'Auteur';

  @override
  String get contact => 'Contact';

  @override
  String get copy => 'Copier';

  @override
  String get copied => 'Copié';

  @override
  String get sourceCode => 'Code source';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get menuSync => 'Synchronisation';

  @override
  String get syncIntro =>
      'Synchronise toutes tes données entre plusieurs appareils (téléphone, ordinateur) via ton serveur TimeLog. L\'application continue de fonctionner hors ligne : les modifications sont envoyées dès que le serveur est joignable.';

  @override
  String get syncServer => 'Adresse du serveur';

  @override
  String get syncServerHint => 'https://timelog.exemple.ch';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'Créer un compte';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get syncMergeInfo => 'Les données de cet appareil seront fusionnées avec celles du compte.';

  @override
  String get syncInsecure =>
      'Connexion non chiffrée (http) : le mot de passe et les données circulent en clair. Utilisez https:// en dehors de votre réseau local.';

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String syncLast(String time) {
    return 'Dernière synchronisation : $time';
  }

  @override
  String get syncNever => 'Pas encore synchronisé';

  @override
  String get syncRunning => 'Synchronisation en cours…';

  @override
  String get syncOffline => 'Serveur injoignable : les modifications seront envoyées plus tard.';

  @override
  String syncPending(int count) {
    return '$count modification(s) en attente d\'envoi';
  }

  @override
  String get syncUpToDate => 'Tout est envoyé';

  @override
  String get syncAccount => 'Compte';

  @override
  String get syncSignOutConfirm => 'Les données restent sur cet appareil mais ne seront plus synchronisées.';

  @override
  String get syncDeleteAccount => 'Supprimer le compte en ligne';

  @override
  String get syncDeleteAccountMessage =>
      'Le compte et toutes ses données seront supprimés du serveur. Les données de cet appareil sont conservées. Saisissez votre mot de passe pour confirmer.';

  @override
  String get syncAccountDeleted => 'Compte en ligne supprimé';

  @override
  String get syncSessionExpired => 'Session expirée : reconnectez-vous.';

  @override
  String get syncSignedIn => 'Connecté';

  @override
  String get syncErrInvalidCredentials => 'E-mail ou mot de passe incorrect.';

  @override
  String get syncErrEmailTaken => 'Un compte existe déjà avec cet e-mail.';

  @override
  String get syncErrInvalidEmail => 'Adresse e-mail invalide.';

  @override
  String get syncErrWeakPassword => 'Le mot de passe doit contenir de 8 à 72 caractères.';

  @override
  String get syncErrTooMany => 'Trop de tentatives. Réessayez dans 15 minutes.';

  @override
  String get syncErrNetwork => 'Serveur injoignable. Vérifiez l\'adresse et la connexion.';

  @override
  String get syncErrNotServer => 'Cette adresse n\'est pas un serveur TimeLog.';

  @override
  String syncErrOther(String code) {
    return 'Erreur : $code';
  }

  @override
  String get licenses => 'Licences';

  @override
  String get vacationDeletePeriod => 'Supprimer la période';

  @override
  String vacationDeletePeriodMessage(String from, String to) {
    return 'Retirer les vacances du $from au $to ? Tous les jours de la période redeviennent des jours normaux ; les heures saisies sont conservées.';
  }

  @override
  String vacationPeriodDeleted(int count) {
    return 'Vacances retirées ($count jour(s))';
  }
}
