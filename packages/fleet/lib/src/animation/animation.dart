import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../common.dart';
import 'animate.dart';

/// Specification for animating state changes.
///
/// You select the type of animation you want through the constructor you use to
/// create the [AnimationSpec].
///
/// - `const AnimationSpec()` uses uses [defaultCurve] and [defaultDuration].
/// - [AnimationSpec.curve] animates with a [Curve] over a fixed [Duration].
///
/// Any [AnimationSpec] instance can be refined by calling one of the modifiers.
/// A modifier returns a new [AnimationSpec] instance:
///
/// - [delay]
/// - [repeat]
/// - [repeatForever]
/// - [speed]
///
/// To apply an [AnimationSpec] to a state change, use [Animated],
/// [withAnimation] or [AnimatingStateMixin].
///
/// ## Examples
///
/// Create an [AnimationSpec] with modifiers:
///
/// ```dart
/// import 'package:flutter/animation.dart';
///
/// final animation = AnimationSpec.curve(Curves.ease, 300.ms)
///     .delay(250.s)
///     .repeat(2)
///     .speed(2.0);
/// ```
///
/// {@category Animation}
@immutable
class AnimationSpec with Diagnosticable {
  /// Default animation which uses [defaultCurve] and [defaultDuration].
  const AnimationSpec()
      : this._(
          provider: const _CurveAnimationProvider(
            curve: defaultCurve,
            duration: defaultDuration,
          ),
        );

  /// Animation which uses a [curve] and animates for a fixed [duration].
  ///
  /// # Examples
  ///
  /// ```dart
  /// import 'package:flutter/animation.dart';
  ///
  /// final linearDefaultDuration = AnimationSpec.curve(Curves.linear);
  /// final linearDefaultDurationFromCurve = Curves.linear.animation();
  /// final ease250ms = AnimationSpec.curve(Curves.ease, 250.ms);
  /// final ease250msFromCurve = Curves.ease.animation(250.ms);
  /// final withDelay = AnimationSpec.curve(Curves.linear).delay(250.ms);
  /// ```
  ///
  /// See also:
  ///
  /// - [AnimationFromCurveExtension.animation] for a more convenient way to
  ///   create an animation from a [Curve].
  AnimationSpec.curve(Curve curve, [Duration duration = defaultDuration])
      : this._(
          provider: _CurveAnimationProvider(
            curve: curve,
            duration: duration,
          ),
        );

  const AnimationSpec._({
    required AnimationProvider provider,
    Duration? delay,
    int? repeatCount,
    bool? reverse,
    double? speed,
  })  : _provider = provider,
        _delay = delay,
        _repeatCount = repeatCount ?? 1,
        _reverse = reverse ?? false,
        _speed = speed ?? 1;

  /// The default [Curve] used for animations, when no curve is specified.
  static const defaultCurve = Curves.linear;

  /// The default duration used for animations, when no duration is specified.
  static const defaultDuration = Duration(milliseconds: 200);

  static const _foreverRepeatCount = -1;

  final AnimationProvider _provider;
  final Duration? _delay;
  final int _repeatCount;
  final bool _reverse;
  final double _speed;

  bool get _repeatForever => _repeatCount == _foreverRepeatCount;

  AnimationSpec _copyWith({
    Duration? delay,
    int? repeatCount,
    bool? reverse,
    double? speed,
  }) {
    return AnimationSpec._(
      provider: _provider,
      delay: delay ?? _delay,
      repeatCount: repeatCount ?? _repeatCount,
      reverse: reverse ?? _reverse,
      speed: speed ?? _speed,
    );
  }

  /// Returns a copy of this [AnimationSpec] which will start animating after
  /// the given [delay].
  ///
  /// # Examples
  ///
  /// ```dart
  /// import 'package:flutter/animation.dart';
  ///
  /// final withDelay = Curves.linear.animation().delay(250.ms);
  /// ```
  AnimationSpec delay(Duration delay) => _copyWith(delay: delay);

