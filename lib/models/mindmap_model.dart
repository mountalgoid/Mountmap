import 'node_model.dart';

class MindMapAsset {
  String id;
  String text;
  final DateTime createdAt;
  DateTime lastModified;
  String folderName; // Tetap dipertahankan untuk info lokasi
  int nodeCount;     // Menandakan jumlah peak di dalamnya
  final bool isFolder;
  String? parentId;
  List<NodeModel> nodes; // FITUR BARU: Menyimpan data struktur canvas (Auto-Save)

  MindMapAsset({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.lastModified,
    this.folderName = "Root",
    this.nodeCount = 0,
    this.isFolder = false,
    this.parentId,
    List<NodeModel>? nodes,
  }) : nodes = nodes ?? [];

  // Helper untuk sinkronisasi judul di UI
  String get title => text;
  
  set title(String value) {
    text = value;
  }

  // Memperbarui timestamp saat ada perubahan (drag node/edit teks)
  void triggerUpdate() {
    lastModified = DateTime.now();
  }

  // ==========================================================
  // SERIALISASI DATA (Untuk Simpan Permanen ke Memori HP)
  // ==========================================================

  /// Mengubah objek ke format JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'folderName': folderName,
      'nodeCount': nodeCount,
      'isFolder': isFolder,
      'parentId': parentId,
      // Mengubah daftar objek NodeModel menjadi JSON list
      'nodes': nodes.map((n) => n.toJson()).toList(),
    };
  }

  /// Membangkitkan objek dari format JSON
  factory MindMapAsset.fromJson(Map<String, dynamic> json) {
    return MindMapAsset(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
      folderName: json['folderName'] as String? ?? "Root",
      nodeCount: json['nodeCount'] as int? ?? 0,
      isFolder: json['isFolder'] as bool? ?? false,
      parentId: json['parentId'] as String?,
      // Mengonversi kembali JSON list menjadi daftar objek NodeModel
      nodes: json['nodes'] != null
          ? (json['nodes'] as List)
              .map((n) => NodeModel.fromJson(n as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}