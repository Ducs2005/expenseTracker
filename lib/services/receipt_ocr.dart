import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcr {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> readText(String imagePath) async {
    final image = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(image);
    return result.text;
  }

  Future<void> close() => _recognizer.close();
}
