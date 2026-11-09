import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/utils/app_config.dart';
import 'package:qwallet_mobileapp/utils/connectivity_monitor.dart';
import 'package:qwallet_mobileapp/widgets/animated_wallet_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  // ── Intro ──────────────────────────────────────────────────────────────
  // 1. Logo assembles alone, centered and enlarged (rest of the UI hidden).
  // 2. Logo glides + shrinks to its normal spot; UI fades/slides in.
  static const double _introLogoScale = 1.35;
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _introMove = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.6, curve: Curves.easeInOutCubic),
  );
  late final Animation<double> _titleIn = _revealAt(0.35);
  late final Animation<double> _subtitleIn = _revealAt(0.42);
  late final Animation<double> _buttonIn = _revealAt(0.50);
  late final Animation<double> _footerIn = _revealAt(0.60);

  final GlobalKey _areaKey = GlobalKey();
  final GlobalKey _logoKey = GlobalKey();

  /// Shift from the logo's normal spot to the center of the screen.
  Offset _introOffset = Offset.zero;
  bool _introFinished = false;

  Animation<double> _revealAt(double start) => CurvedAnimation(
    parent: _intro,
    curve: Interval(start, start + 0.4, curve: Curves.easeOutCubic),
  );

  StreamSubscription<bool>? _netSub;

  /// null = still probing (no banner); false = offline (red); true = online.
  bool? _online;

  /// After reconnect, briefly show green before hiding.
  bool _showBackOnline = false;
  Timer? _hideGreenTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween(
      begin: 0.15,
      end: 0.6,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _netSub = ConnectivityMonitor.instance.watch().listen(_onNetStatus);

    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _introFinished = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureIntroOffset());
  }

  void _measureIntroOffset() {
    if (!mounted) return;
    final area = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    final logo = _logoKey.currentContext?.findRenderObject() as RenderBox?;
    if (area == null || logo == null || !area.hasSize || !logo.hasSize) return;
    final logoCenter = logo.localToGlobal(
      logo.size.center(Offset.zero),
      ancestor: area,
    );
    setState(() => _introOffset = area.size.center(Offset.zero) - logoCenter);
  }

  /// Logo finished assembling → short beat, then move it into place.
  void _onLogoAssembled() {
    if (!mounted) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _intro.value = 1.0;
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _intro.forward();
    });
  }

  /// Fades + slides [child] up as [anim] runs (UI reveal after the intro).
  Widget _reveal(Animation<double> anim, Widget child) => FadeTransition(
    opacity: anim,
    child: AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (_, c) => Transform.translate(
        offset: Offset(0, 16 * (1 - anim.value)),
        child: c,
      ),
    ),
  );

  void _onNetStatus(bool online) {
    if (!mounted) return;
    final wasOffline = _online == false;
    setState(() {
      _online = online;
      if (online && wasOffline) {
        // Just came back — flash green then dismiss.
        _showBackOnline = true;
        _hideGreenTimer?.cancel();
        _hideGreenTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() => _showBackOnline = false);
        });
      } else if (!online) {
        _showBackOnline = false;
        _hideGreenTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _hideGreenTimer?.cancel();
    _netSub?.cancel();
    _ctrl.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showOffline = _online == false;
    final showGreen = _online == true && _showBackOnline;
    // Banner waits for the intro so it doesn't shift the logo mid-animation.
    final showBanner = _introFinished;

    return Scaffold(
      backgroundColor: qBg,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        toolbarHeight: 0,
      ),
      body: SafeArea(
        child: Center(
          // Keeps the splash content centered on fold / wide screens.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SizedBox(
              key: _areaKey,
              width: double.infinity,
              height: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Offline / back-online banner (top of splash).
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: showBanner && showOffline
                        ? _NetBanner(
                            color: qBg,
                            bg: qRed,
                            icon: Icons.wifi_off_rounded,
                            text: 'No internet — you are offline',
                          )
                        : showBanner && showGreen
                        ? _NetBanner(
                            color: qBg,
                            bg: qValid,
                            icon: Icons.wifi_rounded,
                            text: 'Back online',
                          )
                        : const SizedBox.shrink(),
                  ),

                  const Spacer(flex: 2),

                  // ── Logo area ────────────────────────────────────────────────
                  // Keyed box = the logo's resting spot (measured untransformed);
                  // the transform inside moves it from screen center to here.
                  SizedBox(
                    key: _logoKey,
                    child: AnimatedBuilder(
                      animation: _introMove,
                      builder: (_, child) {
                        final t = _introMove.value;
                        return Transform.translate(
                          offset: _introOffset * (1 - t),
                          child: Transform.scale(
                            scale: lerpDouble(_introLogoScale, 1, t)!,
                            child: child,
                          ),
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (_, __) =>
                                const SizedBox(width: 160, height: 160),
                          ),
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (_, __) =>
                                const SizedBox(width: 120, height: 120),
                          ),
                          // Logo only (D4) — not title, not Get Started, not full screen.
                          // STORE GATE — remove onDoubleTap (or wrap in kDebugMode)
                          // before any App Store / production build (with Alice).
                          GestureDetector(
                            onDoubleTap: () {
                              HapticFeedback.lightImpact();
                              Get.toNamed(Routes.DEV_RUNTIME_CONFIG);
                            },
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              alignment: Alignment.center,
                              child: AnimatedWalletLogo(
                                size: 150,
                                onCompleted: _onLogoAssembled,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  _reveal(
                    _titleIn,
                    const Text(
                      'QWallet',
                      style: TextStyle(
                        fontSize: 36,
                        color: Colors.black,
                        letterSpacing: -1,
                        fontFamily: 'formula',
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  _reveal(
                    _subtitleIn,
                    const Text(
                      'QChain assets',
                      style: TextStyle(
                        fontSize: 8,
                        color: qText,
                        letterSpacing: 1,
                        fontFamily: 'formula',
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Button ───────────────────────────────────────────────────
                  // Offline → disabled. Still probing (_online == null) stays
                  // enabled so a slow first probe doesn't lock the button.
                  // Hidden + untappable until the intro has finished.
                  _reveal(
                    _buttonIn,
                    IgnorePointer(
                      ignoring: !_introFinished,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 350),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: showOffline
                                  ? null
                                  : () {
                                      // Controllers (and their API fetches) start only
                                      // after Onboard 3 finishes key check/registration.
                                      Get.toNamed(Routes.ONBOARD1);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: qPrimary,
                                foregroundColor: qBg,
                                disabledBackgroundColor: qBorder,
                                disabledForegroundColor: qSub,
                                elevation: 0,
                                minimumSize: const Size(0, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                showOffline ? 'No internet' : 'Get Started',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _reveal(
                    _footerIn,
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          text: const TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                text: 'Powered by ',
                                style: TextStyle(
                                  color: qDimmed,
                                  fontSize: 11,
                                  fontFamily: 'SFPro',
                                ),
                              ),
                              TextSpan(
                                text: 'QChain',
                                style: TextStyle(
                                  color: qDimmed,
                                  fontSize: 11,
                                  fontFamily: 'formula',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Manual IPA/build label — bump kAppBuildNumber in app_config.dart
                        Text(
                          'Build $kAppBuildNumber',
                          style: const TextStyle(
                            color: qDimmed,
                            fontSize: 10,
                            fontFamily: 'SFPro',
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NetBanner extends StatelessWidget {
  const _NetBanner({
    required this.color,
    required this.bg,
    required this.icon,
    required this.text,
  });

  final Color color;
  final Color bg;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
