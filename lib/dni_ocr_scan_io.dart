import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class DniOcrScanResult {
  final String texto;
  final List<int> imageBytes;

  const DniOcrScanResult({
    required this.texto,
    required this.imageBytes,
  });
}

class DniOcrScanner {
  final _picker = ImagePicker();
  TextRecognizer? _recognizer;

  bool get isSupported => true;

  Future<DniOcrScanResult?> capturarYEscanear({bool camara = true}) async {
    final foto = await _picker.pickImage(
      source: camara ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 40,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (foto == null) return null;

    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    final input = InputImage.fromFilePath(foto.path);
    final result = await _recognizer!.processImage(input);
    final bytes = await foto.readAsBytes();

    return DniOcrScanResult(
      texto: result.text,
      imageBytes: bytes,
    );
  }

  void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}
