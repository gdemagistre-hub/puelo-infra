class DniOcrScanResult {
  final String texto;
  final List<int> imageBytes;

  const DniOcrScanResult({
    required this.texto,
    required this.imageBytes,
  });
}

class DniOcrScanner {
  bool get isSupported => false;

  Future<DniOcrScanResult?> capturarYEscanear({bool camara = true}) async => null;

  void dispose() {}
}
