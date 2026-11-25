import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` after SharedPreferences has loaded. Keeping the
/// instance synchronous avoids a flash of default settings on cold start.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences was not overridden'),
);
