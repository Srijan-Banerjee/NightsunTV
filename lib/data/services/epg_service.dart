import '../models/channel.dart';
import '../models/epg_program.dart';

/// Service responsible for storing and providing verified Electronic Program Guide (EPG)
/// schedules for channels.
///
/// Estimated/fake schedule generation has been completely removed from the app. Schedules
/// are only returned when real broadcast program data is explicitly available.
class EpgService {
  EpgService();

  final Map<String, ChannelSchedule> _schedules = {};

  /// Retrieves the program schedule for [channel] on [date] (defaults to today).
  /// Returns an empty schedule if no real program data is present.
  ChannelSchedule getSchedule(Channel channel, [DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    final cacheKey =
        '${channel.id}_${targetDate.year}_${targetDate.month}_${targetDate.day}';

    final existing = _schedules[cacheKey];
    if (existing != null) return existing;

    return ChannelSchedule(
      channelId: channel.id,
      date: DateTime(targetDate.year, targetDate.month, targetDate.day),
      programs: const [],
    );
  }

  /// Sets or updates the verified schedule for a channel.
  void setSchedule(String channelId, DateTime date, List<EpgProgram> programs) {
    final cacheKey = '${channelId}_${date.year}_${date.month}_${date.day}';
    _schedules[cacheKey] = ChannelSchedule(
      channelId: channelId,
      date: DateTime(date.year, date.month, date.day),
      programs: List.unmodifiable(programs),
    );
  }

  /// Convenience helper to obtain the currently active real program on [channel].
  EpgProgram? getCurrentProgram(Channel channel, [DateTime? time]) {
    final schedule = getSchedule(channel, time);
    final current = schedule.currentProgram(time);
    if (current == null || current.isEstimated) return null;
    return current;
  }

  /// Convenience helper to obtain the upcoming real program on [channel].
  EpgProgram? getNextProgram(Channel channel, [DateTime? time]) {
    final schedule = getSchedule(channel, time);
    final next = schedule.nextProgram(time);
    if (next == null || next.isEstimated) return null;
    return next;
  }

  /// Clears all cached schedules.
  void clear() {
    _schedules.clear();
  }
}
