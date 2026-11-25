import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'state/prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // A friendly recovery panel beats the grey release-mode error box if a
  // single widget ever fails. The real error is still printed to logcat.
  ErrorWidget.builder = (details) {
    FlutterError.presentError(details);
    return const _FatalFallback();
  };

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const NightsunTvApp(),
    ),
  );
}

class _FatalFallback extends StatelessWidget {
  const _FatalFallback();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFF070B14),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'NightsunTV hit an unexpected problem.\n'
            'Reopen the app and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFF3F6FC),
              fontFamily: 'Manrope',
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
