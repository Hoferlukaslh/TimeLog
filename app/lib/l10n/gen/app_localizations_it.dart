// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get languageName => 'Italiano';

  @override
  String get appTitle => 'TimeLog';

  @override
  String get save => 'Salva';

  @override
  String get cancel => 'Annulla';

  @override
  String get delete => 'Elimina';

  @override
  String get edit => 'Modifica';

  @override
  String get add => 'Aggiungi';

  @override
  String get close => 'Chiudi';

  @override
  String get ok => 'OK';

  @override
  String get today => 'Oggi';

  @override
  String get optional => 'facoltativo';

  @override
  String get deleteConfirmTitle => 'Eliminare?';

  @override
  String get deleteConfirmMessage => 'Questa azione non può essere annullata.';

  @override
  String get saved => 'Salvato';

  @override
  String errorMessage(String message) {
    return 'Errore: $message';
  }

  @override
  String get nothingHere => 'Ancora niente qui';

  @override
  String get untitled => 'Senza titolo';

  @override
  String get periodDay => 'Giorno';

  @override
  String get periodWeek => 'Settimana';

  @override
  String get periodMonth => 'Mese';

  @override
  String get periodYear => 'Anno';

  @override
  String weekNumber(int number) {
    return 'Settimana $number';
  }

  @override
  String get menuHours => 'Ore';

  @override
  String get menuJournal => 'Diario di lavoro';

  @override
  String get menuNotes => 'Note';

  @override
  String get menuCategories => 'Categorie';

  @override
  String get menuSettings => 'Impostazioni';

  @override
  String get menuExport => 'Esporta / backup';

  @override
  String get menuAbout => 'Informazioni';

  @override
  String get arrival => 'Arrivo';

  @override
  String get lunchStart => 'Inizio pausa pranzo';

  @override
  String get lunchEnd => 'Fine pausa pranzo';

  @override
  String get departure => 'Uscita';

  @override
  String get morning => 'Mattina';

  @override
  String get afternoon => 'Pomeriggio';

  @override
  String get lunchBreak => 'Pausa pranzo';

  @override
  String get worked => 'Lavorato';

  @override
  String get target => 'Obiettivo';

  @override
  String get balance => 'Saldo';

  @override
  String get totalBalance => 'Saldo totale';

  @override
  String get clockIn => 'Timbra';

  @override
  String get dayComplete => 'Giornata completa';

  @override
  String get dayType => 'Tipo di giornata';

  @override
  String get dayTypeWork => 'Lavoro';

  @override
  String get dayTypeVacation => 'Vacanze';

  @override
  String get dayTypeSick => 'Malattia / infortunio';

  @override
  String get dayTypeHoliday => 'Giorno festivo';

  @override
  String get dayTypeCompensation => 'Recupero ore';

  @override
  String get comment => 'Commento';

  @override
  String get clearTime => 'Cancella';

  @override
  String get noEntry => 'Nessun dato';

  @override
  String get deleteDay => 'Elimina questa giornata';

  @override
  String get timeOrderError => 'Gli orari devono essere in ordine cronologico.';

  @override
  String get daysWorked => 'Giorni lavorati';

  @override
  String get tapToSet => 'Tocca per impostare';

  @override
  String get journalModeAdd => 'Aggiunta';

  @override
  String get journalModeView => 'Consultazione';

  @override
  String get newEntry => 'Nuova voce';

  @override
  String get editEntry => 'Modifica voce';

  @override
  String get title => 'Titolo';

  @override
  String get content => 'Contenuto';

  @override
  String get markdownHint => 'Markdown supportato: **grassetto**, *corsivo*, # titolo, - elenco';

  @override
  String get duration => 'Tempo impiegato';

  @override
  String get noDuration => 'Non specificato';

  @override
  String get category => 'Categoria';

  @override
  String get noCategory => 'Nessuna categoria';

  @override
  String get allCategories => 'Tutte le categorie';

  @override
  String get date => 'Data';

  @override
  String get write => 'Scrivi';

  @override
  String get preview => 'Anteprima';

  @override
  String totalDuration(String duration) {
    return 'Tempo totale: $duration';
  }

  @override
  String get entriesOfDay => 'Voci del giorno';

  @override
  String get saveAndNew => 'Salva e aggiungi un\'altra';

  @override
  String get entryAdded => 'Voce aggiunta';

  @override
  String get titleOrContentRequired => 'Inserisci un titolo o un contenuto.';

  @override
  String get newNote => 'Nuova nota';

  @override
  String get editNote => 'Nota';

  @override
  String get noteText => 'Testo';

  @override
  String get addPhoto => 'Foto';

  @override
  String get takePhoto => 'Scatta una foto';

  @override
  String get choosePhoto => 'Scegli un\'immagine';

  @override
  String get addAudio => 'Audio';

  @override
  String get addDrawing => 'Disegno';

  @override
  String get addDocument => 'Documento';

  @override
  String get attachments => 'Allegati';

  @override
  String get searchNotesHint => 'Cerca testo, titolo, file, categoria…';

  @override
  String get recording => 'Registrazione…';

  @override
  String get audioRecorder => 'Registrazione audio';

  @override
  String get startRecording => 'Avvia registrazione';

  @override
  String get stopRecording => 'Ferma e salva';

  @override
  String get micPermissionDenied => 'L\'accesso al microfono è stato negato.';

  @override
  String get drawingTitle => 'Disegno';

  @override
  String get undo => 'Annulla';

  @override
  String get clearDrawing => 'Cancella tutto';

  @override
  String get eraser => 'Gomma';

  @override
  String get open => 'Apri';

  @override
  String get rename => 'Rinomina';

  @override
  String get fileName => 'Nome file';

  @override
  String get saveToDevice => 'Salva una copia';

  @override
  String get play => 'Riproduci';

  @override
  String get pause => 'Pausa';

  @override
  String get noResults => 'Nessun risultato';

  @override
  String cannotOpenFile(String message) {
    return 'Impossibile aprire il file: $message';
  }

  @override
  String get categoryName => 'Nome';

  @override
  String get categoryColor => 'Colore';

  @override
  String get newCategory => 'Nuova categoria';

  @override
  String get editCategory => 'Modifica categoria';

  @override
  String get noCategories => 'Nessuna categoria. Creane una con il pulsante +.';

  @override
  String get categoryDeleteMessage => 'Le voci e le note di questa categoria verranno mantenute, senza categoria.';

  @override
  String get nameRequired => 'Inserisci un nome.';

  @override
  String get manageCategories => 'Gestisci categorie';

  @override
  String get sectionAppearance => 'Aspetto';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get accentColor => 'Colore di accento';

  @override
  String get sectionGeneral => 'Generale';

  @override
  String get language => 'Lingua';

  @override
  String get languageSystem => 'Lingua di sistema';

  @override
  String get firstDayOfWeek => 'Primo giorno della settimana';

  @override
  String get timeFormat => 'Formato ora';

  @override
  String get format24h => '24 ore';

  @override
  String get format12h => '12 ore (AM/PM)';

  @override
  String get sectionHours => 'Orario di lavoro';

  @override
  String get dailyTarget => 'Obiettivo giornaliero';

  @override
  String get workDays => 'Giorni lavorativi';

  @override
  String get trackingStart => 'Calcola il saldo dal';

  @override
  String get sectionData => 'Dati';

  @override
  String get exportTitle => 'Esporta / backup';

  @override
  String get exportFormat => 'Formato';

  @override
  String get exportWhat => 'Dati da esportare';

  @override
  String get includeAttachments => 'Includi i file allegati (foto, audio, …)';

  @override
  String get exportButton => 'Esporta';

  @override
  String get exportDone => 'Esportazione salvata';

  @override
  String get exportCsvInfo => 'CSV: un file per tipo di dati, raggruppati in un archivio ZIP.';

  @override
  String get exportJsonInfo => 'JSON: un unico file, utilizzabile anche per ripristinare un backup.';

  @override
  String get importBackup => 'Ripristina un backup JSON';

  @override
  String get importConfirm => 'Tutti i dati attuali saranno sostituiti. Continuare?';

  @override
  String get importDone => 'Backup ripristinato';

  @override
  String get settingsData => 'Impostazioni';

  @override
  String get aboutText =>
      'TimeLog ti aiuta a registrare le ore di lavoro, tenere un diario di lavoro e conservare note con foto, audio, disegni e documenti. Tutti i dati restano sul tuo dispositivo in un database SQLite.';

  @override
  String get hoursMinutes => 'Ore e minuti';

  @override
  String get absencePart => 'L\'assenza riguarda';

  @override
  String get absenceFull => 'Giornata intera';

  @override
  String get absenceMorning => 'Mattina';

  @override
  String get absenceAfternoon => 'Pomeriggio';

  @override
  String get absenceCustom => 'Durata personalizzata';

  @override
  String get absenceDuration => 'Durata dell\'assenza';

  @override
  String get partialAbsenceHint => 'Inserisci gli orari per la parte di giornata lavorata.';

  @override
  String get notCredited => 'non accreditato (preso dal saldo)';

  @override
  String get totalCounted => 'Totale conteggiato';

  @override
  String get addAbsence => 'Assenza su più giorni';

  @override
  String get absencePeriod => 'Scegli le date';

  @override
  String get apply => 'Applica';

  @override
  String get onlyWorkDaysInfo =>
      'Vengono modificati solo i giorni lavorativi. Gli orari già inseriti vengono mantenuti.';

  @override
  String absenceApplied(int count) {
    return '$count giorno/i aggiornato/i';
  }

  @override
  String fullDayAbsence(String type) {
    return 'Assenza per tutta la giornata: $type';
  }

  @override
  String get menuVacation => 'Vacanze';

  @override
  String get bookVacation => 'Inserisci vacanze';

  @override
  String get vacationRemaining => 'Giorni di vacanza rimanenti';

  @override
  String get vacationEntitlement => 'Diritto alle vacanze dell\'anno';

  @override
  String get vacationDefaultHint => 'Valore predefinito delle impostazioni, tocca per modificare quest\'anno';

  @override
  String get vacationCarryOver => 'Riporto dall\'anno precedente';

  @override
  String vacationUsePrevious(int year, String days) {
    return 'Riprendi il saldo del $year: $days g';
  }

  @override
  String get vacationTaken => 'Godute';

  @override
  String get vacationPlanned => 'Pianificate';

  @override
  String get vacationList => 'Vacanze dell\'anno';

  @override
  String get vacationExceeded => 'Più vacanze inserite di quelle disponibili.';

  @override
  String get vacationDaysPerYear => 'Giorni di vacanza all\'anno';

  @override
  String daysCount(String days) {
    return '$days g';
  }

  @override
  String workDaysInRange(int count) {
    return '$count giorno/i lavorativo/i in questo periodo';
  }

  @override
  String vacationPreview(String days, String left) {
    return 'Usa $days giorno/i di vacanza · rimanenti dopo: $left';
  }

  @override
  String get toolPen => 'Penna';

  @override
  String get toolLine => 'Linea retta';

  @override
  String get toolArrow => 'Freccia';

  @override
  String get toolRect => 'Rettangolo';

  @override
  String get toolCircle => 'Cerchio';

  @override
  String get toolArc => 'Arco';

  @override
  String get toolFill => 'Riempimento';

  @override
  String get toolObjectEraser => 'Cancella forme intere';

  @override
  String get arcHint => 'Trascina il punto per curvare l\'arco';

  @override
  String get pressureSim => 'Pressione simulata: tratti più veloci sono più sottili';

  @override
  String get pressureShort => 'Pressione';

  @override
  String get redo => 'Ripeti';

  @override
  String get discardDrawingTitle => 'Uscire senza salvare?';

  @override
  String get discardDrawingMessage =>
      'Le modifiche al disegno andranno perse. Per conservarle, usa il pulsante ✓ in alto a destra.';

  @override
  String get discardDrawing => 'Esci senza salvare';

  @override
  String get keepDrawing => 'Continua a disegnare';

  @override
  String get author => 'Autore';

  @override
  String get contact => 'Contatto';

  @override
  String get copy => 'Copia';

  @override
  String get copied => 'Copiato';

  @override
  String get sourceCode => 'Codice sorgente';

  @override
  String version(String version) {
    return 'Versione $version';
  }

  @override
  String get menuSync => 'Sincronizzazione';

  @override
  String get syncIntro =>
      'Sincronizza tutti i dati tra più dispositivi (telefono, computer) tramite il tuo server TimeLog. L\'app funziona anche offline: le modifiche vengono inviate appena il server è raggiungibile.';

  @override
  String get syncServer => 'Indirizzo del server';

  @override
  String get syncServerHint => 'https://timelog.esempio.ch';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Mostra la password';

  @override
  String get signIn => 'Accedi';

  @override
  String get signUp => 'Crea un account';

  @override
  String get signOut => 'Esci';

  @override
  String get syncMergeInfo => 'I dati di questo dispositivo verranno uniti a quelli dell\'account.';

  @override
  String get syncInsecure =>
      'Connessione non cifrata (http): password e dati viaggiano in chiaro. Usa https:// fuori dalla rete locale.';

  @override
  String get syncNow => 'Sincronizza ora';

  @override
  String syncLast(String time) {
    return 'Ultima sincronizzazione: $time';
  }

  @override
  String get syncNever => 'Non ancora sincronizzato';

  @override
  String get syncRunning => 'Sincronizzazione in corso…';

  @override
  String get syncOffline => 'Server non raggiungibile: le modifiche verranno inviate più tardi.';

  @override
  String syncPending(int count) {
    return '$count modifica/e in attesa di invio';
  }

  @override
  String get syncUpToDate => 'Tutto inviato';

  @override
  String get syncAccount => 'Account';

  @override
  String get syncSignOutConfirm => 'I dati restano su questo dispositivo ma non saranno più sincronizzati.';

  @override
  String get syncDeleteAccount => 'Elimina l\'account online';

  @override
  String get syncDeleteAccountMessage =>
      'L\'account e tutti i suoi dati verranno eliminati dal server. I dati di questo dispositivo vengono mantenuti. Inserisci la password per confermare.';

  @override
  String get syncAccountDeleted => 'Account online eliminato';

  @override
  String get syncSessionExpired => 'Sessione scaduta: accedi di nuovo.';

  @override
  String get syncSignedIn => 'Connesso';

  @override
  String get syncErrInvalidCredentials => 'E-mail o password errati.';

  @override
  String get syncErrEmailTaken => 'Esiste già un account con questa e-mail.';

  @override
  String get syncErrInvalidEmail => 'Indirizzo e-mail non valido.';

  @override
  String get syncErrWeakPassword => 'La password deve avere da 8 a 72 caratteri.';

  @override
  String get syncErrTooMany => 'Troppi tentativi. Riprova tra 15 minuti.';

  @override
  String get syncErrNetwork => 'Server non raggiungibile. Controlla l\'indirizzo e la connessione.';

  @override
  String get syncErrNotServer => 'Questo indirizzo non è un server TimeLog.';

  @override
  String syncErrOther(String code) {
    return 'Errore: $code';
  }

  @override
  String get licenses => 'Licenze';
}
