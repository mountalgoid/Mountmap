import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import '../providers/mountmap_provider.dart';
import '../models/node_model.dart';
import '../widgets/node_widget.dart';
import '../widgets/canvas_painter.dart';
import '../widgets/description_panel.dart';
import '../theme/app_colors.dart';
import 'attachment_viewer_screen.dart';

class MountMapCanvas extends StatefulWidget {
  const MountMapCanvas({super.key});

  @override
  State<MountMapCanvas> createState() => _MountMapCanvasState();
}

class _MountMapCanvasState extends State<MountMapCanvas> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  late AnimationController _animationController;
  Animation<Matrix4>? _cameraAnimation;
  
  final double _canvasSize = 10000.0;
  bool _isNodeInteracting = false;
  bool _isExporting = false;
  bool _showOutline = false;
  String? _multiConnectSourceId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        if (_cameraAnimation != null) {
          _transformationController.value = _cameraAnimation!.value;
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusOnNodes(animate: false);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _focusOnNodes({bool animate = true, Offset? targetPosition}) {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    if (provider.nodes.isEmpty && targetPosition == null) return;

    Offset targetCenter;
    if (targetPosition != null) {
      targetCenter = targetPosition;
    } else {
      double minX = double.infinity, minY = double.infinity;
      double maxX = -double.infinity, maxY = -double.infinity;

      for (var node in provider.nodes) {
        minX = math.min(minX, node.position.dx);
        minY = math.min(minY, node.position.dy);
        maxX = math.max(maxX, node.position.dx + 160);
        maxY = math.max(maxY, node.position.dy + 100);
      }
      targetCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    }

    final screenSize = MediaQuery.of(context).size;
    final double tx = (screenSize.width / 2) - targetCenter.dx;
    final double ty = (screenSize.height / 2) - targetCenter.dy;
    final Matrix4 endMatrix = Matrix4.identity()..setTranslationRaw(tx, ty, 0.0);

    if (animate) {
      _cameraAnimation = Matrix4Tween(
        begin: _transformationController.value,
        end: endMatrix,
      ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
      _animationController.forward(from: 0);
    } else {
      _transformationController.value = endMatrix;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MountMapProvider>(context);

    return Scaffold(
      backgroundColor: provider.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(provider),
      body: Stack(
        children: [
          if (!_showOutline) Positioned.fill(
            child: GestureDetector(
              onTap: () => provider.selectNode(null),
              child: CustomPaint(
                painter: GridPainter(gridColor: Colors.white, isDark: provider.currentTheme == AppThemeMode.dark),
                size: Size.infinite,
              ),
            ),
          ),

          if (!_showOutline) RepaintBoundary(
            key: _repaintKey,
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.05,
              maxScale: 3.0,
              constrained: false,
              panEnabled: !_isNodeInteracting,
              scaleEnabled: !_isNodeInteracting,
              child: SizedBox(
                width: _canvasSize,
                height: _canvasSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: CanvasPainter(
                          provider.nodes,
                          provider.currentTheme,
                          selectedNodeId: provider.selectedNodeId,
                          isDocxMap: provider.activeAsset?.folderName == "DocxMap",
                        ),
                      ),
                    ),
                    ...provider.nodes.map((node) => _buildDirectControlNode(node, provider)),
                  ],
                ),
              ),
            ),
          ),

          if (_isExporting)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: MountMapColors.teal),
                      SizedBox(height: 20),
                      Text("Generating Professional PNG...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),

          _buildNavigationPanel(provider),
          if (_showOutline) _buildOutlineOverlay(provider),
        ],
      ),
    );
  }

  Widget _buildDirectControlNode(NodeModel node, MountMapProvider provider) {
    final bool isSelected = node.id == provider.selectedNodeId;

    return Positioned(
      left: node.position.dx,
      top: node.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) {
          setState(() => _isNodeInteracting = true);
          provider.selectNode(node.id); 
        },
        onPanUpdate: (details) {
          final double scale = _transformationController.value.getMaxScaleOnAxis();
          final Offset delta = details.delta / scale;
          provider.updatePeak(node.id, position: node.position + delta);
        },
        onPanEnd: (_) => setState(() => _isNodeInteracting = false),
        onPanCancel: () => setState(() => _isNodeInteracting = false),
        onTap: () {
          if (_multiConnectSourceId != null) {
            if (_multiConnectSourceId != node.id) {
              provider.toggleCrossConnection(_multiConnectSourceId!, node.id);
            }
          } else {
            provider.selectNode(node.id);
          }
        },
        onDoubleTap: () {
          if (_multiConnectSourceId == null) {
            provider.selectNode(node.id);
            _showNodeActionMenu(node, provider);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(20), 
          color: Colors.transparent, 
          child: NodeUI(
            node: node,
            themeMode: provider.currentTheme,
            isSelected: isSelected,
            isConnecting: _multiConnectSourceId == node.id,
            isDragging: _isNodeInteracting && isSelected,
            isDocxMap: provider.activeAsset?.folderName == "DocxMap",
            onCommand: () {},
          ),
        ),
      ),
    );
  }

  void _showNodeActionMenu(NodeModel node, MountMapProvider provider) {
    final isDark = provider.currentTheme == AppThemeMode.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        decoration: BoxDecoration(
          color: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.54 : 0.1), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuHeader(node, provider),
            Divider(color: isDark ? Colors.white10 : Colors.black12, height: 35),
            
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 20,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _menuIconBtn(provider, Icons.edit_note_rounded, "Rename", Colors.blueAccent,
                  () => _handleRename(node, provider)),
                
                _menuIconBtn(provider, Icons.account_tree_rounded, "Branch", Colors.tealAccent, () {
                  provider.addChildPeak(node.id); Navigator.pop(context);
                }),

                _menuIconBtn(provider, Icons.description_outlined, "Desc", Colors.cyanAccent,
                  () => _handleDescription(node, provider)),

                _menuIconBtn(provider, Icons.control_point_duplicate_rounded, "Duplicate", Colors.purpleAccent,
                  () => _showRecursiveActionDialog(context, "Duplicate", (inc) => provider.duplicateNode(node.id, includeChildren: inc))),

                _menuIconBtn(provider, Icons.content_cut_rounded, "Cut", Colors.pinkAccent,
                  () => _showRecursiveActionDialog(context, "Cut", (inc) => provider.cutNode(node.id, includeChildren: inc))),

                _menuIconBtn(provider, Icons.copy_rounded, "Copy", Colors.grey,
                  () => _showRecursiveActionDialog(context, "Copy", (inc) => provider.copyNode(node.id, includeChildren: inc))),

                if (provider.hasClipboard)
                   _menuIconBtn(provider, Icons.paste_rounded, "Paste", Colors.amberAccent, () {
                     provider.pasteNodeAsChild(node.id); Navigator.pop(context);
                   })
                else
                   _menuIconBtn(provider, Icons.paste_rounded, "Paste", isDark ? Colors.white10 : Colors.black12, () {}),

                _menuIconBtn(provider, Icons.attachment_rounded, "Attach", Colors.indigoAccent,
                  () => _handleAttachmentsManager(node, provider)),

                _menuIconBtn(provider, Icons.sell_outlined, "Tags", Colors.greenAccent,
                  () => _handleTags(node, provider)),
                
                _menuIconBtn(provider, Icons.notifications_active_rounded, "Alert", Colors.orangeAccent,
                  () => _handleAlert(node, provider)),

                _menuIconBtn(provider, Icons.palette_rounded, "Style", Colors.amberAccent,
                  () => _handleStyle(node, provider)),

                _menuIconBtn(provider, Icons.format_list_numbered_rounded, "Number", Colors.blueGrey,
                  () => _handleNumberingMenu(node, provider)),

                _menuIconBtn(provider, Icons.account_tree_rounded, "Flow", Colors.deepOrangeAccent,
                  () => _handleShapeMenu(node, provider)),

                _menuIconBtn(provider, Icons.linear_scale_rounded, "Line", Colors.limeAccent,
                  () => _handleLineLabelMenu(node, provider)),

                _menuIconBtn(provider, Icons.table_chart_rounded, "Data", Colors.lightBlueAccent,
                  () => _handleDiagramData(node, provider)),

                if (provider.activeAsset?.folderName == "DocxMap")
                  _menuIconBtn(provider, Icons.settings_applications_rounded, "Doc Style", Colors.indigoAccent,
                    () => _handleDocSettings(node, provider)),

                _menuIconBtn(provider, Icons.link_rounded, "Connect", Colors.greenAccent, () {
                  Navigator.pop(context);
                  setState(() => _multiConnectSourceId = node.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Select other branches to connect. Tap same branch to disconnect."),
                      action: SnackBarAction(label: "DONE", onPressed: () => setState(() => _multiConnectSourceId = null)),
                      duration: const Duration(seconds: 10),
                    )
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),
            
             SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                label: const Text("Delete Options", style: TextStyle(color: Colors.redAccent)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(vertical: 12)
                ),
                onPressed: () => _showRecursiveActionDialog(context, "Delete", (inc) => provider.deletePeak(node.id, includeChildren: inc), isDelete: true),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _handleAttachmentsManager(NodeModel node, MountMapProvider provider) {
    Navigator.pop(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.54 : 0.1), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Attachments", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 10),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text("Link", style: TextStyle(fontSize: 12)),
                      onPressed: () => _showAddLinkDialog(node, provider),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text("Pick", style: TextStyle(fontSize: 12)),
                      onPressed: () => _pickAndAddFile(node, provider),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.add_box_rounded, size: 18),
                      label: const Text("New", style: TextStyle(fontSize: 12)),
                      onPressed: () => _showCreateFileDialog(node, provider),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: node.attachments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.attachment_rounded, size: 40, color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
                          const SizedBox(height: 10),
                          Text("No attachments yet", style: TextStyle(color: isDark ? Colors.white24 : Colors.black26)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: node.attachments.length,
                      itemBuilder: (context, index) {
                        final item = node.attachments[index];
                        final isLink = item.type == 'link';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isLink ? Colors.indigo.withValues(alpha: 0.2) : Colors.teal.withValues(alpha: 0.2),
                              child: Icon(isLink ? Icons.link : Icons.insert_drive_file, color: isLink ? Colors.indigoAccent : Colors.tealAccent, size: 20),
                            ),
                            title: Text(item.name, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
                            subtitle: Text(item.value, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: PopupMenuButton(
                              icon: Icon(Icons.more_vert, color: isDark ? Colors.white54 : Colors.black54),
                              color: isDark ? const Color(0xFF252836) : Colors.white,
                              itemBuilder: (context) => [
                                PopupMenuItem(value: 'open', child: Text("Open", style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
                                PopupMenuItem(value: 'rename', child: Text("Rename", style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
                                if (isLink) PopupMenuItem(value: 'edit_url', child: Text("Edit URL", style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
                                const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.redAccent))),
                              ],
                              onSelected: (value) {
                                if (value == 'open') _openAttachment(item);
                                if (value == 'rename') _renameAttachment(node, provider, item);
                                if (value == 'edit_url') _editAttachmentValue(node, provider, item);
                                if (value == 'delete') provider.removeAttachment(node.id, item.id);
                              },
                            ),
                            onTap: () => _openAttachment(item),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateFileDialog(NodeModel node, MountMapProvider provider) {
    final nameCtrl = TextEditingController();
    final isDark = provider.currentTheme == AppThemeMode.dark;
    _showStyledDialog(
      "Create New File",
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Filename with extension",
              labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              hintText: "note.txt, index.html, style.css",
              hintStyle: TextStyle(color: isDark ? Colors.white10 : Colors.black12)
            ),
          ),
        ],
      ),
      () async {
        if (nameCtrl.text.isNotEmpty) {
           try {
             final dir = await getApplicationDocumentsDirectory();
             final fileDir = Directory('${dir.path}/MountAttachments');
             if (!await fileDir.exists()) await fileDir.create();

             final file = File('${fileDir.path}/${nameCtrl.text}');
             if (!await file.exists()) {
               await file.writeAsString("");
             }

             final newItem = AttachmentItem(
               id: DateTime.now().millisecondsSinceEpoch.toString(),
               name: nameCtrl.text,
               value: file.path,
               type: 'file'
             );
             provider.addAttachment(node.id, newItem);
             if (!mounted) return;
             Navigator.pop(context);
           } catch (e) {
             if (!mounted) return;
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
           }
        }
      }
    );
  }

  void _showAddLinkDialog(NodeModel node, MountMapProvider provider) {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final isDark = provider.currentTheme == AppThemeMode.dark;

    _showStyledDialog(
      "Add Web Link", 
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(labelText: "Display Name (Optional)", labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: urlCtrl,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(labelText: "URL (https://...)", labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54), hintText: "https://google.com", hintStyle: TextStyle(color: isDark ? Colors.white10 : Colors.black12)),
          ),
        ],
      ), 
      () {
        if (urlCtrl.text.isNotEmpty) {
          String url = urlCtrl.text;
          if (!url.startsWith('http')) url = 'https://$url';
          String name = nameCtrl.text.isNotEmpty ? nameCtrl.text : url;
          final newItem = AttachmentItem(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, value: url, type: 'link');
          provider.addAttachment(node.id, newItem);
          Navigator.pop(context);
        }
      }
    );
  }

  Future<void> _pickAndAddFile(NodeModel node, MountMapProvider provider) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null) {
        for (var file in result.files) {
          if (file.path != null) {
            String permanentPath = await provider.saveAttachmentFile(file.path!, file.name);
            final newItem = AttachmentItem(
              id: DateTime.now().millisecondsSinceEpoch.toString() + "_" + file.name,
              name: file.name,
              value: permanentPath,
              type: 'file'
            );
            provider.addAttachment(node.id, newItem);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to pick file")));
    }
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

  void _editAttachmentValue(NodeModel node, MountMapProvider provider, AttachmentItem item) {
    final valCtrl = TextEditingController(text: item.value);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    _showStyledDialog(
      "Edit URL",
      TextField(controller: valCtrl, autofocus: true, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      () {
        List<AttachmentItem> updatedList = List.from(node.attachments);
        final index = updatedList.indexWhere((a) => a.id == item.id);
        if (index != -1) {
          updatedList[index].value = valCtrl.text;
          provider.updatePeak(node.id, attachments: updatedList);
        }
        Navigator.pop(context);
      }
    );
  }

  void _renameAttachment(NodeModel node, MountMapProvider provider, AttachmentItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    _showStyledDialog(
      "Rename Attachment", 
      TextField(controller: nameCtrl, autofocus: true, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      () {
        List<AttachmentItem> updatedList = List.from(node.attachments);
        final index = updatedList.indexWhere((a) => a.id == item.id);
        if (index != -1) {
          updatedList[index].name = nameCtrl.text;
          provider.updatePeak(node.id, attachments: updatedList);
        }
        Navigator.pop(context);
      }
    );
  }

  void _handleRename(NodeModel node, MountMapProvider provider) {
    Navigator.pop(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    final c = TextEditingController(text: node.text);
    _showStyledDialog("Rename Node", TextField(controller: c, autofocus: true, style: TextStyle(color: isDark ? Colors.white : Colors.black87)), () { provider.updatePeak(node.id, text: c.text); Navigator.pop(context); });
  }

  void _handleDescription(NodeModel node, MountMapProvider provider) {
    Navigator.pop(context); // Close action menu

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ProfessionalDescriptionPanel(
          node: node,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _handleDiagramData(NodeModel node, MountMapProvider provider) {
    Navigator.pop(context);
    if (node.shapeType == 'table') {
      _showTableEditor(node, provider);
    } else {
      _showListEditor(node, provider);
    }
  }

  void _showTableEditor(NodeModel node, MountMapProvider provider) {
    List<List<String>> data = List.from(node.tableData ?? [["", ""]]);
    final isDark = provider.currentTheme == AppThemeMode.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Text("Table Data Editor", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Table(
                      defaultColumnWidth: const FixedColumnWidth(100),
                      border: TableBorder.all(color: Colors.white24),
                      children: data.asMap().entries.map((rowEntry) {
                        int rIdx = rowEntry.key;
                        return TableRow(
                          children: rowEntry.value.asMap().entries.map((colEntry) {
                            int cIdx = colEntry.key;
                            return Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: TextField(
                                controller: TextEditingController(text: colEntry.value),
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12),
                                decoration: const InputDecoration(border: InputBorder.none),
                                onSubmitted: (val) => data[rIdx][cIdx] = val,
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(onPressed: () { setModalState(() { data.add(List.generate(data[0].length, (_) => "")); }); }, child: const Text("Add Row")),
                  TextButton(onPressed: () { setModalState(() { for (var r in data) {
                    r.add("");
                  } }); }, child: const Text("Add Col")),
                  ElevatedButton(onPressed: () { provider.updatePeak(node.id, tableData: data); Navigator.pop(context); }, child: const Text("SAVE")),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showListEditor(NodeModel node, MountMapProvider provider) {
    List<String> items = List.from(node.dataList ?? [""]);
    final isDark = provider.currentTheme == AppThemeMode.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Text(node.shapeType == 'triangle' ? "Pyramid Levels" : "Timeline Items", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, idx) => ListTile(
                    title: TextField(
                      controller: TextEditingController(text: items[idx]),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      onChanged: (val) => items[idx] = val,
                    ),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => setModalState(() => items.removeAt(idx))),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(onPressed: () => setModalState(() => items.add("")), child: const Text("Add Item")),
                  ElevatedButton(onPressed: () { provider.updatePeak(node.id, dataList: items); Navigator.pop(context); }, child: const Text("SAVE")),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _handleTags(NodeModel node, MountMapProvider provider) {
    Navigator.pop(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    final TextEditingController customTagController = TextEditingController();
    final List<String> presets = ["Priority", "Research", "Done", "Pending", "Idea", "Bug", "Review"];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.54 : 0.1), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Manage Tags", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                    if (node.labels.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all_rounded, size: 16, color: Colors.redAccent),
                        label: const Text("Clear All", style: TextStyle(color: Colors.redAccent)),
                        onPressed: () {
                          provider.updatePeak(node.id, labels: []);
                          setModalState(() {});
                        },
                      )
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: node.labels.map((l) => Chip(
                    label: Text(l, style: const TextStyle(fontSize: 10)),
                    onDeleted: () {
                      List<String> newList = List.from(node.labels)..remove(l);
                      provider.updatePeak(node.id, labels: newList);
                      setModalState(() {});
                    },
                  )).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customTagController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: "Add tag...",
                          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                          filled: true, fillColor: isDark ? Colors.black26 : Colors.grey.withValues(alpha: 0.1),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty && !node.labels.contains(value)) {
                            List<String> newList = List.from(node.labels)..add(value);
                            provider.updatePeak(node.id, labels: newList);
                            customTagController.clear();
                            setModalState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      onPressed: () {
                        final value = customTagController.text;
                        if (value.isNotEmpty && !node.labels.contains(value)) {
                          List<String> newList = List.from(node.labels)..add(value);
                          provider.updatePeak(node.id, labels: newList);
                          customTagController.clear();
                          setModalState(() {});
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                const Text("Presets", style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: presets.map((t) => ActionChip(
                    label: Text(t),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: node.labels.contains(t) ? MountMapColors.teal : Colors.white10,
                    side: BorderSide.none,
                    labelStyle: TextStyle(color: node.labels.contains(t) ? Colors.black : Colors.white70, fontWeight: FontWeight.w600),
                    onPressed: () {
                      List<String> newList = List.from(node.labels);
                      if (newList.contains(t)) {
                        newList.remove(t);
                      } else {
                        newList.add(t);
                      }
                      provider.updatePeak(node.id, labels: newList);
                      setModalState(() {});
                    },
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRecursiveActionDialog(BuildContext context, String action, Function(bool) onConfirm, {bool isDelete = false}) {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final isDark = provider.currentTheme == AppThemeMode.dark;

    _showStyledDialog(
      "$action Options",
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text("Just this branch", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text(isDelete ? "Children will be moved to parent" : "Children will not be included", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
            onTap: () { Navigator.pop(context); onConfirm(false); Navigator.pop(context); },
          ),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text("Include all descendants", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text("Operate on the entire subtree", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
            onTap: () { Navigator.pop(context); onConfirm(true); Navigator.pop(context); },
          ),
        ],
      ),
      () { Navigator.pop(context); },
      confirmText: "CANCEL",
      icon: isDelete ? Icons.delete_sweep_rounded : Icons.copy_all_rounded,
    );
  }

  void _handleAlert(NodeModel node, MountMapProvider provider) {
    Navigator.pop(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.54 : 0.1), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Colors.orangeAccent, size: 22),
                      const SizedBox(width: 10),
                      Text("Set Alert", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (node.alertEnabled)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                      label: const Text("Remove", style: TextStyle(color: Colors.redAccent)),
                      onPressed: () {
                        provider.updatePeak(node.id, alertMessage: null, alertDate: null, alertEnabled: false);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Alert removed"), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              
              if (node.alertEnabled && node.alertDate != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: node.hasActiveAlert ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: node.hasActiveAlert ? Colors.greenAccent : Colors.redAccent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        node.hasActiveAlert ? Icons.check_circle_outline : Icons.error_outline,
                        color: node.hasActiveAlert ? Colors.greenAccent : Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              node.hasActiveAlert ? "Active Alert" : "Alert Overdue",
                              style: TextStyle(
                                color: node.hasActiveAlert ? Colors.greenAccent : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${node.alertDate!.day}/${node.alertDate!.month}/${node.alertDate!.year} ${node.alertDate!.hour}:${node.alertDate!.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            if (node.alertMessage != null && node.alertMessage!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  node.alertMessage!,
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              
              if (node.alertEnabled && node.alertDate != null)
                const SizedBox(height: 15),
              
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.edit_calendar_rounded, color: Colors.black),
                label: Text(
                  node.alertEnabled ? "Update Alert" : "Create New Alert",
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showAlertEditor(node, provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlertEditor(NodeModel node, MountMapProvider provider) {
    Navigator.pop(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    
    final messageCtrl = TextEditingController(text: node.alertMessage ?? '');
    DateTime selectedDate = node.alertDate ?? DateTime.now().add(const Duration(hours: 1));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: provider.cardColor,
          title: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: Colors.orangeAccent),
              const SizedBox(width: 10),
              Text("Configure Alert", style: TextStyle(color: provider.textColor, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Alert Message (Optional)", style: TextStyle(color: provider.textColor.withValues(alpha: 0.7), fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: messageCtrl,
                  maxLines: 2,
                  style: TextStyle(color: provider.textColor),
                  decoration: InputDecoration(
                    hintText: "e.g., Complete this task!",
                    hintStyle: TextStyle(color: provider.textColor.withValues(alpha: 0.24)),
                    filled: true,
                    fillColor: provider.textColor.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                Text("Alert Date & Time", style: TextStyle(color: provider.textColor.withValues(alpha: 0.7), fontSize: 12)),
                const SizedBox(height: 8),
                
                Container(
                  decoration: BoxDecoration(
                    color: provider.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.tealAccent, size: 20),
                    title: Text(
                      "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                      style: TextStyle(color: provider.textColor),
                    ),
                    trailing: Icon(Icons.arrow_drop_down, color: provider.textColor.withValues(alpha: 0.54)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) => Theme(
                          data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: Colors.tealAccent,
                              onPrimary: Colors.black,
                              surface: provider.cardColor,
                              onSurface: provider.textColor,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                
                Container(
                  decoration: BoxDecoration(
                    color: provider.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.orangeAccent, size: 20),
                    title: Text(
                      "${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(color: provider.textColor),
                    ),
                    trailing: Icon(Icons.arrow_drop_down, color: provider.textColor.withValues(alpha: 0.54)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                        builder: (context, child) => Theme(
                          data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: Colors.orangeAccent,
                              onPrimary: Colors.black,
                              surface: provider.cardColor,
                              onSurface: provider.textColor,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedTime = picked;
                          selectedDate = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            picked.hour,
                            picked.minute,
                          );
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("CANCEL", style: TextStyle(color: provider.textColor.withValues(alpha: 0.24))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                provider.updatePeak(
                  node.id,
                  alertMessage: messageCtrl.text.isEmpty ? null : messageCtrl.text,
                  alertDate: selectedDate,
                  alertEnabled: true,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Alert set for ${selectedDate.day}/${selectedDate.month} at ${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}",
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text("SAVE ALERT"),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNumberingMenu(NodeModel node, MountMapProvider provider) {
    Navigator.pop(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.54 : 0.1), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Auto-Numbering", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.account_tree_rounded, color: Colors.tealAccent),
              title: Text("Number All (Hierarchical)", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () { provider.applyNumberingAll(); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.reorder_rounded, color: Colors.amberAccent),
              title: Text("Number This Subtree", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () { provider.applyNumberingSubtree(node.id); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.looks_one_rounded, color: Colors.blueAccent),
              title: Text("Number Immediate Children", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () { provider.applyNumberingImmediate(node.id); Navigator.pop(context); },
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.layers_clear_rounded, color: Colors.redAccent),
              title: const Text("Clear Numbering", style: TextStyle(color: Colors.redAccent)),
              onTap: () { provider.clearNumbering(node.id); Navigator.pop(context); },
            ),
          ],
        ),
      ),
    );
  }

  void _handleLineLabelMenu(NodeModel node, MountMapProvider provider) {
    Navigator.pop(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    final ctrl = TextEditingController(text: node.connectionLabel);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
        title: Text("Connection Label", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: "e.g. Yes, No, Data Flow",
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white38 : Colors.black38))),
          ElevatedButton(
            onPressed: () {
              provider.updatePeak(node.id, connectionLabel: ctrl.text.isEmpty ? "-clear-" : ctrl.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _handleShapeMenu(NodeModel node, MountMapProvider provider) {
    Navigator.pop(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    final shapes = [
      {'id': 'box', 'name': 'Process', 'icon': Icons.check_box_outline_blank_rounded},
      {'id': 'oval', 'name': 'Start/End', 'icon': Icons.pause_circle_outline_rounded},
      {'id': 'diamond', 'name': 'Decision', 'icon': Icons.diamond_outlined},
      {'id': 'parallelogram', 'name': 'In/Out', 'icon': Icons.input_rounded},
      {'id': 'circle', 'name': 'Connector', 'icon': Icons.circle_outlined},
      {'id': 'hexagon', 'name': 'Hexagon', 'icon': Icons.hexagon_outlined},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.54 : 0.1), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Flow Chart Design", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: shapes.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      IconButton.filledTonal(
                        iconSize: 32,
                        isSelected: node.shapeType == s['id'],
                        onPressed: () { provider.updatePeak(node.id, shapeType: s['id'] as String); Navigator.pop(context); },
                        icon: Icon(s['icon'] as IconData),
                      ),
                      const SizedBox(height: 8),
                      Text(s['name'] as String, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _handleStyle(NodeModel node, MountMapProvider provider) {
    Navigator.pop(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;

    final List<Color> bodyPresets = [
      const Color(0xFF161B22),
      MountMapColors.violet,
      MountMapColors.teal,
      const Color(0xFFE91E63),
      const Color(0xFFFF9800),
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
    ];

    final List<Color> textPresets = [
      Colors.white,
      Colors.black,
      Colors.tealAccent,
      Colors.amberAccent,
      Colors.pinkAccent,
      const Color(0xFFE6EDF3),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.54 : 0.1), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.palette_rounded, color: Colors.amberAccent, size: 22),
                      const SizedBox(width: 10),
                      Text("Customize Branch", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      provider.updatePeak(
                        node.id,
                        bodyColor: -1,
                        textColor: -1,
                        iconColor: -1,
                        isGradient: false,
                        isTextGradient: false,
                        isIconGradient: false,
                      );
                      Navigator.pop(context);
                    },
                    child: const Text("Reset", style: TextStyle(color: Colors.redAccent)),
                  )
                ],
              ),
              const SizedBox(height: 20),

              Text("Body Color", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: bodyPresets.map((color) => _colorPickerItem(
                  color,
                  node.bodyColor == color.toARGB32(),
                  () {
                    provider.updatePeak(node.id, bodyColor: color.toARGB32());
                    setModalState(() {});
                  }
                )).toList(),
              ),

              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Gradient Body", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                subtitle: Text("Apply consistent Teal/Violet gradient", style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 11)),
                value: node.isGradient,
                activeColor: MountMapColors.teal,
                onChanged: (val) {
                  provider.updatePeak(node.id, isGradient: val);
                  setModalState(() {});
                },
              ),

              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Gradient Text", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                value: node.isTextGradient,
                activeColor: MountMapColors.teal,
                onChanged: (val) {
                  provider.updatePeak(node.id, isTextGradient: val);
                  setModalState(() {});
                },
              ),

              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Gradient Icon", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                value: node.isIconGradient,
                activeColor: MountMapColors.teal,
                onChanged: (val) {
                  provider.updatePeak(node.id, isIconGradient: val);
                  setModalState(() {});
                },
              ),

              const SizedBox(height: 20),
              Text("Text Color", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: textPresets.map((color) => _colorPickerItem(
                  color,
                  node.textColor == color.toARGB32(),
                  () {
                    provider.updatePeak(node.id, textColor: color.toARGB32());
                    setModalState(() {});
                  }
                )).toList(),
              ),

              const SizedBox(height: 20),
              Text("Icon & Indicator Color", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: textPresets.map((color) => _colorPickerItem(
                  color,
                  node.iconColor == color.toARGB32(),
                  () {
                    provider.updatePeak(node.id, iconColor: color.toARGB32());
                    setModalState(() {});
                  }
                )).toList(),
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MountMapColors.teal,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("DONE", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorPickerItem(Color color, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)
          ] : null,
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }

  void _showStyledDialog(String t, Widget c, VoidCallback f, {String confirmText = "SAVE", bool isDanger = false, IconData icon = Icons.edit_note_rounded}) {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final Color accentColor = isDanger ? Colors.redAccent : MountMapColors.teal;
    final isDark = provider.currentTheme == AppThemeMode.dark;

    showDialog(
      context: context,
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: provider.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.54 : 0.1), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Icon(icon, color: accentColor, size: 24),
                  const SizedBox(width: 12),
                  Text(t, style: TextStyle(color: provider.textColor, fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                ]),
                const SizedBox(height: 20),
                Material(color: Colors.transparent, child: c),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: provider.textColor.withValues(alpha: 0.24)))),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                    onPressed: f,
                    child: Text(confirmText),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleDocSettings(NodeModel node, MountMapProvider provider) {
    Navigator.pop(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    final markerCtrl = TextEditingController(text: node.marker ?? "DOC");

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("DocxMap Settings", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                Text("Document Type / Label", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                const SizedBox(height: 10),
                TextField(
                  controller: markerCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "e.g. PDF, IMG, VIDEO, WEB, REPORT",
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => provider.updatePeak(node.id, marker: val),
                ),

                const SizedBox(height: 20),
                Text("Paper Presets", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _presetBtn("Classic", node.shapeType != 'hexagon', () {
                      provider.updatePeak(node.id, shapeType: 'box');
                      setModalState(() {});
                    }, isDark),
                    const SizedBox(width: 10),
                    _presetBtn("Modern", node.shapeType == 'hexagon', () {
                      provider.updatePeak(node.id, shapeType: 'hexagon');
                      setModalState(() {});
                    }, isDark),
                  ],
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MountMapColors.teal,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presetBtn(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? MountMapColors.teal : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? MountMapColors.teal : Colors.transparent),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _menuIconBtn(MountMapProvider provider, IconData i, String l, Color c, VoidCallback t) {
    final isDark = provider.currentTheme == AppThemeMode.dark;
    return InkWell(
      onTap: t,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
            child: Icon(i, color: c, size: 24)
          ),
          const SizedBox(height: 8),
          Text(l, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10, fontWeight: FontWeight.w600))
        ]
      )
    );
  }
  
  Widget _buildMenuHeader(NodeModel n, MountMapProvider provider) {
    final isDark = provider.currentTheme == AppThemeMode.dark;
    return Row(
      children: [
        const CircleAvatar(backgroundColor: MountMapColors.teal, child: Icon(Icons.hub_rounded, color: Colors.white)),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.text, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              Text(n.parentId == null ? "Root Node" : "Child Node", style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 10))
            ]
          )
        )
      ]
    );
  }

  Widget _buildNavigationPanel(MountMapProvider provider) {
    final isDark = provider.currentTheme == AppThemeMode.dark;
    final cardColor = isDark ? MountMapColors.darkCard : MountMapColors.lightCard;
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    return Positioned(
      bottom: 30, left: 0, right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1), blurRadius: 15, offset: const Offset(0, 5))]
          ),
          child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _navButton(provider, Icons.arrow_back_ios_new_rounded, () {
                    provider.selectPreviousNode();
                    final n = provider.getSelectedNode() ?? provider.nodes.firstWhere((n) => n.id == provider.selectedNodeId, orElse: () => provider.nodes.first);
                    _focusOnNodes(targetPosition: n.position);
                  }),
                  _divider(provider),
                  _navButton(provider, Icons.auto_graph_rounded, () {
                    provider.autoLayout();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✨ Structure Auto-Organized"), duration: Duration(milliseconds: 800), backgroundColor: MountMapColors.teal));
                    Future.delayed(const Duration(milliseconds: 150), () { _focusOnNodes(); });
                  }, isAccent: true),
                  _divider(provider),
                  _navButton(provider, Icons.more_horiz_rounded, () {
                    if (provider.selectedNodeId != null) {
                      final node = provider.nodes.firstWhere((n) => n.id == provider.selectedNodeId);
                      _focusOnNodes(targetPosition: node.position);
                      _showNodeActionMenu(node, provider);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a peak first"), duration: Duration(milliseconds: 800)));
                    }
                  }, isPrimary: true),

                  if (provider.hasClipboard) ...[
                    _divider(provider),
                    _navButton(provider, Icons.paste_rounded, () {
                      if (provider.selectedNodeId != null) {
                        provider.pasteNodeAsChild(provider.selectedNodeId!);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pasted successfully"), duration: Duration(milliseconds: 800)));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select parent node first"), duration: Duration(milliseconds: 800)));
                      }
                    }, isAccent: true),
                  ],

                  _divider(provider),
                  _navButton(provider, Icons.arrow_forward_ios_rounded, () {
                    provider.selectNextNode();
                    final n = provider.getSelectedNode() ?? provider.nodes.firstWhere((n) => n.id == provider.selectedNodeId, orElse: () => provider.nodes.first);
                    _focusOnNodes(targetPosition: n.position);
                  })
                ]
              ),
            ),
          ),
        );
  }
  
  Widget _divider(MountMapProvider provider) => Container(width: 1, height: 20, color: provider.currentTheme == AppThemeMode.dark ? Colors.white10 : Colors.black12, margin: const EdgeInsets.symmetric(horizontal: 8));
  Widget _navButton(MountMapProvider provider, IconData icon, VoidCallback onTap, {bool isPrimary = false, bool isAccent = false}) {
    final isDark = provider.currentTheme == AppThemeMode.dark;
    Color c = isDark ? Colors.white70 : Colors.black54;
    if (isPrimary) c = MountMapColors.teal;
    if (isAccent) c = Colors.orangeAccent;
    return IconButton(icon: Icon(icon, color: c, size: (isPrimary || isAccent) ? 26 : 22), onPressed: onTap, splashRadius: 24);
  }

  PreferredSizeWidget _buildAppBar(MountMapProvider provider) {
    return AppBar(
      backgroundColor: provider.backgroundColor,
      elevation: 0,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(provider.activeAsset?.title ?? "STRATEGY CANVAS",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: provider.textColor)),
        const Text("Elements Workspace", style: TextStyle(fontSize: 10, color: MountMapColors.teal))]),
      actions: [
        IconButton(
          icon: const Icon(Icons.image_rounded, color: MountMapColors.teal),
          tooltip: "Export PNG",
          onPressed: _exportToPNG,
        ),
        IconButton(
          icon: Icon(_showOutline ? Icons.grid_view_rounded : Icons.list_alt_rounded, color: provider.textColor.withValues(alpha: 0.7)),
          onPressed: () => setState(() => _showOutline = !_showOutline),
        ),
        IconButton(
          icon: Icon(provider.currentTheme == AppThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: provider.textColor.withValues(alpha: 0.7)),
          onPressed: () => provider.toggleTheme(),
        ),
        IconButton(icon: Icon(Icons.search_rounded, color: provider.textColor.withValues(alpha: 0.7)), onPressed: () => _showSearch(provider)),
        IconButton(icon: const Icon(Icons.center_focus_strong_rounded, color: MountMapColors.teal), onPressed: () => _focusOnNodes()),
        IconButton(icon: Icon(Icons.add_circle_outline_rounded, color: provider.textColor), onPressed: () { final center = _transformationController.toScene(MediaQuery.of(context).size.center(Offset.zero)); provider.addPeak(center); })
      ]);
  }

  Future<void> _exportToPNG() async {
    setState(() => _isExporting = true);

    // Memberikan waktu kecil agar UI loading muncul
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw "Could not find canvas boundary";

      // Capturing with high pixel ratio for "Professional" clarity
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) throw "Failed to generate PNG data";

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final fileName = "MountMap_${DateTime.now().millisecondsSinceEpoch}.png";
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      final provider = Provider.of<MountMapProvider>(context, listen: false);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'MountMap Professional Export: ${provider.activeAsset?.title ?? "Strategy Canvas"}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildOutlineOverlay(MountMapProvider provider) {
    // Hierarchical Outline View
    final rootNodes = provider.nodes.where((n) => n.parentId == null).toList();
    final isDark = provider.currentTheme == AppThemeMode.dark;

    return Container(
      color: isDark
          ? const Color(0xFF0F111A).withValues(alpha: 0.95)
          : Colors.white.withValues(alpha: 0.95),
      padding: const EdgeInsets.only(top: 100), // Push below AppBar
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Canvas Outline",
                style: TextStyle(
                  color: provider.currentTheme == AppThemeMode.dark ? Colors.white : Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.bold
                )
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => setState(() => _showOutline = false),
              )
            ],
          ),
          const SizedBox(height: 20),
          if (provider.nodes.isEmpty)
            const Center(child: Text("No nodes found in this canvas", style: TextStyle(color: Colors.grey)))
          else
            ...rootNodes.map((node) => _buildOutlineNodeTile(node, provider)),
        ],
      ),
    );
  }

  Widget _buildOutlineNodeTile(NodeModel node, MountMapProvider provider) {
    final children = provider.nodes.where((n) => n.parentId == node.id).toList();
    final isSelected = node.id == provider.selectedNodeId;
    final isDark = provider.currentTheme == AppThemeMode.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(
            children.isEmpty ? Icons.circle_outlined : Icons.account_tree_rounded,
            size: 16,
            color: isSelected ? MountMapColors.teal : Colors.grey,
          ),
          title: Text(
            node.text,
            style: TextStyle(
              color: isSelected ? MountMapColors.teal : (isDark ? Colors.white : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (node.description != null && node.description!.isNotEmpty)
                Text(node.description!, style: const TextStyle(fontSize: 10, color: Colors.grey)),

              if (node.labels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 4,
                    children: node.labels.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: MountMapColors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(tag, style: const TextStyle(fontSize: 8, color: MountMapColors.teal)),
                    )).toList(),
                  ),
                ),

              _buildOutlineStatusIndicators(node),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                onPressed: () => _showNodeActionMenu(node, provider),
              ),
              if (isSelected) const Icon(Icons.check_circle, color: MountMapColors.teal, size: 16),
            ],
          ),
          onTap: () {
            provider.selectNode(node.id);
            _focusOnNodes(targetPosition: node.position);
            setState(() => _showOutline = false);
          },
        ),

        if (children.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 23.5), // Center of leading icon (approx 16 + 7.5)
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isSelected ? MountMapColors.teal.withValues(alpha: 0.3) : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              children: children.map((child) => _buildOutlineNodeTile(child, provider)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildOutlineStatusIndicators(NodeModel node) {
    bool hasFile = node.attachments.any((a) => a.type == 'file');
    bool hasLink = node.attachments.any((a) => a.type == 'link');

    if (!(node.note != null && node.note!.isNotEmpty) && !hasFile && !hasLink && !(node.alertEnabled && node.alertDate != null)) {
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.note != null && node.note!.isNotEmpty)
            const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.notes_rounded, size: 12, color: Colors.grey)),
          if (hasFile)
            const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.attach_file_rounded, size: 12, color: Colors.grey)),
          if (hasLink || node.linkedAssetId != null)
            const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.link_rounded, size: 12, color: MountMapColors.teal)),
          if (node.alertEnabled && node.alertDate != null)
             Padding(padding: const EdgeInsets.only(right: 4), child: Icon(node.hasActiveAlert ? Icons.notifications_active : Icons.notification_important, size: 12, color: Colors.orangeAccent)),
        ],
      ),
    );
  }
  void _showSearch(MountMapProvider p) { showSearch(context: context, delegate: NodeSearchDelegate(nodes: p.nodes, provider: p, onSelect: (n) => _focusOnNodes(targetPosition: n.position))); }
}

