import 'package:flutter/material.dart';

class TransactionReceiptSelectionBar extends StatelessWidget {
  const TransactionReceiptSelectionBar({
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onShare,
    required this.onDownload,
    super.key,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onShare;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text('$selectedCount selected')),
            TextButton(
              onPressed: totalCount == 0 ? null : onSelectAll,
              child: Text(selectedCount == totalCount ? 'Clear' : 'Select all'),
            ),
            IconButton(
              tooltip: 'Share selected receipts',
              onPressed: selectedCount == 0 ? null : onShare,
              icon: const Icon(Icons.share_outlined),
            ),
            IconButton(
              tooltip: 'Download selected receipts',
              onPressed: selectedCount == 0 ? null : onDownload,
              icon: const Icon(Icons.download_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
