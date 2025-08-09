import 'package:flutter/material.dart';

class TransferProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 - 1.0

  const TransferProgressIndicator({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        final fillWidth = barWidth * progress;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Background
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: Colors.grey[300], // background color
              ),
            ),

            // Filled portion
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 28,
                width: fillWidth,
                decoration: BoxDecoration(
                  color: Colors.black, // filled color
                ),
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
                  "$percent%",
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
