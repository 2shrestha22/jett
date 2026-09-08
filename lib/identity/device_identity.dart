import 'dart:io';

import 'package:jett/crypto/device_alias.dart';
import 'package:jett/crypto/device_keys.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// This device's identity as the rest of the app sees it: the keys, plus the
/// name derived from them.
///
/// Everything cryptographic lives in [DeviceKeys]; this type decides where the
/// keys are kept and loads them once at startup.
class DeviceIdentity {
  final DeviceKeys keys;

  /// What this device calls itself to peers, e.g. "Noble Meadow".
  ///
  /// Derived from the key rather than taken from the OS, whose names are
  /// neither unique nor private. A regenerated key therefore gets a new name.
  final String alias;

  DeviceIdentity(this.keys) : alias = deviceAlias(keys.fingerprint);

  String get fingerprint => keys.fingerprint;
  String get certificatePem => keys.certificatePem;
  String get privateKeyPem => keys.privateKeyPem;

  /// Deletes the stored keys, so the next launch mints a new identity. Not
  /// applied to the running app, which is already serving the old certificate.
  static Future<void> erase() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, 'identity'));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  /// Loads the stored identity, minting one on first run.
  ///
  /// The key sits in the app's private support directory rather than the
  /// platform keychain, keeping the app free of native storage plugins.
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
    // key first, so a crash between the writes leaves no certificate and the
    // next run regenerates both
    await keyFile.writeAsString(keys.privateKeyPem);
    await certFile.writeAsString(keys.certificatePem);
    return DeviceIdentity(keys);
  }
}

/// This device's identity, wired up once at startup.
late DeviceIdentity deviceIdentity;
