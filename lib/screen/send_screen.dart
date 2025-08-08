import 'package:anysend/model/device.dart';
import 'package:anysend/notifier/device.dart';
import 'package:anysend/discovery/multicast.dart';
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
    await sender.listenMessage((message) {
      setState(() {
        notifier.add(
          Device(
            ipAddress: message.ipAddress,
            port: message.port,
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
              builder: (context, child) =>
                  ActiveDevices(devices: notifier.devices),
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
  const ActiveDevices({super.key, required this.devices});

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
        );
      }).toList(),
    );
  }
}
