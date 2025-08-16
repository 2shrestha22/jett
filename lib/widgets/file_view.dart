import 'dart:io';

import 'package:anysend/utils/data.dart' show formatFileSize;
import 'package:flutter/material.dart';
import 'package:forui/widgets/tile.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

class FileInfoTile extends StatelessWidget {
  final String fileName;
  final int? fileSize;
  final VoidCallback onRemoveTap;

  const FileInfoTile({
    super.key,
    required this.fileName,
    this.fileSize,
    required this.onRemoveTap,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(this.fileName);
    final fileType = p
        .extension(this.fileName)
        .replaceFirst('.', '')
        .toUpperCase();

    return FTile(
      prefix: Icon(Icons.insert_drive_file, color: Colors.blue),
      title: Text(fileName, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Text("$fileType • "),
          if (fileSize != null)
            Text(formatFileSize(fileSize!))
          else
            FileSizeWidget(filePath: this.fileName),
        ],
      ),
      suffix: IconButton(onPressed: onRemoveTap, icon: Icon(LucideIcons.x)),
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
