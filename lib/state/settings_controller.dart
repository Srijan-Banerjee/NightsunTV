import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/prefs.dart';

enum ThemeVariant {
  midnight('Midnight'),
  pureBlack('Pure black');

  const ThemeVariant(this.label);
  final String label;
}

enum AccentChoice {
  solar('Solar'),
  aurora('Aurora'),
  nebula('Nebula'),
  ocean('Ocean');

  const AccentChoice(this.label);
  final String label;
}

class Settings {
  const Settings({
    this.onboardingComplete = false,
    this.themeVariant = ThemeVariant.midnight,
    this.accent = AccentChoice.solar,
    this.showAdult = false,
    this.autoplay = true,
    this.autoFallback = true,
    this.preferHighestQuality = true,
    this.haptics = true,
    this.keepScreenOn = true,
  });

  final bool onboardingComplete;
  final ThemeVariant themeVariant;
  final AccentChoice accent;
  final bool showAdult;
  final bool autoplay;
  final bool autoFallback;
  final bool preferHighestQuality;
  final bool haptics;
  final bool keepScreenOn;

  static const _prefix = 'settings.';

  factory Settings.load(SharedPreferences prefs) {
    T enumValue<T extends Enum>(List<T> values, String? name, T fallback) {
      if (name == null) return fallback;
      for (final value in values) {
        if (value.name == name) return value;
      }
      return fallback;
    }

    return Settings(
      onboardingComplete: prefs.getBool('${_prefix}onboarding') ?? false,
      themeVariant: enumValue(
        ThemeVariant.values,
        prefs.getString('${_prefix}theme'),
        ThemeVariant.midnight,
      ),
      accent: enumValue(
        AccentChoice.values,
        prefs.getString('${_prefix}accent'),
        AccentChoice.solar,
      ),
      showAdult: prefs.getBool('${_prefix}showAdult') ?? false,
      autoplay: prefs.getBool('${_prefix}autoplay') ?? true,
      autoFallback: prefs.getBool('${_prefix}autoFallback') ?? true,
      preferHighestQuality:
          prefs.getBool('${_prefix}preferHighestQuality') ?? true,
      haptics: prefs.getBool('${_prefix}haptics') ?? true,
      keepScreenOn: prefs.getBool('${_prefix}keepScreenOn') ?? true,
    );
  }

  Settings copyWith({
    bool? onboardingComplete,
    ThemeVariant? themeVariant,
    AccentChoice? accent,
    bool? showAdult,
    bool? autoplay,
    bool? autoFallback,
    bool? preferHighestQuality,
    bool? haptics,
    bool? keepScreenOn,
  }) {
    return Settings(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      themeVariant: themeVariant ?? this.themeVariant,
      accent: accent ?? this.accent,
      showAdult: showAdult ?? this.showAdult,
      autoplay: autoplay ?? this.autoplay,
      autoFallback: autoFallback ?? this.autoFallback,
      preferHighestQuality: preferHighestQuality ?? this.preferHighestQuality,
      haptics: haptics ?? this.haptics,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    );
  }
}

class SettingsController extends Notifier<Settings> {
  late SharedPreferences _prefs;

  @override
  Settings build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return Settings.load(_prefs);
  }

  void _update(Settings next) {
    if (next == state) return;
    state = next;
    unawaited(_persist(next));
  }

  Future<void> _persist(Settings value) async {
    const prefix = Settings._prefix;
    await _prefs.setBool('${prefix}onboarding', value.onboardingComplete);
    await _prefs.setString('${prefix}theme', value.themeVariant.name);
    await _prefs.setString('${prefix}accent', value.accent.name);
    await _prefs.setBool('${prefix}showAdult', value.showAdult);
    await _prefs.setBool('${prefix}autoplay', value.autoplay);
    await _prefs.setBool('${prefix}autoFallback', value.autoFallback);
    await _prefs.setBool(
      '${prefix}preferHighestQuality',
      value.preferHighestQuality,
    );
    await _prefs.setBool('${prefix}haptics', value.haptics);
    await _prefs.setBool('${prefix}keepScreenOn', value.keepScreenOn);
  }

  void completeOnboarding() =>
      _update(state.copyWith(onboardingComplete: true));

  void setTheme(ThemeVariant variant) =>
      _update(state.copyWith(themeVariant: variant));

  void setAccent(AccentChoice accent) => _update(state.copyWith(accent: accent));

  void setShowAdult(bool value) => _update(state.copyWith(showAdult: value));

  void setAutoplay(bool value) => _update(state.copyWith(autoplay: value));

  void setAutoFallback(bool value) =>
      _update(state.copyWith(autoFallback: value));

  void setPreferHighestQuality(bool value) =>
      _update(state.copyWith(preferHighestQuality: value));

  void setHaptics(bool value) => _update(state.copyWith(haptics: value));

  void setKeepScreenOn(bool value) =>
      _update(state.copyWith(keepScreenOn: value));
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);

/// A lightweight gate for UI feedback that is read from synchronous widgets.
class AppHaptics {
  AppHaptics._();
  static bool enabled = true;
}
