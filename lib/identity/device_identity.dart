import 'dart:io';

import 'package:jett/crypto/device_alias.dart';
import 'package:jett/crypto/device_keys.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// This device's identity as the rest of the app sees it: the keys, plus the
/// name derived from them.
///
/// Everything cryptographic lives in [DeviceKeys]; this type only decides
/// where those keys are kept and loads them once at startup.
class DeviceIdentity {
  final DeviceKeys keys;

  /// What this device calls itself to peers, e.g. "Noble Meadow".
  ///
  /// Generated rather than taken from the operating system. Platform names are
  /// not unique — Linux reports the distribution, Android a build property
  /// shared by every unit of a model — and not private either, since a Mac
  /// reports whatever its owner called it. Following the key also means a
  /// device that regenerates one stops answering to a name that was verified
  /// against the old one.
  final String alias;

  DeviceIdentity(this.keys) : alias = deviceAlias(keys.fingerprint);

  String get fingerprint => keys.fingerprint;
  String get certificatePem => keys.certificatePem;
  String get privateKeyPem => keys.privateKeyPem;

  /// Loads the stored identity, minting one on first run.
  ///
  /// The key sits in the app's private support directory rather than the
  /// platform keychain, which keeps the app free of native storage plugins and
  /// per-platform entitlements. Anything able to read it can already read the
  /// files being transferred.
  static Future<DeviceIdentity> load() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, 'identity'));
    final certFile = File(path.join(directory.path, 'cert.pem'));
    final keyFile = File(path.join(directory.path, 'key.pem'));

    if (await certFile.exists() && await keyFile.exists()) {
      return DeviceIdentity(
        DeviceKeys.fromPem(
          certificatePem: await certFile.readAsString(),
          privateKeyPem: await keyFile.readAsString(),
        ),
      );
    }

    await directory.create(recursive: true);
    final keys = DeviceKeys.generate();
    // key first: a crash between the two writes leaves no certificate, and the
    // next run regenerates both rather than pairing mismatched halves
    await keyFile.writeAsString(keys.privateKeyPem);
    await certFile.writeAsString(keys.certificatePem);
    return DeviceIdentity(keys);
  }
}

/// This device's identity, wired up once at startup.
late DeviceIdentity deviceIdentity;
