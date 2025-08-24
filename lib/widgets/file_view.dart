import 'package:jett/utils/data.dart' show formatFileSize;
import 'package:jett/model/resource.dart';
import 'package:flutter/material.dart';
import 'package:forui/assets.dart';
import 'package:forui/widgets/tile.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

class FileInfoTile extends StatefulWidget {
  final Resource resource;
  final int? fileSize;
  final VoidCallback onRemoveTap;

  const FileInfoTile({
    super.key,
    required this.resource,
    this.fileSize,
    required this.onRemoveTap,
  });

  @override
  State<FileInfoTile> createState() => _FileInfoTileState();
}

class _FileInfoTileState extends State<FileInfoTile> {
  late final String fileType;
  late final IconData icon;

  @override
  void initState() {
    super.initState();
    fileType = p
        .extension(widget.resource.name)
        .replaceFirst('.', '')
        .toUpperCase();

    switch (fileType) {
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'GIF':
        icon = FIcons.fileImage;
        break;
      case 'MP3':
      case 'WAV':
        icon = FIcons.fileMusic;
        break;
      case 'MP4':
      case 'AVI':
      case 'MOV':
        icon = FIcons.fileVideo;
        break;
      case 'ZIP':
      case 'RAR':
        icon = FIcons.fileArchive;
        break;
      case 'PDF':
      case 'DOC':
      case 'DOCX':
        icon = FIcons.fileType;
        break;
      case 'TXT':
        icon = FIcons.fileText;
        break;
      case 'APK':
        icon = Icons.android;
        break;
      default:
        icon = FIcons.file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FTile(
      prefix: Icon(icon, color: Colors.blue),
      title: Text(widget.resource.name, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Text(fileType),
          if (widget.fileSize != null)
            Text('• ${formatFileSize(widget.fileSize!)}'),
        ],
      ),
      suffix: IconButton(
        onPressed: widget.onRemoveTap,
        icon: Icon(LucideIcons.x),
      ),
    );
  }
}
