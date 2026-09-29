import "dart:math" as math;

import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_motion.dart";
import "../../theme/app_typography.dart";
import "../controls/symbol_button.dart";
import "../motion/motion.dart";

/// Presents [AppSheet] content modally: an interrupting task, so it gets the
/// scrim, rising from the bottom, dismissed by drag, the close symbol, a
/// scrim tap or system back.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  // Reduced motion keeps the platform's plain slide rather than jumping.
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? null
      : _sheetMotion,
  builder: builder,
);

/// Sheet motion: rides `AppMotion.chrome` up, leaves on the same spring reversed.
final _sheetMotion = AnimationStyle(
  duration: _sheetIn,
  curve: SpringCurve(AppMotion.chrome, _sheetIn),
  reverseDuration: _sheetOut,
  reverseCurve: SpringCurve(AppMotion.chrome, _sheetOut),
);
const _sheetIn = Duration(milliseconds: 460);
const _sheetOut = Duration(milliseconds: 320);

/// Shared scaffold for every modal sheet: handle, title, close button, scrollable
/// body, and optional pinned primary action. Height is capped at [AppSheetSize.form];
/// body shrinks with the keyboard, fixed parts never have to fit remaining space.
class AppSheet extends StatelessWidget {
  const AppSheet({
    required this.title,
    required this.slivers,
    this.action,
    this.fill = false,
    super.key,
  });

  final String title;
  final List<Widget> slivers;

  /// The pinned primary action, usually a full-width `FilledButton`.
  final Widget? action;

  final bool fill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;
    final action = this.action;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cap = math.min(
            screen * AppSheetSize.form,
            constraints.maxHeight,
          );
          final body = CustomScrollView(
            // A hugging sheet measures its body; a filling one does not
            // need to. The bodies that hug are short lists by construction.
            shrinkWrap: !fill,
            slivers: [
              ...slivers,
              if (action == null)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        MediaQuery.paddingOf(context).bottom + AppSpace.gutter,
                  ),
                ),
            ],
          );

          return AnimatedSize(
            duration: AppMotion.edge,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: cap,
                minHeight: fill ? cap : 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpace.x2),
                  Center(
                    child: SizedBox(
                      width: AppSize.dragHandleWidth,
                      height: AppSize.dragHandleHeight,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: scheme.outlineVariant,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ),
                  _Header(title: title),
                  if (fill) Expanded(child: body) else Flexible(child: body),
                  if (action != null)
                    SafeArea(
                      top: false,
                      minimum: const EdgeInsets.fromLTRB(
                        AppSpace.gutter,
                        AppSpace.x2,
                        AppSpace.gutter,
                        AppSpace.gutter,
                      ),
                      child: Pressable(child: action),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.gutter,
      AppSpace.x2,
      AppSpace.x2,
      0,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SymbolButton(
          icon: AppIcons.close,
          tooltip: "Close",
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

/// The standard inset for an [AppSheet] body sliver.
const appSheetBodyPadding = EdgeInsets.fromLTRB(
  AppSpace.gutter,
  AppSpace.x3,
  AppSpace.gutter,
  AppSpace.x3,
);
