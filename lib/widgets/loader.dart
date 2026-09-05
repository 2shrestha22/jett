import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:forui/forui.dart';

class Loader extends StatelessWidget {
  const Loader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(FLucideIcons.loader)
        .animate(onPlay: (c) => c.repeat())
        .rotate(duration: Durations.extralong4);
  }
}
