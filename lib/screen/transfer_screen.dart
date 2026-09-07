import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:forui/forui.dart';
import 'package:jett/widgets/hooks.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/widgets/speedometer_widget.dart';
import 'package:jett/transfer/client.dart';
import 'package:jett/transfer/server.dart';
import 'package:jett/transfer/speedometer.dart';
import 'package:jett/utils/data.dart';
import 'package:jett/utils/save_path.dart';
import 'package:rxdart/rxdart.dart';

enum TransferType { send, receive }

/// What went wrong, and what the person can do about it.
///
/// Every one of these is read by somebody whose transfer just stopped, so the
/// second half matters as much as the first: a message that only names the
/// failure leaves them with nothing to try. Where there is genuinely nothing to
/// try, the message says so rather than inventing advice.
String _failureMessage(TransferFailure reason) => switch (reason) {
  TransferFailure.declined => 'The other device declined the transfer.',
  TransferFailure.busy =>
    'That device is busy with another transfer. Try again once it has '
        'finished.',
  TransferFailure.peerUnreachable =>
    'Could not reach that device. Check both devices are on the same '
        'network.',
  TransferFailure.timeout =>
    'The other device stopped responding. Check it is still awake and on '
        'the same network.',
  TransferFailure.fileUnreadable =>
    'A file could not be read. It may have been moved or deleted since it '
        'was picked.',
  TransferFailure.storageError =>
    'The files could not be saved. Check there is enough free space.',
  TransferFailure.unverifiedSender =>
    'That device could not prove which device it is, so the transfer was '
        'stopped. Try again, and if it keeps happening you may not be talking '
        'to the device you think you are.',
  TransferFailure.versionMismatch =>
    'That device is running a version of Jett this one cannot talk to. '
        'Update Jett on both devices.',
  TransferFailure.unknown => 'The transfer failed. Try again.',
};

class TransferScreen extends StatefulHookWidget {
  final TransferType transferType;

  const TransferScreen({super.key, required this.transferType});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  late ValueStream<TransferState> transferStateStream;
  late ValueStream<SpeedometerReading?> speedometerReadingStream;

  @override
  void initState() {
    super.initState();
    switch (widget.transferType) {
      case TransferType.send:
        transferStateStream = client.transferState;
        speedometerReadingStream = client.speedometerReadingsStream;
        break;
      case TransferType.receive:
        transferStateStream = server.transferState;
        speedometerReadingStream = server.speedometerReadingStream;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ipAddress = useLocalAddress();
    final theme = context.theme;

    return FScaffold(
      header: FHeader.nested(
        title: switch (widget.transferType) {
          TransferType.receive => Text('Receiving Files'),
          TransferType.send => Text('Sending Files'),
        },
        prefixes: [
          FHeaderAction.x(
            onPress: () => Navigator.pop(context, transferStateStream.value),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            spacing: 8,
            children: [
              Spacer(),
              StreamBuilder(
                stream: speedometerReadingStream.sampleTime(
                  Duration(milliseconds: 400),
                ),
                builder: (context, snapshot) {
                  final speed = (snapshot.data?.speedBps ?? 0) / (1024 * 1024);

                  return Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: (speed).toStringAsFixed(1),
                          style: context.theme.typography.body.xl.copyWith(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        TextSpan(
                          text: ' MB/s', // unit part
                          style: theme.typography.body.md.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              SpeedometerWidget(
                speedometerReadingsStream: speedometerReadingStream,
                showSpeed: false,
              ),
              DefaultTextStyle(
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
                child: HookBuilder(
                  builder: (context) {
                    final transferState = useStream(transferStateStream);
                    return switch (transferState.data) {
                      TransferWaiting() => Text('Waiting for receiver'),
                      TransferInProgress(:final fileName) => Text(
                        fileName ?? 'Starting...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      TransferCompleted() => Text(
                        'Transfer finished, ${formatTransferRate(speedometerReadingStream.value?.avgSpeedBps ?? 0)}',
                      ),
                      TransferFailed(:final reason) => Text(
                        _failureMessage(reason),
                        textAlign: TextAlign.center,
                      ),
                      TransferCancelled(:final by) => Text(switch (by) {
                        CancelledBy.sender => 'The sender cancelled',
                        CancelledBy.receiver => 'Transfer cancelled',
                      }),
                      _ => SizedBox.shrink(),
                    };
                  },
                ),
              ),
              if (widget.transferType == TransferType.receive)
                HookBuilder(
                  builder: (context) {
                    final savePath = useFuture(getSavePath());
                    return savePath.hasData
                        ? Column(
                            children: [
                              Text(
                                'Files will be saved to:',
                                style: theme.typography.body.sm.copyWith(
                                  color: theme.colors.foreground,
                                ),
                              ),
                              SizedBox(height: 6),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colors.border,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  savePath.data!,
                                  style: theme.typography.body.xs.copyWith(
                                    color: theme.colors.foreground,
                                    fontFamily: 'monospace',
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : SizedBox.shrink();
                  },
                ),
              SizedBox(height: 50),
              HookBuilder(
                builder: (context) {
                  final transferState = useStream(transferStateStream);
                  final state = transferState.data;
                  final opacity = (state?.isTerminal ?? false) ? 1.0 : 0.0;
                  return AnimatedOpacity(
                    duration: Durations.long4,
                    opacity: opacity,
                    child: IgnorePointer(
                      ignoring: opacity != 1,
                      child: FButton(
                        variant: .secondary,
                        mainAxisSize: MainAxisSize.min,
                        onPress: () {
                          Navigator.pop(context);
                        },
                        prefix: Icon(FLucideIcons.chevronLeft),
                        child: Text('Back'),
                      ),
                    ),
                  );
                },
              ),
              Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 6,
                children: [
                  Icon(FLucideIcons.radio, size: 18),
                  Text(
                    ipAddress.value ?? '',
                    style: context.theme.typography.body.sm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
