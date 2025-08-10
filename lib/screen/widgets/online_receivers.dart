import 'package:anysend/model/device.dart';
import 'package:anysend/widgets/loader.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class OnlineRecivers extends StatelessWidget {
  const OnlineRecivers({super.key, required this.devices, required this.onTap});

  final List<Device> devices;

  final void Function(Device device) onTap;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        if (devices.isEmpty) {
          return const Center(
            child: Column(
              spacing: 8,
              mainAxisSize: MainAxisSize.min,
              children: [Text('Searching for devices...'), Loader()],
            ),
          );
        }
        return Column(
          children: devices.map((device) {
            return ListTile(
              leading: Icon(LucideIcons.monitorSmartphone),
              title: Text(device.name),
              subtitle: Text(device.ipAddress),
              onTap: () => onTap(device),
            );
          }).toList(),
        );
      },
    );
  }
}
