// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get languageName => 'Deutsch';

  @override
  String get appTitle => 'TimeLog';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get add => 'Hinzufügen';

  @override
  String get close => 'Schliessen';

  @override
  String get ok => 'OK';

  @override
  String get today => 'Heute';

  @override
  String get optional => 'optional';

  @override
  String get deleteConfirmTitle => 'Löschen?';

  @override
  String get deleteConfirmMessage => 'Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get saved => 'Gespeichert';

  @override
  String errorMessage(String message) {
    return 'Fehler: $message';
  }

  @override
  String get nothingHere => 'Noch keine Einträge';

  @override
  String get untitled => 'Ohne Titel';

  @override
  String get periodDay => 'Tag';

  @override
  String get periodWeek => 'Woche';

  @override
  String get periodMonth => 'Monat';

  @override
  String get periodYear => 'Jahr';

  @override
  String weekNumber(int number) {
    return 'Woche $number';
  }

  @override
  String get menuHours => 'Stunden';

  @override
  String get menuJournal => 'Arbeitsjournal';

  @override
  String get menuNotes => 'Notizen';

  @override
  String get menuCategories => 'Kategorien';

  @override
  String get menuSettings => 'Einstellungen';

  @override
  String get menuExport => 'Export / Sicherung';

  @override
  String get menuAbout => 'Über';

  @override
  String get arrival => 'Ankunft';

  @override
  String get lunchStart => 'Beginn Mittagspause';

  @override
  String get lunchEnd => 'Ende Mittagspause';

  @override
  String get departure => 'Feierabend';

  @override
  String get morning => 'Vormittag';

  @override
  String get afternoon => 'Nachmittag';

  @override
  String get lunchBreak => 'Mittagspause';

  @override
  String get worked => 'Gearbeitet';

  @override
  String get target => 'Soll';

  @override
  String get balance => 'Saldo';

  @override
  String get totalBalance => 'Gesamtsaldo';

  @override
  String get clockIn => 'Stempeln';

  @override
  String get dayComplete => 'Tag abgeschlossen';

  @override
  String get dayType => 'Tagesart';

  @override
  String get dayTypeWork => 'Arbeit';

  @override
  String get dayTypeVacation => 'Ferien';

  @override
  String get dayTypeSick => 'Krankheit / Unfall';

  @override
  String get dayTypeHoliday => 'Feiertag';

  @override
  String get dayTypeCompensation => 'Kompensation';

  @override
  String get comment => 'Kommentar';

  @override
  String get clearTime => 'Löschen';

  @override
  String get noEntry => 'Kein Eintrag';

  @override
  String get deleteDay => 'Diesen Tag löschen';

  @override
  String get timeOrderError => 'Die Zeiten müssen chronologisch sein.';

  @override
  String get daysWorked => 'Arbeitstage';

  @override
  String get tapToSet => 'Tippen zum Erfassen';

  @override
  String get journalModeAdd => 'Erfassen';

  @override
  String get journalModeView => 'Ansicht';

  @override
  String get newEntry => 'Neuer Eintrag';

  @override
  String get editEntry => 'Eintrag bearbeiten';

  @override
  String get title => 'Titel';

  @override
  String get content => 'Inhalt';

  @override
  String get markdownHint => 'Markdown möglich: **fett**, *kursiv*, # Titel, - Liste';

  @override
  String get duration => 'Aufgewendete Zeit';

  @override
  String get noDuration => 'Nicht angegeben';

  @override
  String get category => 'Kategorie';

  @override
  String get noCategory => 'Keine Kategorie';

  @override
  String get allCategories => 'Alle Kategorien';

  @override
  String get date => 'Datum';

  @override
  String get write => 'Schreiben';

  @override
  String get preview => 'Vorschau';

  @override
  String totalDuration(String duration) {
    return 'Gesamtzeit: $duration';
  }

  @override
  String get entriesOfDay => 'Einträge des Tages';

  @override
  String get saveAndNew => 'Speichern und weiteren erfassen';

  @override
  String get entryAdded => 'Eintrag hinzugefügt';

  @override
  String get titleOrContentRequired => 'Bitte Titel oder Inhalt eingeben.';

  @override
  String get newNote => 'Neue Notiz';

  @override
  String get editNote => 'Notiz';

  @override
  String get noteText => 'Text';

  @override
  String get addPhoto => 'Foto';

  @override
  String get takePhoto => 'Foto aufnehmen';

  @override
  String get choosePhoto => 'Bild auswählen';

  @override
  String get addAudio => 'Audio';

  @override
  String get addDrawing => 'Zeichnung';

  @override
  String get addDocument => 'Dokument';

  @override
  String get attachments => 'Anhänge';

  @override
  String get searchNotesHint => 'Text, Titel, Datei, Kategorie suchen…';

  @override
  String get recording => 'Aufnahme…';

  @override
  String get audioRecorder => 'Audioaufnahme';

  @override
  String get startRecording => 'Aufnahme starten';

  @override
  String get stopRecording => 'Stoppen und speichern';

  @override
  String get micPermissionDenied => 'Der Mikrofonzugriff wurde verweigert.';

  @override
  String get drawingTitle => 'Zeichnung';

  @override
  String get undo => 'Rückgängig';

  @override
  String get clearDrawing => 'Alles löschen';

  @override
  String get eraser => 'Radierer';

  @override
  String get open => 'Öffnen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get fileName => 'Dateiname';

  @override
  String get saveToDevice => 'Kopie speichern';

  @override
  String get play => 'Abspielen';

  @override
  String get pause => 'Pause';

  @override
  String get noResults => 'Keine Ergebnisse';

  @override
  String cannotOpenFile(String message) {
    return 'Datei kann nicht geöffnet werden: $message';
  }

  @override
  String get categoryName => 'Name';

  @override
  String get categoryColor => 'Farbe';

  @override
  String get newCategory => 'Neue Kategorie';

  @override
  String get editCategory => 'Kategorie bearbeiten';

  @override
  String get noCategories => 'Noch keine Kategorien. Mit + erstellen.';

  @override
  String get categoryDeleteMessage => 'Einträge und Notizen dieser Kategorie bleiben ohne Kategorie erhalten.';

  @override
  String get nameRequired => 'Bitte einen Namen eingeben.';

  @override
  String get manageCategories => 'Kategorien verwalten';

  @override
  String get sectionAppearance => 'Darstellung';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get accentColor => 'Akzentfarbe';

  @override
  String get sectionGeneral => 'Allgemein';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemsprache';

  @override
  String get firstDayOfWeek => 'Erster Tag der Woche';

  @override
  String get timeFormat => 'Zeitformat';

  @override
  String get format24h => '24 Stunden';

  @override
  String get format12h => '12 Stunden (AM/PM)';

  @override
  String get sectionHours => 'Arbeitszeit';

  @override
  String get dailyTarget => 'Tagessoll';

  @override
  String get workDays => 'Arbeitstage';

  @override
  String get trackingStart => 'Saldo berechnen ab';

  @override
  String get sectionData => 'Daten';

  @override
  String get exportTitle => 'Export / Sicherung';

  @override
  String get exportFormat => 'Format';

  @override
  String get exportWhat => 'Zu exportierende Daten';

  @override
  String get includeAttachments => 'Anhänge einschliessen (Fotos, Audio, …)';

  @override
  String get exportButton => 'Exportieren';

  @override
  String get exportDone => 'Export gespeichert';

  @override
  String get exportCsvInfo => 'CSV: eine Datei pro Datentyp in einem ZIP-Archiv.';

  @override
  String get exportJsonInfo => 'JSON: eine einzige Datei, die auch zur Wiederherstellung dient.';

  @override
  String get importBackup => 'JSON-Sicherung wiederherstellen';

  @override
  String get importConfirm => 'Alle aktuellen Daten werden ersetzt. Fortfahren?';

  @override
  String get importDone => 'Sicherung wiederhergestellt';

  @override
  String get settingsData => 'Einstellungen';

  @override
  String get aboutText =>
      'TimeLog hilft Ihnen, Ihre Arbeitszeit zu erfassen, ein Arbeitsjournal zu führen und Notizen mit Fotos, Audio, Zeichnungen und Dokumenten zu speichern. Alle Daten bleiben in einer SQLite-Datenbank auf Ihrem Gerät.';

  @override
  String get hoursMinutes => 'Stunden und Minuten';

  @override
  String get absencePart => 'Abwesenheit betrifft';

  @override
  String get absenceFull => 'Ganzer Tag';

  @override
  String get absenceMorning => 'Vormittag';

  @override
  String get absenceAfternoon => 'Nachmittag';

  @override
  String get absenceCustom => 'Eigene Dauer';

  @override
  String get absenceDuration => 'Dauer der Abwesenheit';

  @override
  String get partialAbsenceHint => 'Erfassen Sie Ihre Zeiten für den gearbeiteten Teil des Tages.';

  @override
  String get notCredited => 'nicht angerechnet (vom Saldo abgezogen)';

  @override
  String get totalCounted => 'Total angerechnet';

  @override
  String get addAbsence => 'Abwesenheit über mehrere Tage';

  @override
  String get absencePeriod => 'Daten wählen';

  @override
  String get apply => 'Anwenden';

  @override
  String get onlyWorkDaysInfo => 'Nur Arbeitstage werden geändert. Bereits erfasste Zeiten bleiben erhalten.';

  @override
  String absenceApplied(int count) {
    return '$count Tag(e) aktualisiert';
  }

  @override
  String fullDayAbsence(String type) {
    return 'Ganztägige Abwesenheit: $type';
  }

  @override
  String get menuVacation => 'Ferien';

  @override
  String get bookVacation => 'Ferien eintragen';

  @override
  String get vacationRemaining => 'Verbleibende Ferientage';

  @override
  String get vacationEntitlement => 'Ferienanspruch des Jahres';

  @override
  String get vacationDefaultHint => 'Standardwert aus den Einstellungen, tippen zum Ändern für dieses Jahr';

  @override
  String get vacationCarryOver => 'Übertrag vom Vorjahr';

  @override
  String vacationUsePrevious(int year, String days) {
    return 'Saldo von $year übernehmen: $days T.';
  }

  @override
  String get vacationTaken => 'Bezogen';

  @override
  String get vacationPlanned => 'Geplant';

  @override
  String get vacationList => 'Ferien des Jahres';

  @override
  String get vacationExceeded => 'Mehr Ferien eingetragen als verfügbar.';

  @override
  String get vacationDaysPerYear => 'Ferientage pro Jahr';

  @override
  String daysCount(String days) {
    return '$days T.';
  }

  @override
  String workDaysInRange(int count) {
    return '$count Arbeitstag(e) in diesem Zeitraum';
  }

  @override
  String vacationPreview(String days, String left) {
    return 'Benötigt $days Ferientag(e) · danach verbleibend: $left';
  }

  @override
  String get toolPen => 'Stift';

  @override
  String get toolLine => 'Gerade Linie';

  @override
  String get toolArrow => 'Pfeil';

  @override
  String get toolRect => 'Rechteck';

  @override
  String get toolCircle => 'Kreis';

  @override
  String get toolArc => 'Kreisbogen';

  @override
  String get toolFill => 'Fläche füllen';

  @override
  String get toolObjectEraser => 'Ganze Formen löschen';

  @override
  String get arcHint => 'Punkt ziehen, um den Bogen zu biegen';

  @override
  String get pressureSim => 'Simulierter Druck: schnellere Striche sind dünner';

  @override
  String get pressureShort => 'Druck';

  @override
  String get redo => 'Wiederholen';

  @override
  String get discardDrawingTitle => 'Ohne Speichern verlassen?';

  @override
  String get discardDrawingMessage =>
      'Ihre Änderungen an der Zeichnung gehen verloren. Zum Behalten oben rechts auf ✓ tippen.';

  @override
  String get discardDrawing => 'Ohne Speichern verlassen';

  @override
  String get keepDrawing => 'Weiterzeichnen';

  @override
  String get author => 'Autor';

  @override
  String get contact => 'Kontakt';

  @override
  String get copy => 'Kopieren';

  @override
  String get copied => 'Kopiert';

  @override
  String get sourceCode => 'Quellcode';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get menuSync => 'Synchronisation';

  @override
  String get syncIntro =>
      'Synchronisiere alle Daten zwischen mehreren Geräten (Handy, Computer) über deinen TimeLog-Server. Die App funktioniert auch offline: Änderungen werden gesendet, sobald der Server erreichbar ist.';

  @override
  String get syncServer => 'Serveradresse';

  @override
  String get syncServerHint => 'https://timelog.beispiel.ch';

  @override
  String get email => 'E-Mail';

  @override
  String get password => 'Passwort';

  @override
  String get showPassword => 'Passwort anzeigen';

  @override
  String get signIn => 'Anmelden';

  @override
  String get signUp => 'Konto erstellen';

  @override
  String get signOut => 'Abmelden';

  @override
  String get syncMergeInfo => 'Die Daten dieses Geräts werden mit denen des Kontos zusammengeführt.';

  @override
  String get syncInsecure =>
      'Unverschlüsselte Verbindung (http): Passwort und Daten werden im Klartext gesendet. Ausserhalb des Heimnetzes https:// verwenden.';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String syncLast(String time) {
    return 'Letzte Synchronisation: $time';
  }

  @override
  String get syncNever => 'Noch nicht synchronisiert';

  @override
  String get syncRunning => 'Synchronisierung läuft…';

  @override
  String get syncOffline => 'Server nicht erreichbar: Änderungen werden später gesendet.';

  @override
  String syncPending(int count) {
    return '$count Änderung(en) warten auf Versand';
  }

  @override
  String get syncUpToDate => 'Alles gesendet';

  @override
  String get syncAccount => 'Konto';

  @override
  String get syncSignOutConfirm => 'Die Daten bleiben auf diesem Gerät, werden aber nicht mehr synchronisiert.';

  @override
  String get syncDeleteAccount => 'Online-Konto löschen';

  @override
  String get syncDeleteAccountMessage =>
      'Das Konto und alle Daten werden vom Server gelöscht. Die Daten dieses Geräts bleiben erhalten. Zur Bestätigung Passwort eingeben.';

  @override
  String get syncAccountDeleted => 'Online-Konto gelöscht';

  @override
  String get syncSessionExpired => 'Sitzung abgelaufen: bitte erneut anmelden.';

  @override
  String get syncSignedIn => 'Angemeldet';

  @override
  String get syncErrInvalidCredentials => 'E-Mail oder Passwort falsch.';

  @override
  String get syncErrEmailTaken => 'Mit dieser E-Mail existiert bereits ein Konto.';

  @override
  String get syncErrInvalidEmail => 'Ungültige E-Mail-Adresse.';

  @override
  String get syncErrWeakPassword => 'Das Passwort muss 8 bis 72 Zeichen haben.';

  @override
  String get syncErrTooMany => 'Zu viele Versuche. In 15 Minuten erneut versuchen.';

  @override
  String get syncErrNetwork => 'Server nicht erreichbar. Adresse und Verbindung prüfen.';

  @override
  String get syncErrNotServer => 'Diese Adresse ist kein TimeLog-Server.';

  @override
  String syncErrOther(String code) {
    return 'Fehler: $code';
  }

  @override
  String get licenses => 'Lizenzen';

  @override
  String get vacationDeletePeriod => 'Zeitraum löschen';

  @override
  String vacationDeletePeriodMessage(String from, String to) {
    return 'Urlaub vom $from bis $to entfernen? Alle Tage des Zeitraums werden wieder normale Arbeitstage; bereits eingegebene Zeiten bleiben erhalten.';
  }

  @override
  String vacationPeriodDeleted(int count) {
    return 'Urlaub entfernt ($count Tag(e))';
  }
}
