import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/node_model.dart';
import '../models/mindmap_model.dart';
import '../theme/app_colors.dart';
import '../services/notification_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, warm }

class MountMapProvider extends ChangeNotifier {
  SharedPreferences? _prefs;
  // --- STATE VARIABLES ---
  List<MindMapAsset> _assets = [];      // Semua file/folder
  List<NodeModel> _nodes = [];          // Node yang sedang aktif di canvas
  MindMapAsset? _activeAsset;           // File yang sedang dibuka
  AppThemeMode _currentTheme = AppThemeMode.dark;
  String? _currentFolderId;             // Navigasi folder
  double _dashboardScale = 1.0;         // Skala zoom di dashboard

  // Selection & Node Clipboard
  String? _selectedNodeId;
  NodeModel? _clipboardNode; 

  // Asset Clipboard (File/Folder)
  MindMapAsset? _clipboardAsset;
  bool _isCutOperation = false;
  List<String> _attendanceDates = [];

  // --- CONSTRUCTOR ---
  MountMapProvider() {
    loadFromDisk();
  }

  // --- GETTERS ---
  List<MindMapAsset> get assets => _assets;
  List<String> get attendanceDates => _attendanceDates;
  List<NodeModel> get nodes => _nodes;
  MindMapAsset? get activeAsset => _activeAsset;
  AppThemeMode get currentTheme => _currentTheme;
  String? get currentFolderId => _currentFolderId;
  String? get selectedNodeId => _selectedNodeId;
  double get dashboardScale => _dashboardScale;

  // Cek status clipboard
  bool get hasClipboard => _clipboardNode != null || _clipboardSubtree.isNotEmpty;
  bool get hasAssetClipboard => _clipboardAsset != null;

  List<MindMapAsset> get filteredAssets {
    return _assets.where((asset) => asset.parentId == _currentFolderId).toList();
  }

  List<MindMapAsset> get breadcrumbs {
    List<MindMapAsset> crumbs = [];
    String? tempId = _currentFolderId;
    while (tempId != null) {
      final folder = _assets.firstWhere((a) => a.id == tempId);
      crumbs.insert(0, folder);
      tempId = folder.parentId;
    }
    return crumbs;
  }
  
  void clearAssetClipboard() {
    _clipboardAsset = null;
    _isCutOperation = false;
    notifyListeners(); // Memicu UI untuk update dan menyembunyikan tombol
  }

  // ==========================================
  // 1. LOGIKA SELEKSI & NAVIGASI NODE
  // ==========================================
  
  void selectNode(String? id) {
    if (_selectedNodeId != id) {
      _selectedNodeId = id;
      notifyListeners();
    }
  }

  void selectNextNode() {
    if (_nodes.isEmpty) return;
    int currentIndex = _nodes.indexWhere((n) => n.id == _selectedNodeId);
    if (currentIndex == -1) { selectNode(_nodes.first.id); return; }
    int nextIndex = (currentIndex + 1) % _nodes.length;
    selectNode(_nodes[nextIndex].id);
  }

  void selectPreviousNode() {
    if (_nodes.isEmpty) return;
    int currentIndex = _nodes.indexWhere((n) => n.id == _selectedNodeId);
    if (currentIndex == -1) { selectNode(_nodes.last.id); return; }
    int prevIndex = (currentIndex - 1 + _nodes.length) % _nodes.length;
    selectNode(_nodes[prevIndex].id);
  }

  NodeModel? getSelectedNode() {
    if (_selectedNodeId == null) return null;
    try { return _nodes.firstWhere((n) => n.id == _selectedNodeId); } catch (e) { return null; }
  }

  // ==========================================
  // 2. MANAJEMEN NODE (CRUD, CLIPBOARD, ATTACHMENTS)
  // ==========================================

  void openAsset(MindMapAsset asset) {
    _activeAsset = asset;
    _selectedNodeId = null;
    if (asset.nodes.isEmpty) {
      _nodes = [
        NodeModel(
          id: 'root_${asset.id}_${DateTime.now().millisecondsSinceEpoch}',
          text: asset.title,
          position: const Offset(0, 0),
          labels: ["Root"],
        )
      ];
      _selectedNodeId = _nodes.first.id;
      _syncWithAsset(); 
    } else {
      _nodes = List.from(asset.nodes);
    }
    notifyListeners();
  }

