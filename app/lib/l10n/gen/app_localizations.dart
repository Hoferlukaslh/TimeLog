import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('de'), Locale('en'), Locale('fr'), Locale('it')];

  /// No description provided for @languageName.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TimeLog'**
  String get appTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get optional;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteConfirmMessage;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorMessage(String message);

  /// No description provided for @nothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHere;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @periodDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get periodDay;

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonth;

  /// No description provided for @periodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYear;

  /// No description provided for @weekNumber.
  ///
  /// In en, this message translates to:
  /// **'Week {number}'**
  String weekNumber(int number);

  /// No description provided for @menuHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get menuHours;

  /// No description provided for @menuJournal.
  ///
  /// In en, this message translates to:
  /// **'Work journal'**
  String get menuJournal;

  /// No description provided for @menuNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get menuNotes;

  /// No description provided for @menuCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get menuCategories;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSettings;

  /// No description provided for @menuExport.
  ///
  /// In en, this message translates to:
  /// **'Export / backup'**
  String get menuExport;

  /// No description provided for @menuAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get menuAbout;

  /// No description provided for @arrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get arrival;

  /// No description provided for @lunchStart.
  ///
  /// In en, this message translates to:
  /// **'Lunch break start'**
  String get lunchStart;

  /// No description provided for @lunchEnd.
  ///
  /// In en, this message translates to:
  /// **'Lunch break end'**
  String get lunchEnd;

  /// No description provided for @departure.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get departure;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @afternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get afternoon;

  /// No description provided for @lunchBreak.
  ///
  /// In en, this message translates to:
  /// **'Lunch break'**
  String get lunchBreak;

  /// No description provided for @worked.
  ///
  /// In en, this message translates to:
  /// **'Worked'**
  String get worked;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Overall balance'**
  String get totalBalance;

  /// No description provided for @clockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock in'**
  String get clockIn;

  /// No description provided for @dayComplete.
  ///
  /// In en, this message translates to:
  /// **'Day complete'**
  String get dayComplete;

  /// No description provided for @dayType.
  ///
  /// In en, this message translates to:
  /// **'Day type'**
  String get dayType;

  /// No description provided for @dayTypeWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get dayTypeWork;

  /// No description provided for @dayTypeVacation.
  ///
  /// In en, this message translates to:
  /// **'Vacation'**
  String get dayTypeVacation;

  /// No description provided for @dayTypeSick.
  ///
  /// In en, this message translates to:
  /// **'Sick / accident'**
  String get dayTypeSick;

  /// No description provided for @dayTypeHoliday.
  ///
  /// In en, this message translates to:
  /// **'Public holiday'**
  String get dayTypeHoliday;

  /// No description provided for @dayTypeCompensation.
  ///
  /// In en, this message translates to:
  /// **'Overtime compensation'**
  String get dayTypeCompensation;

  /// No description provided for @comment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get comment;

  /// No description provided for @clearTime.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearTime;

  /// No description provided for @noEntry.
  ///
  /// In en, this message translates to:
  /// **'No entry'**
  String get noEntry;

  /// No description provided for @deleteDay.
  ///
  /// In en, this message translates to:
  /// **'Delete this day'**
  String get deleteDay;

  /// No description provided for @timeOrderError.
  ///
  /// In en, this message translates to:
  /// **'Times must be in chronological order.'**
  String get timeOrderError;

  /// No description provided for @daysWorked.
  ///
  /// In en, this message translates to:
  /// **'Days worked'**
  String get daysWorked;

  /// No description provided for @tapToSet.
  ///
  /// In en, this message translates to:
  /// **'Tap to set'**
  String get tapToSet;

  /// No description provided for @journalModeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get journalModeAdd;

  /// No description provided for @journalModeView.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get journalModeView;

  /// No description provided for @newEntry.
  ///
  /// In en, this message translates to:
  /// **'New entry'**
  String get newEntry;

  /// No description provided for @editEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get editEntry;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @markdownHint.
  ///
  /// In en, this message translates to:
  /// **'Markdown supported: **bold**, *italic*, # title, - list'**
  String get markdownHint;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Time spent'**
  String get duration;

  /// No description provided for @noDuration.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get noDuration;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @noCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get noCategory;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategories;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @write.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get write;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @totalDuration.
  ///
  /// In en, this message translates to:
  /// **'Total time: {duration}'**
  String totalDuration(String duration);

  /// No description provided for @entriesOfDay.
  ///
  /// In en, this message translates to:
  /// **'Entries of the day'**
  String get entriesOfDay;

  /// No description provided for @saveAndNew.
  ///
  /// In en, this message translates to:
  /// **'Save and add another'**
  String get saveAndNew;

  /// No description provided for @entryAdded.
  ///
  /// In en, this message translates to:
  /// **'Entry added'**
  String get entryAdded;

  /// No description provided for @titleOrContentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title or a content.'**
  String get titleOrContentRequired;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get editNote;

  /// No description provided for @noteText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get noteText;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get addPhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose an image'**
  String get choosePhoto;

  /// No description provided for @addAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get addAudio;

  /// No description provided for @addDrawing.
  ///
  /// In en, this message translates to:
  /// **'Drawing'**
  String get addDrawing;

  /// No description provided for @addDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get addDocument;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @searchNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Search text, title, file, category…'**
  String get searchNotesHint;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get recording;

  /// No description provided for @audioRecorder.
  ///
  /// In en, this message translates to:
  /// **'Audio recording'**
  String get audioRecorder;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get startRecording;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop and save'**
  String get stopRecording;

  /// No description provided for @micPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access was refused.'**
  String get micPermissionDenied;

  /// No description provided for @drawingTitle.
  ///
  /// In en, this message translates to:
  /// **'Drawing'**
  String get drawingTitle;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @clearDrawing.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearDrawing;

  /// No description provided for @eraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get eraser;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get fileName;

  /// No description provided for @saveToDevice.
  ///
  /// In en, this message translates to:
  /// **'Save a copy'**
  String get saveToDevice;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @cannotOpenFile.
  ///
  /// In en, this message translates to:
  /// **'This file cannot be opened: {message}'**
  String cannotOpenFile(String message);

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get categoryName;

  /// No description provided for @categoryColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get categoryColor;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @noCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories yet. Create one with the + button.'**
  String get noCategories;

  /// No description provided for @categoryDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Entries and notes using this category will be kept, without category.'**
  String get categoryDeleteMessage;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name.'**
  String get nameRequired;

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get manageCategories;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @sectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get sectionGeneral;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get languageSystem;

  /// No description provided for @firstDayOfWeek.
  ///
  /// In en, this message translates to:
  /// **'First day of the week'**
  String get firstDayOfWeek;

  /// No description provided for @timeFormat.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get timeFormat;

  /// No description provided for @format24h.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get format24h;

  /// No description provided for @format12h.
  ///
  /// In en, this message translates to:
  /// **'12 hours (AM/PM)'**
  String get format12h;

  /// No description provided for @sectionHours.
  ///
  /// In en, this message translates to:
  /// **'Working time'**
  String get sectionHours;

  /// No description provided for @dailyTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily target'**
  String get dailyTarget;

  /// No description provided for @workDays.
  ///
  /// In en, this message translates to:
  /// **'Working days'**
  String get workDays;

  /// No description provided for @trackingStart.
  ///
  /// In en, this message translates to:
  /// **'Count the balance from'**
  String get trackingStart;

  /// No description provided for @sectionData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get sectionData;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export / backup'**
  String get exportTitle;

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get exportFormat;

  /// No description provided for @exportWhat.
  ///
  /// In en, this message translates to:
  /// **'Data to export'**
  String get exportWhat;

  /// No description provided for @includeAttachments.
  ///
  /// In en, this message translates to:
  /// **'Include attachment files (photos, audio, …)'**
  String get includeAttachments;

  /// No description provided for @exportButton.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportButton;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'Export saved'**
  String get exportDone;

  /// No description provided for @exportCsvInfo.
  ///
  /// In en, this message translates to:
  /// **'CSV: one file per data type, grouped in a ZIP archive.'**
  String get exportCsvInfo;

  /// No description provided for @exportJsonInfo.
  ///
  /// In en, this message translates to:
  /// **'JSON: a single file, which can also be used to restore a backup.'**
  String get exportJsonInfo;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore a JSON backup'**
  String get importBackup;

  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'All current data will be replaced by the backup. Continue?'**
  String get importConfirm;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get importDone;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsData;

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'TimeLog helps you track your working hours, keep a work journal and store notes with photos, audio, drawings and documents. All data stays on your device in a SQLite database.'**
  String get aboutText;

  /// No description provided for @hoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'Hours and minutes'**
  String get hoursMinutes;

  /// No description provided for @absencePart.
  ///
  /// In en, this message translates to:
  /// **'Absence covers'**
  String get absencePart;

  /// No description provided for @absenceFull.
  ///
  /// In en, this message translates to:
  /// **'Whole day'**
  String get absenceFull;

  /// No description provided for @absenceMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get absenceMorning;

  /// No description provided for @absenceAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get absenceAfternoon;

  /// No description provided for @absenceCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom duration'**
  String get absenceCustom;

  /// No description provided for @absenceDuration.
  ///
  /// In en, this message translates to:
  /// **'Absence duration'**
  String get absenceDuration;

  /// No description provided for @partialAbsenceHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your times for the part of the day you worked.'**
  String get partialAbsenceHint;

  /// No description provided for @notCredited.
  ///
  /// In en, this message translates to:
  /// **'not credited (taken from the balance)'**
  String get notCredited;

  /// No description provided for @totalCounted.
  ///
  /// In en, this message translates to:
  /// **'Total counted'**
  String get totalCounted;

  /// No description provided for @addAbsence.
  ///
  /// In en, this message translates to:
  /// **'Absence over several days'**
  String get addAbsence;

  /// No description provided for @absencePeriod.
  ///
  /// In en, this message translates to:
  /// **'Choose the dates'**
  String get absencePeriod;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @onlyWorkDaysInfo.
  ///
  /// In en, this message translates to:
  /// **'Only working days are changed. Times already entered are kept.'**
  String get onlyWorkDaysInfo;

  /// No description provided for @absenceApplied.
  ///
  /// In en, this message translates to:
  /// **'{count} day(s) updated'**
  String absenceApplied(int count);

  /// No description provided for @fullDayAbsence.
  ///
  /// In en, this message translates to:
  /// **'Whole-day absence: {type}'**
  String fullDayAbsence(String type);

  /// No description provided for @menuVacation.
  ///
  /// In en, this message translates to:
  /// **'Vacation'**
  String get menuVacation;

  /// No description provided for @bookVacation.
  ///
  /// In en, this message translates to:
  /// **'Book vacation'**
  String get bookVacation;

  /// No description provided for @vacationRemaining.
  ///
  /// In en, this message translates to:
  /// **'Vacation days left'**
  String get vacationRemaining;

  /// No description provided for @vacationEntitlement.
  ///
  /// In en, this message translates to:
  /// **'Vacation entitlement for the year'**
  String get vacationEntitlement;

  /// No description provided for @vacationDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'Default value from the settings, tap to change for this year'**
  String get vacationDefaultHint;

  /// No description provided for @vacationCarryOver.
  ///
  /// In en, this message translates to:
  /// **'Carried over from last year'**
  String get vacationCarryOver;

  /// No description provided for @vacationUsePrevious.
  ///
  /// In en, this message translates to:
  /// **'Use the balance of {year}: {days} d.'**
  String vacationUsePrevious(int year, String days);

  /// No description provided for @vacationTaken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get vacationTaken;

  /// No description provided for @vacationPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get vacationPlanned;

  /// No description provided for @vacationList.
  ///
  /// In en, this message translates to:
  /// **'Vacation days of the year'**
  String get vacationList;

  /// No description provided for @vacationExceeded.
  ///
  /// In en, this message translates to:
  /// **'More vacation booked than available.'**
  String get vacationExceeded;

  /// No description provided for @vacationDaysPerYear.
  ///
  /// In en, this message translates to:
  /// **'Vacation days per year'**
  String get vacationDaysPerYear;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{days} d.'**
  String daysCount(String days);

  /// No description provided for @workDaysInRange.
  ///
  /// In en, this message translates to:
  /// **'{count} working day(s) in this period'**
  String workDaysInRange(int count);

  /// No description provided for @vacationPreview.
  ///
  /// In en, this message translates to:
  /// **'Uses {days} vacation day(s) · left afterwards: {left}'**
  String vacationPreview(String days, String left);

  /// No description provided for @toolPen.
  ///
  /// In en, this message translates to:
  /// **'Pen'**
  String get toolPen;

  /// No description provided for @toolLine.
  ///
  /// In en, this message translates to:
  /// **'Straight line'**
  String get toolLine;

  /// No description provided for @toolArrow.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get toolArrow;

  /// No description provided for @toolRect.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get toolRect;

  /// No description provided for @toolCircle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get toolCircle;

  /// No description provided for @toolArc.
  ///
  /// In en, this message translates to:
  /// **'Arc'**
  String get toolArc;

  /// No description provided for @toolFill.
  ///
  /// In en, this message translates to:
  /// **'Fill area'**
  String get toolFill;

  /// No description provided for @toolObjectEraser.
  ///
  /// In en, this message translates to:
  /// **'Erase whole shapes'**
  String get toolObjectEraser;

  /// No description provided for @arcHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the dot to bend the arc'**
  String get arcHint;

  /// No description provided for @pressureSim.
  ///
  /// In en, this message translates to:
  /// **'Simulated pressure: faster strokes are thinner'**
  String get pressureSim;

  /// No description provided for @pressureShort.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get pressureShort;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @discardDrawingTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get discardDrawingTitle;

  /// No description provided for @discardDrawingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your changes to the drawing will be lost. To keep them, use the ✓ button at the top right.'**
  String get discardDrawingMessage;

  /// No description provided for @discardDrawing.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving'**
  String get discardDrawing;

  /// No description provided for @keepDrawing.
  ///
  /// In en, this message translates to:
  /// **'Keep drawing'**
  String get keepDrawing;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @menuSync.
  ///
  /// In en, this message translates to:
  /// **'Synchronization'**
  String get menuSync;

  /// No description provided for @syncIntro.
  ///
  /// In en, this message translates to:
  /// **'Synchronize all your data between several devices (phone, computer) through your TimeLog server. The app keeps working offline: changes are sent as soon as the server can be reached.'**
  String get syncIntro;

  /// No description provided for @syncServer.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get syncServer;

  /// No description provided for @syncServerHint.
  ///
  /// In en, this message translates to:
  /// **'https://timelog.example.com'**
  String get syncServerHint;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show the password'**
  String get showPassword;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @syncMergeInfo.
  ///
  /// In en, this message translates to:
  /// **'The data of this device will be merged with the data of the account.'**
  String get syncMergeInfo;

  /// No description provided for @syncInsecure.
  ///
  /// In en, this message translates to:
  /// **'Unencrypted connection (http): the password and the data are sent in clear text. Use https:// outside your home network.'**
  String get syncInsecure;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Synchronize now'**
  String get syncNow;

  /// No description provided for @syncLast.
  ///
  /// In en, this message translates to:
  /// **'Last synchronization: {time}'**
  String syncLast(String time);

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'Not synchronized yet'**
  String get syncNever;

  /// No description provided for @syncRunning.
  ///
  /// In en, this message translates to:
  /// **'Synchronizing…'**
  String get syncRunning;

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'Server not reachable: changes will be sent later.'**
  String get syncOffline;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'{count} change(s) waiting to be sent'**
  String syncPending(int count);

  /// No description provided for @syncUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Everything is sent'**
  String get syncUpToDate;

  /// No description provided for @syncAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get syncAccount;

  /// No description provided for @syncSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'The data stays on this device but will not be synchronized anymore.'**
  String get syncSignOutConfirm;

  /// No description provided for @syncDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete the online account'**
  String get syncDeleteAccount;

  /// No description provided for @syncDeleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'The account and all its data will be deleted from the server. The data of this device is kept. Enter your password to confirm.'**
  String get syncDeleteAccountMessage;

  /// No description provided for @syncAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Online account deleted'**
  String get syncAccountDeleted;

  /// No description provided for @syncSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired: please sign in again.'**
  String get syncSessionExpired;

  /// No description provided for @syncSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get syncSignedIn;

  /// No description provided for @syncErrInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong e-mail or password.'**
  String get syncErrInvalidCredentials;

  /// No description provided for @syncErrEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with this e-mail.'**
  String get syncErrEmailTaken;

  /// No description provided for @syncErrInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid e-mail address.'**
  String get syncErrInvalidEmail;

  /// No description provided for @syncErrWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'The password must have 8 to 72 characters.'**
  String get syncErrWeakPassword;

  /// No description provided for @syncErrTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in 15 minutes.'**
  String get syncErrTooMany;

  /// No description provided for @syncErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Server not reachable. Check the address and the connection.'**
  String get syncErrNetwork;

  /// No description provided for @syncErrNotServer.
  ///
  /// In en, this message translates to:
  /// **'This address is not a TimeLog server.'**
  String get syncErrNotServer;

  /// No description provided for @syncErrOther.
  ///
  /// In en, this message translates to:
  /// **'Error: {code}'**
  String syncErrOther(String code);

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// No description provided for @vacationDeletePeriod.
  ///
  /// In en, this message translates to:
  /// **'Delete period'**
  String get vacationDeletePeriod;

  /// No description provided for @vacationDeletePeriodMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove the vacation from {from} to {to}? All days of the period become normal working days; times already entered are kept.'**
  String vacationDeletePeriodMessage(String from, String to);

  /// No description provided for @vacationPeriodDeleted.
  ///
  /// In en, this message translates to:
  /// **'Vacation removed ({count} day(s))'**
  String vacationPeriodDeleted(int count);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
