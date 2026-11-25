# Flutter and plugin rules are contributed by their consumer ProGuard files.
# Keep this file for app-specific additions.

# Preserve line numbers for readable crash reports without leaking source.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Flutter's deferred components / platform channels use reflection in places.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Keep Media3 / ExoPlayer for reliable streaming playback
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-dontwarn com.google.android.exoplayer2.**

# Keep simple_pip_mode plugin
-keep class cl.puntito.simple_pip_mode.** { *; }
-dontwarn cl.puntito.simple_pip_mode.**
