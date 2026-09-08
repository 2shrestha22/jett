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
abstract class JettHostApi {
  Version getPlatformVersion();
  List<PlatformFile> getInitialFiles();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  List<APKInfo> getAPKs({bool withSystemApp = false});

  /// Opens [uri] for reading and hands back a file descriptor.
  ///
  /// Android only, and the reason the native data plane can send at all: a
  /// `content://` URI names a file inside another app's provider, which only
  /// the framework can resolve. Rust cannot open one and Dart can only stream
  /// it back a chunk at a time — which is every byte crossing the platform
  /// channel before any of them reach the wire.
  ///
  /// **Ownership passes to the caller.** The descriptor is detached from the
  /// `ParcelFileDescriptor` that produced it, so nothing on the platform side
  /// will close it; whoever receives it must, on every path including failure
  /// and cancellation, or the process leaks descriptors until it hits its
  /// limit.
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  int openFileDescriptor(String uri);
}

@EventChannelApi()
abstract class JettEventChannelApi {
  List<PlatformFile> files();
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
