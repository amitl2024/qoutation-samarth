/// How tightly the letterhead is packed. 1.0 is the full-size layout; smaller
/// values shrink every font, gap, and stamp proportionally so a long quotation
/// still lands on one sheet.
///
/// The letterhead banner and the footer block keep their full size — they are
/// the fixed furniture of the page — so only the body shrinks.
class LetterheadDensity {
  final double scale;
  const LetterheadDensity(this.scale);

  static const LetterheadDensity full = LetterheadDensity(1.0);

  /// Steps tried by the auto-fit pass, loosest first. The floor is the point
  /// where the document stops being comfortable to read in print.
  static const List<double> fitSteps = [1.0, 0.95, 0.90, 0.85, 0.80, 0.75, 0.70];

  /// Below this the text is too small to put in front of a client.
  static const double readableFloor = 0.70;

  bool get isCompressed => scale < 1.0;

  /// Scale a dimension (font size, gap, image box).
  double d(double value) => value * scale;

  /// Vertical gaps shrink a little faster than text — whitespace is the
  /// cheapest thing to give up.
  double gap(double value) => value * (0.55 + 0.45 * scale) * scale;
}
