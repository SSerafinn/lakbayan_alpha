import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../auth/domain/auth_providers.dart";

/// Me as a circle: my photo, else my initial in emerald words on the emerald
/// wash; a guest's is the account glyph. Profile's, large on its cover with
/// a paper [ring], and Explore's, small at the top trailing corner.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({required this.size, this.ring, super.key});

  /// The circle's outer size, the ring included.
  final double size;

  /// A paper ring that lifts the circle off a photo (Profile's cover).
  final double? ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.lakbayan;
    final ink = brand.textOnLightGreen;
    final ring = this.ring ?? 0;
    final inner = size - 2 * ring;
    // The initial in the size of the circle around it.
    final type = size >= AppSize.avatar
        ? AppTypography.display
        : AppTypography.titleMedium;

    final Widget face;
    if (ref.watch(guestModeProvider)) {
      face = Icon(AppIcons.account, size: inner / 2, color: ink);
    } else {
      final user = ref.watch(authStateProvider).value;
      final label = user?.label ?? "";
      final initial = Text(
        label.isEmpty ? "?" : label.characters.first.toUpperCase(),
        style: type.copyWith(color: ink),
      );
      final photo = user?.photoUrl;
      face = photo == null
          ? initial
          : ClipOval(
              child: Image.network(
                photo,
                fit: BoxFit.cover,
                width: inner,
                height: inner,
                cacheWidth: (inner * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => initial,
              ),
            );
    }

    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: brand.tint,
        shape: CircleBorder(
          side: ring == 0
              ? BorderSide.none
              : BorderSide(
                  color: Theme.of(context).colorScheme.surface,
                  width: ring,
                ),
        ),
      ),
      padding: EdgeInsets.all(ring),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: face,
    );
  }
}
