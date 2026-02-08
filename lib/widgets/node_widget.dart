import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/node_model.dart';
import '../theme/app_colors.dart';
import '../providers/mountmap_provider.dart';

class NodeUI extends StatelessWidget {
  final NodeModel node;
  final AppThemeMode themeMode;
  final VoidCallback onCommand;
  final bool isDragging;
  final bool isSelected;
  final bool isConnecting;
  final bool isDocxMap;

  const NodeUI({
    super.key,
    required this.node,
    required this.themeMode,
    required this.onCommand,
    this.isDragging = false,
    this.isSelected = false,
    this.isConnecting = false,
    this.isDocxMap = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = themeMode == AppThemeMode.dark;
    final bool isWarm = themeMode == AppThemeMode.warm;

    final Color? customBodyColor = node.bodyColor != null ? Color(node.bodyColor!) : null;
    final Color? customTextColor = node.textColor != null ? Color(node.textColor!) : null;
    final Color? customIconColor = node.iconColor != null ? Color(node.iconColor!) : null;

    final Color cardColor = customBodyColor ?? (isDark
        ? const Color(0xFF1E293B)
        : (isWarm ? const Color(0xFFFDF6E3) : Colors.white));

    final Color textColor = customTextColor ?? (isDark
        ? Colors.white
        : (isWarm ? const Color(0xFF586E75) : Colors.black87));

    final Color iconColor = customIconColor ?? (isDark ? const Color(0xFF00FFD1) : const Color(0xFF089981));

    Color borderColor = isSelected
        ? (isDark ? Colors.white : Colors.black87)
        : (isConnecting ? Colors.amberAccent : (isDark ? Colors.white12 : Colors.black12));

    return GestureDetector(
      onLongPress: onCommand, 
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDragging ? 0.7 : 1.0,
        child: _buildNodeWrapper(
          isSelected: isSelected,
          borderColor: borderColor,
          cardColor: cardColor,
          child: _buildBodyContent(cardColor, textColor, iconColor, isSelected),
        ),
      ),
    );
  }

  Widget _buildNodeWrapper({
    required Widget child,
    required bool isSelected,
    required Color borderColor,
    required Color cardColor,
  }) {
    if (isDocxMap) return child; // DocxMap handles its own decoration and layout

    double radius = 12;
    if (node.shapeType == 'circle') radius = 1000;
    if (node.shapeType == 'oval') radius = 30;

    // Custom constraints for special diagrams
    double? maxWidth = 260;
    double? minWidth = 100;
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10);