  /// Returns a copy of this [AnimationSpec] which repeats [count] times.
  ///
  /// If [reverse] is true, the animation will reverse after finishing, instead
  /// of starting immediately from the beginning. A reverse counts as a repeat.
  ///
  /// # Examples
  ///
  /// ```dart
  /// import 'package:flutter/animation.dart';
  ///
  /// final withRepeat = Curves.linear.animation().repeat(2);
  /// ```
  AnimationSpec repeat(int count, {bool reverse = true}) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'must be greater than zero.');
    }
    return _copyWith(repeatCount: count, reverse: reverse);
  }

  /// Returns a copy of this [AnimationSpec] which repeats forever.
  ///
  /// If [reverse] is true, the animation will reverse after finishing, instead
  /// of starting immediately from the beginning.
  ///
  /// # Examples
  ///
  /// ```dart
  /// import 'package:flutter/animation.dart';
  ///
  /// final withRepeatForever = Curves.linear.animation().repeatForever();
  /// ```
  AnimationSpec repeatForever({bool reverse = true}) =>
      _copyWith(repeatCount: _foreverRepeatCount, reverse: reverse);

  /// Returns a copy of this [AnimationSpec] with the given [speed].
  ///
  /// For example a speed of 0.5 will cause the animation to run at half speed.
  ///
  /// # Examples
  ///
  /// ```dart
  /// import 'package:flutter/animation.dart';
  ///
  /// final withSpeed = Curves.linear.animation().speed(0.5);
  /// ```
  AnimationSpec speed(double speed) {
    if (speed <= 0) {
      throw ArgumentError.value(speed, 'speed', 'must be greater than zero.');
    }
    return _copyWith(speed: speed);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    _provider.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<Duration>(
        'delay',
        _delay,
        missingIfNull: true,
      ),
    );
    properties.add(
      DiagnosticsProperty(
        'repeat',
        _repeatForever ? 'forever' : _repeatCount,
        defaultValue: 1,
      ),
    );
    properties.add(
      DiagnosticsProperty<bool>('reverse', _reverse, defaultValue: false),
    );
    properties.add(
      DiagnosticsProperty<double>('speed', _speed, defaultValue: 1),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimationSpec &&
          runtimeType == other.runtimeType &&
          _provider == other._provider &&
          _delay == other._delay &&
          _repeatCount == other._repeatCount &&
          _reverse == other._reverse &&
          _speed == other._speed;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      _provider.hashCode ^
      _delay.hashCode ^
      _repeatCount.hashCode ^
      _reverse.hashCode ^
      _speed.hashCode;
}

/// Extension for creating [AnimationSpec]s from [Curve]s.
///
/// See also:
///
/// - [AnimationSpec.curve]
///
/// {@category Animation}
extension AnimationFromCurveExtension on Curve {
  /// Returns an animation which uses this curve and animates for a fixed
  /// [duration].
  ///
  /// # Examples
  ///
  /// ```dart
  /// import 'package:flutter/animation.dart';
  ///
  /// final linearDefaultDuration = Curves.linear.animation();
  /// final linear250ms = Curves.linear.animation(250.ms);
  /// ```
  ///
  /// See also:
  ///
  /// - [AnimationSpec.curve]
  AnimationSpec animation([Duration duration = AnimationSpec.defaultDuration]) {
    return AnimationSpec.curve(this, duration);
  }
}

/// The current [AnimationSpec] that will be used to animated state changes.
AnimationSpec? get currentAnimation => _currentAnimation;
AnimationSpec? _currentAnimation;

/// Internal API of [AnimationSpec].
extension InternalAnimationSpec on AnimationSpec {
  /// The [AnimationProvider] for this [AnimationSpec].
  AnimationProvider get provider => _provider;
}

