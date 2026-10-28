import "package:flutter/material.dart";

import "../../router/app_router.dart";
import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_typography.dart";
import "../controls/symbol_button.dart";

/// A pushed page's top: back on its card circle, then the page's name large
/// under it, one or two words (D-19). Scrolls with the page.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SymbolButton(
        icon: AppIcons.back,
        tooltip: "Back",
        onTap: context.popOrHome,
        onGround: true,
      ),
      const SizedBox(height: AppSpace.x2),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.x1),
        child: Semantics(
          header: true,
          child: Text(title, style: AppTypography.display),
        ),
      ),
    ],
  );
}
