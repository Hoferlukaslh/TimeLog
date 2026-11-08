import 'package:flutter/material.dart';

import '../drawing/drawing.dart';
import '../utils/dates.dart';

class Category {
  final int? id;
  final String name;
  final int color;

  const Category({this.id, required this.name, required this.color});

  Color get colorValue => Color(color);

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'color': color};

  factory Category.fromMap(Map<String, Object?> m) =>
      Category(id: m['id'] as int?, name: m['name'] as String, color: m['color'] as int);
}

enum DayType { work, vacation, sick, holiday, compensation }

/// Which part of the day an absence covers.
enum AbsencePart { full, morning, afternoon, custom }

/// One day of time tracking. Times are stored as minutes after midnight.
class TimeEntry {
  final int? id;
  final DateTime date;
  final DayType dayType;

  /// Part of the day covered by the absence (ignored for [DayType.work]).
  final AbsencePart absencePart;

  /// Absence duration in minutes when [absencePart] is [AbsencePart.custom].
  final int? absenceMinutes;
  final int? arrival;
  final int? lunchStart;
  final int? lunchEnd;
  final int? departure;
  final String comment;

  const TimeEntry({
    this.id,
    required this.date,
    this.dayType = DayType.work,
    this.absencePart = AbsencePart.full,
    this.absenceMinutes,
    this.arrival,
    this.lunchStart,
    this.lunchEnd,
    this.departure,
    this.comment = '',
  });

  TimeEntry copyWith({
    int? id,
    DateTime? date,
    DayType? dayType,
    AbsencePart? absencePart,
    int? Function()? absenceMinutes,
    int? Function()? arrival,
    int? Function()? lunchStart,
    int? Function()? lunchEnd,
    int? Function()? departure,
    String? comment,
  }) => TimeEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    dayType: dayType ?? this.dayType,
    absencePart: absencePart ?? this.absencePart,
    absenceMinutes: absenceMinutes != null ? absenceMinutes() : this.absenceMinutes,
    arrival: arrival != null ? arrival() : this.arrival,
    lunchStart: lunchStart != null ? lunchStart() : this.lunchStart,
    lunchEnd: lunchEnd != null ? lunchEnd() : this.lunchEnd,
    departure: departure != null ? departure() : this.departure,
    comment: comment ?? this.comment,
  );

  static int _span(int? a, int? b) {
    if (a == null || b == null) return 0;
    final d = b - a;
    return d > 0 ? d : 0;
  }

  /// Minutes worked in the morning (arrival -> lunch start).
  /// Without lunch break: arrival -> departure.
  int get morningMinutes {
    if (lunchStart == null && lunchEnd == null) return _span(arrival, departure);
    return _span(arrival, lunchStart);
  }

  /// Minutes worked in the afternoon (lunch end -> departure).
  int get afternoonMinutes {
    if (lunchStart == null && lunchEnd == null) return 0;
    return _span(lunchEnd, departure);
  }

  int get lunchMinutes => _span(lunchStart, lunchEnd);

  int get workedMinutes => morningMinutes + afternoonMinutes;

  bool get isAbsence => dayType != DayType.work;

  /// Absence for the whole day: no clock times to enter.
  bool get isFullAbsence => isAbsence && absencePart == AbsencePart.full;

  /// Absence for the morning or the afternoon: only arrival and departure of
  /// the worked half are entered.
  bool get isHalfDayAbsence =>
      isAbsence && (absencePart == AbsencePart.morning || absencePart == AbsencePart.afternoon);

  /// Clock steps used this day: 0 arrival, 1 lunch start, 2 lunch end, 3 departure.
  List<int> get clockSteps => isFullAbsence
      ? const []
      : isHalfDayAbsence
      ? const [0, 3]
      : const [0, 1, 2, 3];

  /// Time of clock step [i] (see [clockSteps]).
  int? timeAt(int i) => switch (i) {
    0 => arrival,
    1 => lunchStart,
    2 => lunchEnd,
    _ => departure,
  };

  /// Copy with clock step [i] set to [minutes] (null clears it).
  TimeEntry withTime(int i, int? minutes) => switch (i) {
    0 => copyWith(arrival: () => minutes),
    1 => copyWith(lunchStart: () => minutes),
    2 => copyWith(lunchEnd: () => minutes),
    _ => copyWith(departure: () => minutes),
  };

  /// Next clock step to fill, or null when the day is complete.
  int? get nextClockStep {
    for (final i in clockSteps) {
      if (timeAt(i) == null) return i;
    }
    return null;
  }

  /// Copy with another absence part; half days drop the lunch break.
  TimeEntry withAbsencePart(AbsencePart part) {
    final e = copyWith(absencePart: part);
    return e.isHalfDayAbsence ? e.copyWith(lunchStart: () => null, lunchEnd: () => null) : e;
  }

  /// Whether the entered times are in chronological order.
  bool get isChronological {
    final v = [arrival, lunchStart, lunchEnd, departure].whereType<int>().toList();
    for (var i = 1; i < v.length; i++) {
      if (v[i] < v[i - 1]) return false;
    }
    return true;
  }

  /// Minutes of absence for a day whose target is [target].
  int absenceDuration(int target) {
    if (!isAbsence) return 0;
    switch (absencePart) {
      case AbsencePart.full:
        return target;
      case AbsencePart.morning:
        return target ~/ 2;
      case AbsencePart.afternoon:
        return target - target ~/ 2;
      case AbsencePart.custom:
        return (absenceMinutes ?? 0).clamp(0, target);
    }
  }

  /// Minutes credited for the absence. Vacation, sickness and public
  /// holidays are credited; overtime compensation is not (it uses the balance).
  int creditedMinutes(int target) => dayType == DayType.compensation ? 0 : absenceDuration(target);

  /// Clocked time (if any) + credited absence time.
  int effectiveMinutes(int target) => (isFullAbsence ? 0 : workedMinutes) + creditedMinutes(target);

  Map<String, Object?> toMap() => {
    'id': id,
    'date': Dates.key(date),
    'day_type': dayType.name,
    'absence_part': absencePart.name,
    'absence_minutes': absenceMinutes,
    'arrival': arrival,
    'lunch_start': lunchStart,
    'lunch_end': lunchEnd,
    'departure': departure,
    'comment': comment,
  };

  factory TimeEntry.fromMap(Map<String, Object?> m) => TimeEntry(
    id: m['id'] as int?,
    date: Dates.parseKey(m['date'] as String),
    dayType: DayType.values.firstWhere((e) => e.name == m['day_type'], orElse: () => DayType.work),
    absencePart: AbsencePart.values.firstWhere((e) => e.name == m['absence_part'], orElse: () => AbsencePart.full),
    absenceMinutes: m['absence_minutes'] as int?,
    arrival: m['arrival'] as int?,
    lunchStart: m['lunch_start'] as int?,
    lunchEnd: m['lunch_end'] as int?,
    departure: m['departure'] as int?,
    comment: (m['comment'] as String?) ?? '',
  );
}

