import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/node_model.dart';
import '../providers/mountmap_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/chart_engine.dart';
import 'dart:ui' as ui;

class DescriptionItem {
  final String id;
  final String type; // 'text', 'attachment', 'table', 'chart'
  final dynamic content;

  DescriptionItem({
    required this.id,
    required this.type,
    required this.content,
  });
}

class ImprovedDescriptionPanel extends StatefulWidget {
  final NodeModel node;
  final VoidCallback onClose;

  const ImprovedDescriptionPanel({
    super.key,
    required this.node,
    required this.onClose,
  });

  @override
  State<ImprovedDescriptionPanel> createState() => _ImprovedDescriptionPanelState();
}

class _ImprovedDescriptionPanelState extends State<ImprovedDescriptionPanel> {
  late List<DescriptionItem> _items;
  late TextEditingController _descController;
  bool _isEditingText = false;
  String? _editingItemId;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.node.description ?? '');
    _initializeItems();
  }

  void _initializeItems() {
    _items = [];
    
    // Add main description
    if (widget.node.description?.isNotEmpty == true) {
      _items.add(DescriptionItem(
        id: 'desc_main',
        type: 'text',
        content: widget.node.description,
      ));
    }

    // Add attachments
    for (var attachment in widget.node.attachments) {
      _items.add(DescriptionItem(
        id: attachment.id,
        type: 'attachment',
        content: attachment,
      ));
    }

    // Add table if exists
    if (widget.node.tableData != null && widget.node.tableData!.isNotEmpty) {
      _items.add(DescriptionItem(
        id: 'table_main',
        type: 'table',
        content: widget.node.tableData,
      ));
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _saveDescription() {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    provider.updatePeak(widget.node.id, description: _descController.text);
    setState(() {
      _isEditingText = false;
      _initializeItems();
    });
  }

  void _addTextItem() {
    setState(() {
      _items.add(DescriptionItem(
        id: DateTime.now().toString(),
        type: 'text',
        content: '',
      ));
    });
  }

  void _addAttachmentItem() {
    // This would open file picker in real implementation
    setState(() {
      _items.add(DescriptionItem(
        id: DateTime.now().toString(),
        type: 'attachment',
        content: AttachmentItem(
          id: DateTime.now().toString(),
          name: 'New File',
          value: '',
          type: 'file',
        ),
      ));
    });
  }

  void _addTableItem() {
    setState(() {
      _items.add(DescriptionItem(
        id: DateTime.now().toString(),
        type: 'table',
        content: [
          ['Item', 'Status', 'Owner', 'Due Date', 'Notes'],
          ['Example', 'Not started', '0', '', ''],
        ],
      ));
    });
  }

  void _addChartItem() {
    setState(() {
      _items.add(DescriptionItem(
        id: DateTime.now().toString(),
        type: 'chart',
        content: {
          'type': 'donut',
          'data': [
            {'label': 'Item 1', 'value': 25.0},
            {'label': 'Item 2', 'value': 25.0},
            {'label': 'Item 3', 'value': 25.0},
            {'label': 'Item 4', 'value': 25.0},
          ]
        },
      ));
    });
  }

  void _removeItem(String id) {
    setState(() {
      _items.removeWhere((item) => item.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MountMapProvider>(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    final textColor = provider.textColor;
    final cardColor = provider.cardColor;

    return Container(
      width: MediaQuery.of(context).size.width > 600 ? 500 : double.infinity,
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        border: Border.all(
          color: MountMapColors.teal.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
            blurRadius: 20,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGradientHeader(textColor, isDark),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainDescriptionSection(provider, textColor, isDark),
                  const SizedBox(height: 24),
                  ..._buildItemsList(provider, textColor, isDark),
                ],
              ),
            ),
          ),
          _buildFooterWithActions(provider, textColor),
        ],
      ),
    );
  }

  Widget _buildGradientHeader(Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MountMapColors.teal,
            MountMapColors.violet,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JUDUL DESKRIPSI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildMainDescriptionSection(MountMapProvider provider, Color textColor, bool isDark) {
    if (!_isEditingText) {
      return InkWell(
        onTap: () => setState(() => _isEditingText = true),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: MountMapColors.teal.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INI ADALAH CONTOH DARI ISI DESKRIPSI',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                color: textColor.withValues(alpha: 0.1),
                height: 1,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _descController,
          maxLines: 6,
          autofocus: true,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: textColor.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: MountMapColors.teal.withValues(alpha: 0.2),
              ),
            ),
            hintText: "Enter description...",
            hintStyle: TextStyle(color: textColor.withValues(alpha: 0.2)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => setState(() {
                _isEditingText = false;
                _descController.text = widget.node.description ?? "";
              }),
              child: Text('CANCEL', style: TextStyle(color: textColor.withValues(alpha: 0.6))),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _saveDescription,
              style: ElevatedButton.styleFrom(
                backgroundColor: MountMapColors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildItemsList(MountMapProvider provider, Color textColor, bool isDark) {
    return _items.where((item) => item.id != 'desc_main').map((item) {
      switch (item.type) {
        case 'text':
          return _buildTextItem(item, provider, textColor, isDark);
        case 'attachment':
          return _buildAttachmentItem(item, provider, textColor, isDark);
        case 'table':
          return _buildTableItem(item, provider, textColor, isDark);
        case 'chart':
          return _buildChartItem(item, provider, textColor, isDark);
        default:
          return const SizedBox.shrink();
      }
    }).toList();
  }

  Widget _buildTextItem(DescriptionItem item, MountMapProvider provider, Color textColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: textColor.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.content ?? 'Empty text',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: textColor.withValues(alpha: 0.4)),
                  onPressed: () => _removeItem(item.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Divider(color: textColor.withValues(alpha: 0.1), height: 16),
        ],
      ),
    );
  }

  Widget _buildAttachmentItem(DescriptionItem item, MountMapProvider provider, Color textColor, bool isDark) {
    final attachment = item.content as AttachmentItem;
    IconData icon = Icons.insert_drive_file_rounded;
    Color iconColor = Colors.blue;

    final ext = attachment.value.toLowerCase();
    if (ext.endsWith('.mp3') || ext.endsWith('.wav')) {
      icon = Icons.audiotrack_rounded;
      iconColor = Colors.orange;
    } else if (ext.endsWith('.mp4') || ext.endsWith('.mov')) {
      icon = Icons.videocam_rounded;
      iconColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: MountMapColors.teal.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attachment.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ATTACHMENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: textColor.withValues(alpha: 0.4)),
                  onPressed: () => _removeItem(item.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Divider(color: textColor.withValues(alpha: 0.1), height: 16),
        ],
      ),
    );
  }

  Widget _buildTableItem(DescriptionItem item, MountMapProvider provider, Color textColor, bool isDark) {
    final tableData = item.content as List<List<String>>;
    if (tableData.isEmpty) return const SizedBox.shrink();

    final headers = tableData[0];
    final rows = tableData.length > 1 ? tableData.sublist(1) : [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFCDDC39),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Checklist',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(textColor.withValues(alpha: 0.05)),
              columns: headers.map((h) => DataColumn(label: Text(h, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)))).toList(),
              rows: rows.map((row) => DataRow(cells: row.map((cell) => DataCell(Text(cell, style: TextStyle(fontSize: 9, color: textColor.withValues(alpha: 0.8))))).toList())).toList(),
            ),
          ),
          Divider(color: textColor.withValues(alpha: 0.1), height: 16),
        ],
      ),
    );
  }

  Widget _buildChartItem(DescriptionItem item, MountMapProvider provider, Color textColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INI ADALAH CONTOH DARI ISI DESKRIPSI',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: textColor.withValues(alpha: 0.05)),
            ),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: SimpleDonutChartPainter(
                    isDark: isDark,
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'PREVIEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: textColor.withValues(alpha: 0.1), height: 16),
        ],
      ),
    );
  }

  Widget _buildFooterWithActions(MountMapProvider provider, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: textColor.withValues(alpha: 0.1))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionButton('Add Text', Icons.note_add_rounded, _addTextItem, textColor),
            const SizedBox(width: 8),
            _buildActionButton('Add Attachment', Icons.attach_file_rounded, _addAttachmentItem, textColor),
            const SizedBox(width: 8),
            _buildActionButton('Add Table', Icons.table_chart_rounded, _addTableItem, textColor),
            const SizedBox(width: 8),
            _buildActionButton('Add Chart', Icons.bar_chart_rounded, _addChartItem, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed, Color textColor) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: textColor.withValues(alpha: 0.2)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}

