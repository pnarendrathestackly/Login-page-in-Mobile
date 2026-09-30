import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../widgets.dart';

/// One CSV line: every field quoted, embedded quotes doubled (RFC 4180).
String csvRow(Iterable<Object?> fields) => fields
    .map((f) => '"${(f ?? '').toString().replaceAll('"', '""')}"')
    .join(',');

/// Builds a CSV document from a header and rows.
String csvOf(List<String> header, Iterable<List<Object?>> rows) =>
    [csvRow(header), for (final r in rows) csvRow(r)].join('\n');

/// Saves [csv] as [fileName] through the platform's save dialog (a browser
/// download on the web). Silent when the user cancels; reports success only
/// once the file is written, and a failure as an error.
Future<void> exportCsv(
  BuildContext context, {
  required String fileName,
  required String csv,
}) async {
  try {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Export $fileName',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(csv)),
      mimeType: 'text/csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (!context.mounted) return;
    // The web download has no path to hand back; elsewhere null = cancelled.
    if (saved == null && !kIsWeb) return;
    showToast(context, 'Exported $fileName.');
  } catch (_) {
    if (context.mounted) {
      showToast(
        context,
        'Unable to export the file. Please try again.',
        isError: true,
      );
    }
  }
}
