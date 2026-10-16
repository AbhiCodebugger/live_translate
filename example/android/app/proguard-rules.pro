# google_mlkit_text_recognition references every script's recognizer, but the
# app only bundles Latin and Devanagari. Without these, R8 fails release builds.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
