import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A file the user picked.
class PickedFile {
  PickedFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Choosing and saving files through the system dialogs.
abstract interface class FileAccess {
  /// Lets the user pick a PDF file; null when cancelled.
  Future<PickedFile?> pickPdf();

  /// Lets the user save [bytes] as a PDF named [fileName]; false when
  /// cancelled.
  Future<bool> savePdf(String fileName, Uint8List bytes);
}

/// [FileAccess] through `file_picker` (docs/decisions.md, step 3.0): the
/// system document picker on Android, the XDG portal on Ubuntu, the native
/// dialogs on Windows.
class SystemFileAccess implements FileAccess {
  @override
  Future<PickedFile?> pickPdf() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
    if (file == null) return null;
    return PickedFile(file.name, await file.readAsBytes());
  }

  @override
  Future<bool> savePdf(String fileName, Uint8List bytes) async =>
      await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: 'application/pdf') != null;
}
