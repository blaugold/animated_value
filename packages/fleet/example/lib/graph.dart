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
  return ValueAnimationDefaults(
    curve: Curves.ease,
    Sequence([
      // Here we reset all animated values to their default value.
      // This is necessary, in case the animation has already been run, because
      // the animated values are not reset automatically.
      // Unless `AnimatedValue.to(from: ...)` is specified, the animation of
      // that value starts from the value that was last set, either by an
      // animation, explicitly, or by resetting to the default value.
      resetAll([
        _scale,
        _rotation,
        _opacity,
        _color,
        _offset,
      ]),
      Group([
        _scale.to(2, over: 300.ms),
        _rotation.to(.25, over: 300.ms),
        _opacity.to(1, from: 0, over: 200.ms, curve: Curves.linear),
      ]),
      Pause(500.ms),
      Group([
        _color.to(Colors.teal, over: 500.ms, curve: Curves.linear),
        _scale.to(1, over: 500.ms),
        _offset.to(const Offset(300, 0), over: 500.ms).delay(200.ms),
        _opacity.to(0, over: 1.s, curve: Curves.linear).delay(300.ms),
      ]),
      // ignore: avoid_print
      Action(() => print('Animation completed')),
    ]),
  )
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
// AnimationGraphController and AnimatedValue used in the animation graph.
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
