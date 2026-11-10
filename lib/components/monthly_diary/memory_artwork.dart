import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Warm paper and quiet botanical tints, with the app's own theme underneath.
class MemoryArtworkColors {
  MemoryArtworkColors(ColorScheme scheme)
    : ink = scheme.onSurface,
      muted = scheme.onSurfaceVariant,
      paper = Color.lerp(
        scheme.surfaceContainerLow,
        scheme.brightness == Brightness.dark
            ? const Color(0xff37372e)
            : const Color(0xfff7f0dd),
        .72,
      )!,
      kraft = Color.lerp(
        scheme.surfaceContainerHighest,
        scheme.brightness == Brightness.dark
            ? const Color(0xff514c3e)
            : const Color(0xffe6d8b9),
        .78,
      )!,
      sage = Color.lerp(
        scheme.secondaryContainer,
        scheme.brightness == Brightness.dark
            ? const Color(0xff394c41)
            : const Color(0xffe0e7d6),
        .78,
      )!,
      accent = Color.lerp(
        scheme.primary,
        scheme.brightness == Brightness.dark
            ? const Color(0xffc6b496)
            : const Color(0xff806e52),
        .65,
      )!,
      shadow = scheme.shadow.withValues(
        alpha: scheme.brightness == Brightness.dark ? .25 : .13,
      );

  final Color ink;
  final Color muted;
  final Color paper;
  final Color kraft;
  final Color sage;
  final Color accent;
  final Color shadow;
}

/// A single accessible action around decorative (possibly interactive) photos.
/// Motion only happens on interaction, and is disabled with the route's ticker.
class MemoryArtworkButton extends StatefulWidget {
  const MemoryArtworkButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<MemoryArtworkButton> createState() => _MemoryArtworkButtonState();
}

class _MemoryArtworkButtonState extends State<MemoryArtworkButton> {
  bool _pressed = false;
  bool _focused = false;
  bool _showFocus = false;

  void _setPressed(bool value) {
    if (value != _pressed) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final animate =
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context) &&
        TickerMode.of(context);
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      includeFocusSemantics: false,
      onFocusChange: (value) => setState(() => _focused = value),
      onShowFocusHighlight: (value) => setState(() => _showFocus = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Semantics(
        label: widget.label,
        button: true,
        focusable: true,
        focused: _focused,
        onTap: widget.onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: _showFocus
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: AnimatedScale(
              scale: _pressed && animate ? .975 : 1,
              duration: animate
                  ? const Duration(milliseconds: 180)
                  : Duration.zero,
              curve: Curves.easeOutCubic,
              child: ExcludeFocus(child: IgnorePointer(child: widget.child)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slow breathing belongs to the illustration, never its label or hit region.
class MemoryArtworkFloat extends StatefulWidget {
  const MemoryArtworkFloat({
    super.key,
    required this.seed,
    required this.child,
  });

  final int seed;
  final Widget child;

  @override
  State<MemoryArtworkFloat> createState() => _MemoryArtworkFloatState();
}

class _MemoryArtworkFloatState extends State<MemoryArtworkFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _enabled = false;

  Duration get _period =>
      Duration(milliseconds: 5500 + (widget.seed % 7) * 250);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _period,
      value: (widget.seed % 13) / 13,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled =
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context) &&
        TickerMode.of(context);
    if (enabled == _enabled) return;
    _enabled = enabled;
    if (enabled) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(MemoryArtworkFloat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed) {
      _controller.duration = _period;
      if (_enabled) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_enabled
      ? widget.child
      : AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, math.sin(_controller.value * math.pi * 2) * 2),
            child: child,
          ),
        );
}

/// Smooth, asymmetric silhouettes rather than a repeated rounded rectangle.
Path memoryOrganicPath(Size size, int seed) {
  final variant = seed % 4;
  final points = switch (variant) {
    0 => const [
      Offset(.48, .025),
      Offset(.94, .17),
      Offset(.97, .62),
      Offset(.70, .97),
      Offset(.23, .94),
      Offset(.025, .59),
      Offset(.12, .17),
    ],
    1 => const [
      Offset(.39, .03),
      Offset(.83, .09),
      Offset(.975, .44),
      Offset(.85, .86),
      Offset(.44, .98),
      Offset(.065, .76),
      Offset(.04, .30),
    ],
    2 => const [
      Offset(.52, .035),
      Offset(.94, .27),
      Offset(.92, .73),
      Offset(.57, .98),
      Offset(.14, .85),
      Offset(.025, .43),
      Offset(.20, .095),
    ],
    _ => const [
      Offset(.36, .03),
      Offset(.83, .10),
      Offset(.975, .50),
      Offset(.75, .94),
      Offset(.30, .97),
      Offset(.035, .65),
      Offset(.08, .24),
    ],
  };
  Offset scale(Offset point) =>
      Offset(point.dx * size.width, point.dy * size.height);
  final start = scale((points.last + points.first) / 2);
  final path = Path()..moveTo(start.dx, start.dy);
  for (var i = 0; i < points.length; i++) {
    final control = scale(points[i]);
    final next = scale((points[i] + points[(i + 1) % points.length]) / 2);
    path.quadraticBezierTo(control.dx, control.dy, next.dx, next.dy);
  }
  return path..close();
}

class MemoryOrganicClipper extends CustomClipper<Path> {
  const MemoryOrganicClipper(this.seed);
  final int seed;
  @override
  Path getClip(Size size) => memoryOrganicPath(size, seed);
  @override
  bool shouldReclip(MemoryOrganicClipper oldClipper) => oldClipper.seed != seed;
}

class MemoryOrganicPainter extends CustomPainter {
  const MemoryOrganicPainter({
    required this.seed,
    required this.fill,
    required this.shadow,
    this.rim,
  });
  final int seed;
  final Color fill;
  final Color shadow;
  final Color? rim;

