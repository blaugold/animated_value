import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'animation.dart';

/// An animated value that can participate in an animation graph.
///
/// The current value of an animated value is managed by an
/// [AnimationGraphController].
///
/// To use an animated value in a widget, use [of] to access an [Animation] that
/// notifies listeners when the value changes.
///
/// You can also access the current value or an [Animation] for an animated
/// value by calling [AnimationGraphController.get] or
/// [AnimationGraphController.animation] respectively.
final class AnimatedValue<T> {
  /// Creates an animated value.
  const AnimatedValue({
    this.name,
    required this.defaultValue,
    required this.tweenFactory,
  });

  /// Creates an animated [double] value.
  static AnimatedValue<double> double$({
    String? name,
    double defaultValue = 0,
  }) {
    return AnimatedValue(
      name: name,
      defaultValue: defaultValue,
      tweenFactory: Tween.new,
    );
  }

  /// Creates an animated [int] value.
  static AnimatedValue<int> int$({
    String? name,
    int defaultValue = 0,
  }) {
    return AnimatedValue(
      name: name,
      defaultValue: defaultValue,
      tweenFactory: IntTween.new,
    );
  }

  /// Creates an animated [Color] value.
  static AnimatedValue<Color> color({
    String? name,
    Color defaultValue = const Color(0x00000000),
  }) {
    return AnimatedValue(
      name: name,
      defaultValue: defaultValue,
      tweenFactory: ColorTween.new,
    );
  }

  /// Creates an animated [Offset] value.
  static AnimatedValue<Offset> offset({
    String? name,
    Offset defaultValue = Offset.zero,
  }) {
    return AnimatedValue(
      name: name,
      defaultValue: defaultValue,
      tweenFactory: Tween.new,
    );
  }

  /// The name of this animated value for debugging purposes.
  final String? name;

  /// The default value of this animated value when no animation has been
  /// started.
  final T defaultValue;

  /// A factory function for creating a tween to animate between values of this
  /// animated value.
  final Tween<T?> Function() tweenFactory;

  /// Creates an [AnimationNode] that animates this value to a new [value].
  ///
  /// If [from] is provided, the animation will start from that value. Otherwise
  /// the animation will start from the current value of this animated value.
  ///
  /// The animation will have a duration of [duration] and will start after a
  /// delay of [delay] (defaults to zero).
  ///
  /// The animation will use the specified [curve] (defaults to
  /// [Curves.linear]).
  AnimationNode to(
    T value,
    Duration duration, {
    T? from,
    Duration delay = Duration.zero,
    Curve curve = Curves.linear,
  }) {
    return ValueAnimation(
      spec: AnimationSpec.curve(curve, duration).delay(delay),
      value: this,
      from: from,
      to: value,
    );
  }

  /// Creates an [AnimationNode] that jumps to a new [value] without animating.
  AnimationNode jump(T value) => to(value, Duration.zero);

  /// Creates an [AnimationNode] that resets this animated value to its
  /// [defaultValue] without animating.
  AnimationNode reset() => jump(defaultValue);

  /// Returns an [Animation] for this animated value by looking up an
  /// [AnimationGraphController] in the given [context].
  ///
  /// See [AnimationGraphController.maybeOf] for more information about where a
  /// controller is available.
  ///
  /// If no controller is found, an [AlwaysStoppedAnimation] with the default
  /// value of this animated value is returned.
  Animation<T> of(BuildContext context) =>
      AnimationGraphController.maybeOf(context)?.animation(this) ??
      AlwaysStoppedAnimation(defaultValue);

  _ValueAnimation<T> _animation(AnimationGraphController controller) =>
      controller._valueAnimations.putIfAbsent(
        this,
        () => _ValueAnimation<T>(
          AnimationStatus.dismissed,
          this.defaultValue,
        ),
      ) as _ValueAnimation<T>;

  void _set(AnimationGraphController controller, T value) =>
      _animation(controller).value = value;

  void _reset(AnimationGraphController controller) =>
      _set(controller, defaultValue);

  T _get(AnimationGraphController controller) => _animation(controller).value;
}

/// A node in an animation graph.
abstract class AnimationNode {
  /// Accepts a [visitor] to visit this node.
  T _accept<T>(_AnimationNodeVisitor<T> visitor);

  /// Visits the children of this node with the specified [visitor].
  // ignore: unused_element
  void _visitChildren(_AnimationNodeVisitor<void> visitor);

  _AnimationElement _createElement();
}

