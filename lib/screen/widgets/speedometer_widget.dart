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
    return SizedBox(
      height: 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
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
          StreamBuilder(
            stream: speedometerReadingsStream.throttleTime(
              Duration(milliseconds: 500),
            ),
            builder: (context, asyncSnapshot) {
              final data = asyncSnapshot.data;
              if (data != null) {
                return Center(
                  child: Text(
                    formatTransferRate(data.avgSpeedBps),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
