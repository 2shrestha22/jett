import 'dart:io';

import 'package:jett/model/resource.dart';
import 'package:jett/utils/io.dart';
import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

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

    return DropRegion(
      formats: [Formats.fileUri],
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        // This drop region only supports copy operation.
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          return DropOperation.copy;
        } else {
          return DropOperation.none;
        }
      },
      onDropEnter: (event) {
        // This is called when region first accepts a drag. You can use this
        // to display a visual indicator that the drop is allowed.
      },
      onDropLeave: (event) {
        // Called when drag leaves the region. Will also be called after
        // drag completion.
        // This is a good place to remove any visual indicators.
      },
      onPerformDrop: (event) async {
        // Called when user dropped the item. You can now request the data.
        // Note that data must be requested before the performDrop callback
        // is over.
        final items = event.session.items;

        for (var item in items) {
          final dataReader = item.dataReader!;
          if (dataReader.canProvide(Formats.fileUri)) {
            dataReader.getValue(Formats.fileUri, (value) async {
              if (value != null) {
                final fileType = await FileSystemEntity.type(value.path);

                // TODO: support folder picking
                // note: for some file, filetype is not found in mac
                // but it works after renaming the file in the mac,
                // weird issue
                if (fileType == FileSystemEntityType.directory) return;
                onResourceAdd(
                  ContentResource(
                    uri: value.toString(),
                    name: value.pathSegments.last,
                  ),
                );
              }
            });
          }
        }
      },
      child: child,
    );
  }
}
