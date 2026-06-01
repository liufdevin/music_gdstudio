import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class SavedDownload {
  const SavedDownload(this.displayPath);

  final String displayPath;
}

const _androidDownloadFolder = 'lf_music';

Future<String?> pickBatchDownloadDirectory() async {
  if (Platform.isAndroid) {
    return _androidDownloadFolder;
  }
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
  if (Platform.isAndroid) {
    return _saveAndroidDownload(bytes: bytes, fileName: fileName);
  }

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

Future<SavedDownload> _saveAndroidDownload({
  required Uint8List bytes,
  required String fileName,
}) async {
  await _ensureMediaStore();
  final tempDirectory = await getTemporaryDirectory();
  final tempFile = File(path.join(tempDirectory.path, fileName));
  await tempFile.writeAsBytes(bytes, flush: true);

  final saveInfo = await MediaStore().saveFile(
    tempFilePath: tempFile.path,
    dirType: DirType.download,
    dirName: DirName.download,
    relativePath: _androidDownloadFolder,
  );
  if (saveInfo == null) {
    throw Exception('保存到 Download/lf_music 失败');
  }
  return SavedDownload('Download/lf_music/$fileName');
}

Future<void>? _mediaStoreInit;

Future<void> _ensureMediaStore() {
  MediaStore.appFolder = _androidDownloadFolder;
  return _mediaStoreInit ??= MediaStore.ensureInitialized();
}
