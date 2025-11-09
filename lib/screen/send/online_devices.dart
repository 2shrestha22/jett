import 'package:jett/model/device.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class OnlineDevices extends StatelessWidget {
  final void Function(Device device) onTap;
  final Stream<List<Device>> stream;

  const OnlineDevices({super.key, required this.onTap, required this.stream});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: StreamBuilder(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                FProgress.circularIcon(),
                Text('Looking for nearby devices...'),
              ],
            );
          }
          return Wrap(
            spacing: 8,
            children: snapshot.data!
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
