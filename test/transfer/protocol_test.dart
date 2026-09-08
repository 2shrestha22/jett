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

    test('a request carries the bulk-data path the sender can use', () {
      final back = ControlMessage.fromJson(
        RequestFrame(
          sessionId: 's1',
          senderName: 'Noble Meadow',
          files: const [],
          totalSize: 0,
          senderCertificate: 'cert',
          signature: 'sig',
          dataPlaneVersion: kDataPlaneVersion,
        ).toJson(),
      ) as RequestFrame;
      expect(back.dataPlaneVersion, kDataPlaneVersion);
    });

    test('an acceptance carries the path the receiver settled on', () {
      final back = ControlMessage.fromJson(
        AcceptedFrame(sessionId: 's1', dataPlaneVersion: 2).toJson(),
      ) as AcceptedFrame;
      expect(back.dataPlaneVersion, 2);
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

  group('talking to a build that predates the raw-body path', () {
    // Multipart is gone, so these two defaults are no longer how such a peer is
    // served — they are how it is recognised. Decoding either as 2 would let a
    // build that only speaks multipart past the floor check and leave it being
    // sent v2 bytes it has no endpoint for.
    test('a request without the field decodes below the floor', () {
      final legacy = ControlMessage.fromJson(
        '{"type":"request","sessionId":"s1","protocolVersion":'
        '$kProtocolVersion,"senderName":"Old Phone","files":[],'
        '"totalSize":0,"requestVerification":false,'
        '"senderCertificate":"cert","signature":"sig"}',
      ) as RequestFrame;
      expect(legacy.dataPlaneVersion, 1);
    });

    test('an acceptance without the field decodes below the floor', () {
      final legacy = ControlMessage.fromJson(
        '{"type":"accepted","sessionId":"s1"}',
      ) as AcceptedFrame;
      expect(legacy.dataPlaneVersion, 1);
    });

    test('negotiation takes the lower of the two', () {
      expect(negotiatedDataPlaneVersion(1), 1);
      expect(1, lessThan(kDataPlaneVersion));
      expect(negotiatedDataPlaneVersion(kDataPlaneVersion), kDataPlaneVersion);
      // A newer peer offering more than this build knows is held to what this
      // build can actually serve.
      expect(
        negotiatedDataPlaneVersion(kDataPlaneVersion + 5),
        kDataPlaneVersion,
      );
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