class JournalEntry {
  final int? id;
  final DateTime date;
  final String title;
  final String content;
  final int? durationMinutes;
  final int? categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalEntry({
    this.id,
    required this.date,
    this.title = '',
    this.content = '',
    this.durationMinutes,
    this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'date': Dates.key(date),
    'title': title,
    'content': content,
    'duration_minutes': durationMinutes,
    'category_id': categoryId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory JournalEntry.fromMap(Map<String, Object?> m) => JournalEntry(
    id: m['id'] as int?,
    date: Dates.parseKey(m['date'] as String),
    title: (m['title'] as String?) ?? '',
    content: (m['content'] as String?) ?? '',
    durationMinutes: m['duration_minutes'] as int?,
    categoryId: m['category_id'] as int?,
    createdAt: DateTime.parse(m['created_at'] as String),
    updatedAt: DateTime.parse(m['updated_at'] as String),
  );
}

enum AttachmentKind { photo, audio, drawing, document }

class Attachment {
  final int? id;
  final int noteId;
  final AttachmentKind kind;
  final String fileName;
  final String? mime;
  final int size;
  final DateTime createdAt;

  const Attachment({
    this.id,
    required this.noteId,
    required this.kind,
    required this.fileName,
    this.mime,
    required this.size,
    required this.createdAt,
  });

  /// Vector drawing (editable); converted to an image only when exported.
  bool get isVectorDrawing => kind == AttachmentKind.drawing && mime == kDrawingMime;

  /// Bitmap image (photos, and drawings made with older versions).
  bool get isImage => kind == AttachmentKind.photo || (kind == AttachmentKind.drawing && !isVectorDrawing);

  /// Shown as a thumbnail in the note.
  bool get isVisual => isImage || isVectorDrawing;

  /// File name used when the attachment is exported (drawings become PNG).
  String get exportFileName => isVectorDrawing ? '$fileName.png' : fileName;

  Map<String, Object?> toMap() => {
    'id': id,
    'note_id': noteId,
    'kind': kind.name,
    'file_name': fileName,
    'mime': mime,
    'size': size,
    'created_at': createdAt.toIso8601String(),
  };

  factory Attachment.fromMap(Map<String, Object?> m) => Attachment(
    id: m['id'] as int?,
    noteId: m['note_id'] as int,
    kind: AttachmentKind.values.firstWhere((e) => e.name == m['kind'], orElse: () => AttachmentKind.document),
    fileName: m['file_name'] as String,
    mime: m['mime'] as String?,
    size: m['size'] as int,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

class Note {
  final int? id;
  final DateTime date;
  final String title;
  final String content;
  final int? categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Attachment> attachments;

  const Note({
    this.id,
    required this.date,
    this.title = '',
    this.content = '',
    this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    this.attachments = const [],
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'date': Dates.key(date),
    'title': title,
    'content': content,
    'category_id': categoryId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Note.fromMap(Map<String, Object?> m, [List<Attachment> att = const []]) => Note(
    id: m['id'] as int?,
    date: Dates.parseKey(m['date'] as String),
    title: (m['title'] as String?) ?? '',
    content: (m['content'] as String?) ?? '',
    categoryId: m['category_id'] as int?,
    createdAt: DateTime.parse(m['created_at'] as String),
    updatedAt: DateTime.parse(m['updated_at'] as String),
    attachments: att,
  );
}
