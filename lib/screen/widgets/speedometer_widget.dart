import 'package:anysend/transfer/speedometer.dart';
import 'package:anysend/utils/data.dart';
import 'package:anysend/widgets/transfer_progress.dart';
import 'package:flutter/material.dart';

class SpeedometerWidget extends StatelessWidget {
  const SpeedometerWidget({
    super.key,
    required this.speedometerReadingsStream,
    this.showSpeed = true,
  });

  final Stream<SpeedometerReading?> speedometerReadingsStream;
  final bool showSpeed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: speedometerReadingsStream,
      builder: (context, asyncSnapshot) {
        final data = asyncSnapshot.data;
        return Stack(
          children: [
            TransferProgressIndicator(
              progress: data?.progress ?? 0,
              height: 48,
            ),
            if (showSpeed && data != null)
              Positioned(
                right: 4,
                bottom: 2,
                child: Center(
                  child: Text(
                    formatTransferRate(data.speedBps),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
