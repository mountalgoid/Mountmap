import 'package:flutter/material.dart';

// Class Pembantu untuk menyimpan data Link/File dengan Nama Custom
class AttachmentItem {
  String id;
  String name; // Nama Tampilan (misal: "Dokumen Skripsi")
  String value; // URL atau File Path (misal: "/storage/emulated/0/Download/skripsi.pdf")
  String type; // 'link' atau 'file'
  String? fileData; // Base64 data for export/import

  AttachmentItem({
    required this.id, 
    required this.name, 
    required this.value, 
    required this.type,
    this.fileData,
  });

  Map<String, dynamic> toJson() {
    final map = {'id': id, 'name': name, 'value': value, 'type': type};
    if (fileData != null) map['fileData'] = fileData!;
    return map;
  }
  
  factory AttachmentItem.fromJson(Map<String, dynamic> json) {
    return AttachmentItem(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? "Untitled",
      value: json['value'] ?? "",
      type: json['type'] ?? "link",
      fileData: json['fileData'],
    );
  }
}

enum BlockType { text, attachment, table, chart }

class DescriptionBlock {
  String id;
  BlockType type;
  String? content; // For text
  AttachmentItem? attachment; // For attachment
  List<List<String>>? tableData; // For table or chart
  String? chartType; // For chart

  DescriptionBlock({
    required this.id,
    required this.type,
    this.content,
    this.attachment,
    this.tableData,
    this.chartType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'attachment': attachment?.toJson(),
      'tableData': tableData,
      'chartType': chartType,
    };
  }

  factory DescriptionBlock.fromJson(Map<String, dynamic> json) {
    return DescriptionBlock(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: BlockType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'text'),
        orElse: () => BlockType.text,
      ),
      content: json['content'],
      attachment: json['attachment'] != null ? AttachmentItem.fromJson(json['attachment']) : null,
      tableData: json['tableData'] != null
          ? (json['tableData'] as List).map((row) => List<String>.from(row)).toList()
          : null,
      chartType: json['chartType'],
    );
  }
}

class NodeModel {
  String id;
  String text;
  Offset position;
  String? parentId;
  String? note;
  List<String> labels;
  String? description;
  String? marker;
  String? linkedAssetId;
  List<String> crossConnections;
  
  // [UPDATED] Menggunakan List<AttachmentItem> agar bisa simpan banyak & edit nama
  List<AttachmentItem> attachments;
  
  // [NEW] Alert/Notification feature
  String? alertMessage;
  DateTime? alertDate;
  bool alertEnabled; 

  // [NEW] Custom Styling
  int? bodyColor;
  int? textColor;
  int? iconColor;
  bool isGradient;
  bool isTextGradient;
  bool isIconGradient;
  String? nodeNumber;
  String shapeType; // 'box', 'circle', 'diamond', 'hexagon'
  String? connectionLabel; // Label untuk garis ke parent (misal: "Yes", "No")
  List<List<String>>? tableData; // Untuk Diagram Tabel
  List<String>? dataList; // Untuk Diagram Piramida/Timeline
  List<DescriptionBlock> descriptionBlocks;

  NodeModel({
    required this.id,
    required this.text,
    required this.position,
    this.parentId,
    this.note,
    this.labels = const [],
    this.description,
    this.marker,
    this.linkedAssetId,
    this.crossConnections = const [],
    this.attachments = const [], // Default kosong
    this.alertMessage,
    this.alertDate,
    this.alertEnabled = false,
    this.bodyColor,
    this.textColor,
    this.iconColor,
    this.isGradient = false,
    this.isTextGradient = false,
    this.isIconGradient = false,
    this.nodeNumber,
    this.shapeType = 'box',
    this.connectionLabel,
    this.tableData,
    this.dataList,
    this.descriptionBlocks = const [],
  });

