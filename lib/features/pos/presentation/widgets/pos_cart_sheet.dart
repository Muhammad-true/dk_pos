import 'package:flutter/material.dart';

import 'pos_cart_panel.dart';

void showPosCartSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (_, scrollCtrl) {
            return PosCartPanel(
              scrollController: scrollCtrl,
              onClose: () => Navigator.pop(ctx),
            );
          },
        ),
      );
    },
  );
}
