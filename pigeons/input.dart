import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/messages.g.dart',
    dartPackageName: 'com.sangamshrestha.jett',
    kotlinOut:
        'android/app/src/main/kotlin/com/sangamshrestha/jett/Messages.g.kt',
    swiftOut: 'ios/Runner/Messages.g.swift',
  ),
)
@HostApi()
abstract class JettApi {
  Version getPlatformVersion();
  List<PlatformFile> getInitialFiles();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  List<APKInfo> getAPKs();
}

@FlutterApi()
abstract class JettFlutterApi {
  void onIntent(List<PlatformFile> files);
}

class Version {
  String? string;
}

class PlatformFile {
  PlatformFile(this.uri, this.name, this.size);

  final String uri;
  final String? name;
  final int? size;
}

class APKInfo {
  final String name;
  final String packageName;
  final String fileName;
  final bool isSystemApp;
  final bool isSplitApk;
  final Uint8List icon;

  /// Content URI
  final String contentUri;

  APKInfo(
    this.name,
    this.packageName,
    this.fileName,
    this.isSystemApp,
    this.isSplitApk,
    this.icon,
    this.contentUri,
  );
}
