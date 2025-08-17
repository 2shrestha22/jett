import 'dart:async';
import 'dart:developer';

import 'package:anysend/model/device.dart';
import 'package:anysend/model/file_info.dart';
import 'package:anysend/screen/widgets/file_info_stream_builder.dart';
import 'package:anysend/screen/widgets/speedometer_widget.dart';
import 'package:anysend/transfer/client.dart';
import 'package:anysend/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

enum SendState { waiting, rejected, inProgress, failed, completed }

class SendDialog extends StatefulWidget {
  final Device device;
  final List<FileInfo> files;

  const SendDialog({super.key, required this.device, required this.files});

  @override
  State<SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends State<SendDialog> {
  late final Client client;
  SendState sendState = SendState.waiting;
  late Completer<void> _abortTrigger;

  @override
  void initState() {
    super.initState();
    client = Client(
      onUploadStart: _onUploadStartHandler,
      onUploadFinish: _onUploadFinishHandler,
    );
    _initTransfer();
  }

  _initTransfer() async {
    try {
      final request = await client.requestUpload(widget.device.ipAddress);
      // do nothing if user already closed the dialog to cancel the transfer
      if (!mounted) return;

      if (request) {
        _abortTrigger = Completer<void>();
        await client.upload(
          widget.files,
          widget.device.ipAddress,
          _abortTrigger.future,
        );
        // do nothing if user already closed the dialog to cancel the transfer
        if (!mounted) return;

        setState(() {
          sendState = SendState.completed;
        });
      } else {
        setState(() {
          sendState = SendState.rejected;
        });
      }
    } catch (e) {
      log(e.toString());
      setState(() {
        sendState = SendState.failed;
      });
    }
  }

  void _onUploadStartHandler() {
    setState(() {
      sendState = SendState.inProgress;
    });
  }

  void _onUploadFinishHandler() async {
    setState(() {
      sendState = SendState.inProgress;
    });
  }

  Widget _getTitle() {
    return switch (sendState) {
      SendState.waiting => Text('Requesting transfer'),
      SendState.inProgress => Text('Sending files'),
      SendState.completed => Text('Transfer complete'),
      SendState.rejected => Text('Request rejected'),
      SendState.failed => Text('Transfer failed'),
    };
  }

  List<Widget> _getActionButton() {
    return switch (sendState) {
      SendState.waiting || SendState.inProgress => [
        FButton(
          style: FButtonStyle.primary(),
          onPress: () {
            if (sendState == SendState.inProgress) {
              // client.abort();
              _abortTrigger.complete();
            } else {
              Navigator.pop(context);
            }
          },
          child: Text('Cancel'),
        ),
      ],
      _ => [
        FButton(
          style: FButtonStyle.primary(),
          onPress: () => Navigator.pop(context),
          child: Text('Ok'),
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    return FDialog.adaptive(
      title: _getTitle(),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sendState == SendState.waiting)
            Text('Waiting for receiver to accept transfer...'),
          if (sendState == SendState.inProgress)
            SpeedometerWidget(
              speedometerReadingsStream: client.speedometerReadingsStream,
            ),
          if (sendState == SendState.inProgress)
            FileInfoStreamBuilder(stream: client.fileNameStream),
          if (sendState == SendState.completed)
            Text(
              'Sent ${widget.files.length} files to ${widget.device.name} at ${formatTransferRate(client.speedometerReadings?.avgSpeedBps ?? 0)}',
            ),
        ],
      ),
      actions: _getActionButton(),
    );
  }
}
