import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../models/node_model.dart';
import '../providers/mountmap_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/chart_engine.dart';
import '../screens/attachment_viewer_screen.dart';
import 'aesthetic_toast.dart';

class DescriptionTemplate {
  final String title;
  final String category;
  final IconData icon;
  final String description;
  final String recommendedChartType;
  final List<List<String>> data;

  const DescriptionTemplate({
    required this.title,
    required this.category,
    required this.icon,
    required this.description,
    required this.recommendedChartType,
    required this.data,
  });
}

final List<DescriptionTemplate> kDescriptionTemplates = [
  // MONEY MANAGEMENT
  const DescriptionTemplate(
    title: "Advanced Money & Cashflow",
    category: "MONEY MANAGEMENT",
    icon: Icons.account_balance_wallet_rounded,
    description: "Multi-category budget, actual vs target, variance & financial status.",
    recommendedChartType: "Histogram",
    data: [
      ['Category', 'Type', 'Target (IDR)', 'Actual (IDR)', 'Variance (IDR)', 'Status'],
      ['Pemasukan Utama', 'Income', '15000000', '15500000', '+500000', 'Surplus'],
      ['Investasi & Tabungan', 'Savings', '4000000', '4000000', '0', 'On Target'],
      ['Kebutuhan Rutin', 'Expense', '5000000', '4800000', '-200000', 'Efficient'],
      ['Cicilan & Tagihan', 'Expense', '3000000', '3000000', '0', 'Paid'],
      ['Hiburan & Gaya Hidup', 'Expense', '2000000', '2300000', '+300000', 'Overbudget'],
      ['Dana Darurat', 'Savings', '1000000', '1000000', '0', 'On Target'],
    ],
  ),
  const DescriptionTemplate(
    title: "Investment Portfolio & Asset Allocation",
    category: "MONEY MANAGEMENT",
    icon: Icons.pie_chart_outline_rounded,
    description: "Asset distribution, portfolio value, ROI percentage and risk profile.",
    recommendedChartType: "Multi-level Pie Chart",
    data: [
      ['Asset Class', 'Specific Asset', 'Capital (IDR)', 'Current Value (IDR)', 'ROI (%)', 'Risk'],
      ['Saham & Reksadana', 'IHSG Top 10', '25000000', '28500000', '14.0', 'High'],
      ['Crypto Asset', 'Bitcoin & ETH', '10000000', '13500000', '35.0', 'Very High'],
      ['Obligasi Negara', 'ORI / SBR', '20000000', '21200000', '6.0', 'Low'],
      ['Emas Digital', 'Antam Logam Mulia', '15000000', '16800000', '12.0', 'Low'],
      ['Cash & Deposito', 'Bank Deposito', '10000000', '10400000', '4.0', 'Safe'],
    ],
  ),
  const DescriptionTemplate(
    title: "Debt & Financial Goal Planner",
    category: "MONEY MANAGEMENT",
    icon: Icons.savings_rounded,
    description: "Target savings, monthly progress, remaining balance, and target deadline.",
    recommendedChartType: "Radial Bar Chart",
    data: [
      ['Goal / Debt Name', 'Target Amount', 'Current Saved', 'Remaining', 'Deadline', 'Status'],
      ['Dana Darurat (6 Bulan)', '60000000', '45000000', '15000000', '2025-12-31', '75% Done'],
      ['DP Rumah Pertama', '150000000', '60000000', '90000000', '2026-06-30', '40% Done'],
      ['Liburan Jepang', '25000000', '20000000', '5000000', '2025-08-15', '80% Done'],
      ['Upgrade Laptop Workstation', '20000000', '18000000', '2000000', '2025-04-30', '90% Done'],
    ],
  ),

  // CREDENTIAL & PASSWORD MANAGEMENT
  const DescriptionTemplate(
    title: "Secure Account & Password Vault",
    category: "CREDENTIALS & SECURITY",
    icon: Icons.lock_person_rounded,
    description: "Centralized account credentials with category, security rating, and 2FA info.",
    recommendedChartType: "Rose Chart",
    data: [
      ['Service / App', 'Username / Email', 'Password / Master Key', 'Category', 'Security Rating', '2FA Status'],
      ['Google Worksuite', 'admin@mountmap.io', '••••••••••••', 'Work', 'Strong (100%)', 'Enabled (TOTP)'],
      ['GitHub Enterprise', 'dev-lead@mountmap.io', '••••••••••••', 'Development', 'Very Strong (100%)', 'Security Key'],
      ['AWS Console', 'root-admin', '••••••••••••', 'Infrastructure', 'Critical (100%)', 'Hardware Token'],
      ['Bank Mandiri BKN', 'user_financial_88', '••••••••••••', 'Banking', 'High Security', 'SMS & Biometric'],
      ['Figma Pro', 'designer@mountmap.io', '••••••••••••', 'Design', 'Medium', 'Enabled'],
    ],
  ),
  const DescriptionTemplate(
    title: "API Keys & Token Management",
    category: "CREDENTIALS & SECURITY",
    icon: Icons.key_rounded,
    description: "Track API tokens, secret keys, environment, rate limits and expiration.",
    recommendedChartType: "Butterfly Chart",
    data: [
      ['Service / Provider', 'Key ID / Client', 'Environment', 'Rate Limit (req/m)', 'Expiry Date', 'Status'],
      ['OpenAI API', 'sk-proj-99882...', 'Production', '10000', '2025-12-31', 'Active'],
      ['Stripe Payment', 'pk_live_51M...', 'Production', '5000', '2026-01-01', 'Active'],
      ['Firebase Cloud', 'mountmap-prod-app', 'Production', '50000', '2027-05-15', 'Active'],
      ['SendGrid Email', 'SG.x892a10...', 'Staging', '2000', '2025-09-30', 'Expiring Soon'],
      ['Mapbox GL', 'pk.eyJ1Ijoib...', 'Development', '1000', '2025-11-01', 'Active'],
    ],
  ),
  const DescriptionTemplate(
    title: "Server & DB Connection Vault",
    category: "CREDENTIALS & SECURITY",
    icon: Icons.dns_rounded,
    description: "Server IP, SSH ports, database credentials, environment and access level.",
    recommendedChartType: "Sankey Diagram",
    data: [
      ['Host / Server Name', 'IP / Domain', 'Port / Service', 'Admin User', 'Auth Method', 'Env Level'],
      ['Production Primary DB', '10.0.1.50', '5432 (PostgreSQL)', 'postgres_admin', 'TLS Certificate', 'Production'],
      ['Redis Cache Cluster', '10.0.1.80', '6379 (Redis)', 'default', 'Auth Passkey', 'Production'],
      ['App Kubernetes Node', '100.64.0.12', '22 (SSH)', 'deploy_sys', 'ED25519 Key', 'Production'],
      ['Staging Sandbox', '192.168.1.100', '22 / 3306', 'dev_root', 'SSH Keypair', 'Staging'],
    ],
  ),

  // PROJECT & TASK TRACKER
  const DescriptionTemplate(
    title: "Agile Sprint & Task Board",
    category: "PROJECT & MANAGEMENT",
    icon: Icons.task_alt_rounded,
    description: "Sprint tasks, assignees, story points, priority levels and execution status.",
    recommendedChartType: "Pareto Chart",
    data: [
      ['Task Name', 'Assignee', 'Story Points', 'Priority', 'Status', 'DueDate'],
      ['Auth Refactoring', 'Alex Dev', '8', 'High', 'In Progress', '2025-03-20'],
      ['UI Chart Engine Upgrade', 'Jules', '13', 'Critical', 'Completed', '2025-03-18'],
      ['Backend Speed Optimization', 'Sarah', '5', 'Medium', 'Review', '2025-03-22'],
      ['PDF Export Bugfix', 'Budi', '3', 'Low', 'Backlog', '2025-03-25'],
      ['User Analytics Dashboard', 'Maya', '8', 'High', 'In Progress', '2025-03-24'],
    ],
  ),

  // HABIT & HEALTH TRACKER
  const DescriptionTemplate(
    title: "Weekly Fitness & Health Tracker",
    category: "HEALTH & LIFESTYLE",
    icon: Icons.directions_run_rounded,
    description: "Daily workout duration, calories burned, water intake, and sleep quality.",
    recommendedChartType: "Histogram",
    data: [
      ['Day', 'Workout (Mins)', 'Calories (kcal)', 'Water (Liters)', 'Sleep (Hours)', 'Overall Feel'],
      ['Monday', '45', '420', '2.5', '7.5', 'Great'],
      ['Tuesday', '60', '580', '3.0', '8.0', 'Energetic'],
      ['Wednesday', '30', '290', '2.0', '6.5', 'Tired'],
      ['Thursday', '50', '490', '2.8', '7.0', 'Good'],
      ['Friday', '40', '380', '2.5', '8.5', 'Rested'],
      ['Saturday', '90', '850', '3.5', '9.0', 'Peak'],
      ['Sunday', '20', '180', '2.0', '8.0', 'Relaxed'],
    ],
  ),

  // SALES & MARKETING
  const DescriptionTemplate(
    title: "Sales Funnel & Conversion Rates",
    category: "SALES & MARKETING",
    icon: Icons.filter_alt_rounded,
    description: "Funnel stages, lead volume, conversion rate %, and estimated value.",
    recommendedChartType: "Alluvial Diagram",
    data: [
      ['Funnel Stage', 'Lead Count', 'Conversion Rate (%)', 'Pipeline Value (USD)'],
      ['Website Visitors', '50000', '100.0', '0'],
      ['Leads / Signups', '7500', '15.0', '150000'],
      ['Qualified Leads', '3000', '40.0', '120000'],
      ['Demo Scheduled', '1200', '40.0', '96000'],
      ['Proposal Sent', '600', '50.0', '72000'],
      ['Closed Won', '250', '41.6', '50000'],
    ],
  ),
];

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
  int _tableGeneration = 0;
  bool _progressDialogShown = false;

  void _showLoadingDialog(String message) {
    _progressDialogShown = true;
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: provider.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: MountMapColors.teal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: provider.textColor, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hideLoadingDialog() {
    if (_progressDialogShown && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _progressDialogShown = false;
    }
  }

  String _sanitizeFolderName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'MountMap' : sanitized;
  }

  Future<Directory> _getPublicDownloadDirectory({String? nodeFolderName}) async {
    Directory baseDir;
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        baseDir = downloadDir;
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final safeNodeFolder = _sanitizeFolderName(nodeFolderName ?? widget.node.text);
    final targetFolder = Directory('${baseDir.path}/MountMap/$safeNodeFolder');
    if (!await targetFolder.exists()) {
      await targetFolder.create(recursive: true);
    }
    return targetFolder;
  }

  Future<void> _saveFileToDevice(String filePath, String originalName, {String? subFolder}) async {
    try {
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        if (!mounted) return;
        AestheticToast.show(
          context,
          title: "FILE TIDAK DITEMUKAN",
          message: "File asal tidak ditemukan di penyimpanan lokal",
          type: ToastType.error,
          persistent: true,
        );
        return;
      }

      _showLoadingDialog("Sedang menyimpan file '$originalName' ke perangkat...");

      Directory targetDir = await _getPublicDownloadDirectory();
      if (subFolder != null && subFolder.trim().isNotEmpty) {
        final safeSubFolder = _sanitizeFolderName(subFolder);
        targetDir = Directory('${targetDir.path}/$safeSubFolder');
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      }

      final safeName = originalName.isEmpty ? sourceFile.path.split('/').last : originalName;
      String destPath = "${targetDir.path}/$safeName";

      if (await File(destPath).exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final nameParts = safeName.split('.');
        if (nameParts.length > 1) {
          final ext = nameParts.last;
          final base = nameParts.sublist(0, nameParts.length - 1).join('.');
          destPath = "${targetDir.path}/${base}_$timestamp.$ext";
        } else {
          destPath = "${targetDir.path}/${safeName}_$timestamp";
        }
      }

      await sourceFile.copy(destPath);
      _hideLoadingDialog();

      if (!mounted) return;
      AestheticToast.show(
        context,
        title: "SIMPAN FILE BERHASIL",
        message: "File '$safeName' berhasil disimpan ke folder perangkat:\n$destPath",
        type: ToastType.success,
        persistent: true,
      );
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      AestheticToast.show(
        context,
        title: "SIMPAN FILE GAGAL",
        message: "Gagal menyimpan file ke perangkat: $e",
        type: ToastType.error,
        persistent: true,
      );
    }
  }

  Future<void> _saveAllFilesToDevice(NodeModel node) async {
    final List<({String path, String name, String? subFolder})> filesToSave = [];

    // Map folder blocks for subfolder pathing
    final Map<String, String> folderNames = {};
    for (var block in node.descriptionBlocks) {
      if (block.type == BlockType.folder && block.content != null) {
        folderNames[block.id] = block.content!;
      }
    }

    for (var item in node.attachments) {
      if (item.type == 'file' && item.value.isNotEmpty) {
        filesToSave.add((path: item.value, name: item.name, subFolder: null));
      }
    }

    for (var block in node.descriptionBlocks) {
      final subFolder = block.folderId != null ? folderNames[block.folderId] : null;

      if (block.type == BlockType.attachment && block.attachment != null) {
        final item = block.attachment!;
        if (item.type == 'file' && item.value.isNotEmpty) {
          filesToSave.add((path: item.value, name: item.name, subFolder: subFolder));
        }
      }
      if ((block.type == BlockType.table || block.type == BlockType.chart) && block.tableData != null) {
        for (var row in block.tableData!) {
          for (var cell in row) {
            if (cell.startsWith(DescriptionBlock.tableFilePrefix)) {
              final parsed = _parseTableAttachmentValue(cell);
              if (parsed.value.isNotEmpty) {
                filesToSave.add((path: parsed.value, name: parsed.name, subFolder: subFolder));
              }
            }
          }
        }
      }
    }

    if (filesToSave.isEmpty) {
      AestheticToast.show(
        context,
        title: "TIDAK ADA FILE",
        message: "Tidak ada file lampiran yang ditemukan di deskripsi ini.",
        type: ToastType.info,
        persistent: true,
      );
      return;
    }

    _showLoadingDialog("Sedang menyimpan ${filesToSave.length} file deskripsi ke perangkat...");
    int successCount = 0;
    int failCount = 0;
    final baseTargetDir = await _getPublicDownloadDirectory(nodeFolderName: node.text);

    for (var fileItem in filesToSave) {
      try {
        final sourceFile = File(fileItem.path);
        if (await sourceFile.exists()) {
          Directory currentTargetDir = baseTargetDir;
          if (fileItem.subFolder != null && fileItem.subFolder!.trim().isNotEmpty) {
            final safeSub = _sanitizeFolderName(fileItem.subFolder!);
            currentTargetDir = Directory('${baseTargetDir.path}/$safeSub');
            if (!await currentTargetDir.exists()) {
              await currentTargetDir.create(recursive: true);
            }
          }

          final safeName = fileItem.name.isEmpty ? sourceFile.path.split('/').last : fileItem.name;
          String destPath = "${currentTargetDir.path}/$safeName";

          if (await File(destPath).exists()) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final nameParts = safeName.split('.');
            if (nameParts.length > 1) {
              final ext = nameParts.last;
              final base = nameParts.sublist(0, nameParts.length - 1).join('.');
              destPath = "${currentTargetDir.path}/${base}_$timestamp.$ext";
            } else {
              destPath = "${currentTargetDir.path}/${safeName}_$timestamp";
            }
          }

          await sourceFile.copy(destPath);
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    _hideLoadingDialog();

    if (!mounted) return;
    AestheticToast.show(
      context,
      title: "SIMPAN SEMUA FILE BERHASIL",
      message: "Berhasil menyimpan $successCount file deskripsi beserta struktur foldernya ke:\n${baseTargetDir.path}${failCount > 0 ? ' ($failCount gagal)' : ''}",
      type: ToastType.success,
      persistent: true,
    );
  }

  // Embedded chart interactive settings state per block
  final Map<String, Map<String, dynamic>> _chartInteractiveState = {};

  Map<String, dynamic> _getChartState(String blockId) {
    return _chartInteractiveState.putIfAbsent(blockId, () => {
      'primaryColor': MountMapColors.teal,
      'secondaryColor': MountMapColors.violet,
      'showStats': true,
      'showTrend': false,
      'intensity': 0.65,
      'thickness': 22.0,
      'opacity': 0.75,
    });
  }

  void _addFolderItem() {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final folderCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: provider.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Buat Folder Baru", style: TextStyle(color: provider.textColor, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: folderCtrl,
          autofocus: true,
          style: TextStyle(color: provider.textColor),
          decoration: InputDecoration(
            labelText: "Nama Folder Deskripsi",
            labelStyle: TextStyle(color: provider.textColor.withValues(alpha: 0.5)),
            hintText: "misal: Dokumen Proyek",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("BATAL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MountMapColors.teal, foregroundColor: Colors.white),
            onPressed: () {
              final folderName = folderCtrl.text.trim();
              if (folderName.isNotEmpty) {
                final blockId = DateTime.now().millisecondsSinceEpoch.toString();
                provider.addDescriptionBlock(
                  widget.node.id,
                  DescriptionBlock(
                    id: blockId,
                    type: BlockType.folder,
                    content: folderName,
                    isExpanded: true,
                  ),
                );
                Navigator.pop(dialogCtx);
                AestheticToast.show(
                  context,
                  title: "FOLDER DIBUAT",
                  message: "Folder '$folderName' berhasil dibuat di deskripsi.",
                  type: ToastType.success,
                  persistent: false,
                );
              }
            },
            child: const Text("BUAT FOLDER"),
          ),
        ],
      ),
    );
  }

  void _addTextItem({String? folderId}) {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final blockId = DateTime.now().millisecondsSinceEpoch.toString();
    provider.addDescriptionBlock(widget.node.id, DescriptionBlock(
      id: blockId,
      type: BlockType.text,
      content: "",
      folderId: folderId,
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
              leading: const CircleAvatar(backgroundColor: Colors.purpleAccent, child: Icon(Icons.folder_open_rounded, color: Colors.white, size: 20)),
              title: Text("Pick Local Folder (All Files)", style: TextStyle(color: provider.textColor)),
              subtitle: Text("Import folder & seisi filenya", style: TextStyle(color: provider.textColor.withValues(alpha: 0.5), fontSize: 10)),
              onTap: () {
                Navigator.pop(context);
                _pickAndAddFolder(provider);
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

  String _resolveDirectoryPath(String path) {
    if (path.contains('primary:')) {
      final relative = Uri.decodeFull(path.split('primary:').last);
      return '/storage/emulated/0/$relative';
    }
    if (path.contains('primary%3A')) {
      final relative = Uri.decodeFull(path.split('primary%3A').last);
      return '/storage/emulated/0/$relative';
    }
    return path;
  }

  Future<void> _pickAndAddFolder(MountMapProvider provider, {String? folderId}) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      List<File> filesToImport = [];
      String folderName = "Folder";

      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        final resolvedPath = _resolveDirectoryPath(selectedDirectory);
        final dir = Directory(resolvedPath);
        folderName = resolvedPath.split('/').last.replaceAll('/', '');
        if (folderName.isEmpty) folderName = "Folder";

        if (await dir.exists()) {
          try {
            final List<FileSystemEntity> entities = await dir.list(recursive: true).toList();
            filesToImport = entities.whereType<File>().where((f) {
              final name = f.path.split('/').last;
              return !name.startsWith('.');
            }).toList();
          } catch (e) {
            debugPrint("Directory listing restricted by Android SAF: $e");
          }
        }
      }

      // If SAF restriction prevents directory listing or no directory selected/returned empty, fallback to file selection inside folder
      if (filesToImport.isEmpty) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          dialogTitle: "Pilih file di dalam folder",
        );
        if (result != null && result.files.isNotEmpty) {
          for (var pf in result.files) {
            if (pf.path != null) {
              filesToImport.add(File(pf.path!));
            }
          }
          if (filesToImport.isNotEmpty) {
            final firstParent = filesToImport.first.parent.path;
            folderName = firstParent.split('/').last;
          }
        }
      }

      if (filesToImport.isEmpty) {
        if (!mounted) return;
        AestheticToast.show(
          context,
          title: "TIDAK ADA FILE",
          message: "Tidak ada file yang dipilih atau ditemukan dalam folder.",
          type: ToastType.info,
          persistent: true,
        );
        return;
      }

      _showLoadingDialog("Mengimpor ${filesToImport.length} file dari folder '$folderName'...");

      int importedCount = 0;
      int errorCount = 0;

      for (var file in filesToImport) {
        try {
          final fileName = file.path.split('/').last;
          final displayName = "$folderName/$fileName";
          final permanentPath = await provider.saveAttachmentFile(file.path, "${folderName}_$fileName");

          provider.addDescriptionBlock(
            widget.node.id,
            DescriptionBlock(
              id: "${DateTime.now().microsecondsSinceEpoch}_${importedCount}_$fileName",
              type: BlockType.attachment,
              attachment: AttachmentItem(
                id: "${DateTime.now().microsecondsSinceEpoch}_${importedCount}_$fileName",
                name: displayName,
                value: permanentPath,
                type: 'file',
              ),
              folderId: folderId,
            ),
          );
          importedCount++;
        } catch (e) {
          errorCount++;
        }
      }

      _hideLoadingDialog();

      if (!mounted) return;
      AestheticToast.show(
        context,
        title: "FOLDER BERHASIL DIIMPOR",
        message: "Berhasil menambahkan $importedCount file dari folder '$folderName' ke deskripsi${errorCount > 0 ? ' ($errorCount gagal)' : ''}.",
        type: ToastType.success,
        persistent: true,
      );
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      AestheticToast.show(
        context,
        title: "GAGAL MENGIMPOR FOLDER",
        message: "Gagal memproses folder: $e",
        type: ToastType.error,
        persistent: true,
      );
    }
  }

  Future<void> _pickAndAddFile(MountMapProvider provider, {String? folderId}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return;

      _showLoadingDialog("Sedang memproses lampiran file...");
      int addedCount = 0;
      List<String> fileNames = [];

      for (var file in result.files) {
        if (file.path != null) {
          String permanentPath = await provider.saveAttachmentFile(file.path!, file.name);
          provider.addDescriptionBlock(widget.node.id, DescriptionBlock(
            id: "${DateTime.now().millisecondsSinceEpoch}_${file.name}",
            type: BlockType.attachment,
            attachment: AttachmentItem(
              id: "${DateTime.now().millisecondsSinceEpoch}_${file.name}",
              name: file.name,
              value: permanentPath,
              type: 'file',
            ),
            folderId: folderId,
          ));
          addedCount++;
          fileNames.add(file.name);
        }
      }

      _hideLoadingDialog();

      if (!mounted) return;
      AestheticToast.show(
        context,
        title: "LAMPIRAN DITAMBAHKAN",
        message: "Berhasil menambahkan $addedCount lampiran file:\n${fileNames.join(', ')}",
        type: ToastType.success,
        persistent: true,
      );
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      AestheticToast.show(
        context,
        title: "GAGAL MENAMBAHKAN LAMPIRAN",
        message: "Gagal menambahkan lampiran file: $e",
        type: ToastType.error,
        persistent: true,
      );
    }
  }

  void _showCreateFileDialog(MountMapProvider provider) {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MountMapColors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                final fileName = nameCtrl.text.trim();
                Navigator.pop(dialogCtx);
                try {
                  _showLoadingDialog("Sedang membuat file baru '$fileName'...");

                  final dir = await getApplicationDocumentsDirectory();
                  final fileDir = Directory('${dir.path}/MountAttachments');
                  if (!await fileDir.exists()) await fileDir.create();

                  final file = File('${fileDir.path}/$fileName');
                  if (!await file.exists()) {
                    await file.writeAsString("");
                  }

                  provider.addDescriptionBlock(widget.node.id, DescriptionBlock(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: BlockType.attachment,
                    attachment: AttachmentItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: fileName,
                      value: file.path,
                      type: 'file',
                    ),
                  ));

                  _hideLoadingDialog();

                  if (!mounted) return;
                  AestheticToast.show(
                    context,
                    title: "FILE DIBUAT",
                    message: "Berhasil membuat dan menempelkan file '$fileName' di deskripsi.",
                    type: ToastType.success,
                    persistent: true,
                  );
                } catch (e) {
                  _hideLoadingDialog();
                  if (!mounted) return;
                  AestheticToast.show(
                    context,
                    title: "GAGAL MEMBUAT FILE",
                    message: "Gagal membuat file: $e",
                    type: ToastType.error,
                    persistent: true,
                  );
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
    _showTemplatePickerModal(
      context: context,
      provider: provider,
      title: "CREATE TABLE WITH TEMPLATE",
      onSelectTemplate: (template) {
        final blockId = DateTime.now().millisecondsSinceEpoch.toString();
        provider.addDescriptionBlock(widget.node.id, DescriptionBlock(
          id: blockId,
          type: BlockType.table,
          tableData: template.data.map((r) => List<String>.from(r)).toList(),
        ));
      },
      onSelectBlank: () {
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
      },
    );
  }

  void _addChartItem() {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    _showTemplatePickerModal(
      context: context,
      provider: provider,
      title: "CREATE CHART WITH TEMPLATE",
      onSelectTemplate: (template) {
        final blockId = DateTime.now().millisecondsSinceEpoch.toString();
        provider.addDescriptionBlock(widget.node.id, DescriptionBlock(
          id: blockId,
          type: BlockType.chart,
          chartType: template.recommendedChartType,
          tableData: template.data.map((r) => List<String>.from(r)).toList(),
        ));
      },
      onSelectBlank: () {
        _showChartTypePicker(context, provider);
      },
    );
  }

  void _showTemplatePickerModal({
    required BuildContext context,
    required MountMapProvider provider,
    required String title,
    required Function(DescriptionTemplate) onSelectTemplate,
    required VoidCallback onSelectBlank,
  }) {
    final isDark = provider.currentTheme == AppThemeMode.dark;
    final categories = <String, List<DescriptionTemplate>>{};
    for (var t in kDescriptionTemplates) {
      categories.putIfAbsent(t.category, () => []).add(t);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: provider.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: provider.textColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: MountMapColors.teal,
                            letterSpacing: 2,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Pilih template siap pakai untuk Money Management, Credential Vault, dsb.",
                          style: TextStyle(
                            color: provider.textColor.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onSelectBlank();
                    },
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text("Blank", style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: provider.textColor,
                      side: BorderSide(color: provider.textColor.withValues(alpha: 0.2)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: categories.entries.map((catEntry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(width: 4, height: 14, decoration: BoxDecoration(color: MountMapColors.teal, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            Text(
                              catEntry.key,
                              style: TextStyle(color: provider.textColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                            ),
                          ],
                        ),
                      ),
                      ...catEntry.value.map((template) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: provider.textColor.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: provider.textColor.withValues(alpha: 0.06)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: MountMapColors.teal.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(template.icon, color: MountMapColors.teal, size: 20),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    template.title,
                                    style: TextStyle(color: provider.textColor, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: MountMapColors.violet.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    template.recommendedChartType,
                                    style: const TextStyle(color: MountMapColors.violet, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                template.description,
                                style: TextStyle(color: provider.textColor.withValues(alpha: 0.5), fontSize: 10),
                              ),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MountMapColors.teal,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                onSelectTemplate(template);
                              },
                              child: const Text("GUNAKAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      }),
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

  void _showChartTypePicker(BuildContext context, MountMapProvider provider) {
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

  bool _isTableAttachmentValue(String value) {
    return value.startsWith(DescriptionBlock.tableFilePrefix) || value.startsWith(DescriptionBlock.tableLinkPrefix);
  }

  String _buildTableFileValue(String name, String path) => '${DescriptionBlock.tableFilePrefix}$name|$path';
  String _buildTableLinkValue(String name, String url) => '${DescriptionBlock.tableLinkPrefix}$name|$url';

  ({String name, String value}) _parseTableAttachmentValue(String raw) {
    final payload = raw.replaceFirst(DescriptionBlock.tableFilePrefix, '').replaceFirst(DescriptionBlock.tableLinkPrefix, '');
    final splitIndex = payload.indexOf('|');
    if (splitIndex == -1) {
      return (name: payload, value: payload);
    }
    return (
      name: payload.substring(0, splitIndex),
      value: payload.substring(splitIndex + 1),
    );
  }

  String _displayTableCellValue(String value) {
    if (!_isTableAttachmentValue(value)) return value;
    final parsed = _parseTableAttachmentValue(value);
    final isLink = value.startsWith(DescriptionBlock.tableLinkPrefix);
    return isLink ? '[LINK] ${parsed.name}' : '[FILE] ${parsed.name}';
  }

  Future<void> _pickFileForTableCell(
    MountMapProvider provider,
    List<List<String>> data,
    int row,
    int column,
    void Function(void Function()) setModalState,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false);
      if (result == null || result.files.isEmpty || result.files.first.path == null) return;
      final file = result.files.first;
      final savedPath = await provider.saveAttachmentFile(file.path!, file.name);
      setModalState(() {
        data[row][column] = _buildTableFileValue(file.name, savedPath);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to attach file to table cell')),
      );
    }
  }

  void _showAddLinkForTableCell(
    MountMapProvider provider,
    List<List<String>> data,
    int row,
    int column,
    void Function(void Function()) setModalState,
  ) {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: provider.cardColor,
        title: Text('Attach Link to Cell', style: TextStyle(color: provider.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: provider.textColor),
              decoration: const InputDecoration(labelText: 'Display Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlCtrl,
              style: TextStyle(color: provider.textColor),
              decoration: const InputDecoration(labelText: 'URL'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (urlCtrl.text.trim().isEmpty) return;
              var url = urlCtrl.text.trim();
              if (!url.startsWith('http')) url = 'https://$url';
              final name = nameCtrl.text.trim().isEmpty ? url : nameCtrl.text.trim();
              setModalState(() {
                data[row][column] = _buildTableLinkValue(name, url);
              });
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Future<void> _openTableCellValue(String value) async {
    if (!_isTableAttachmentValue(value)) return;
    final parsed = _parseTableAttachmentValue(value);
    final isLink = value.startsWith(DescriptionBlock.tableLinkPrefix);

    try {
      if (isLink) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttachmentViewerScreen(
              item: AttachmentItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: parsed.name,
                value: parsed.value,
                type: 'link',
              ),
            ),
          ),
        );
      } else {
        final path = parsed.value.toLowerCase();
        final supportedExt = [
          '.jpg', '.jpeg', '.png', '.webp',
          '.txt',
          '.mp3', '.wav', '.m4a',
          '.mp4', '.mp5', '.mov', '.mkv'
        ];
        final isInAppSupported = supportedExt.any((ext) => path.endsWith(ext));

        if (isInAppSupported) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttachmentViewerScreen(
                item: AttachmentItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: parsed.name,
                  value: parsed.value,
                  type: 'file',
                ),
              ),
            ),
          );
        } else {
          await _openFileExternally(parsed.value);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open table attachment: $e')),
      );
    }
  }

  void _showTableEditor(MountMapProvider provider, String nodeId, String blockId, {bool isChart = false}) {
    final node = provider.nodes.firstWhere((n) => n.id == nodeId);
    final block = node.descriptionBlocks.firstWhere((b) => b.id == blockId);
    List<List<String>> data = List.from(block.tableData?.map((row) => List<String>.from(row)) ?? [["", ""]]);
    if (data.isEmpty) {
      data = [["", ""]];
    }
    if (data.first.isEmpty) {
      data[0] = [""];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: provider.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: provider.textColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isChart ? "Chart Data Editor" : "Table Data Editor", style: TextStyle(color: provider.textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          _showTemplatePickerModal(
                            context: context,
                            provider: provider,
                            title: "LOAD TEMPLATE",
                            onSelectTemplate: (template) {
                              setModalState(() {
                                data = template.data.map((r) => List<String>.from(r)).toList();
                                _tableGeneration++;
                              });
                            },
                            onSelectBlank: () {},
                          );
                        },
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: MountMapColors.teal),
                        label: const Text("Load Template", style: TextStyle(color: MountMapColors.teal, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Table actions',
                        icon: const Icon(Icons.more_vert_rounded, color: MountMapColors.teal),
                        onSelected: (value) {
                          setModalState(() {
                            if (value == 'add_row') {
                              data.add(List.generate(data[0].length, (_) => ""));
                            } else if (value == 'add_column') {
                              for (var r in data) {
                                r.add("");
                              }
                            } else if (value == 'remove_row') {
                              if (data.length > 1) {
                                data.removeLast();
                              }
                            } else if (value == 'remove_column') {
                              if (data.isNotEmpty && data[0].length > 1) {
                                for (var r in data) {
                                  r.removeLast();
                                }
                              }
                            }
                          });
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'add_row',
                            child: Row(
                              children: [
                                Icon(Icons.add_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Add Row'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'add_column',
                            child: Row(
                              children: [
                                Icon(Icons.view_column_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Add Column'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'remove_row',
                            child: Row(
                              children: [
                                Icon(Icons.remove_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Remove Row'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'remove_column',
                            child: Row(
                              children: [
                                Icon(Icons.view_column_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Remove Column'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isChart
                      ? "Edit data chart langsung di sel atau muat Template. Gunakan menu ⋮ kanan atas untuk add/remove row/column."
                      : "Gunakan menu ⋮ kanan atas untuk add/remove row/column, atau muat Template. Gunakan menu ⋮ di tiap sel untuk file/link.",
                  style: TextStyle(color: provider.textColor.withValues(alpha: 0.6), fontSize: 11),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width - 64,
                      ),
                      child: Column(
                        children: [
                          // Column Actions Header
                          Row(
                            children: [
                              const SizedBox(width: 40), // Row action column offset
                              ...List.generate(data[0].length, (cIdx) => SizedBox(
                                width: isChart ? 170 : 220,
                                child: Center(
                                  child: PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(Icons.more_horiz_rounded, size: 16, color: provider.textColor.withValues(alpha: 0.3)),
                                    onSelected: (value) {
                                      setModalState(() {
                                        _tableGeneration++;
                                        if (value == 'move_left' && cIdx > 0) {
                                          for (var r in data) {
                                            final temp = r[cIdx];
                                            r[cIdx] = r[cIdx - 1];
                                            r[cIdx - 1] = temp;
                                          }
                                        } else if (value == 'move_right' && cIdx < data[0].length - 1) {
                                          for (var r in data) {
                                            final temp = r[cIdx];
                                            r[cIdx] = r[cIdx + 1];
                                            r[cIdx + 1] = temp;
                                          }
                                        } else if (value == 'duplicate') {
                                          for (var r in data) {
                                            r.insert(cIdx + 1, r[cIdx]);
                                          }
                                        } else if (value == 'delete' && data[0].length > 1) {
                                          for (var r in data) {
                                            r.removeAt(cIdx);
                                          }
                                        }
                                      });
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'move_left', child: Row(children: [Icon(Icons.arrow_back_rounded, size: 16), SizedBox(width: 8), Text('Move Left')])),
                                      const PopupMenuItem(value: 'move_right', child: Row(children: [Icon(Icons.arrow_forward_rounded, size: 16), SizedBox(width: 8), Text('Move Right')])),
                                      const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_rounded, size: 16), SizedBox(width: 8), Text('Duplicate Column')])),
                                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent), SizedBox(width: 8), Text('Delete Column', style: TextStyle(color: Colors.redAccent))])),
                                    ],
                                  ),
                                ),
                              )),
                            ],
                          ),
                          ...data.asMap().entries.map((rowEntry) {
                            final int rIdx = rowEntry.key;
                            return Container(
                              decoration: BoxDecoration(
                                color: rIdx == 0 ? MountMapColors.teal.withValues(alpha: 0.1) : null,
                                border: Border(
                                  left: BorderSide(color: provider.textColor.withValues(alpha: 0.1)),
                                  right: BorderSide(color: provider.textColor.withValues(alpha: 0.1)),
                                  top: BorderSide(color: provider.textColor.withValues(alpha: 0.1)),
                                  bottom: BorderSide(color: provider.textColor.withValues(alpha: 0.1)),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Row Actions
                                  SizedBox(
                                    width: 40,
                                    child: Center(
                                      child: PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        icon: Icon(Icons.more_vert_rounded, size: 16, color: provider.textColor.withValues(alpha: 0.3)),
                                        onSelected: (value) {
                                          setModalState(() {
                                            _tableGeneration++;
                                            if (value == 'move_up' && rIdx > 0) {
                                              final temp = data[rIdx];
                                              data[rIdx] = data[rIdx - 1];
                                              data[rIdx - 1] = temp;
                                            } else if (value == 'move_down' && rIdx < data.length - 1) {
                                              final temp = data[rIdx];
                                              data[rIdx] = data[rIdx + 1];
                                              data[rIdx + 1] = temp;
                                            } else if (value == 'duplicate') {
                                              data.insert(rIdx + 1, List<String>.from(data[rIdx]));
                                            } else if (value == 'delete' && data.length > 1) {
                                              data.removeAt(rIdx);
                                            }
                                          });
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'move_up', child: Row(children: [Icon(Icons.arrow_upward_rounded, size: 16), SizedBox(width: 8), Text('Move Up')])),
                                          const PopupMenuItem(value: 'move_down', child: Row(children: [Icon(Icons.arrow_downward_rounded, size: 16), SizedBox(width: 8), Text('Move Down')])),
                                          const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_rounded, size: 16), SizedBox(width: 8), Text('Duplicate Row')])),
                                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent), SizedBox(width: 8), Text('Delete Row', style: TextStyle(color: Colors.redAccent))])),
                                        ],
                                      ),
                                    ),
                                  ),
                                  ...rowEntry.value.asMap().entries.map((colEntry) {
                                    final int cIdx = colEntry.key;
                                    final bool isAttachmentCell = !isChart && _isTableAttachmentValue(colEntry.value);
                                    final String displayValue = isChart ? colEntry.value : _displayTableCellValue(colEntry.value);

                                    return Container(
                                      width: isChart ? 170 : 220,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: provider.textColor.withValues(alpha: 0.08)),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              key: ValueKey('cell_${rIdx}_${cIdx}_$_tableGeneration'),
                                              initialValue: displayValue,
                                              readOnly: isAttachmentCell,
                                              style: TextStyle(
                                                color: provider.textColor,
                                                fontSize: 13,
                                                fontWeight: rIdx == 0 ? FontWeight.bold : FontWeight.normal,
                                              ),
                                              minLines: 1,
                                              maxLines: null,
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              onChanged: (val) => data[rIdx][cIdx] = val,
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: Icon(Icons.more_vert_rounded, size: 16, color: provider.textColor.withValues(alpha: 0.65)),
                                            tooltip: 'Cell actions',
                                            onSelected: (value) async {
                                              if (value == 'move_left' && cIdx > 0) {
                                                setModalState(() {
                                                  _tableGeneration++;
                                                  final temp = data[rIdx][cIdx];
                                                  data[rIdx][cIdx] = data[rIdx][cIdx - 1];
                                                  data[rIdx][cIdx - 1] = temp;
                                                });
                                                return;
                                              }
                                              if (value == 'move_right' && cIdx < data[rIdx].length - 1) {
                                                setModalState(() {
                                                  _tableGeneration++;
                                                  final temp = data[rIdx][cIdx];
                                                  data[rIdx][cIdx] = data[rIdx][cIdx + 1];
                                                  data[rIdx][cIdx + 1] = temp;
                                                });
                                                return;
                                              }
                                              if (value == 'move_up' && rIdx > 0) {
                                                setModalState(() {
                                                  _tableGeneration++;
                                                  final temp = data[rIdx][cIdx];
                                                  data[rIdx][cIdx] = data[rIdx - 1][cIdx];
                                                  data[rIdx - 1][cIdx] = temp;
                                                });
                                                return;
                                              }
                                              if (value == 'move_down' && rIdx < data.length - 1) {
                                                setModalState(() {
                                                  _tableGeneration++;
                                                  final temp = data[rIdx][cIdx];
                                                  data[rIdx][cIdx] = data[rIdx + 1][cIdx];
                                                  data[rIdx + 1][cIdx] = temp;
                                                });
                                                return;
                                              }

                                              if (value == 'attach_file') {
                                                await _pickFileForTableCell(provider, data, rIdx, cIdx, setModalState);
                                                return;
                                              }
                                              if (value == 'attach_link') {
                                                _showAddLinkForTableCell(provider, data, rIdx, cIdx, setModalState);
                                                return;
                                              }
                                              if (value == 'save_to_device' && isAttachmentCell && colEntry.value.startsWith(DescriptionBlock.tableFilePrefix)) {
                                                final parsed = _parseTableAttachmentValue(colEntry.value);
                                                await _saveFileToDevice(parsed.value, parsed.name);
                                                return;
                                              }
                                              if (value == 'open' && isAttachmentCell) {
                                                await _openTableCellValue(colEntry.value);
                                                return;
                                              }
                                              if (value == 'clear_attachment' && isAttachmentCell) {
                                                setModalState(() {
                                                  data[rIdx][cIdx] = '';
                                                });
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(value: 'move_left', child: Row(children: [Icon(Icons.arrow_back_rounded, size: 16), SizedBox(width: 8), Text('Move Cell Left')])),
                                              const PopupMenuItem(value: 'move_right', child: Row(children: [Icon(Icons.arrow_forward_rounded, size: 16), SizedBox(width: 8), Text('Move Cell Right')])),
                                              const PopupMenuItem(value: 'move_up', child: Row(children: [Icon(Icons.arrow_upward_rounded, size: 16), SizedBox(width: 8), Text('Move Cell Up')])),
                                              const PopupMenuItem(value: 'move_down', child: Row(children: [Icon(Icons.arrow_downward_rounded, size: 16), SizedBox(width: 8), Text('Move Cell Down')])),
                                              if (!isChart && rIdx != 0)
                                                const PopupMenuItem(
                                                  value: 'attach_file',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.attach_file_rounded, size: 16),
                                                      SizedBox(width: 8),
                                                      Text('Attach File'),
                                                    ],
                                                  ),
                                                ),
                                              if (!isChart && rIdx != 0 && isAttachmentCell && colEntry.value.startsWith(DescriptionBlock.tableFilePrefix))
                                                const PopupMenuItem(
                                                  value: 'save_to_device',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.download_rounded, size: 16, color: MountMapColors.teal),
                                                      SizedBox(width: 8),
                                                      Text('Simpan ke Perangkat'),
                                                    ],
                                                  ),
                                                ),
                                              if (!isChart && rIdx != 0)
                                                const PopupMenuItem(
                                                  value: 'attach_link',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.link_rounded, size: 16),
                                                      SizedBox(width: 8),
                                                      Text('Attach Link'),
                                                    ],
                                                  ),
                                                ),
                                              if (!isChart && rIdx != 0 && isAttachmentCell)
                                                const PopupMenuItem(
                                                  value: 'open',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.open_in_new_rounded, size: 16),
                                                      SizedBox(width: 8),
                                                      Text('Open Attachment'),
                                                    ],
                                                  ),
                                                ),
                                              if (!isChart && rIdx != 0 && isAttachmentCell)
                                                const PopupMenuItem(
                                                  value: 'clear_attachment',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.clear_rounded, size: 16),
                                                      SizedBox(width: 8),
                                                      Text('Clear Attachment'),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: MountMapColors.teal, foregroundColor: Colors.white),
                  onPressed: () {
                    provider.updateDescriptionBlock(nodeId, blockId, tableData: data);
                    Navigator.pop(context);
                  },
                  child: const Text("SAVE CHANGES"),
                ),
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
      width: MediaQuery.of(context).size.width > 600 ? 550 : double.infinity,
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
          _buildHeader(node, textColor, isDark),
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
                  final blockNumber = _getBlockTypeSequence(node!.descriptionBlocks, entry.key);
                  return _buildBlock(
                    key: ValueKey(entry.value.id),
                    entry.value,
                    provider,
                    node!,
                    textColor,
                    isDark,
                    entry.key,
                    blockNumber,
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
          _buildFooter(provider, node),
        ],
      ),
    );
  }

  Widget _buildHeader(NodeModel node, Color textColor, bool isDark) {
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
              node.text.toUpperCase(),
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
            icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white),
            tooltip: "Simpan Semua File Deskripsi ke Perangkat",
            onPressed: () => _saveAllFilesToDevice(node),
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

  Widget _buildBlock(DescriptionBlock block, MountMapProvider provider, NodeModel node, Color textColor, bool isDark, int index, int blockNumber, {required Key key}) {
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
                  _buildSectionTitle('${_getBlockTypeLabel(block.type).toUpperCase()} $blockNumber', _getIconForType(block.type), textColor),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 16, color: textColor.withValues(alpha: 0.5)),
                    onPressed: () => provider.duplicateDescriptionBlock(node.id, block.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    onPressed: () => provider.removeDescriptionBlock(node.id, block.id),
                  ),
                ],
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
      case BlockType.folder: return Icons.folder_rounded;
    }
  }

  int _getBlockTypeSequence(List<DescriptionBlock> blocks, int currentIndex) {
    final currentType = blocks[currentIndex].type;
    int sequence = 0;

    for (int i = 0; i <= currentIndex; i++) {
      if (blocks[i].type == currentType) {
        sequence++;
      }
    }

    return sequence;
  }

  String _getBlockTypeLabel(BlockType type) {
    switch (type) {
      case BlockType.text:
        return 'Text';
      case BlockType.attachment:
        return 'Attachment';
      case BlockType.table:
        return 'Table';
      case BlockType.chart:
        return 'Chart';
      case BlockType.folder:
        return 'Folder';
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
      case BlockType.folder:
        return _buildFolderBlock(block, provider, node, textColor);
    }
  }

  Widget _buildFolderBlock(DescriptionBlock block, MountMapProvider provider, NodeModel node, Color textColor) {
    final folderName = block.content ?? "Folder Deskripsi";
    final isExpanded = block.isExpanded;
    final folderBlocks = node.descriptionBlocks.where((b) => b.folderId == block.id).toList();

    return Container(
      decoration: BoxDecoration(
        color: MountMapColors.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MountMapColors.teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const CircleAvatar(
              backgroundColor: MountMapColors.teal,
              child: Icon(Icons.folder_open_rounded, color: Colors.white, size: 20),
            ),
            title: Text(
              folderName,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              "${folderBlocks.length} item di dalam folder",
              style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: MountMapColors.teal),
                  tooltip: "Tambah File ke Folder ini",
                  onPressed: () => _pickAndAddFile(provider, folderId: block.id),
                ),
                IconButton(
                  icon: Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 22, color: textColor),
                  onPressed: () {
                    setState(() {
                      block.isExpanded = !block.isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 0.5),
            Padding(
              padding: const EdgeInsets.all(12),
              child: folderBlocks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          "Folder kosong. Gunakan tombol + di atas untuk menambah item.",
                          style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 11),
                        ),
                      ),
                    )
                  : Column(
                      children: folderBlocks.asMap().entries.map((fEntry) {
                        final childBlock = fEntry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 32,
                                color: MountMapColors.teal.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildBlockContent(childBlock, provider, node, textColor, true),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                onPressed: () => provider.removeDescriptionBlock(node.id, childBlock.id),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ],
      ),
    );
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLink)
              IconButton(
                icon: const Icon(Icons.download_rounded, size: 18, color: MountMapColors.teal),
                tooltip: "Simpan ke Perangkat",
                onPressed: () => _saveFileToDevice(item.value, item.name),
              ),
            Icon(Icons.open_in_new_rounded, size: 14, color: provider.textColor.withValues(alpha: 0.3)),
          ],
        ),
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
            MaterialPageRoute(
              builder: (context) => AttachmentViewerScreen(
                item: AttachmentItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: item.name,
                  value: item.value,
                  type: 'file',
                ),
              ),
            ),
          );
        } else {
          await _openFileExternally(item.value);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cannot open item: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _openFileExternally(String path) async {
    final result = await OpenFile.open(path);
    if (!mounted) return;

    if (result.type == ResultType.noAppToOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada aplikasi untuk membuka file ini (PDF/DOCX/PPT). Install viewer yang sesuai.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka file: ${result.message}'),
          backgroundColor: Colors.redAccent,
        ),
      );
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
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 120, maxWidth: 280),
                    child: InkWell(
                      onTap: _isTableAttachmentValue(cell) ? () => _openTableCellValue(cell) : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _displayTableCellValue(cell),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                              style: TextStyle(color: textColor, fontSize: 12),
                            ),
                          ),
                          if (_isTableAttachmentValue(cell)) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(Icons.open_in_new_rounded, size: 12, color: MountMapColors.teal),
                            ),
                            if (cell.startsWith(DescriptionBlock.tableFilePrefix))
                              IconButton(
                                icon: const Icon(Icons.download_rounded, size: 14, color: MountMapColors.teal),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: "Simpan ke Perangkat",
                                onPressed: () {
                                  final parsed = _parseTableAttachmentValue(cell);
                                  _saveFileToDevice(parsed.value, parsed.name);
                                },
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )).toList(),
              )).toList(),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: MountMapColors.teal),
              label: const Text("Load Template", style: TextStyle(fontSize: 12, color: MountMapColors.teal)),
              onPressed: () {
                _showTemplatePickerModal(
                  context: context,
                  provider: provider,
                  title: "APPLY TEMPLATE TO TABLE",
                  onSelectTemplate: (template) {
                    provider.updateDescriptionBlock(node.id, block.id, tableData: template.data.map((r) => List<String>.from(r)).toList());
                  },
                  onSelectBlank: () {},
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: const Text("Edit Table", style: TextStyle(fontSize: 12)),
              onPressed: () => _showTableEditor(provider, node.id, block.id),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildChartBlock(DescriptionBlock block, MountMapProvider provider, NodeModel node) {
    final chartData = block.tableData ?? const [];
    final rowCount = chartData.length > 1 ? chartData.length - 1 : 0;
    final chartState = _getChartState(block.id);
    final GlobalKey chartRepaintKey = GlobalKey();

    // Compute basic statistics if numerical values exist
    final stats = _computeChartStats(chartData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: provider.textColor.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: provider.textColor.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.insights_rounded, color: chartState['primaryColor'] as Color, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            (block.chartType ?? "Chart").toUpperCase(),
                            style: TextStyle(
                              color: provider.textColor.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: MountMapColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$rowCount rows',
                      style: const TextStyle(
                        color: MountMapColors.teal,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.fullscreen_rounded, size: 20, color: MountMapColors.teal),
                    tooltip: "Full Screen Interactive View",
                    onPressed: () => _openFullscreenChartModal(provider, block),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Mini Toolbar for Interactive Customization directly in Description
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chartMiniToggle(
                      label: "Stats",
                      icon: Icons.analytics_outlined,
                      isActive: chartState['showStats'] as bool,
                      onToggle: () => setState(() => chartState['showStats'] = !(chartState['showStats'] as bool)),
                    ),
                    const SizedBox(width: 6),
                    _chartMiniToggle(
                      label: "Trend",
                      icon: Icons.show_chart_rounded,
                      isActive: chartState['showTrend'] as bool,
                      onToggle: () => setState(() => chartState['showTrend'] = !(chartState['showTrend'] as bool)),
                    ),
                    const SizedBox(width: 6),
                    _chartColorPresetChip(
                      name: "Teal/Violet",
                      p: MountMapColors.teal,
                      s: MountMapColors.violet,
                      onSelect: () => setState(() {
                        chartState['primaryColor'] = MountMapColors.teal;
                        chartState['secondaryColor'] = MountMapColors.violet;
                      }),
                    ),
                    const SizedBox(width: 4),
                    _chartColorPresetChip(
                      name: "Amber/Red",
                      p: Colors.amber,
                      s: Colors.redAccent,
                      onSelect: () => setState(() {
                        chartState['primaryColor'] = Colors.amber;
                        chartState['secondaryColor'] = Colors.redAccent;
                      }),
                    ),
                    const SizedBox(width: 4),
                    _chartColorPresetChip(
                      name: "Cyan/Blue",
                      p: Colors.cyanAccent,
                      s: Colors.blueAccent,
                      onSelect: () => setState(() {
                        chartState['primaryColor'] = Colors.cyanAccent;
                        chartState['secondaryColor'] = Colors.blueAccent;
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // RepaintBoundary for PNG Exporting
              RepaintBoundary(
                key: chartRepaintKey,
                child: Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: provider.currentTheme == AppThemeMode.dark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: provider.textColor.withValues(alpha: 0.08)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: ChartEnginePainter(
                        chartType: block.chartType ?? 'rose chart',
                        data: NodeModel(id: 'temp', text: '', position: Offset.zero, tableData: block.tableData),
                        primaryColor: chartState['primaryColor'] as Color,
                        secondaryColor: chartState['secondaryColor'] as Color,
                        showStats: chartState['showStats'] as bool,
                        showTrend: chartState['showTrend'] as bool,
                        isDark: provider.currentTheme == AppThemeMode.dark,
                        visualSettings: {
                          'intensity': chartState['intensity'] as double,
                          'thickness': chartState['thickness'] as double,
                          'opacity': chartState['opacity'] as double,
                        },
                      ),
                    ),
                  ),
                ),
              ),

              if (stats != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: MountMapColors.teal.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MountMapColors.teal.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statBadge("SUM", stats.sum.toStringAsFixed(1)),
                      _statBadge("AVG", stats.avg.toStringAsFixed(1)),
                      _statBadge("MAX", stats.max.toStringAsFixed(1)),
                      _statBadge("MIN", stats.min.toStringAsFixed(1)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: MountMapColors.teal),
              label: const Text("Template"),
              onPressed: () {
                _showTemplatePickerModal(
                  context: context,
                  provider: provider,
                  title: "LOAD TEMPLATE TO CHART",
                  onSelectTemplate: (template) {
                    provider.updateDescriptionBlock(
                      node.id,
                      block.id,
                      chartType: template.recommendedChartType,
                      tableData: template.data.map((r) => List<String>.from(r)).toList(),
                    );
                  },
                  onSelectBlank: () {},
                );
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.type_specimen_rounded, size: 14),
              label: const Text("Chart Type"),
              onPressed: () => _showChartTypePickerForExistingBlock(provider, node.id, block.id),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.image_rounded, size: 14, color: Colors.amber),
              label: const Text("Export PNG"),
              onPressed: () => _exportEmbeddedChartToPNG(chartRepaintKey, block.chartType ?? 'Chart'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: MountMapColors.teal,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: const Text("Edit Data"),
              onPressed: () => _showTableEditor(provider, node.id, block.id, isChart: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chartMiniToggle({required String label, required IconData icon, required bool isActive, required VoidCallback onToggle}) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? MountMapColors.teal.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? MountMapColors.teal : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isActive ? MountMapColors.teal : Colors.white54),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isActive ? MountMapColors.teal : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _chartColorPresetChip({required String name, required Color p, required Color s, required VoidCallback onSelect}) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: p, shape: BoxShape.circle)),
            const SizedBox(width: 2),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: s, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }

  Widget _statBadge(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: MountMapColors.teal, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  ({double sum, double avg, double max, double min})? _computeChartStats(List<List<String>> data) {
    if (data.length < 2) return null;
    final doubleValues = <double>[];

    for (int r = 1; r < data.length; r++) {
      for (int c = 0; c < data[r].length; c++) {
        final d = double.tryParse(data[r][c]);
        if (d != null) {
          doubleValues.add(d);
        }
      }
    }

    if (doubleValues.isEmpty) return null;

    double sum = doubleValues.reduce((a, b) => a + b);
    double max = doubleValues.reduce((a, b) => a > b ? a : b);
    double min = doubleValues.reduce((a, b) => a < b ? a : b);
    double avg = sum / doubleValues.length;

    return (sum: sum, avg: avg, max: max, min: min);
  }

  Future<void> _exportEmbeddedChartToPNG(GlobalKey key, String chartName) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/Chart_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles([XFile(file.path)], text: 'MountMap Chart Export: $chartName');
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('Share callback error') || e.toString().contains('prior share-sheet')) {
        debugPrint("Share callback info ignored: $e");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export PNG error: $e'),
            duration: const Duration(days: 365),
            action: SnackBarAction(
              label: 'CLOSE',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  void _openFullscreenChartModal(MountMapProvider provider, DescriptionBlock block) {
    final chartState = _getChartState(block.id);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: provider.cardColor,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fullscreen_rounded, color: MountMapColors.teal),
                        const SizedBox(width: 8),
                        Text(
                          (block.chartType ?? "Chart").toUpperCase(),
                          style: TextStyle(color: provider.textColor, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: provider.textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: provider.currentTheme == AppThemeMode.dark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: provider.textColor.withValues(alpha: 0.1)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: ChartEnginePainter(
                        chartType: block.chartType ?? 'rose chart',
                        data: NodeModel(id: 'temp', text: '', position: Offset.zero, tableData: block.tableData),
                        primaryColor: chartState['primaryColor'] as Color,
                        secondaryColor: chartState['secondaryColor'] as Color,
                        showStats: chartState['showStats'] as bool,
                        showTrend: chartState['showTrend'] as bool,
                        isDark: provider.currentTheme == AppThemeMode.dark,
                        visualSettings: {
                          'intensity': chartState['intensity'] as double,
                          'thickness': chartState['thickness'] as double,
                          'opacity': chartState['opacity'] as double,
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _chartMiniToggle(
                      label: "Stats Overlay",
                      icon: Icons.analytics_outlined,
                      isActive: chartState['showStats'] as bool,
                      onToggle: () {
                        setDialogState(() => chartState['showStats'] = !(chartState['showStats'] as bool));
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 12),
                    _chartMiniToggle(
                      label: "Trend Line",
                      icon: Icons.show_chart_rounded,
                      isActive: chartState['showTrend'] as bool,
                      onToggle: () {
                        setDialogState(() => chartState['showTrend'] = !(chartState['showTrend'] as bool));
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildFooter(MountMapProvider provider, NodeModel node) {
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
            _buildActionButton('Buat Folder', Icons.create_new_folder_rounded, _addFolderItem, provider.textColor),
            const SizedBox(width: 8),
            _buildActionButton('Add Text', Icons.note_add_rounded, _addTextItem, provider.textColor),
            const SizedBox(width: 8),
            _buildActionButton('Add Attachment', Icons.attach_file_rounded, _addAttachmentItem, provider.textColor),
            const SizedBox(width: 8),
            _buildActionButton('Add Table', Icons.table_chart_rounded, _addTableItem, provider.textColor),
            const SizedBox(width: 8),
            _buildActionButton('Add Chart', Icons.bar_chart_rounded, _addChartItem, provider.textColor),
            const SizedBox(width: 8),
            _buildActionButton('Simpan Semua File', Icons.download_for_offline_rounded, () => _saveAllFilesToDevice(node), provider.textColor),
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
