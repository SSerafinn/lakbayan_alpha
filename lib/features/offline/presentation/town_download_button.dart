import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../domain/downloads_controller.dart";
import "../domain/offline_bundle.dart";
import "../domain/offline_providers.dart";

/// Taking a town offline as one round control on glass: the download glyph,
/// the progress ring while it runs, a tap stopping it, and [done] once it is
/// on the phone, current or not. A failed attempt says why once, and the
/// glyph is back. The Town page and Offline.
class TownDownloadButton extends ConsumerWidget {
  const TownDownloadButton({
    required this.bundle,
    required this.done,
    super.key,
  });

  final OfflineBundle bundle;
  final Widget done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = bundle.townId;
    final town = bundle.name;
    final download = ref.watch(
      downloadsControllerProvider.select((downloads) => downloads[id]),
    );
    final state = ref.watch(townStatesProvider.select((states) => states[id]));
    final downloads = ref.read(downloadsControllerProvider.notifier);

    ref.listen(
      downloadsControllerProvider.select((downloads) => downloads[id]?.error),
      (_, error) {
        if (error == null || ModalRoute.of(context)?.isCurrent == false) return;
        // Nothing was kept, so the honest instruction is to try again.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(downloadStoreProvider).recordFor(id) == null
                  ? "That download didn't finish, and nothing was kept. $error"
                  : "That update didn't finish. Your previous download is still on this phone. $error",
            ),
          ),
        );
      },
    );

    if (download?.isRunning ?? false) {
      return Stack(
        alignment: Alignment.center,
        children: [
          SymbolButton(
            icon: AppIcons.close,
            tooltip: "Stop saving $town",
            onTap: () => downloads.cancel(id),
          ),
          IgnorePointer(
            child: SizedBox.square(
              dimension: AppSize.symbolButton,
              child: CircularProgressIndicator(
                // Nothing to measure while the file list is worked out.
                value: download!.progress.filesTotal == 0
                    ? null
                    : download.progress.fraction,
                strokeWidth: AppStroke.regular,
              ),
            ),
          ),
        ],
      );
    }
    if (state != null && state != TownState.absent) return done;
    return SymbolButton(
      icon: AppIcons.download,
      tooltip: "Save $town offline",
      onTap: () => unawaited(downloads.start(bundle)),
    );
  }
}