abstract class _AnimationElement {
  late final GraphAnimation animation;
  VoidCallback? onComplete;

  void start();
  void cancel();

  _AnimationElement createChild(AnimationNode node) =>
      node._createElement()..animation = animation;
}

/// A visitor for visiting nodes in an animation graph.
abstract class _AnimationNodeVisitor<T> {
  /// Visits a [Group] node.
  T visitGroup(Group node);

  /// Visits a [Sequence] node.
  T visitSequence(Sequence node);

  /// Visits a [ValueAnimation] node.
  T visitValueAnimation<V>(ValueAnimation<V> node);

  /// Visits a [Reset] node.
  T visitReset(Reset node);

  /// Visits an [Action] node.
  T visitAction(Action node);
}

class _RecursiveVisitor extends _AnimationNodeVisitor<void> {
  @override
  void visitGroup(Group node) => node._visitChildren(this);

  @override
  void visitSequence(Sequence node) => node._visitChildren(this);

  @override
  void visitValueAnimation<V>(ValueAnimation<V> node) =>
      node._visitChildren(this);

  @override
  void visitReset(Reset node) => node._visitChildren(this);

  @override
  void visitAction(Action node) => node._visitChildren(this);
}

class _TransformVisitor extends _AnimationNodeVisitor<AnimationNode> {
  @override
  AnimationNode visitGroup(Group node) {
    return Group([
      for (final child in node.children) child._accept(this),
    ]);
  }

  @override
  AnimationNode visitSequence(Sequence node) {
    return Sequence([
      for (final child in node.children) child._accept(this),
    ]);
  }

  @override
  AnimationNode visitValueAnimation<V>(ValueAnimation<V> node) => node;

  @override
  AnimationNode visitReset(Reset node) => node;

  @override
  AnimationNode visitAction(Action node) => node;
}

class _MapAnimationSpecsVisitor extends _TransformVisitor {
  _MapAnimationSpecsVisitor(this.map);

  final AnimationSpec Function(AnimationSpec) map;

  @override
  AnimationNode visitValueAnimation<V>(ValueAnimation<V> node) {
    return ValueAnimation(
      spec: map(node.spec),
      value: node.value,
      from: node.from,
      to: node.to,
    );
  }
}

/// Extension methods for [AnimationNode].
extension AnimationNodeExtension on AnimationNode {
  /// Returns a new animation node in which the [AnimationSpec] of each
  /// contained [ValueAnimation] is transformed by the given [map] function.
  AnimationNode mapAnimationSpecs(AnimationSpec Function(AnimationSpec) map) =>
      _accept(_MapAnimationSpecsVisitor(map));

  /// Returns a new animation node that runs all contained animation nodes at
  /// the given [speed].
  AnimationNode speed(double speed) =>
      mapAnimationSpecs((spec) => spec.speed(speed));

  /// Returns a new animation node that delays the start of this animation by
  /// the specified [duration].
  AnimationNode delay(Duration duration) => Sequence([Pause(duration), this]);
}

/// A group of animation nodes that are started and run in parallel.
final class Group extends AnimationNode {
  /// Creates a group of [children] that are started and run in parallel.
  Group(this.children);

  /// The children of this group, which are started and run in parallel.
  final List<AnimationNode> children;

  @override
  V _accept<V>(_AnimationNodeVisitor<V> visitor) => visitor.visitGroup(this);

  @override
  void _visitChildren(_AnimationNodeVisitor<void> visitor) {
    for (final child in children) {
      child._accept(visitor);
    }
  }

  @override
  _AnimationElement _createElement() => _GroupElement(this);
}

class _GroupElement extends _AnimationElement {
  _GroupElement(this.node);

  final Group node;

  final runningChildren = <_AnimationElement>[];

  @override
  void start() {
    if (node.children.isEmpty) {
      onComplete?.call();
    } else {
      for (final child in node.children.map(createChild)) {
        runningChildren.add(child);
        child.onComplete = () {
          runningChildren.remove(child);
          if (runningChildren.isEmpty) {
            onComplete?.call();
          }
        };
        child.start();
      }
    }
  }

  @override
  void cancel() {
    for (final child in runningChildren) {
      child.cancel();
    }
    runningChildren.clear();
  }
}

/// A sequence of animation nodes that are started and run in sequence.
final class Sequence extends AnimationNode {
  /// Creates a sequence of [children] that are started and run in sequence.
  Sequence(this.children);

  /// The children of this sequence, which are started and run in sequence.
  final List<AnimationNode> children;