    if (node.shapeType == 'table') {
      maxWidth = 600;
      minWidth = 200;
      padding = EdgeInsets.zero;
    } else if (node.shapeType == 'triangle') {
      maxWidth = 400;
      minWidth = 200;
      padding = const EdgeInsets.only(bottom: 20); // Room for bottom levels
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding,
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      decoration: _getDecoration(cardColor, borderColor, isSelected, radius),
      child: child,
    );
  }

  Decoration _getDecoration(Color cardColor, Color borderColor, bool isSelected, double radius) {
    final Decoration bgDecoration = node.isGradient ? const BoxDecoration(
      gradient: LinearGradient(
        colors: [MountMapColors.teal, MountMapColors.violet],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ) : BoxDecoration(color: cardColor);

    switch (node.shapeType) {
      case 'triangle':
        return ShapeDecoration(
          color: node.isGradient ? null : cardColor,
          gradient: node.isGradient ? (bgDecoration as BoxDecoration).gradient : null,
          shadows: isSelected ? [
            BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2)
          ] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
          shape: _TriangleBorder(
            side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
          ),
        );
      case 'circle':
        return ShapeDecoration(
          color: node.isGradient ? null : cardColor,
          gradient: node.isGradient ? (bgDecoration as BoxDecoration).gradient : null,
          shadows: isSelected ? [
            BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2)
          ] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
          shape: CircleBorder(side: BorderSide(color: borderColor, width: isSelected ? 2 : 1)),
        );
      case 'oval':
        return ShapeDecoration(
          color: node.isGradient ? null : cardColor,
          gradient: node.isGradient ? (bgDecoration as BoxDecoration).gradient : null,
          shadows: isSelected ? [
            BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2)
          ] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
          shape: StadiumBorder(side: BorderSide(color: borderColor, width: isSelected ? 2 : 1)),
        );
      case 'parallelogram':
        return ShapeDecoration(
          color: node.isGradient ? null : cardColor,
          gradient: node.isGradient ? (bgDecoration as BoxDecoration).gradient : null,
          shadows: isSelected ? [
            BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2)
          ] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
          shape: _ParallelogramBorder(
            side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
          ),
        );
      case 'diamond':
      case 'hexagon':
        return ShapeDecoration(
          color: node.isGradient ? null : cardColor,
          gradient: node.isGradient ? (bgDecoration as BoxDecoration).gradient : null,
          shadows: isSelected ? [
            BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2)
          ] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
          shape: _PolygonBorder(
            sides: node.shapeType == 'diamond' ? 4 : 6,
            rotate: node.shapeType == 'diamond' ? 0 : 0,
            side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
          ),
        );
      case 'box':
      default:
        return BoxDecoration(
          color: node.isGradient ? null : cardColor,
          gradient: node.isGradient ? (bgDecoration as BoxDecoration).gradient : null,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [
            BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2)
          ] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
        );
    }
  }

  Widget _buildBodyContent(Color cardColor, Color textColor, Color iconColor, bool isSelected) {
    if (isDocxMap) return _buildDocxContent(cardColor, textColor, iconColor, isSelected);

    // Specialized Rendering for Diagrams
    if (node.shapeType == 'table') return _buildTable(textColor, isSelected);
    if (node.shapeType == 'triangle') return _buildTrianglePyramid(textColor, isSelected);
    if (node.shapeType == 'timeline') return _buildTimeline(textColor, isSelected);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (node.marker != null && node.marker!.isNotEmpty)
          _buildMarker(iconColor),

        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (node.isTextGradient)
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      MountMapColors.teal,
                      MountMapColors.violet,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    node.nodeNumber != null ? "${node.nodeNumber}. ${node.text}" : node.text,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Text(
                  node.nodeNumber != null ? "${node.nodeNumber}. ${node.text}" : node.text,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              if (node.description != null && node.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    node.description!,
                    style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              if (node.labels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: node.labels.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            MountMapColors.teal.withValues(alpha: 0.8),
                            MountMapColors.violet.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        tag.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )).toList(),
                  ),
                ),

              if (_hasMetadata()) _buildStatusIndicators(iconColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarker(Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/logo.png',
            width: 28,
            height: 28,
            color: color.withValues(alpha: 0.8),
          ),
          if (node.marker != null && node.marker!.isNotEmpty)
            Positioned(
              child: node.isIconGradient
                  ? ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          MountMapColors.teal,
                          MountMapColors.violet,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        node.marker!,
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    )
                  : Text(
                      node.marker!,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicators(Color specialColor) {
    bool hasFile = node.attachments.any((a) => a.type == 'file');
    bool hasLink = node.attachments.any((a) => a.type == 'link');

    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.note != null && node.note!.isNotEmpty)
            _statusIcon(Icons.notes_rounded),
          
          if (hasFile) 
            _statusIcon(Icons.attach_file_rounded),
          
          if (hasLink || node.linkedAssetId != null)
            _statusIcon(Icons.link_rounded, isSpecial: true, color: specialColor),
          
          if (node.alertEnabled && node.alertDate != null)
            _statusIcon(
              node.hasActiveAlert ? Icons.notifications_active : Icons.notification_important,
              isSpecial: true,
              color: node.hasActiveAlert ? Colors.orangeAccent : Colors.redAccent,
            ),

          if (node.isLocked)
            _statusIcon(Icons.lock_rounded, isSpecial: true, color: Colors.redAccent),
        ],
      ),
    );
  }

  Widget _statusIcon(IconData icon, {bool isSpecial = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Icon(
        icon,
        size: 14,
        color: color ?? (isSpecial ? MountMapColors.teal : Colors.grey.withValues(alpha: 0.8)),
      ),
    );
  }

  bool _hasMetadata() {
    return (node.note != null && node.note!.isNotEmpty) ||
        node.attachments.isNotEmpty ||
        node.linkedAssetId != null ||
        (node.alertEnabled && node.alertDate != null) ||
        node.isLocked;
  }

  // --- Specialized Diagram Builders ---

  Widget _buildTable(Color textColor, bool isSelected) {
    final data = node.tableData ?? [["Col 1", "Col 2"], ["Row 1", "Row 2"]];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            node.nodeNumber != null ? "${node.nodeNumber}. ${node.text}" : node.text,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)
          ),
        ),
        Table(
          border: TableBorder.all(color: textColor.withValues(alpha: 0.2), width: 0.5),
          children: data.map((row) => TableRow(
            children: row.map((cell) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(cell, style: TextStyle(color: textColor, fontSize: 12)),
            )).toList(),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildTrianglePyramid(Color textColor, bool isSelected) {
    final levels = node.dataList ?? ["Top", "Middle", "Bottom"];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Text(
            node.nodeNumber != null ? "${node.nodeNumber}. ${node.text}" : node.text,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)
          ),
        ),
        const SizedBox(height: 20), // Spacing for triangle effect
        ...levels.asMap().entries.map((entry) {
          int idx = entry.key;
          String text = entry.value;
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 20.0 + (idx * 10)),
            child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12 + (levels.length - idx).toDouble())),
          );
        }),
      ],
    );
  }

  Widget _buildDocxContent(Color cardColor, Color textColor, Color iconColor, bool isSelected) {
    final bool isDark = themeMode == AppThemeMode.dark;

    // Determine Doc Icon based on marker
    IconData docIcon = Icons.description_rounded;
    String markerStr = (node.marker ?? "DOC").toUpperCase();
    if (markerStr.contains("PDF")) docIcon = Icons.picture_as_pdf_rounded;
    if (markerStr.contains("IMG") || markerStr.contains("PIC")) docIcon = Icons.image_rounded;
    if (markerStr.contains("VID")) docIcon = Icons.video_collection_rounded;
    if (markerStr.contains("LINK") || markerStr.contains("WEB")) docIcon = Icons.language_rounded;
    if (markerStr.contains("DATA") || markerStr.contains("CSV")) docIcon = Icons.analytics_rounded;

    // Determine Modern vs Classic look via shapeType
    bool isModern = node.shapeType == 'hexagon';

    return Container(
      width: 190,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isModern ? 16 : 4),
        border: Border.all(
          color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white10 : Colors.black12),
          width: isSelected ? 1.8 : 1
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: isModern ? 15 : 8,
            offset: const Offset(0, 4)
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isModern ? 16 : 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bar
            Container(
              height: 32,
              decoration: BoxDecoration(
                gradient: node.isGradient ? const LinearGradient(
                  colors: [MountMapColors.teal, MountMapColors.violet],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ) : MountMapColors.primaryGradient,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(docIcon, color: Colors.white, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      markerStr,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (node.isLocked)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.lock_rounded, color: Colors.white, size: 12),
                    ),
                  if (node.attachments.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                      child: Text("${node.attachments.length}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.nodeNumber != null ? "${node.nodeNumber}. ${node.text}" : node.text,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: -0.2
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Interactive feeling visual lines (Professional balance)
                  ...List.generate(2, (i) => Container(
                    height: 2.0,
                    margin: const EdgeInsets.only(bottom: 5),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: i == 0 ? 0.08 : 0.04),
                      borderRadius: BorderRadius.circular(1),
                    ),
                    width: i == 1 ? 100 : double.infinity,
                  )),

                  if (node.description != null && node.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      node.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.54),
                        fontSize: 10,
                        height: 1.4,
                        fontStyle: isModern ? FontStyle.italic : FontStyle.normal
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Advanced Footer for Professional feel
            if (node.attachments.isNotEmpty || node.labels.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.03),
                  border: Border(top: BorderSide(color: textColor.withValues(alpha: 0.06))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (node.attachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          children: node.attachments.take(5).map((a) => Icon(
                            a.type == 'link' ? Icons.link_rounded : Icons.file_present_rounded,
                            color: iconColor.withValues(alpha: 0.6),
                            size: 14,
                          )).toList(),
                        ),
                      ),

                    if (node.labels.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: node.labels.map((l) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: iconColor.withValues(alpha: 0.15), width: 0.5),
                          ),
                          child: Text(
                            l.toUpperCase(),
                            style: TextStyle(color: iconColor, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                          ),
                        )).toList(),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(Color textColor, bool isSelected) {
    final events = node.dataList ?? ["Event 1", "Event 2", "Event 3"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          node.nodeNumber != null ? "${node.nodeNumber}. ${node.text}" : node.text,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)
        ),
        const SizedBox(height: 12),
        ...events.map((event) => Row(
          children: [
            Column(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: MountMapColors.teal, shape: BoxShape.circle)),
                Container(width: 2, height: 20, color: textColor.withValues(alpha: 0.2)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(event, style: TextStyle(color: textColor, fontSize: 13))),
          ],
        )),
      ],
    );
  }
}

