import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Family name registered in pubspec.yaml for the handwritten marker face.
const String kMarkerFont = 'Marker';

const Color _kBoardTop = Color(0xFF17417F);
const Color _kBoardBottom = Color(0xFF071B3D);
const Color _kTileBorder = Color(0xFF9FD0F0);
const Color _kTileBorderGrey = Color(0xFF4A5C72);
const Color _kPaper = Color(0xFFF2EFE6);
const Color _kInk = Color(0xFF16181C);

/// One labelled column of hero portraits on the board (e.g. "TANKS", 3 wide).
class BoardColumn {
  const BoardColumn({
    required this.label,
    required this.heroes,
    required this.tilesPerRow,
  });

  final String label;
  final List<String> heroes;
  final int tilesPerRow;

  int get rowCount => (heroes.length / tilesPerRow).ceil();
}

/// A whiteboard-style roster: portraits laid out in role columns, tapped to
/// bring them into full colour as complete.
class HeroBoard extends StatelessWidget {
  const HeroBoard({
    super.key,
    required this.title,
    required this.columns,
    required this.completedHeroes,
    required this.onToggleHero,
    required this.assetPathFor,
    this.topInset = 0,
  });

  final String title;
  final List<BoardColumn> columns;
  final Set<String> completedHeroes;
  final void Function(String hero) onToggleHero;
  final String Function(String hero) assetPathFor;

  /// Space reserved at the top for the floating app bar.
  final double topInset;

  static const double _tileGap = 8;
  static const double _columnGap = 26;
  static const double _horizontalPadding = 20;
  static const double _labelHeight = 46;
  static const double _minTile = 44;
  static const double _maxTile = 132;

  /// Below this width the three role columns stop fitting side by side.
  static const double _stackBreakpoint = 720;

