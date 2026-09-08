import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// A device whose key has been verified and accepted.
class TrustedPeer {
  final String fingerprint;

  /// What it went by when it was accepted. Nothing is decided from it.
  final String name;
  final DateTime trustedAt;

  const TrustedPeer({
    required this.fingerprint,
    required this.name,
    required this.trustedAt,
  });

  Map<String, dynamic> toJson() => {
    'fingerprint': fingerprint,
    'name': name,
    'trustedAt': trustedAt.toIso8601String(),
  };

  static TrustedPeer fromJson(Map<String, dynamic> json) => TrustedPeer(
    fingerprint: json['fingerprint'] as String,
    name: json['name'] as String,
    trustedAt: DateTime.parse(json['trustedAt'] as String),
  );
}

/// The keys this device has accepted, so a peer is verified once rather than
/// every time.
///
/// An absent key is unknown, whether the device is new or was reinstalled;
/// the key is the identity.
abstract class TrustStore {
  bool isTrusted(String fingerprint);
  Future<void> trust(String fingerprint, String name);
  List<TrustedPeer> get peers;

  /// Forgets every key, so each peer is verified afresh.
  Future<void> clear();
}

/// A [TrustStore] that forgets everything when the process ends. For tests.
class InMemoryTrustStore implements TrustStore {
  final Map<String, TrustedPeer> _peers = {};

  @override
  bool isTrusted(String fingerprint) => _peers.containsKey(fingerprint);

  @override
  List<TrustedPeer> get peers => _peers.values.toList();

  @override
  Future<void> trust(String fingerprint, String name) async {
    _peers[fingerprint] = TrustedPeer(
      fingerprint: fingerprint,
      name: name,
      trustedAt: DateTime.now(),
    );
  }

  @override
  Future<void> clear() async => _peers.clear();
}

/// A [TrustStore] backed by a JSON file beside the device's keys.
class FileTrustStore implements TrustStore {
  final File file;
  final Map<String, TrustedPeer> _peers = {};

  FileTrustStore(this.file);

  /// Opens the store next to the identity, creating nothing until something is
  /// actually trusted.
  static Future<FileTrustStore> open() async {
    final support = await getApplicationSupportDirectory();
    final store = FileTrustStore(
      File(path.join(support.path, 'identity', 'trusted.json')),
    );
    await store.load();
    return store;
  }

  Future<void> load() async {
    _peers.clear();
    if (!await file.exists()) return;
    try {
      final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
      for (final entry in raw) {
        final peer = TrustedPeer.fromJson(entry as Map<String, dynamic>);
        _peers[peer.fingerprint] = peer;
      }
    } catch (e, s) {
      // A damaged store must not stop the app; the cost is re-verifying.
      log('Could not read the trust store', error: e, stackTrace: s);
      _peers.clear();
    }
  }

  @override
  bool isTrusted(String fingerprint) => _peers.containsKey(fingerprint);

  @override
  List<TrustedPeer> get peers => _peers.values.toList();

  @override
  Future<void> trust(String fingerprint, String name) async {
    _peers[fingerprint] = TrustedPeer(
      fingerprint: fingerprint,
      name: name,
      trustedAt: DateTime.now(),
    );
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode([for (final peer in _peers.values) peer.toJson()]),
      );
    } catch (e, s) {
      log('Could not save the trust store', error: e, stackTrace: s);
    }
  }

  @override
  Future<void> clear() async {
    _peers.clear();
    try {
      if (await file.exists()) await file.delete();
    } catch (e, s) {
      log('Could not delete the trust store', error: e, stackTrace: s);
    }
  }
}

/// The keys this device has accepted, wired up once at startup.
late TrustStore trustStore;
