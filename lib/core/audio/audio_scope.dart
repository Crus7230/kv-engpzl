import 'package:flutter/widgets.dart';

import 'audio_controller.dart';
import 'audio_settings.dart';

class AudioScope extends InheritedWidget {
  const AudioScope({required this.controller, required super.child, super.key});
  final AudioController controller;
  static AudioController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AudioScope>()?.controller;
  static void play(BuildContext context, PuzzleSound sound) =>
      maybeOf(context)?.play(sound);
  @override
  bool updateShouldNotify(AudioScope oldWidget) =>
      !identical(controller, oldWidget.controller);
}
