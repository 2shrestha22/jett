import 'package:jett/core/hooks.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/screen/widgets/file_info_stream_builder.dart';
import 'package:jett/screen/widgets/speedometer_widget.dart';
import 'package:jett/transfer/client.dart';
import 'package:jett/transfer/server.dart';
import 'package:jett/transfer/speedometer.dart';
import 'package:jett/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:forui/forui.dart';
import 'package:rxdart/rxdart.dart';

enum TransferType { send, receive }

class TransferScreen extends StatefulHookWidget {
  final TransferType transferType;

  const TransferScreen({super.key, required this.transferType});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  late ValueStream<TransferState> transferStateStream;
  late ValueStream<SpeedometerReading?> speedometerReadingStream;
  late Stream<String> fileNameStream;

  @override
  void initState() {
    super.initState();
    switch (widget.transferType) {
      case TransferType.send:
        transferStateStream = client.transferState;
        speedometerReadingStream = client.speedometerReadingsStream;
        fileNameStream = client.fileNameStream;
        break;
      case TransferType.receive:
        transferStateStream = server.transferState;
        speedometerReadingStream = server.speedometerReadingStream;
        fileNameStream = server.fileNameStream;
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
                          style: context.theme.typography.xl.copyWith(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        TextSpan(
                          text: " MB/s", // unit part
                          style: theme.typography.base.copyWith(
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
                style: theme.typography.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
                child: HookBuilder(
                  builder: (context) {
                    final transferState = useStream(transferStateStream);
                    return switch (transferState.data) {
                      TransferState.waiting => Text('Waiting for receiver'),
                      TransferState.inProgress => FileInfoStreamBuilder(
                        stream: fileNameStream,
                      ),
                      TransferState.completed => Text(
                        'Transfer finished, ${formatTransferRate(speedometerReadingStream.value?.avgSpeedBps ?? 0)}',
                      ),
                      TransferState.failed => Text('Transfer failed'),
                      _ => SizedBox.shrink(),
                    };
                  },
                ),
              ),
              SizedBox(height: 50),
              HookBuilder(
                builder: (context) {
                  final transferState = useStream(transferStateStream);
                  final opacity = switch (transferState.data) {
                    TransferState.completed || TransferState.failed => 1.0,
                    _ => 0.0,
                  };
                  return AnimatedOpacity(
                    duration: Durations.long4,
                    opacity: opacity,
                    child: IgnorePointer(
                      ignoring: opacity != 1,
                      child: FButton(
                        style: FButtonStyle.secondary(),
                        mainAxisSize: MainAxisSize.min,
                        onPress: () {
                          Navigator.pop(context);
                        },
                        prefix: Icon(FIcons.chevronLeft),
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
                  Icon(FIcons.radio, size: 18),
                  Text(
                    ipAddress.value ?? '',
                    style: context.theme.typography.sm,
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
