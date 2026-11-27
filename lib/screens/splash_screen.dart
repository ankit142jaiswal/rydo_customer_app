import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Animated splash that builds the Rydo icon in three steps:
///   1. the winding road ("way") draws itself,
///   2. the navigation pin drops onto the end of the road,
///   3. the "Rydo" wordmark appears.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 3200);

  // Icon background colours (sampled from assets/images/rydo_icon.png)
  static const _bgCenter = Color(0xFFE5B724);
  static const _bgEdge = Color(0xFFC69421);

  // Where the wordmark sits inside the 1024×1024 icon, as fractions (with margin for the edge fade).
  static const _markLeft = 0.10, _markTop = 0.315, _markWidth = 0.80, _markHeight = 0.405;

  late final AnimationController _ctrl;
  late final Animation<double> _road;
  late final Animation<double> _pinDrop;
  late final Animation<double> _pinFade;
  late final Animation<double> _ripple;
  late final Animation<double> _markFade;
  late final Animation<double> _markScale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: _duration, vsync: this);

    Animation<double> interval(double a, double b, Curve curve) =>
        CurvedAnimation(parent: _ctrl, curve: Interval(a, b, curve: curve));

    _road = interval(0.00, 0.42, Curves.easeInOutCubic); // 1. way
    _pinDrop = interval(0.40, 0.60, Curves.bounceOut); //    2. pin
    _pinFade = interval(0.40, 0.46, Curves.easeOut);
    _ripple = interval(0.52, 0.80, Curves.easeOut);
    _markFade = interval(0.58, 0.85, Curves.easeOut); //     3. Rydo
    _markScale = Tween(begin: 0.85, end: 1.0).animate(interval(0.58, 0.92, Curves.easeOutBack));

    _ctrl.forward();
    // Start after the first frame: checkAuthStatus() notifies listeners
    // synchronously, which is not allowed while the first build is running.
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  Future<void> _navigate() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // Run the auth check while the animation plays; leave once both are done.
    await Future.wait([
      Future.delayed(_duration + const Duration(milliseconds: 400)),
      auth.checkAuthStatus(),
    ]);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, auth.user != null ? '/home' : '/login');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    // Square "icon canvas", sized to fit any window shape.
    final s = (screen.shortestSide * 0.95).clamp(220.0, 620.0);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(colors: [_bgCenter, _bgEdge], radius: 0.95),
        ),
        child: Center(
          child: SizedBox(
            width: s,
            height: s,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final pinTip = _RoadPainter.end * s;
                final pinSize = s * 0.085;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Road
                    Positioned.fill(child: CustomPaint(painter: _RoadPainter(_road.value))),

                    // Ripple under the pin
                    if (_ripple.value > 0)
                      Positioned(
                        left: pinTip.dx - s * 0.07,
                        top: pinTip.dy - s * 0.02,
                        width: s * 0.14,
                        height: s * 0.04,
                        child: CustomPaint(painter: _RipplePainter(_ripple.value)),
                      ),

                    // 2. Pin (drops from above, tip lands on the road end)
                    Positioned(
                      left: pinTip.dx - pinSize / 2,
                      top: pinTip.dy - pinSize * 0.95 - (1 - _pinDrop.value) * s * 0.25,
                      child: Opacity(
                        opacity: _pinFade.value,
                        child: CustomPaint(size: Size(pinSize, pinSize), painter: _PinPainter()),
                      ),
                    ),

                    // 3. Rydo wordmark (cropped from the icon, edges faded into the background)
                    Positioned(
                      left: _markLeft * s,
                      top: _markTop * s,
                      width: _markWidth * s,
                      height: _markHeight * s,
                      child: Opacity(
                        opacity: _markFade.value,
                        child: Transform.scale(scale: _markScale.value, child: _wordmark(s)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// The wordmark region of rydo_icon.png. Only the outer rim is faded
  /// (horizontally and vertically) so the crop blends into the background
  /// without cutting into the letters.
  Widget _wordmark(double s) {
    Shader fade(Rect rect, Alignment begin, Alignment end) => LinearGradient(
          begin: begin,
          end: end,
          colors: const [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
          stops: const [0.0, 0.10, 0.90, 1.0],
        ).createShader(rect);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => fade(r, Alignment.topCenter, Alignment.bottomCenter),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => fade(r, Alignment.centerLeft, Alignment.centerRight),
        child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: s,
          maxWidth: s,
          minHeight: s,
          maxHeight: s,
          child: Transform.translate(
            offset: Offset(-_markLeft * s, -_markTop * s),
            child: Image.asset('assets/images/rydo_icon.png', width: s, height: s, fit: BoxFit.cover),
          ),
        ),
      ),
      ),
    );
  }
}

/// Winding road from the bottom-left up to the pin, drawn progressively.
/// Shape follows the road in the Rydo icon.
class _RoadPainter extends CustomPainter {
  _RoadPainter(this.progress);
  final double progress;

  /// Road end (where the pin lands), as a fraction of the canvas.
  static const end = Offset(0.69, 0.255);

  static Path _path(Size size) {
    Offset p(double x, double y) => Offset(x * size.width, y * size.height);
    final a = p(0.0, 0.82);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(p(0.30, 0.70).dx, p(0.30, 0.70).dy, p(0.80, 0.72).dx, p(0.80, 0.72).dy, p(0.90, 0.55).dx, p(0.90, 0.55).dy)
      ..cubicTo(p(0.98, 0.42).dx, p(0.98, 0.42).dy, p(0.50, 0.40).dx, p(0.50, 0.40).dy, p(0.48, 0.32).dx, p(0.48, 0.32).dy)
      ..cubicTo(p(0.47, 0.27).dx, p(0.47, 0.27).dy, p(0.62, 0.27).dx, p(0.62, 0.27).dy, p(end.dx, end.dy).dx, p(end.dx, end.dy).dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final full = _path(size);
    final drawn = Path();
    for (final m in full.computeMetrics()) {
      drawn.addPath(m.extractPath(0, m.length * progress), Offset.zero);
    }
    final w = size.width;

    // Road body (soft darker band), edges, and a bright centre line
    canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.055
          ..color = const Color(0xFF8A6412).withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    for (final edge in [w * 0.05, w * 0.03]) {
      canvas.drawPath(
          drawn,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = edge
            ..color = const Color(0xFFF6D35A).withValues(alpha: 0.35));
    }
    canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.006
          ..shader = ui.Gradient.linear(Offset(0, size.height), Offset(w, 0),
              [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.9)]));
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.progress != progress;
}

/// Dark glossy map pin (like the one in the Rydo icon). Tip is at the bottom centre.
class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, r = w * 0.36, cy = r + h * 0.04;
    final tip = Offset(cx, h * 0.98);
    final pin = Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(cx - r * 0.35, h * 0.80, cx - r, cy + r * 0.75, cx - r, cy)
      ..arcToPoint(Offset(cx + r, cy), radius: Radius.circular(r))
      ..cubicTo(cx + r, cy + r * 0.75, cx + r * 0.35, h * 0.80, tip.dx, tip.dy)
      ..close();
    canvas.drawShadow(pin, Colors.black, 3, false);
    canvas.drawPath(
        pin,
        Paint()
          ..shader = ui.Gradient.linear(Offset(cx - r, 0), Offset(cx + r, h),
              [const Color(0xFF5A5A5A), const Color(0xFF1A1A1A), const Color(0xFF0D0D0D)], [0.0, 0.5, 1.0]));
    // Hole in the pin head
    canvas.drawCircle(Offset(cx, cy), r * 0.42, Paint()..color = const Color(0xFFE1B224));
    canvas.drawCircle(Offset(cx, cy), r * 0.42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12
          ..color = const Color(0xFF6B6B6B));
  }

  @override
  bool shouldRepaint(_PinPainter old) => false;
}

/// Glowing rings spreading out under the pin after it lands.
class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final k = (t - i * 0.2).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final rect = Rect.fromCenter(center: c, width: size.width * k, height: size.height * k);
      canvas.drawOval(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white.withValues(alpha: (1 - k) * 0.8));
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}
