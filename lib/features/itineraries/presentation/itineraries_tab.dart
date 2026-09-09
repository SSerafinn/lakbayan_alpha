import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/itinerary.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../auth/domain/auth_providers.dart";
import "../domain/itinerary_providers.dart";

/// Wireframe 1g — the Itineraries tab.
///
/// Two lists that look alike and are not the same thing. **Saved** are the
/// province's tours somebody kept; **Mine** are tours they built. They live in
/// different collections for a reason worth remembering here: `tours` is
/// admin-written, so a visitor could not put their own plan in it.
class ItinerariesTab extends ConsumerWidget {
  const ItinerariesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authStateProvider).value != null;
    final saved = ref.watch(savedToursProvider);
    final mine = ref.watch(myItinerariesProvider);

    if (!signedIn) return const _GuestPrompt();

    return ListView(
      padding: const EdgeInsets.all(AppSpace.x4),
      children: [
        Row(
          children: [
            Text("My itineraries", style: AppTypography.h3),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _createItinerary(context, ref),
              icon: const Icon(Icons.add),
              label: const Text("New"),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.x2),
        mine.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => _Error("Couldn't load your itineraries.", error: e),
          data: (items) => items.isEmpty
              ? const _Empty(
                  "Nothing planned yet. Make one and add stops from any "
                  "destination.",
                )
              : Column(
                  children: [
                    for (final itinerary in items)
                      _ItineraryRow(itinerary: itinerary),
                  ],
                ),
        ),

        const SizedBox(height: AppSpace.x6),
        Text("Saved tours", style: AppTypography.h3),
        const SizedBox(height: AppSpace.x2),
        saved.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => _Error("Couldn't load your saved tours.", error: e),
          data: (items) => items.isEmpty
              ? const _Empty(
                  "Tours you save from the province's list appear here.",
                )
              : Column(
                  children: [for (final tour in items) _TourRow(tour: tour)],
                ),
        ),
      ],
    );
  }
}

Future<void> _createItinerary(BuildContext context, WidgetRef ref) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => const _NameDialog(),
  );
  if (name == null || name.trim().isEmpty) return;

  final uid = ref.read(authStateProvider).value?.uid;
  if (uid == null) return;

  final id = await ref
      .read(itineraryRepositoryProvider)
      .create(uid, name: name.trim());
  if (context.mounted) context.push(Routes.itinerary(id));
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text("Name your itinerary"),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: "Two days in Peñablanca"),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text("Cancel"),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text("Create"),
      ),
    ],
  );
}

class _ItineraryRow extends StatelessWidget {
  const _ItineraryRow({required this.itinerary});

  final Itinerary itinerary;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    final count = itinerary.destinationIds.length;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.route_outlined),
      title: Text(itinerary.name, style: AppTypography.title),
      subtitle: Text(
        count == 0
            ? "No stops yet"
            : "$count stop${count == 1 ? "" : "s"}"
                  "${itinerary.isRoutable ? "" : " · add one more to draw a route"}",
        style: AppTypography.caption.copyWith(color: c.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(Routes.itinerary(itinerary.id)),
    );
  }
}

class _TourRow extends ConsumerWidget {
  const _TourRow({required this.tour});

  final Tour tour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lakbayan;
    final count = tour.stops.length;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.tour_outlined),
      title: Text(tour.title, style: AppTypography.title),
      subtitle: Text(
        "$count stop${count == 1 ? "" : "s"}",
        style: AppTypography.caption.copyWith(color: c.textSecondary),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.bookmark_remove_outlined),
        tooltip: "Remove from saved",
        onPressed: () {
          final uid = ref.read(authStateProvider).value?.uid;
          if (uid == null) return;
          ref
              .read(userProfileRepositoryProvider)
              .setTourSaved(uid, tour.id, saved: false);
        },
      ),
    );
  }
}

class _GuestPrompt extends ConsumerWidget {
  const _GuestPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lakbayan;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Plans need an account", style: AppTypography.h3),
            const SizedBox(height: AppSpace.x2),
            Text(
              // Says what signing in buys, rather than simply refusing.
              // Browsing and downloading both work without one, so the reason
              // has to be specific or it reads as an arbitrary gate.
              "Itineraries are kept with your account so they follow you to "
              "another phone. Browsing and downloading a town work without "
              "signing in.",
              style: AppTypography.body.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.x5),
            FilledButton(
              onPressed: () => ref.read(guestModeProvider.notifier).disable(),
              child: const Text("Sign in"),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.x3),
    child: Text(
      text,
      style: AppTypography.body.copyWith(color: context.lakbayan.textSecondary),
    ),
  );
}

class _Error extends StatelessWidget {
  const _Error(this.text, {required this.error});

  final String text;
  final Object error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.x3),
    child: Text(
      "$text\n$error",
      style: AppTypography.body.copyWith(
        color: context.lakbayan.badgeErrorText,
      ),
    ),
  );
}