  @override
  V _accept<V>(_AnimationNodeVisitor<V> visitor) => visitor.visitSequence(this);

  @override
  void _visitChildren(_AnimationNodeVisitor<void> visitor) {
    for (final child in children) {
      child._accept(visitor);
    }
  }

  @override
  _AnimationElement _createElement() => _SequenceElement(this);
}

class _SequenceElement extends _AnimationElement {
  _SequenceElement(this.node);

  final Sequence node;

  int currentIndex = 0;
  late _AnimationElement? currentChild;

  @override
  void start() => nextChild();

  @override
  void cancel() {
    currentChild?.cancel();
    currentChild = null;
  }

  void nextChild() {
    if (currentIndex < node.children.length) {
      final child = createChild(node.children[currentIndex++]);
      currentChild = child;
      child.onComplete = nextChild;
      child.start();
    } else {
      currentChild = null;
      onComplete?.call();
    }
  }
}

/// An animation node that animates an [AnimatedValue].
final class ValueAnimation<T> extends AnimationNode {
  /// Creates a value animation that animates the given [value].
  ValueAnimation({
    required this.value,
    required this.spec,
    this.from,
    required this.to,
  });

  /// The animated value to animate.
  final AnimatedValue<T> value;

  /// The animation specification.
  final AnimationSpec spec;

  /// The value to start the animation from.
  final T? from;

  /// The value to animate to.
  final T to;

  @override
  V _accept<V>(_AnimationNodeVisitor<V> visitor) =>
      visitor.visitValueAnimation(this);

  @override
  void _visitChildren(_AnimationNodeVisitor<void> visitor) {}

  @override
  _AnimationElement _createElement() => _ValueAnimationElement(this);
}

class _ValueAnimationElement<T> extends _AnimationElement
    implements AnimatableValue<T> {
  _ValueAnimationElement(this.node);

  final ValueAnimation<T> node;

  AnimationImpl<T>? animationImpl;
  _ValueAnimation<T>? valueAnimation;

  @override
  Tween<T?> createTween() => node.value.tweenFactory();

  @override
  Ticker createTicker(TickerCallback onTick) =>
      animation.controller.sync.createTicker(onTick);

  @override
  T get value => node.to;

  @override
  T get animatedValue => node.from ?? valueAnimation!.value;

  @override
  void start() {
    final controller = animation.controller;
    final valueAnimationImpls = controller._valueAnimationImpls;

    final valueAnimation = node.value._animation(controller);
    this.valueAnimation = valueAnimation;

    final previousAnimationImpl =
        valueAnimationImpls.remove(valueAnimation) as AnimationImpl<T>?;

    final animationImpl = node.spec.provider
        .createAnimation(node.spec, this, previousAnimationImpl);
    this.animationImpl = animationImpl;

    valueAnimationImpls[valueAnimation] = animationImpl;

    animationImpl
      ..onDone = onCompleteInternal
      ..onChange = onChange
      ..start();
  }

  @override
  void cancel() {
    // Calling stop will call the onDone callback, which in turn will call
    // _onComplete. So we don't need to clean up everything here.
    // We need to clear the onComplete callback, though, because it must not be
    // called when an animation element is canceled and _onComplete would
    // call it.
    onComplete = null;
    animationImpl?.stop();
  }

  void onChange() {
    final animationImpl = this.animationImpl!;
    valueAnimation!
      ..status = animationImpl.status
      ..value = animationImpl.currentValue;
  }

  void onCompleteInternal() {
    final valueAnimationImpls = animation.controller._valueAnimationImpls;
    // If this elements AnimationImpl is still the current one for the value
    // animation, remove it from the map of value animation implementations.
    // If it is not the current one, it has been replaced by another element
    // that has started before this element completed and should not be removed.
    if (valueAnimationImpls.containsKey(valueAnimation)) {
      valueAnimationImpls.remove(valueAnimation);
    }
    valueAnimation = null;
    animationImpl = null;
    onComplete?.call();
  }
}

/// An animation node that pauses for a specified duration.
final class Pause extends ValueAnimation<double> {
  /// Creates a pause animation that pauses for the specified [duration].
  Pause(Duration duration) : this._fromSpec(Curves.linear.animation(duration));

  Pause._fromSpec(AnimationSpec spec)
      : super(spec: spec, value: AnimatedValue.double$(name: 'Pause'), to: 0);
}

