import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../config/app_config.dart";
import "../../firebase/demo_firebase_options.dart";
import "../../firebase/firebase_bootstrap.dart";
import "../../firebase/firebase_status_provider.dart";
import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";

/// A thin strip along the bottom saying which backend the app is talking to.
///
/// The CMS has had one of these since CMS-0 and the app did not, which is a
/// large part of why a misconfigured backend was so hard to spot here: an
/// unreachable emulator and an empty database look exactly alike on Explore,
/// and neither says anything in the logs once startup has scrolled past.
///
/// **Debug builds only.** Wrapped in [kDebugMode] so the tree is compiled out
/// of a release build, on top of [AppConfig.useFirebaseEmulators] already being
/// a `const false` there. A shipped app cannot render this.
///
/// A strip rather than an overlay: it takes its own space at the bottom instead
/// of floating over the bottom navigation, so it can never cover a control.
class DevStatusBanner extends ConsumerWidget {
  const DevStatusBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(firebaseBootstrapStatusProvider);

    // Null in tests and in release; `live` needs no announcement, because that
    // is what a real build is supposed to be doing.
    if (!kDebugMode ||
        status == null ||
        status == FirebaseBootstrapStatus.live) {
      return child;
    }

    return Column(
      children: [
        Expanded(child: child),
        _Strip(status: status),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.status});

  final FirebaseBootstrapStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Colours come from the scheme rather than the brand ramps: this is
    // developer chrome, not product surface, and it must read as "not part of
    // the app". See docs/DESIGN_SYSTEM.md on not hardcoding brand colour.
    final (background, foreground, icon, message) = switch (status) {
      FirebaseBootstrapStatus.emulators => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        AppIcons.developer,
        "Emulators · ${AppConfig.emulatorHost}",
      ),
      FirebaseBootstrapStatus.emulatorsUnreachable => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        AppIcons.offline,
        "No emulator at ${AppConfig.emulatorHost} — lists will look empty",
      ),
      // The one that looked exactly like success: reachable, signed in, and
      // reading an empty database that is not the one anybody seeded. It
      // names the project the suite uses, because "which project am I on" is
      // the question nobody thinks to ask when everything appears to work.
      FirebaseBootstrapStatus.emulatorsWrongProject => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        AppIcons.warning,
        "Not the emulators' project (${demoFirebaseOptions.projectId}) — "
            "lists will look empty",
      ),
      FirebaseBootstrapStatus.unavailable => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        AppIcons.warning,
        "Firebase failed to start — nothing will load",
      ),
      FirebaseBootstrapStatus.live => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        AppIcons.cloud,
        "Live project",
      ),
    };

    return Material(
      color: background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x3,
            vertical: AppSpace.x1,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppSize.glyphXs, color: foreground),
              const SizedBox(width: AppSpace.x2),
              Flexible(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: foreground),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
