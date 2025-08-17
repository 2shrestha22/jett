import 'package:flutter/material.dart';

class FileInfoStreamBuilder extends StatelessWidget {
  const FileInfoStreamBuilder({super.key, required this.stream});
  final Stream<String> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text(
            snapshot.data!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        return Text('Sending files...');
      },
    );
  }
}
