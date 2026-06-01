import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

class SavedDownload {
  const SavedDownload(this.displayPath);

  final String displayPath;
}

Future<String?> pickBatchDownloadDirectory() {
  return getDirectoryPath(
    confirmButtonText: '选择保存目录',
    canCreateDirectories: true,
  );
}

Future<SavedDownload?> saveDownloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? targetPath,
}) async {
  final savePath =
      targetPath ??
      (await getSaveLocation(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(
            label: 'Audio',
            extensions: <String>['mp3', 'flac', 'm4a', 'aac', 'ogg', 'wav'],
            mimeTypes: <String>[
              'audio/mpeg',
              'audio/flac',
              'audio/mp4',
              'audio/aac',
              'audio/ogg',
              'audio/wav',
            ],
            webWildCards: <String>['audio/*'],
          ),
        ],
        suggestedName: fileName,
        confirmButtonText: '保存',
      ))?.path;

  if (savePath == null) {
    return null;
  }

  final file = XFile.fromData(bytes, name: fileName, mimeType: mimeType);
  await file.saveTo(savePath);
  return SavedDownload(savePath);
}
