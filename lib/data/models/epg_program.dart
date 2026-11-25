/// A single broadcast program entry in the Electronic Program Guide (EPG).
class EpgProgram {
  const EpgProgram({
    required this.id,
    required this.channelId,
    required this.title,
    required this.description,
    required this.category,
    required this.start,
    required this.stop,
    this.episode,
    this.rating,
    this.isEstimated = false,
  });

  final String id;
  final String channelId;
  final String title;
  final String description;
  final String category;
  final DateTime start;
  final DateTime stop;
  final String? episode;
  final String? rating;

  /// Whether this program entry was estimated or synthesized.
  /// If true, show times, durations, and progress are omitted from UI.
  final bool isEstimated;

  Duration get duration => isEstimated ? Duration.zero : stop.difference(start);

  /// Checks if the program is currently on the air.
  bool isLive([DateTime? now]) {
    final current = now ?? DateTime.now();
    return !current.isBefore(start) && current.isBefore(stop);
  }

  /// Checks if the program has already finished.
  bool isPast([DateTime? now]) {
    final current = now ?? DateTime.now();
    return !current.isBefore(stop);
  }

  /// Checks if the program is upcoming.
  bool isUpcoming([DateTime? now]) {
    final current = now ?? DateTime.now();
    return current.isBefore(start);
  }

  /// Returns playback progress in [0.0, 1.0].
  /// Returns 0.0 if estimated.
  double progress([DateTime? now]) {
    if (isEstimated) return 0.0;
    final current = now ?? DateTime.now();
    if (current.isBefore(start)) return 0.0;
    if (!current.isBefore(stop)) return 1.0;
    final totalMs = stop.difference(start).inMilliseconds;
    if (totalMs <= 0) return 1.0;
    final elapsedMs = current.difference(start).inMilliseconds;
    return (elapsedMs / totalMs).clamp(0.0, 1.0);
  }

  /// Time remaining until the show finishes.
  /// Returns Duration.zero if estimated.
  Duration remaining([DateTime? now]) {
    if (isEstimated) return Duration.zero;
    final current = now ?? DateTime.now();
    if (!current.isBefore(stop)) return Duration.zero;
    return stop.difference(current);
  }

  /// Time elapsed since the show began.
  /// Returns Duration.zero if estimated.
  Duration elapsed([DateTime? now]) {
    if (isEstimated) return Duration.zero;
    final current = now ?? DateTime.now();
    if (current.isBefore(start)) return Duration.zero;
    if (!current.isBefore(stop)) return duration;
    return current.difference(start);
  }

  /// Human-friendly 24-hour time range, e.g. "14:00 – 15:30".
  /// Returns empty string if fake or estimated.
  String get timeRange =>
      isEstimated ? '' : '${_formatTime(start)} – ${_formatTime(stop)}';

  /// Human-friendly start time, e.g. "14:00".
  /// Returns empty string if fake or estimated.
  String get startTimeLabel => isEstimated ? '' : _formatTime(start);

  /// Human-friendly stop time, e.g. "15:30".
  /// Returns empty string if fake or estimated.
  String get stopTimeLabel => isEstimated ? '' : _formatTime(stop);

  /// Friendly remaining string, e.g. "24m remaining" or "Ending now".
  /// Returns empty string if fake or estimated.
  String remainingLabel([DateTime? now]) {
    if (isEstimated) return '';
    final rem = remaining(now);
    if (rem.inMinutes <= 0) return 'Ending now';
    if (rem.inHours > 0) {
      final hours = rem.inHours;
      final mins = rem.inMinutes % 60;
      return mins > 0 ? '${hours}h ${mins}m left' : '${hours}h left';
    }
    return '${rem.inMinutes}m left';
  }

  /// Friendly elapsed string, e.g. "15m in".
  /// Returns empty string if fake or estimated.
  String elapsedLabel([DateTime? now]) {
    if (isEstimated) return '';
    final el = elapsed(now);
    if (el.inMinutes <= 0) return 'Just started';
    if (el.inHours > 0) {
      final hours = el.inHours;
      final mins = el.inMinutes % 60;
      return mins > 0 ? '${hours}h ${mins}m in' : '${hours}h in';
    }
    return '${el.inMinutes}m in';
  }

  /// Duration string, e.g. "60 min" or "1h 30m".
  /// Returns empty string if fake or estimated.
  String get durationLabel {
    if (isEstimated) return '';
    final mins = duration.inMinutes;
    if (mins < 60) return '$mins min';
    final hours = duration.inHours;
    final remMins = mins % 60;
    return remMins > 0 ? '${hours}h ${remMins}m' : '${hours}h';
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory EpgProgram.fromJson(Map<String, dynamic> json) {
    return EpgProgram(
      id: json['id'] as String? ?? '',
      channelId: json['channelId'] as String? ?? '',
      title: json['title'] as String? ?? 'Broadcast',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      start: DateTime.tryParse(json['start'] as String? ?? '') ?? DateTime.now(),
      stop: DateTime.tryParse(json['stop'] as String? ?? '') ??
          DateTime.now().add(const Duration(hours: 1)),
      episode: json['episode'] as String?,
      rating: json['rating'] as String?,
      isEstimated: json['isEstimated'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'channelId': channelId,
        'title': title,
        'description': description,
        'category': category,
        'start': start.toIso8601String(),
        'stop': stop.toIso8601String(),
        if (episode != null) 'episode': episode,
        if (rating != null) 'rating': rating,
        'isEstimated': isEstimated,
      };
}

/// A day schedule of programs for a channel.
class ChannelSchedule {
  const ChannelSchedule({
    required this.channelId,
    required this.date,
    required this.programs,
  });

  final String channelId;
  final DateTime date;
  final List<EpgProgram> programs;

  /// Whether this schedule contains real, verified broadcast program entries.
  bool get hasRealPrograms => programs.any((p) => !p.isEstimated);

  /// The program currently on air for the given time.
  EpgProgram? currentProgram([DateTime? now]) {
    if (programs.isEmpty) return null;
    final current = now ?? DateTime.now();

    for (final program in programs) {
      if (program.isLive(current)) return program;
    }

    return null;
  }

  /// The upcoming program directly following the current one.
  EpgProgram? nextProgram([DateTime? now]) {
    if (programs.isEmpty) return null;
    final current = now ?? DateTime.now();
    for (var i = 0; i < programs.length; i++) {
      if (programs[i].isLive(current)) {
        if (i + 1 < programs.length) return programs[i + 1];
        return null;
      }
      if (programs[i].isUpcoming(current)) {
        return programs[i];
      }
    }
    return null;
  }

  /// All programs starting from current on air into the future.
  List<EpgProgram> upcomingPrograms([DateTime? now]) {
    if (programs.isEmpty) return const [];
    final current = now ?? DateTime.now();
    return programs
        .where((p) => p.stop.isAfter(current))
        .toList(growable: false);
  }

  factory ChannelSchedule.fromJson(Map<String, dynamic> json) {
    final rawPrograms = json['programs'];
    final list = <EpgProgram>[];
    if (rawPrograms is List) {
      for (final item in rawPrograms) {
        if (item is Map<String, dynamic>) {
          list.add(EpgProgram.fromJson(item));
        }
      }
    }
    return ChannelSchedule(
      channelId: json['channelId'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      programs: List.unmodifiable(list),
    );
  }

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'date': date.toIso8601String(),
        'programs': programs.map((p) => p.toJson()).toList(growable: false),
      };
}