/// Runs [block] with [currentAnimation] set to [animation].
T runWithAnimation<T>(AnimationSpec animation, Block<T> block) {
  final previousAnimation = _currentAnimation;
  _currentAnimation = animation;
  try {
    return block();
  } finally {
    _currentAnimation = previousAnimation;
  }
}

/// Abstraction of a value that can be animated by an [AnimationImpl].
abstract class AnimatableValue<T> implements TickerProvider {
  /// The current value of this [AnimatableValue].
  ///
  /// This value is read at the start of an animation and is animate **to**.
  T get value;

  /// The value of this [AnimatableValue] that is currently used when rendering
  /// the UI.
  ///
  /// This value is read at the start of an animation and is animate **from**.
  T get animatedValue;

  /// Returns a [Tween] that the [AnimationImpl] can use to interpolate between
  /// [value] and [animatedValue].
  ///
  /// The returned [Tween] must always evaluate to [T] even though the signature
  /// allows for a nullable type. The signature is chosen to allow the usage of
  /// [Tween]s that only return `null` when neither [Tween.begin] nor
  /// [Tween.end] are set, which [AnimationImpl] will never do.
  Tween<T?> createTween();
}

/// An object that can create [AnimationImpl]s.
///
/// See also:
///
/// - [_CurveAnimationProvider] for a provider that creates animations that uses
///   a [Curve] to animate.
abstract class AnimationProvider with Diagnosticable {
  /// Const constructor for subclasses.
  const AnimationProvider();

  /// Returns a new [AnimationImpl] to animate [value] using [animationSpec].
  ///
  /// The [previousAnimation] for [value] is provided so that the new
  /// [AnimationImpl] can decide how to transition to the new animation. For
  /// example it could blend between the previous and new animation.
  AnimationImpl<T> createAnimation<T>(
    AnimationSpec animationSpec,
    AnimatableValue<T> value,
    AnimationImpl<T>? previousAnimation,
  );
}

/// Base class for animations that animate an [AnimatableValue].
///
/// See also:
///
/// - [_CurveAnimation] for an implementation that uses a [Curve] to animate.
abstract class AnimationImpl<T> with Diagnosticable {
  /// Base constructor for subclasses.
  AnimationImpl(this._spec, this._value)
      : _tween = _value.createTween()
          ..begin = _value.animatedValue
          ..end = _value.value,
        _currentValue = _value.animatedValue {
    _ticker = _value.createTicker(_onTick);
  }

  final AnimationSpec _spec;
  final AnimatableValue<T> _value;
  final Tween<T?> _tween;
  late final Ticker _ticker;
  var _repeat = 0;
  var _forward = true;
  Duration _lastRepeatEnd = Duration.zero;
  Duration _lastRepeatDuration = Duration.zero;
  var _isStopped = false;

  /// Whether this animation is currently running.
  bool get isAnimating => _ticker.isActive;

  /// The current status of this animation.
  AnimationStatus get status {
    if (!isAnimating) {
      if (_currentValue == _tween.begin) {
        return AnimationStatus.dismissed;
      }
      if (_currentValue == _tween.end) {
        return AnimationStatus.completed;
      }
    }

    return _forward ? AnimationStatus.forward : AnimationStatus.reverse;
  }

  /// The current value of the animation.
  T get currentValue => _currentValue;
  T _currentValue;

  /// Callback that is called when [currentValue] changes.
  VoidCallback? onChange;

  /// Callback that is called when this animation is done.
  VoidCallback? onDone;

  /// Starts this animation.
  void start() {
    assert(!_isStopped);
    assert(!_ticker.isActive);
    _ticker.start();
  }

  /// Stops this animation.
  void stop() {
    if (_isStopped) {
      return;
    }

    _isStopped = true;
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _ticker.dispose();
    onDone?.call();
  }

  /// Returns a non-null value when this animation has reached its end value.
  ///
  /// [elapsed] is the time that has passed since the animation started.
  ///
  /// The returned [Duration] must be negative or zero and represents the
  /// difference between when the animation reached its end value and [elapsed].
  @protected
  Duration? isAtEnd(Duration elapsed);

