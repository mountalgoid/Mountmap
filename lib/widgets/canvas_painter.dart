import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../models/node_model.dart';
import '../theme/app_colors.dart';
import '../providers/mountmap_provider.dart';

/// Painter Utama untuk Menggambar Garis Koneksi (Connection Lines)
class CanvasPainter extends CustomPainter {
  final List<NodeModel> nodes;
  final AppThemeMode themeMode;
  final String? selectedNodeId;
  final bool isDocxMap;

  CanvasPainter(this.nodes, this.themeMode, {this.selectedNodeId, this.isDocxMap = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    final nodeMap = {for (var n in nodes) n.id: n};

    // 1. Loop untuk mencari hubungan Orang Tua -> Anak
    for (var node in nodes) {
      // A. Gambar Cross Connections
      for (var targetId in node.crossConnections) {
        final target = nodeMap[targetId];
        if (target != null) {
          _drawConnection(canvas, size, node, target, true, nodeMap);
        }
      }

      // B. Gambar Parent-Child Connections
      if (node.parentId != null) {
        final parent = nodeMap[node.parentId];
        if (parent != null) {
          _drawConnection(canvas, size, parent, node, false, nodeMap);
        }
      }
    }
  }

  bool _isNodeInSelectedSubtree(String nodeId, Map<String, NodeModel> nodeMap) {
    if (selectedNodeId == null) return false;
    if (nodeId == selectedNodeId) return true;

    // Recursive check for parent (climbing up to selectedNodeId)
    String? currentId = nodeId;
    while (currentId != null) {
      if (currentId == selectedNodeId) return true;
      final node = nodeMap[currentId];
      currentId = node?.parentId;
    }
    return false;
  }

  void _drawConnection(Canvas canvas, Size size, NodeModel startNode, NodeModel endNode, bool isCross, Map<String, NodeModel> nodeMap) {
    // Highlighting Logic: All lines use uniform visual style as per latest feedback.
    // However, we still track isConnectedToSelected to optionally apply minor visual weight if needed,
    // though the core visual (shader/glow) will remain identical to normal lines.
    final bool isConnectedToSelected = selectedNodeId != null && _isNodeInSelectedSubtree(endNode.id, nodeMap);

    // Estimasi tinggi berdasarkan jumlah tag dan deskripsi yang akurat
    double getEstimatedHeight(NodeModel n) {
      if (isDocxMap) {
        double h = 160.0; // Base Docx height
        if (n.description != null && n.description!.isNotEmpty) h += 30.0;
        if (n.attachments.isNotEmpty || n.labels.isNotEmpty) h += 40.0;
        return h;
      }
      double h = 50.0; // Base MindMap height
      if (n.description != null && n.description!.isNotEmpty) h += 25.0;
      if (n.labels.isNotEmpty) h += (n.labels.length / 2).ceil() * 24.0;
      if (n.shapeType == 'table') h += 80.0;
      return h;
    }

    final double startH = getEstimatedHeight(startNode);
    final double endH = getEstimatedHeight(endNode);

    // Menentukan sisi keluar secara dinamis untuk line yang lebih organik
    bool isChildOnRight = endNode.position.dx > startNode.position.dx;
    final double nodeVisibleW = isDocxMap ? 190.0 : 160.0;

    // Titik jangkar yang menjorok masuk ke body agar seamless
    double startX = isChildOnRight ? (startNode.position.dx + nodeVisibleW - 10) : (startNode.position.dx + 10);
    double endX = isChildOnRight ? (endNode.position.dx + 10) : (endNode.position.dx + nodeVisibleW - 10);

    // Posisi absolut dengan padding global 20 (menggunakan titik tengah murni agar seimbang)
    double startYOffset = startH * 0.5;
    double endYOffset = endH * 0.5;

    Offset start = Offset(startX + 20, startNode.position.dy + startYOffset + 20);
    Offset end = Offset(endX + 20, endNode.position.dy + endYOffset + 20);

    final paint = Paint()
      ..strokeWidth = isConnectedToSelected ? 4.0 : (isCross ? 1.8 : 2.8)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bool isDark = themeMode == AppThemeMode.dark;
    if (isConnectedToSelected) {
      // SELECTED LINE: Consistent Teal & Violet Gradient
      paint.shader = ui.Gradient.linear(
        start,
        end,
        [
          MountMapColors.teal,
          MountMapColors.violet,
        ],
      );
    } else {
      // Normal Line: Subtle Teal & Violet Gradient
      paint.shader = ui.Gradient.linear(
        start,
        end,
        [
          MountMapColors.violet.withValues(alpha: isDark ? 0.3 : 0.5),
          MountMapColors.teal.withValues(alpha: isDark ? 0.3 : 0.5),
        ],
      );
    }

    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Tentukan control points dinamis berdasarkan jarak (Dynamic Tension)
    final double deltaX = (end.dx - start.dx).abs();
    final double cpDist = (deltaX * 0.5).clamp(40.0, 160.0);
    Offset cp1, cp2;

    if (isChildOnRight) {
      cp1 = Offset(start.dx + cpDist, start.dy);
      cp2 = Offset(end.dx - cpDist, end.dy);
    } else {
      cp1 = Offset(start.dx - cpDist, start.dy);
      cp2 = Offset(end.dx + cpDist, end.dy);
    }

    if (isDocxMap) {
      // Professional Orthogonal Lines for DocxMap
      final double midX = start.dx + (end.dx - start.dx) * 0.5;
      path.lineTo(midX, start.dy);
      path.lineTo(midX, end.dy);
      path.lineTo(end.dx, end.dy);

      paint.shader = null;
      paint.color = themeMode == AppThemeMode.dark ? Colors.white70 : Colors.black54;
      paint.strokeWidth = 2.2;
      _drawArrowHead(canvas, Offset(end.dx - 10, end.dy), end, paint);
    } else {
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);

      // Draw Arrow Head for Flowchart look
      _drawArrowHead(canvas, cp2, end, paint);
    }

    // 1. Draw Subtle Glow/Shadow for ALL lines (Depth effect)
    final baseGlowPaint = Paint()
      ..strokeWidth = paint.strokeWidth + 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0)
      ..color = paint.color.withValues(alpha: 0.05);
    canvas.drawPath(path, baseGlowPaint);