  void addPeak(Offset position) {
    final newNode = NodeModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: "New Idea",
      position: position,
    );
    _nodes.add(newNode);
    selectNode(newNode.id);
    _syncWithAsset();
  }

  void addChildPeak(String parentId) {
    final parentIndex = _nodes.indexWhere((n) => n.id == parentId);
    
    if (parentIndex != -1) {
      final parentNode = _nodes[parentIndex];
      final siblings = _nodes.where((n) => n.parentId == parentId).toList();
      final int siblingCount = siblings.length;
      
      const double xOffset = 250.0;
      final double yOffset = (siblingCount == 0) ? 0 : (siblingCount * 110.0);

      final newNode = NodeModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Branch ${siblingCount + 1}", 
        parentId: parentId,
        position: Offset(parentNode.position.dx + xOffset, parentNode.position.dy + yOffset),
      );
      
      _nodes.add(newNode);
      selectNode(newNode.id);
      _syncWithAsset();
    }
  }

  // [UPDATED] Support update attachments list and alert
  void updatePeak(String id, {
    String? text,
    String? note,
    List<String>? labels,
    String? description,
    String? marker,
    String? linkedAssetId,
    List<AttachmentItem>? attachments,
    Offset? position,
    String? alertMessage,
    DateTime? alertDate,
    bool? alertEnabled,
    bool clearAlertMessage = false,
    bool clearAlertDate = false,
    int? bodyColor,
    int? textColor,
    int? iconColor,
    bool? isGradient,
    bool? isTextGradient,
    bool? isIconGradient,
    String? nodeNumber,
    String? shapeType,
    bool? isLocked,
    String? connectionLabel,
    List<String>? crossConnections,
    List<List<String>>? tableData,
    List<String>? dataList,
    List<DescriptionBlock>? descriptionBlocks,
  }) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      if (text != null) _nodes[index].text = text;
      if (note != null) _nodes[index].note = note;
      if (labels != null) _nodes[index].labels = labels;
      if (description != null) _nodes[index].description = description;
      if (marker != null) _nodes[index].marker = marker;
      if (linkedAssetId != null) _nodes[index].linkedAssetId = linkedAssetId;
      if (attachments != null) _nodes[index].attachments = attachments;
      if (clearAlertMessage) {
        _nodes[index].alertMessage = null;
      } else if (alertMessage != null) {
        _nodes[index].alertMessage = alertMessage;
      }

      if (clearAlertDate) {
        _nodes[index].alertDate = null;
      } else if (alertDate != null) {
        _nodes[index].alertDate = alertDate;
      }

      if (alertEnabled != null) _nodes[index].alertEnabled = alertEnabled;

      if (alertMessage != null || alertDate != null || alertEnabled != null || clearAlertMessage || clearAlertDate) {
        final node = _nodes[index];
        NotificationService.instance.scheduleNodeAlert(
          node,
          assetTitle: _activeAsset?.title,
        );
      }

      if (bodyColor != null) _nodes[index].bodyColor = bodyColor == -1 ? null : bodyColor;
      if (textColor != null) _nodes[index].textColor = textColor == -1 ? null : textColor;
      if (iconColor != null) _nodes[index].iconColor = iconColor == -1 ? null : iconColor;
      if (isGradient != null) _nodes[index].isGradient = isGradient;
      if (isTextGradient != null) _nodes[index].isTextGradient = isTextGradient;
      if (isIconGradient != null) _nodes[index].isIconGradient = isIconGradient;
      if (nodeNumber != null) _nodes[index].nodeNumber = nodeNumber == "-clear-" ? null : nodeNumber;
      if (shapeType != null) _nodes[index].shapeType = shapeType;
      if (isLocked != null) _nodes[index].isLocked = isLocked;
      if (connectionLabel != null) _nodes[index].connectionLabel = connectionLabel == "-clear-" ? null : connectionLabel;
      if (crossConnections != null) _nodes[index].crossConnections = crossConnections;

      if (tableData != null) _nodes[index].tableData = tableData;

      // Hanya update posisi jika node TIDAK sedang dikunci
      if (position != null && !_nodes[index].isLocked) _nodes[index].position = position;
      if (dataList != null) _nodes[index].dataList = dataList;
      if (descriptionBlocks != null) _nodes[index].descriptionBlocks = descriptionBlocks;

      _syncWithAsset();
    }
  }

  void toggleAllNodesLock(bool lock) {
    for (var node in _nodes) {
      node.isLocked = lock;
    }
    _syncWithAsset();
    notifyListeners();
  }

  void toggleCrossConnection(String fromId, String toId) {
    final index = _nodes.indexWhere((n) => n.id == fromId);
    if (index != -1) {
      List<String> current = List.from(_nodes[index].crossConnections);
      if (current.contains(toId)) {
        current.remove(toId);
      } else {
        current.add(toId);
      }
      updatePeak(fromId, crossConnections: current);
    }
  }
  
  // Helper: Tambah Attachment Single
  void addAttachment(String nodeId, AttachmentItem item) {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index != -1) {
      List<AttachmentItem> newChecklist = List.from(_nodes[index].attachments);
      newChecklist.add(item);
      updatePeak(nodeId, attachments: newChecklist);
    }
  }

  void addDescriptionBlock(String nodeId, DescriptionBlock block) {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index != -1) {
      List<DescriptionBlock> blocks = List.from(_nodes[index].descriptionBlocks);
      blocks.add(block);
      updatePeak(nodeId, descriptionBlocks: blocks);
    }
  }

  void reorderDescriptionBlock(String nodeId, int oldIndex, int newIndex) {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index != -1) {
      List<DescriptionBlock> blocks = List.from(_nodes[index].descriptionBlocks);
      if (newIndex > oldIndex) newIndex -= 1;
      final item = blocks.removeAt(oldIndex);
      blocks.insert(newIndex, item);
      updatePeak(nodeId, descriptionBlocks: blocks);
    }
  }

  void updateDescriptionBlock(String nodeId, String blockId, {String? content, List<List<String>>? tableData, String? chartType}) {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index != -1) {
      List<DescriptionBlock> blocks = List.from(_nodes[index].descriptionBlocks);
      final bIdx = blocks.indexWhere((b) => b.id == blockId);
      if (bIdx != -1) {
        if (content != null) blocks[bIdx].content = content;
        if (tableData != null) blocks[bIdx].tableData = tableData;
        if (chartType != null) blocks[bIdx].chartType = chartType;
        updatePeak(nodeId, descriptionBlocks: blocks);
      }
    }
  }

  void removeDescriptionBlock(String nodeId, String blockId) {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index != -1) {
      List<DescriptionBlock> blocks = List.from(_nodes[index].descriptionBlocks);
      blocks.removeWhere((b) => b.id == blockId);
      updatePeak(nodeId, descriptionBlocks: blocks);
    }
  }

  void duplicateDescriptionBlock(String nodeId, String blockId) {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index != -1) {
      List<DescriptionBlock> blocks = List.from(_nodes[index].descriptionBlocks);
      final bIdx = blocks.indexWhere((b) => b.id == blockId);
      if (bIdx != -1) {
        final original = blocks[bIdx];
        final copy = DescriptionBlock.fromJson(original.toJson());
        copy.id = "${original.id}_copy_${DateTime.now().millisecondsSinceEpoch}";

        // Insert after the original
        blocks.insert(bIdx + 1, copy);
        updatePeak(nodeId, descriptionBlocks: blocks);
      }
    }
  }

  // Helper: Hapus Attachment Single
  void removeAttachment(String nodeId, String attachmentId) {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index != -1) {
      List<AttachmentItem> newChecklist = List.from(_nodes[index].attachments);
      newChecklist.removeWhere((a) => a.id == attachmentId);
      updatePeak(nodeId, attachments: newChecklist);
    }
  }

  void deletePeak(String id, {bool includeChildren = true}) {
    if (includeChildren) {
      List<String> idsToRemove = [id];
      _findChildrenRecursive(id, idsToRemove);
      _nodes.removeWhere((node) => idsToRemove.contains(node.id));
      for (final nodeId in idsToRemove) {
        NotificationService.instance.cancelNodeAlert(nodeId);
      }
      if (idsToRemove.contains(_selectedNodeId)) {
        _selectedNodeId = null;
      }
    } else {
      final index = _nodes.indexWhere((n) => n.id == id);
      if (index != -1) {
        final parentId = _nodes[index].parentId;
        // Re-parent children
        for (var node in _nodes) {
          if (node.parentId == id) {
            node.parentId = parentId;
          }
        }
        _nodes.removeAt(index);
        NotificationService.instance.cancelNodeAlert(id);
        if (_selectedNodeId == id) {
          _selectedNodeId = null;
        }
      }
    }
    _syncWithAsset();
  }

  void _findChildrenRecursive(String parentId, List<String> currentList) {
    final children = _nodes.where((n) => n.parentId == parentId).toList();
    for (var child in children) {
      currentList.add(child.id);
      _findChildrenRecursive(child.id, currentList);
    }
  }

  // --- NODE CLIPBOARD ---

  // Recursive clipboard data
  List<NodeModel> _clipboardSubtree = [];

  void copyNode(String id, {bool includeChildren = false}) {
    if (!includeChildren) {
      final index = _nodes.indexWhere((n) => n.id == id);
      if (index != -1) {
        _clipboardNode = _nodes[index];
        _clipboardSubtree = [];
        notifyListeners();
      }
    } else {
      List<String> ids = [id];
      _findChildrenRecursive(id, ids);
      _clipboardSubtree = _nodes.where((n) => ids.contains(n.id)).map((n) => NodeModel.fromJson(n.toJson())).toList();
      _clipboardNode = null;
      notifyListeners();
    }
  }

  void cutNode(String id, {bool includeChildren = false}) {
    copyNode(id, includeChildren: includeChildren);
    deletePeak(id, includeChildren: includeChildren);
    notifyListeners();
  }

  void pasteNodeAsChild(String parentId) {
    if (_clipboardNode != null) {
      _pasteSingleNode(parentId, _clipboardNode!);
    } else if (_clipboardSubtree.isNotEmpty) {
      _pasteSubtree(parentId, _clipboardSubtree);
    }
  }

  void _pasteSingleNode(String parentId, NodeModel source) {
    final parentIndex = _nodes.indexWhere((n) => n.id == parentId);
    if (parentIndex != -1) {
      final parentNode = _nodes[parentIndex];
      final siblings = _nodes.where((n) => n.parentId == parentId).toList();
      final double yOffset = siblings.isEmpty ? 0 : (siblings.length * 110.0);

      final newNode = NodeModel.fromJson(source.toJson());
      newNode.id = DateTime.now().millisecondsSinceEpoch.toString();
      newNode.parentId = parentId;
      newNode.position = Offset(parentNode.position.dx + 250, parentNode.position.dy + yOffset);

      _nodes.add(newNode);
      selectNode(newNode.id);
      _syncWithAsset();
    }
  }

  void _pasteSubtree(String parentId, List<NodeModel> subtree) {
    if (subtree.isEmpty) return;

    // Cari root dari subtree (node yang parentId-nya tidak ada di subtree)
    Set<String> subtreeIds = subtree.map((n) => n.id).toSet();
    NodeModel rootNode = subtree.firstWhere((n) => n.parentId == null || !subtreeIds.contains(n.parentId));

    String oldRootId = rootNode.id;
    Map<String, String> idMapping = {};

    final parentIndex = _nodes.indexWhere((n) => n.id == parentId);
    if (parentIndex == -1) return;
    final parentNode = _nodes[parentIndex];

    // New Root
    final newRoot = NodeModel.fromJson(rootNode.toJson());
    newRoot.id = "new_${DateTime.now().millisecondsSinceEpoch}";
    newRoot.parentId = parentId;
    newRoot.position = parentNode.position + const Offset(250, 0);
    idMapping[oldRootId] = newRoot.id;
    _nodes.add(newRoot);

    // Paste rest of subtree
    for (var node in subtree) {
      if (node.id == oldRootId) continue;
      final newNode = NodeModel.fromJson(node.toJson());
      newNode.id = "new_${DateTime.now().millisecondsSinceEpoch}_${node.id}";
      idMapping[node.id] = newNode.id;
      _nodes.add(newNode);
    }

    // Fix parent IDs
    for (var node in subtree) {
      if (node.id == oldRootId) continue;
      final newlyAdded = _nodes.firstWhere((n) => n.id == idMapping[node.id]);
      if (idMapping.containsKey(node.parentId)) {
        newlyAdded.parentId = idMapping[node.parentId];
      }
    }

    selectNode(newRoot.id);
    _syncWithAsset();
  }

  void duplicateNode(String id, {bool includeChildren = false}) {
    if (!includeChildren) {
      final index = _nodes.indexWhere((n) => n.id == id);
      if (index != -1) {
        final originalNode = _nodes[index];
        final Offset newPos = originalNode.position + const Offset(30, 30);

        final newNode = NodeModel.fromJson(originalNode.toJson());
        newNode.id = DateTime.now().millisecondsSinceEpoch.toString();
        newNode.text = "${originalNode.text} (Copy)";
        newNode.position = newPos;

        _nodes.add(newNode);
        selectNode(newNode.id);
        _syncWithAsset();
      }
    } else {
      List<String> ids = [id];
      _findChildrenRecursive(id, ids);
      List<NodeModel> subtree = _nodes.where((n) => ids.contains(n.id)).map((n) => NodeModel.fromJson(n.toJson())).toList();

      // Paste subtree logic
      Set<String> subtreeIds = subtree.map((n) => n.id).toSet();
      NodeModel rootNode = subtree.firstWhere((n) => n.parentId == null || !subtreeIds.contains(n.parentId));

      String oldRootId = rootNode.id;
      Map<String, String> idMapping = {};

      // New Root
      final newRoot = NodeModel.fromJson(rootNode.toJson());
      newRoot.id = "dup_${DateTime.now().millisecondsSinceEpoch}";
      newRoot.text = "${rootNode.text} (Copy)";
      newRoot.position = rootNode.position + const Offset(50, 50);
      idMapping[oldRootId] = newRoot.id;
      _nodes.add(newRoot);

      // Duplicate rest
      for (var node in subtree) {
        if (node.id == oldRootId) continue;
        final newNode = NodeModel.fromJson(node.toJson());
        newNode.id = "dup_${DateTime.now().millisecondsSinceEpoch}_${node.id}";
        idMapping[node.id] = newNode.id;
        _nodes.add(newNode);
      }

      for (var node in subtree) {
        if (node.id == oldRootId) continue;
        final newlyAdded = _nodes.firstWhere((n) => n.id == idMapping[node.id]);
        if (idMapping.containsKey(node.parentId)) {
          newlyAdded.parentId = idMapping[node.parentId];
        }
      }

      selectNode(newRoot.id);
      _syncWithAsset();
    }
  }

  // --- AUTO LAYOUT ALGORITHM ---
  
  // ==========================================
  // [NEW] AUTO NUMBERING LOGIC
  // ==========================================

  void applyNumberingAll() {
    List<NodeModel> roots = _findRoots();
    roots.sort((a, b) => a.position.dy.compareTo(b.position.dy));
    for (int i = 0; i < roots.length; i++) {
      _numberNodeRecursive(roots[i].id, (i + 1).toString(), true);
    }
    _syncWithAsset();
  }

  void applyNumberingSubtree(String rootId) {
    _numberNodeRecursive(rootId, "1", true);
    _syncWithAsset();
  }

  void applyNumberingImmediate(String parentId) {
    final children = _nodes.where((n) => n.parentId == parentId).toList();
    children.sort((a, b) => a.position.dy.compareTo(b.position.dy));
    for (int i = 0; i < children.length; i++) {
      final index = _nodes.indexWhere((n) => n.id == children[i].id);
      if (index != -1) {
        _nodes[index].nodeNumber = (i + 1).toString();
      }
    }
    _syncWithAsset();
  }

  void clearNumbering(String rootId, {bool recursive = true}) {
    final index = _nodes.indexWhere((n) => n.id == rootId);
    if (index != -1) {
      _nodes[index].nodeNumber = null;
      if (recursive) {
        List<String> childrenIds = [];
        _findChildrenRecursive(rootId, childrenIds);
        for (var id in childrenIds) {
          final cIdx = _nodes.indexWhere((n) => n.id == id);
          if (cIdx != -1) _nodes[cIdx].nodeNumber = null;
        }
      }
    }
    _syncWithAsset();
  }

  List<NodeModel> _findRoots() {
    Set<String> allIds = _nodes.map((n) => n.id).toSet();
    return _nodes.where((n) => n.parentId == null || !allIds.contains(n.parentId)).toList();
  }

  void _numberNodeRecursive(String id, String number, bool recursive) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _nodes[index].nodeNumber = number;
      if (recursive) {
        final children = _nodes.where((n) => n.parentId == id).toList();
        children.sort((a, b) => a.position.dy.compareTo(b.position.dy));
        for (int i = 0; i < children.length; i++) {
          _numberNodeRecursive(children[i].id, "$number.${i + 1}", true);
        }
      }
    }
  }

  void autoLayout() {
    if (_nodes.isEmpty) return;
    final bool isDocx = _activeAsset?.folderName == "DocxMap";
    Set<String> allNodeIds = _nodes.map((n) => n.id).toSet();
    
    // Cari root (bisa multiple root)
    List<NodeModel> roots = _nodes.where((n) {
      return n.parentId == null || !allNodeIds.contains(n.parentId);
    }).toList();

    roots.sort((a, b) => a.position.dy.compareTo(b.position.dy));

    double currentY = 0;
    // Professional tighter gaps
    final double verticalGap = isDocx ? 80.0 : 60.0;
    final double horizontalGap = isDocx ? 260.0 : 300.0;

    for (var root in roots) {
      double treeHeight = _layoutNodeRecursive(root, 0.0, currentY, verticalGap, horizontalGap, isDocx);
      currentY += treeHeight + verticalGap;
    }
    _syncWithAsset();
    notifyListeners();
  }

  double _layoutNodeRecursive(NodeModel node, double currentX, double startY, double vGap, double hGap, bool isDocx) {
    List<NodeModel> children = _nodes.where((n) => n.parentId == node.id).toList();

    // Account for node content in vertical height more professionally
    double estimatedNodeHeight = isDocx ? 160.0 : 50.0;
    if (!isDocx) {
      if (node.description != null && node.description!.isNotEmpty) estimatedNodeHeight += 25.0;
      if (node.labels.isNotEmpty) {
        estimatedNodeHeight += (node.labels.length / 2).ceil() * 24.0;
      }
      if (node.shapeType == 'table') estimatedNodeHeight += 80.0;
    } else {
       // DocxMap structured content
       if (node.description != null && node.description!.isNotEmpty) estimatedNodeHeight += 30.0;
       if (node.attachments.isNotEmpty || node.labels.isNotEmpty) estimatedNodeHeight += 40.0;
    }

    // Node visual height including half-gap on each side
    double nodeVisualHeight = estimatedNodeHeight + vGap;

    if (children.isEmpty) {
      // Center node in its vertical slot
      updatePeak(node.id, position: Offset(currentX, startY + (nodeVisualHeight / 2) - (estimatedNodeHeight / 2)));
      return nodeVisualHeight;
    }

    // Calculate horizontal offset for children
    double nextX = currentX + hGap;

    double accumulatedHeight = 0;
    // Sort children by their current Y to maintain relative order if manually moved
    children.sort((a, b) => a.position.dy.compareTo(b.position.dy));

    for (var child in children) {
      double childHeight = _layoutNodeRecursive(child, nextX, startY + accumulatedHeight, vGap, hGap, isDocx);
      accumulatedHeight += childHeight;
    }

    // Ensure parent is at least as high as its own visual content
    accumulatedHeight = math.max(accumulatedHeight, nodeVisualHeight);

    // Center parent relative to children's total height for perfect balance
    double centeredY = startY + (accumulatedHeight / 2) - (estimatedNodeHeight / 2);
    updatePeak(node.id, position: Offset(currentX, centeredY));

    return accumulatedHeight;
  }


  // ==========================================
  // 3. PERSISTENCE & ASSET SYNC
  // ==========================================

  Future<String> saveAttachmentFile(String sourcePath, String fileName) async {
    final docDir = await getApplicationDocumentsDirectory();
    final String newPath = "${docDir.path}/attachments/${DateTime.now().microsecondsSinceEpoch}_$fileName";
    final newFile = File(newPath);
    await newFile.parent.create(recursive: true);
    await File(sourcePath).copy(newPath);
    return newPath;
  }
  
  void _syncWithAsset() {
    if (_activeAsset != null) {
      _activeAsset!.nodes = List.from(_nodes);
      _activeAsset!.nodeCount = _nodes.length;
      _activeAsset!.lastModified = DateTime.now();
      _activeAsset!.triggerUpdate();

      final index = _assets.indexWhere((a) => a.id == _activeAsset!.id);
      if (index != -1) {
        _assets[index] = _activeAsset!;
      }

      _saveToDisk();
      notifyListeners();
    }
  }

  Future<void> _saveToDisk() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final String encodedData = jsonEncode(
        _assets.map((asset) => asset.toJson()).toList(),
      );
      await _prefs!.setString('mountmap_assets_key', encodedData);
      _recordTodayAttendance();
    } catch (e) {
      debugPrint("Save Error: $e");
    }
  }
  
  Future<void> loadFromDisk() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final String? data = _prefs!.getString('mountmap_assets_key');
      
      if (data != null) {
        final List<dynamic> decodedData = jsonDecode(data);
        _assets = decodedData.map((item) => MindMapAsset.fromJson(item)).toList();
      }

      // Load Attendance
      _attendanceDates = _prefs!.getStringList('attendance_dates_key') ?? [];
      _recordTodayAttendance();
      await NotificationService.instance.syncAllAlerts(_assets);

      notifyListeners();
    } catch (e) {
      debugPrint("Load Error: $e");
    }
  }

  void _recordTodayAttendance() {
    if (_prefs == null) return;
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (!_attendanceDates.contains(today)) {
      _attendanceDates.add(today);
      _prefs!.setStringList('attendance_dates_key', _attendanceDates);
    }
  }

  // ==========================================
  // 4. MANAJEMEN FOLDER & DASHBOARD
  // ==========================================
  
  void enterFolder(String? folderId) {
    _currentFolderId = folderId;
    notifyListeners();
  }
  
  void goBack() {
    if (_currentFolderId == null) return;
    try {
      final folderList = _assets.where((a) => a.id == _currentFolderId).toList();
      if (folderList.isNotEmpty) {
        _currentFolderId = folderList.first.parentId;
      } else {
        _currentFolderId = null;
      }
    } catch (e) {
      _currentFolderId = null;
    }
    notifyListeners();
  }

  void updateDashboardScale(double scale) {
    _dashboardScale = scale.clamp(0.8, 1.8);
    notifyListeners();
  }

  List<MindMapAsset> getAvailableFolders(String assetId) {
    final movingAsset = _assets.firstWhere(
      (a) => a.id == assetId, 
      orElse: () => _assets.first
    );

    return _assets.where((a) {
      if (!a.isFolder || a.id == assetId) return false;
      if (movingAsset.isFolder) {
        if (_isDescendant(assetId, a.id)) return false;
      }
      return true;
    }).toList();
  }

  void createNewAsset(String title, {bool isDocxMap = false}) {
    final asset = MindMapAsset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: title,
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      parentId: _currentFolderId,
      isFolder: false,
    );
    if (isDocxMap) {
      asset.folderName = "DocxMap";
    }
    _assets.insert(0, asset);
    _saveToDisk();
    notifyListeners();
  }

  void createNewFolder(String title) {
    _assets.insert(0, MindMapAsset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: title,
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      parentId: _currentFolderId,
      isFolder: true,
    ));
    _saveToDisk();
    notifyListeners();
  }

  MindMapAsset createNewChartAsset(String title, String chartType) {
    final newAsset = MindMapAsset(
      id: "chart_${DateTime.now().millisecondsSinceEpoch}",
      text: title,
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      parentId: _currentFolderId,
      isFolder: false,
    );
    // Kita bisa menyimpan tipe chart di folderName atau metadata lain jika perlu
    newAsset.folderName = "Chart: $chartType"; 
    
    _assets.insert(0, newAsset);
    _saveToDisk();
    notifyListeners();
    return newAsset;
  }

  void renameAsset(String id, String newTitle) {
    final index = _assets.indexWhere((asset) => asset.id == id);
    if (index != -1) {
      _assets[index].title = newTitle; 
      _assets[index].lastModified = DateTime.now();
      _saveToDisk();
      notifyListeners();
    }
  }

  void moveAsset(String assetId, String? targetFolderId) {
    final index = _assets.indexWhere((a) => a.id == assetId);
    if (index != -1) {
      _assets[index].parentId = targetFolderId;
      _saveToDisk();
      notifyListeners();
    }
  }

  void deleteAsset(String id) {
    if (id == _currentFolderId || _isParentOfCurrent(id)) {
      _currentFolderId = null;
    }

    final index = _assets.indexWhere((a) => a.id == id);
    if (index != -1) {
      final assetToDelete = _assets[index];
      for (final node in assetToDelete.nodes) {
        NotificationService.instance.cancelNodeAlert(node.id);
      }
      if (assetToDelete.isFolder) {
        _deleteFolderContents(id);
      }
      _assets.removeAt(index);
      _saveToDisk();
      notifyListeners();
    }
  }

  void _deleteFolderContents(String parentId) {
    final children = _assets.where((a) => a.parentId == parentId).toList();
    for (var child in children) {
      if (child.isFolder) {
        _deleteFolderContents(child.id);
      }
      for (final node in child.nodes) {
        NotificationService.instance.cancelNodeAlert(node.id);
      }
      _assets.removeWhere((a) => a.id == child.id);
    }
  }

  bool _isParentOfCurrent(String folderId) {
    if (_currentFolderId == null) return false;
    return _isDescendant(folderId, _currentFolderId!);
  }

  bool _isDescendant(String parentId, String targetId) {
    try {
      final target = _assets.firstWhere((a) => a.id == targetId);
      if (target.parentId == null) return false;
      if (target.parentId == parentId) return true;
      return _isDescendant(parentId, target.parentId!);
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // [FIXED] ASSET MANIPULATION (Duplicate, Copy, Paste)
  // ==========================================

  void duplicateAsset(String assetId) {
    final index = _assets.indexWhere((a) => a.id == assetId);
    if (index != -1) {
      final original = _assets[index];
      final String prefix = original.id.startsWith("chart_") ? "chart_" : "";
      
      // Menggunakan Constructor untuk membuat instance baru (Fix error final fields)
      final MindMapAsset copy = MindMapAsset(
        id: "$prefix${DateTime.now().millisecondsSinceEpoch}",
        text: "${original.title} (Copy)",
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        parentId: original.parentId,
        isFolder: original.isFolder,
        folderName: original.folderName,
      );

      // Deep Copy Nodes (agar node di copy tidak mengubah node asli)
      if (original.nodes.isNotEmpty) {
        copy.nodes = original.nodes.map((n) => NodeModel.fromJson(n.toJson())).toList();
        copy.nodeCount = copy.nodes.length;
      }

      _assets.insert(0, copy);
      _saveToDisk();
      notifyListeners();
    }
  }

  void copyAssetToClipboard(String assetId) {
    final index = _assets.indexWhere((a) => a.id == assetId);
    if (index != -1) {
      _clipboardAsset = _assets[index];
      _isCutOperation = false;
      notifyListeners();
    }
  }

  void cutAssetToClipboard(String assetId) {
    final index = _assets.indexWhere((a) => a.id == assetId);
    if (index != -1) {
      _clipboardAsset = _assets[index];
      _isCutOperation = true;
      notifyListeners();
    }
  }

  void pasteAsset() {
    if (_clipboardAsset == null) return;

    if (_isCutOperation) {
      moveAsset(_clipboardAsset!.id, _currentFolderId);
      _clipboardAsset = null;
      _isCutOperation = false;
    } else {
      final String prefix = _clipboardAsset!.id.startsWith("chart_") ? "chart_" : "";
      // Menggunakan Constructor untuk Paste Copy
      final MindMapAsset newAsset = MindMapAsset(
        id: "$prefix${DateTime.now().millisecondsSinceEpoch}",
        text: _clipboardAsset!.title,
        parentId: _currentFolderId, // Paste ke folder sekarang
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        isFolder: _clipboardAsset!.isFolder,
        folderName: _clipboardAsset!.folderName,
      );

      // Deep copy nodes
      if (_clipboardAsset!.nodes.isNotEmpty) {
        newAsset.nodes = _clipboardAsset!.nodes.map((n) => NodeModel.fromJson(n.toJson())).toList();
        newAsset.nodeCount = newAsset.nodes.length;
      }

      _assets.insert(0, newAsset);
      _saveToDisk();
    }
    notifyListeners();
  }


  // ==========================================
  // 5. THEME & EXPORT
  // ==========================================

  void setTheme(AppThemeMode mode) {
    _currentTheme = mode;
    notifyListeners();
  }

  void toggleTheme() {
    _currentTheme = (_currentTheme == AppThemeMode.dark) ? AppThemeMode.light : AppThemeMode.dark;
    notifyListeners();
  }

  Color get backgroundColor {
    switch (_currentTheme) {
      case AppThemeMode.light: return MountMapColors.lightBackground;
      case AppThemeMode.warm: return MountMapColors.warmBackground;
      default: return MountMapColors.darkBackground;
    }
  }

  Color get cardColor {
    switch (_currentTheme) {
      case AppThemeMode.light: return MountMapColors.lightCard;
      case AppThemeMode.warm: return MountMapColors.warmCard;
      default: return MountMapColors.darkCard;
    }
  }

  Color get textColor {
    switch (_currentTheme) {
      case AppThemeMode.light: return MountMapColors.lightText;
      case AppThemeMode.warm: return MountMapColors.warmText;
      default: return MountMapColors.darkText;
    }
  }

  Color get dividerColor {
    switch (_currentTheme) {
      case AppThemeMode.light: return Colors.black12;
      case AppThemeMode.warm: return Colors.black12;
      default: return Colors.white10;
    }
  }

  Color get accentColor {
    return MountMapColors.teal;
  }

  // ==========================================
  // [NEW] ADVANCED EXPORT / IMPORT (.mountflow)
  // ==========================================

  Future<void> exportToMountFlow(MindMapAsset asset) async {
    return exportToMountPack(asset);
  }

  Future<void> exportToMountFlowLegacy(MindMapAsset asset) async {
    try {
      List<MindMapAsset> bundle = [];
      if (asset.isFolder) {
        bundle.add(asset);
        _gatherFolderContentsRecursive(asset.id, bundle);
      } else {
        bundle.add(asset);
      }

      // Embedding file data for truly portable .mountflow
      List<Map<String, dynamic>> assetsJson = [];
      for (var a in bundle) {
        var aJson = a.toJson();
        if (aJson['nodes'] != null) {
          for (var nJson in aJson['nodes']) {
            // Embed primary attachments
            if (nJson['attachments'] != null) {
              for (var attachJson in nJson['attachments']) {
                if (attachJson['type'] == 'file') {
                  final file = File(attachJson['value']);
                  if (await file.exists()) {
                    final bytes = await file.readAsBytes();
                    attachJson['fileData'] = base64Encode(bytes);
                  }
                }
              }
            }

            // Embed top-level tableData attachments
            if (nJson['tableData'] != null) {
              Map<String, String> tableFileData = {};
              for (var row in nJson['tableData']) {
                for (var cell in row) {
                  if (cell is String && cell.startsWith(DescriptionBlock.tableFilePrefix)) {
                    final payload = cell.replaceFirst(DescriptionBlock.tableFilePrefix, '');
                    final splitIndex = payload.indexOf('|');
                    if (splitIndex != -1) {
                      final path = payload.substring(splitIndex + 1);
                      final file = File(path);
                      if (await file.exists()) {
                        final bytes = await file.readAsBytes();
                        tableFileData[path] = base64Encode(bytes);
                      }
                    }
                  }
                }
              }
              if (tableFileData.isNotEmpty) {
                nJson['topLevelTableFileData'] = tableFileData;
              }
            }
            // Embed description block attachments
            if (nJson['descriptionBlocks'] != null) {
              for (var blockJson in nJson['descriptionBlocks']) {
                if (blockJson['type'] == 'attachment' && blockJson['attachment'] != null) {
                  var attachJson = blockJson['attachment'];
                  if (attachJson['type'] == 'file') {
                    final file = File(attachJson['value']);
                    if (await file.exists()) {
                      final bytes = await file.readAsBytes();
                      attachJson['fileData'] = base64Encode(bytes);
                    }
                  }
                }

                // Embed table/chart attachments
                if ((blockJson['type'] == 'table' || blockJson['type'] == 'chart') && blockJson['tableData'] != null) {
                  Map<String, String> tableFileData = {};
                  for (var row in blockJson['tableData']) {
                    for (var cell in row) {
                      if (cell is String && cell.startsWith(DescriptionBlock.tableFilePrefix)) {
                        final payload = cell.replaceFirst(DescriptionBlock.tableFilePrefix, '');
                        final splitIndex = payload.indexOf('|');
                        if (splitIndex != -1) {
                          final path = payload.substring(splitIndex + 1);
                          final file = File(path);
                          if (await file.exists()) {
                            final bytes = await file.readAsBytes();
                            tableFileData[path] = base64Encode(bytes);
                          }
                        }
                      }
                    }
                  }
                  if (tableFileData.isNotEmpty) {
                    blockJson['tableFileData'] = tableFileData;
                  }
                }

              }
            }
          }
        }
        assetsJson.add(aJson);
      }

      Map<String, dynamic> exportData = {
        'type': asset.isFolder ? 'folder_bundle' : 'single_asset',
        'rootId': asset.id,
        'assets': assetsJson,
        'exportedAt': DateTime.now().toIso8601String(),
        'app': 'MountMap',
        'format': 'mountflow'
      };

      String jsonString = jsonEncode(exportData);
      final directory = await getTemporaryDirectory();
      final String safeFileName = asset.title.replaceAll(RegExp(r'[^\w\s]+'), '_').replaceAll(' ', '_');
      final file = File('${directory.path}/$safeFileName.mountflow');

      await file.writeAsString(jsonString);
      await Share.shareXFiles([XFile(file.path)], text: 'MountFlow Export: ${asset.title}');
    } catch (e) {
      if (e.toString().contains('Share callback error') || e.toString().contains('prior share-sheet')) {
        debugPrint("Share callback info ignored: $e");
      } else {
        debugPrint("Export Error: $e");
        rethrow;
      }
    }
  }

  void _gatherFolderContentsRecursive(String folderId, List<MindMapAsset> bundle) {
    final children = _assets.where((a) => a.parentId == folderId).toList();
    for (var child in children) {
      bundle.add(child);
      if (child.isFolder) {
        _gatherFolderContentsRecursive(child.id, bundle);
      }
    }
  }

  Future<void> importFromMountFlow(File file) async {
    try {
      String content = await file.readAsString();
      Map<String, dynamic> data = jsonDecode(content);

      if (data['format'] != 'mountflow') throw "Invalid format";

      List<dynamic> assetList = data['assets'];
      String oldRootId = data['rootId'];
      Map<String, String> idMapping = {};

      // First pass: Create new IDs and instantiate assets
      List<MindMapAsset> newAssets = [];
      final docDir = await getApplicationDocumentsDirectory();
      int recoveryCount = 0;

      for (var aJson in assetList) {
        // Recover files from embedded data
        if (aJson['nodes'] != null) {
          for (var nJson in aJson['nodes']) {
            // Recover primary attachments
            if (nJson['attachments'] != null) {
              for (var attachJson in nJson['attachments']) {
                if (attachJson['type'] == 'file' && attachJson['fileData'] != null) {
                  try {
                    final bytes = base64Decode(attachJson['fileData']);
                    final String fileName = attachJson['name'] ?? "attachment";
                    // Ensure unique path using both timestamp and counter
                    final String newPath = "${docDir.path}/attachments/${DateTime.now().microsecondsSinceEpoch}_${recoveryCount++}_$fileName";
                    final f = File(newPath);
                    await f.parent.create(recursive: true);
                    await f.writeAsBytes(bytes);

                    // Verify file was written successfully
                    if (await f.exists()) {
                      attachJson['value'] = newPath;
                      attachJson.remove('fileData'); // Important: remove after extraction to save RAM/Prefs space
                    }
                  } catch (e) {
                    debugPrint("Error extracting attachment: $e");
                  }
                }
              }
            }
            // Recover description block attachments
            if (nJson['descriptionBlocks'] != null) {
              for (var blockJson in nJson['descriptionBlocks']) {
                if (blockJson['type'] == 'attachment' && blockJson['attachment'] != null) {
                  var attachJson = blockJson['attachment'];
                  if (attachJson['type'] == 'file' && attachJson['fileData'] != null) {
                    try {
                      final bytes = base64Decode(attachJson['fileData']);
                      final String fileName = attachJson['name'] ?? "attachment";
                      final String newPath = "${docDir.path}/attachments/${DateTime.now().microsecondsSinceEpoch}_${recoveryCount++}_$fileName";
                      final f = File(newPath);
                      await f.parent.create(recursive: true);
                      await f.writeAsBytes(bytes);

                      if (await f.exists()) {
                        attachJson['value'] = newPath;
                        attachJson.remove('fileData');
                      }
                    } catch (e) {
                      debugPrint("Error extracting block attachment: $e");
                    }
                  }
                }

                // Recover table/chart attachments
                if ((blockJson['type'] == 'table' || blockJson['type'] == 'chart') &&
                    blockJson['tableData'] != null &&
                    blockJson['tableFileData'] != null) {
                  Map<String, dynamic> tableFileData = blockJson['tableFileData'];
                  for (int r = 0; r < blockJson['tableData'].length; r++) {
                    for (int c = 0; c < blockJson['tableData'][r].length; c++) {
                      String cell = blockJson['tableData'][r][c];
                      if (cell.startsWith(DescriptionBlock.tableFilePrefix)) {
                        final payload = cell.replaceFirst(DescriptionBlock.tableFilePrefix, '');
                        final splitIndex = payload.indexOf('|');
                        if (splitIndex != -1) {
                          final name = payload.substring(0, splitIndex);
                          final oldPath = payload.substring(splitIndex + 1);
                          if (tableFileData.containsKey(oldPath)) {
                            try {
                              final bytes = base64Decode(tableFileData[oldPath]);
                              final String fileName = name.isEmpty ? "attachment" : name;
                              final String newPath = "${docDir.path}/attachments/${DateTime.now().microsecondsSinceEpoch}_${recoveryCount++}_$fileName";
                              final f = File(newPath);
                              await f.parent.create(recursive: true);
                              await f.writeAsBytes(bytes);

                              if (await f.exists()) {
                                blockJson['tableData'][r][c] = '${DescriptionBlock.tableFilePrefix}$name|$newPath';
                              }
                            } catch (e) {
                              debugPrint("Error extracting table file: $e");
                            }
                          }
                        }
                      }
                    }
                  }
                  blockJson.remove('tableFileData');
                }
              }
            }

            // Recover top-level tableData attachments
            if (nJson['tableData'] != null && nJson['topLevelTableFileData'] != null) {
              Map<String, dynamic> tableFileData = nJson['topLevelTableFileData'];
              for (int r = 0; r < nJson['tableData'].length; r++) {
                for (int c = 0; c < nJson['tableData'][r].length; c++) {
                  String cell = nJson['tableData'][r][c];
                  if (cell.startsWith(DescriptionBlock.tableFilePrefix)) {
                    final payload = cell.replaceFirst(DescriptionBlock.tableFilePrefix, '');
                    final splitIndex = payload.indexOf('|');
                    if (splitIndex != -1) {
                      final name = payload.substring(0, splitIndex);
                      final oldPath = payload.substring(splitIndex + 1);
                      if (tableFileData.containsKey(oldPath)) {
                        try {
                          final bytes = base64Decode(tableFileData[oldPath]);
                          final String fileName = name.isEmpty ? "attachment" : name;
                          final String newPath = "${docDir.path}/attachments/${DateTime.now().microsecondsSinceEpoch}_${recoveryCount++}_$fileName";
                          final f = File(newPath);
                          await f.parent.create(recursive: true);
                          await f.writeAsBytes(bytes);

                          if (await f.exists()) {
                            nJson['tableData'][r][c] = '${DescriptionBlock.tableFilePrefix}$name|$newPath';
                          }
                        } catch (e) {
                          debugPrint("Error extracting top-level table file: $e");
                        }
                      }
                    }
                  }
                }
              }
              nJson.remove('topLevelTableFileData');
            }
          }
        }

        MindMapAsset a = MindMapAsset.fromJson(aJson);
        String oldId = a.id;
        final String prefix = oldId.startsWith("chart_") ? "chart_" : "";
        String newId = "${prefix}imp_${DateTime.now().millisecondsSinceEpoch}_$oldId";
        idMapping[oldId] = newId;

        // Update basic info
        a.id = newId;
        a.title = (oldId == oldRootId) ? "${a.title} (Imported)" : a.title;
        newAssets.add(a);
      }

      // Second pass: Fix parent relationships and add to main list
      for (var a in newAssets) {
        String? oldParentId = assetList.firstWhere((aj) => aj['id'] == (idMapping.entries.firstWhere((e) => e.value == a.id).key))['parentId'];

        if (oldParentId == null || !idMapping.containsKey(oldParentId)) {
          // It's a root of the bundle, set to current folder
          a.parentId = _currentFolderId;
        } else {
          a.parentId = idMapping[oldParentId];
        }
        _assets.insert(0, a);
      }

      await _saveToDisk();
      notifyListeners();
    } catch (e) {
      debugPrint("Import Error: $e");
      rethrow;
    }
  }


  static const String _mountPackMagic = 'MOUNTPACK2';
  static const String _blobPlaceholderPrefix = '__MOUNT_BLOB__:';

  Future<void> exportToMountPack(MindMapAsset asset) async {
    File? outputFile;
    try {
      final bundle = _buildBundleForExport(asset);
      final assetsJson = <Map<String, dynamic>>[];
      final blobSourceByKey = <String, String>{};
      final blobKeyByPath = <String, String>{};
      int blobCounter = 0;

      String registerBlob(String path) {
        final existing = blobKeyByPath[path];
        if (existing != null) {
          return existing;
        }
        final key = 'b_${blobCounter++}_${DateTime.now().microsecondsSinceEpoch}';
        blobSourceByKey[key] = path;
        blobKeyByPath[path] = key;
        return key;
      }

      for (final a in bundle) {
        final aJson = a.toJson();
        final nodes = aJson['nodes'];
        if (nodes is List) {
          for (final n in nodes) {
            if (n is! Map<String, dynamic>) continue;
            _replaceNodeFileRefsWithBlobKeys(n, registerBlob);
          }
        }
        assetsJson.add(aJson);
      }

      final manifest = {
        'type': asset.isFolder ? 'folder_bundle' : 'single_asset',
        'rootId': asset.id,
        'assets': assetsJson,
        'exportedAt': DateTime.now().toIso8601String(),
        'app': 'MountMap',
        'format': 'mountpack2',
        'blobCount': blobSourceByKey.length,
      };

      final directory = await getApplicationDocumentsDirectory();
      final safeFileName = asset.title.replaceAll(RegExp(r'[^\w\s]+'), '_').replaceAll(' ', '_');
      outputFile = File('${directory.path}/${safeFileName}_${DateTime.now().millisecondsSinceEpoch}.mountpack');
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      final raf = await outputFile.open(mode: FileMode.write);
      try {
        await _writeStringWithLength(raf, _mountPackMagic);
        await _writeStringWithLength(raf, jsonEncode(manifest));
        await _writeInt32(raf, blobSourceByKey.length);

        for (final entry in blobSourceByKey.entries) {
          final source = File(entry.value);
          if (!await source.exists()) {
            await _writeStringWithLength(raf, entry.key);
            await _writeStringWithLength(raf, '');
            await _writeInt64(raf, 0);
            continue;
          }

          final filename = entry.value.split('/').last;
          await _writeStringWithLength(raf, entry.key);
          await _writeStringWithLength(raf, filename);
          final size = await source.length();
          await _writeInt64(raf, size);

          final input = source.openRead();
          await for (final chunk in input) {
            await raf.writeFrom(chunk);
          }
        }
      } finally {
        await raf.close();
      }

      await Share.shareXFiles([XFile(outputFile.path)], text: 'MountPack Export: ${asset.title}');
    } catch (e) {
      if (e.toString().contains('Share callback error') || e.toString().contains('prior share-sheet')) {
        debugPrint("Share callback info ignored: $e");
        return;
      }
      if (outputFile != null && await outputFile.exists()) {
        await outputFile.delete();
      }
      debugPrint('Export MountPack Error: $e');
      if (_isNoSpaceLeftError(e)) {
        throw Exception('Storage penuh. Hapus file lama atau kosongkan memori lalu coba export lagi.');
      }
      rethrow;
    }
  }

  List<MindMapAsset> _buildBundleForExport(MindMapAsset asset) {
    final bundle = <MindMapAsset>[];
    if (asset.isFolder) {
      bundle.add(asset);
      _gatherFolderContentsRecursive(asset.id, bundle);
    } else {
      bundle.add(asset);
    }
    return bundle;
  }

  bool _isNoSpaceLeftError(Object error) {
    if (error is FileSystemException) {
      final osError = error.osError;
      if (osError?.errorCode == 28) {
        return true;
      }
      final message = (osError?.message ?? error.message).toLowerCase();
      if (message.contains('no space left on device') || message.contains('not enough space')) {
        return true;
      }
    }
    final fallback = error.toString().toLowerCase();
    return fallback.contains('no space left on device') || fallback.contains('errno = 28');
  }

  void _replaceNodeFileRefsWithBlobKeys(
    Map<String, dynamic> nodeJson,
    String Function(String path) registerBlob,
  ) {
    final attachments = nodeJson['attachments'];
    if (attachments is List) {
      for (final entry in attachments) {
        if (entry is Map<String, dynamic> && entry['type'] == 'file') {
          final path = entry['value'];
          if (path is String && path.isNotEmpty) {
            final key = registerBlob(path);
            entry['value'] = '$_blobPlaceholderPrefix$key';
          }
          entry.remove('fileData');
        }
      }
    }

    final tableData = nodeJson['tableData'];
    if (tableData is List) {
      _replaceTableFilePaths(tableData, registerBlob);
    }

    final blocks = nodeJson['descriptionBlocks'];
    if (blocks is List) {
      for (final block in blocks) {
        if (block is! Map<String, dynamic>) continue;
        if (block['type'] == 'attachment' && block['attachment'] is Map<String, dynamic>) {
          final attachment = block['attachment'] as Map<String, dynamic>;
          if (attachment['type'] == 'file') {
            final path = attachment['value'];
            if (path is String && path.isNotEmpty) {
              final key = registerBlob(path);
              attachment['value'] = '$_blobPlaceholderPrefix$key';
            }
            attachment.remove('fileData');
          }
        }

        if ((block['type'] == 'table' || block['type'] == 'chart') && block['tableData'] is List) {
          _replaceTableFilePaths(block['tableData'] as List, registerBlob);
        }

        block.remove('tableFileData');
      }
    }

    nodeJson.remove('topLevelTableFileData');
  }

  void _replaceTableFilePaths(List tableData, String Function(String path) registerBlob) {
    for (int r = 0; r < tableData.length; r++) {
      if (tableData[r] is! List) continue;
      final row = tableData[r] as List;
      for (int c = 0; c < row.length; c++) {
        final cell = row[c];
        if (cell is String && cell.startsWith(DescriptionBlock.tableFilePrefix)) {
          final payload = cell.replaceFirst(DescriptionBlock.tableFilePrefix, '');
          final splitIndex = payload.indexOf('|');
          if (splitIndex != -1) {
            final name = payload.substring(0, splitIndex);
            final path = payload.substring(splitIndex + 1);
            if (path.isNotEmpty) {
              final key = registerBlob(path);
              row[c] = '${DescriptionBlock.tableFilePrefix}$name|$_blobPlaceholderPrefix$key';
            }
          }
        }
      }
    }
  }

  Future<void> importFromMountPack(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);
      final blobPathByKey = <String, String>{};
      Map<String, dynamic> manifest;
      try {
        final magic = await _readStringWithLength(raf);
        if (magic != _mountPackMagic) {
          throw 'Invalid .mountpack file';
        }
        manifest = jsonDecode(await _readStringWithLength(raf));
        final blobCount = await _readInt32(raf);

        final docDir = await getApplicationDocumentsDirectory();
        for (int i = 0; i < blobCount; i++) {
          final key = await _readStringWithLength(raf);
          final filename = await _readStringWithLength(raf);
          final size = await _readInt64(raf);
          final safeName = filename.isEmpty ? 'attachment.bin' : filename;
          final newPath = '${docDir.path}/attachments/${DateTime.now().microsecondsSinceEpoch}_$safeName';
          final outputFile = File(newPath);
          await outputFile.parent.create(recursive: true);
          final sink = outputFile.openWrite();
          try {
            int remaining = size;
            const chunkSize = 1024 * 1024;
            while (remaining > 0) {
              final toRead = remaining > chunkSize ? chunkSize : remaining;
              final bytes = await raf.read(toRead);
              if (bytes.isEmpty) {
                throw 'Unexpected end of blob stream';
              }
              sink.add(bytes);
              remaining -= bytes.length;
            }
          } finally {
            await sink.close();
          }
          blobPathByKey[key] = newPath;
        }
      } finally {
        await raf.close();
      }

      if (manifest['format'] != 'mountpack2') {
        throw 'Invalid mountpack manifest';
      }

      final assetList = List<Map<String, dynamic>>.from(manifest['assets'] ?? []);
      for (final aJson in assetList) {
        final nodes = aJson['nodes'];
        if (nodes is List) {
          for (final node in nodes) {
            if (node is Map<String, dynamic>) {
              _recoverNodeFileRefsFromBlobKeys(node, blobPathByKey);
            }
          }
        }
      }

      await _importAssetsWithRemap(assetList, manifest['rootId']);
    } catch (e) {
      debugPrint('Import MountPack Error: $e');
      rethrow;
    }
  }

  void _recoverNodeFileRefsFromBlobKeys(Map<String, dynamic> nodeJson, Map<String, String> blobPathByKey) {
    final attachments = nodeJson['attachments'];
    if (attachments is List) {
      for (final entry in attachments) {
        if (entry is Map<String, dynamic> && entry['type'] == 'file' && entry['value'] is String) {
          final value = entry['value'] as String;
          if (value.startsWith(_blobPlaceholderPrefix)) {
            final key = value.replaceFirst(_blobPlaceholderPrefix, '');
            entry['value'] = blobPathByKey[key] ?? '';
          }
          entry.remove('fileData');
        }
      }
    }

    final tableData = nodeJson['tableData'];
    if (tableData is List) {
      _recoverTableFilePaths(tableData, blobPathByKey);
    }

    final blocks = nodeJson['descriptionBlocks'];
    if (blocks is List) {
      for (final block in blocks) {
        if (block is! Map<String, dynamic>) continue;
        if (block['type'] == 'attachment' && block['attachment'] is Map<String, dynamic>) {
          final attachment = block['attachment'] as Map<String, dynamic>;
          if (attachment['type'] == 'file' && attachment['value'] is String) {
            final value = attachment['value'] as String;
            if (value.startsWith(_blobPlaceholderPrefix)) {
              final key = value.replaceFirst(_blobPlaceholderPrefix, '');
              attachment['value'] = blobPathByKey[key] ?? '';
            }
            attachment.remove('fileData');
          }
        }
        if ((block['type'] == 'table' || block['type'] == 'chart') && block['tableData'] is List) {
          _recoverTableFilePaths(block['tableData'] as List, blobPathByKey);
        }
      }
    }
  }

  void _recoverTableFilePaths(List tableData, Map<String, String> blobPathByKey) {
    for (int r = 0; r < tableData.length; r++) {
      if (tableData[r] is! List) continue;
      final row = tableData[r] as List;
      for (int c = 0; c < row.length; c++) {
        final cell = row[c];
        if (cell is String && cell.startsWith(DescriptionBlock.tableFilePrefix)) {
          final payload = cell.replaceFirst(DescriptionBlock.tableFilePrefix, '');
          final splitIndex = payload.indexOf('|');
          if (splitIndex != -1) {
            final name = payload.substring(0, splitIndex);
            final ref = payload.substring(splitIndex + 1);
            if (ref.startsWith(_blobPlaceholderPrefix)) {
              final key = ref.replaceFirst(_blobPlaceholderPrefix, '');
              final resolvedPath = blobPathByKey[key] ?? '';
              row[c] = '${DescriptionBlock.tableFilePrefix}$name|$resolvedPath';
            }
          }
        }
      }
    }
  }

  Future<void> _importAssetsWithRemap(List<Map<String, dynamic>> assetList, String oldRootId) async {
    final idMapping = <String, String>{};
    final newAssets = <MindMapAsset>[];

    for (var aJson in assetList) {
      final a = MindMapAsset.fromJson(aJson);
      final oldId = a.id;
      final prefix = oldId.startsWith('chart_') ? 'chart_' : '';
      final newId = '${prefix}imp_${DateTime.now().millisecondsSinceEpoch}_$oldId';
      idMapping[oldId] = newId;
      a.id = newId;
      a.title = (oldId == oldRootId) ? '${a.title} (Imported)' : a.title;
      newAssets.add(a);
    }

    for (var a in newAssets) {
      final oldId = idMapping.entries.firstWhere((e) => e.value == a.id).key;
      final source = assetList.firstWhere((aj) => aj['id'] == oldId);
      final oldParentId = source['parentId'];

      if (oldParentId == null || !idMapping.containsKey(oldParentId)) {
        a.parentId = _currentFolderId;
      } else {
        a.parentId = idMapping[oldParentId];
      }
      _assets.insert(0, a);
    }

    await _saveToDisk();
    notifyListeners();
  }

  Future<void> _writeInt32(RandomAccessFile raf, int value) async {
    final data = ByteData(4)..setUint32(0, value, Endian.big);
    await raf.writeFrom(data.buffer.asUint8List());
  }

  Future<void> _writeInt64(RandomAccessFile raf, int value) async {
    final data = ByteData(8)..setInt64(0, value, Endian.big);
    await raf.writeFrom(data.buffer.asUint8List());
  }

  Future<int> _readInt32(RandomAccessFile raf) async {
    final bytes = await raf.read(4);
    if (bytes.length != 4) throw 'Corrupted package';
    return ByteData.sublistView(Uint8List.fromList(bytes)).getUint32(0, Endian.big);
  }

  Future<int> _readInt64(RandomAccessFile raf) async {
    final bytes = await raf.read(8);
    if (bytes.length != 8) throw 'Corrupted package';
    return ByteData.sublistView(Uint8List.fromList(bytes)).getInt64(0, Endian.big);
  }

  Future<void> _writeStringWithLength(RandomAccessFile raf, String value) async {
    final bytes = utf8.encode(value);
    await _writeInt32(raf, bytes.length);
    if (bytes.isNotEmpty) {
      await raf.writeFrom(bytes);
    }
  }

  Future<String> _readStringWithLength(RandomAccessFile raf) async {
    final length = await _readInt32(raf);
    if (length == 0) return '';
    final bytes = await raf.read(length);
    if (bytes.length != length) throw 'Corrupted package';
    return utf8.decode(bytes);
  }

  // Legacy support or alias
  Future<void> exportToMountMap([MindMapAsset? targetAsset]) async {
    final asset = targetAsset ?? _activeAsset;
    if (asset != null) await exportToMountFlow(asset);
  }

  void triggerUpdate() {
    notifyListeners();
  }

  Future<void> importFromMountMap(File file) async {
    if (file.path.endsWith('.mountpack')) {
      await importFromMountPack(file);
    } else if (file.path.endsWith('.mountflow')) {
      await importFromMountFlow(file);
    } else {
      // Basic mountmap import logic as fallback
      try {
        String content = await file.readAsString();
        Map<String, dynamic> data = jsonDecode(content);
        final newAsset = MindMapAsset(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: "${data['asset']['title']} (Imported)",
          createdAt: DateTime.now(),
          lastModified: DateTime.now(),
          parentId: _currentFolderId,
          isFolder: false,
        );
        if (data['nodes'] != null) {
          List<dynamic> nodeData = data['nodes'];
          newAsset.nodes = nodeData.map((n) => NodeModel.fromJson(n)).toList();
          newAsset.nodeCount = newAsset.nodes.length;
        }
        _assets.insert(0, newAsset);
        await _saveToDisk();
        notifyListeners();
      } catch (e) {
        debugPrint("Legacy Import Error: $e");
      }
    }
  }
}