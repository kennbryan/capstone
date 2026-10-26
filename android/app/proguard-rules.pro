# shared_preferences_android (2.5+, Pigeon JNI) is called from Dart through
# JNI by exact class and method names, e.g.
#   getAll(String, List, kotlin.coroutines.Continuation) -> kotlin.Result
# R8 cannot see these calls, so keep the plugin, the JNI bridge, and the
# Kotlin runtime types those signatures use under their original names.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