    canvas.drawPath(path, paint);

    // Draw Connection Label if exists
    if (endNode.connectionLabel != null && endNode.connectionLabel!.isNotEmpty) {
      if (isDocxMap) {
        _drawConnectionLabel(canvas, start, start, end, end, endNode.connectionLabel!);
      } else {
        _drawConnectionLabel(canvas, start, cp1, cp2, end, endNode.connectionLabel!);
      }
    }

    if (isConnectedToSelected) {
      // High-End Glow for Selected Branch Connections
      final glowPaint = Paint()
        ..strokeWidth = 8.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0)
        ..shader = ui.Gradient.linear(
          start,
          end,
          [
            MountMapColors.teal.withValues(alpha: 0.6),
            MountMapColors.violet.withValues(alpha: 0.6),
          ],
        );
      canvas.drawPath(path, glowPaint);
    }
  }

  void _drawConnectionLabel(Canvas canvas, Offset p0, Offset p1, Offset p2, Offset p3, String label) {
    // mid point of cubic bezier at t=0.5
    // B(t) = (1-t)^3*p0 + 3(1-t)^2*t*p1 + 3(1-t)*t^2*p2 + t^3*p3
    const double t = 0.5;
    const double mt = 1 - t;
    final Offset mid = p0 * (mt * mt * mt) +
                       p1 * (3 * mt * mt * t) +
                       p2 * (3 * mt * t * t) +
                       p3 * (t * t * t);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: themeMode == AppThemeMode.dark ? Colors.white70 : Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: themeMode == AppThemeMode.dark ? MountMapColors.darkCard : Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, mid - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawArrowHead(Canvas canvas, Offset controlPoint, Offset endPoint, Paint paint) {
    const double arrowSize = 12.0;
    final double angle = (endPoint - controlPoint).direction;

    final path = Path();
    path.moveTo(endPoint.dx, endPoint.dy);
    path.lineTo(
      endPoint.dx - arrowSize * math.cos(angle - math.pi / 6),
      endPoint.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    path.lineTo(
      endPoint.dx - arrowSize * math.cos(angle + math.pi / 6),
      endPoint.dy - arrowSize * math.sin(angle + math.pi / 6),
    );
    path.close();

    final arrowPaint = Paint()
      ..color = paint.shader == null ? paint.color : (themeMode == AppThemeMode.dark ? Colors.white : Colors.black)
      ..shader = paint.shader
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    // Selalu repaint saat ada interaksi untuk animasi yang mulus
    return true;
  }
}

/// Painter Tambahan untuk Background Grid (Blueprint Effect)
/// Gunakan ini di widget CustomPaint terpisah di layer paling belakang (Stack)
class GridPainter extends CustomPainter {
  final Color gridColor;
  final bool isDark;

  GridPainter({this.gridColor = const Color(0xFFFFFFFF), this.isDark = true});

  @override
  void paint(Canvas canvas, Size size) {
    // Gunakan opacity sangat rendah agar tidak mengganggu pandangan
    final paint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    const double step = 50.0; // Jarak antar kotak grid

    // Gambar Garis Vertikal
    for (double i = 0; i <= size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    // Gambar Garis Horizontal
    for (double i = 0; i <= size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}