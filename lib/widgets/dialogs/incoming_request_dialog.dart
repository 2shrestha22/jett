import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:jett/adaptive_dialog.dart';
import 'package:jett/transfer/protocol.dart';
import 'package:jett/utils/data.dart';
import 'package:jett/widgets/dialogs/verification_words.dart';

/// Asks whether to accept the files a peer is offering.
///
/// Presentation only; the caller decides what an answer means and handles a
/// prompt that is closed from under it.
///
/// Returns true to accept, false to decline, null if it was dismissed — which
/// the caller should read as a decline.
Future<bool?> showIncomingRequestDialog(
  BuildContext context, {
  required String senderLabel,
  required List<OfferedFile> files,
  required int totalSize,
  required List<String> words,
}) {
  final summary = files.length == 1
      ? files.single.name
      : '${files.length} files';

  return showFDialog<bool>(
    context: context,
    builder: (context, _, _) {
      final theme = context.theme;
      return AdaptiveDialog(
        title: const Text('Incoming File Transfer'),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: senderLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        ' wants to send you $summary '
                        '(${formatFileSize(totalSize)}).',
                  ),
                ],
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
            // Reference material, not a second question; whether the words
            // match is decided on the sending device. Accepting here is
            // about the files.
            if (words.isNotEmpty) ...[
              Text(
                'This device is showing these words to $senderLabel.',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              VerificationWords(words),
            ],
          ],
        ),
        actions: [
          FButton(
            variant: .secondary,
            onPress: () => Navigator.pop(context, false),
            child: const Text('Decline'),
          ),
          FButton(
            variant: .primary,
            onPress: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      );
    },
  );
}
