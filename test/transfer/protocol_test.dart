import 'package:flutter_test/flutter_test.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/model/message.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/transfer/protocol.dart';

void main() {
  group('control frames', () {
    final frames = <ControlMessage>[
      RequestFrame(
        sessionId: 's1',
        senderName: 'Noble Meadow',
        files: [
          OfferedFile(name: 'a.zip', size: 12, mimeType: 'application/zip'),
        ],
        totalSize: 12,
        requestVerification: true,
        senderCertificate:
            '-----BEGIN CERTIFICATE-----\nAAA\n-----END CERTIFICATE-----',
        signature: 'c2ln',
      ),
      AcceptedFrame(sessionId: 's1'),
      DeclinedFrame(sessionId: 's1', reason: TransferFailure.busy),
      ProgressFrame(sessionId: 's1', bytesReceived: 5, fileName: 'a.zip'),
      CompletedFrame(sessionId: 's1'),
      FailedFrame(sessionId: 's1', reason: TransferFailure.storageError),
      CancelFrame(sessionId: 's1'),
    ];

    for (final frame in frames) {
      test('${frame.runtimeType} survives a round trip', () {
        final back = ControlMessage.fromJson(frame.toJson());
        expect(back.runtimeType, frame.runtimeType);
        expect(back.sessionId, frame.sessionId);
      });
    }

    test('a request keeps everything the receiver decides on', () {
      final original = frames.first as RequestFrame;
      final back = ControlMessage.fromJson(original.toJson()) as RequestFrame;

      expect(back.senderName, original.senderName);
      expect(back.totalSize, original.totalSize);
      expect(back.files.single.name, 'a.zip');
      expect(back.requestVerification, isTrue);
      expect(back.senderCertificate, original.senderCertificate);
      expect(back.signature, original.signature);
      expect(back.protocolVersion, kProtocolVersion);
    });

    test(
      'a failure reason survives, so the sender can say what went wrong',
      () {
        final back = ControlMessage.fromJson(
          FailedFrame(
            sessionId: 's1',
            reason: TransferFailure.unverifiedSender,
          ).toJson(),
        ) as FailedFrame;
        expect(back.reason, TransferFailure.unverifiedSender);
      },
    );

    test('unreadable input throws rather than producing a frame', () {
      expect(
        () => ControlMessage.fromJson('{"type":"nonsense"}'),
        throwsA(anything),
      );
      expect(() => ControlMessage.fromJson('not json'), throwsA(anything));
    });
  });

  group('the attestation statement', () {
    test('names both the session and the receiver', () {
      // Binding the receiver is what stops a signature collected by one device
      // being replayed at another.
      final a = attestationStatement('session-1', 'receiver-a');
      expect(a, isNot(attestationStatement('session-2', 'receiver-a')));
      expect(a, isNot(attestationStatement('session-1', 'receiver-b')));
    });
  });

  group('presence', () {
    test('carries the version and fingerprint', () {
      final back = Message.fromJson(
        Message(
          name: 'Noble Meadow',
          protocolVersion: kProtocolVersion,
          fingerprint: 'abc',
        ).toJson(),
      );
      expect(back.protocolVersion, kProtocolVersion);
      expect(back.fingerprint, 'abc');
    });

    test('a broadcast from an older build has neither', () {
      // The absence of a version is the only way such a device is recognisable,
      // so these fields must never acquire defaults.
      final legacy = Message.fromJson('{"name":"Old Phone","available":true}');
      expect(legacy.protocolVersion, isNull);
      expect(legacy.fingerprint, isNull);
    });
  });
}
