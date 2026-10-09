# The Flutter ML Kit plugin references optional script recognizers.
# ReceiptWise uses the Latin recognizer; these language-specific classes are
# not packaged by google_mlkit_text_recognition unless their dependencies are added.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
