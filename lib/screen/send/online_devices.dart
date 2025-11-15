import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:jett/model/device.dart';
import 'package:jett/screen/send/presence_notifier.dart';

class OnlineDevices extends StatelessWidget {
  final void Function(Device device) onTap;
  final PresenceNotifier notifier;

  const OnlineDevices({super.key, required this.onTap, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListenableBuilder(
        listenable: notifier,
        builder: (context, child) {
          if (notifier.devices.isEmpty) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                FCircularProgress.loader(),
                Text('Looking for nearby devices...'),
              ],
            );
          }
          return Wrap(
            spacing: 8,
            children: notifier.devices
                .map(
                  (device) => FButton(
                    mainAxisSize: MainAxisSize.min,
                    prefix: Icon(FIcons.send),
                    onPress: () => onTap(device),
                    child: Text(device.name),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
