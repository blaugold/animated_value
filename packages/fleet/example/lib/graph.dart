import 'package:fleet/fleet.dart';
import 'package:flutter/material.dart' hide Action;

import 'app.dart';

final _scale = AnimatedValue.double$(defaultValue: 1, name: 'scale');
final _rotation = AnimatedValue.double$(name: 'rotation');
final _opacity = AnimatedValue.double$(defaultValue: 1, name: 'opacity');
final _color = AnimatedValue.color(defaultValue: Colors.pink, name: 'color');
final _offset = AnimatedValue.offset(name: 'offset');

AnimationNode _buildAnimation() {
  // An animation graph is an immutable data structure that represents an
  // animation. It is built by composing animation nodes. Group runs its
  // children in parallel, Sequence runs its children in sequence.
  return Sequence([
    // Here we reset all animated values to their default value.
    // This is necessary, in case the animation has already been run, because
    // the animated values are not reset automatically.
    // Unless `AnimatedValue.to(from: ...)` is specified, the animation of
    // that value starts from the value that was last set, either by an
    // animation, explicitly, or by resetting to the default value.
    Reset(),
    Group([
      _scale.to(2, 300.ms, curve: Curves.ease),
      _rotation.to(.25, 300.ms, curve: Curves.ease),
      _opacity.to(1, from: 0, 200.ms),
    ]),
    Pause(500.ms),
    Group([
      _color.to(Colors.teal, 500.ms),
      _scale.to(1, 500.ms, curve: Curves.ease),
      _offset.to(
        const Offset(300, 0),
        500.ms,
        curve: Curves.ease,
        delay: 200.ms,
      ),
      _opacity.to(0, 1.s, delay: 300.ms),
    ]),
    // ignore: avoid_print
    Action(() => print('Animation completed')),
  ])
      // The speed of all nodes in the animation graph can be adjusted by
      // this single call. This is useful for debugging purposes.
      .speed(1);
}

void main() {
  runApp(const ExampleApp(page: Page()));
}

class Page extends StatefulWidget {
  const Page({super.key});

  @override
  State<Page> createState() => _PageState();
}

class _PageState extends State<Page>
    with TickerProviderStateMixin, AnimationGraphMixin {
  void _animate() {
    // Cancel all running animations before starting a new one, in case the
    // previous animation has not completed. If two animations are run in
    // parallel that affect the same value, the result can be unpredictable.
    // If one animation starts a new value animation for the same animated value
    // while the previous animation is still running, the previous animation
    // is stopped and the new animation starts from the current value.
    cancelAllAnimations();
    animate(_buildAnimation());
  }

  @override
  Widget build(BuildContext context) {
    // By using an AnimationGraphScope, child widgets can access the
    // AnimationGraphController instance and it does not need to be passed
    // down the widget tree.
    return AnimationGraphScope(
      controller: animationGraphController,
      child: Scaffold(
        body: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              TranslateTransition(
                offset: _offset.of(context),
                child: RotationTransition(
                  turns: _rotation.of(context),
                  child: ScaleTransition(
                    scale: _scale.of(context),
                    child: FadeTransition(
                      opacity: _opacity.of(context),
                      child: _ColoredSquare(color: _color),
                    ),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _animate,
                child: const Text('Animate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// This widget is reusable since it is decoupled from the concrete
// AnimationGraphController and AnimationKey used in the AnimationGraph.
class _ColoredSquare extends StatelessWidget {
  const _ColoredSquare({required this.color});

  final AnimatedValue<Color> color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 200,
      child: ValueListenableBuilder(
        valueListenable: color.of(context),
        builder: (context, color, _) {
          return ColoredBox(color: color);
        },
      ),
    );
  }
}

class TranslateTransition extends AnimatedWidget {
  const TranslateTransition({
    super.key,
    required Animation<Offset> offset,
    required this.child,
  }) : super(listenable: offset);

  Animation<Offset> get offset => listenable as Animation<Offset>;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset.value,
      child: child,
    );
  }
}