class _TriangleBorder extends ShapeBorder {
  final BorderSide side;

  const _TriangleBorder({this.side = BorderSide.none});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _getPath(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _getPath(rect);

  Path _getPath(Rect rect) {
    return Path()
      ..moveTo(rect.center.dx, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final paint = side.toPaint();
    final path = getOuterPath(rect, textDirection: textDirection);
    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) => _TriangleBorder(side: side.scale(t));
}

class _PolygonBorder extends ShapeBorder {
  final int sides;
  final double rotate;
  final BorderSide side;

  const _PolygonBorder({
    required this.sides,
    this.rotate = 0.0,
    this.side = BorderSide.none,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _getPolygonPath(rect.deflate(side.width));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _getPolygonPath(rect);
  }

  Path _getPolygonPath(Rect rect) {
    final double r = rect.width / 2;
    final Offset center = rect.center;
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final double angle = (i * 2 * math.pi / sides) - (math.pi / 2) + rotate;
      final double x = center.dx + r * math.cos(angle);
      final double y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final paint = side.toPaint();
    final path = getOuterPath(rect, textDirection: textDirection);
    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) => _PolygonBorder(sides: sides, rotate: rotate, side: side.scale(t));
}

class _ParallelogramBorder extends ShapeBorder {
  final BorderSide side;
  final double skew;

  const _ParallelogramBorder({
    this.side = BorderSide.none,
    this.skew = 20.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _getPath(rect.deflate(side.width));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _getPath(rect);
  }

  Path _getPath(Rect rect) {
    return Path()
      ..moveTo(rect.left + skew, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right - skew, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final paint = side.toPaint();
    final path = getOuterPath(rect, textDirection: textDirection);
    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) => _ParallelogramBorder(side: side.scale(t), skew: skew);
}
