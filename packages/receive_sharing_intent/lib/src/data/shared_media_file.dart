part of receive_sharing_intent;

/// SuperNote fork (S321 / E53): why the native side rejected an entry.
///
/// The entry still reaches Dart (so the user can be told), but it carries an
/// EMPTY `path` and no file behind it.
enum SharedMediaIntakeError {
  /// The stream could not be opened/copied (e.g. `content://` without grant).
  unreadable('unreadable'),

  /// The copy was aborted because of the hard ceiling (100 MB per file/intent).
  tooLarge('tooLarge');

  final String value;

  const SharedMediaIntakeError(this.value);

  /// Unknown/missing values are tolerated (never throws).
  static SharedMediaIntakeError? fromValue(Object? value) {
    if (value is! String) return null;
    for (final e in SharedMediaIntakeError.values) {
      if (e.value == value) return e;
    }
    return null;
  }
}

class SharedMediaFile {
  /// Shared file path, url or the text
  /// NOTE. All files are copied to a temp cache folder
  final String path;

  /// Video thumbnail (fork: always null — thumbnails are no longer generated)
  final String? thumbnail;

  /// Video duration in milliseconds (fork: always null)
  final int? duration;

  /// Shared media type
  final SharedMediaType type;

  /// Mime type of the file.
  /// i.e. image/jpeg, video/mp4, text/plain
  final String? mimeType;

  /// Post message iOS ONLY (fork: also the Android `EXTRA_TEXT` when a stream
  /// is shared together with text)
  final String? message;

  /// SuperNote fork (S321): non-null when the native side rejected the entry.
  final SharedMediaIntakeError? intakeError;

  SharedMediaFile({
    required this.path,
    required this.type,
    this.thumbnail,
    this.duration,
    this.mimeType,
    this.message,
    this.intakeError,
  });

  /// Tolerant: a missing/`null` path becomes `''` (upstream threw a TypeError)
  /// and an unknown type falls back to [SharedMediaType.file].
  SharedMediaFile.fromMap(Map<String, dynamic> json)
      : path = (json['path'] as String?) ?? '',
        thumbnail = json['thumbnail'] as String?,
        duration = json['duration'] as int?,
        type = SharedMediaType.fromValue(json['type'] as String?),
        mimeType = json['mimeType'] as String?,
        message = json['message'] as String?,
        intakeError = SharedMediaIntakeError.fromValue(json['error']);

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'thumbnail': thumbnail,
      'duration': duration,
      'type': type.value,
      'mimeType': mimeType,
      'message': message,
      if (intakeError != null) 'error': intakeError!.value,
    };
  }
}

enum SharedMediaType {
  image('image'),
  video('video'),
  text('text'),
  file('file'),
  url('url');

  final String value;

  const SharedMediaType(this.value);

  /// Tolerant: unknown/missing values fall back to [SharedMediaType.file]
  /// (upstream threw a StateError from `firstWhere`).
  static SharedMediaType fromValue(String? value) {
    for (final e in SharedMediaType.values) {
      if (e.value == value) return e;
    }
    return SharedMediaType.file;
  }
}
