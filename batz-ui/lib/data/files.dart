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
  /// Lets the user pick a statement: a PDF or a CSV export; null when
  /// cancelled.
  Future<PickedFile?> pickStatement();

  /// Lets the user save [bytes], the original file of a statement (PDF or
  /// CSV, after the extension of [fileName]); false when cancelled.
  Future<bool> saveStatement(String fileName, Uint8List bytes);

  /// Lets the user save [bytes] as a ZIP named [fileName] (an export);
  /// false when cancelled, and then nothing is written.
  Future<bool> saveZip(String fileName, Uint8List bytes);
}

/// [FileAccess] through `file_picker` (docs/decisions.md): the
/// system document picker on Android, the XDG portal on Ubuntu, the native
/// dialogs on Windows.
class SystemFileAccess implements FileAccess {
  @override
  Future<PickedFile?> pickStatement() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf', 'csv']);
    if (file == null) return null;
    return PickedFile(file.name, await file.readAsBytes());
  }

  @override
  Future<bool> saveStatement(String fileName, Uint8List bytes) async =>
      await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: fileName.endsWith('.csv') ? 'text/csv' : 'application/pdf',
      ) !=
      null;

  @override
  Future<bool> saveZip(String fileName, Uint8List bytes) async =>
      await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: 'application/zip') != null;
}
