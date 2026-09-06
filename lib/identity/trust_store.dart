import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final trustStore = TrustStore();

/// A device whose key this device has verified and accepted.
class TrustedPeer {
  final String fingerprint;

  /// The name it went by when it was trusted, used to notice when a familiar
  /// device turns up with a key we have not seen.
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
/// A key that is not in here is unknown, whether it belongs to a device never
/// seen before or to a familiar one that has been reinstalled. Both are
/// treated the same way, because the key is the identity and there is nothing
/// else stable to tell those cases apart: device names are not unique and
/// often not even device-specific, so a warning keyed on them would fire on
/// ordinary pairs of similar machines.
///
/// Only the sending side keeps trust: it is the only side that can verify who
/// it is talking to, since the receiver never sees a client certificate.
class TrustStore {
  static const _fileName = 'trusted.json';

  final Map<String, TrustedPeer> _peers = {};
  late final File _file;

  Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    _file = File(path.join(support.path, 'identity', _fileName));

    if (!await _file.exists()) return;
    try {
      final raw = jsonDecode(await _file.readAsString()) as List<dynamic>;
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

  /// Whether the certificate a peer presented is one the user has accepted.
  bool isTrusted(String fingerprint) => _peers.containsKey(fingerprint);

  Future<void> trust(String fingerprint, String name) async {
    _peers[fingerprint] = TrustedPeer(
      fingerprint: fingerprint,
      name: name,
      trustedAt: DateTime.now(),
    );
    await _save();
  }

  Future<void> _save() async {
    try {
      await _file.parent.create(recursive: true);
      await _file.writeAsString(
        jsonEncode([for (final peer in _peers.values) peer.toJson()]),
      );
    } catch (e, s) {
      log('Could not save the trust store', error: e, stackTrace: s);
    }
  }
}
