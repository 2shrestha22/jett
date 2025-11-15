import 'package:flutter/material.dart';

class TransferProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final double height;

  const TransferProgressIndicator({
    super.key,
    required this.progress,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        final fillWidth = barWidth * progress;
        final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Background
            Container(
              height: height,
              decoration: BoxDecoration(color: Colors.grey[300]),
            ),

            // Filled portion
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: height,
                width: fillWidth,
                decoration: BoxDecoration(color: Colors.black),
              ),
            ),

            // Percentage text with dynamic color
            SizedBox(
              width: constraints.maxWidth,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    colors: [
                      Colors.white, // over filled part
                      Colors.black, // over empty part
                    ],
                    stops: [
                      (fillWidth / barWidth).clamp(0.0, 1.0),
                      (fillWidth / barWidth).clamp(0.0, 1.0),
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
