import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/widgets/storage_image.dart";
import "../../audio/presentation/audio_guide_section.dart";
import "../domain/destination_providers.dart";

/// Wireframe 1d, screen 5 — Destination Detail.
///
/// Opens as a full-height sheet over the map or list, which is why it closes
/// with ✕ rather than a back arrow and shows no tab bar.
class DestinationDetailScreen extends ConsumerWidget {
  const DestinationDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(destinationByIdProvider(id));

    return Scaffold(
      body: destination.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message("Couldn't load this destination.\n$e"),
        data: (d) => d == null
            ? const _Message("This destination is no longer available.")
            : _Content(destination: d),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lakbayan;
    final segments = ref.watch(destinationSegmentsProvider(destination.id));
    final segmentCount = segments.value?.length ?? 0;

    return Column(
      children: [
        _Carousel(destination: destination),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.x4),
            children: [
              Text(destination.name, style: AppTypography.h2),
              const SizedBox(height: AppSpace.x1),
              Text(
                [
                  destination.town,
                  if (destination.isMuseum) "museum site",
                  if (segmentCount > 0)
                    "$segmentCount audio segment${segmentCount == 1 ? "" : "s"}",
                ].join(" · "),
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpace.x4),
              Text(destination.description, style: AppTypography.bodyLarge),

              if (destination.history case final history?
                  when history.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpace.x4),
                Text(history, style: AppTypography.body),
              ],

              if (destination.practical case final info?) _Practical(info),

              if (destination.tags.isNotEmpty) ...[
                const SizedBox(height: AppSpace.x5),
                Wrap(
                  spacing: AppSpace.x2,
                  runSpacing: AppSpace.x2,
                  children: [
                    for (final tag in destination.tags)
                      LakbayanBadge(tag, kind: BadgeKind.neutral),
                  ],
                ),
              ],

              const SizedBox(height: AppSpace.x6),
              Row(
                children: [
                  Text("Audio guide", style: AppTypography.h3),
                  const Spacer(),
                  if (segmentCount == 0)
                    Text("Coming soon", style: AppTypography.caption),
                ],
              ),
              const SizedBox(height: AppSpace.x2),
              segments.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(
                  "Couldn't load the audio guide.",
                  style: AppTypography.body.copyWith(color: c.badgeErrorText),
                ),
                data: (items) => AudioGuideSection(
                  destinationId: destination.id,
                  segments: items,
                ),
              ),
            ],
          ),
        ),
        _Actions(destination: destination),
      ],
    );
  }
}

class _Carousel extends StatefulWidget {
  const _Carousel({required this.destination});

  final Destination destination;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.destination.images;

    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          Positioned.fill(
            child: images.isEmpty
                ? const ImagePlaceholder(borderRadius: BorderRadius.zero)
                : PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: images.length,
                    itemBuilder: (context, i) => StorageImage(path: images[i]),
                  ),
          ),

          // ✕, not a back arrow: this is a sheet over the map or list.
          Positioned(
            top: AppSpace.x4,
            left: AppSpace.x4,
            child: _RoundButton(
              icon: Icons.close,
              onTap: () => context.canPop() ? context.pop() : context.go("/"),
            ),
          ),

          if (widget.destination.hasAR)
            const Positioned(
              top: AppSpace.x4,
              right: AppSpace.x4,
              child: LakbayanBadge.ar(),
            ),

          // Dots only when there is something to page through — the wireframe
          // falls back to a single image without them.
          if (images.length > 1)
            Positioned(
              bottom: AppSpace.x3,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length; i++)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(
                          alpha: i == _page ? 1 : 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.45),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}

class _Practical extends StatelessWidget {
  const _Practical(this.info);

  final PracticalInfo info;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (info.openHours case final v? when v.isNotEmpty) ("Hours", v),
      if (info.entryFee case final v? when v.isNotEmpty) ("Entry", v),
      if (info.bestSeason case final v? when v.isNotEmpty) ("Best season", v),
      if (info.accessibility case final v? when v.isNotEmpty)
        ("Accessibility", v),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    final c = context.lakbayan;
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.x5),
      padding: const EdgeInsets.all(AppSpace.x4),
      decoration: BoxDecoration(
        color: c.greenSubtle,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(label, style: AppTypography.label),
                  ),
                  // Rendered as written. openHours is free text and cannot be
                  // computed against — see docs/DATA_MODEL.md. No "Open now".
                  Expanded(child: Text(value, style: AppTypography.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    return Container(
      padding: const EdgeInsets.all(AppSpace.x3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: const SafeArea(
        top: false,
        child: Row(
          children: [
            // Saving requires an account and itineraries; both land later. The
            // wireframe pins these actions, so they stay visible but inert.
            OutlinedButton(onPressed: null, child: Icon(Icons.favorite_border)),
            SizedBox(width: AppSpace.x3),
            Expanded(
              child: FilledButton(onPressed: null, child: Text("Add Tour")),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.x8),
      child: Text(text, style: AppTypography.body, textAlign: TextAlign.center),
    ),
  );
}
