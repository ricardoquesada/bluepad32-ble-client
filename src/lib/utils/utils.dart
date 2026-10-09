/// Reactive stream utilities for caching and re-emitting the latest value to
/// new subscribers.
///
/// Used by `extra.dart` to track per-device `isConnecting` and
/// `isDisconnecting` broadcast streams that replay their current boolean state
/// immediately upon subscription.
library;

import 'dart:async';

/// Broadcast stream controller wrapper that caches the most recently emitted
/// value and replays it immediately to any new subscriber on [stream].
class StreamControllerReemit<T> {
  T? _latestValue;

  final StreamController<T> _controller = StreamController<T>.broadcast();

  /// Creates a [StreamControllerReemit] optionally seeded with [initialValue].
  StreamControllerReemit({T? initialValue}) : _latestValue = initialValue;

  /// Broadcast stream that immediately emits [value] (when non-null) to each
  /// new listener before forwarding subsequent events.
  Stream<T> get stream {
    return _latestValue != null ? _controller.stream.newStreamWithInitialValue(_latestValue as T) : _controller.stream;
  }

  /// Most recently emitted value, or the initial value if no events have been
  /// added yet.
  T? get value => _latestValue;

  /// Caches [newValue] as [value] and broadcasts it to all active listeners.
  void add(T newValue) {
    _latestValue = newValue;
    _controller.add(newValue);
  }

  /// Closes the underlying broadcast [StreamController].
  Future<void> close() {
    return _controller.close();
  }
}

/// Extension on [Stream] that prepends an immediate [initialValue] emission for
/// every new subscriber.
extension StreamNewStreamWithInitialValue<T> on Stream<T> {
  /// Returns a new stream that synchronously emits [initialValue] when listened
  /// to and then forwards all data, error, and done events from `this`.
  Stream<T> newStreamWithInitialValue(T initialValue) {
    return transform(_NewStreamWithInitialValueTransformer(initialValue));
  }
}

/// [StreamTransformer] implementation backing
/// [StreamNewStreamWithInitialValue.newStreamWithInitialValue].
///
/// Preserves single-subscription vs. broadcast semantics and manages the
/// upstream subscription lifecycle across multiple broadcast listeners.
class _NewStreamWithInitialValueTransformer<T> extends StreamTransformerBase<T, T> {
  /// The initial value pushed to the transformed stream upon subscription.
  final T initialValue;

  /// Controller for the transformed downstream stream.
  late StreamController<T> controller;

  /// Active subscription to the upstream source stream.
  late StreamSubscription<T> subscription;

  /// Active downstream listener count.
  var listenerCount = 0;

  _NewStreamWithInitialValueTransformer(this.initialValue);

  @override
  Stream<T> bind(Stream<T> stream) {
    if (stream.isBroadcast) {
      return _bind(stream, broadcast: true);
    } else {
      return _bind(stream);
    }
  }

  Stream<T> _bind(Stream<T> stream, {bool broadcast = false}) {
    // -------------------------------------------------------------------------
    // Original Stream Subscription Callbacks
    // -------------------------------------------------------------------------

    // When the original stream emits data, forward it to our new stream.
    void onData(T data) {
      controller.add(data);
    }

    // When the original stream is done, close our new stream.
    void onDone() {
      controller.close();
    }

    // When the original stream has an error, forward it to our new stream.
    void onError(Object error) {
      controller.addError(error);
    }

    // When a client listens to our new stream, emit the initial value and
    // subscribe to the original stream if needed.
    void onListen() {
      // Emit the initial value to our new stream.
      controller.add(initialValue);

      // Listen to the original stream on the first subscriber.
      if (listenerCount == 0) {
        subscription = stream.listen(
          onData,
          onError: onError,
          onDone: onDone,
        );
      }

      // Count listeners of the new stream.
      listenerCount++;
    }

    // -------------------------------------------------------------------------
    // New Stream Controller Callbacks
    // -------------------------------------------------------------------------

    // (Single-subscription only) Pause the upstream subscription on pause.
    void onPause() {
      subscription.pause();
    }

    // (Single-subscription only) Resume the upstream subscription on resume.
    void onResume() {
      subscription.resume();
    }

    // Called when a client cancels their subscription to the new stream.
    void onCancel() {
      // Decrement active listener count.
      listenerCount--;

      // When there are no more listeners of the new stream, cancel the
      // upstream subscription and close the downstream controller.
      if (listenerCount == 0) {
        subscription.cancel();
        controller.close();
      }
    }

    // -------------------------------------------------------------------------
    // Return New Stream
    // -------------------------------------------------------------------------

    if (broadcast) {
      controller = StreamController<T>.broadcast(
        onListen: onListen,
        onCancel: onCancel,
      );
    } else {
      controller = StreamController<T>(
        onListen: onListen,
        onPause: onPause,
        onResume: onResume,
        onCancel: onCancel,
      );
    }

    return controller.stream;
  }
}
