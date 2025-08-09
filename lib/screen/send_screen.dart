import 'dart:io';

import 'package:anysend/discovery/konst.dart';
import 'package:anysend/model/device.dart';
import 'package:anysend/notifier/device.dart';
import 'package:anysend/discovery/multicast.dart';
import 'package:anysend/transfer/client.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final sender = Sender();

  final notifier = ReceiversNotifier();

  @override
  void initState() {
    super.initState();
    _initSender();
  }

  Future<void> _initSender() async {
    await sender.listenMessage((message, ipAddress, port) {
      setState(() {
        notifier.add(
          Device(
            ipAddress: ipAddress,
            port: port,
            name: message.name,
            lastSeen: DateTime.now(),
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Screen')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ListenableBuilder(
              listenable: notifier,
              builder: (context, child) {
                return ActiveDevices(
                  devices: notifier.devices,
                  onTap: (device) {
                    FilePicker.platform
                        .pickFiles(allowMultiple: true, type: FileType.any)
                        .then((result) {
                          if (result != null && result.files.isNotEmpty) {
                            final files = result.files
                                .map((file) => File(file.path!))
                                .toList();
                            Client().upload(files, device.ipAddress, kTcpPort);
                          } else {
                            print('No files selected');
                          }
                        });
                  },
                );
              },
            ),
            TextButton(
              onPressed: () {
                // Handle button press
              },
              child: const Text('Send'),
            ),
            TextButton(
              onPressed: () {
                // Handle another button press
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    sender.close();
    notifier.dispose();
    super.dispose();
  }
}

class ActiveDevices extends StatelessWidget {
  const ActiveDevices({super.key, required this.devices, required this.onTap});

  final void Function(Device device) onTap;
  final List<Device> devices;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const Text('No active devices found');
    }
    return Column(
      spacing: 8,
      children: devices.map((device) {
        return ListTile(
          title: Text(device.name),
          subtitle: Text('${device.ipAddress}:${device.port}'),
          onTap: () => onTap(device),
        );
      }).toList(),
    );
  }
}
