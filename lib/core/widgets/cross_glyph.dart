import "package:flutter/material.dart";

/// The church glyph on Home's category strip: a Latin cross.
///
/// The one glyph in the app that is not a `CupertinoIcons` entry, because the
/// set has no cross. Two rounded strokes on the same optical box and stroke
/// weight the Cupertino glyphs draw at 25dp, so it sits beside them without
/// reading as a different family. See the note in `AppIcons`.
class CrossGlyph extends StatelessWidget {
  const CrossGlyph({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _CrossPainter(color)),
  );
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width / 9
      ..strokeCap = StrokeCap.round;
    final centreX = size.width / 2;
    final upright = size.height * 0.9;
    final top = (size.height - upright) / 2;
    final crossbarY = top + upright * 0.32;
    final halfBar = size.width * 0.3;
    canvas.drawLine(
      Offset(centreX, top),
      Offset(centreX, top + upright),
      paint,
    );
    canvas.drawLine(
      Offset(centreX - halfBar, crossbarY),
      Offset(centreX + halfBar, crossbarY),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => color != oldDelegate.color;
}
