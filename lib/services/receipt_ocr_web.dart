class ReceiptOcr {
  Future<String> readText(String imagePath) async =>
      throw UnsupportedError(
        'Receipt OCR runs on Android. Use the installable APK to scan receipts.',
      );

  Future<void> close() async {}
}
