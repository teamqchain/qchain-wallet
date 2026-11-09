import 'dart:math' as math;

import 'package:flutter/material.dart';

/// QWallet logo that assembles itself: the wallet appears, the yellow, blue
/// and red cards pour in (alternating from the top right / top left) as flat
/// rectangles and tuck into the pocket, then all three pop into their
/// slanted final pose.
///
/// Layers:
///  * cards — drawn in code (see [_cards]) so they are complete while moving;
///  * wallet front — `logo_wallet_front.png`, sliced from
///    `wallet_icon_transparet.png` (same canvas, transparent where cards show).
///
/// All geometry is in the original 2472×2476 logo's pixel space and scaled
/// to [size]. Honors the system "reduce motion" setting.
class AnimatedWalletLogo extends StatefulWidget {
  const AnimatedWalletLogo({super.key, this.size = 150, this.onCompleted});

  /// Rendered width in logical pixels.
  final double size;

  /// Called once the logo has fully assembled (also with reduce motion on).
  final VoidCallback? onCompleted;

  static const String frontAsset = 'assets/images/logo_wallet_front.png';
  static const String fallbackAsset =
      'assets/images/wallet_icon_transparet.png';

  @override
  State<AnimatedWalletLogo> createState() => _AnimatedWalletLogoState();
}

class _AnimatedWalletLogoState extends State<AnimatedWalletLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  late final Animation<double> _walletIn = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 0.18, curve: Curves.easeOut),
  );

  /// Tiny squash on the wallet while the cards pop into place.
  late final Animation<double> _landing =
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.025), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.025, end: 1.0), weight: 1),
      ]).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.74, 0.92, curve: Curves.easeInOut),
        ),
      );

  /// Flight + insert per card, in [_cards] order (red, blue, yellow).
  /// Yellow goes first, then blue, then red.
  late final List<Animation<double>> _flights = [
    for (final start in const [0.42, 0.27, 0.12])
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, start + 0.30, curve: Curves.linear),
      ),
  ];

  /// Final step: flat cards pop into their slanted pose, all together.
  late final Animation<double> _arrange = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.74, 1.0, curve: Curves.linear),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _ctrl.value = 1.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCompleted?.call();
      });
      return;
    }
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onCompleted?.call();
    });
    // Decode the wallet layer first so it doesn't pop in mid-animation.
    precacheImage(
      const AssetImage(AnimatedWalletLogo.frontAsset),
      context,
    ).whenComplete(() {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = w * _kSrcH / _kSrcW;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CardsPainter(_flights, _arrange, repaint: _ctrl),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) => Opacity(
                opacity: _walletIn.value,
                child: Transform.scale(
                  scale: (0.9 + 0.1 * _walletIn.value) * _landing.value,
                  alignment: const Alignment(0, 0.4),
                  child: child,
                ),
              ),
              child: Image.asset(
                AnimatedWalletLogo.frontAsset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) =>
                    Image.asset(AnimatedWalletLogo.fallbackAsset),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card geometry (source-logo pixels) ─────────────────────────────────────

const double _kSrcW = 2472;
const double _kSrcH = 2476;
const double _kCardRadius = 140;
const double _kCardAspect = 1.586; // ID-1 card ratio; bottom stays hidden.

class _CardSpec {
  const _CardSpec({
    required this.left,
    required this.right,
    required this.top,
    required this.slope,
    required this.fromRight,
    required this.colors,
  });

  final double left, right;

  /// Y of the top-left corner.
  final double top;

  /// Top edge rises by this much per pixel to the right (vertical sides).
  final double slope;

  /// Pours in from the top right (true) or top left (false).
  final bool fromRight;

  /// [edge] or [edge, highlight] — two colors get a soft radial gloss.
  final List<Color> colors;

  double get width => right - left;
  double get height => width / _kCardAspect;
}

const List<_CardSpec> _cards = [
  _CardSpec(
    left: 304,
    right: 2051,
    top: 207,
    slope: -0.1007,
    fromRight: true,
    colors: [Color(0xFFE14444)],
  ),
  _CardSpec(
    left: 264,
    right: 2187,
    top: 428,
    slope: -0.0656,
    fromRight: false,
    colors: [Color(0xFF3577E7)],
  ),
  _CardSpec(
    left: 284,
    right: 2193,
    top: 596,
    slope: 0,
    fromRight: true,
    colors: [Color(0xFFE7D23C), Color(0xFFF0E173)],
  ),
];

/// Where a card starts its pour, as fractions of the logo size.
const double _kPourDx = 0.55;
const double _kPourDy = 0.48;

/// Tilt (radians) a card has at the start of its pour.
const double _kPourTilt = 0.22;

class _CardsPainter extends CustomPainter {
  _CardsPainter(this.flights, this.arrange, {required Listenable repaint})
    : super(repaint: repaint);

  final List<Animation<double>> flights;
  final Animation<double> arrange;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _kSrcW;

    // Arrange: skew 0 → final with a little overshoot ("pop"), and a small lift.
    final a = arrange.value;
    final skewT = Curves.easeOutBack.transform(a);
    final lift = -0.025 * size.height * math.sin(math.pi * a);

    for (var i = 0; i < _cards.length; i++) {
      final t = flights[i].value;
      if (t <= 0) continue;

      final card = _cards[i];
      final dir = card.fromRight ? 1.0 : -1.0;
      final opacity = Curves.easeOut.transform((t / 0.3).clamp(0.0, 1.0));

      // Pour arc: sideways motion settles first, then the card drops in.
      final dx =
          dir * _kPourDx * size.width * (1 - Curves.easeOutCubic.transform(t));
      final dy =
          -_kPourDy * size.height * (1 - Curves.easeInOutCubic.transform(t));
      final tilt = dir * _kPourTilt * (1 - Curves.easeOut.transform(t));

      final w = card.width, h = card.height;
      // Pivot = middle of the card's top edge in its final pose, so the pop
      // fans the top: left side dips, right side rises.
      final pivotX = card.left + w / 2;
      final pivotY = card.top + card.slope * w / 2;

      canvas.save();
      canvas.translate(dx, dy + (a > 0 ? lift : 0));
      canvas.scale(s);
      canvas.translate(pivotX, pivotY);
      if (tilt != 0) {
        canvas.translate(0, h / 2);
        canvas.rotate(tilt);
        canvas.translate(0, -h / 2);
      }
      // Skew Y: sides stay vertical, top edge slants. 0 while flying.
      final k = card.slope * skewT;
      if (k != 0) {
        canvas.transform((Matrix4.identity()..setEntry(1, 0, k)).storage);
      }

      final rect = Rect.fromLTWH(-w / 2, 0, w, h);
      final paint = Paint()..isAntiAlias = true;
      if (card.colors.length == 1) {
        paint.color = card.colors.first.withValues(alpha: opacity);
      } else {
        paint.shader = RadialGradient(
          center: const Alignment(0.1, -0.6),
          radius: 0.75,
          colors: [
            card.colors[1].withValues(alpha: opacity),
            card.colors[0].withValues(alpha: opacity),
          ],
        ).createShader(rect);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(_kCardRadius)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CardsPainter old) =>
      old.flights != flights || old.arrange != arrange;
}