  factory NodeModel.fromJson(Map<String, dynamic> json) {
    var attachList = <AttachmentItem>[];
    
    // Migrasi data lama (jika ada field 'linkUrl' atau 'filePaths' versi lama)
    if (json['linkUrl'] != null) {
      attachList.add(AttachmentItem(id: 'legacy_link', name: 'Website Link', value: json['linkUrl'], type: 'link'));
    }
    if (json['filePaths'] != null) {
      for (var path in List<String>.from(json['filePaths'])) {
        attachList.add(AttachmentItem(id: DateTime.now().toString(), name: path.split('/').last, value: path, type: 'file'));
      }
    }
    
    // Load data attachments baru
    if (json['attachments'] != null) {
      attachList = (json['attachments'] as List).map((i) => AttachmentItem.fromJson(i)).toList();
    }

    var blocks = <DescriptionBlock>[];
    if (json['descriptionBlocks'] != null) {
      blocks = (json['descriptionBlocks'] as List).map((i) => DescriptionBlock.fromJson(i)).toList();
    } else {
      // Migration logic
      if (json['description'] != null && (json['description'] as String).isNotEmpty) {
        blocks.add(DescriptionBlock(
          id: 'migrated_desc',
          type: BlockType.text,
          content: json['description'],
        ));
      }
      for (var att in attachList) {
        blocks.add(DescriptionBlock(
          id: 'migrated_att_${att.id}',
          type: BlockType.attachment,
          attachment: att,
        ));
      }
      if (json['tableData'] != null) {
        blocks.add(DescriptionBlock(
          id: 'migrated_table',
          type: BlockType.table,
          tableData: (json['tableData'] as List).map((row) => List<String>.from(row)).toList(),
        ));
      }
    }

    return NodeModel(
      id: json['id'],
      text: json['text'],
      parentId: json['parentId'],
      note: json['note'],
      labels: json['labels'] != null ? List<String>.from(json['labels']) : (json['label'] != null ? [json['label']] : []),
      description: json['description'],
      marker: json['marker'],
      linkedAssetId: json['linkedAssetId'],
      crossConnections: json['crossConnections'] != null ? List<String>.from(json['crossConnections']) : [],
      attachments: attachList,
      alertMessage: json['alertMessage'],
      alertDate: json['alertDate'] != null ? DateTime.parse(json['alertDate']) : null,
      alertEnabled: json['alertEnabled'] ?? false,
      bodyColor: json['bodyColor'],
      textColor: json['textColor'],
      iconColor: json['iconColor'],
      isGradient: json['isGradient'] ?? false,
      isTextGradient: json['isTextGradient'] ?? false,
      isIconGradient: json['isIconGradient'] ?? false,
      nodeNumber: json['nodeNumber'],
      shapeType: json['shapeType'] ?? 'box',
      connectionLabel: json['connectionLabel'],
      tableData: json['tableData'] != null
          ? (json['tableData'] as List).map((row) => List<String>.from(row)).toList()
          : null,
      dataList: json['dataList'] != null ? List<String>.from(json['dataList']) : null,
      descriptionBlocks: blocks,
      position: Offset(
        json['dx']?.toDouble() ?? 0.0,
        json['dy']?.toDouble() ?? 0.0,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'parentId': parentId,
      'note': note,
      'labels': labels,
      'description': description,
      'marker': marker,
      'linkedAssetId': linkedAssetId,
      'crossConnections': crossConnections,
      'attachments': attachments.map((a) => a.toJson()).toList(), // Simpan list
      'alertMessage': alertMessage,
      'alertDate': alertDate?.toIso8601String(),
      'alertEnabled': alertEnabled,
      'bodyColor': bodyColor,
      'textColor': textColor,
      'iconColor': iconColor,
      'isGradient': isGradient,
      'isTextGradient': isTextGradient,
      'isIconGradient': isIconGradient,
      'nodeNumber': nodeNumber,
      'shapeType': shapeType,
      'connectionLabel': connectionLabel,
      'tableData': tableData,
      'dataList': dataList,
      'descriptionBlocks': descriptionBlocks.map((b) => b.toJson()).toList(),
      'dx': position.dx,
      'dy': position.dy,
    };
  }
  
  // Helper: Cek apakah punya file/link tertentu
  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasLinks => attachments.any((a) => a.type == 'link');
  bool get hasFiles => attachments.any((a) => a.type == 'file');
  
  // Helper: Cek apakah alert aktif dan belum lewat
  bool get hasActiveAlert => alertEnabled && alertDate != null && alertDate!.isAfter(DateTime.now());
  bool get isAlertOverdue => alertEnabled && alertDate != null && alertDate!.isBefore(DateTime.now());
}