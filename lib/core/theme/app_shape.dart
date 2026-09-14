import "package:flutter/material.dart";

/// Shape, the foundation of the design language (design doc 02).
///
/// Every rounded element is exactly one of three types:
///
/// - **Fixed.** A token from [AppRadii]. Top level containers, standalone
///   cards, sheets, media tiles.
/// - **Capsule.** [capsule], radius = half the height. Buttons, chips, search
///   fields, bar groups, navigation indicators. Inherently concentric with
///   anything it sits inside.
/// - **Concentric.** Derived from the parent: `inner = outer - padding`. Any
///   content inside a container with a known radius. Read it through
///   [ParentRadius] or compute it with [concentricRadius].
///
/// Never hard code an inner radius. Uniform radius at every nesting level is
/// the most common cause of corners that look wrong without an obvious reason.
abstract final class AppRadii {
  /// Thumbnails and media inside a row when there is no parent to derive from.
  static const xs = 8.0;

  /// Dense controls and form fields.
  static const sm = 12.0;

  /// A media tile.
  static const tile = 14.0;

  /// Cards and grouped sections. The default fallback.
  static const md = 16.0;

  /// Hero media and the Profile brand block.
  static const lg = 24.0;

  /// A sheet drawn up over content. Larger than [lg] so the corners read as a
  /// separate surface rather than a rounded box.
  static const sheet = 28.0;

  static const xsAll = BorderRadius.all(Radius.circular(xs));
  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const tileAll = BorderRadius.all(Radius.circular(tile));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
}

/// The capsule. Height driven, so it stays a capsule at any size; this is the
/// shape, not a `RoundedRectangleBorder` with a large number.
const OutlinedBorder capsule = StadiumBorder();

/// A capsule as a [BorderRadius], for `InkWell` and `ClipRRect`, which cannot
/// take a [ShapeBorder]. Large enough to round any control this app draws.
const BorderRadius capsuleRadius = BorderRadius.all(Radius.circular(999));

/// `inner = outer - padding`, floored at zero. Falls back when the parent is
/// too tight for the inset to leave a curve.
double concentricRadius({
  required double parentRadius,
  required double padding,
  double? fallback,
}) {
  final computed = parentRadius - padding;
  if (computed <= 0) return fallback ?? 0;
  return computed;
}

/// Carries a container's corner radius to its descendants so nested shapes
/// resolve concentrically without each call site knowing the parent.
///
/// A component that must work both nested and standalone reads
/// [ParentRadius.maybeOf] and falls back to its own token when null: one
/// definition, not two variants.
class ParentRadius extends InheritedWidget {
  const ParentRadius({required this.radius, required super.child, super.key});

  final double radius;

  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ParentRadius>()?.radius;

  @override
  bool updateShouldNotify(ParentRadius oldWidget) => radius != oldWidget.radius;
}

/// The radius a child should take inside the nearest [ParentRadius], given the
/// inset between the two edges. [fallback] applies when there is no parent.
double concentricOf(
  BuildContext context, {
  required double padding,
  required double fallback,
}) {
  final parent = ParentRadius.maybeOf(context);
  if (parent == null) return fallback;
  return concentricRadius(
    parentRadius: parent,
    padding: padding,
    fallback: fallback,
  );
}
