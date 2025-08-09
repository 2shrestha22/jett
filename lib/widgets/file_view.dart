import 'dart:io';

import 'package:anysend/utils/file_size.dart' show formatFileSize;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class FileInfoTile extends StatelessWidget {
  final String filePath;
  final int? fileSize;

  const FileInfoTile({super.key, required this.filePath, this.fileSize});

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(filePath);
    final fileType = p.extension(filePath).replaceFirst('.', '').toUpperCase();

    return ListTile(
      leading: Icon(Icons.insert_drive_file, color: Colors.blue),
      title: Text(fileName, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Text("$fileType • "),
          if (fileSize != null)
            Text(formatFileSize(fileSize!))
          else
            FileSizeWidget(filePath: filePath),
        ],
      ),
    );
  }
}

class FileSizeWidget extends StatefulWidget {
  const FileSizeWidget({super.key, required this.filePath});
  final String filePath;

  @override
  State<FileSizeWidget> createState() => _FileSizeWidgetState();
}

class _FileSizeWidgetState extends State<FileSizeWidget> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: File(widget.filePath).length(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final fileSize = snapshot.data!;
          return Text(formatFileSize(fileSize));
        }
        return Text('');
      },
    );
  }
}