  /// Returns the value of this animation at the given [elapsed] time.
  ///
  /// [elapsed] is the time that has passed since the animation started.
  ///
  /// The return type is nullable because so is that of [_tween]s, but the
  /// actually returned value must always be assignable to [T] (if [T] is
  /// nullable returning `null` is fine). See [AnimatableValue.createTween] for
  /// more information.
  @protected
  T? valueAt(Duration elapsed);

  void _onTick(Duration elapsed) {
    var elapsedForAllRepeats = elapsed * _spec._speed;

    final delay = _spec._delay;
    if (delay != null) {
      if (elapsedForAllRepeats < delay) {
        return;
      }
      elapsedForAllRepeats -= delay;
    }

    var elapsedForRepeat = elapsedForAllRepeats - _lastRepeatEnd;

    var isDone = false;

    void onFinishRepeat() {
      if (!_spec._repeatForever && ++_repeat >= _spec._repeatCount) {
        isDone = true;
      }
    }

    if (_forward) {
      final endDelta = isAtEnd(elapsedForRepeat);
      if (endDelta != null) {
        assert(endDelta.isNegative || endDelta.inMicroseconds == 0);
        elapsedForRepeat = elapsedForRepeat + endDelta;
        _lastRepeatEnd += elapsedForRepeat;
        _lastRepeatDuration = elapsedForRepeat;

        if (_spec._reverse) {
          _forward = false;
        }

        onFinishRepeat();
      }
    } else {
      elapsedForRepeat = _lastRepeatDuration - elapsedForRepeat;

      if (elapsedForRepeat.isNegative || elapsedForRepeat.inMicroseconds == 0) {
        _lastRepeatEnd += _lastRepeatDuration + elapsedForRepeat;
        elapsedForRepeat = elapsedForRepeat.abs();

        _forward = true;

        onFinishRepeat();
      }
    }

    if (isDone) {
      // On the last tick we need to be exactly at the end of the animation.
      // If the animation is repeated and reversing it is possible that the
      // last tick is at the beginning of the animation.
      _currentValue = _tween.end as T;
    } else {
      _currentValue = valueAt(elapsedForRepeat) as T;
    }

    onChange?.call();

    if (isDone) {
      stop();
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty('spec', _spec));
    properties.add(DiagnosticsProperty('repeat', _repeat));
    properties.add(
      FlagProperty(
        'direction',
        value: isAnimating ? _forward : null,
        ifTrue: 'forward',
        ifFalse: 'reverse',
      ),
    );
  }
}

@immutable
class _CurveAnimationProvider extends AnimationProvider {
  const _CurveAnimationProvider({required this.curve, required this.duration});

  final Curve curve;
  final Duration duration;

  @override
  AnimationImpl<T> createAnimation<T>(
    AnimationSpec spec,
    AnimatableValue<T> value,
    AnimationImpl<T>? previousAnimation,
  ) {
    previousAnimation?.stop();
    return _CurveAnimation(spec, value, this);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Curve>('curve', curve));
    properties.add(DiagnosticsProperty<Duration>('duration', duration));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CurveAnimationProvider &&
          runtimeType == other.runtimeType &&
          curve == other.curve &&
          duration == other.duration;

  @override
  int get hashCode => runtimeType.hashCode ^ curve.hashCode ^ duration.hashCode;
}

class _CurveAnimation<T> extends AnimationImpl<T> {
  _CurveAnimation(super.spec, super.value, this._provider);

  final _CurveAnimationProvider _provider;

  @override
  Duration? isAtEnd(Duration elapsed) {
    if (elapsed >= _provider.duration) {
      return _provider.duration - elapsed;
    }
    return null;
  }

  @override
  T? valueAt(Duration elapsed) {
    var t = elapsed.inMicroseconds / _provider.duration.inMicroseconds;
    t = _provider.curve.transform(t);
    return _tween.transform(t);
  }
}
