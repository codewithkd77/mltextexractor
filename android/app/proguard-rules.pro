# Suppress warnings for missing classes related to non-English text recognizers
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep classes related to English text recognition
-keep class com.google.mlkit.vision.text.TextRecognizer { *; }
-keep class com.google.mlkit.vision.text.EnglishTextRecognizerOptions { *; }

# Keep Flutter plugin classes
-keep class io.flutter.plugin.** { *; }