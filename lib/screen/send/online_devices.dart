import 'dart:async';

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
          if (notifier.devices.isEmpty) return const _LookingForDevices();
          return Wrap(
            spacing: 8,
            children: notifier.devices
                .map(
                  (device) => FButton(
                    mainAxisSize: MainAxisSize.min,
                    prefix: Icon(
                      device.isSupported
                          ? FLucideIcons.send
                          : FLucideIcons.circleAlert,
                    ),
                    // a device on an older build cannot be sent to at all,
                    // so say why rather than letting the send fail
                    onPress: device.isSupported ? () => onTap(device) : null,
                    child: Text(
                      device.isSupported
                          ? device.name
                          : '${device.name} — needs updating',
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

/// The empty state of the device list.
///
/// Separate, and stateful, for one reason: a spinner that never resolves is the
/// worst thing this screen can show. Discovery failing looks exactly like
/// discovery still going — the usual causes are the two devices being on
/// different networks, or the other one not having Jett open — and neither is
/// something the app can detect or fix on its own. So after a while it stops
/// implying that waiting longer will help and says what to check.
class _LookingForDevices extends StatefulWidget {
  const _LookingForDevices();

  @override
  State<_LookingForDevices> createState() => _LookingForDevicesState();
}

class _LookingForDevicesState extends State<_LookingForDevices> {
  /// Long enough that a device appearing normally never shows the hint, short
  /// enough to arrive while the person is still looking at the screen.
  static const _hintAfter = Duration(seconds: 8);

  Timer? _timer;
  bool _takingLong = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_hintAfter, () {
      if (mounted) setState(() => _takingLong = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            FCircularProgress.loader(),
            const Text('Looking for nearby devices...'),
          ],
        ),
        if (_takingLong)
          Text(
            'Check both devices are on the same Wi-Fi network, and that Jett '
            'is open on the other one.',
            textAlign: TextAlign.center,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
      ],
    );
  }
}
