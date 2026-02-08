import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../models/node_model.dart';
import '../theme/app_colors.dart';

class ChartEnginePainter extends CustomPainter {
  final String chartType;
  final NodeModel? data;
  final Color primaryColor;
  final Color secondaryColor;
  final bool showLabels;
  final Offset? hoverPosition;
  final String? sunburstRoot;
  final Map<String, double> visualSettings;
  final int? selectedRowIndex;
  final Map<String, Offset>? dynamicNodePositions;
  final bool showStats;
  final bool showTrend;
  final Color labelColor;
  final Color borderColor;
  final Color glowColor;
  final bool isDark;

  ChartEnginePainter({
    required this.chartType,
    this.data,
    this.primaryColor = MountMapColors.teal,
    this.secondaryColor = MountMapColors.violet,
    this.showLabels = true,
    this.hoverPosition,
    this.sunburstRoot,
    required this.visualSettings,
    this.selectedRowIndex,
    this.dynamicNodePositions,
    this.showStats = false,
    this.showTrend = false,
    this.labelColor = Colors.white70,
    this.borderColor = Colors.white10,
    this.glowColor = Colors.transparent,
    this.isDark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data == null || data!.tableData == null) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final table = data!.tableData!;
    if (table.length < 2) {
      _drawPlaceholder(canvas, size, "Not enough data");
      canvas.restore();
      return;
    }

    try {
      switch (chartType.toLowerCase()) {
        case 'alluvial diagram':
          _drawAlluvial(canvas, size, table);
          break;
        case 'butterfly chart':
          _drawButterfly(canvas, size, table);
          break;
        case 'chord diagram':
          _drawChord(canvas, size, table);
          break;
        case 'contour plot':
          _drawContour(canvas, size, table);
          break;
        case 'histogram':
          _drawHistogram(canvas, size, table);
          break;
        case 'hyperbolic tree':
          _drawHyperbolicTree(canvas, size, table);
          break;
        case 'multi-level pie chart':
          _drawMultiLevelPie(canvas, size, table);
          break;
        case 'pareto chart':
          _drawPareto(canvas, size, table);
          break;
        case 'radial bar chart':
          _drawRadialBar(canvas, size, table);
          break;
        case 'taylor diagram':
          _drawTaylor(canvas, size, table);
          break;
        case 'treemap':
          _drawTreemap(canvas, size, table);
          break;
        case 'three-dimensional stream graph':
          _drawStreamGraph(canvas, size, table);
          break;
        case 'sankey diagram':
          _drawSankey(canvas, size, table);
          break;
        case 'rose chart':
          _drawRose(canvas, size, table);
          break;
        case 'data table':
          _drawDataTable(canvas, size, table);
          break;
        default:
          _drawPlaceholder(canvas, size, "Visualizer for $chartType not implemented");
      }
    } catch (e) {
      _drawPlaceholder(canvas, size, "Error rendering chart: $e");
    } finally {
      canvas.restore();
    }
  }

