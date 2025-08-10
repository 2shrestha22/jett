import 'dart:io';

import 'package:anysend/utils/package_info.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;

/// return path when it saves all the files
Future<String> getSavePath() async {
  final appName = PackageInfoHelper.appName;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      // by default it is not visible in the Files app
      // https://github.com/fluttercommunity/flutter_downloader/issues/163#issuecomment-620393031
      final directory = await path_provider.getApplicationDocumentsDirectory();

      return directory.path;

    case TargetPlatform.android:
      // on Android, the files are saved in the app's private storage
      // which is not accessible to the user directly
      final directory = await path_provider.getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('Could not get external storage directory!');
      }
      final storageDir = directory.path.split('/Android/').first;
      final savePath = '$storageDir/Download/$appName';
      await Directory(savePath).create();
      return savePath;

    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      final downloadsDir = await path_provider.getDownloadsDirectory();
      final savePath = path.join(downloadsDir!.path, appName);

      return await Directory(
        savePath,
      ).create(recursive: true).then((value) => value.path);

    default:
      throw UnimplementedError();
  }
}
