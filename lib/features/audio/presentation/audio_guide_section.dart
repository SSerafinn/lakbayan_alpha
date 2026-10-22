import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:motor/motor.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/content/stop_numeral.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/motion.dart";
import "../domain/audio_providers.dart";
import "../domain/narration.dart";

/// The audio guide on Place detail: one white card on the page, the place's
/// photo with play on it and "Audio Guide" (the playing stop once one
/// plays), no count (D-19). A tap opens the player sheet over a scrim: the
/// stop, its progress, transport, then every stop, the running one a solid
/// numeral. Drag down, a scrim tap or back closes it. The sheet is this
/// section's own [OverlayPortal], so it is always this place's player.
class AudioGuideSection extends ConsumerStatefulWidget {
  const AudioGuideSection({
    required this.destinationId,
    required this.segments,
    this.cover,
    super.key,
  });

  final String destinationId;
  final List<Segment> segments;

  /// The place's photo, under the play glyph.
  final String? cover;

  /// The card's height at rest: its photo inside the card's padding.
  static const height = AppSize.rowMedia + 2 * AppSpace.x2;

  @override
  ConsumerState<AudioGuideSection> createState() => _AudioGuideSectionState();
}

class _AudioGuideSectionState extends ConsumerState<AudioGuideSection>
    with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  final _sheetKey = GlobalKey();

  /// The sheet's travel: 0 folded away below the screen, 1 up. A drag moves
  /// it directly; letting go springs it to one end.
  late final _sheet = SingleMotionController(
    motion: AppMotion.chrome,
    vsync: this,
  );

  /// Where the sheet is heading.
  bool _open = false;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _openSheet() {
    if (_open) return;
    setState(() => _open = true);
    _portal.show();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sheet.value = 1;
    } else {
      _sheet.animateTo(1);
    }
  }

  Future<void> _closeSheet() async {
    if (!_open) return;
    setState(() => _open = false);
    if (MediaQuery.disableAnimationsOf(context)) {
      _sheet.value = 0;
      _portal.hide();
      return;
    }
    await _sheet.animateTo(0);
    // Reopened on the way down: the sheet stays.
    if (mounted && !_open) _portal.hide();
  }

  void _drag(DragUpdateDetails details) {
    final box = _sheetKey.currentContext?.findRenderObject() as RenderBox?;
    final height = box != null && box.hasSize ? box.size.height : 1.0;
    _sheet.value = (_sheet.value - details.primaryDelta! / height).clamp(
      0.0,
      1.0,
    );
  }

  /// A downward fling closes it wherever it is; a slow drag closes it once
  /// less than [_closeBelow] of it is showing.
  void _release(DragEndDetails details) {
    final flung = (details.primaryVelocity ?? 0) > AppMotion.flingSpeed;
    if (flung || _sheet.value < _closeBelow) {
      _closeSheet();
    } else {
      _sheet.animateTo(1);
    }
  }

  static const _closeBelow = 0.6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final segments = widget.segments;
    if (segments.isEmpty) {
      return Text(
        "No audio guide for this stop yet.",
        style: AppTypography.bodyMedium.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    // Only what changes the capsule and the list: the position ticks
    // constantly and only the transport watches it.
    final now = ref.watch(
      audioGuideControllerProvider.select(
        (playback) => (
          destinationId: playback.destinationId,
          segmentId: playback.segmentId,
          phase: playback.narrator.phase,
        ),
      ),
    );
    final controller = ref.read(audioGuideControllerProvider.notifier);
    final active =
        now.destinationId == widget.destinationId && now.segmentId != null;
    final playing = active && now.phase == NarratorPhase.playing;
    final loading = active && now.phase == NarratorPhase.loading;
    final match = segments.indexWhere((s) => s.id == now.segmentId);
    final currentIndex = active && match >= 0 ? match : null;
    final current = currentIndex == null ? null : segments[currentIndex];
    final first = segments.where((s) => s.isPlayable).firstOrNull;

    void play(Segment segment) =>
        controller.toggle(widget.destinationId, segments, segment);

    final VoidCallback? playPause = active
        ? controller.togglePlayPause
        : first == null
        ? null
        : () => play(first);

    return PopScope(
      // System back closes the player before it leaves the screen.
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSheet();
      },
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => _PlayerOverlay(
          sheet: _sheet,
          open: _open,
          onClose: _closeSheet,
          child: _PlayerSheet(
            sheetKey: _sheetKey,
            onDrag: _drag,
            onRelease: _release,
            child: _Player(
              segments: segments,
              current: current,
              currentIndex: currentIndex,
              active: active,
              playing: playing,
              loading: loading,
              onPlayPause: playPause,
              onTapStop: play,
            ),
          ),
        ),
        child: _Capsule(
          title: current?.title ?? "Audio Guide",
          cover: widget.cover,
          playing: playing,
          loading: loading,
          onPlayPause: playPause,
          onOpen: _openSheet,
        ),
      ),
    );
  }
}

