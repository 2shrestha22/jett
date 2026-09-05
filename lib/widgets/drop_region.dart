import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:jett/model/resource.dart';
import 'package:jett/utils/io.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class FileDropRegion extends StatelessWidget {
  final void Function(Resource resource) onResourceAdd;
  final Widget child;

  const FileDropRegion({
    super.key,
    required this.onResourceAdd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // only support drop region for desktop
    if (!isDesktop) return child;

    return DropTarget(
      onDragEntered: (details) {
        // This is called when region first accepts a drag. You can use this
        // to display a visual indicator that the drop is allowed.
      },
      onDragExited: (details) {
        // Called when drag leaves the region. Will also be called after
        // drag completion.
        // This is a good place to remove any visual indicators.
      },
      onDragDone: (details) async {
        for (final item in details.files) {
          // TODO: support folder picking
          if (item is DropItemDirectory) continue;
          // directories come through as plain files on windows/linux
          final type = await FileSystemEntity.type(item.path);
          if (type == FileSystemEntityType.directory) continue;

          // on macOS, files dropped from outside the app container need
          // security-scoped access before they can be read; keep the access
          // for the session since the file is read later during transfer
          final bookmark = item.extraAppleBookmark;
          if (Platform.isMacOS && bookmark != null && bookmark.isNotEmpty) {
            await DesktopDrop.instance.startAccessingSecurityScopedResource(
              bookmark: bookmark,
            );
          }

          onResourceAdd(
            ContentResource(uri: item.path, name: p.basename(item.path)),
          );
        }
      },
      child: child,
    );
  }
}