class GridPainter extends CustomPainter {
  final Color gridColor;
  final bool isDark;
  GridPainter({required this.gridColor, required this.isDark});
  @override void paint(Canvas c, Size s) { final p = Paint()..color = isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02)..strokeWidth = 1.0; const double step = 50.0; for (double i = 0; i <= s.width; i += step) {
    c.drawLine(Offset(i, 0), Offset(i, s.height), p);
  } for (double i = 0; i <= s.height; i += step) {
    c.drawLine(Offset(0, i), Offset(s.width, i), p);
  } }
  @override bool shouldRepaint(CustomPainter o) => false;
}

class NodeSearchDelegate extends SearchDelegate {
  final List<NodeModel> nodes;
  final MountMapProvider provider;
  final Function(NodeModel) onSelect;

  NodeSearchDelegate({required this.nodes, required this.provider, required this.onSelect});

  @override ThemeData appBarTheme(BuildContext context) {
    final bool isDark = provider.currentTheme == AppThemeMode.dark;
    return (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
      scaffoldBackgroundColor: provider.backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: provider.cardColor,
        iconTheme: IconThemeData(color: provider.textColor),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: provider.textColor.withValues(alpha: 0.5)),
        border: InputBorder.none,
      ),
    );
  }

  @override List<Widget>? buildActions(BuildContext c) => [IconButton(icon: Icon(Icons.clear, color: provider.textColor), onPressed: () => query = '')];
  @override Widget? buildLeading(BuildContext c) => IconButton(icon: Icon(Icons.arrow_back, color: provider.textColor), onPressed: () => close(c, null));
  @override Widget buildResults(BuildContext c) => _list();
  @override Widget buildSuggestions(BuildContext c) => _list();

  Widget _list() {
    final results = nodes.where((n) => n.text.toLowerCase().contains(query.toLowerCase())).toList();
    return Container(
      color: provider.backgroundColor,
      child: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, i) => ListTile(
          title: Text(results[i].text, style: TextStyle(color: provider.textColor)),
          onTap: () { onSelect(results[i]); close(context, null); }
        ),
      ),
    );
  }
}
