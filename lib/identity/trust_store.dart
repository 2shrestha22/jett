import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:jett/model/device.dart';
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

/// What the user is being asked to agree to before a transfer starts.
enum TrustDecision {
  /// The key is already known; go ahead without asking.
  known,

  /// Never seen this key. Compare the words once, then remember it.
  firstContact,

  /// A device by this name was trusted before, with a different key. Either
  /// it was reinstalled, or something is pretending to be it.
  keyChanged,
}

/// The keys this device has accepted, so a peer is verified once rather than
/// every time.
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

  bool isTrusted(String fingerprint) => _peers.containsKey(fingerprint);

  /// What to do about [device], given the certificate it actually presented.
  TrustDecision decide(Device device, String presentedFingerprint) {
    if (_peers.containsKey(presentedFingerprint)) return TrustDecision.known;

    final sameName = _peers.values.any((peer) => peer.name == device.name);
    return sameName ? TrustDecision.keyChanged : TrustDecision.firstContact;
  }

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
