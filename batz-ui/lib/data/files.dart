import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// A file the user picked.
class PickedFile {
  PickedFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// The media type of a document, from the extension of its name.
String mediaTypeOf(String fileName) => switch (fileName.toLowerCase().split('.').last) {
  'pdf' => 'application/pdf',
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  _ => 'application/octet-stream',
};

/// Choosing, saving and opening files and links through the system.
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

  /// Lets the user pick a document: a PDF or a picture; null when
  /// cancelled.
  Future<PickedFile?> pickDocument();

  /// Lets the user save [bytes], a document named [fileName], elsewhere;
  /// false when cancelled.
  Future<bool> saveDocument(String fileName, Uint8List bytes);

  /// Opens [bytes], a document named [fileName], with the app of the
  /// system that shows it; false when there is none.
  Future<bool> openDocument(String fileName, Uint8List bytes);

  /// Opens [url] in the browser; false when it cannot.
  Future<bool> openLink(String url);
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

  @override
  Future<PickedFile?> pickDocument() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (file == null) return null;
    return PickedFile(file.name, await file.readAsBytes());
  }

  @override
  Future<bool> saveDocument(String fileName, Uint8List bytes) async =>
      await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mediaTypeOf(fileName)) != null;

  /// Written in the temporary folder of the app, then opened: on Android
  /// through the FileProvider of open_filex, without any permission.
  @override
  Future<bool> openDocument(String fileName, Uint8List bytes) async {
    final folder = Directory('${(await getTemporaryDirectory()).path}/documents');
    await folder.create(recursive: true);
    final file = File('${folder.path}/${fileName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')}');
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path, type: mediaTypeOf(fileName));
    return result.type == ResultType.done;
  }

  @override
  Future<bool> openLink(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
