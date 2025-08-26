import 'package:jett/core/hooks.dart';
import 'package:jett/utils/network.dart';
import 'package:jett/widgets/presence_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:forui/forui.dart';

class PresenceView extends HookWidget {
  const PresenceView({super.key});

  @override
  Widget build(BuildContext context) {
    final address = useLocalAddress();
    return Column(
      children: [
        PresenceIcon(),
        if (address.value?.isNotEmpty ?? false)
          Builder(
            builder: (context) {
              final addr = splitAddress(address.value!);
              return RichText(
                text: TextSpan(
                  text: 'IP Address: ${addr.$1}',
                  children: [
                    TextSpan(
                      text: addr.$2,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                  style: context.theme.typography.sm,
                ),
              );
            },
          ),
      ],
    );
  }
}