/// An animation node that resets a list of [AnimatedValue]s or all
/// [AnimatedValue]s of the running animation to their
/// [AnimatedValue.defaultValue]s.
final class Reset extends AnimationNode {
  /// Creates a reset animation that resets the given [values], or if `null`,
  /// all values of the running animation to their
  /// [AnimatedValue.defaultValue]s.
  Reset([this.values]);

  /// The values to reset.
  final Set<AnimatedValue<void>>? values;

  @override
  V _accept<V>(_AnimationNodeVisitor<V> visitor) => visitor.visitReset(this);

  @override
  void _visitChildren(_AnimationNodeVisitor<void> visitor) {}

  @override
  _AnimationElement _createElement() => _ResetElement(this);
}

class _ResetElement extends _AnimationElement {
  _ResetElement(this.node);

  final Reset node;

  @override
  void start() {
    var values = node.values;
    if (values == null) {
      final collector = _AnimatedValueCollector();
      animation.root._accept(collector);
      values = collector.values;
    }

    values.forEach(animation.controller.reset);

    onComplete?.call();
  }

  @override
  void cancel() {}
}

class _AnimatedValueCollector extends _RecursiveVisitor {
  final values = <AnimatedValue<void>>{};

  @override
  void visitValueAnimation<V>(ValueAnimation<V> node) {
    values.add(node.value);
  }

  @override
  void visitReset(Reset node) {
    if (node.values != null) {
      values.addAll(node.values!);
    }
  }
}

/// An animation node that immediately runs an [action] and waits for it to
/// complete.
final class Action extends AnimationNode {
  /// Creates an action animation that immediately runs an [action] and waits
  /// for it to complete.
  Action(this.action);

  /// The action to run.
  ///
  /// The action can be asynchronous and can return a [Future]. In this case
  /// this animation node will wait for the future to complete before
  /// completing.
  final FutureOr<void> Function() action;

  @override
  T _accept<T>(_AnimationNodeVisitor<T> visitor) => visitor.visitAction(this);

  @override
  void _visitChildren(_AnimationNodeVisitor<void> visitor) {}

  @override
  _AnimationElement _createElement() => _ActionElement(this);
}

class _ActionElement extends _AnimationElement {
  _ActionElement(this.node);

  final Action node;

  @override
  // ignore: avoid_void_async
  void start() async {
    try {
      final result = node.action();
      if (result is Future<void>) {
        await result;
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'fleet',
          context: ErrorDescription('while running action'),
        ),
      );
    } finally {
      onComplete?.call();
    }
  }

  @override
  void cancel() {
    // TODO: Make actions cancelable
  }
}

/// A controller for running animation graph animations.
class AnimationGraphController {
  /// Creates an animation graph controller.
  AnimationGraphController({required this.sync});

  /// Returns the nearest [AnimationGraphController] from the given [context],
  /// if available.
  ///
  /// This method can be used to access the [AnimationGraphController] from a
  /// widget that is a descendant of a [AnimationGraphScope] or a [State] that
  /// uses the [AnimationGraphMixin] mixin.
  static AnimationGraphController? maybeOf(BuildContext context) {
    if (context
        case StatefulElement(
          state: AnimationGraphMixin(:final animationGraphController)
        )) {
      return animationGraphController;
    }

    return context
        .dependOnInheritedWidgetOfExactType<AnimationGraphScope>()
        ?.controller;
  }

  /// Returns the nearest [AnimationGraphController] from the given [context].
  ///
  /// Same as [maybeOf], but throws an error if no controller is found.
  static AnimationGraphController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller == null) {
      throw FlutterError('No AnimationGraphController found in context');
    }
    return controller;
  }

  /// The ticker provider for creating tickers for animations.
  final TickerProvider sync;

  final _valueAnimations = <AnimatedValue<void>, _ValueAnimation<void>>{};
  final _valueAnimationImpls = <_ValueAnimation<void>, AnimationImpl<void>>{};
  final _runningAnimations = <GraphAnimation>[];

  /// Starts the animation graph specified by the given [root] node.
  ///
  /// Returns a [GraphAnimation] that can be used to wait for the animation to
  /// complete or to cancel it.
  GraphAnimation animate(AnimationNode root) {
    final animation = GraphAnimation._(this, root).._start();
    _runningAnimations.add(animation);
    return animation;
  }

  /// Returns the [Animation] for the given animated [value].
  Animation<T> animation<T>(AnimatedValue<T> value) => value._animation(this);

  /// Returns the current value of the given animated [value].
  T get<T>(AnimatedValue<T> value) => value._get(this);

  /// Sets the current value of the animated [value] to [newValue].
  void set<T>(AnimatedValue<T> value, T newValue) => value._set(this, newValue);

  /// Resets the current value of the given animated [value] to its
  /// [AnimatedValue.defaultValue].
  void reset(AnimatedValue<void> value) => value._reset(this);

  /// Resets the current values of all [AnimatedValue]s to their
  /// [AnimatedValue.defaultValue]s.
  void resetAll() {
    for (final MapEntry(:key, :value) in _valueAnimations.entries) {
      value.value = key.defaultValue;
    }
  }

  /// Cancels all running animations.
  void cancelAll() {
    for (final animation in List.of(_runningAnimations)) {
      animation.cancel();
    }
  }

  /// Disposes this controller and cancels all running animations.
  void dispose() => cancelAll();
}