  @override
  Widget build(BuildContext context) {
    final allHeroes = [for (final column in columns) ...column.heroes];
    final doneCount = allHeroes.where(completedHeroes.contains).length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBoardTop, _kBoardBottom],
        ),
      ),
      child: CustomPaint(
        painter: _BlueprintPainter(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bannerHeight = _bannerHeightFor(constraints.maxWidth);

            return Column(
              children: [
                SizedBox(height: topInset),
                _PaperBanner(
                  title: title,
                  doneCount: doneCount,
                  totalCount: allHeroes.length,
                  width: math.min(constraints.maxWidth - 32, 760),
                  height: bannerHeight,
                ),
                const SizedBox(height: 26),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _horizontalPadding,
                        0,
                        _horizontalPadding,
                        24,
                      ),
                      child: constraints.maxWidth < _stackBreakpoint
                          ? _buildStacked(constraints.maxWidth)
                          : _buildSideBySide(
                              constraints,
                              topInset + bannerHeight + 26,
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Roles beside each other, sized so the whole roster fits the viewport.
  Widget _buildSideBySide(BoxConstraints constraints, double headerBlock) {
    final totalTiles = columns.fold<int>(
      0,
      (sum, column) => sum + column.tilesPerRow,
    );
    final innerGaps = columns.fold<int>(
      0,
      (sum, column) => sum + column.tilesPerRow - 1,
    );
    final widthForTiles = constraints.maxWidth -
        (_horizontalPadding * 2) -
        (_columnGap * (columns.length - 1)) -
        (_tileGap * innerGaps);
    final tileFromWidth = widthForTiles / totalTiles;

    final maxRows =
        columns.map((column) => column.rowCount).fold<int>(1, math.max);
    final heightForTiles = constraints.maxHeight -
        headerBlock -
        _labelHeight -
        24 -
        (_tileGap * (maxRows - 1));
    final tileFromHeight = heightForTiles / maxRows;

    final tileSize = math
        .min(tileFromWidth, tileFromHeight)
        .clamp(_minTile, _maxTile)
        .toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (i > 0) const SizedBox(width: _columnGap),
          _buildColumn(columns[i], tileSize),
        ],
      ],
    );
  }

  /// Too narrow for three columns, so each role gets the full width in turn
  /// and the board scrolls.
  Widget _buildStacked(double maxWidth) {
    const targetTile = 76.0;
    final available = maxWidth - (_horizontalPadding * 2);
    final tilesPerRow =
        ((available + _tileGap) / (targetTile + _tileGap)).floor().clamp(3, 8);
    final tileSize = ((available - (_tileGap * (tilesPerRow - 1))) / tilesPerRow)
        .clamp(_minTile, _maxTile)
        .toDouble();

    return Column(
      children: [
        for (final column in columns)
          _buildColumn(
            BoardColumn(
              label: column.label,
              heroes: column.heroes,
              tilesPerRow: tilesPerRow,
            ),
            tileSize,
          ),
      ],
    );
  }

  double _bannerHeightFor(double width) => width < 620 ? 74 : 92;

  Widget _buildColumn(BoardColumn column, double tileSize) {
    final width =
        (tileSize * column.tilesPerRow) + (_tileGap * (column.tilesPerRow - 1));

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: _labelHeight,
            child: Center(
              child: Transform.rotate(
                angle: -0.018,
                child: FittedBox(
                  child: Text(
                    column.label,
                    style: const TextStyle(
                      fontFamily: kMarkerFont,
                      fontSize: 30,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Wrap(
            spacing: _tileGap,
            runSpacing: _tileGap,
            alignment: WrapAlignment.center,
            children: [
              for (final hero in column.heroes)
                _HeroTile(
                  hero: hero,
                  assetPath: assetPathFor(hero),
                  isComplete: completedHeroes.contains(hero),
                  size: tileSize,
                  onTap: () => onToggleHero(hero),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTile extends StatefulWidget {
  const _HeroTile({
    required this.hero,
    required this.assetPath,
    required this.isComplete,
    required this.size,
    required this.onTap,
  });

  final String hero;
  final String assetPath;
  final bool isComplete;
  final double size;
  final VoidCallback onTap;

  @override
  State<_HeroTile> createState() => _HeroTileState();
}

class _HeroTileState extends State<_HeroTile> {
  bool _hovered = false;

  /// Colour matrix taking a portrait to "still to do" as [t] goes 0 -> 1:
  /// drained of colour, dimmed, and with its blacks lifted so it still reads as
  /// grey rather than sinking into the dark board behind it.
  List<double> _fadeToGrey(double t) {
    const lumR = 0.2126;
    const lumG = 0.7152;
    const lumB = 0.0722;
    final s = 1 - t;
    final dim = 1 - (0.34 * t);
    final lift = 26.0 * t;
    return [
      (lumR * (1 - s) + s) * dim, lumG * (1 - s) * dim, lumB * (1 - s) * dim, 0, lift, //
      lumR * (1 - s) * dim, (lumG * (1 - s) + s) * dim, lumB * (1 - s) * dim, 0, lift, //
      lumR * (1 - s) * dim, lumG * (1 - s) * dim, (lumB * (1 - s) + s) * dim, 0, lift, //
      0, 0, 0, 1, 0, //
    ];
  }

  @override
  Widget build(BuildContext context) {
    final grey = widget.isComplete ? 0.0 : 1.0;
    final radius = BorderRadius.circular(widget.size * 0.13);

    return Tooltip(
      message: widget.hero,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hovered ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: grey, end: grey),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              builder: (context, t, _) {
                return Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: Color.lerp(_kTileBorder, _kTileBorderGrey, t)!,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.38 - (0.2 * t)),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(_fadeToGrey(t)),
                      child: Image.asset(
                        widget.assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _FallbackPortrait(hero: widget.hero),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackPortrait extends StatelessWidget {
  const _FallbackPortrait({required this.hero});

  final String hero;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF24456F),
      child: Center(
        child: Text(
          hero.substring(0, 1),
          style: const TextStyle(
            fontFamily: kMarkerFont,
            color: Colors.white,
            fontSize: 26,
          ),
        ),
      ),
    );
  }
}

/// The torn strip of paper across the top, carrying the title and the tally.
class _PaperBanner extends StatelessWidget {
  const _PaperBanner({
    required this.title,
    required this.doneCount,
    required this.totalCount,
    required this.width,
    required this.height,
  });

  final String title;
  final int doneCount;
  final int totalCount;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final titleSize = height * 0.46;

    return Transform.rotate(
      angle: -0.012,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _TornPaperPainter(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: kMarkerFont,
                        fontSize: titleSize,
                        color: _kInk,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: width * 0.04),
                Transform.rotate(
                  angle: 0.03,
                  child: Text(
                    '$doneCount/$totalCount',
                    style: TextStyle(
                      fontFamily: kMarkerFont,
                      fontSize: titleSize * 0.72,
                      color: const Color(0xFFB4530C),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Deterministic 0..1 jitter so the torn edges look random but never move.
double _noise(int i) {
  final v = math.sin(i * 127.1) * 43758.5453;
  return v - v.floorToDouble();
}

class _TornPaperPainter extends CustomPainter {
  static const double _amplitude = 5;
  static const int _steps = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final stepX = size.width / _steps;

    path.moveTo(0, _amplitude * _noise(0));
    for (var i = 1; i <= _steps; i++) {
      path.lineTo(stepX * i, _amplitude * _noise(i));
    }
    path.lineTo(size.width - (_amplitude * 0.6), size.height * 0.5);
    for (var i = _steps; i >= 0; i--) {
      path.lineTo(
        stepX * i,
        size.height - (_amplitude * _noise(i + 40)),
      );
    }
    path.lineTo(_amplitude * 0.6, size.height * 0.5);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(path, Paint()..color = _kPaper);
  }

  @override
  bool shouldRepaint(covariant _TornPaperPainter oldDelegate) => false;
}

/// Deep blue background with the faint graph-paper grid and centre glow.
class _BlueprintPainter extends CustomPainter {
  static const double _cell = 46;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.55),
          radius: size.shortestSide * 0.7,
        ),
      );
    canvas.drawRect(Offset.zero & size, glow);

    final minor = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1.4;

    var index = 0;
    for (var x = 0.0; x <= size.width; x += _cell, index++) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        index % 4 == 0 ? major : minor,
      );
    }
    index = 0;
    for (var y = 0.0; y <= size.height; y += _cell, index++) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        index % 4 == 0 ? major : minor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintPainter oldDelegate) => false;
}