  @override
  void paint(Canvas canvas, Size size) {
    final path = memoryOrganicPath(size, seed);
    if (rim == null) {
      canvas.drawShadow(path, shadow, 9, true);
      canvas.drawPath(path, Paint()..color = fill);
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = rim!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(MemoryOrganicPainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.fill != fill ||
      oldDelegate.shadow != shadow ||
      oldDelegate.rim != rim;
}

class MemoryPaperBagPainter extends CustomPainter {
  const MemoryPaperBagPainter({
    required this.paper,
    required this.ink,
    required this.shadow,
  });
  final Color paper;
  final Color ink;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(3, 10)
      ..lineTo(w * .16, 14)
      ..lineTo(w * .34, 6)
      ..lineTo(w * .51, 12)
      ..lineTo(w * .66, 5)
      ..lineTo(w * .84, 11)
      ..lineTo(w - 3, 3)
      ..lineTo(w - 7, h - 7)
      ..lineTo(w * .52, h - 2)
      ..lineTo(7, h - 5)
      ..close();
    canvas.drawShadow(path, shadow, 9, true);
    canvas.drawPath(path, Paint()..color = paper);
    canvas.save();
    canvas.clipPath(path);
    final foldPaint = Paint()..color = ink.withValues(alpha: .035);
    canvas.drawPath(
      Path()
        ..moveTo(0, h * .49)
        ..lineTo(w * .56, h)
        ..lineTo(0, h)
        ..close(),
      foldPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w, h * .42)
        ..lineTo(w * .43, h)
        ..lineTo(w, h)
        ..close(),
      foldPaint,
    );
    final fiber = Paint()
      ..color = ink.withValues(alpha: .06)
      ..strokeWidth = .5;
    for (var y = 14.0; y < h; y += 8) {
      for (var x = 6.0; x < w; x += 8) {
        final shift = math.sin(x * .7 + y) * 1.5;
        canvas.drawLine(
          Offset(x + shift, y),
          Offset(x + shift + 1, y + .8),
          fiber,
        );
      }
    }
    canvas.drawLine(Offset(8, h - 16), Offset(w - 8, h - 18), fiber);
    canvas.restore();
  }

  @override
  bool shouldRepaint(MemoryPaperBagPainter oldDelegate) =>
      oldDelegate.paper != paper ||
      oldDelegate.ink != ink ||
      oldDelegate.shadow != shadow;
}