/// The guide at rest on the page: a white card, the place's photo with
/// play or pause on a dark glass circle, and the guide's name or the stop
/// playing. A tap on the card opens the player; the photo plays and pauses
/// in place.
class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.title,
    required this.cover,
    required this.playing,
    required this.loading,
    required this.onPlayPause,
    required this.onOpen,
  });

  final String title;
  final String? cover;
  final bool playing;
  final bool loading;
  final VoidCallback? onPlayPause;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photoRadius = concentricRadius(
      parentRadius: AppRadii.md,
      padding: AppSpace.x2,
      fallback: AppRadii.xs,
    );
    return Pressable(
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.x2),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: AppSize.rowMedia,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(photoRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CoverImage(cover),
                        IconButton(
                          onPressed: onPlayPause,
                          tooltip: playing ? "Pause" : "Play the audio guide",
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.scrim,
                            fixedSize: const Size.square(AppSize.tileSave),
                          ),
                          icon: FadeSwap(
                            id: loading,
                            child: loading
                                ? const SizedBox.square(
                                    dimension: AppSize.spinner,
                                    child: CircularProgressIndicator(
                                      strokeWidth: AppStroke.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : SymbolSwap(
                                    playing ? AppIcons.pause : AppIcons.play,
                                    size: AppSize.glyphSm,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: FadeSwap(
                    id: title,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: AppTypography.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The guide's play button: filled green, white glyph, the one action this
/// control exists for. [large] is the player sheet's.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.loading,
    required this.onPressed,
    this.large = false,
  });

  final bool playing;
  final bool loading;
  final VoidCallback? onPressed;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = large ? AppSize.playerButton : AppSize.minTouchTarget;
    return Pressable(
      enabled: onPressed != null,
      child: IconButton.filled(
        onPressed: onPressed,
        tooltip: playing ? "Pause" : "Play the audio guide",
        style: IconButton.styleFrom(
          fixedSize: Size.square(size),
          minimumSize: Size.square(size),
        ),
        icon: FadeSwap(
          id: loading,
          child: loading
              ? SizedBox.square(
                  dimension: AppSize.spinner,
                  child: CircularProgressIndicator(
                    strokeWidth: AppStroke.bold,
                    color: scheme.onPrimary,
                  ),
                )
              : SymbolSwap(
                  playing ? AppIcons.pause : AppIcons.play,
                  size: large ? AppSize.glyphLg : null,
                ),
        ),
      ),
    );
  }
}

/// The scrim and the sheet riding the one spring. The sheet is built once;
/// a frame of the rise moves it and tints the scrim, and rebuilds nothing
/// under them.
class _PlayerOverlay extends StatelessWidget {
  const _PlayerOverlay({
    required this.sheet,
    required this.open,
    required this.onClose,
    required this.child,
  });

  final Animation<double> sheet;
  final bool open;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scrim = Theme.of(context).colorScheme.scrim;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: sheet,
      child: IgnorePointer(ignoring: !open, child: child),
      builder: (context, sheetBody) {
        final t = sheet.value;
        final shown = t.clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !open,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  // Faded by its colour, so the scrim costs no `saveLayer`.
                  child: ColoredBox(
                    color: scrim.withValues(alpha: scrim.a * shown),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: reduced
                  ? Opacity(opacity: shown, child: sheetBody)
                  : FractionalTranslation(
                      translation: Offset(0, 1 - t),
                      child: sheetBody,
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// The sheet's surface: rounded at its top like every sheet, capped at the
/// sheet height, its handle the part a drag moves.
class _PlayerSheet extends StatelessWidget {
  const _PlayerSheet({
    required this.sheetKey,
    required this.onDrag,
    required this.onRelease,
    required this.child,
  });

  final GlobalKey sheetKey;
  final GestureDragUpdateCallback onDrag;
  final GestureDragEndCallback onRelease;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screen = MediaQuery.sizeOf(context).height;
    return Material(
      key: sheetKey,
      color: scheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screen * AppSheetSize.mapMax),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: onDrag,
                onVerticalDragEnd: onRelease,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.x3),
                  child: Center(
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
                ),
              ),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The player: what is playing and its transport, then every stop.
///
/// At rest nothing is playing for this place, so the head is the guide's
/// name and one large play button; once a stop plays, the head names it and
/// the progress, previous, next and stop arrive around the button.
class _Player extends ConsumerWidget {
  const _Player({
    required this.segments,
    required this.current,
    required this.currentIndex,
    required this.active,
    required this.playing,
    required this.loading,
    required this.onPlayPause,
    required this.onTapStop,
  });

  final List<Segment> segments;
  final Segment? current;
  final int? currentIndex;
  final bool active;
  final bool playing;
  final bool loading;
  final VoidCallback? onPlayPause;

  /// A stop's row was tapped: play it, or pause and resume it.
  final ValueChanged<Segment> onTapStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(audioGuideControllerProvider.notifier);
    final index = currentIndex;
    final count = segments.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.gutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSwap(
            id: current?.id,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index != null) ...[
                  Text(
                    "Stop ${index + 1} of $count",
                    style: AppTypography.labelMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpace.x1),
                ],
                Text(
                  current?.title ?? "Audio guide",
                  style: AppTypography.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Fold(open: active, child: const _Progress()),
          const SizedBox(height: AppSpace.x3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (active)
                PopIn(
                  child: IconButton(
                    onPressed: controller.skipPrevious,
                    icon: const Icon(AppIcons.skipPrevious),
                    tooltip: "Previous stop",
                  ),
                ),
              const SizedBox(width: AppSpace.x6),
              _PlayButton(
                playing: playing,
                loading: loading,
                onPressed: onPlayPause,
                large: true,
              ),
              const SizedBox(width: AppSpace.x6),
              if (active)
                PopIn(
                  child: IconButton(
                    onPressed: controller.skipNext,
                    icon: const Icon(AppIcons.skipNext),
                    tooltip: "Next stop",
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.section),
          for (final (i, segment) in segments.indexed)
            _StopRow(
              key: Key("stop-${segment.id}"),
              number: i + 1,
              segment: segment,
              current: i == index,
              onTap: segment.isPlayable ? () => onTapStop(segment) : null,
            ),
        ],
      ),
    );
  }
}

/// The stop's progress, the only part of the player that watches the
/// position, so its ticks rebuild this and nothing else. A scrubber when the
/// source can be scrubbed; speech reports no length and cannot seek, so it
/// gets an indeterminate bar. Stop sits at the end of the times.
class _Progress extends ConsumerWidget {
  const _Progress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(audioGuideControllerProvider.notifier);
    final n = ref.watch(
      audioGuideControllerProvider.select((playback) => playback.narrator),
    );
    final total = n.duration;
    final second = AppTypography.secondLine.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (n.canSeek && total != null)
            Slider(
              padding: EdgeInsets.zero,
              value: n.position.inMilliseconds
                  .clamp(0, total.inMilliseconds)
                  .toDouble(),
              max: total.inMilliseconds.toDouble(),
              onChanged: (v) =>
                  controller.seek(Duration(milliseconds: v.round())),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
              child: LinearProgressIndicator(
                value: n.phase == NarratorPhase.playing ? null : 0,
                borderRadius: capsuleRadius,
              ),
            ),
          if (n.error case final message?)
            Text(message, style: second.copyWith(color: scheme.error)),
          Row(
            children: [
              if (total != null) ...[
                Text(_clock(n.position), style: second),
                const Spacer(),
                Text(_clock(total), style: second),
              ] else
                const Spacer(),
              IconButton(
                onPressed: controller.stop,
                icon: const Icon(AppIcons.stop, size: AppSize.glyphMd),
                tooltip: "Stop the audio guide",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A stop: its numeral, its full title and what it is. The running stop's
/// numeral is a solid green circle with a white number, the app's mark for a
/// selection; it eases in on that row as it eases out on the last, so a
/// jump across the list is as calm as a step to the next stop.
class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.number,
    required this.segment,
    required this.current,
    required this.onTap,
    super.key,
  });

  final int number;
  final Segment segment;
  final bool current;
  final VoidCallback? onTap;

  String get _about {
    final description = segment.description?.trim() ?? "";
    final spoken =
        (segment.audioUrl?.isEmpty ?? true) &&
        (segment.ttsText?.trim().isNotEmpty ?? false);
    if (!segment.isPlayable) return "No recording or script yet";
    if (description.isNotEmpty) return description;
    return spoken ? "Read aloud by your device" : "";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final about = _about;
    // The stop numeral's own sizing: at least its token, and larger with the
    // person's text size, so "12" never spills out of its circle.
    final numeral = StopNumeral.sideOf(context, size: AppSize.tileSave);
    return Semantics(
      selected: current,
      label: "Stop $number, ${segment.title}",
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.rowMedia),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.x1,
              vertical: AppSpace.x2,
            ),
            child: Row(
              children: [
                AppMotionBuilder(
                  end: current ? 1 : 0,
                  builder: (context, t, _) {
                    final on = t.clamp(0.0, 1.0);
                    return Container(
                      width: numeral,
                      height: numeral,
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: scheme.primary.withValues(alpha: on),
                        shape: CircleBorder(
                          side: BorderSide(
                            color: Color.lerp(
                              scheme.outlineVariant,
                              scheme.primary,
                              on,
                            )!,
                          ),
                        ),
                      ),
                      child: Text(
                        "$number",
                        style: AppTypography.labelMedium.copyWith(
                          color: Color.lerp(
                            scheme.onSurfaceVariant,
                            scheme.onPrimary,
                            on,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        segment.title,
                        style: AppTypography.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (about.isNotEmpty)
                        Text(
                          about,
                          style: AppTypography.secondLine.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _clock(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, "0");
  return "$minutes:$seconds";
}
