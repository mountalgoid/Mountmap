import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/node_model.dart';
import '../providers/mountmap_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/chart_engine.dart';
import '../screens/attachment_viewer_screen.dart';

class ProfessionalDescriptionPanel extends StatefulWidget {
  final NodeModel node;
  final VoidCallback onClose;

  const ProfessionalDescriptionPanel({
    super.key,
    required this.node,
    required this.onClose,
  });

  @override
  State<ProfessionalDescriptionPanel> createState() => _ProfessionalDescriptionPanelState();
}

class _ProfessionalDescriptionPanelState extends State<ProfessionalDescriptionPanel> {
  String? _editingBlockId;

  void _addTextItem() {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final blockId = DateTime.now().millisecondsSinceEpoch.toString();
    provider.addDescriptionBlock(widget.node.id, DescriptionBlock(
      id: blockId,
      type: BlockType.text,
      content: "",
    ));
    setState(() {
      _editingBlockId = blockId;
    });
  }

  Future<void> _addAttachmentItem() async {
    final provider = Provider.of<MountMapProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: provider.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Add Attachment", style: TextStyle(color: provider.textColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const CircleAvatar(backgroundColor: Colors.indigoAccent, child: Icon(Icons.link, color: Colors.white, size: 20)),
              title: Text("Add Web Link", style: TextStyle(color: provider.textColor)),
              onTap: () {
                Navigator.pop(context);
                _showAddLinkDialog(provider);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.upload_file, color: Colors.white, size: 20)),
              title: Text("Pick Local File", style: TextStyle(color: provider.textColor)),
              onTap: () {
                Navigator.pop(context);
                _pickAndAddFile(provider);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const CircleAvatar(backgroundColor: Colors.orangeAccent, child: Icon(Icons.add_box_rounded, color: Colors.white, size: 20)),
              title: Text("Create New File", style: TextStyle(color: provider.textColor)),
              onTap: () {
                Navigator.pop(context);
                _showCreateFileDialog(provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLinkDialog(MountMapProvider provider) {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: provider.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Add Web Link", style: TextStyle(color: provider.textColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: provider.textColor),
              decoration: InputDecoration(
                labelText: "Display Name (Optional)",
                labelStyle: TextStyle(color: provider.textColor.withValues(alpha: 0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlCtrl,
              style: TextStyle(color: provider.textColor),
              decoration: InputDecoration(
                labelText: "URL (https://...)",
                labelStyle: TextStyle(color: provider.textColor.withValues(alpha: 0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: "https://google.com",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MountMapColors.teal, foregroundColor: Colors.white),
            onPressed: () {
              if (urlCtrl.text.isNotEmpty) {
                String url = urlCtrl.text;
                if (!url.startsWith('http')) url = 'https://$url';
                String name = nameCtrl.text.isNotEmpty ? nameCtrl.text : url;

                  provider.addDescriptionBlock(widget.node.id, DescriptionBlock(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: BlockType.attachment,
                    attachment: AttachmentItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      value: url,
                      type: 'link',
                    ),
                ));
                Navigator.pop(context);
              }
            },
            child: const Text("ADD LINK"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndAddFile(MountMapProvider provider) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null) {
        for (var file in result.files) {
          if (file.path != null) {
            String permanentPath = await provider.saveAttachmentFile(file.path!, file.name);
            provider.addDescriptionBlock(widget.node.id, DescriptionBlock(
              id: DateTime.now().millisecondsSinceEpoch.toString() + "_" + file.name,
              type: BlockType.attachment,
              attachment: AttachmentItem(
                id: DateTime.now().millisecondsSinceEpoch.toString() + "_" + file.name,
                name: file.name,
                value: permanentPath,
                type: 'file'
              ),
            ));
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to pick file")));
    }
  }

  void _showCreateFileDialog(MountMapProvider provider) {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: provider.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Create New File", style: TextStyle(color: provider.textColor, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          style: TextStyle(color: provider.textColor),
          decoration: InputDecoration(
            labelText: "Filename with extension",
            labelStyle: TextStyle(color: provider.textColor.withValues(alpha: 0.5)),
            hintText: "note.txt",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MountMapColors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                try {
                  final dir = await getApplicationDocumentsDirectory();
                  final fileDir = Directory('${dir.path}/MountAttachments');
                  if (!await fileDir.exists()) await fileDir.create();

                  final file = File('${fileDir.path}/${nameCtrl.text}');
                  if (!await file.exists()) {
                    await file.writeAsString("");
                  }

                  provider.addDescriptionBlock(widget.node.id, DescriptionBlock(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: BlockType.attachment,
                    attachment: AttachmentItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text,
                      value: file.path,
                      type: 'file'
                    ),
                  ));
                  if (!mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("CREATE"),
          ),
        ],
      ),
    );
  }

  void _addTableItem() {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final blockId = DateTime.now().millisecondsSinceEpoch.toString();
    provider.addDescriptionBlock(widget.node.id, DescriptionBlock(
      id: blockId,
      type: BlockType.table,
      tableData: [
        ['Column 1', 'Column 2'],
        ['Data 1', 'Data 2'],
      ],
    ));
    _showTableEditor(provider, widget.node.id, blockId);
  }

  void _addChartItem() {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    _showChartTypePicker(context, provider);
  }

  void _showChartTypePicker(BuildContext context, MountMapProvider provider) {
    final isDark = provider.currentTheme == AppThemeMode.dark;
    final Map<String, List<Map<String, dynamic>>> categories = {
      "FLOW & RELATIONAL": [
        {"name": "Alluvial Diagram", "icon": Icons.waterfall_chart_rounded},
        {"name": "Sankey Diagram", "icon": Icons.subway_rounded},
        {"name": "Chord Diagram", "icon": Icons.donut_large_rounded},
        {"name": "Hyperbolic Tree", "icon": Icons.account_tree_rounded},
      ],
      "COMPARISON & STATS": [
        {"name": "Butterfly Chart", "icon": Icons.compare_arrows_rounded},
        {"name": "Histogram", "icon": Icons.bar_chart_rounded},
        {"name": "Pareto Chart", "icon": Icons.show_chart_rounded},
        {"name": "Radial Bar Chart", "icon": Icons.vignette_rounded},
        {"name": "Rose Chart", "icon": Icons.filter_tilt_shift_rounded},
      ],
      "HIERARCHICAL": [
        {"name": "Treemap", "icon": Icons.grid_view_rounded},
        {"name": "Multi-level Pie Chart", "icon": Icons.pie_chart_rounded},
      ],
      "SCIENTIFIC & DATA": [
        {"name": "Contour Plot", "icon": Icons.waves_rounded},
        {"name": "Taylor Diagram", "icon": Icons.radar_rounded},
        {"name": "Three-dimensional Stream Graph", "icon": Icons.multiline_chart_rounded},
        {"name": "Data Table", "icon": Icons.table_view_rounded},
      ],
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: provider.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("SELECT CHART TYPE",
                    style: TextStyle(color: provider.textColor.withValues(alpha: 0.5), letterSpacing: 3, fontSize: 10, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: provider.textColor.withValues(alpha: 0.5)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: categories.entries.map((category) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Row(
                          children: [
                            Container(width: 4, height: 14, decoration: BoxDecoration(color: MountMapColors.teal, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 10),
                            Text(category.key, style: TextStyle(color: provider.textColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          ],
                        ),
                      ),
                      GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: category.value.length,
                        itemBuilder: (context, index) {
                          final chart = category.value[index];
                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _createChartBlock(provider, chart['name']);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: provider.textColor.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: provider.textColor.withValues(alpha: 0.05)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: MountMapColors.teal.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(chart['icon'] as IconData, color: MountMapColors.teal, size: 24),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    chart['name'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: provider.textColor.withValues(alpha: 0.8), fontSize: 9, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createChartBlock(MountMapProvider provider, String chartType) {
    final blockId = DateTime.now().millisecondsSinceEpoch.toString();

    List<List<String>> initialData = [
      ['Label', 'Value'],
      ['A', '30'],
      ['B', '70'],
    ];

    if (chartType == "Sankey Diagram" || chartType == "Alluvial Diagram" || chartType == "Chord Diagram") {
      initialData = [
        ['Source', 'Target', 'Value'],
        ['A', 'B', '50'],
        ['B', 'C', '30'],
      ];
    } else if (chartType == "Treemap" || chartType == "Multi-level Pie Chart") {
      initialData = [
        ['Parent', 'Child', 'Value'],
        ['Total', 'Category A', '60'],
        ['Total', 'Category B', '40'],
      ];
    } else if (chartType == "Contour Plot") {
      initialData = [
        ['X', 'Y', 'Z'],
        ['10', '20', '35'],
        ['50', '40', '80'],
      ];
    }

    provider.addDescriptionBlock(widget.node.id, DescriptionBlock(
      id: blockId,
      type: BlockType.chart,
      chartType: chartType,
      tableData: initialData,
    ));

    _showTableEditor(provider, widget.node.id, blockId, isChart: true);
  }

  void _showTableEditor(MountMapProvider provider, String nodeId, String blockId, {bool isChart = false}) {
    final node = provider.nodes.firstWhere((n) => n.id == nodeId);
    final block = node.descriptionBlocks.firstWhere((b) => b.id == blockId);
    List<List<String>> data = List.from(block.tableData?.map((row) => List<String>.from(row)) ?? [["", ""]]);
    final isDark = provider.currentTheme == AppThemeMode.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: provider.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: provider.textColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isChart ? "Chart Data Editor" : "Table Data Editor", style: TextStyle(color: provider.textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(icon: const Icon(Icons.add_box_rounded, color: MountMapColors.teal), onPressed: () {
                    setModalState(() { data.add(List.generate(data[0].length, (_) => "")); });
                  }),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Table(
                    border: TableBorder.all(color: provider.textColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    children: data.asMap().entries.map((rowEntry) {
                      int rIdx = rowEntry.key;
                      return TableRow(
                        decoration: BoxDecoration(color: rIdx == 0 ? MountMapColors.teal.withValues(alpha: 0.1) : null),
                        children: rowEntry.value.asMap().entries.map((colEntry) {
                          int cIdx = colEntry.key;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: TextField(
                              controller: TextEditingController(text: colEntry.value),
                              style: TextStyle(color: provider.textColor, fontSize: 12, fontWeight: rIdx == 0 ? FontWeight.bold : FontWeight.normal),
                              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                              onChanged: (val) => data[rIdx][cIdx] = val,
                            ),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          for (var r in data) {
                            r.add("");
                          }
                        });
                      },
                      child: const Text("ADD COLUMN"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: MountMapColors.teal, foregroundColor: Colors.white),
                      onPressed: () {
                        provider.updateDescriptionBlock(nodeId, blockId, tableData: data);
                        Navigator.pop(context);
                      },
                      child: const Text("SAVE CHANGES"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MountMapProvider>(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    final textColor = provider.textColor;
    final cardColor = provider.cardColor;

    // Always get the freshest node data from provider
    NodeModel? node;
    try {
      node = provider.nodes.firstWhere((n) => n.id == widget.node.id);
    } catch (e) {
      node = widget.node;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      width: MediaQuery.of(context).size.width > 600 ? 500 : double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(node.text, textColor, isDark),
          Flexible(
            child: ReorderableListView(
              padding: const EdgeInsets.all(24),
              onReorder: (oldIndex, newIndex) {
                if (oldIndex >= node!.descriptionBlocks.length) return;
                final targetIndex = newIndex > node.descriptionBlocks.length
                    ? node.descriptionBlocks.length
                    : newIndex;
                provider.reorderDescriptionBlock(node.id, oldIndex, targetIndex);
              },
              children: [
                ...node.descriptionBlocks.asMap().entries.map((entry) {
                  return _buildBlock(
                    key: ValueKey(entry.value.id),
                    entry.value,
                    provider,
                    node!,
                    textColor,
                    isDark,
                    entry.key,
                  );
                }),

                Container(
                  key: const ValueKey('tags_section'),
                  padding: const EdgeInsets.only(top: 20, bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("TAGS", Icons.sell_outlined, textColor),
                      const SizedBox(height: 12),
                      _buildTags(node, provider),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildFooter(provider),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, Color textColor, bool isDark) {
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
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
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

  Widget _buildSectionTitle(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: MountMapColors.teal),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBlock(DescriptionBlock block, MountMapProvider provider, NodeModel node, Color textColor, bool isDark, int index, {required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(Icons.drag_indicator_rounded, size: 20, color: textColor.withValues(alpha: 0.2)),
                  ),
                  const SizedBox(width: 8),
                  _buildSectionTitle(block.type.name.toUpperCase(), _getIconForType(block.type), textColor),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                onPressed: () => provider.removeDescriptionBlock(node.id, block.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildBlockContent(block, provider, node, textColor, isDark),
        ],
      ),
    );
  }

  IconData _getIconForType(BlockType type) {
    switch (type) {
      case BlockType.text: return Icons.notes_rounded;
      case BlockType.attachment: return Icons.attach_file_rounded;
      case BlockType.table: return Icons.table_chart_rounded;
      case BlockType.chart: return Icons.bar_chart_rounded;
    }
  }

  Widget _buildBlockContent(DescriptionBlock block, MountMapProvider provider, NodeModel node, Color textColor, bool isDark) {
    switch (block.type) {
      case BlockType.text:
        return _buildTextBlock(block, provider, node, textColor);
      case BlockType.attachment:
        return _buildAttachmentBlock(block, provider, node);
      case BlockType.table:
        return _buildTableBlock(block, provider, node, textColor);
      case BlockType.chart:
        return _buildChartBlock(block, provider, node);
    }
  }

  Widget _buildTextBlock(DescriptionBlock block, MountMapProvider provider, NodeModel node, Color textColor) {
    final isEditing = _editingBlockId == block.id;
    if (!isEditing) {
      return InkWell(
        onTap: () => setState(() => _editingBlockId = block.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: textColor.withValues(alpha: 0.05)),
          ),
          child: Text(
            block.content?.isNotEmpty == true ? block.content! : "Tap to add text...",
            style: TextStyle(
              color: block.content?.isNotEmpty == true ? textColor.withValues(alpha: 0.8) : textColor.withValues(alpha: 0.3),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      );
    }

    return _TextBlockEditor(
      initialContent: block.content ?? "",
      textColor: textColor,
      onSave: (val) {
        provider.updateDescriptionBlock(node.id, block.id, content: val);
        setState(() => _editingBlockId = null);
      },
      onCancel: () => setState(() => _editingBlockId = null),
    );
  }

  Widget _buildAttachmentBlock(DescriptionBlock block, MountMapProvider provider, NodeModel node) {
    final item = block.attachment;
    if (item == null) return const SizedBox();

    final isLink = item.type == 'link';
    IconData icon = Icons.insert_drive_file_rounded;
    Color iconColor = Colors.blueAccent;

    if (isLink) {
      icon = Icons.link_rounded;
      iconColor = Colors.indigoAccent;
    } else {
      final ext = item.value.toLowerCase();
      if (ext.endsWith('.mp3') || ext.endsWith('.wav')) {
        icon = Icons.audiotrack_rounded;
        iconColor = Colors.orangeAccent;
      } else if (ext.endsWith('.mp4') || ext.endsWith('.mov')) {
        icon = Icons.videocam_rounded;
        iconColor = Colors.redAccent;
      } else if (ext.endsWith('.jpg') || ext.endsWith('.png')) {
        icon = Icons.image_rounded;
        iconColor = Colors.greenAccent;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: provider.textColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: provider.textColor.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: () => _openAttachment(item),
        dense: true,
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(item.name, style: TextStyle(color: provider.textColor, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(isLink ? item.value : "LOCAL FILE", style: TextStyle(color: provider.textColor.withValues(alpha: 0.4), fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.open_in_new_rounded, size: 14, color: provider.textColor.withValues(alpha: 0.3)),
      ),
    );
  }

  Future<void> _openAttachment(AttachmentItem item) async {
    try {
      if (item.type == 'link') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AttachmentViewerScreen(item: item)),
        );
      } else {
        // Cek ekstensi untuk in-app viewer
        final path = item.value.toLowerCase();
        final supportedExt = [
          '.jpg', '.jpeg', '.png', '.webp',
          '.txt',
          '.mp3', '.wav', '.m4a',
          '.mp4', '.mp5', '.mov', '.mkv'
        ];

        bool isInAppSupported = supportedExt.any((ext) => path.endsWith(ext));

        if (isInAppSupported) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AttachmentViewerScreen(item: item)),
          );
        } else {
          await OpenFile.open(item.value);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cannot open item: $e"), backgroundColor: Colors.red));
    }
  }

  Widget _buildTableBlock(DescriptionBlock block, MountMapProvider provider, NodeModel node, Color textColor) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: textColor.withValues(alpha: 0.05)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: textColor.withValues(alpha: 0.1), width: 0.5),
              children: (block.tableData ?? []).map((row) => TableRow(
                children: row.map((cell) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(cell, style: TextStyle(color: textColor, fontSize: 12)),
                )).toList(),
              )).toList(),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.edit_rounded, size: 14),
            label: const Text("Edit Table", style: TextStyle(fontSize: 12)),
            onPressed: () => _showTableEditor(provider, node.id, block.id),
          ),
        )
      ],
    );
  }

  Widget _buildChartBlock(DescriptionBlock block, MountMapProvider provider, NodeModel node) {
    return Column(
      children: [
        Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: ChartEnginePainter(
                  chartType: block.chartType ?? 'rose chart',
                  data: NodeModel(id: 'temp', text: '', position: Offset.zero, tableData: block.tableData),
                  isDark: provider.currentTheme == AppThemeMode.dark,
                  visualSettings: const {'intensity': 0.6, 'thickness': 20},
                ),
              ),
              Positioned(
                top: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (block.chartType ?? "CHART").toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.type_specimen_rounded, size: 14),
              label: const Text("Change Type", style: TextStyle(fontSize: 12)),
              onPressed: () => _showChartTypePickerForExistingBlock(provider, node.id, block.id),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: const Text("Edit Data", style: TextStyle(fontSize: 12)),
              onPressed: () => _showTableEditor(provider, node.id, block.id, isChart: true),
            ),
          ],
        )
      ],
    );
  }

  void _showChartTypePickerForExistingBlock(MountMapProvider provider, String nodeId, String blockId) {
    final Map<String, List<Map<String, dynamic>>> categories = {
      "FLOW & RELATIONAL": [
        {"name": "Alluvial Diagram", "icon": Icons.waterfall_chart_rounded},
        {"name": "Sankey Diagram", "icon": Icons.subway_rounded},
        {"name": "Chord Diagram", "icon": Icons.donut_large_rounded},
        {"name": "Hyperbolic Tree", "icon": Icons.account_tree_rounded},
      ],
      "COMPARISON & STATS": [
        {"name": "Butterfly Chart", "icon": Icons.compare_arrows_rounded},
        {"name": "Histogram", "icon": Icons.bar_chart_rounded},
        {"name": "Pareto Chart", "icon": Icons.show_chart_rounded},
        {"name": "Radial Bar Chart", "icon": Icons.vignette_rounded},
        {"name": "Rose Chart", "icon": Icons.filter_tilt_shift_rounded},
      ],
      "HIERARCHICAL": [
        {"name": "Treemap", "icon": Icons.grid_view_rounded},
        {"name": "Multi-level Pie Chart", "icon": Icons.pie_chart_rounded},
      ],
      "SCIENTIFIC & DATA": [
        {"name": "Contour Plot", "icon": Icons.waves_rounded},
        {"name": "Taylor Diagram", "icon": Icons.radar_rounded},
        {"name": "Three-dimensional Stream Graph", "icon": Icons.multiline_chart_rounded},
        {"name": "Data Table", "icon": Icons.table_view_rounded},
      ],
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: provider.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("CHANGE CHART TYPE",
                    style: TextStyle(color: provider.textColor.withValues(alpha: 0.5), letterSpacing: 3, fontSize: 10, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: provider.textColor.withValues(alpha: 0.5)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: categories.entries.map((category) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Row(
                          children: [
                            Container(width: 4, height: 14, decoration: BoxDecoration(color: MountMapColors.teal, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 10),
                            Text(category.key, style: TextStyle(color: provider.textColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          ],
                        ),
                      ),
                      GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: category.value.length,
                        itemBuilder: (context, index) {
                          final chart = category.value[index];
                          return InkWell(
                            onTap: () {
                              provider.updateDescriptionBlock(nodeId, blockId, chartType: chart['name']);
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: provider.textColor.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: provider.textColor.withValues(alpha: 0.05)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: MountMapColors.teal.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(chart['icon'] as IconData, color: MountMapColors.teal, size: 24),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    chart['name'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: provider.textColor.withValues(alpha: 0.8), fontSize: 9, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTags(NodeModel node, MountMapProvider provider) {
    if (node.labels.isEmpty) {
      return Text(
        "No tags added",
        style: TextStyle(color: provider.textColor.withValues(alpha: 0.3), fontSize: 12),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: node.labels.map((l) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: MountMapColors.teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MountMapColors.teal.withValues(alpha: 0.2)),
        ),
        child: Text(
          l.toUpperCase(),
          style: const TextStyle(color: MountMapColors.teal, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      )).toList(),
    );
  }

  Widget _buildFooter(MountMapProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: provider.cardColor,
        border: Border(top: BorderSide(color: provider.textColor.withValues(alpha: 0.1))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionButton('Add Text', Icons.note_add_rounded, _addTextItem, provider.textColor),
            const SizedBox(width: 8),
            _buildActionButton('Add Attachment', Icons.attach_file_rounded, _addAttachmentItem, provider.textColor),
            const SizedBox(width: 8),
            _buildActionButton('Add Table', Icons.table_chart_rounded, _addTableItem, provider.textColor),
            const SizedBox(width: 8),
            _buildActionButton('Add Chart', Icons.bar_chart_rounded, _addChartItem, provider.textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed, Color textColor) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: MountMapColors.teal),
      label: Text(label, style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.8))),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: MountMapColors.teal.withValues(alpha: 0.2)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _TextBlockEditor extends StatefulWidget {
  final String initialContent;
  final Color textColor;
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;

  const _TextBlockEditor({
    required this.initialContent,
    required this.textColor,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_TextBlockEditor> createState() => _TextBlockEditorState();
}

class _TextBlockEditorState extends State<_TextBlockEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _controller,
          maxLines: null,
          autofocus: true,
          style: TextStyle(color: widget.textColor, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: widget.textColor.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            hintText: "Enter text...",
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: widget.onCancel, child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () => widget.onSave(_controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: MountMapColors.teal, foregroundColor: Colors.white),
              child: const Text("SAVE"),
            ),
          ],
        ),
      ],
    );
  }
}
