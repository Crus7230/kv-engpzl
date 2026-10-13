/// The legacy intro revealed the logo before its softly breathing prompt.
/// Compress that sequence into the existing 2.4-second startup hold. This
/// finite timeline never delays preparation or creates an endless ticker.
abstract final class IntroMotionTimeline {
  static const duration = Duration(milliseconds: 2200);

  static double reveal(double milliseconds, int start, int length) =>
      ((milliseconds - start) / length).clamp(0.0, 1.0);

  static double logo(double milliseconds) => reveal(milliseconds, 100, 1000);
  static double title(double milliseconds) => reveal(milliseconds, 450, 1000);
  static double tagline(double milliseconds) => reveal(milliseconds, 950, 750);
  static double status(double milliseconds) => reveal(milliseconds, 1300, 650);

  /// One gentle 800ms down/up breath, then full opacity. Unlike the original
  /// looping prompt, startup still advances automatically when it is ready.
  static double promptBrightness(double milliseconds) {
    if (milliseconds <= 1400 || milliseconds >= 2200) return 1;
    final phase = (milliseconds - 1400) / 800;
    return phase < .5 ? 1 - phase * 1.4 : .3 + (phase - .5) * 1.4;
  }
}
