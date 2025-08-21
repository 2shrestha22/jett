import 'package:anysend/core/hooks.dart';
import 'package:anysend/model/transfer_status.dart';
import 'package:anysend/screen/widgets/file_info_stream_builder.dart';
import 'package:anysend/screen/widgets/speedometer_widget.dart';
import 'package:anysend/transfer/speedometer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:forui/forui.dart';

enum TransferType { send, receive }

class TransferScreen extends StatefulHookWidget {
  final TransferType transferType;
  final Stream<SpeedometerReading?> speedometerReadingStream;
  final Stream<String> fileNameStream;

  final ValueNotifier<TransferState> transferNotifier;

  const TransferScreen({
    super.key,
    required this.transferType,
    required this.speedometerReadingStream,
    required this.fileNameStream,
    required this.transferNotifier,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  @override
  Widget build(BuildContext context) {
    final ipAddress = useLocalAddress();

    return FScaffold(
      header: FHeader.nested(
        title: switch (widget.transferType) {
          TransferType.receive => Text('Receiving Files'),
          TransferType.send => Text('Sending Files'),
        },
        prefixes: [
          FButton.icon(
            onPress: () =>
                Navigator.pop(context, widget.transferNotifier.value),
            child: Icon(FIcons.x),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            children: [
              Spacer(),
              SpeedometerWidget(
                speedometerReadingsStream: widget.speedometerReadingStream,
              ),
              HookBuilder(
                builder: (context) {
                  final transferState = useListenable(widget.transferNotifier);
                  return switch (transferState.value) {
                    TransferState.idle => SizedBox.shrink(),
                    TransferState.waiting => Text('Waiting for receiver'),
                    TransferState.inProgress => FileInfoStreamBuilder(
                      stream: widget.fileNameStream,
                    ),
                    TransferState.completed => Text('Transfer completed'),
                    TransferState.failed => Text('Transfer failed'),
                  };
                },
              ),
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
