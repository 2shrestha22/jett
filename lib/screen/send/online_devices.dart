import 'package:anysend/model/device.dart';
import 'package:anysend/screen/send/presence_notifier.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class OnlineDevices extends StatelessWidget {
  final void Function(Device device) onTap;
  final PresenceNotifier notifier;

  const OnlineDevices({super.key, required this.onTap, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListenableBuilder(
          listenable: notifier,
          builder: (context, child) {
            if (notifier.devices.isEmpty) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  FProgress.circularIcon(),
                  Text('Looking for nearby devices...'),
                ],
              );
            }
            return Row(
              spacing: 8,
              mainAxisAlignment: MainAxisAlignment.center,
              children: notifier.devices
                  .map(
                    (device) => FButton(
                      prefix: Icon(FIcons.send),
                      onPress: () => onTap(device),
                      child: Text(device.name),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}
