import "package:flutter/material.dart";

import "../../router/app_router.dart";
import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_typography.dart";

/// A pushed page's title beside a plain back target. Scrolls with the page.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        icon: const Icon(AppIcons.back, size: AppSize.glyphMd),
        tooltip: "Back",
        constraints: const BoxConstraints.tightFor(
          width: AppSize.minTouchTarget,
          height: AppSize.minTouchTarget,
        ),
        onPressed: context.popOrHome,
      ),
      const SizedBox(width: AppSpace.x1),
      Expanded(
        child: Semantics(
          header: true,
          child: Text(title, style: AppTypography.display),
        ),
      ),
    ],
  );
}
