import "package:flutter_riverpod/flutter_riverpod.dart";

/// Reading a provider local-first: what is on the phone outranks a failure
/// to refresh it. The rules are in `docs/DESIGN_SYSTEM.md` (Loading, empty
/// and error states).
///
/// Riverpod's own [AsyncValue.when] and [AsyncValue.whenData] do not hold
/// to that. A provider that fails after it had a value is retried, about
/// 38 seconds of backoff by default, and reads as loading meanwhile: `when`
/// swaps what is on screen for its spinner, `skipError` or not, and
/// `whenData` drops the value outright, on the retries and on the error
/// they end in.
extension LocalFirst<T> on AsyncValue<T> {
  /// [AsyncValue.when], decided by what there is rather than by `isLoading`,
  /// as the policy pages are:
  ///
  /// - a value is [data], kept through a failure and the retries after it.
  ///   Not while it is being replaced for changed inputs (another category,
  ///   another account): it answers what nobody is asking any more, so
  ///   [loading] shows instead, as with `when`.
  /// - with no value, an error is [error] at once rather than after the
  ///   retries, and [loading] while Try again is under way, so the tap is
  ///   seen to do something.
  /// - otherwise [loading].
  R whenLocalFirst<R>({
    required R Function(T value) data,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function() loading,
  }) {
    final replacing = this is AsyncLoading<T> && !hasError;
    if (hasValue && !replacing) return data(requireValue);
    if (this.error case final failure? when !isRefreshing) {
      return error(failure, stackTrace!);
    }
    return loading();
  }

  /// [AsyncValue.whenData] that keeps the value: a list derived from a
  /// provider that failed after loading is derived from what that provider
  /// still holds, rather than dropped for the error. With no value, the
  /// retries read as the error they are retrying, not as loading, which is
  /// how [whenLocalFirst] shows a source read directly.
  AsyncValue<R> deriveKeepingValue<R>(R Function(T value) derive) {
    if (hasValue && hasError) {
      return AsyncData<T>(requireValue).whenData(derive);
    }
    if (this case AsyncLoading(error: final failure?, :final stackTrace?)) {
      return AsyncError<R>(failure, stackTrace);
    }
    return whenData(derive);
  }
}
