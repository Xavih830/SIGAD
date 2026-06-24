import 'package:flutter/material.dart';

class SigadLogo extends StatelessWidget {
  final double size;
  final bool showLabel;
  final Color? textColor;

  const SigadLogo({
    super.key,
    this.size = 120,
    this.showLabel = true,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF1971C2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.15),
            child: CustomPaint(
              painter: _LogoPainter(),
            ),
          ),
        ),
        if (showLabel) ...[
          SizedBox(height: size * 0.1),
          Text(
            'SIGAD',
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: size * 0.2,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Draw the white shield
    paint.color = Colors.white;
    final path = Path();
    
    // Shield coordinates relative to size
    double w = size.width;
    double h = size.height;
    
    path.moveTo(w * 0.5, 0); // Top center
    path.lineTo(w * 0.9, h * 0.15); // Top right
    path.quadraticBezierTo(w * 0.9, h * 0.6, w * 0.5, h * 0.95); // Right side curve to pointed bottom
    path.quadraticBezierTo(w * 0.1, h * 0.6, w * 0.1, h * 0.15); // Pointed bottom to left curve
    path.close();
    
    canvas.drawPath(path, paint);

    // 2. Draw the car in corporate blue (#1971C2)
    paint.color = const Color(0xFF1971C2);
    
    // Draw car body
    final carBody = Rect.fromLTWH(w * 0.25, h * 0.38, w * 0.5, h * 0.12);
    final rrectBody = RRect.fromRectAndRadius(carBody, Radius.circular(w * 0.035));
    canvas.drawRRect(rrectBody, paint);
    
    // Draw car roof (cabin)
    final cabinPath = Path();
    cabinPath.moveTo(w * 0.32, h * 0.38);
    cabinPath.lineTo(w * 0.40, h * 0.26);
    cabinPath.lineTo(w * 0.60, h * 0.26);
    cabinPath.lineTo(w * 0.68, h * 0.38);
    cabinPath.close();
    canvas.drawPath(cabinPath, paint);

    // Draw wheels
    canvas.drawCircle(Offset(w * 0.36, h * 0.52), w * 0.075, paint);
    canvas.drawCircle(Offset(w * 0.64, h * 0.52), w * 0.075, paint);

    // Inner wheel hubs (white)
    paint.color = Colors.white;
    canvas.drawCircle(Offset(w * 0.36, h * 0.52), w * 0.03, paint);
    canvas.drawCircle(Offset(w * 0.64, h * 0.52), w * 0.03, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