  void _drawPlaceholder(Canvas canvas, Size size, String message) {
    final tp = TextPainter(
      text: TextSpan(text: message, style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 14)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2));
  }

  // 1. ALLUVIAL DIAGRAM (HYPER-PROFESSIONAL N-LEVEL VERSION)
  void _drawAlluvial(Canvas canvas, Size size, List<List<String>> table) {
    final Map<String, double> nodeTotalIn = {};
    final Map<String, double> nodeTotalOut = {};
    final List<Map<String, dynamic>> connections = [];
    final Set<String> allNodes = {};

    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      String src = table[i][0];
      String tgt = table[i][1];
      double val = double.tryParse(table[i][2]) ?? 0;
      if (val <= 0) continue;

      connections.add({'src': src, 'tgt': tgt, 'val': val, 'index': i});
      nodeTotalOut[src] = (nodeTotalOut[src] ?? 0) + val;
      nodeTotalIn[tgt] = (nodeTotalIn[tgt] ?? 0) + val;
      allNodes.add(src);
      allNodes.add(tgt);
    }

    if (connections.isEmpty) return;

    // Detect Levels
    Map<String, int> nodeLevels = {};
    for (var node in allNodes) {
      _calculateNodeLevel(node, connections, nodeLevels);
    }

    int maxLevel = nodeLevels.values.fold(0, math.max);
    Map<int, List<String>> levelGroups = {};
    for (int l = 0; l <= maxLevel; l++) {
      levelGroups[l] = allNodes.where((n) => nodeLevels[n] == l).toList();
    }

    double paddingX = 80;
    double columnWidth = maxLevel > 0 ? math.max(0, (size.width - paddingX * 2) / maxLevel) : 0;
    double verticalPadding = 40;
    double chartHeight = math.max(0, size.height - (verticalPadding * 2));

    // Calculate Node Geometry
    Map<String, Rect> nodeRects = {};
    Map<int, double> levelTotals = {};

    double nodeThickness = visualSettings['thickness'] ?? 24.0;
    levelGroups.forEach((lvl, nodes) {
      double total = nodes.fold(0.0, (sum, n) => sum + math.max(nodeTotalIn[n] ?? 0, nodeTotalOut[n] ?? 0));
      levelTotals[lvl] = total;

      double totalVal = levelTotals[lvl] ?? 0;
      int nodeCount = nodes.length;
      double availableForGaps = chartHeight * 0.2;
      double gap = nodeCount > 1 ? availableForGaps / (nodeCount - 1) : 0;

      double currentY = verticalPadding;
      for (var n in nodes) {
        double val = math.max(nodeTotalIn[n] ?? 0, nodeTotalOut[n] ?? 0);
        double h = totalVal > 0 ? (val / totalVal) * (chartHeight * 0.8) : (nodes.isEmpty ? 0 : chartHeight / nodes.length);
        nodeRects[n] = Rect.fromLTWH(paddingX + lvl * columnWidth - (lvl == 0 ? 0 : (lvl == maxLevel ? nodeThickness : nodeThickness/2)), currentY, nodeThickness, h);
        currentY += h + gap;
      }
    });

    // Draw Flows
    final Map<String, double> currentOutOffset = {};
    final Map<String, double> currentInOffset = {};
    final paint = Paint()..style = PaintingStyle.fill;

    double flowOpacity = visualSettings['opacity'] ?? 0.3;
    double curvature = visualSettings['smoothing'] ?? 0.4;

    for (var conn in connections) {
      String src = conn['src'];
      String tgt = conn['tgt'];
      double val = conn['val'];
      final bool isSelected = selectedRowIndex == conn['index'];

      Rect? srcRect = nodeRects[src];
      Rect? tgtRect = nodeRects[tgt];
      if (srcRect == null || tgtRect == null) continue;

      double srcTotal = nodeTotalOut[src] ?? 0;
      double tgtTotal = nodeTotalIn[tgt] ?? 0;
      if (srcTotal == 0 || tgtTotal == 0) continue;

      double h1 = (val / srcTotal) * srcRect.height;
      double h2 = (val / tgtTotal) * tgtRect.height;

      double y1 = srcRect.top + (currentOutOffset[src] ?? 0);
      double y2 = tgtRect.top + (currentInOffset[tgt] ?? 0);

      currentOutOffset[src] = (currentOutOffset[src] ?? 0) + h1;
      currentInOffset[tgt] = (currentInOffset[tgt] ?? 0) + h2;

      final path = Path();
      path.moveTo(srcRect.right, y1);
      path.cubicTo(
        srcRect.right + columnWidth * curvature, y1,
        tgtRect.left - columnWidth * curvature, y2,
        tgtRect.left, y2
      );
      path.lineTo(tgtRect.left, y2 + h2);
      path.cubicTo(
        tgtRect.left - columnWidth * curvature, y2 + h2,
        srcRect.right + columnWidth * curvature, y1 + h1,
        srcRect.right, y1 + h1
      );
      path.close();

      bool isHovered = false;
      if (hoverPosition != null && path.contains(hoverPosition!)) {
        isHovered = true;
      }

      paint.shader = ui.Gradient.linear(
        srcRect.centerRight, tgtRect.centerLeft,
        [
          (isHovered || isSelected ? Colors.amberAccent : primaryColor.withValues(alpha: flowOpacity)),
          (isHovered || isSelected ? Colors.amberAccent : secondaryColor.withValues(alpha: flowOpacity))
        ]
      );
      canvas.drawPath(path, paint);

      // Particles for Alluvial
      if (isHovered || isSelected || (visualSettings['intensity'] ?? 0.0) > 0.6) {
        final pPaint = Paint()..color = Colors.white.withValues(alpha: 0.5)..style = PaintingStyle.fill;
        double time = DateTime.now().millisecondsSinceEpoch / 2000.0;
        for (int i = 0; i < 2; i++) {
          double t = (time + i * 0.5) % 1.0;
          Offset pos = _getPointOnCubic(
            srcRect.centerRight + Offset(0, y1 + h1/2 - srcRect.center.dy),
            srcRect.centerRight + Offset(columnWidth * curvature, y1 + h1/2 - srcRect.center.dy),
            tgtRect.centerLeft - Offset(columnWidth * curvature, y2 + h2/2 - tgtRect.center.dy),
            tgtRect.centerLeft + Offset(0, y2 + h2/2 - tgtRect.center.dy),
            t
          );
          canvas.drawCircle(pos, 1.5, pPaint);
        }
      }

      if (isSelected) {
        final hp = Paint()..color = Colors.amberAccent..style = PaintingStyle.stroke..strokeWidth = 2;
        canvas.drawPath(path, hp);
      }

      if (isHovered && showLabels) {
        _drawText(canvas, "${conn['src']} → ${conn['tgt']}: ${val.toStringAsFixed(0)}", hoverPosition! + const Offset(10, -10), Colors.white, false);
      }
    }

    // Draw Nodes
    paint.shader = null;
    nodeRects.forEach((name, rect) {
      int lvl = nodeLevels[name] ?? 0;
      paint.color = Color.lerp(primaryColor, secondaryColor, lvl / (maxLevel + 1))!;

      _applyEffects(canvas, RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);

      if (showLabels) {
        bool isLast = lvl == maxLevel;
        _drawText(
          canvas, name,
          isLast ? rect.centerRight + const Offset(10, 0) : rect.centerLeft - const Offset(10, 0),
          Colors.white, false, alignRight: !isLast
        );
        _drawText(canvas, (math.max(nodeTotalIn[name] ?? 0, nodeTotalOut[name] ?? 0)).toStringAsFixed(0), rect.bottomCenter + const Offset(0, 5), Colors.white38, true);
      }
    });
  }

  int _calculateNodeLevel(String node, List<Map<String, dynamic>> connections, Map<String, int> cache, [Set<String>? visited, int depth = 0]) {
    if (cache.containsKey(node)) return cache[node] ?? 0;

    if (depth > 64) {
      cache[node] = 0;
      return 0;
    }

    visited ??= {};
    if (visited.contains(node)) return 0;
    visited.add(node);

    int maxLevel = 0;
    for (var conn in connections) {
      if (conn['tgt'] == node) {
        // Avoid self-loops
        if (conn['src'] != node) {
          maxLevel = math.max(maxLevel, _calculateNodeLevel(conn['src'], connections, cache, visited, depth + 1) + 1);
        }
      }
    }

    visited.remove(node);
    cache[node] = maxLevel;
    return maxLevel;
  }

  // 2. BUTTERFLY CHART (MASTERPIECE VERSION)
  void _drawButterfly(Canvas canvas, Size size, List<List<String>> table) {
    double maxVal = 0;
    double sumL = 0, sumR = 0;
    List<double> lefts = [], rights = [];

    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      double l = double.tryParse(table[i][1]) ?? 0;
      double r = double.tryParse(table[i][2]) ?? 0;
      lefts.add(l); rights.add(r);
      maxVal = math.max(maxVal, math.max(l, r));
      sumL += l; sumR += r;
    }
    if (lefts.isEmpty) return;
    if (maxVal == 0) maxVal = 1;

    double barHeight = visualSettings['thickness'] ?? 20.0;
    double labelWidth = visualSettings['gap'] ?? 100.0;

    double center = size.width / 2;
    double sideWidth = math.max(0, (size.width - labelWidth) / 2 - 20);
    double spacing = (size.height - 150) / (lefts.length + 1);
    spacing = spacing.clamp(10, 40);
    double startY = 80;

    final trendPaintL = Paint()..color = primaryColor.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 2;
    final trendPaintR = Paint()..color = secondaryColor.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 2;

    // Draw Radial Background (Professional depth)
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = ui.Gradient.radial(Offset(center, size.height/2), size.width/2, [Colors.white.withValues(alpha: 0.02), Colors.transparent]));

    // Headers & Stats
    if (table[0].length >= 3) {
      _drawText(canvas, table[0][1].toUpperCase(), Offset(center - labelWidth / 2 - sideWidth / 2, 40), primaryColor, true);
      _drawText(canvas, "AVG: ${(sumL / lefts.length).toStringAsFixed(1)}", Offset(center - labelWidth / 2 - sideWidth / 2, 55), primaryColor.withValues(alpha: 0.5), true);

      _drawText(canvas, table[0][2].toUpperCase(), Offset(center + labelWidth / 2 + sideWidth / 2, 40), secondaryColor, true);
      _drawText(canvas, "AVG: ${(sumR / rights.length).toStringAsFixed(1)}", Offset(center + labelWidth / 2 + sideWidth / 2, 55), secondaryColor.withValues(alpha: 0.5), true);
    }

    final pathL = Path();
    final pathR = Path();

    for (int i = 0; i < lefts.length; i++) {
      double l = lefts[i], r = rights[i];
      double lw = (l / maxVal) * sideWidth;
      double rw = (r / maxVal) * sideWidth;
      double y = startY + i * (barHeight + spacing);

      // Trendline paths
      if (i == 0) {
        pathL.moveTo(center - labelWidth/2 - lw, y + barHeight/2);
        pathR.moveTo(center + labelWidth/2 + rw, y + barHeight/2);
      } else {
        pathL.lineTo(center - labelWidth/2 - lw, y + barHeight/2);
        pathR.lineTo(center + labelWidth/2 + rw, y + barHeight/2);
      }

      final bool isSelected = selectedRowIndex == i + 1;

      // Left Bar (Professional Shader)
      final rectL = Rect.fromLTWH(center - labelWidth/2 - lw, y, lw, barHeight);
      _applyEffects(canvas, RRect.fromRectAndCorners(rectL, topLeft: const Radius.circular(4), bottomLeft: const Radius.circular(4)), Paint()..shader = ui.Gradient.linear(rectL.centerRight, rectL.centerLeft, [primaryColor, primaryColor.withValues(alpha: 0.2)]));

      // Right Bar (Professional Shader)
      final rectR = Rect.fromLTWH(center + labelWidth/2, y, rw, barHeight);
      _applyEffects(canvas, RRect.fromRectAndCorners(rectR, topRight: const Radius.circular(4), bottomRight: const Radius.circular(4)), Paint()..shader = ui.Gradient.linear(rectR.centerLeft, rectR.centerRight, [secondaryColor, secondaryColor.withValues(alpha: 0.2)]));

      if (isSelected) {
        final highlightPaint = Paint()
          ..color = Colors.amberAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRRect(RRect.fromRectAndCorners(rectL.inflate(2), topLeft: const Radius.circular(6), bottomLeft: const Radius.circular(6)), highlightPaint);
        canvas.drawRRect(RRect.fromRectAndCorners(rectR.inflate(2), topRight: const Radius.circular(6), bottomRight: const Radius.circular(6)), highlightPaint);
      }

      // Category Label with background pill
      final labelRect = Rect.fromCenter(center: Offset(center, y + barHeight/2), width: labelWidth - 10, height: barHeight + 4);
      canvas.drawRRect(RRect.fromRectAndRadius(labelRect, const Radius.circular(20)), Paint()..color = Colors.white.withValues(alpha: 0.05));
      _drawText(canvas, table[i+1][0], Offset(center, y + barHeight/2), Colors.white, true);

      if (showLabels) {
        _drawText(canvas, l.toStringAsFixed(0), Offset(center - labelWidth/2 - lw - 10, y + barHeight/2), Colors.white70, false, alignRight: true);
        _drawText(canvas, r.toStringAsFixed(0), Offset(center + labelWidth/2 + rw + 10, y + barHeight/2), Colors.white70, false);
      }
    }

    // Draw Smooth Trendlines
    canvas.drawPath(pathL, trendPaintL);
    canvas.drawPath(pathR, trendPaintR);

    // Median markers
    lefts.sort(); rights.sort();
    double medL = lefts[lefts.length~/2];
    double medR = rights[rights.length~/2];
    double medLx = center - labelWidth/2 - (medL/maxVal)*sideWidth;
    double medRx = center + labelWidth/2 + (medR/maxVal)*sideWidth;

    canvas.drawLine(Offset(medLx, startY - 10), Offset(medLx, startY + lefts.length * (barHeight + spacing)), Paint()..color = primaryColor.withValues(alpha: 0.5)..strokeWidth = 1..style = PaintingStyle.stroke);
    canvas.drawLine(Offset(medRx, startY - 10), Offset(medRx, startY + rights.length * (barHeight + spacing)), Paint()..color = secondaryColor.withValues(alpha: 0.5)..strokeWidth = 1..style = PaintingStyle.stroke);
  }

  // 3. CHORD DIAGRAM (HIGH-FIDELITY TRUE RIBBONS)
  void _drawChord(Canvas canvas, Size size, List<List<String>> table) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = math.min(size.width, size.height) * 0.38;

    double ringWidth = visualSettings['thickness'] ?? 12.0;
    double gap = visualSettings['gap'] ?? 0.08;

    double innerRadius = radius - ringWidth;

    final Map<String, double> nodeTotals = {};
    final List<Map<String, dynamic>> flows = [];

    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      String src = table[i][0], tgt = table[i][1];
      double val = double.tryParse(table[i][2]) ?? 0;
      if (val <= 0) continue;
      flows.add({'src': src, 'tgt': tgt, 'val': val});
      nodeTotals[src] = (nodeTotals[src] ?? 0) + val;
      nodeTotals[tgt] = (nodeTotals[tgt] ?? 0) + val;
    }

    if (nodeTotals.isEmpty) return;
    double totalVal = nodeTotals.values.fold(0, (sum, v) => sum + v);

    final sortedNames = nodeTotals.keys.toList()..sort();
    final Map<String, double> nodeStartAngles = {};
    double currentAngle = 0;
    double availableAngle = math.max(0, 2 * math.pi - (sortedNames.length * gap));

    // Draw Outer Segments
    for (var name in sortedNames) {
      double nodeTotal = nodeTotals[name] ?? 0;
      double sweep = totalVal > 0 ? (nodeTotal / totalVal) * availableAngle : 0;
      nodeStartAngles[name] = currentAngle;

      final rect = Rect.fromCircle(center: center, radius: radius);
      final segmentPaint = Paint()
        ..shader = ui.Gradient.sweep(center, [primaryColor, secondaryColor, primaryColor], [0, 0.5, 1])
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, currentAngle, sweep, false, segmentPaint);

      if (showLabels) {
        double midAngle = currentAngle + sweep/2;
        Offset labelPos = center + Offset(math.cos(midAngle) * (radius + 25), math.sin(midAngle) * (radius + 25));
        _drawText(canvas, name, labelPos, Colors.white, true);
      }
      currentAngle += sweep + gap;
    }

    // Draw True Ribbons (Asymmetric end widths)
    final Map<String, double> currentOutOffset = {};
    final Map<String, double> currentInOffset = {};

    for (var flow in flows) {
      String src = flow['src'], tgt = flow['tgt'];
      double val = flow['val'];

      double sStart = (nodeStartAngles[src] ?? 0) + (currentOutOffset[src] ?? 0);
      double sSweep = totalVal > 0 ? (val / totalVal) * availableAngle : 0;
      currentOutOffset[src] = (currentOutOffset[src] ?? 0) + sSweep;

      double tStart = (nodeStartAngles[tgt] ?? 0) + (currentInOffset[tgt] ?? 0);
      double tSweep = totalVal > 0 ? (val / totalVal) * availableAngle : 0;
      currentInOffset[tgt] = (currentInOffset[tgt] ?? 0) + tSweep;

      final path = Path();
      Offset s1 = center + Offset(math.cos(sStart) * innerRadius, math.sin(sStart) * innerRadius);
      Offset s2 = center + Offset(math.cos(sStart + sSweep) * innerRadius, math.sin(sStart + sSweep) * innerRadius);
      Offset t1 = center + Offset(math.cos(tStart) * innerRadius, math.sin(tStart) * innerRadius);
      Offset t2 = center + Offset(math.cos(tStart + tSweep) * innerRadius, math.sin(tStart + tSweep) * innerRadius);

      path.moveTo(s1.dx, s1.dy);
      path.arcToPoint(s2, radius: Radius.circular(innerRadius));
      // Flow to target with control points near center (0.2 factor for slight curve)
      path.cubicTo(
        center.dx + (s2.dx - center.dx) * 0.2, center.dy + (s2.dy - center.dy) * 0.2,
        center.dx + (t1.dx - center.dx) * 0.2, center.dy + (t1.dy - center.dy) * 0.2,
        t1.dx, t1.dy
      );
      path.arcToPoint(t2, radius: Radius.circular(innerRadius));
      path.cubicTo(
        center.dx + (t2.dx - center.dx) * 0.2, center.dy + (t2.dy - center.dy) * 0.2,
        center.dx + (s1.dx - center.dx) * 0.2, center.dy + (s1.dy - center.dy) * 0.2,
        s1.dx, s1.dy
      );
      path.close();

      final ribbonPaint = Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          Colors.accents[sortedNames.indexOf(src) % Colors.accents.length].withValues(alpha: 0.4),
          Colors.accents[sortedNames.indexOf(tgt) % Colors.accents.length].withValues(alpha: 0.1),
        ])
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, ribbonPaint);
    }
  }

  // 4. CONTOUR PLOT (SCIENTIFIC MARCHING-SQUARES VERSION)
  void _drawContour(Canvas canvas, Size size, List<List<String>> table) {
    final List<Map<String, double>> points = [];
    double minZ = double.infinity, maxZ = double.negativeInfinity;
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (int i = 1; i < table.length; i++) {
      double x = double.tryParse(table[i][0]) ?? 0, y = double.tryParse(table[i][1]) ?? 0, z = double.tryParse(table[i][2]) ?? 0;
      points.add({'x': x, 'y': y, 'z': z});
      minZ = math.min(minZ, z); maxZ = math.max(maxZ, z);
      minX = math.min(minX, x); maxX = math.max(maxX, x);
      minY = math.min(minY, y); maxY = math.max(maxY, y);
    }
    if (points.isEmpty) return;
    if (minZ == maxZ) maxZ += 1;
    if (minX == maxX) maxX += 1;
    if (minY == maxY) maxY += 1;

    double chartW = math.max(0, size.width - 120);
    double chartH = math.max(0, size.height - 100);
    Offset origin = const Offset(60, 40);

    // 1. Generate Grid Values using IDW
    int resX = math.max(1, (visualSettings['thickness'] ?? 40.0).toInt());
    int resY = math.max(1, (resX * 0.75).toInt());
    double gridDx = chartW / resX, gridDy = chartH / resY;
    List<List<double>> grid = List.generate(resX + 1, (_) => List.filled(resY + 1, 0.0));

    for (int i = 0; i <= resX; i++) {
      for (int j = 0; j <= resY; j++) {
        double vx = minX + (i / resX) * (maxX - minX);
        double vy = minY + (j / resY) * (maxY - minY);
        double wSum = 0, zSum = 0;
        for (var p in points) {
          double px = p['x'] ?? 0;
          double py = p['y'] ?? 0;
          double pz = p['z'] ?? 0;
          double d = math.sqrt(math.pow(vx - px, 2) + math.pow(vy - py, 2));
          double w = 1 / (math.pow(d, 2) + 0.1);
          zSum += pz * w; wSum += w;
        }
        grid[i][j] = zSum / wSum;
      }
    }

    // 2. Draw Heatmap (Professional Gradient)
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < resX; i++) {
      for (int j = 0; j < resY; j++) {
        double avgZ = (grid[i][j] + grid[i+1][j] + grid[i][j+1] + grid[i+1][j+1]) / 4;
        double norm = (maxZ == minZ) ? 0.0 : (avgZ - minZ) / (maxZ - minZ);
        paint.color = Color.lerp(primaryColor.withValues(alpha: 0.05), secondaryColor.withValues(alpha: 0.4), norm.clamp(0, 1))!;
        canvas.drawRect(Rect.fromLTWH(origin.dx + i * gridDx, origin.dy + j * gridDy, gridDx + 0.5, gridDy + 0.5), paint);
      }
    }

    // 3. Draw Vector Isolines (Marching Squares Approximation)
    final linePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1;
    int numIso = 8;
    for (int k = 1; k < numIso; k++) {
      double isoVal = minZ + (k / numIso) * (maxZ - minZ);
      linePaint.color = secondaryColor.withValues(alpha: 0.6);

      for (int i = 0; i < resX; i++) {
        for (int j = 0; j < resY; j++) {
          // Check vertices against threshold
          int config = 0;
          if (grid[i][j] >= isoVal) {
            config |= 8;
          }
          if (grid[i + 1][j] >= isoVal) {
            config |= 4;
          }
          if (grid[i + 1][j + 1] >= isoVal) {
            config |= 2;
          }
          if (grid[i][j + 1] >= isoVal) {
            config |= 1;
          }

          if (config > 0 && config < 15) {
            // Draw lines based on config (Simplified)
            Offset pA = origin + Offset(i * gridDx + gridDx/2, j * gridDy);
            Offset pB = origin + Offset((i+1) * gridDx, j * gridDy + gridDy/2);
            canvas.drawLine(pA, pB, linePaint);
          }
        }
      }
    }

    // 4. Draw Points & Labels
    for (int i = 0; i < points.length; i++) {
      var p = points[i];
      final bool isSelected = selectedRowIndex == i + 1;
      double pxVal = p['x'] ?? 0;
      double pyVal = p['y'] ?? 0;
      double pzVal = p['z'] ?? 0;
      double px = origin.dx + (maxX == minX ? chartW / 2 : ((pxVal - minX) / (maxX - minX)) * chartW);
      double py = origin.dy + (maxY == minY ? chartH / 2 : ((pyVal - minY) / (maxY - minY)) * chartH);
      canvas.drawCircle(Offset(px, py), isSelected ? 7 : 4, Paint()..color = isSelected ? Colors.amberAccent : Colors.white..style = PaintingStyle.fill);
      if (isSelected) {
        canvas.drawCircle(Offset(px, py), 9, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1);
      }
      if (showLabels) _drawText(canvas, pzVal.toStringAsFixed(0), Offset(px, py - 12), Colors.white70, true);
    }

    // Scale Legend
    for (int m = 0; m < 50; m++) {
      paint.color = Color.lerp(primaryColor.withValues(alpha: 0.1), secondaryColor, m / 50)!;
      canvas.drawRect(Rect.fromLTWH(origin.dx + chartW + 25, origin.dy + (1 - m/50) * chartH, 15, chartH/50), paint);
    }
    _drawText(canvas, maxZ.toStringAsFixed(1), Offset(origin.dx + chartW + 45, origin.dy), Colors.white38, false);
    _drawText(canvas, minZ.toStringAsFixed(1), Offset(origin.dx + chartW + 45, origin.dy + chartH), Colors.white38, false);
  }

  // 5. HISTOGRAM (ADVANCED STATISTICAL VERSION)
  void _drawHistogram(Canvas canvas, Size size, List<List<String>> table) {
    int numGroups = table[0].length - 1;
    double barOpacity = visualSettings['opacity'] ?? 0.6;
    double maxVal = 0;
    double sumX = 0, sumX2 = 0;
    int totalN = 0;

    for (int i = 1; i < table.length; i++) {
      for (int g = 1; g <= numGroups; g++) {
        if (table[i].length > g) {
          double v = double.tryParse(table[i][g]) ?? 0;
          maxVal = math.max(maxVal, v);
          sumX += v; sumX2 += v * v; totalN++;
        }
      }
    }
    if (maxVal == 0) maxVal = 1;

    double pL = 60, pB = 50, pT = 40, pR = 30;
    double chartW = size.width - pL - pR, chartH = size.height - pB - pT;

    double barWidthScale = visualSettings['intensity'] ?? 0.8;
    double cornerRadius = visualSettings['radius'] ?? 4.0;

    // Draw Y-Axis and Grid
    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 1;
    for (int j = 0; j <= 5; j++) {
      double y = pT + chartH - (j / 5) * chartH;
      canvas.drawLine(Offset(pL, y), Offset(size.width - pR, y), gridPaint);
      _drawText(canvas, (maxVal * j / 5).toStringAsFixed(0), Offset(pL - 10, y), Colors.white38, false, alignRight: true);
    }

    if (table.length <= 1) return;
    double groupAreaW = chartW / (table.length - 1);
    double barW = numGroups == 0 ? 0 : (groupAreaW * barWidthScale) / numGroups;

    for (int i = 1; i < table.length; i++) {
      double groupX = pL + (i - 1) * groupAreaW + (groupAreaW * (1 - barWidthScale) / 2);
      for (int g = 0; g < numGroups; g++) {
        double val = double.tryParse(table[i][g + 1]) ?? 0;
        double h = maxVal == 0 ? 0 : (val / maxVal) * chartH;
        double x = groupX + g * barW;
        double y = pT + chartH - h;

        final color = Color.lerp(primaryColor, secondaryColor, g / math.max(1, numGroups - 1))!;
        final rect = Rect.fromLTWH(x, y, barW - 2, h);

        final bool isSelected = selectedRowIndex == i;
        final rrect = RRect.fromRectAndCorners(rect, topLeft: Radius.circular(cornerRadius), topRight: Radius.circular(cornerRadius));

        _drawGlossyShape(canvas, rrect, isSelected ? Colors.amberAccent : color, opacity: barOpacity);

        if (isSelected) {
          final glowPaint = Paint()
            ..color = Colors.amberAccent.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
          canvas.drawRRect(rrect, glowPaint);
        }

        if (showLabels && val > 0) {
          _drawText(canvas, val.toStringAsFixed(0), Offset(x + barW / 2, y - 10), Colors.white70, true);
        }
      }
      _drawText(canvas, table[i][0], Offset(groupX + (groupAreaW * 0.4), size.height - 25), Colors.white38, true);
    }

    // Gaussian Bell Curve Overlay (Simplified based on data stats)
    if (totalN > 1) {
      double mean = sumX / totalN;
      double variance = (sumX2 / totalN) - (mean * mean);
      double stdDev = math.sqrt(math.max(0.1, variance));

      final bellPath = Path();
      final bellPaint = Paint()..color = Colors.amber.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 2;

      for (int step = 0; step <= 100; step++) {
        double xNorm = step / 100.0;
        double xVal = mean - 3 * stdDev + xNorm * 6 * stdDev;
        // Normal distribution formula
        double yVal = (1 / (stdDev * math.sqrt(2 * math.pi))) * math.exp(-0.5 * math.pow((xVal - mean) / stdDev, 2));

        double px = pL + (xNorm * chartW);
        double py = pT + chartH - (yVal * chartH * stdDev * 2); // Scaled for visibility

        if (step == 0) bellPath.moveTo(px, py); else bellPath.lineTo(px, py);
      }
      canvas.drawPath(bellPath, bellPaint);
      if (showStats) {
        _drawText(canvas, "MEAN: ${mean.toStringAsFixed(1)} | σ: ${stdDev.toStringAsFixed(1)}", Offset(pL + chartW/2, pT - 15), Colors.amber.withValues(alpha: 0.6), true);
      }
    }

    if (showTrend) {
      _drawHistogramTrend(canvas, chartW, chartH, pL, pT, table, numGroups);
    }
  }

  void _drawHistogramTrend(Canvas canvas, double w, double h, double l, double t, List<List<String>> table, int numGroups) {
    for (int g = 0; g < numGroups; g++) {
      final path = Path();
      double maxV = 0;
      for (int i = 1; i < table.length; i++) {
        maxV = math.max(maxV, double.tryParse(table[i][g+1]) ?? 0);
      }
      if (maxV == 0) maxV = 1;

      double dx = w / (table.length - 1);
      for (int i = 1; i < table.length; i++) {
        double val = double.tryParse(table[i][g+1]) ?? 0;
        double px = l + (i - 1 + 0.5) * dx;
        double py = t + h - (val / maxV) * h;
        if (i == 1) path.moveTo(px, py); else path.lineTo(px, py);
      }
      canvas.drawPath(path, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  // 6. HYPERBOLIC TREE (POINCARÉ DISK MASTERPIECE)
  void _drawHyperbolicTree(Canvas canvas, Size size, List<List<String>> table) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double diskRadius = math.min(size.width, size.height) * 0.45 * (visualSettings['intensity'] ?? 1.0);

    double baseNodeSize = visualSettings['thickness'] ?? 12.0;
    double branchOpacity = visualSettings['opacity'] ?? 0.2;

    // Draw the Disk Boundary
    canvas.drawCircle(center, diskRadius, Paint()..color = Colors.white.withValues(alpha: 0.03)..style = PaintingStyle.fill);
    canvas.drawCircle(center, diskRadius, Paint()..color = Colors.white10..style = PaintingStyle.stroke..strokeWidth = 2);

    final tree = <String, List<String>>{};
    String? root;
    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 2) continue;
      String p = table[i][0], c = table[i][1];
      if (root == null) root = p;
      tree[p] = (tree[p] ?? [])..add(c);
    }
    if (root == null) return;

    Offset getDiskPos(String name, double angle, double r) {
      if (dynamicNodePositions != null && dynamicNodePositions!.containsKey(name)) {
        Offset? raw = dynamicNodePositions![name];
        if (raw == null) return center;
        double rawD = raw.distance;
        double diskD = diskRadius * (rawD / (rawD + 100));
        return center + Offset(raw.dx / (rawD + 0.1) * diskD, raw.dy / (rawD + 0.1) * diskD);
      } else {
        double d = diskRadius * (r / (r + 1.5));
        return center + Offset(math.cos(angle) * d, math.sin(angle) * d);
      }
    }

    // Hyperbolic projection
    void drawHyperNode(String name, double angle, double sweep, double r, int depth) {
      Offset p = getDiskPos(name, angle, r);
      double nodeSize = (baseNodeSize / (r + 1)).clamp(2.0, baseNodeSize);

      bool isSelected = false;
      if (selectedRowIndex != null && selectedRowIndex! < table.length) {
        isSelected = table[selectedRowIndex!][1] == name || (r == 0 && table[selectedRowIndex!][0] == name);
      }

      final children = tree[name] ?? [];
      if (children.isNotEmpty) {
        double childSweep = sweep / children.length;
        for (int i = 0; i < children.length; i++) {
          double childAngle = (angle - sweep/2) + (i + 0.5) * childSweep;
          double childR = r + 1.0;

          Offset cp = getDiskPos(children[i], childAngle, childR);

          // Draw hyperbolic-like arc branch
          final branchPath = Path();
          branchPath.moveTo(p.dx, p.dy);
          // Control point towards center
          Offset ctrl = center + (cp - center) * 0.7;
          branchPath.quadraticBezierTo(ctrl.dx, ctrl.dy, cp.dx, cp.dy);

          canvas.drawPath(branchPath, Paint()..color = primaryColor.withValues(alpha: branchOpacity / (r + 1))..style = PaintingStyle.stroke..strokeWidth = nodeSize/3);

          drawHyperNode(children[i], childAngle, childSweep, childR, depth + 1);
        }
      }

      final color = isSelected ? Colors.amberAccent : Color.lerp(primaryColor, secondaryColor, (depth / 5).clamp(0, 1))!;
      final nodePath = Path()..addOval(Rect.fromCircle(center: p, radius: isSelected ? nodeSize * 1.5 : nodeSize));
      _applyEffects(canvas, nodePath, Paint()..color = color..style = PaintingStyle.fill);

      if (isSelected) {
        canvas.drawCircle(p, nodeSize * 2.0, Paint()..color = Colors.amberAccent.withValues(alpha: 0.2)..style = PaintingStyle.fill);
      }

      if (showLabels && depth < 4) {
        _drawText(canvas, name, p + Offset(0, nodeSize + 8), Colors.white.withValues(alpha: 1/(r+1)), true);
      }
    }

    drawHyperNode(root, 0, 2 * math.pi, 0, 0);
  }

  // 7. MULTI-LEVEL SUNBURST (INFINITE DEPTH MASTERPIECE)
  void _drawMultiLevelPie(Canvas canvas, Size size, List<List<String>> table) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double minDim = math.min(size.width, size.height);
    double baseRadius = (visualSettings['gap'] ?? 50.0).clamp(10, minDim * 0.2);
    double ringThickness = (visualSettings['thickness'] ?? 50.0).clamp(10, minDim * 0.15);

    // Build hierarchy from table [Parent, Child, Value]
    final tree = <String, List<String>>{};
    final values = <String, double>{};
    final Set<String> allNodes = {};
    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      String p = table[i][0], c = table[i][1];
      double v = double.tryParse(table[i][2]) ?? 0;
      tree[p] = (tree[p] ?? [])..add(c);
      values[c] = v;
      allNodes.add(p); allNodes.add(c);
    }

    String root = sunburstRoot ?? (allNodes.firstWhere((n) => !allNodes.any((p) => (tree[p] ?? []).contains(n)), orElse: () => allNodes.first));

    double calculateTotal(String node, [Set<String>? visited, int depth = 0]) {
      if (depth > 32 || (visited?.contains(node) ?? false)) return values[node] ?? 0;
      final children = tree[node] ?? [];
      if (children.isEmpty) return values[node] ?? 0;

      visited ??= {};
      visited.add(node);
      double sum = children.fold(0.0, (s, c) => s + calculateTotal(c, visited, depth + 1));
      visited.remove(node);

      values[node] = sum;
      return sum;
    }
  if (allNodes.isEmpty) return;
    double totalVal = calculateTotal(root);
    if (totalVal == 0) return;

    void drawRing(String node, double startAngle, double sweep, int depth) {
      if (sweep < 0.01 || depth > 16) return;
      double rInner = baseRadius + depth * ringThickness;
      double rOuter = rInner + ringThickness;
      final color = Colors.accents[(node.hashCode).abs() % Colors.accents.length];

      // Draw segment
      double labelDetail = visualSettings['intensity'] ?? 0.8;
      final paint = Paint()..style = PaintingStyle.fill..color = color.withValues(alpha: labelDetail / (depth + 1));

      final double motionScale = (visualSettings['intensity'] ?? 0.0) > 0.6 ? (math.sin(DateTime.now().millisecondsSinceEpoch / 1500 + depth) * 0.02) : 0;
      final path = Path();
      path.arcTo(Rect.fromCircle(center: center, radius: rOuter * (1 + motionScale)), startAngle, sweep, true);
      path.arcTo(Rect.fromCircle(center: center, radius: rInner), startAngle + sweep, -sweep, false);
      path.close();

      _applyEffects(canvas, path, paint);

      if (showLabels && sweep > 0.15) {
        double labelAngle = startAngle + sweep/2;
        Offset labelPos = center + Offset(math.cos(labelAngle) * (rInner + ringThickness/2), math.sin(labelAngle) * (rInner + ringThickness/2));
        _drawText(canvas, node, labelPos, Colors.white, true);
      }

      final children = tree[node] ?? [];
      double currentAngle = startAngle;
      for (var child in children) {
        double childVal = values[child] ?? 0;
        double childSweep = (values[node] ?? 0) == 0 ? 0 : (childVal / (values[node] ?? 1.0)) * sweep;
        drawRing(child, currentAngle, childSweep, depth + 1);
        currentAngle += childSweep;
      }
    }

    drawRing(root, -math.pi/2, 2 * math.pi, 0);

    // Central info
    final centerRect = Rect.fromCircle(center: center, radius: baseRadius);
    _drawGlossyShape(canvas, RRect.fromRectAndRadius(centerRect, Radius.circular(baseRadius)), MountMapColors.darkCard);
    _drawText(canvas, root.toUpperCase(), center - const Offset(0, 10), MountMapColors.teal, true);
    _drawText(canvas, totalVal.toStringAsFixed(0), center + const Offset(0, 10), Colors.white, true);
  }

  // 8. PARETO CHART (ANALYTICAL QC VERSION)
  void _drawPareto(Canvas canvas, Size size, List<List<String>> table) {
    List<Map<String, dynamic>> items = [];
    double total = 0;
    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 2) continue;
      double v = double.tryParse(table[i][1]) ?? 0;
      items.add({'name': table[i][0], 'val': v, 'index': i});
      total += v;
    }
    if (total == 0) return;
    items.sort((a, b) => (b['val'] as double).compareTo(a['val'] as double));

    double pL = 60, pR = 60, pT = 60, pB = 60;
    double chartW = size.width - pL - pR, chartH = size.height - pT - pB;
    double maxBar = items.first['val'];

    double threshold = visualSettings['intensity'] ?? 0.8;

    // Draw Gradient Background Zones
    canvas.drawRect(Rect.fromLTWH(pL, pT, chartW * (1-threshold), chartH), Paint()..color = primaryColor.withValues(alpha: 0.05));
    _drawText(canvas, "VITAL FEW", Offset(pL + chartW * 0.1, pT - 15), primaryColor.withValues(alpha: 0.5), true);
    _drawText(canvas, "USEFUL MANY", Offset(pL + chartW * 0.6, pT - 15), Colors.white10, true);

    // Axes
    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 1;
    for (int i = 0; i <= 5; i++) {
      double y = pT + chartH - (i / 5) * chartH;
      canvas.drawLine(Offset(pL, y), Offset(size.width - pR, y), gridPaint);
      _drawText(canvas, (maxBar * i / 5).toStringAsFixed(0), Offset(pL - 10, y), Colors.white38, false, alignRight: true);
      _drawText(canvas, "${i * 20}%", Offset(size.width - pR + 10, y), Colors.amber.withValues(alpha: 0.6), false);
    }

    double stepW = chartW / items.length;
    double barW = stepW * 0.8;
    double cumulative = 0;
    final curvePath = Path();

    for (int i = 0; i < items.length; i++) {
      double v = items[i]['val'];
      double h = (v / maxBar) * chartH;
      double x = pL + i * stepW + (stepW - barW) / 2;
      double y = pT + chartH - h;

      final bool isSelected = selectedRowIndex == items[i]['index'];

      // Professional Bar
      final rect = Rect.fromLTWH(x, y, barW, h);
      final paint = Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
        (isSelected ? Colors.amberAccent : primaryColor),
        (isSelected ? Colors.amberAccent : primaryColor.withValues(alpha: 0.3))
      ]);
      canvas.drawRRect(RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(4), topRight: const Radius.circular(4)), paint);

      if (isSelected) {
        final hp = Paint()..color = Colors.amberAccent..style = PaintingStyle.stroke..strokeWidth = 2;
        canvas.drawRRect(RRect.fromRectAndCorners(rect.inflate(2), topLeft: const Radius.circular(6), topRight: const Radius.circular(6)), hp);
      }

      // Curve logic
      cumulative += v;
      double cx = x + barW/2;
      double cy = pT + chartH - (cumulative / total) * chartH;
      if (i == 0) curvePath.moveTo(cx, cy); else curvePath.lineTo(cx, cy);

      if (showLabels) {
        _drawText(canvas, items[i]['name'], Offset(cx, size.height - pB + 20), Colors.white38, true);
        if (cumulative/total <= 0.81 && cumulative/total >= 0.79) {
           canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = Colors.redAccent..style = PaintingStyle.stroke);
        }
      }
    }

    // Pareto Line
    canvas.drawPath(curvePath, Paint()..color = Colors.amber..strokeWidth = 2..style = PaintingStyle.stroke);

    // 80% Cutoff Line
    double y80 = pT + chartH - 0.8 * chartH;
    canvas.drawLine(Offset(pL, y80), Offset(size.width - pR, y80), Paint()..color = Colors.redAccent.withValues(alpha: 0.4)..strokeWidth = 1..style = PaintingStyle.stroke);

    // Stats Summary box
    final statsRect = Rect.fromLTWH(size.width - pR - 120, pT + 10, 110, 60);
    canvas.drawRRect(RRect.fromRectAndRadius(statsRect, const Radius.circular(8)), Paint()..color = Colors.black45);
    _drawText(canvas, "TOTAL: ${total.toInt()}", statsRect.topLeft + const Offset(10, 15), Colors.white70, false);
    _drawText(canvas, "ITEMS: ${items.length}", statsRect.topLeft + const Offset(10, 35), Colors.white70, false);
  }

  // 9. RADIAL BAR CHART (PRECISION MULTI-SERIES GAUGE)
  void _drawRadialBar(Canvas canvas, Size size, List<List<String>> table) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double minDim = math.min(size.width, size.height);

    double innerRadius = minDim * 0.2;
    double barThickness = (visualSettings['thickness'] ?? 18.0).clamp(5, minDim * 0.08);
    double gap = 8;
    double startAngle = visualSettings['smoothing'] ?? -1.25 * math.pi;
    double glowIntensity = visualSettings['intensity'] ?? 0.8;

    final paint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 2) continue;
      double val = (double.tryParse(table[i][1]) ?? 0).clamp(0, 100);
      double radius = innerRadius + (i - 1) * (barThickness + gap);
      double sweepAngle = (val / 100) * (1.5 * math.pi); // 270 degree gauge
      Color baseColor = Colors.accents[(i * 3) % Colors.accents.length];
      final bool isSelected = selectedRowIndex == i;

      // 1. Background Glass Track
      paint.color = Colors.white.withValues(alpha: 0.03);
      paint.strokeWidth = barThickness;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.25 * math.pi, 1.5 * math.pi, false, paint);

      // 2. Neon Glow Path
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = barThickness
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..color = baseColor.withValues(alpha: 0.2);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.25 * math.pi, sweepAngle, false, glowPaint);

      // 3. Active Bar with Sweep Gradient
      paint.shader = ui.Gradient.sweep(center, [
        (isSelected ? Colors.amberAccent.withValues(alpha: 0.2) : baseColor.withValues(alpha: 0.1)),
        (isSelected ? Colors.amberAccent : baseColor)
      ], [0.0, sweepAngle / (2*math.pi)]);
      paint.color = isSelected ? Colors.amberAccent : baseColor.withValues(alpha: glowIntensity);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, paint);
      paint.shader = null;

      if (isSelected) {
        final hp = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, hp);
      }

      // 4. Precision Markers (Ticks every 25%)
      final tickPaint = Paint()..color = Colors.white24..strokeWidth = 2;
      for (double t = 0; t <= 1.0; t += 0.25) {
        double tickAngle = -1.25 * math.pi + t * 1.5 * math.pi;
        Offset p1 = center + Offset(math.cos(tickAngle) * (radius - barThickness/2), math.sin(tickAngle) * (radius - barThickness/2));
        Offset p2 = center + Offset(math.cos(tickAngle) * (radius + barThickness/2), math.sin(tickAngle) * (radius + barThickness/2));
        canvas.drawLine(p1, p2, tickPaint);
      }

      if (showLabels) {
        _drawText(canvas, table[i][0].toUpperCase(), center + Offset(math.cos(-1.3 * math.pi) * radius, math.sin(-1.3 * math.pi) * radius), Colors.white38, false);
        _drawText(canvas, "${val.toInt()}%", center + Offset(math.cos(-1.25 * math.pi + sweepAngle) * (radius + 5), math.sin(-1.25 * math.pi + sweepAngle) * (radius + 5)), Colors.white, true);
      }
    }

    // Center Dashboard
    canvas.drawCircle(center, innerRadius - 10, Paint()..color = Colors.black45);
    canvas.drawCircle(center, innerRadius - 15, Paint()..style = PaintingStyle.stroke..color = primaryColor.withValues(alpha: 0.1)..strokeWidth = 1);
    _drawText(canvas, "SYSTEM\nMETRICS", center, primaryColor.withValues(alpha: 0.7), true);
  }

  // 10. TAYLOR DIAGRAM (RESEARCH-GRADE MASTERPIECE)
  void _drawTaylor(Canvas canvas, Size size, List<List<String>> table) {
    double p = 60;
    Offset origin = Offset(p, size.height - p);
    double chartSize = math.max(0, math.min(size.width - p * 2.5, size.height - p * 2));
    double maxSD = 2.0;
    double scale = chartSize / maxSD;

    double gridOpacity = visualSettings['opacity'] ?? 0.1;

    final gridPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1;

    // 1. Angular Correlation Grid (0 to 1)
    final corrs = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.99];
    for (var c in corrs) {
      double angle = math.acos(c);
      Offset end = origin + Offset(math.cos(-angle) * chartSize, math.sin(-angle) * chartSize);
      canvas.drawLine(origin, end, gridPaint..color = Colors.white.withValues(alpha: gridOpacity/2));
      _drawText(canvas, c.toString(), end + Offset(math.cos(-angle) * 15, math.sin(-angle) * 15), Colors.white38, true);
    }

    // 2. Radial SD Arcs
    for (double sd = 0.5; sd <= maxSD; sd += 0.5) {
      double r = sd * scale;
      canvas.drawArc(Rect.fromCircle(center: origin, radius: r), -math.pi/2, math.pi/2, false, gridPaint..color = Colors.white.withValues(alpha: gridOpacity));
      _drawText(canvas, sd.toString(), origin + Offset(r, 5), Colors.white38, true);
    }

    // 3. Skill Score (S) Contours
    double sCount = visualSettings['gap'] ?? 5.0;
    for (double k = 1; k <= sCount; k++) {
       double s = 0.5 + (k / sCount) * 0.4;
       Offset refPos = origin + Offset(1.0 * scale, 0);
       double rS = (1.0 - s) * 2 * scale;
       canvas.drawArc(Rect.fromCircle(center: refPos, radius: rS), math.pi, math.pi, false, gridPaint..color = Colors.teal.withValues(alpha: 0.1));
    }

    // 4. REF Point & RMSD Arcs
    Offset refPos = origin + Offset(1.0 * scale, 0);
    canvas.drawCircle(refPos, 5, Paint()..color = Colors.greenAccent);
    _drawText(canvas, "REF", refPos + const Offset(0, 15), Colors.greenAccent, true);
    for (double rms = 0.5; rms <= 1.5; rms += 0.5) {
      canvas.drawArc(Rect.fromCircle(center: refPos, radius: rms * scale), 1.1*math.pi, 0.8*math.pi, false, gridPaint..color = Colors.blueAccent.withValues(alpha: 0.1));
    }

    // 5. Model Data Points with Legend
    final legendRect = Rect.fromLTWH(size.width - 150, p, 130, 20 + table.length * 20);
    canvas.drawRRect(RRect.fromRectAndRadius(legendRect, const Radius.circular(8)), Paint()..color = Colors.black45);
    _drawText(canvas, "MODELS", legendRect.topCenter + const Offset(0, 10), Colors.white38, true);

    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 2) continue;
      double sd = double.tryParse(table[i][0]) ?? 0;
      double corr = double.tryParse(table[i][1]) ?? 0;
      double angle = math.acos(corr.clamp(0, 1));
      double r = sd * scale;
      Offset pos = origin + Offset(math.cos(-angle) * r, math.sin(-angle) * r);

      final bool isSelected = selectedRowIndex == i;
      final color = isSelected ? Colors.amberAccent : Colors.accents[i % Colors.accents.length];
      canvas.drawCircle(pos, isSelected ? 8 : 6, Paint()..color = color);
      canvas.drawCircle(pos, isSelected ? 8 : 6, Paint()..style = PaintingStyle.stroke..color = Colors.white..strokeWidth = isSelected ? 2 : 1);

      if (showLabels) {
        _drawText(canvas, "M$i", pos + const Offset(0, -14), Colors.white, true);
      }

      // Legend entry
      _drawText(canvas, "Model $i", legendRect.topLeft + Offset(35, 15 + i * 20), Colors.white70, false);
      canvas.drawCircle(legendRect.topLeft + Offset(20, 15 + i * 20), 4, Paint()..color = color);
    }

    // Axis Labels
    _drawText(canvas, "CORRELATION", origin + Offset(chartSize * 0.7, -chartSize * 0.7), Colors.white38, true);
    _drawText(canvas, "STANDARD DEVIATION", origin + Offset(chartSize/2, 40), Colors.white38, true);
  }

  // 11. TREEMAP (PROFESSIONAL SQUARIFIED VERSION)
  void _drawTreemap(Canvas canvas, Size size, List<List<String>> table) {
    List<Map<String, dynamic>> items = [];
    double totalVal = 0;
    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      double v = double.tryParse(table[i][2]) ?? 0;
      if (v > 0) {
        items.add({'name': table[i][1], 'val': v, 'id': i});
        totalVal += v;
      }
    }
    if (items.isEmpty) return;
    items.sort((a, b) => (b['val'] as double).compareTo(a['val'] as double));

    void squarify(int elementIndex, List<Map<String, dynamic>> currentRow, Rect rect) {
      if (elementIndex >= items.length) {
        _layoutRow(currentRow, rect, canvas, totalVal);
        return;
      }

      double width = math.min(rect.width, rect.height);
      Map<String, dynamic> next = items[elementIndex];
      List<Map<String, dynamic>> nextRow = List.from(currentRow)..add(next);

      if (_worstAspectRatio(currentRow, width, totalVal, rect.width * rect.height) >=
          _worstAspectRatio(nextRow, width, totalVal, rect.width * rect.height)) {
        squarify(elementIndex + 1, nextRow, rect);
      } else {
        Rect newRect = _layoutRow(currentRow, rect, canvas, totalVal);
        squarify(elementIndex, [], newRect);
      }
    }

    squarify(0, [], Rect.fromLTWH(0, 0, size.width, size.height));
  }

  double _worstAspectRatio(List<Map<String, dynamic>> row, double w, double total, double totalArea) {
    if (row.isEmpty || total == 0 || totalArea == 0 || w == 0) return double.infinity;
    double rowSum = row.fold(0, (s, e) => s + e['val']);
    double rowArea = (rowSum / total) * totalArea;
    double minArea = (row.last['val'] / total) * totalArea;
    double maxArea = (row.first['val'] / total) * totalArea;
    if (rowArea == 0 || minArea == 0 || w == 0) return double.infinity;
    double r1 = (math.pow(w, 2) * maxArea) / math.pow(rowArea, 2);
    double r2 = math.pow(rowArea, 2) / (math.pow(w, 2) * minArea);
    return math.max(r1, r2);
  }

  Rect _layoutRow(List<Map<String, dynamic>> row, Rect rect, Canvas canvas, double total) {
    if (row.isEmpty) return rect;
    double rowSum = row.fold(0, (s, e) => s + e['val']);
    double totalArea = rect.width * rect.height;
    double rowArea = (rowSum / total) * totalArea;

    bool vertical = rect.width < rect.height;
    double rowWidth = vertical ? rect.width : (rect.height == 0 ? 0 : rowArea / rect.height);
    double rowHeight = vertical ? (rect.width == 0 ? 0 : rowArea / rect.width) : rect.height;

    double currentX = rect.left;
    double currentY = rect.top;

    double blockGap = visualSettings['gap'] ?? 2.0;
    double cornerRadius = visualSettings['radius'] ?? 4.0;

    for (var e in row) {
      double eArea = (e['val'] / total) * totalArea;
      double ew = vertical ? (rowHeight == 0 ? 0 : eArea / rowHeight) : rowWidth;
      double eh = vertical ? rowHeight : (rowWidth == 0 ? 0 : eArea / rowWidth);

      final eRect = Rect.fromLTWH(currentX, currentY, ew, eh);
      final color = Colors.accents[(e['id'] as int) % Colors.accents.length];

      final bool isSelected = selectedRowIndex == e['id'];
      double colorMix = visualSettings['intensity'] ?? 0.6;
      _applyEffects(canvas, RRect.fromRectAndRadius(eRect.deflate(blockGap), Radius.circular(cornerRadius)), Paint()..color = isSelected ? Colors.amberAccent : color.withValues(alpha: colorMix));

      if (showLabels && eRect.width > 30 && eRect.height > 20) {
        _drawText(canvas, e['name'], eRect.center, Colors.white, true);
      }

      if (vertical) currentX += ew; else currentY += eh;
    }

    return vertical ? Rect.fromLTWH(rect.left, rect.top + rowHeight, rect.width, rect.height - rowHeight)
                    : Rect.fromLTWH(rect.left + rowWidth, rect.top, rect.width - rowWidth, rect.height);
  }

  // 12. STREAM GRAPH (ORGANIC MASTERPIECE - WIGGLE ALGORITHM)
  void _drawStreamGraph(Canvas canvas, Size size, List<List<String>> table) {
    final Map<String, List<double>> seriesMap = {};
    final List<String> timePoints = [];

    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      String time = table[i][0], cat = table[i][1];
      double val = double.tryParse(table[i][2]) ?? 0;
      if (!timePoints.contains(time)) timePoints.add(time);
      seriesMap[cat] = (seriesMap[cat] ?? [])..add(val);
    }
    if (seriesMap.isEmpty) return;

    // Normalize series lengths
    int maxLen = timePoints.length;
    for (var cat in seriesMap.keys) {
      while ((seriesMap[cat]?.length ?? 0) < maxLen) {
        seriesMap[cat]?.add(0.0);
      }
    }

    final categories = seriesMap.keys.toList();
    int m = categories.length;
    int n = maxLen;
    double dx = n > 1 ? size.width / (n - 1) : 0;

    double heightScale = visualSettings['intensity'] ?? 1.0;
    double wiggleFactor = visualSettings['smoothing'] ?? 0.5;
    double streamOpacity = visualSettings['opacity'] ?? 0.8;

    // 1. Calculate Wiggle Baseline
    List<double> baseline = List.filled(n, 0.0);
    for (int j = 0; j < n; j++) {
      double sum = 0;
      for (int i = 0; i < m; i++) {
        final series = seriesMap[categories[i]];
        if (series != null && series.length > j) {
          sum += (m - i - 0.5) * series[j];
        }
      }
      baseline[j] = m == 0 ? 0 : (-sum / m) * wiggleFactor;
    }

    final paint = Paint()..style = PaintingStyle.fill;
    List<double> lowerY = List.from(baseline);

    for (int i = 0; i < m; i++) {
      String cat = categories[i];
      List<double> vals = seriesMap[cat] ?? [];
      List<double> upperY = List.generate(n, (k) => lowerY[k] + (vals[k] * heightScale));

      // Determine if this category is selected
      bool isSelected = false;
      if (selectedRowIndex != null && selectedRowIndex! < table.length) {
        isSelected = table[selectedRowIndex!][1] == cat;
      }

      final path = Path();
      double midY = size.height / 2;

      path.moveTo(0, midY + lowerY[0]);
      for (int k = 1; k < n; k++) {
         path.cubicTo((k-0.5)*dx, midY + upperY[k-1], (k-0.5)*dx, midY + upperY[k], k*dx, midY + upperY[k]);
      }
      path.lineTo(size.width, midY + lowerY[n-1]);
      for (int k = n - 1; k > 0; k--) {
         path.cubicTo((k-0.5)*dx, midY + lowerY[k], (k-0.5)*dx, midY + lowerY[k-1], (k-1)*dx, midY + lowerY[k-1]);
      }
      path.close();

      final color = Colors.accents[(i * 2) % Colors.accents.length];
      paint.shader = ui.Gradient.linear(
        Offset(0, midY + lowerY.fold(0.0, math.min)),
        Offset(0, midY + upperY.fold(0.0, math.max)),
        [
          (isSelected ? Colors.amberAccent : color.withValues(alpha: streamOpacity)),
          (isSelected ? Colors.amberAccent.withValues(alpha: 0.5) : color.withValues(alpha: streamOpacity/2))
        ]
      );

      canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = Colors.black38);
      canvas.drawPath(path, paint);

      if (isSelected) {
        final hp = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5;
        canvas.drawPath(path, hp);
      }

      if (showLabels && vals.fold(0.0, (a, b) => a + b) > 10) {
        _drawText(canvas, cat, Offset(size.width * 0.5, midY + (lowerY[n~/2] + upperY[n~/2])/2), Colors.white, true);
      }
      lowerY = upperY;
    }
  }

  // 13. SANKEY DIAGRAM (HIGH-FIDELITY FLOW)
  void _drawSankey(Canvas canvas, Size size, List<List<String>> table) {
    final Map<String, double> nodeTotalIn = {};
    final Map<String, double> nodeTotalOut = {};
    final List<Map<String, dynamic>> connections = [];
    final Set<String> allNodes = {};

    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      String src = table[i][0];
      String tgt = table[i][1];
      double val = double.tryParse(table[i][2]) ?? 0;
      if (val <= 0) continue;

      connections.add({'src': src, 'tgt': tgt, 'val': val, 'index': i});
      nodeTotalOut[src] = (nodeTotalOut[src] ?? 0) + val;
      nodeTotalIn[tgt] = (nodeTotalIn[tgt] ?? 0) + val;
      allNodes.add(src);
      allNodes.add(tgt);
    }

    if (connections.isEmpty) return;

    Map<String, int> nodeLevels = {};
    for (var node in allNodes) {
      _calculateNodeLevel(node, connections, nodeLevels);
    }

    int maxLevel = nodeLevels.values.fold(0, math.max);
    Map<int, List<String>> levelGroups = {};
    for (int l = 0; l <= maxLevel; l++) {
      levelGroups[l] = allNodes.where((n) => nodeLevels[n] == l).toList();
    }

    double paddingX = 60;
    double columnWidth = maxLevel > 0 ? math.max(0, (size.width - paddingX * 2) / maxLevel) : 0;
    double nodeThickness = visualSettings['thickness'] ?? 18.0;
    double verticalPadding = 40;
    double chartHeight = math.max(0, size.height - (verticalPadding * 2));

    Map<String, Rect> nodeRects = {};
    levelGroups.forEach((lvl, nodes) {
      double total = nodes.fold(0.0, (sum, n) => sum + math.max(nodeTotalIn[n] ?? 0, nodeTotalOut[n] ?? 0));
      double currentY = verticalPadding;
      double availableForGaps = chartHeight * 0.15;
      double gap = nodes.length > 1 ? availableForGaps / (nodes.length - 1) : 0;

      for (var n in nodes) {
        double val = math.max(nodeTotalIn[n] ?? 0, nodeTotalOut[n] ?? 0);
        double h = total > 0 ? (val / total) * (chartHeight * 0.85) : (nodes.isEmpty ? 0 : chartHeight / nodes.length);
        nodeRects[n] = Rect.fromLTWH(paddingX + lvl * columnWidth - (lvl == maxLevel ? nodeThickness : 0), currentY, nodeThickness, h);
        currentY += h + gap;
      }
    });

    final paint = Paint()..style = PaintingStyle.fill;
    final Map<String, double> currentOutOffset = {};
    final Map<String, double> currentInOffset = {};

    for (var conn in connections) {
      String src = conn['src'];
      String tgt = conn['tgt'];
      double val = conn['val'];
      final bool isSelected = selectedRowIndex == conn['index'];

      Rect? srcRect = nodeRects[src];
      Rect? tgtRect = nodeRects[tgt];
      if (srcRect == null || tgtRect == null) continue;

      double h1 = (nodeTotalOut[src] ?? 0) == 0 ? 0 : (val / (nodeTotalOut[src] ?? 1.0)) * srcRect.height;
      double h2 = (nodeTotalIn[tgt] ?? 0) == 0 ? 0 : (val / (nodeTotalIn[tgt] ?? 1.0)) * tgtRect.height;

      double y1 = srcRect.top + (currentOutOffset[src] ?? 0);
      double y2 = tgtRect.top + (currentInOffset[tgt] ?? 0);

      currentOutOffset[src] = (currentOutOffset[src] ?? 0) + h1;
      currentInOffset[tgt] = (currentInOffset[tgt] ?? 0) + h2;

      final path = Path();
      path.moveTo(srcRect.right, y1);
      path.cubicTo(srcRect.right + columnWidth/2, y1, tgtRect.left - columnWidth/2, y2, tgtRect.left, y2);
      path.lineTo(tgtRect.left, y2 + h2);
      path.cubicTo(tgtRect.left - columnWidth/2, y2 + h2, srcRect.right + columnWidth/2, y1 + h1, srcRect.right, y1 + h1);
      path.close();

      paint.shader = ui.Gradient.linear(srcRect.centerRight, tgtRect.centerLeft, [
        (isSelected ? Colors.amberAccent : primaryColor.withValues(alpha: 0.3)),
        (isSelected ? Colors.amberAccent : secondaryColor.withValues(alpha: 0.3))
      ]);
      canvas.drawPath(path, paint);

      // Flowing Particles Effect
      if (isSelected || (visualSettings['intensity'] ?? 0.0) > 0.5) {
        final pPaint = Paint()..color = Colors.white.withValues(alpha: 0.5)..style = PaintingStyle.fill;
        double time = DateTime.now().millisecondsSinceEpoch / 2000.0;
        for (int i = 0; i < 3; i++) {
          double t = (time + i * 0.33) % 1.0;
          Offset pos = _getPointOnCubic(
            srcRect.centerRight + Offset(0, (y1 - srcRect.top) + h1/2 - srcRect.height/2),
            srcRect.centerRight + Offset(columnWidth/2, (y1 - srcRect.top) + h1/2 - srcRect.height/2),
            tgtRect.centerLeft - Offset(columnWidth/2, (y2 - tgtRect.top) + h2/2 - tgtRect.height/2),
            tgtRect.centerLeft + Offset(0, (y2 - tgtRect.top) + h2/2 - tgtRect.height/2),
            t
          );
          canvas.drawCircle(pos, 2, pPaint);
        }
      }

      if (isSelected) {
        final hp = Paint()..color = Colors.amberAccent..style = PaintingStyle.stroke..strokeWidth = 2;
        canvas.drawPath(path, hp);
      }
    }

    nodeRects.forEach((name, rect) {
      _applyEffects(canvas, RRect.fromRectAndRadius(rect, const Radius.circular(2)), Paint()..color = primaryColor);
      _drawText(canvas, name, rect.centerLeft - const Offset(5, 0), Colors.white, false, alignRight: true);
    });
  }

  // 14. ROSE CHART (NIGHTINGALE POLAR AREA)
  void _drawRose(Canvas canvas, Size size, List<List<String>> table) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double maxRadius = math.min(size.width, size.height) * 0.4;
    double maxVal = 0;
    List<Map<String, dynamic>> items = [];

    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 2) continue;
      double val = double.tryParse(table[i][1]) ?? 0;
      items.add({'name': table[i][0], 'val': val});
      maxVal = math.max(maxVal, val);
    }
    if (maxVal == 0) maxVal = 1;

    if (items.isEmpty) return;
    double angleStep = (2 * math.pi) / items.length;
    double currentAngle = -math.pi / 2;

    for (int i = 0; i < items.length; i++) {
      double r = (items[i]['val'] / maxVal) * maxRadius;
      final color = Colors.accents[(i * 2) % Colors.accents.length];

      final bool isSelected = selectedRowIndex == i + 1;
      final paint = Paint()
        ..shader = ui.Gradient.radial(center, r, [
          (isSelected ? Colors.amberAccent : color),
          (isSelected ? Colors.amberAccent : color.withValues(alpha: 0.3))
        ])
        ..style = PaintingStyle.fill;

      final double motionOffset = (visualSettings['intensity'] ?? 0.0) > 0.7 ? (math.sin(DateTime.now().millisecondsSinceEpoch / 1000 + i) * 5) : 0;
      final sectorPath = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: r + motionOffset), currentAngle, angleStep, false)
        ..close();

      _applyEffects(canvas, sectorPath, paint);

      if (showLabels) {
        double labelAngle = currentAngle + angleStep / 2;
        Offset pos = center + Offset(math.cos(labelAngle) * (r + 20), math.sin(labelAngle) * (r + 20));
        _drawText(canvas, items[i]['name'], pos, Colors.white, true);
      }
      currentAngle += angleStep;
    }

    // Concentric grid
    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.05)..style = PaintingStyle.stroke;
    for (int j = 1; j <= 4; j++) {
      canvas.drawCircle(center, maxRadius * (j / 4), gridPaint);
    }
  }

  // 15. DATA TABLE (PROFESSIONAL CANVAS GRID)
  void _drawDataTable(Canvas canvas, Size size, List<List<String>> table) {
    if (table.isEmpty || table[0].isEmpty) return;

    double rowHeight = 40;
    double colWidth = size.width / table[0].length;
    double startY = (size.height - (table.length * rowHeight)) / 2;

    final baseColor = isDark ? Colors.white : Colors.black;

    for (int i = 0; i < table.length; i++) {
      double y = startY + (i * rowHeight);
      final bool isSelected = selectedRowIndex == i;

      // Row Background (Zebra striping)
      if (i == 0) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, y, size.width, rowHeight), const Radius.circular(8)), Paint()..color = MountMapColors.teal.withValues(alpha: 0.2));
      } else if (isSelected) {
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, rowHeight), Paint()..color = Colors.amberAccent.withValues(alpha: 0.15));
      } else if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, rowHeight), Paint()..color = baseColor.withValues(alpha: 0.02));
      }

      for (int j = 0; j < table[i].length; j++) {
        double x = j * colWidth;
        _drawText(canvas, table[i][j], Offset(x + colWidth / 2, y + rowHeight / 2), i == 0 ? MountMapColors.teal : (isDark ? Colors.white70 : Colors.black87), true);

        // Vertical dividers
        if (j > 0) {
          canvas.drawLine(Offset(x, y + 5), Offset(x, y + rowHeight - 5), Paint()..color = baseColor.withValues(alpha: 0.05));
        }
      }

      // Horizontal divider
      canvas.drawLine(Offset(0, y + rowHeight), Offset(size.width, y + rowHeight), Paint()..color = baseColor.withValues(alpha: 0.05));
    }
  }

  void _drawText(Canvas canvas, String text, Offset position, Color color, bool center, {bool alignRight = false}) {
    double fontScale = visualSettings['fontScale'] ?? 1.0;
    double rotation = visualSettings['labelRotation'] ?? 0.0;

    // Use global labelColor if the passed color is generic white
    Color finalColor = (color == Colors.white || color == Colors.white70) ? labelColor : color;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: finalColor,
          fontSize: 10 * fontScale,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: isDark ? Colors.black : Colors.white, blurRadius: 2)]
        )
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    Offset finalPos = position;
    if (center) {
      finalPos = position - Offset(tp.width / 2, tp.height / 2);
    } else if (alignRight) {
      finalPos = position - Offset(tp.width, tp.height / 2);
    } else {
      finalPos = position - Offset(0, tp.height / 2);
    }

    if (rotation != 0) {
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(rotation);
      tp.paint(canvas, center ? Offset(-tp.width / 2, -tp.height / 2) : (alignRight ? Offset(-tp.width, -tp.height / 2) : Offset(0, -tp.height / 2)));
      canvas.restore();
    } else {
      tp.paint(canvas, finalPos);
    }
  }

  void _drawGlossyShape(Canvas canvas, dynamic shape, Color color, {double opacity = 1.0, bool hasGlass = true}) {
    final rect = shape is Rect ? shape : (shape is RRect ? shape.outerRect : (shape is Path ? shape.getBounds() : Rect.zero));

    // 1. Depth Shadow
    final shadowPaint = Paint()
      ..color = (isDark ? Colors.black : Colors.grey).withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    if (shape is Rect) canvas.drawRect(shape.shift(const Offset(4, 4)), shadowPaint);
    else if (shape is RRect) canvas.drawRRect(shape.shift(const Offset(4, 4)), shadowPaint);
    else if (shape is Path) canvas.drawPath(shape.shift(const Offset(4, 4)), shadowPaint);

    // 2. Base Paint
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [color, color.withValues(alpha: 0.8 * opacity), color.withValues(alpha: 0.5 * opacity)],
        [0.0, 0.6, 1.0]
      );

    _applyEffects(canvas, shape, paint);

    if (hasGlass) {
      // 3. Glass Highlight
      final glossPaint = Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [Colors.white.withValues(alpha: 0.25), Colors.transparent, Colors.white.withValues(alpha: 0.05)],
          const [0.0, 0.4, 0.6]
        );

      if (shape is Rect) canvas.drawRect(shape, glossPaint);
      else if (shape is RRect) canvas.drawRRect(shape, glossPaint);
      else if (shape is Path) canvas.drawPath(shape, glossPaint);

      // 4. Rim Light
      final rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = Colors.white.withValues(alpha: 0.3);
      if (shape is Rect) canvas.drawRect(shape, rimPaint);
      else if (shape is RRect) canvas.drawRRect(shape, rimPaint);
      else if (shape is Path) canvas.drawPath(shape, rimPaint);
    }
  }

  Offset _getPointOnCubic(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    double mt = 1 - t;
    return p0 * (mt * mt * mt) +
        p1 * (3 * mt * mt * t) +
        p2 * (3 * mt * t * t) +
        p3 * (t * t * t);
  }

  void _applyEffects(Canvas canvas, dynamic shape, Paint basePaint) {
    double bWidth = visualSettings['borderWidth'] ?? 0.0;
    double sInten = visualSettings['shadowIntensity'] ?? 0.0;

    if (sInten > 0) {
      final sPaint = Paint()
        ..color = glowColor != Colors.transparent ? glowColor.withValues(alpha: sInten) : (isDark ? Colors.black : Colors.grey).withValues(alpha: sInten * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * sInten);

      if (shape is Rect) canvas.drawRect(shape.shift(const Offset(2, 2)), sPaint);
      else if (shape is RRect) canvas.drawRRect(shape.shift(const Offset(2, 2)), sPaint);
      else if (shape is Path) canvas.drawPath(shape.shift(const Offset(2, 2)), sPaint);
    }

    if (shape is Rect) canvas.drawRect(shape, basePaint);
    else if (shape is RRect) canvas.drawRRect(shape, basePaint);
    else if (shape is Path) canvas.drawPath(shape, basePaint);

    if (bWidth > 0) {
      final bPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = bWidth;

      if (shape is Rect) canvas.drawRect(shape, bPaint);
      else if (shape is RRect) canvas.drawRRect(shape, bPaint);
      else if (shape is Path) canvas.drawPath(shape, bPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  /// Returns the index of the data row hit at [position]
  int? getHitIndex(Offset position, Size size) {
    if (data == null || data!.tableData == null) return null;
    final table = data!.tableData!;
    if (table.length < 2) return null;

    switch (chartType.toLowerCase()) {
      case 'alluvial diagram':
        return _hitTestAlluvial(position, size, table);
      case 'butterfly chart':
        return _hitTestButterfly(position, size, table);
      case 'chord diagram':
        return _hitTestChord(position, size, table);
      case 'histogram':
        return _hitTestHistogram(position, size, table);
      case 'multi-level pie chart':
        return _hitTestMultiLevelPie(position, size, table);
      case 'pareto chart':
        return _hitTestPareto(position, size, table);
      case 'radial bar chart':
        return _hitTestRadialBar(position, size, table);
      case 'treemap':
        return _hitTestTreemap(position, size, table);
      case 'sankey diagram':
        return _hitTestSankey(position, size, table);
      case 'rose chart':
        return _hitTestRose(position, size, table);
      case 'three-dimensional stream graph':
        return _hitTestStreamGraph(position, size, table);
      case 'hyperbolic tree':
        return _hitTestHyperbolic(position, size, table);
      case 'taylor diagram':
        return _hitTestTaylor(position, size, table);
      case 'contour plot':
        return _hitTestContour(position, size, table);
      case 'data table':
        return _hitTestDataTable(position, size, table);
      default:
        return null;
    }
  }

  // Implementation of hit tests would mirror the painting logic
  // For brevity and accuracy, we'll implement the ones that represent distinct data rows clearly.

  int? _hitTestHistogram(Offset pos, Size size, List<List<String>> table) {
    int numGroups = table[0].length - 1;
    double maxVal = 0;
    for (int i = 1; i < table.length; i++) {
      for (int g = 1; g <= numGroups; g++) {
        if (table[i].length > g) {
          maxVal = math.max(maxVal, double.tryParse(table[i][g]) ?? 0);
        }
      }
    }
    if (maxVal == 0) maxVal = 1;
    double pL = 60, pB = 50, pT = 40, pR = 30;
    double chartW = math.max(0, size.width - pL - pR);
    double chartH = math.max(0, size.height - pB - pT);
    double barWidthScale = visualSettings['intensity'] ?? 0.8;
    double groupAreaW = table.length > 1 ? chartW / (table.length - 1) : 0;
    double barW = (groupAreaW * barWidthScale) / numGroups;

    for (int i = 1; i < table.length; i++) {
      double groupX = pL + (i - 1) * groupAreaW + (groupAreaW * (1 - barWidthScale) / 2);
      for (int g = 0; g < numGroups; g++) {
        double val = double.tryParse(table[i][g + 1]) ?? 0;
        double h = (val / maxVal) * chartH;
        double x = groupX + g * barW;
        double y = pT + chartH - h;
        if (Rect.fromLTWH(x, y, barW, h).contains(pos)) return i;
      }
    }
    return null;
  }

  int? _hitTestTreemap(Offset pos, Size size, List<List<String>> table) {
    List<Map<String, dynamic>> items = [];
    double totalVal = 0;
    for (int i = 1; i < table.length; i++) {
      double v = double.tryParse(table[i][2]) ?? 0;
      if (v > 0) {
        items.add({'name': table[i][1], 'val': v, 'id': i});
        totalVal += v;
      }
    }
    if (items.isEmpty) return null;
    items.sort((a, b) => (b['val'] as double).compareTo(a['val'] as double));

    int? hitIndex;
    void squarify(int elementIndex, List<Map<String, dynamic>> currentRow, Rect rect) {
      if (elementIndex >= items.length) {
        _checkHitRow(currentRow, rect, totalVal, pos, (idx) => hitIndex = idx);
        return;
      }

      double width = math.min(rect.width, rect.height);
      Map<String, dynamic> next = items[elementIndex];
      List<Map<String, dynamic>> nextRow = List.from(currentRow)..add(next);

      if (_worstAspectRatio(currentRow, width, totalVal, rect.width * rect.height) >=
          _worstAspectRatio(nextRow, width, totalVal, rect.width * rect.height)) {
        squarify(elementIndex + 1, nextRow, rect);
      } else {
        Rect newRect = _checkHitRow(currentRow, rect, totalVal, pos, (idx) => hitIndex = idx);
        squarify(elementIndex, [], newRect);
      }
    }

    squarify(0, [], Rect.fromLTWH(0, 0, size.width, size.height));
    return hitIndex;
  }

  Rect _checkHitRow(List<Map<String, dynamic>> row, Rect rect, double total, Offset pos, Function(int) onHit) {
    if (row.isEmpty || total == 0) return rect;
    double rowSum = row.fold(0, (s, e) => s + e['val']);
    double totalArea = rect.width * rect.height;
    double rowArea = (rowSum / total) * totalArea;

    bool vertical = rect.width < rect.height;
    double rowWidth = vertical ? rect.width : (rect.height == 0 ? 0 : rowArea / rect.height);
    double rowHeight = vertical ? (rect.width == 0 ? 0 : rowArea / rect.width) : rect.height;

    double currentX = rect.left;
    double currentY = rect.top;

    for (var e in row) {
      double eArea = (e['val'] / total) * totalArea;
      double ew = vertical ? eArea / rowHeight : rowWidth;
      double eh = vertical ? rowHeight : eArea / rowWidth;

      if (Rect.fromLTWH(currentX, currentY, ew, eh).contains(pos)) {
        onHit(e['id']);
      }

      if (vertical) currentX += ew; else currentY += eh;
    }

    return vertical ? Rect.fromLTWH(rect.left, rect.top + rowHeight, rect.width, rect.height - rowHeight)
                    : Rect.fromLTWH(rect.left + rowWidth, rect.top, rect.width - rowWidth, rect.height);
  }

  int? _hitTestButterfly(Offset pos, Size size, List<List<String>> table) {
    double maxVal = 0;
    List<double> lefts = [], rights = [];
    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      double l = double.tryParse(table[i][1]) ?? 0;
      double r = double.tryParse(table[i][2]) ?? 0;
      lefts.add(l); rights.add(r);
      maxVal = math.max(maxVal, math.max(l, r));
    }
    if (maxVal == 0) maxVal = 1;
    double barHeight = visualSettings['thickness'] ?? 20.0;
    double labelWidth = visualSettings['gap'] ?? 100.0;
    double center = size.width / 2;
    double sideWidth = (size.width - labelWidth) / 2 - 20;
    double spacing = (size.height - 150) / (lefts.length + 1);
    spacing = spacing.clamp(10, 40);
    double startY = 80;

    for (int i = 0; i < lefts.length; i++) {
      double lw = maxVal == 0 ? 0 : (lefts[i] / maxVal) * sideWidth;
      double rw = maxVal == 0 ? 0 : (rights[i] / maxVal) * sideWidth;
      double y = startY + i * (barHeight + spacing);
      if (Rect.fromLTWH(center - labelWidth/2 - lw, y, lw, barHeight).contains(pos)) return i + 1;
      if (Rect.fromLTWH(center + labelWidth/2, y, rw, barHeight).contains(pos)) return i + 1;
    }
    return null;
  }

  int? _hitTestSankey(Offset pos, Size size, List<List<String>> table) {
    // Mirroring Sankey geometry logic to find the hit flow
    final Map<String, double> nodeTotalIn = {};
    final Map<String, double> nodeTotalOut = {};
    final List<Map<String, dynamic>> connections = [];
    final Set<String> allNodes = {};

    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      String src = table[i][0];
      String tgt = table[i][1];
      double val = double.tryParse(table[i][2]) ?? 0;
      if (val <= 0) continue;
      connections.add({'src': src, 'tgt': tgt, 'val': val, 'index': i});
      nodeTotalOut[src] = (nodeTotalOut[src] ?? 0) + val;
      nodeTotalIn[tgt] = (nodeTotalIn[tgt] ?? 0) + val;
      allNodes.add(src); allNodes.add(tgt);
    }

    Map<String, int> nodeLevels = {};
    for (var node in allNodes) { _calculateNodeLevel(node, connections, nodeLevels); }
    int maxLevel = nodeLevels.values.fold(0, math.max);
    Map<int, List<String>> levelGroups = {};
    for (int l = 0; l <= maxLevel; l++) { levelGroups[l] = allNodes.where((n) => nodeLevels[n] == l).toList(); }

    double paddingX = 60;
    double columnWidth = maxLevel > 0 ? (size.width - paddingX * 2) / maxLevel : 0;
    double nodeThickness = visualSettings['thickness'] ?? 18.0;
    double verticalPadding = 40;
    double chartHeight = size.height - (verticalPadding * 2);

    Map<String, Rect> nodeRects = {};
    levelGroups.forEach((lvl, nodes) {
      double total = nodes.fold(0.0, (sum, n) => sum + math.max(nodeTotalIn[n] ?? 0, nodeTotalOut[n] ?? 0));
      double currentY = verticalPadding;
      double availableForGaps = chartHeight * 0.15;
      double gap = nodes.length > 1 ? availableForGaps / (nodes.length - 1) : 0;

      for (var n in nodes) {
        double val = math.max(nodeTotalIn[n] ?? 0, nodeTotalOut[n] ?? 0);
        double h = total > 0 ? (val / total) * (chartHeight * 0.85) : (nodes.isEmpty ? 0 : chartHeight / nodes.length);
        nodeRects[n] = Rect.fromLTWH(paddingX + lvl * columnWidth - (lvl == maxLevel ? nodeThickness : 0), currentY, nodeThickness, h);
        currentY += h + gap;
      }
    });

    final Map<String, double> currentOutOffset = {};
    final Map<String, double> currentInOffset = {};

    for (var conn in connections) {
      String src = conn['src']; String tgt = conn['tgt']; double val = conn['val'];
      Rect? srcRect = nodeRects[src]; Rect? tgtRect = nodeRects[tgt];
      if (srcRect == null || tgtRect == null) continue;
      double h1 = (nodeTotalOut[src] ?? 0) == 0 ? 0 : (val / (nodeTotalOut[src] ?? 1.0)) * srcRect.height;
      double h2 = (nodeTotalIn[tgt] ?? 0) == 0 ? 0 : (val / (nodeTotalIn[tgt] ?? 1.0)) * tgtRect.height;
      double y1 = srcRect.top + (currentOutOffset[src] ?? 0);
      double y2 = tgtRect.top + (currentInOffset[tgt] ?? 0);
      currentOutOffset[src] = (currentOutOffset[src] ?? 0) + h1;
      currentInOffset[tgt] = (currentInOffset[tgt] ?? 0) + h2;

      final path = Path();
      path.moveTo(srcRect.right, y1);
      path.cubicTo(srcRect.right + columnWidth/2, y1, tgtRect.left - columnWidth/2, y2, tgtRect.left, y2);
      path.lineTo(tgtRect.left, y2 + h2);
      path.cubicTo(tgtRect.left - columnWidth/2, y2 + h2, srcRect.right + columnWidth/2, y1 + h1, srcRect.right, y1 + h1);
      path.close();

      if (path.contains(pos)) return conn['index'];
    }
    return null;
  }

  // Add more as needed...
  int? _hitTestAlluvial(Offset pos, Size size, List<List<String>> table) {
    // Mirroring Alluvial logic
    final Map<String, double> nodeTotalIn = {};
    final Map<String, double> nodeTotalOut = {};
    final List<Map<String, dynamic>> connections = [];
    final Set<String> allNodes = {};

    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      String src = table[i][0]; String tgt = table[i][1];
      double val = double.tryParse(table[i][2]) ?? 0;
      if (val <= 0) continue;
      connections.add({'src': src, 'tgt': tgt, 'val': val, 'index': i});
      nodeTotalOut[src] = (nodeTotalOut[src] ?? 0) + val;
      nodeTotalIn[tgt] = (nodeTotalIn[tgt] ?? 0) + val;
      allNodes.add(src); allNodes.add(tgt);
    }

    Map<String, int> nodeLevels = {};
    for (var node in allNodes) { _calculateNodeLevel(node, connections, nodeLevels); }
    int maxLevel = nodeLevels.values.fold(0, math.max);
    Map<int, List<String>> levelGroups = {};
    for (int l = 0; l <= maxLevel; l++) {
      levelGroups[l] = allNodes.where((n) => nodeLevels[n] == l).toList();
    }

    double paddingX = 80;
    double columnWidth = maxLevel > 0 ? (size.width - paddingX * 2) / maxLevel : 0;
    double verticalPadding = 40;
    double chartHeight = size.height - (verticalPadding * 2);

    Map<String, Rect> nodeRects = {};
    double nodeThickness = visualSettings['thickness'] ?? 24.0;
    levelGroups.forEach((lvl, nodes) {
      double total = nodes.fold(0.0, (sum, n) => sum + math.max(nodeTotalIn[n] ?? 0, nodeTotalOut[n] ?? 0));
      int nodeCount = nodes.length;
      double availableForGaps = chartHeight * 0.2;
      double gap = nodeCount > 1 ? availableForGaps / (nodeCount - 1) : 0;

      double currentY = verticalPadding;
      for (var n in nodes) {
        double val = math.max(nodeTotalIn[n] ?? 0, nodeTotalOut[n] ?? 0);
        double h = total > 0 ? (val / total) * (chartHeight * 0.8) : (nodes.isEmpty ? 0 : chartHeight / nodes.length);
        nodeRects[n] = Rect.fromLTWH(paddingX + lvl * columnWidth - (lvl == 0 ? 0 : (lvl == maxLevel ? nodeThickness : nodeThickness/2)), currentY, nodeThickness, h);
        currentY += h + gap;
      }
    });

    final Map<String, double> currentOutOffset = {};
    final Map<String, double> currentInOffset = {};
    double curvature = visualSettings['smoothing'] ?? 0.4;

    for (var conn in connections) {
      String src = conn['src']; String tgt = conn['tgt']; double val = conn['val'];
      Rect? srcRect = nodeRects[src]; Rect? tgtRect = nodeRects[tgt];
      if (srcRect == null || tgtRect == null) continue;
      double h1 = (nodeTotalOut[src] ?? 0) == 0 ? 0 : (val / (nodeTotalOut[src] ?? 1.0)) * srcRect.height;
      double h2 = (nodeTotalIn[tgt] ?? 0) == 0 ? 0 : (val / (nodeTotalIn[tgt] ?? 1.0)) * tgtRect.height;
      double y1 = srcRect.top + (currentOutOffset[src] ?? 0);
      double y2 = tgtRect.top + (currentInOffset[tgt] ?? 0);
      currentOutOffset[src] = (currentOutOffset[src] ?? 0) + h1;
      currentInOffset[tgt] = (currentInOffset[tgt] ?? 0) + h2;

      final path = Path();
      path.moveTo(srcRect.right, y1);
      path.cubicTo(srcRect.right + columnWidth * curvature, y1, tgtRect.left - columnWidth * curvature, y2, tgtRect.left, y2);
      path.lineTo(tgtRect.left, y2 + h2);
      path.cubicTo(tgtRect.left - columnWidth * curvature, y2 + h2, srcRect.right + columnWidth * curvature, y1 + h1, srcRect.right, y1 + h1);
      path.close();

      if (path.contains(pos)) return conn['index'];
    }
    return null;
  }

  int? _hitTestChord(Offset pos, Size size, List<List<String>> table) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = math.min(size.width, size.height) * 0.38;
    double ringWidth = visualSettings['thickness'] ?? 12.0;
    double innerRadius = radius - ringWidth;
    double gap = visualSettings['gap'] ?? 0.08;

    final Map<String, double> nodeTotals = {};
    final List<Map<String, dynamic>> flows = [];
    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      String src = table[i][0]; String tgt = table[i][1];
      double val = double.tryParse(table[i][2]) ?? 0;
      if (val <= 0) continue;
      flows.add({'src': src, 'tgt': tgt, 'val': val, 'index': i});
      nodeTotals[src] = (nodeTotals[src] ?? 0) + val;
      nodeTotals[tgt] = (nodeTotals[tgt] ?? 0) + val;
    }
    if (nodeTotals.isEmpty) return null;
    final totalVal = nodeTotals.values.fold(0.0, (sum, v) => sum + v);
    if (totalVal == 0) return null;
    final sortedNames = nodeTotals.keys.toList()..sort();
    final Map<String, double> nodeStartAngles = {};
    double currentAngle = 0;
    double availableAngle = math.max(0, 2 * math.pi - (sortedNames.length * gap));
    for (var name in sortedNames) {
      double nodeTotal = nodeTotals[name] ?? 0;
      double sweep = totalVal > 0 ? (nodeTotal / totalVal) * availableAngle : 0;
      nodeStartAngles[name] = currentAngle;
      currentAngle += sweep + gap;
    }

    final Map<String, double> currentOutOffset = {};
    final Map<String, double> currentInOffset = {};
    for (var flow in flows) {
      String src = flow['src']; String tgt = flow['tgt']; double val = flow['val'];
      double sStart = (nodeStartAngles[src] ?? 0) + (currentOutOffset[src] ?? 0);
      double sSweep = totalVal > 0 ? (val / totalVal) * availableAngle : 0;
      currentOutOffset[src] = (currentOutOffset[src] ?? 0) + sSweep;
      double tStart = (nodeStartAngles[tgt] ?? 0) + (currentInOffset[tgt] ?? 0);
      double tSweep = totalVal > 0 ? (val / totalVal) * availableAngle : 0;
      currentInOffset[tgt] = (currentInOffset[tgt] ?? 0) + tSweep;

      final path = Path();
      Offset s1 = center + Offset(math.cos(sStart) * innerRadius, math.sin(sStart) * innerRadius);
      Offset s2 = center + Offset(math.cos(sStart + sSweep) * innerRadius, math.sin(sStart + sSweep) * innerRadius);
      Offset t1 = center + Offset(math.cos(tStart) * innerRadius, math.sin(tStart) * innerRadius);
      Offset t2 = center + Offset(math.cos(tStart + tSweep) * innerRadius, math.sin(tStart + tSweep) * innerRadius);
      path.moveTo(s1.dx, s1.dy);
      path.arcToPoint(s2, radius: Radius.circular(innerRadius));
      path.cubicTo(
        center.dx + (s2.dx - center.dx) * 0.2, center.dy + (s2.dy - center.dy) * 0.2,
        center.dx + (t1.dx - center.dx) * 0.2, center.dy + (t1.dy - center.dy) * 0.2,
        t1.dx, t1.dy
      );
      path.arcToPoint(t2, radius: Radius.circular(innerRadius));
      path.cubicTo(
        center.dx + (t2.dx - center.dx) * 0.2, center.dy + (t2.dy - center.dy) * 0.2,
        center.dx + (s1.dx - center.dx) * 0.2, center.dy + (s1.dy - center.dy) * 0.2,
        s1.dx, s1.dy
      );
      path.close();
      if (path.contains(pos)) return flow['index'];
    }
    return null;
  }
  int? _hitTestMultiLevelPie(Offset pos, Size size, List<List<String>> table) {
    if (table.length < 2) return null;
    Offset center = Offset(size.width / 2, size.height / 2);
    double minDim = math.min(size.width, size.height);
    double baseRadius = (visualSettings['gap'] ?? 50.0).clamp(10, minDim * 0.2);
    double ringThickness = (visualSettings['thickness'] ?? 50.0).clamp(10, minDim * 0.15);

    double dist = (pos - center).distance;
    if (dist < baseRadius) return null;

    double angle = (pos - center).direction;
    if (angle < -math.pi / 2) angle += 2 * math.pi;
    double targetAngle = angle + math.pi / 2;
    while (targetAngle < 0) {
      targetAngle += 2 * math.pi;
    }
    while (targetAngle > 2 * math.pi) {
      targetAngle -= 2 * math.pi;
    }

    final tree = <String, List<Map<String, dynamic>>>{};
    final values = <String, double>{};
    final Set<String> allNodes = {};
    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      String p = table[i][0], c = table[i][1];
      double v = double.tryParse(table[i][2]) ?? 0;
      tree[p] = (tree[p] ?? [])..add({'name': c, 'index': i});
      values[c] = v;
      allNodes.add(p); allNodes.add(c);
    }
    if (allNodes.isEmpty) return null;
    String root = sunburstRoot ?? (allNodes.firstWhere((n) => !allNodes.any((p) => (tree[p] ?? []).any((child) => child['name'] == n)), orElse: () => allNodes.first));

    double calculateTotal(String node, [Set<String>? visited, int depth = 0]) {
      if (depth > 32 || (visited?.contains(node) ?? false)) return values[node] ?? 0;
      final children = tree[node] ?? [];
      if (children.isEmpty) return values[node] ?? 0;

      visited ??= {};
      visited.add(node);
      double sum = children.fold(0.0, (s, c) => s + calculateTotal(c['name'], visited, depth + 1));
      visited.remove(node);

      values[node] = sum;
      return sum;
    }
    calculateTotal(root);

    int? hitIndex;
    void findHit(String node, double startAngle, double sweep, int depth) {
      if (hitIndex != null || depth > 16) return;
      double rInner = baseRadius + depth * ringThickness;
      double rOuter = rInner + ringThickness;

      double normStart = startAngle + math.pi / 2;
      while (normStart < 0) {
        normStart += 2 * math.pi;
      }
      while (normStart > 2 * math.pi) {
        normStart -= 2 * math.pi;
      }

      // Check if targetAngle is within [normStart, normStart + sweep]
      // Account for wrap-around
      bool angleMatch = false;
      double endA = normStart + sweep;
      if (endA > 2 * math.pi) {
        angleMatch = targetAngle >= normStart || targetAngle <= (endA - 2 * math.pi);
      } else {
        angleMatch = targetAngle >= normStart && targetAngle <= endA;
      }

      if (dist >= rInner && dist <= rOuter && angleMatch) {
        // Found segment! Find row index.
        for (int i = 1; i < table.length; i++) {
          if (table[i][1] == node) {
            hitIndex = i;
            break;
          }
        }
      }
      if (hitIndex != null) return;

      final children = tree[node] ?? [];
      double currentAngle = startAngle;
      for (var child in children) {
        double childVal = values[child['name']] ?? 0;
        double childSweep = (values[node] ?? 0) == 0 ? 0 : (childVal / (values[node] ?? 1.0)) * sweep;
        findHit(child['name'], currentAngle, childSweep, depth + 1);
        currentAngle += childSweep;
      }
    }

    findHit(root, -math.pi/2, 2 * math.pi, 0);
    return hitIndex;
  }
  int? _hitTestPareto(Offset pos, Size size, List<List<String>> table) {
    List<Map<String, dynamic>> items = [];
    double total = 0;
    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 2) continue;
      double v = double.tryParse(table[i][1]) ?? 0;
      items.add({'name': table[i][0], 'val': v, 'index': i});
      total += v;
    }
    if (total == 0) return null;
    items.sort((a, b) => (b['val'] as double).compareTo(a['val'] as double));

    double pL = 60, pR = 60, pT = 60, pB = 60;
    double chartW = size.width - pL - pR, chartH = size.height - pT - pB;
    double maxBar = items.first['val'];
    double stepW = chartW / items.length;
    double barW = stepW * 0.8;

    for (int i = 0; i < items.length; i++) {
      double h = maxBar == 0 ? 0 : (items[i]['val'] / maxBar) * chartH;
      double x = pL + i * stepW + (stepW - barW) / 2;
      double y = pT + chartH - h;
      if (Rect.fromLTWH(x, y, barW, h).contains(pos)) return items[i]['index'];
    }
    return null;
  }
  int? _hitTestRadialBar(Offset pos, Size size, List<List<String>> table) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double minDim = math.min(size.width, size.height);
    double innerRadius = minDim * 0.2;
    double barThickness = (visualSettings['thickness'] ?? 18.0).clamp(5, minDim * 0.08);
    double gap = 8;

    double dist = (pos - center).distance;
    if (dist < innerRadius - barThickness/2) return null;

    int index = ((dist - (innerRadius - barThickness/2)) / (barThickness + gap)).round();
    if (index >= 0 && index < table.length - 1 && table[index + 1].length >= 2) {
      // Also check angle
      double angle = (pos - center).direction;
      if (angle < -1.25 * math.pi) angle += 2 * math.pi;
      // Simplified angle check
      return index + 1;
    }
    return null;
  }
  int? _hitTestStreamGraph(Offset pos, Size size, List<List<String>> table) {
    final Map<String, List<double>> seriesMap = {};
    final List<String> timePoints = [];
    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 3) continue;
      String time = table[i][0], cat = table[i][1];
      double val = double.tryParse(table[i][2]) ?? 0;
      if (!timePoints.contains(time)) timePoints.add(time);
      seriesMap[cat] = (seriesMap[cat] ?? [])..add(val);
    }
    if (seriesMap.isEmpty) return null;

    // Normalize series lengths
    int maxLen = timePoints.length;
    for (var cat in seriesMap.keys) {
      while ((seriesMap[cat]?.length ?? 0) < maxLen) {
        seriesMap[cat]?.add(0.0);
      }
    }

    final categories = seriesMap.keys.toList();
    int m = categories.length; int n = maxLen;
    double dx = n > 1 ? size.width / (n - 1) : 0;
    double heightScale = visualSettings['intensity'] ?? 1.0;
    double wiggleFactor = visualSettings['smoothing'] ?? 0.5;

    List<double> baseline = List.filled(n, 0.0);
    for (int j = 0; j < n; j++) {
      double sum = 0;
      for (int i = 0; i < m; i++) {
        final series = seriesMap[categories[i]];
        if (series != null && series.length > j) {
          sum += (m - i - 0.5) * series[j];
        }
      }
      baseline[j] = m == 0 ? 0 : (-sum / m) * wiggleFactor;
    }

    List<double> lowerY = List.from(baseline);
    for (int i = 0; i < m; i++) {
      String cat = categories[i];
      List<double> vals = seriesMap[cat] ?? [];
      List<double> upperY = List.generate(n, (k) => lowerY[k] + (vals[k] * heightScale));
      final path = Path();
      double midY = size.height / 2;
      path.moveTo(0, midY + lowerY[0]);
      for (int k = 1; k < n; k++) { path.cubicTo((k-0.5)*dx, midY + upperY[k-1], (k-0.5)*dx, midY + upperY[k], k*dx, midY + upperY[k]); }
      path.lineTo(size.width, midY + lowerY[n-1]);
      for (int k = n - 1; k > 0; k--) { path.cubicTo((k-0.5)*dx, midY + lowerY[k], (k-0.5)*dx, midY + lowerY[k-1], (k-1)*dx, midY + lowerY[k-1]); }
      path.close();

      if (path.contains(pos)) {
        // Return the first matching row index for this category
        for (int rowIdx = 1; rowIdx < table.length; rowIdx++) {
          if (table[rowIdx][1] == cat) {
            return rowIdx;
          }
        }
      }
      lowerY = upperY;
    }
    return null;
  }

  int? _hitTestHyperbolic(Offset pos, Size size, List<List<String>> table) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double diskRadius = math.min(size.width, size.height) * 0.45 * (visualSettings['intensity'] ?? 1.0);
    double baseNodeSize = visualSettings['thickness'] ?? 12.0;

    final tree = <String, List<Map<String, dynamic>>>{};
    String? root;
    for (int i = 1; i < table.length; i++) {
      String p = table[i][0], c = table[i][1];
      if (root == null) root = p;
      tree[p] = (tree[p] ?? [])..add({'name': c, 'index': i});
    }
    if (root == null) return null;

    int? hitIndex;
    void findHit(String name, double angle, double sweep, double r) {
      Offset p;
      if (dynamicNodePositions != null && dynamicNodePositions!.containsKey(name)) {
        Offset? raw = dynamicNodePositions![name];
        if (raw == null) {
          p = center;
        } else {
          double rawD = raw.distance;
          double diskD = diskRadius * (rawD / (rawD + 100));
          p = center + Offset(raw.dx / (rawD + 0.1) * diskD, raw.dy / (rawD + 0.1) * diskD);
        }
      } else {
        double d = diskRadius * (r / (r + 1.5));
        p = center + Offset(math.cos(angle) * d, math.sin(angle) * d);
      }
      double nodeSize = (baseNodeSize / (r + 1)).clamp(2.0, baseNodeSize);
      if ((pos - p).distance < nodeSize + 5) {
        // Find row index for this node
        for (int i = 1; i < table.length; i++) {
          if (table[i][1] == name || (r == 0 && table[i][0] == name)) {
            hitIndex = i;
            break;
          }
        }
      }
      if (hitIndex != null) return;

      final children = tree[name] ?? [];
      if (children.isNotEmpty) {
        double childSweep = sweep / children.length;
        for (int i = 0; i < children.length; i++) {
          findHit(children[i]['name'], (angle - sweep/2) + (i + 0.5) * childSweep, childSweep, r + 1.0);
          if (hitIndex != null) return;
        }
      }
    }
    findHit(root, 0, 2 * math.pi, 0);
    return hitIndex;
  }

  int? _hitTestRose(Offset pos, Size size, List<List<String>> table) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double maxRadius = math.min(size.width, size.height) * 0.4;
    double maxVal = 0;
    int validItems = 0;
    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 2) continue;
      maxVal = math.max(maxVal, double.tryParse(table[i][1]) ?? 0);
      validItems++;
    }
    if (validItems == 0) return null;
    if (maxVal == 0) maxVal = 1;
    int itemsCount = table.length - 1;
    double angleStep = (2 * math.pi) / itemsCount;

    double dist = (pos - center).distance;
    double angle = (pos - center).direction;
    if (angle < -math.pi / 2) angle += 2 * math.pi;

    double normalizedAngle = angle + math.pi/2;
    int index = (normalizedAngle / angleStep).floor() % itemsCount;

    double r = maxVal == 0 ? 0 : ((double.tryParse(table[index + 1][1]) ?? 0) / maxVal) * maxRadius;
    if (dist <= r) return index + 1;

    return null;
  }

  int? _hitTestTaylor(Offset pos, Size size, List<List<String>> table) {
    double p = 60;
    Offset origin = Offset(p, size.height - p);
    double chartSize = math.max(0, math.min(size.width - p * 2.5, size.height - p * 2));
    double scale = chartSize / 2.0;

    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 2) continue;
      double sd = double.tryParse(table[i][0]) ?? 0;
      double corr = double.tryParse(table[i][1]) ?? 0;
      double angle = math.acos(corr.clamp(0, 1));
      double r = sd * scale;
      Offset pointPos = origin + Offset(math.cos(-angle) * r, math.sin(-angle) * r);
      if ((pos - pointPos).distance < 15) return i;
    }
    return null;
  }

  int? _hitTestContour(Offset pos, Size size, List<List<String>> table) {
    double chartW = math.max(0, size.width - 120);
    double chartH = math.max(0, size.height - 100);
    Offset origin = const Offset(60, 40);

    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    bool hasData = false;
    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 2) continue;
      double x = double.tryParse(table[i][0]) ?? 0, y = double.tryParse(table[i][1]) ?? 0;
      minX = math.min(minX, x); maxX = math.max(maxX, x);
      minY = math.min(minY, y); maxY = math.max(maxY, y);
      hasData = true;
    }
    if (!hasData) return null;

    for (int i = 1; i < table.length; i++) {
      if (table[i].length < 2) continue;
      double x = double.tryParse(table[i][0]) ?? 0, y = double.tryParse(table[i][1]) ?? 0;
      double px = origin.dx + (maxX == minX ? chartW / 2 : ((x - minX) / (maxX - minX)) * chartW);
      double py = origin.dy + (maxY == minY ? chartH / 2 : ((y - minY) / (maxY - minY)) * chartH);
      if ((pos - Offset(px, py)).distance < 15) return i;
    }
    return null;
  }

  int? _hitTestDataTable(Offset pos, Size size, List<List<String>> table) {
    if (table.isEmpty) return null;
    double rowHeight = 40;
    double startY = (size.height - (table.length * rowHeight)) / 2;
    if (pos.dy < startY) return null;
    int index = ((pos.dy - startY) / rowHeight).floor();
    if (index >= 0 && index < table.length) return index;
    return null;
  }
}
