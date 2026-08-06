import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../platform_capabilities.dart';

/// Bottom sheet de origen de imagen con guard multiplataforma.
Future<ImageSource?> pickImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (c2) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (PlatformCapabilities.supportsCamera)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(c2, ImageSource.camera),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de galería'),
            onTap: () => Navigator.pop(c2, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}