class _ValueAnimation<T> extends Animation<T>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  _ValueAnimation(this._status, this._value);

  AnimationStatus _status;

  @override
  AnimationStatus get status => _status;

  set status(AnimationStatus status) {
    if (_status != status) {
      _status = status;
      notifyStatusListeners(status);
    }
  }

  T _value;

  @override
  T get value => _value;

  set value(T value) {
    if (_value != value) {
      _value = value;
      notifyListeners();
    }
  }

  @override
  void didRegisterListener() {}

  @override
  void didUnregisterListener() {}
}

/// An animation that executes the graph animation specified by a [root]
/// animation node.
///
/// You can wait for the animation to complete by awaiting the [done] future.
/// This future will complete when the animation has completed but not when it
/// has been canceled.
///
/// You can also await the [doneOrCanceled] future, which will complete when the
/// animation has completed or has been canceled.
final class GraphAnimation {
  GraphAnimation._(this.controller, this.root);

  /// The animation graph controller this animation belongs to.
  final AnimationGraphController controller;

  /// The root animation node of this animation.
  final AnimationNode root;

  final Completer<void> _doneCompleter = Completer<void>();
  final Completer<bool> _doneOrCanceledCompleter = Completer<bool>();

  late final _AnimationElement _rootElement;

  /// A future that completes when the animation has completed.
  Future<void> get done => _doneCompleter.future;

  /// A future that completes when the animation has completed or has been
  /// canceled.
  ///
  /// If the animation has completed, the future will complete with `true`. If
  /// the animation has been canceled, the future will complete with `false`.
  Future<bool> get doneOrCanceled => _doneOrCanceledCompleter.future;

  /// Cancels the animation.
  void cancel() {
    if (_doneCompleter.isCompleted) {
      return;
    }

    _rootElement.cancel();
    controller._runningAnimations.remove(this);
    _doneOrCanceledCompleter.complete(false);
  }

  void _start() {
    _rootElement = root._createElement()
      ..animation = this
      ..onComplete = _onComplete
      ..start();
  }

  void _onComplete() {
    controller._runningAnimations.remove(this);
    _doneCompleter.complete();
    _doneOrCanceledCompleter.complete(true);
  }
}

/// A mixin that simplifies working with animation graphs in a [State].
mixin AnimationGraphMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  /// The animation graph controller for this state.
  late final animationGraphController = AnimationGraphController(sync: this);

  @override
  void dispose() {
    animationGraphController.dispose();
    super.dispose();
  }

  /// Starts the animation graph specified by the given [root] node.
  ///
  /// See [AnimationGraphController.animate] for more information.
  GraphAnimation animate(AnimationNode root) =>
      animationGraphController.animate(root);

  /// Resets the current values of all [AnimatedValue]s to their
  /// [AnimatedValue.defaultValue]s.
  ///
  /// See [AnimationGraphController.resetAll] for more information.
  void resetAllAnimatedValues() => animationGraphController.resetAll();

  /// Cancels all running animations.
  void cancelAllAnimations() => animationGraphController.cancelAll();
}

/// Provides an [AnimationGraphController] to child widgets.
///
/// A provided controller can be accessed by calling
/// [AnimationGraphController.of] with the [BuildContext] of a widget that is a
/// descendant of an [AnimationGraphScope].
class AnimationGraphScope extends InheritedWidget {
  /// Creates an animation graph scope.
  const AnimationGraphScope({
    super.key,
    required this.controller,
    required super.child,
  });

  /// The animation graph controller to provide to child widgets.
  final AnimationGraphController controller;

  @override
  bool updateShouldNotify(AnimationGraphScope oldWidget) =>
      controller != oldWidget.controller;
}