class SimpleDonutChartPainter extends CustomPainter {
  final bool isDark;

  SimpleDonutChartPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;
    final innerRadius = radius * 0.5;

    final data = [
      {'label': 'Item 1', 'value': 16.1, 'color': const Color(0xFF00FFD1)},
      {'label': 'Item 2', 'value': 19.4, 'color': const Color(0xFF00D9FF)},
      {'label': 'Item 3', 'value': 29.0, 'color': const Color(0xFF0099FF)},
      {'label': 'Item 4', 'value': 25.8, 'color': const Color(0xFF6B5BFF)},
      {'label': 'Item 5', 'value': 9.7, 'color': const Color(0xFF9D4EDD)},
    ];

    double currentAngle = -3.14159 / 2;
    final total = data.fold<double>(0, (sum, item) => sum + (item['value'] as double));

    for (var item in data) {
      final value = item['value'] as double;
      final color = item['color'] as Color;
      final sliceAngle = (value / total) * 2 * 3.14159;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
        currentAngle,
        sliceAngle,
        false,
        paint,
      );

      final innerPaint = Paint()
        ..color = isDark ? const Color(0xFF0F172A) : Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, innerRadius, innerPaint);

      currentAngle += sliceAngle;
    }
  }

  @override
  bool shouldRepaint(SimpleDonutChartPainter oldDelegate) => false;
}
