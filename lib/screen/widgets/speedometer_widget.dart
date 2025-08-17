import 'package:anysend/transfer/speedometer.dart';
import 'package:anysend/utils/data.dart';
import 'package:anysend/widgets/transfer_progress.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/transformers.dart';

class SpeedometerWidget extends StatelessWidget {
  const SpeedometerWidget({super.key, required this.speedometerReadingsStream});

  final Stream<SpeedometerReading?> speedometerReadingsStream;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder(
          stream: speedometerReadingsStream,
          builder: (context, asyncSnapshot) {
            final data = asyncSnapshot.data;
            if (data != null) {
              return TransferProgressIndicator(progress: data.progress);
            }
            return SizedBox.shrink();
          },
        ),
        Positioned(
          right: 4,
          bottom: 2,
          child: StreamBuilder(
            stream: speedometerReadingsStream.throttleTime(
              Duration(milliseconds: 500),
            ),
            builder: (context, asyncSnapshot) {
              final data = asyncSnapshot.data;
              if (data != null) {
                return Center(
                  child: Text(
                    formatTransferRate(data.speedBps),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}
