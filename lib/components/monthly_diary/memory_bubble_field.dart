import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'memory_artwork.dart';

class MemoryDayBubble extends StatelessWidget {
  const MemoryDayBubble({
    super.key,
    required this.day,
    required this.dateLabel,
    required this.excerpt,
    required this.semanticsLabel,
    required this.entryCount,
    this.photo,
    this.accent,
    required this.onTap,
  });
  final DateTime day;
  final String dateLabel;
  final String excerpt;
  final String semanticsLabel;
  final int entryCount;
  final Widget? photo;
  final Color? accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = MemoryArtworkColors(Theme.of(context).colorScheme);
    final seed = day.year * 372 + day.month * 31 + day.day;
    final fill = Color.lerp(
      colors.sage,
      accent ?? colors.paper,
      seed.isEven ? .25 : .65,
    )!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MemoryArtworkButton(
      label: semanticsLabel,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: seed % 3 == 0 ? 1.05 : 1,
              child: MemoryArtworkFloat(
                seed: seed,
                child: Stack(
                  children: [
                    if (entryCount > 1)
                      Positioned(
                        right: 6,
                        top: 19,
                        child: Transform.rotate(
                          angle: .23,
                          child: Container(
                            width: 45,
                            height: 53,
                            decoration: BoxDecoration(
                              color: Color.lerp(fill, colors.accent, .12),
                              borderRadius: const BorderRadius.all(
                                Radius.elliptical(23, 28),
                              ),
                              border: Border.all(color: colors.paper, width: 2),
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: MemoryOrganicPainter(
                          seed: seed,
                          fill: fill,
                          shadow: colors.shadow,
                        ),
                        foregroundPainter: MemoryOrganicPainter(
                          seed: seed,
                          fill: fill,
                          shadow: colors.shadow,
                          rim: colors.paper.withValues(
                            alpha: isDark ? .35 : .85,
                          ),
                        ),
                        child: ClipPath(
                          clipper: MemoryOrganicClipper(seed),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (photo != null)
                                photo!
                              else
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final fontSize = constraints.maxWidth < 155
                                        ? 13.0
                                        : 15.0;
                                    final lineHeight =
                                        MediaQuery.textScalerOf(
                                          context,
                                        ).scale(fontSize) *
                                        1.65;
                                    final lines =
                                        (constraints.maxHeight *
                                                .57 /
                                                lineHeight)
                                            .floor()
                                            .clamp(1, 5);
                                    return Stack(
                                      children: [
                                        Positioned(
                                          top: constraints.maxHeight * .05,
                                          left: constraints.maxWidth * .17,
                                          child: Text(
                                            '“',
                                            textScaler: TextScaler.noScaling,
                                            style: TextStyle(
                                              fontSize: 49,
                                              fontWeight: FontWeight.w300,
                                              color: colors.accent.withValues(
                                                alpha: .25,
                                              ),
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  constraints.maxWidth * .17,
                                              vertical:
                                                  constraints.maxHeight * .2,
                                            ),
                                            child: excerpt.trim().isEmpty
                                                ? Icon(
                                                    Icons.edit_note_rounded,
                                                    color: colors.accent
                                                        .withValues(alpha: .65),
                                                    size: 32,
                                                  )
                                                : Text(
                                                    excerpt,
                                                    maxLines: lines,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: fontSize,
                                                      height: 1.65,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      color: colors.ink,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    stops: const [0, .28, .70, 1],
                                    colors: [
                                      colors.paper.withValues(
                                        alpha: photo == null ? .22 : .18,
                                      ),
                                      Colors.transparent,
                                      Colors.transparent,
                                      const Color(
                                        0xff263c2d,
                                      ).withValues(alpha: isDark ? .20 : .11),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 7,
                runSpacing: 4,
                children: [
                  Text(
                    dateLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: colors.ink,
                    ),
                  ),
                  if (entryCount > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.sage.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers_outlined,
                            size: 12,
                            color: colors.muted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$entryCount',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemoryBubbleField extends StatelessWidget {
  const MemoryBubbleField({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: _MemoryFieldLayout(
        largeText: MediaQuery.textScalerOf(context).scale(14) > 18.2,
        children: children,
      ),
    ),
  );
}

class _MemoryFieldLayout extends MultiChildRenderObjectWidget {
  const _MemoryFieldLayout({required this.largeText, required super.children});
  final bool largeText;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMemoryField(largeText);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMemoryField renderObject,
  ) {
    renderObject.largeText = largeText;
  }
}

class _MemoryFieldParentData extends ContainerBoxParentData<RenderBox> {}

/// Measures the actual date/excerpt layout before positioning the next group.
/// A five-node rhythm (two staggered pairs, then one drifting larger object)
/// leaves deliberate breathing room while guaranteeing disjoint hit regions.
class _RenderMemoryField extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MemoryFieldParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MemoryFieldParentData> {
  _RenderMemoryField(this._largeText);
  bool _largeText;

  set largeText(bool value) {
    if (value == _largeText) return;
    _largeText = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MemoryFieldParentData) {
      child.parentData = _MemoryFieldParentData();
    }
  }

  Size _compose(BoxConstraints constraints, {required bool dry}) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : 360.0;
    final single = width < 330 || _largeText;
    var child = firstChild;
    var index = 0;
    var bottom = 0.0;

    Size measure(RenderBox node, double nodeWidth) {
      final childConstraints = BoxConstraints.tightFor(width: nodeWidth);
      if (dry) return node.getDryLayout(childConstraints);
      node.layout(childConstraints, parentUsesSize: true);
      return node.size;
    }

    void place(RenderBox node, double x, double y) {
      if (!dry) {
        (node.parentData! as _MemoryFieldParentData).offset = Offset(x, y);
      }
    }

    while (child != null) {
      final node = child;
      final data = node.parentData! as _MemoryFieldParentData;
      final top = bottom + (index == 0 ? 10 : 24);
      if (single || index % 5 == 4 || data.nextSibling == null) {
        final fraction = single
            ? (_largeText ? .92 : .78 + (index % 3) * .06)
            : .63;
        final nodeWidth = math.min(
          width * fraction,
          _largeText ? 380.0 : 300.0,
        );
        final measured = measure(node, nodeWidth);
        final drift = switch (index % 3) {
          0 => .12,
          1 => .88,
          _ => .45,
        };
        place(node, (width - nodeWidth) * drift, top);
        bottom = top + measured.height;
        child = data.nextSibling;
        index++;
      } else {
        final second = data.nextSibling!;
        final secondData = second.parentData! as _MemoryFieldParentData;
        final reverse = index % 5 == 2;
        final firstWidth = width * (reverse ? .40 : .52);
        final secondWidth = width * (reverse ? .51 : .39);
        final firstSize = measure(node, firstWidth);
        final secondSize = measure(second, secondWidth);
        final stagger = width * (reverse ? .14 : .22);
        place(node, reverse ? width - firstWidth : 0, top);
        place(second, reverse ? 0 : width - secondWidth, top + stagger);
        bottom = math.max(
          top + firstSize.height,
          top + stagger + secondSize.height,
        );
        child = secondData.nextSibling;
        index += 2;
      }
    }
    return constraints.constrain(
      Size(width, childCount == 0 ? 0 : bottom + 18),
    );
  }

  @override
  void performLayout() {
    size = _compose(constraints, dry: false);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _compose(constraints, dry: true);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
