class DniOcrScanResult {
  final String texto;
  final String imagePath;
  final List<int> imageBytes;

  const DniOcrScanResult({
    required this.texto,
    required this.imagePath,
    required this.imageBytes,
  });
}

class DniOcrScanner {
  bool get isSupported => false;

  Future<DniOcrScanResult?> capturarYEscanear({bool camara = true}) async {
    return null;
  }

  void dispose() {}
}
