import "package:flutter/scheduler.dart";
import "package:flutter/widgets.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/theme/app_dimens.dart";

part "home_chrome.g.dart";

/// The floating tab bar's form.
enum HomeChromeState {
  /// The full bar.
  rest,

  /// The same bar shrunk, one touch target tall, every cell still one tap,
  /// after a deliberate scroll down.
  collapsed,

  /// Off screen, while a surface the person is engaging with (the Map's
  /// places sheet above its rest height) needs the bottom of the screen.
  hidden,
}

/// The floating tab bar's state. Shrinks after [collapseTravel] of downward
/// scroll past [collapseFloor]; expands after [expandTravel] upward, at the
/// top, on a tab switch or a tap. A change of direction restarts the count.
/// While hidden, only [expand] or [reset] brings the bar back.
///
/// [expandTravel] > [collapseTravel] on purpose: snapping open on the first
/// upward wobble of a fling is worse than being a beat slow to collapse.
@riverpod
class HomeChrome extends _$HomeChrome {
  static const collapseFloor = AppSpace.x12 * 2.5;

  static const collapseTravel = AppSpace.x12;

  static const expandTravel = AppSpace.x12 * 2;

  double _travel = 0;

  @override
  HomeChromeState build() => HomeChromeState.rest;

  /// A notification can arrive mid-layout (keyboard resize, ballistic
  /// correction); flipping state then builds in the wrong scope, so wait.
  void _set(HomeChromeState next) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (ref.mounted) state = next;
      });
    } else {
      state = next;
    }
  }

  void expand() {
    _travel = 0;
    _set(HomeChromeState.rest);
  }

  void reset() => expand();

  void hide() {
    _travel = 0;
    _set(HomeChromeState.hidden);
  }

  bool onScroll(ScrollNotification notification) {
    if (state == HomeChromeState.hidden) return false;
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;
    if (notification is! ScrollUpdateNotification) return false;

    final collapsed = state == HomeChromeState.collapsed;
    if (metrics.pixels <= metrics.minScrollExtent) {
      if (collapsed) expand();
      _travel = 0;
      return false;
    }
    if (metrics.pixels > metrics.maxScrollExtent) return false;

    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) return false;
    if ((delta > 0) != (_travel > 0)) _travel = 0;
    _travel += delta;

    if (!collapsed &&
        _travel >= collapseTravel &&
        metrics.pixels > collapseFloor) {
      _set(HomeChromeState.collapsed);
      _travel = 0;
    } else if (collapsed && _travel <= -expandTravel) {
      expand();
    }
    return false;
  }
}
