// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get appTitle => 'TimeLog';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get today => 'Today';

  @override
  String get optional => 'optional';

  @override
  String get deleteConfirmTitle => 'Delete?';

  @override
  String get deleteConfirmMessage => 'This action cannot be undone.';

  @override
  String get saved => 'Saved';

  @override
  String errorMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get nothingHere => 'Nothing here yet';

  @override
  String get untitled => 'Untitled';

  @override
  String get periodDay => 'Day';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodYear => 'Year';

  @override
  String weekNumber(int number) {
    return 'Week $number';
  }

  @override
  String get menuHours => 'Hours';

  @override
  String get menuJournal => 'Work journal';

  @override
  String get menuNotes => 'Notes';

  @override
  String get menuCategories => 'Categories';

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuExport => 'Export / backup';

  @override
  String get menuAbout => 'About';

  @override
  String get arrival => 'Arrival';

  @override
  String get lunchStart => 'Lunch break start';

  @override
  String get lunchEnd => 'Lunch break end';

  @override
  String get departure => 'Departure';

  @override
  String get morning => 'Morning';

  @override
  String get afternoon => 'Afternoon';

  @override
  String get lunchBreak => 'Lunch break';

  @override
  String get worked => 'Worked';

  @override
  String get target => 'Target';

  @override
  String get balance => 'Balance';

  @override
  String get totalBalance => 'Overall balance';

  @override
  String get clockIn => 'Clock in';

  @override
  String get dayComplete => 'Day complete';

  @override
  String get dayType => 'Day type';

  @override
  String get dayTypeWork => 'Work';

  @override
  String get dayTypeVacation => 'Vacation';

  @override
  String get dayTypeSick => 'Sick / accident';

  @override
  String get dayTypeHoliday => 'Public holiday';

  @override
  String get dayTypeCompensation => 'Overtime compensation';

  @override
  String get comment => 'Comment';

  @override
  String get clearTime => 'Clear';

  @override
  String get noEntry => 'No entry';

  @override
  String get deleteDay => 'Delete this day';

  @override
  String get timeOrderError => 'Times must be in chronological order.';

  @override
  String get daysWorked => 'Days worked';

  @override
  String get tapToSet => 'Tap to set';

  @override
  String get journalModeAdd => 'Add';

  @override
  String get journalModeView => 'Browse';

  @override
  String get newEntry => 'New entry';

  @override
  String get editEntry => 'Edit entry';

  @override
  String get title => 'Title';

  @override
  String get content => 'Content';

  @override
  String get markdownHint => 'Markdown supported: **bold**, *italic*, # title, - list';

  @override
  String get duration => 'Time spent';

  @override
  String get noDuration => 'Not specified';

  @override
  String get category => 'Category';

  @override
  String get noCategory => 'No category';

  @override
  String get allCategories => 'All categories';

  @override
  String get date => 'Date';

  @override
  String get write => 'Write';

  @override
  String get preview => 'Preview';

  @override
  String totalDuration(String duration) {
    return 'Total time: $duration';
  }

  @override
  String get entriesOfDay => 'Entries of the day';

  @override
  String get saveAndNew => 'Save and add another';

  @override
  String get entryAdded => 'Entry added';

  @override
  String get titleOrContentRequired => 'Please enter a title or a content.';

  @override
  String get newNote => 'New note';

  @override
  String get editNote => 'Note';

  @override
  String get noteText => 'Text';

  @override
  String get addPhoto => 'Photo';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get choosePhoto => 'Choose an image';

  @override
  String get addAudio => 'Audio';

  @override
  String get addDrawing => 'Drawing';

  @override
  String get addDocument => 'Document';

  @override
  String get attachments => 'Attachments';

  @override
  String get searchNotesHint => 'Search text, title, file, category…';

  @override
  String get recording => 'Recording…';

  @override
  String get audioRecorder => 'Audio recording';

  @override
  String get startRecording => 'Start recording';

  @override
  String get stopRecording => 'Stop and save';

  @override
  String get micPermissionDenied => 'Microphone access was refused.';

  @override
  String get drawingTitle => 'Drawing';

  @override
  String get undo => 'Undo';

  @override
  String get clearDrawing => 'Clear all';

  @override
  String get eraser => 'Eraser';

  @override
  String get open => 'Open';

  @override
  String get rename => 'Rename';

  @override
  String get fileName => 'File name';

  @override
  String get saveToDevice => 'Save a copy';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get noResults => 'No results';

  @override
  String cannotOpenFile(String message) {
    return 'This file cannot be opened: $message';
  }

  @override
  String get categoryName => 'Name';

  @override
  String get categoryColor => 'Color';

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get noCategories => 'No categories yet. Create one with the + button.';

  @override
  String get categoryDeleteMessage => 'Entries and notes using this category will be kept, without category.';

  @override
  String get nameRequired => 'Please enter a name.';

  @override
  String get manageCategories => 'Manage categories';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accentColor => 'Accent color';

  @override
  String get sectionGeneral => 'General';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System language';

  @override
  String get firstDayOfWeek => 'First day of the week';

  @override
  String get timeFormat => 'Time format';

  @override
  String get format24h => '24 hours';

  @override
  String get format12h => '12 hours (AM/PM)';

  @override
  String get sectionHours => 'Working time';

  @override
  String get dailyTarget => 'Daily target';

  @override
  String get workDays => 'Working days';

  @override
  String get trackingStart => 'Count the balance from';

  @override
  String get sectionData => 'Data';

  @override
  String get exportTitle => 'Export / backup';

  @override
  String get exportFormat => 'Format';

  @override
  String get exportWhat => 'Data to export';

  @override
  String get includeAttachments => 'Include attachment files (photos, audio, …)';

  @override
  String get exportButton => 'Export';

  @override
  String get exportDone => 'Export saved';

  @override
  String get exportCsvInfo => 'CSV: one file per data type, grouped in a ZIP archive.';

  @override
  String get exportJsonInfo => 'JSON: a single file, which can also be used to restore a backup.';

  @override
  String get importBackup => 'Restore a JSON backup';

  @override
  String get importConfirm => 'All current data will be replaced by the backup. Continue?';

  @override
  String get importDone => 'Backup restored';

  @override
  String get settingsData => 'Settings';

  @override
  String get aboutText =>
      'TimeLog helps you track your working hours, keep a work journal and store notes with photos, audio, drawings and documents. All data stays on your device in a SQLite database.';

  @override
  String get hoursMinutes => 'Hours and minutes';

  @override
  String get absencePart => 'Absence covers';

  @override
  String get absenceFull => 'Whole day';

  @override
  String get absenceMorning => 'Morning';

  @override
  String get absenceAfternoon => 'Afternoon';

  @override
  String get absenceCustom => 'Custom duration';

  @override
  String get absenceDuration => 'Absence duration';

  @override
  String get partialAbsenceHint => 'Enter your times for the part of the day you worked.';

  @override
  String get notCredited => 'not credited (taken from the balance)';

  @override
  String get totalCounted => 'Total counted';

  @override
  String get addAbsence => 'Absence over several days';

  @override
  String get absencePeriod => 'Choose the dates';

  @override
  String get apply => 'Apply';

  @override
  String get onlyWorkDaysInfo => 'Only working days are changed. Times already entered are kept.';

  @override
  String absenceApplied(int count) {
    return '$count day(s) updated';
  }

  @override
  String fullDayAbsence(String type) {
    return 'Whole-day absence: $type';
  }

  @override
  String get menuVacation => 'Vacation';

  @override
  String get bookVacation => 'Book vacation';

  @override
  String get vacationRemaining => 'Vacation days left';

  @override
  String get vacationEntitlement => 'Vacation entitlement for the year';

  @override
  String get vacationDefaultHint => 'Default value from the settings, tap to change for this year';

  @override
  String get vacationCarryOver => 'Carried over from last year';

  @override
  String vacationUsePrevious(int year, String days) {
    return 'Use the balance of $year: $days d.';
  }

  @override
  String get vacationTaken => 'Taken';

  @override
  String get vacationPlanned => 'Planned';

  @override
  String get vacationList => 'Vacation days of the year';

  @override
  String get vacationExceeded => 'More vacation booked than available.';

  @override
  String get vacationDaysPerYear => 'Vacation days per year';

  @override
  String daysCount(String days) {
    return '$days d.';
  }

  @override
  String workDaysInRange(int count) {
    return '$count working day(s) in this period';
  }

  @override
  String vacationPreview(String days, String left) {
    return 'Uses $days vacation day(s) · left afterwards: $left';
  }

  @override
  String get toolPen => 'Pen';

  @override
  String get toolLine => 'Straight line';

  @override
  String get toolArrow => 'Arrow';

  @override
  String get toolRect => 'Rectangle';

  @override
  String get toolCircle => 'Circle';

  @override
  String get toolArc => 'Arc';

  @override
  String get toolFill => 'Fill area';

  @override
  String get toolObjectEraser => 'Erase whole shapes';

  @override
  String get arcHint => 'Drag the dot to bend the arc';

  @override
  String get pressureSim => 'Simulated pressure: faster strokes are thinner';

  @override
  String get pressureShort => 'Pressure';

  @override
  String get redo => 'Redo';

  @override
  String get discardDrawingTitle => 'Leave without saving?';

  @override
  String get discardDrawingMessage =>
      'Your changes to the drawing will be lost. To keep them, use the ✓ button at the top right.';

  @override
  String get discardDrawing => 'Leave without saving';

  @override
  String get keepDrawing => 'Keep drawing';

  @override
  String get author => 'Author';

  @override
  String get contact => 'Contact';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get sourceCode => 'Source code';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get menuSync => 'Synchronization';

  @override
  String get syncIntro =>
      'Synchronize all your data between several devices (phone, computer) through your TimeLog server. The app keeps working offline: changes are sent as soon as the server can be reached.';

  @override
  String get syncServer => 'Server address';

  @override
  String get syncServerHint => 'https://timelog.example.com';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Show the password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Create an account';

  @override
  String get signOut => 'Sign out';

  @override
  String get syncMergeInfo => 'The data of this device will be merged with the data of the account.';

  @override
  String get syncInsecure =>
      'Unencrypted connection (http): the password and the data are sent in clear text. Use https:// outside your home network.';

  @override
  String get syncNow => 'Synchronize now';

  @override
  String syncLast(String time) {
    return 'Last synchronization: $time';
  }

  @override
  String get syncNever => 'Not synchronized yet';

  @override
  String get syncRunning => 'Synchronizing…';

  @override
  String get syncOffline => 'Server not reachable: changes will be sent later.';

  @override
  String syncPending(int count) {
    return '$count change(s) waiting to be sent';
  }

  @override
  String get syncUpToDate => 'Everything is sent';

  @override
  String get syncAccount => 'Account';

  @override
  String get syncSignOutConfirm => 'The data stays on this device but will not be synchronized anymore.';

  @override
  String get syncDeleteAccount => 'Delete the online account';

  @override
  String get syncDeleteAccountMessage =>
      'The account and all its data will be deleted from the server. The data of this device is kept. Enter your password to confirm.';

  @override
  String get syncAccountDeleted => 'Online account deleted';

  @override
  String get syncSessionExpired => 'Session expired: please sign in again.';

  @override
  String get syncSignedIn => 'Signed in';

  @override
  String get syncErrInvalidCredentials => 'Wrong e-mail or password.';

  @override
  String get syncErrEmailTaken => 'An account already exists with this e-mail.';

  @override
  String get syncErrInvalidEmail => 'Invalid e-mail address.';

  @override
  String get syncErrWeakPassword => 'The password must have 8 to 72 characters.';

  @override
  String get syncErrTooMany => 'Too many attempts. Try again in 15 minutes.';

  @override
  String get syncErrNetwork => 'Server not reachable. Check the address and the connection.';

  @override
  String get syncErrNotServer => 'This address is not a TimeLog server.';

  @override
  String syncErrOther(String code) {
    return 'Error: $code';
  }

  @override
  String get licenses => 'Licenses';

  @override
  String get vacationDeletePeriod => 'Delete period';

  @override
  String vacationDeletePeriodMessage(String from, String to) {
    return 'Remove the vacation from $from to $to? All days of the period become normal working days; times already entered are kept.';
  }

  @override
  String vacationPeriodDeleted(int count) {
    return 'Vacation removed ($count day(s))';
  }
}
