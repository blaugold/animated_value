// ignore_for_file: lines_longer_than_80_chars

// SimpleAnimation(SuccessAnimation.miniGameProgressOpacity, 0.4, 0.5),
// SimpleAnimation(SuccessAnimation.overlayOpacity, 0.4, 0.7, curve: Curves.easeOut),
// SimpleAnimation(SuccessAnimation.cheerOpacity, 0.9, 1.2, curve: Curves.easeOut),
// SimpleAnimation(SuccessAnimation.primaryButtonScale, 0.9, 1.2, curve: Curves.easeOutBack),
// SimpleAnimation(SuccessAnimation.secondaryButtonScale, 1.1, 1.4, curve: Curves.easeOutBack),

import 'package:fleet/fleet.dart';
import 'package:flutter/material.dart';

abstract final class SuccessAnimation {
  static final miniGameProgressOpacity = AnimatedValue.double$();
  static final overlayOpacity = AnimatedValue.double$();
  static final cheerOpacity = AnimatedValue.double$();
  static final primaryButtonScale = AnimatedValue.double$();
  static final secondaryButtonScale = AnimatedValue.double$();

  AnimationNode enterAnimation() {
    return ValueAnimationDefaults(
      curve: Curves.easeOut,
      duration: 300.ms,
      Sequence([
        Pause(400.ms),
        Group([
          miniGameProgressOpacity.forward(over: 100.ms, curve: Curves.linear),
          overlayOpacity.forward(),
        ]),
        Pause(300.ms),
        Group([
          cheerOpacity.forward(),
          ValueAnimationDefaults(
            curve: Curves.easeOutBack,
            staggered(delay: 200.ms, [
              primaryButtonScale.forward(),
              secondaryButtonScale.forward(),
            ]),
          ),
        ]),
      ]),
    );
  }
}

AnimationNode staggered(
  List<AnimationNode> children, {
  required Duration delay,
}) {
  return Group([
    for (final (i, child) in children.indexed) child.delay(delay * i),
  ]);
}
