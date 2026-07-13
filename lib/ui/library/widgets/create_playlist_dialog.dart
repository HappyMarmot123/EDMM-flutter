import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

Future<String?> showCreatePlaylistDialog(
  BuildContext context, {
  required Key fieldKey,
  required Key confirmKey,
}) {
  final l10n = AppLocalizations.of(context);
  var playlistName = '';
  var showNameError = false;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        void submit() {
          final normalizedName = playlistName.trim();
          if (normalizedName.isEmpty) {
            setDialogState(() => showNameError = true);
            return;
          }
          Navigator.pop(dialogContext, normalizedName);
        }

        return AlertDialog(
          title: Text(l10n.playlistCreate),
          content: TextField(
            key: fieldKey,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.playlistName,
              errorText: showNameError ? '${l10n.playlistName} *' : null,
            ),
            onChanged: (value) {
              playlistName = value;
              if (showNameError && value.trim().isNotEmpty) {
                setDialogState(() => showNameError = false);
              }
            },
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              key: confirmKey,
              onPressed: submit,
              child: Text(l10n.playlistCreate),
            ),
          ],
        );
      },
    ),
  );
}
