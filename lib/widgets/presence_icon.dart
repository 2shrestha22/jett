import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class PresenceIcon extends StatefulWidget {
  final Color? color;

  const PresenceIcon({super.key, this.color});

  @override
  State<PresenceIcon> createState() => _PresenceIconState();
}

class _PresenceIconState extends State<PresenceIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _RipplePainter(
                    progress: _controller.value,
                    color:
                        widget.color ??
                        context.theme.colors.secondaryForeground,
                  ),
                );
              },
            ),
          ),
          FAvatar.raw(child: Icon(FIcons.radio)),
        ],
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final paint = Paint()
      ..color = color.withValues(alpha: 1 - progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw expanding ripple
    canvas.drawCircle(center, maxRadius * progress, paint);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
