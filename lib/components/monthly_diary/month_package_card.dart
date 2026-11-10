import 'package:flutter/material.dart';

import 'memory_artwork.dart';

class MonthPackageCard extends StatelessWidget {
  const MonthPackageCard({
    super.key,
    required this.month,
    required this.title,
    required this.subtitle,
    required this.openLabel,
    required this.semanticsLabel,
    required this.photos,
    required this.onTap,
  });
  final DateTime month;
  final String title;
  final String subtitle;
  final String openLabel;
  final String semanticsLabel;
  final List<Widget> photos;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = MemoryArtworkColors(Theme.of(context).colorScheme);
    final tilt = (month.month % 3 - 1) * .014 - .018;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 48),
        child: MemoryArtworkButton(
          label: semanticsLabel,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: 44,
                          left: 14,
                          right: 14,
                          height: 126,
                          child: Transform.rotate(
                            angle: tilt,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color.lerp(
                                  colors.kraft,
                                  colors.accent,
                                  .22,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(9),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: width * .38,
                          child: Transform.rotate(
                            angle: .055,
                            child: Container(
                              width: width * .29,
                              height: 112,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: colors.paper,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadow,
                                    blurRadius: 7,
                                    offset: const Offset(1, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.spa_outlined,
                                    size: 22,
                                    color: colors.accent.withValues(alpha: .65),
                                  ),
                                  const SizedBox(height: 12),
                                  for (var i = 0; i < 3; i++)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: FractionallySizedBox(
                                        widthFactor: i == 2 ? .65 : 1,
                                        child: Container(
                                          height: 1,
                                          color: colors.accent.withValues(
                                            alpha: .22,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        for (var i = 0; i < photos.length && i < 2; i++)
                          Positioned(
                            left: i == 0 ? width * .075 : null,
                            right: i == 1 ? width * .055 : null,
                            top: i == 0 ? 12 : 20,
                            child: Transform.rotate(
                              angle: i == 0 ? -.20 : .19,
                              child: Container(
                                width: width * .33,
                                height: width * .39,
                                padding: const EdgeInsets.fromLTRB(5, 5, 5, 15),
                                decoration: BoxDecoration(
                                  color: colors.paper,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.shadow,
                                      blurRadius: 8,
                                      offset: const Offset(1, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRect(
                                  child: SizedBox.expand(child: photos[i]),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 86),
                          child: Transform.rotate(
                            angle: tilt,
                            child: CustomPaint(
                              painter: MemoryPaperBagPainter(
                                paper: colors.kraft,
                                ink: colors.accent,
                                shadow: colors.shadow,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  30,
                                  28,
                                  36,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          month.month.toString().padLeft(
                                            2,
                                            '0',
                                          ),
                                          textScaler: TextScaler.noScaling,
                                          style: TextStyle(
                                            fontSize: 62,
                                            fontWeight: FontWeight.w300,
                                            fontStyle: FontStyle.italic,
                                            height: 1,
                                            letterSpacing: -4,
                                            color: colors.ink,
                                          ),
                                        ),
                                        Transform.rotate(
                                          angle: .13,
                                          child: Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: colors.accent.withValues(
                                                  alpha: .55,
                                                ),
                                              ),
                                            ),
                                            child: Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .local_florist_outlined,
                                                    size: 17,
                                                    color: colors.accent,
                                                  ),
                                                  Text(
                                                    '${month.year}',
                                                    textScaler:
                                                        TextScaler.noScaling,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: colors.accent,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                        color: colors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.5,
                                        color: colors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Transform.translate(
                      offset: const Offset(0, -15),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: colors.ink,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                openLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: colors.paper,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 17,
                              color: colors.paper,
                            ),
                          ],
                        ),
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
}
