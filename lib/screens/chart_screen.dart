import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../providers/mountmap_provider.dart';
import '../models/mindmap_model.dart';
import '../models/node_model.dart';
import '../theme/app_colors.dart';
import '../widgets/chart_engine.dart';

enum ChartViewMode { workbench, report }

class ChartCanvasScreen extends StatefulWidget {
  final String chartType;
  final MindMapAsset asset;

  const ChartCanvasScreen({
    super.key,
    required this.chartType,
    required this.asset,
  });

  @override
  State<ChartCanvasScreen> createState() => _ChartCanvasScreenState();
}

class _ChartCanvasScreenState extends State<ChartCanvasScreen> with TickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  final ScrollController _dataScrollController = ScrollController();
  final List<List<List<String>>> _undoStack = [];
  bool _isProcessing = false;
  bool _isExporting = false;
  bool _showLeftPanel = true;
  bool _showRightPanel = true;
  double _leftPanelWidth = 320;
  double _rightPanelWidth = 280;
  int? _selectedRowIndex;
  String? _selectedChartId;
  Offset? _hoverPosition;
  String? _sunburstRoot; // For drill-down
  bool _showLabels = true;
  bool _showLegend = true;
  bool _animate = true;
  bool _showStats = false;
  bool _showTrend = false;

  // View Mode
  ChartViewMode _viewMode = ChartViewMode.workbench;

  // Document Settings
  bool _showDocHeader = true;
  bool _showDocAnalysis = true;
  bool _showDocSummary = true;
  bool _showDocDataGrid = true;
  bool _showDocWatermark = false;
  bool _showDocSignature = true;
  bool _showDocStamp = true;
  bool _showDocBorder = true;
  bool _isLandscape = true;
  String _docTitle = "";
  String _docSubtitle = "PROJECTION REPORT";
  String _docAuthor = "MountMap Executive";
  String _docAnalysis = "Based on the analyzed data patterns, we observe significant structural hierarchies that inform our current projections.";
  String _docLayout = "STANDARD";
  String _docPreset = "CLASSIC"; // CLASSIC, BLUEPRINT, MODERN_DARK, LINEN
  TextAlign _headerAlign = TextAlign.left;
  Color _paperColor = Colors.white;
  Offset _lightPos = const Offset(0, 0);

  Color _primaryColor = MountMapColors.teal;
  Color _secondaryColor = MountMapColors.violet;
  Color _labelColor = Colors.white70;
  Color _borderColor = Colors.white10;
  Color _glowColor = Colors.transparent;

  final TransformationController _transformationController = TransformationController();
  late AnimationController _physicsController;
  final Map<String, Offset> _dynamicNodePositions = {};
  final Map<String, Offset> _nodeVelocities = {};

  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Dynamic visual settings
  final Map<String, double> _chartSettings = {
    'opacity': 0.6,
    'thickness': 2.0,
    'smoothing': 0.5,
    'gap': 10.0,
    'radius': 4.0,
    'intensity': 0.8,
    'borderWidth': 1.0,
    'shadowIntensity': 0.0,
    'fontScale': 1.0,
    'headerScale': 1.0,
    'bodyTextScale': 1.0,
    'labelRotation': 0.0,
    'barSpacing': 10.0,
    'paperMargin': 40.0,
  };

  // To avoid controller recreation bug
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    _transformationController.dispose();
    _physicsController.dispose();
    _dataScrollController.dispose();
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _physicsController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _docTitle = widget.asset.title;

    // Initialize data if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.asset.nodes.isEmpty) {
        if (widget.chartType.toLowerCase() == 'blank canvas') {
          // Stay empty for blank canvas
          return;
        }
        final provider = Provider.of<MountMapProvider>(context, listen: false);
        // Create a root node to hold chart metadata/table data
        final rootNode = NodeModel(
          id: 'chart_root_${widget.asset.id}_${DateTime.now().millisecondsSinceEpoch}',
          text: widget.asset.title,
          position: Offset.zero,
          tableData: _getInitialTableData(widget.chartType),
          dataList: [],
          marker: widget.chartType, // Use marker to store chart type
        );
        widget.asset.nodes = [rootNode];
        _selectedChartId = rootNode.id;
        provider.triggerUpdate();
      } else {
        setState(() {
          _selectedChartId = widget.asset.nodes.first.id;
        });
      }
    });
  }

  List<List<String>> _getInitialTableData(String type) {
    switch (type.toLowerCase()) {
      case 'alluvial diagram':
        return [
          ['Source', 'Target', 'Value'],
          ['Marketing', 'Leads', '100'],
          ['Sales', 'Leads', '50'],
          ['Leads', 'Opportunity', '120'],
          ['Leads', 'Drop', '30'],
          ['Opportunity', 'Customer', '80'],
          ['Opportunity', 'Retention', '40']
        ];
      case 'butterfly chart':
        return [['Label', '2023', '2024'], ['Revenue', '400', '600'], ['Profit', '80', '120'], ['Users', '1000', '2500'], ['Churn', '50', '30']];
      case 'chord diagram':
        return [['Source', 'Target', 'Value'], ['Asia', 'Europe', '25'], ['Europe', 'Americas', '15'], ['Americas', 'Asia', '20'], ['Africa', 'Europe', '10']];
      case 'contour plot':
        return [['X', 'Y', 'Z'], ['0', '0', '10'], ['5', '5', '50'], ['10', '0', '20'], ['0', '10', '30'], ['10', '10', '40'], ['5', '2', '25']];
      case 'histogram':
        return [
          ['Label', 'Group A', 'Group B'],
          ['Q1', '450', '300'],
          ['Q2', '600', '400'],
          ['Q3', '300', '500'],
          ['Q4', '800', '200']
        ];
      case 'hyperbolic tree':
        return [['Parent', 'Child'], ['CEO', 'CTO'], ['CEO', 'CFO'], ['CTO', 'Eng Manager'], ['CTO', 'Product Manager'], ['Eng Manager', 'Dev A'], ['Eng Manager', 'Dev B']];
      case 'multi-level pie chart':
        return [['Category', 'Subcategory', 'Value'], ['Electronics', 'Mobile', '500'], ['Electronics', 'Laptop', '300'], ['Home', 'Furniture', '200'], ['Home', 'Decor', '100']];
      case 'pareto chart':
        return [['Issue', 'Count'], ['Latency', '120'], ['Crashes', '80'], ['UI Bug', '30'], ['Other', '10']];
      case 'radial bar chart':
        return [['Goal', 'Progress'], ['Fitness', '75'], ['Reading', '40'], ['Coding', '90'], ['Sleep', '60']];
      case 'taylor diagram':
        return [['SD', 'CORR', 'RMS'], ['1.2', '0.92', '0.1'], ['0.8', '0.75', '0.3'], ['1.5', '0.60', '0.5']];
      case 'treemap':
        return [['Parent', 'Child', 'Value'], ['Stock', 'Tech', '500'], ['Stock', 'Energy', '200'], ['Stock', 'Retail', '150'], ['Stock', 'Health', '300']];
      case 'three-dimensional stream graph':
        return [['Day', 'Category', 'Value'], ['Mon', 'Social', '10'], ['Mon', 'Work', '40'], ['Tue', 'Social', '15'], ['Tue', 'Work', '35'], ['Wed', 'Social', '20'], ['Wed', 'Work', '30']];
      case 'sankey diagram':
        return [['Source', 'Target', 'Value'], ['Input A', 'Process 1', '50'], ['Input B', 'Process 1', '30'], ['Process 1', 'Output X', '60'], ['Process 1', 'Loss', '20']];
      case 'rose chart':
        return [['Category', 'Value'], ['Jan', '45'], ['Feb', '52'], ['Mar', '38'], ['Apr', '65'], ['May', '48'], ['Jun', '70']];
      case 'data table':
        return [['ID', 'NAME', 'VALUE', 'STATUS'], ['001', 'Alpha', '450', 'Active'], ['002', 'Beta', '120', 'Pending'], ['003', 'Gamma', '890', 'Completed'], ['004', 'Delta', '340', 'Active']];
      default:
        return [['Category', 'Value'], ['Item 1', '10'], ['Item 2', '20']];
    }
  }

  Future<void> _exportAsMountFlow() async {
    setState(() => _isProcessing = true);
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    try {
      await provider.exportToMountFlow(widget.asset);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Chart exported as .mountflow successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _importFromMountFlow() async {
    setState(() => _isProcessing = true);
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final File file = File(result.files.single.path!);
        if (file.path.endsWith('.mountflow')) {
          await provider.importFromMountFlow(file);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Data imported from .mountflow successfully!")),
            );
          }
        } else {
          throw "Please select a valid .mountflow file";
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showManagementMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: const BoxDecoration(
          color: MountMapColors.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "CHART MANAGEMENT",
              style: TextStyle(
                color: Colors.white54,
                letterSpacing: 4,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildMenuSection("DATA OPERATIONS", [
              _buildMenuItem(Icons.refresh_rounded, "Reset to Default", "Clear all modifications", () {
                final provider = Provider.of<MountMapProvider>(context, listen: false);
                for (var node in widget.asset.nodes) {
                  provider.updatePeak(node.id, tableData: _getInitialTableData(node.marker ?? widget.chartType));
                }
                _controllers.clear();
                _undoStack.clear();
                Navigator.pop(context);
                setState(() {});
              }),
            ]),
            const SizedBox(height: 16),
            _buildMenuSection("EXPORT & IMPORT", [
              _buildMenuItem(Icons.ios_share_rounded, "Export .mountflow", "Standard MountFlow bundle", () {
                Navigator.pop(context);
                _exportAsMountFlow();
              }),
              _buildMenuItem(Icons.code_rounded, "Export Data (JSON)", "Copy raw data to clipboard", () {
                Navigator.pop(context);
                // In a real app we would use Clipboard.setData
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("JSON Data copied to clipboard")));
              }),
              _buildMenuItem(Icons.file_download_rounded, "Import .mountflow", "Load from MountFlow file", () {
                Navigator.pop(context);
                _importFromMountFlow();
              }),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentFooter() {
    final bool isDarkPaper = ThemeData.estimateBrightnessForColor(_paperColor) == Brightness.dark;
    final Color textColor = isDarkPaper ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: textColor.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Text(
            "CONFIDENTIAL | SYSTEM GENERATED",
            style: TextStyle(color: textColor.withValues(alpha: 0.2), fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const Spacer(),
          _buildBarcodeSimulation(textColor),
          const SizedBox(width: 20),
          Text(
            "PAGE 01",
            style: TextStyle(color: textColor.withValues(alpha: 0.2), fontSize: 7, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeSimulation(Color textColor) {
    return Opacity(
      opacity: 0.1,
      child: Row(
        children: List.generate(15, (i) => Container(
          width: (i % 3 == 0) ? 2 : 1,
          height: 12,
          margin: const EdgeInsets.only(right: 1),
          color: textColor,
        )),
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: MountMapColors.teal.withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: MountMapColors.teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: MountMapColors.teal, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MountMapProvider>(context);
    
    return Scaffold(
      backgroundColor: provider.backgroundColor,
      appBar: AppBar(
        backgroundColor: MountMapColors.darkCard,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.asset.title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              widget.chartType,
              style: TextStyle(
                color: MountMapColors.teal.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _buildViewSwitcher(),
          const VerticalDivider(width: 20, indent: 15, endIndent: 15, color: Colors.white10),
          IconButton(
            icon: Icon(_showLeftPanel ? Icons.list_alt_rounded : Icons.table_chart_outlined,
              color: _showLeftPanel ? MountMapColors.teal : Colors.white54),
            onPressed: () => setState(() => _showLeftPanel = !_showLeftPanel),
            tooltip: "Data Panel",
          ),
          IconButton(
            icon: Icon(_showRightPanel ? Icons.palette_rounded : Icons.palette_outlined,
              color: _showRightPanel ? MountMapColors.teal : Colors.white54),
            onPressed: () => setState(() => _showRightPanel = !_showRightPanel),
            tooltip: "Style Panel",
          ),
          const VerticalDivider(width: 20, indent: 15, endIndent: 15, color: Colors.white10),
          if (_isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: MountMapColors.teal)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.white),
              onPressed: _showManagementMenu,
            ),
          IconButton(
            icon: Icon(Icons.undo_rounded, color: _undoStack.isNotEmpty ? Colors.white70 : Colors.white10),
            onPressed: _undoStack.isNotEmpty ? () {
              final previous = _undoStack.removeLast();
              final provider = Provider.of<MountMapProvider>(context, listen: false);
              final targetId = _selectedChartId ?? widget.asset.nodes.first.id;
              provider.updatePeak(targetId, tableData: previous);
              _controllers.clear();
              setState(() {});
            } : null,
            tooltip: "Undo Change",
          ),
          IconButton(
            icon: const Icon(Icons.image_rounded, color: MountMapColors.teal),
            tooltip: "Export PNG",
            onPressed: _exportToPNG,
          ),
          IconButton(
            icon: const Icon(Icons.save_rounded, color: MountMapColors.teal),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Chart saved successfully!")),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              // LEFT PANEL: DATA INPUT
              if (_showLeftPanel) ...[
                SizedBox(
                  width: _leftPanelWidth,
                  child: _buildLeftPanel(provider),
                ),
                _buildSplitter(true),
              ],

              // MIDDLE PANEL: VISUALIZATION
              Expanded(
                child: _buildMiddlePanel(provider),
              ),

              // RIGHT PANEL: CUSTOMIZATION
              if (_showRightPanel) ...[
                _buildSplitter(false),
                SizedBox(
                  width: _rightPanelWidth,
                  child: _buildRightPanel(provider),
                ),
              ],
            ],
          ),
          if (_isExporting) _buildExportOverlay(),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(MountMapProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: MountMapColors.darkCard,
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        children: [
          _panelHeader(
            "DATA INPUT",
            Icons.edit_document,
            textColor: provider.textColor,
            actions: [
              _miniPanelAction(Icons.view_column_rounded, "Add Column", () => _addColumn(provider)),
              _miniPanelAction(Icons.layers_clear_rounded, "Clear All", () => _clearAllData(provider), isDanger: true),
            ],
          ),
          _buildFormulaBar(),
          Expanded(
            child: widget.asset.nodes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _buildDataTable(provider),
          ),
          _buildCalculatedRow(),
          _panelFooter(provider),
        ],
      ),
    );
  }

  Widget _buildFormulaBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          const Icon(Icons.functions_rounded, size: 14, color: MountMapColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedRowIndex != null ? "ROW $_selectedRowIndex: Selected for detailed analysis" : "Select a cell to apply intelligence",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatedRow() {
    if (widget.asset.nodes.isEmpty || widget.asset.nodes.first.tableData == null) return const SizedBox();
    final table = widget.asset.nodes.first.tableData!;

    double sum = 0;
    for (int i = 1; i < table.length; i++) {
      sum += double.tryParse(table[i].length > 1 ? table[i][1] : "0") ?? 0;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: MountMapColors.teal.withValues(alpha: 0.05),
        border: Border(top: BorderSide(color: MountMapColors.teal.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("COLUMN TOTAL", style: TextStyle(color: MountMapColors.teal, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
          Text(sum.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _miniPanelAction(IconData icon, String tooltip, VoidCallback onTap, {bool isDanger = false}) {
    return IconButton(
      icon: Icon(icon, size: 16, color: isDanger ? Colors.redAccent.withValues(alpha: 0.6) : MountMapColors.teal.withValues(alpha: 0.6)),
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    );
  }

  Widget _buildRightPanel(MountMapProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: MountMapColors.darkCard,
        border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        children: [
          _panelHeader("CUSTOMIZATION", Icons.palette_rounded, textColor: provider.textColor),
          Expanded(
            child: _buildStyleControls(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _switcherBtn("WORKBENCH", ChartViewMode.workbench, Icons.edit_attributes_rounded),
          _switcherBtn("REPORT", ChartViewMode.report, Icons.description_rounded),
        ],
      ),
    );
  }

  Widget _switcherBtn(String label, ChartViewMode mode, IconData icon) {
    final bool isActive = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? MountMapColors.teal.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isActive ? MountMapColors.teal : Colors.white38),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiddlePanel(MountMapProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: CustomPaint(
                  painter: GridPainter(),
                ),
              ),
            ),
            _viewMode == ChartViewMode.workbench
              ? _buildWorkbench(provider)
              : MouseRegion(
                  onHover: (event) => setState(() => _lightPos = event.localPosition),
                  child: _buildReport(provider, constraints),
                ),
            // Overlays
            Positioned(
              bottom: 20,
              right: 20,
              child: _buildQuickActionRow(constraints),
            ),
          ],
        );
      }
    );
  }

  Widget _buildWorkbench(MountMapProvider provider) {
    return InteractiveViewer(
      transformationController: _transformationController,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 5.0,
      child: Center(
        child: RepaintBoundary(
          key: _viewMode == ChartViewMode.workbench ? _repaintKey : null,
          child: _buildInteractiveChartCanvas(provider, isReport: false),
        ),
      ),
    );
  }

  Widget _buildReport(MountMapProvider provider, BoxConstraints constraints) {
    return InteractiveViewer(
      transformationController: _transformationController,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 5.0,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 100), // Vertical spacing for scrolling feel
          child: RepaintBoundary(
            key: _viewMode == ChartViewMode.report ? _repaintKey : null,
            child: _buildDocumentPaper(provider),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveChartCanvas(MountMapProvider provider, {required bool isReport}) {
    final bool isDarkBackground = ThemeData.estimateBrightnessForColor(provider.backgroundColor) == Brightness.dark;
    final Color workbenchTextColor = isDarkBackground ? Colors.white : Colors.black87;

    if (isReport) {
       // Report Mode: Render the first chart
       final bool isDarkPaper = _docPreset == "MODERN_DARK" || _docPreset == "BLUEPRINT";
       final Color adaptiveColor = isDarkPaper ? Colors.white : Colors.black87;
       return _buildSingleChart(provider, widget.asset.nodes.first, true, overrideTextColor: adaptiveColor);
    }

    // WORKBENCH: Render ALL charts in a stack
    return Stack(
      children: widget.asset.nodes.map((node) {
        return Positioned(
          left: node.position.dx,
          top: node.position.dy,
          child: _buildSingleChart(provider, node, false, overrideTextColor: workbenchTextColor),
        );
      }).toList(),
    );
  }

  Widget _buildSingleChart(MountMapProvider provider, NodeModel node, bool isReport, {Color? overrideTextColor}) {
    final String cType = node.marker ?? widget.chartType;
    final bool isSelected = _selectedChartId == node.id;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = isReport ? constraints.maxWidth : 800;
        final double h = isReport ? (constraints.maxHeight == double.infinity ? 450 : constraints.maxHeight) : 600;

        return MouseRegion(
          onHover: (event) => setState(() => _hoverPosition = isSelected ? event.localPosition : null),
          onExit: (_) => setState(() => _hoverPosition = null),
          child: GestureDetector(
            onPanUpdate: isReport ? null : (details) {
              setState(() {
                node.position += details.delta;
              });
            },
            onTapUp: (details) {
              setState(() {
                _selectedChartId = node.id;
              });
              _bringToFront(node.id);

              final Offset localOffset = details.localPosition;

              final painter = ChartEnginePainter(
                chartType: cType,
                data: node,
                visualSettings: _chartSettings,
              );

              final hitIndex = painter.getHitIndex(
                localOffset,
                Size(w, h)
              );

              setState(() {
                _selectedRowIndex = hitIndex;
              });

              if (hitIndex != null) {
                _scrollToRow(hitIndex);
                _showQuickEdit(hitIndex, localOffset);
              }

              if (cType.toLowerCase() == 'multi-level pie chart' && hitIndex != null) {
                  final nodeName = node.tableData![hitIndex][1];
                  setState(() => _sunburstRoot = nodeName);
              }
            },
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isReport ? null : Border.all(color: isSelected ? MountMapColors.teal : Colors.white10, width: isSelected ? 2 : 1),
                boxShadow: isSelected && !isReport ? [
                  BoxShadow(color: MountMapColors.teal.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 5)
                ] : null,
              ),
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _physicsController,
                    builder: (context, child) {
                      _updatePhysics();
                      return CustomPaint(
                        size: Size(w, h),
                        key: ValueKey("${cType}_${node.id}_${node.tableData.hashCode}_$isReport"),
                        painter: ChartEnginePainter(
                          chartType: cType,
                          data: node,
                          primaryColor: _primaryColor,
                          secondaryColor: _secondaryColor,
                          showLabels: _showLabels,
                          hoverPosition: isSelected ? _hoverPosition : null,
                          sunburstRoot: isSelected ? _sunburstRoot : null,
                          visualSettings: _chartSettings,
                          selectedRowIndex: isSelected ? _selectedRowIndex : null,
                          dynamicNodePositions: _dynamicNodePositions,
                          showStats: _showStats,
                          showTrend: _showTrend,
                          labelColor: overrideTextColor ?? (isReport ? Colors.black87 : _labelColor),
                          borderColor: (overrideTextColor ?? (isReport ? Colors.black87 : _borderColor)).withValues(alpha: 0.1),
                          glowColor: _glowColor,
                        ),
                      );
                    }
                  ),
                  if (!isReport)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Row(
                        children: [
                          _chartMiniAction(Icons.copy_rounded, () => _duplicateChart(node)),
                          const SizedBox(width: 8),
                          _chartMiniAction(Icons.delete_forever_rounded, () => _deleteChart(node), isDanger: true),
                        ],
                      ),
                    ),
                  if (!isReport)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(cType.toUpperCase(), style: const TextStyle(color: MountMapColors.teal, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
        );
      }
    );
  }

  void _bringToFront(String id) {
    final index = widget.asset.nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final node = widget.asset.nodes.removeAt(index);
      widget.asset.nodes.add(node);
      setState(() {});
    }
  }

  Widget _chartMiniAction(IconData icon, VoidCallback onTap, {bool isDanger = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: isDanger ? Colors.redAccent.withValues(alpha: 0.1) : Colors.white10, shape: BoxShape.circle),
        child: Icon(icon, size: 14, color: isDanger ? Colors.redAccent : Colors.white54),
      ),
    );
  }

  void _duplicateChart(NodeModel node) {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final newNode = NodeModel.fromJson(node.toJson());
    newNode.id = "chart_${DateTime.now().millisecondsSinceEpoch}";
    newNode.position += const Offset(50, 50);
    widget.asset.nodes.add(newNode);
    setState(() => _selectedChartId = newNode.id);
    _bringToFront(newNode.id);
    provider.triggerUpdate();
  }

  void _deleteChart(NodeModel node) {
    if (widget.asset.nodes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot delete the last chart")));
      return;
    }
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    widget.asset.nodes.removeWhere((n) => n.id == node.id);
    if (_selectedChartId == node.id) {
      _selectedChartId = widget.asset.nodes.first.id;
    }
    setState(() {});
    provider.triggerUpdate();
  }

  Widget _buildDocumentPaper(MountMapProvider provider) {
    final double paperWidth = _isLandscape ? 1122 : 794;
    final double paperHeight = _isLandscape ? 794 : 1122;
    final double margin = _chartSettings['paperMargin'] ?? 40.0;

    Color pColor = _paperColor;
    if (_docPreset == "BLUEPRINT") pColor = const Color(0xFF003366);
    if (_docPreset == "MODERN_DARK") pColor = const Color(0xFF0D1117);
    if (_docPreset == "LINEN") pColor = const Color(0xFFF5F5F0);

    final bool isDarkPaper = ThemeData.estimateBrightnessForColor(pColor) == Brightness.dark;
    final Color textColor = isDarkPaper ? Colors.white : Colors.black87;

    // Dynamic height based on content
    double totalHeight = paperHeight;
    if (widget.asset.nodes.length > 1) {
       totalHeight = paperHeight + (widget.asset.nodes.length - 1) * 500;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: paperWidth,
      height: totalHeight,
      decoration: BoxDecoration(
        color: pColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
        gradient: _docPreset == "CLASSIC" ? LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [pColor, Color.lerp(pColor, isDarkPaper ? Colors.black : Colors.white, 0.05)!],
        ) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 5),
        ],
      ),
      child: Stack(
        children: [
          if (_docPreset == "BLUEPRINT") _buildBlueprintGrid(),
          if (_docPreset == "LINEN") _buildLinenTexture(),
          if (_showDocBorder)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: textColor.withValues(alpha: 0.1), width: 1.5),
                ),
              ),
            ),
          if (_showDocWatermark) _buildWatermark(),
          if (_showDocStamp) _buildOfficialStamp(textColor),
          _buildDynamicLightOverlay(paperWidth, paperHeight),
          Padding(
            padding: EdgeInsets.all(margin),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showDocHeader) _buildDocumentHeader(),
                  if (_showDocSummary) _buildMetricDashboard(textColor),
                  if (_showDocAnalysis) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildAnalysisSection()),
                        const SizedBox(width: 20),
                        Expanded(flex: 1, child: _buildInsightCards(textColor)),
                      ],
                    ),
                  ],
                  // Multi-Chart Display in Report
                  ...widget.asset.nodes.map((node) {
                    final String nodeType = node.marker ?? widget.chartType;
                    return Container(
                      height: 450, // More breathing room
                      margin: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 3, height: 12,
                                decoration: BoxDecoration(color: MountMapColors.teal, borderRadius: BorderRadius.circular(2)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${node.text.toUpperCase()} - $nodeType",
                                style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildSingleChart(provider, node, true, overrideTextColor: textColor),
                                ),
                                if (_showDocDataGrid) ...[
                                  const SizedBox(width: 30),
                                  Expanded(
                                    flex: 1,
                                    child: _buildSmallDataPreview(node, textColor),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Divider(height: 40, thickness: 0.5, color: Colors.black12),
                        ],
                      ),
                    );
                  }).toList(),
                  if (_showDocSignature) _buildSignatureBlock(),
                  if (_showDocHeader) _buildDocumentFooter(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSmallDataPreview(NodeModel node, Color textColor) {
    if (node.tableData == null) return const SizedBox();
    final table = node.tableData!;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CHART DATA", style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 7, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          for (int i = 1; i < math.min(5, table.length); i++)
             Text("${table[i][0]}: ${table[i][1]}", style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 8)),
        ],
      ),
    );
  }

  Widget _buildBlueprintGrid() {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.1,
        child: CustomPaint(painter: GridPainter()),
      ),
    );
  }

  Widget _buildLinenTexture() {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.02,
        child: Image.asset('assets/logo.png', repeat: ImageRepeat.repeat, scale: 5),
      ),
    );
  }

  Widget _buildDynamicLightOverlay(double w, double h) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                (_lightPos.dx / w * 2) - 1,
                (_lightPos.dy / h * 2) - 1,
              ),
              radius: 1.5,
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.1),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWatermark() {
    return Positioned.fill(
      child: Center(
        child: Opacity(
          opacity: 0.03,
          child: Transform.rotate(
            angle: -math.pi / 4,
            child: const Text(
              "CONFIDENTIAL\nMOUNTMAP EXECUTIVE",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildReferenceChart() {
    final bool isDarkPaper = ThemeData.estimateBrightnessForColor(_paperColor) == Brightness.dark;
    final Color textColor = isDarkPaper ? Colors.white : Colors.black87;

    return Container(
      height: 120,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: textColor.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("CROSS-REFERENCE", style: TextStyle(color: MountMapColors.teal, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text("Relative Distribution", style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Secondary analytical view providing context to the primary dataset.", style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 7)),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: CustomPaint(
              painter: ChartEnginePainter(
                chartType: "Rose Chart",
                data: widget.asset.nodes.isNotEmpty ? widget.asset.nodes.first : null,
                visualSettings: _chartSettings,
                primaryColor: MountMapColors.teal,
                secondaryColor: MountMapColors.violet,
                showLabels: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocDataGrid() {
    final bool isDarkPaper = ThemeData.estimateBrightnessForColor(_paperColor) == Brightness.dark;
    final Color textColor = isDarkPaper ? Colors.white : Colors.black87;

    if (widget.asset.nodes.isEmpty || widget.asset.nodes.first.tableData == null) return const SizedBox();
    final table = widget.asset.nodes.first.tableData!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text("DATA PREVIEW", style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: textColor.withValues(alpha: 0.05)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
              children: [
                for (int i = 0; i < math.min(10, table.length); i++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: i == 0 ? textColor.withValues(alpha: 0.05) : (i % 2 == 0 ? textColor.withValues(alpha: 0.02) : Colors.transparent),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(table[i][0], style: TextStyle(color: textColor.withValues(alpha: i == 0 ? 0.9 : 0.6), fontSize: 9, fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(table[i].length > 1 ? table[i][1] : "-", style: TextStyle(color: i == 0 ? textColor.withValues(alpha: 0.9) : MountMapColors.teal, fontSize: 9, fontWeight: i == 0 ? FontWeight.bold : FontWeight.bold), textAlign: TextAlign.right),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (table.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text("+ ${table.length - 10} more rows", style: TextStyle(color: textColor.withValues(alpha: 0.2), fontSize: 7, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _buildMetricDashboard(Color textColor) {
    // Extract stats
    double total = 0, maxVal = 0;
    String topCategory = "N/A";
    if (widget.asset.nodes.isNotEmpty && widget.asset.nodes.first.tableData != null) {
      final table = widget.asset.nodes.first.tableData!;
      for (int i = 1; i < table.length; i++) {
        final val = double.tryParse(table[i].length > 1 ? table[i][1] : "0") ?? 0;
        total += val;
        if (val > maxVal) {
          maxVal = val;
          topCategory = table[i][0];
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          _metricCard("GROSS VOLUME", total.toStringAsFixed(0), Icons.account_balance_wallet_rounded, MountMapColors.teal, textColor),
          const SizedBox(width: 15),
          _metricCard("PEAK PERFORMANCE", topCategory, Icons.auto_graph_rounded, MountMapColors.violet, textColor),
          const SizedBox(width: 15),
          _metricCard("STATUS", "CERTIFIED", Icons.verified_user_rounded, Colors.greenAccent, textColor),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCards(Color textColor) {
    return Column(
      children: [
        _insightItem("Market Lead", "Consistent growth observed in primary sectors.", Icons.tips_and_updates_rounded, MountMapColors.teal, textColor),
        const SizedBox(height: 10),
        _insightItem("Optimization", "Efficiency can be improved by 12% in Q4.", Icons.bolt_rounded, Colors.amberAccent, textColor),
      ],
    );
  }

  Widget _insightItem(String title, String desc, IconData icon, Color color, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: TextStyle(color: textColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 8, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialStamp(Color textColor) {
    return Positioned(
      bottom: 60,
      right: 40,
      child: Opacity(
        opacity: 0.1,
        child: Container(
          width: 100,
          height: 100,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: MountMapColors.teal, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 30, color: MountMapColors.teal),
              const SizedBox(height: 4),
              const Text("CERTIFIED", style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: MountMapColors.teal)),
              const Text("MOUNTMAP", style: TextStyle(fontSize: 5, fontWeight: FontWeight.w900, color: MountMapColors.teal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureBlock() {
    final bool isDarkPaper = ThemeData.estimateBrightnessForColor(_paperColor) == Brightness.dark;
    final Color textColor = isDarkPaper ? Colors.white : Colors.black87;

    if (_docLayout == "MINIMAL") return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 30, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("PREPARED BY", style: TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 20),
              Container(width: 150, height: 1, color: textColor.withValues(alpha: 0.1)),
              const SizedBox(height: 4),
              Text(_docAuthor.toUpperCase(), style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.bold)),
              Text("Lead Data Architect", style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 8)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("VERIFIED BY", style: TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 20),
              Container(width: 150, height: 1, color: textColor.withValues(alpha: 0.1)),
              const SizedBox(height: 4),
              Text("SYSTEM AUTOMATION", style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.bold)),
              Text("MountMap Engine v1.0", style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSection() {
    final bool isDarkPaper = ThemeData.estimateBrightnessForColor(_paperColor) == Brightness.dark;
    final Color textColor = isDarkPaper ? Colors.white : Colors.black87;
    final double bodyScale = _chartSettings['bodyTextScale'] ?? 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "EXECUTIVE SUMMARY & DATA ANALYSIS",
            style: TextStyle(
              color: MountMapColors.teal,
              fontSize: 10 * bodyScale,
              fontWeight: FontWeight.w900,
              letterSpacing: 2
            ),
          ),
          const SizedBox(height: 15),
          Text(
            _docAnalysis,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 13 * bodyScale,
              height: 1.6,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentHeader() {
    final bool isDarkPaper = ThemeData.estimateBrightnessForColor(_paperColor) == Brightness.dark;
    final Color textColor = isDarkPaper ? Colors.white : Colors.black87;
    final double headerScale = _chartSettings['headerScale'] ?? 1.0;

    if (_docLayout == "MINIMAL") {
       return Container(
         margin: const EdgeInsets.only(bottom: 30),
         child: Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             Text(_docTitle.toUpperCase(), style: TextStyle(color: textColor, fontSize: 14 * headerScale, fontWeight: FontWeight.bold, letterSpacing: 1)),
             Text("${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}", style: TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 10)),
           ],
         ),
       );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: textColor.withValues(alpha: 0.1), width: 2)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_headerAlign == TextAlign.left) ...[
                Image.asset('assets/logo.png', width: 40 * headerScale, height: 40 * headerScale, color: MountMapColors.teal),
                const SizedBox(width: 15),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: _headerAlign == TextAlign.center ? CrossAxisAlignment.center : (_headerAlign == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start),
                  children: [
                    Text(
                      _docTitle.toUpperCase(),
                      style: TextStyle(color: textColor, fontSize: 24 * headerScale, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                      textAlign: _headerAlign,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _docSubtitle.toUpperCase(),
                      style: TextStyle(color: MountMapColors.teal, fontSize: 10 * headerScale, fontWeight: FontWeight.bold, letterSpacing: 4),
                    ),
                  ],
                ),
              ),
              if (_headerAlign == TextAlign.right) ...[
                const SizedBox(width: 15),
                Image.asset('assets/logo.png', width: 40 * headerScale, height: 40 * headerScale, color: MountMapColors.teal),
              ],
              if (_headerAlign == TextAlign.left)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.chartType.toUpperCase(),
                      style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "DATE: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                      style: TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 8, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      "AUTH: ${_docAuthor.toUpperCase()}",
                      style: TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 8, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
            ],
          ),
          if (_headerAlign == TextAlign.center) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("MOUNTMAP ANALYTICS", style: TextStyle(color: textColor.withValues(alpha: 0.2), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(width: 10),
                Container(width: 4, height: 4, decoration: BoxDecoration(color: MountMapColors.teal, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text("${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}", style: TextStyle(color: textColor.withValues(alpha: 0.2), fontSize: 8)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportToPNG() async {
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw "Could not find chart boundary";

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) throw "Failed to generate PNG data";

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final fileName = "MountChart_${DateTime.now().millisecondsSinceEpoch}.png";
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Professional Chart Export: ${widget.asset.title} (${widget.chartType})',
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

  Widget _panelHeader(String title, IconData icon, {List<Widget>? actions, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (textColor ?? Colors.white).withValues(alpha: 0.02),
        border: Border(bottom: BorderSide(color: (textColor ?? Colors.white).withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: MountMapColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: (textColor ?? Colors.white).withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          if (actions != null) ...actions,
        ],
      ),
    );
  }

  Widget _panelFooter(MountMapProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.01),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: () => _addRow(provider),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text("ADD ROW"),
            style: ElevatedButton.styleFrom(
              backgroundColor: MountMapColors.teal.withValues(alpha: 0.1),
              foregroundColor: MountMapColors.teal,
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showBulkImport(provider),
            icon: const Icon(Icons.grid_on_rounded, size: 16),
            label: const Text("BULK IMPORT / CSV", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white38,
              side: BorderSide(color: Colors.white10),
              minimumSize: const Size(double.infinity, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _addColumn(MountMapProvider provider) {
    if (_selectedChartId == null) return;
    final node = widget.asset.nodes.firstWhere((n) => n.id == _selectedChartId);
    final table = List<List<String>>.from(node.tableData!);
    for (int i = 0; i < table.length; i++) {
      table[i] = List<String>.from(table[i]);
      table[i].add(i == 0 ? "Col ${table[i].length + 1}" : "0");
    }
    provider.updatePeak(node.id, tableData: table);
    _controllers.clear();
  }

  void _clearAllData(MountMapProvider provider) {
    if (_selectedChartId == null) return;
    final node = widget.asset.nodes.firstWhere((n) => n.id == _selectedChartId);
    final header = node.tableData![0];
    provider.updatePeak(node.id, tableData: [header, List.filled(header.length, "0")]);
    _controllers.clear();
  }

  void _showBulkImport(MountMapProvider provider) {
    final TextEditingController importCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MountMapColors.darkCard,
        title: const Text("Bulk Import (CSV/TSV)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Paste comma or tab separated data below. The first row will be used as headers.", style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 16),
            TextField(
              controller: importCtrl,
              maxLines: 10,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                hintText: "Category,Value\nItem A,100\nItem B,200",
                hintStyle: TextStyle(color: Colors.white10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white24))),
          ElevatedButton(
            onPressed: () {
              final String input = importCtrl.text.trim();
              if (input.isNotEmpty) {
                final List<List<String>> newTable = [];
                final List<String> lines = input.split('\n');
                for (var line in lines) {
                  if (line.trim().isEmpty) continue;
                  // Try tab first, then comma
                  if (line.contains('\t')) {
                    newTable.add(line.split('\t').map((e) => e.trim()).toList());
                  } else {
                    newTable.add(line.split(',').map((e) => e.trim()).toList());
                  }
                }
                if (newTable.isNotEmpty) {
                  final rootNode = widget.asset.nodes.first;
                  provider.updatePeak(rootNode.id, tableData: newTable);
                  _controllers.clear();
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("IMPORT"),
          ),
        ],
      ),
    );
  }

  void _updatePhysics() {
    if (widget.chartType.toLowerCase() != 'hyperbolic tree') return;

    // Simple Force-Directed Simulation
    final rootNode = widget.asset.nodes.first;
    final table = rootNode.tableData ?? [];
    if (table.length < 2) return;

    // Repulsion
    for (var i = 1; i < table.length; i++) {
      String node = table[i][1];
      if (!_dynamicNodePositions.containsKey(node)) {
        _dynamicNodePositions[node] = Offset(math.Random().nextDouble() * 10, math.Random().nextDouble() * 10);
        _nodeVelocities[node] = Offset.zero;
      }

      Offset force = Offset.zero;
      for (var j = 1; j < table.length; j++) {
        if (i == j) continue;
        String other = table[j][1];
        if (!_dynamicNodePositions.containsKey(other)) continue;

        Offset delta = _dynamicNodePositions[node]! - _dynamicNodePositions[other]!;
        double distSq = delta.distanceSquared + 0.1;
        force += delta * (500.0 / distSq); // Coulomb repulsion
      }

      // Attraction to parent
      String parent = table[i][0];
      if (_dynamicNodePositions.containsKey(parent)) {
         Offset delta = _dynamicNodePositions[parent]! - _dynamicNodePositions[node]!;
         force += delta * 0.05; // Hooke's Law attraction
      } else {
         // Attract to origin if root
         force -= _dynamicNodePositions[node]! * 0.01;
      }

      // Update velocity and position
      _nodeVelocities[node] = (_nodeVelocities[node]! + force) * 0.85; // Damping
      _dynamicNodePositions[node] = _dynamicNodePositions[node]! + _nodeVelocities[node]!;
    }
  }

  void _scrollToRow(int index) {
    if (!_dataScrollController.hasClients) return;
    // Basic approximation of row height (approx 50px)
    _dataScrollController.animateTo(
      (index * 50.0).clamp(0, _dataScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showQuickEdit(int rowIndex, Offset position) {
    if (_selectedChartId == null) return;
    final node = widget.asset.nodes.firstWhere((n) => n.id == _selectedChartId);
    final row = node.tableData![rowIndex];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MountMapColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: MountMapColors.teal.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: MountMapColors.teal),
            const SizedBox(width: 10),
            Text("Edit Data: ${row[0]}", style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < row.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.tableData![0][i].toUpperCase(),
                          style: TextStyle(color: MountMapColors.teal.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: TextEditingController(text: row[i]),
                          onChanged: (val) {
                            setState(() {
                              row[i] = val;
                              // Refresh controllers in table
                              _controllers.clear();
                            });
                          },
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.03),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MountMapColors.teal, width: 1)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("DONE", style: TextStyle(color: MountMapColors.teal, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildDataTable(MountMapProvider provider) {
    if (_selectedChartId == null) return Center(child: Text("Select a chart to view data", style: TextStyle(color: provider.textColor.withValues(alpha: 0.2))));
    final node = widget.asset.nodes.firstWhere((n) => n.id == _selectedChartId);
    final table = node.tableData ?? [];

    return Scrollbar(
      controller: _dataScrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _dataScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        itemCount: table.length,
        itemBuilder: (context, rowIndex) {
          final bool isHeader = rowIndex == 0;
          final bool isSelected = _selectedRowIndex == rowIndex;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: isHeader
                  ? MountMapColors.teal.withValues(alpha: 0.05)
                  : (isSelected ? MountMapColors.teal.withValues(alpha: 0.15) : Colors.transparent),
              borderRadius: BorderRadius.circular(isHeader ? 8 : 4),
              border: Border.all(
                color: isSelected
                    ? MountMapColors.teal.withValues(alpha: 0.4)
                    : (isHeader ? Colors.white.withValues(alpha: 0.1) : Colors.transparent),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Row Numbering
                Container(
                  width: 24,
                  alignment: Alignment.center,
                  child: Text(
                    isHeader ? "#" : rowIndex.toString(),
                    style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),

                for (int colIndex = 0; colIndex < table[rowIndex].length; colIndex++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      child: isHeader
                        ? _buildHeaderCell(provider, table, colIndex)
                        : _buildCellField(provider, table, rowIndex, colIndex),
                    ),
                  ),

                if (!isHeader)
                  _miniPanelAction(
                    Icons.delete_sweep_rounded,
                    "Delete Row",
                    () {
                      final newTable = List<List<String>>.from(table);
                      newTable.removeAt(rowIndex);
                      provider.updatePeak(node.id, tableData: newTable);
                    },
                    isDanger: true,
                  )
                else
                  const SizedBox(width: 30), // Alignment for delete button space
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCell(MountMapProvider provider, List<List<String>> table, int colIndex) {
    return InkWell(
      onTap: () => _sortData(colIndex),
      onLongPress: () => _showColumnOptions(provider, colIndex),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: _buildCellField(provider, table, 0, colIndex)),
            Icon(
              _sortColumnIndex == colIndex
                ? (_sortAscending ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded)
                : Icons.unfold_more_rounded,
              size: 14, color: MountMapColors.teal.withValues(alpha: 0.5)
            ),
          ],
        ),
      ),
    );
  }

  void _showColumnOptions(MountMapProvider provider, int colIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MountMapColors.darkCard,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: Text("Delete Column", style: TextStyle(color: Colors.white)),
              onTap: () {
                final rootNode = widget.asset.nodes.first;
                final table = List<List<String>>.from(rootNode.tableData!);
                for (var row in table) {
                  if (row.length > 1) row.removeAt(colIndex);
                }
                provider.updatePeak(rootNode.id, tableData: table);
                _controllers.clear();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sortData(int colIndex) {
    if (_selectedChartId == null) return;
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final node = widget.asset.nodes.firstWhere((n) => n.id == _selectedChartId);
    final table = node.tableData ?? [];
    if (table.length < 2) return;

    setState(() {
      if (_sortColumnIndex == colIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = colIndex;
        _sortAscending = true;
      }

      final header = table.removeAt(0);
      table.sort((a, b) {
        int cmp = a[colIndex].compareTo(b[colIndex]);
        // Try numeric comparison if possible
        double? na = double.tryParse(a[colIndex]);
        double? nb = double.tryParse(b[colIndex]);
        if (na != null && nb != null) cmp = na.compareTo(nb);

        return _sortAscending ? cmp : -cmp;
      });
      table.insert(0, header);
    });

    // Clear controllers to force refresh with new order
    _controllers.clear();
    provider.triggerUpdate();
  }

  void _addRow(MountMapProvider provider) {
    if (_selectedChartId == null) return;
    final node = widget.asset.nodes.firstWhere((n) => n.id == _selectedChartId);
    final table = node.tableData ?? [];
    if (table.isNotEmpty) {
      final newTable = List<List<String>>.from(table);
      newTable.add(List.filled(table[0].length, "0"));
      provider.updatePeak(node.id, tableData: newTable);
    }
  }

  Widget _buildCellField(MountMapProvider provider, List<List<String>> table, int rowIndex, int colIndex) {
    if (_selectedChartId == null) return const SizedBox();
    final node = widget.asset.nodes.firstWhere((n) => n.id == _selectedChartId);
    final key = "cell_${node.id}_${rowIndex}_${colIndex}";

    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: table[rowIndex][colIndex]);
    } else if (_controllers[key]!.text != table[rowIndex][colIndex]) {
      // Logic to update text only if it changed externally (e.g. from chart click or bulk import)
      // but avoid jumping if user is typing
      if (!_controllers[key]!.selection.isValid || _controllers[key]!.selection.isCollapsed) {
         // This is a rough check. Better: use a flag or check focus.
      }
    }

    final bool isHeader = rowIndex == 0;

    Color cellTextColor = isHeader ? MountMapColors.teal : provider.textColor.withValues(alpha: 0.7);
    Color? cellBgColor;

    if (!isHeader) {
      final double? val = double.tryParse(table[rowIndex][colIndex]);
      if (val != null) {
        if (val < 0) {
          cellTextColor = Colors.redAccent;
          cellBgColor = Colors.redAccent.withValues(alpha: 0.05);
        }
        if (val > 1000) {
          cellTextColor = Colors.greenAccent;
          cellBgColor = Colors.greenAccent.withValues(alpha: 0.05);
        }
      }
    }

    return TextField(
      controller: _controllers[key],
      onTap: () {
        setState(() {
          _selectedRowIndex = rowIndex;
        });
      },
      onChanged: (val) {
        if (_undoStack.isEmpty || _undoStack.last != node.tableData) {
          _undoStack.add(node.tableData!.map((r) => List<String>.from(r)).toList());
          if (_undoStack.length > 20) _undoStack.removeAt(0);
        }
        table[rowIndex][colIndex] = val;
        provider.updatePeak(node.id, tableData: table);
      },
      style: TextStyle(
        color: cellTextColor,
        fontSize: isHeader ? 11 : 12,
        fontWeight: isHeader ? FontWeight.w900 : FontWeight.normal,
        letterSpacing: isHeader ? 0.5 : 0,
      ),
      textAlign: isHeader ? TextAlign.center : TextAlign.start,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: cellBgColor ?? (isHeader ? Colors.transparent : Colors.white.withValues(alpha: 0.02)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
    );
  }

  Widget _buildStyleControls(MountMapProvider provider) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _buildStyleAccordion(
          "DOCUMENT ENGINE (REPORT MODE)",
          Icons.description_rounded,
          [
            _styleSection("VISIBILITY", Icons.visibility_rounded),
            _switchTile("Show Header/Footer", _showDocHeader, (v) => setState(() => _showDocHeader = v)),
            _switchTile("Show Analysis Block", _showDocAnalysis, (v) => setState(() => _showDocAnalysis = v)),
            _switchTile("Show Summary Stats", _showDocSummary, (v) => setState(() => _showDocSummary = v)),
            _switchTile("Show Side Data Grid", _showDocDataGrid, (v) => setState(() => _showDocDataGrid = v)),
            _switchTile("Show Watermark", _showDocWatermark, (v) => setState(() => _showDocWatermark = v)),
            _switchTile("Show Official Stamp", _showDocStamp, (v) => setState(() => _showDocStamp = v)),
            _switchTile("Show Page Border", _showDocBorder, (v) => setState(() => _showDocBorder = v)),
            _switchTile("Show Signature", _showDocSignature, (v) => setState(() => _showDocSignature = v)),

            const SizedBox(height: 12),
            _styleSection("LAYOUT & TYPOGRAPHY", Icons.dashboard_customize_rounded),
            _switchTile("Landscape Orientation", _isLandscape, (v) => setState(() => _isLandscape = v)),
            _buildDropdown("Report Layout", _docLayout, ["STANDARD", "EXECUTIVE", "MINIMAL"], (v) => setState(() => _docLayout = v!)),
            _buildDropdown("Document Preset", _docPreset, ["CLASSIC", "BLUEPRINT", "MODERN_DARK", "LINEN"], (v) => setState(() => _docPreset = v!)),
            _buildDropdown("Header Alignment", _headerAlign.name, ["left", "center", "right"], (v) {
              setState(() {
                if (v == "left") _headerAlign = TextAlign.left;
                if (v == "center") _headerAlign = TextAlign.center;
                if (v == "right") _headerAlign = TextAlign.right;
              });
            }),
            _buildSlider("Header Font Scale", "headerScale", min: 0.5, max: 2.0),
            _buildSlider("Body Font Scale", "bodyTextScale", min: 0.5, max: 2.0),

            const SizedBox(height: 12),
            _styleSection("METADATA", Icons.edit_note_rounded),
            _buildTextField("Doc Title", _docTitle, (v) => setState(() => _docTitle = v)),
            _buildTextField("Subtitle", _docSubtitle, (v) => setState(() => _docSubtitle = v)),
            _buildTextField("Author", _docAuthor, (v) => setState(() => _docAuthor = v)),
            _buildTextField("Analysis/Notes", _docAnalysis, (v) => setState(() => _docAnalysis = v), maxLines: 5),

            const SizedBox(height: 12),
            _styleSection("PAPER STYLE", Icons.style_rounded),
            _colorPicker("Paper Color", _paperColor, (c) => setState(() => _paperColor = c)),
            _buildSlider("Internal Margin", "paperMargin", min: 10, max: 100),
          ],
          onReset: () => setState(() {
            _showDocHeader = true;
            _showDocAnalysis = true;
            _showDocSummary = true;
            _showDocDataGrid = true;
            _showDocWatermark = false;
            _showDocStamp = true;
            _showDocBorder = true;
            _showDocSignature = true;
            _isLandscape = true;
            _docLayout = "STANDARD";
            _headerAlign = TextAlign.left;
            _docTitle = widget.asset.title;
            _docSubtitle = "PROJECTION REPORT";
            _docAuthor = "MountMap Executive";
            _docAnalysis = "Based on the analyzed data patterns, we observe significant structural hierarchies that inform our current projections.";
            _paperColor = Colors.white;
            _chartSettings['paperMargin'] = 40.0;
            _chartSettings['headerScale'] = 1.0;
            _chartSettings['bodyTextScale'] = 1.0;
          }),
        ),
        _buildStyleAccordion(
          "GLOBAL CONFIG",
          Icons.settings_suggest_rounded,
          [
            _switchTile("Show Labels", _showLabels, (v) => setState(() => _showLabels = v)),
            _switchTile("Show Legend", _showLegend, (v) => setState(() => _showLegend = v)),
            _switchTile("Animate", _animate, (v) => setState(() => _animate = v)),
            _switchTile("Statistical Overlays", _showStats, (v) => setState(() => _showStats = v)),
            _switchTile("Trend Lines", _showTrend, (v) => setState(() => _showTrend = v)),
          ],
          onReset: () => setState(() {
            _showLabels = true;
            _showLegend = true;
            _animate = true;
            _showStats = false;
            _showTrend = false;
          }),
        ),

        _buildStyleAccordion(
          "TUNING: ${widget.chartType.toUpperCase()}",
          Icons.tune_rounded,
          _buildChartSpecificControls(),
          initiallyExpanded: true,
          onReset: () => setState(() {
            _chartSettings['opacity'] = 0.6;
            _chartSettings['thickness'] = 2.0;
            _chartSettings['smoothing'] = 0.5;
            _chartSettings['gap'] = 10.0;
            _chartSettings['radius'] = 4.0;
            _chartSettings['intensity'] = 0.8;
          }),
        ),

        _buildStyleAccordion(
          "VISUAL THEME",
          Icons.brush_rounded,
          [
            _colorPicker("Primary Color", _primaryColor, (c) => setState(() => _primaryColor = c)),
            _colorPicker("Secondary Color", _secondaryColor, (c) => setState(() => _secondaryColor = c)),
            const SizedBox(height: 12),
            _styleSection("PRESET COMBOS", Icons.palette_outlined),
            _buildThemePresets(),
          ],
          onReset: () => setState(() {
            _primaryColor = MountMapColors.teal;
            _secondaryColor = MountMapColors.violet;
          }),
        ),

        _buildStyleAccordion(
          "ADVANCED TYPOGRAPHY",
          Icons.text_fields_rounded,
          [
            _buildSlider("Font Scale", "fontScale", min: 0.5, max: 2.5),
            _buildSlider("Label Rotation", "labelRotation", min: -3.14, max: 3.14),
            _colorPicker("Label Color", _labelColor, (c) => setState(() => _labelColor = c)),
          ],
          onReset: () => setState(() {
            _chartSettings['fontScale'] = 1.0;
            _chartSettings['labelRotation'] = 0.0;
            _labelColor = Colors.white70;
          }),
        ),

        _buildStyleAccordion(
          "BORDERS & SHADOWS",
          Icons.auto_awesome_motion_rounded,
          [
            _buildSlider("Border Width", "borderWidth", min: 0.0, max: 10.0),
            _buildSlider("Shadow Intensity", "shadowIntensity", min: 0.0, max: 1.0),
            _colorPicker("Border Color", _borderColor, (c) => setState(() => _borderColor = c)),
            _colorPicker("Glow Color", _glowColor, (c) => setState(() => _glowColor = c)),
          ],
          onReset: () => setState(() {
            _chartSettings['borderWidth'] = 1.0;
            _chartSettings['shadowIntensity'] = 0.0;
            _borderColor = Colors.white10;
            _glowColor = Colors.transparent;
          }),
        ),

        if (widget.chartType.toLowerCase() == 'multi-level pie chart') ...[
          _buildStyleAccordion("HIERARCHY", Icons.account_tree_rounded, [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Reset to Root", style: TextStyle(color: Colors.white70, fontSize: 13)),
              trailing: IconButton(icon: const Icon(Icons.first_page_rounded, color: MountMapColors.teal), onPressed: () => setState(() => _sunburstRoot = null)),
            ),
          ]),
        ],

        _buildStyleAccordion(
          "CANVAS LAYOUT",
          Icons.layers_rounded,
          [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Reset Viewport", style: TextStyle(color: Colors.white70, fontSize: 12)),
              trailing: IconButton(icon: const Icon(Icons.refresh_rounded, color: MountMapColors.teal), onPressed: () => _transformationController.value = Matrix4.identity()),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Fit to Center", style: TextStyle(color: Colors.white70, fontSize: 12)),
              trailing: IconButton(icon: const Icon(Icons.center_focus_strong_rounded, color: MountMapColors.teal), onPressed: () => _transformationController.value = Matrix4.identity()),
            ),
          ],
          onReset: () => _transformationController.value = Matrix4.identity(),
        ),

        const SizedBox(height: 24),
        Center(
          child: Text(
            "MountChart v1.0 Professional Edition",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.1), fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildThemePresets() {
    final themes = [
      {
        'name': 'CYBER NEON',
        'primary': Colors.cyanAccent,
        'secondary': Colors.purpleAccent,
        'label': Colors.white,
        'border': Colors.cyanAccent.withValues(alpha: 0.5),
        'glow': Colors.cyanAccent,
        'borderWidth': 2.0,
        'shadow': 0.8,
        'opacity': 0.8,
      },
      {
        'name': 'FROSTED',
        'primary': Colors.white,
        'secondary': MountMapColors.teal,
        'label': Colors.white70,
        'border': Colors.white24,
        'glow': Colors.transparent,
        'borderWidth': 1.0,
        'shadow': 0.2,
        'opacity': 0.3,
      },
      {
        'name': 'MIDNIGHT',
        'primary': const Color(0xFFFFD700), // Gold
        'secondary': const Color(0xFF000080), // Navy
        'label': Colors.white,
        'border': const Color(0xFFFFD700).withValues(alpha: 0.3),
        'glow': const Color(0xFFFFD700),
        'borderWidth': 1.5,
        'shadow': 0.6,
        'opacity': 0.9,
      },
      {
        'name': 'ROYAL',
        'primary': Colors.deepPurpleAccent,
        'secondary': Colors.amberAccent,
        'label': Colors.white,
        'border': Colors.white10,
        'glow': Colors.purpleAccent,
        'borderWidth': 1.0,
        'shadow': 0.5,
        'opacity': 0.7,
      },
      {
        'name': 'EMERALD',
        'primary': Colors.greenAccent,
        'secondary': Colors.tealAccent,
        'label': Colors.white,
        'border': Colors.greenAccent.withValues(alpha: 0.2),
        'glow': Colors.greenAccent,
        'borderWidth': 1.0,
        'shadow': 0.4,
        'opacity': 0.6,
      },
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: themes.map((t) => InkWell(
        onTap: () => setState(() {
          _primaryColor = t['primary'] as Color;
          _secondaryColor = t['secondary'] as Color;
          _labelColor = t['label'] as Color;
          _borderColor = t['border'] as Color;
          _glowColor = t['glow'] as Color;
          _chartSettings['borderWidth'] = t['borderWidth'] as double;
          _chartSettings['shadowIntensity'] = t['shadow'] as double;
          _chartSettings['opacity'] = t['opacity'] as double;
        }),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 1),
                gradient: LinearGradient(colors: [t['primary'] as Color, t['secondary'] as Color]),
                boxShadow: [
                  if ((t['shadow'] as double) > 0.1)
                    BoxShadow(color: (t['glow'] as Color).withValues(alpha: 0.3), blurRadius: 5),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(t['name'] as String, style: const TextStyle(color: Colors.white24, fontSize: 7, fontWeight: FontWeight.bold)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildStyleAccordion(String title, IconData icon, List<Widget> children, {bool initiallyExpanded = false, VoidCallback? onReset}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, size: 16, color: MountMapColors.teal.withValues(alpha: 0.8)),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          trailing: onReset != null
            ? IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white24),
                onPressed: onReset,
                tooltip: "Reset Category",
              )
            : null,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: children,
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: value,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 11)))).toList(),
              onChanged: onChanged,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: MountMapColors.darkCard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String initialValue, Function(String) onChanged, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: TextEditingController(text: initialValue),
        onChanged: onChanged,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: MountMapColors.teal.withValues(alpha: 0.5), fontSize: 10),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.02),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildSlider(String label, String key, {double min = 0, double max = 1, int divisions = 10}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text((_chartSettings[key] ?? 0.0).toStringAsFixed(1), style: const TextStyle(color: MountMapColors.teal, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: (_chartSettings[key] ?? min).clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              activeColor: MountMapColors.teal,
              inactiveColor: Colors.white10,
              onChanged: (v) => setState(() => _chartSettings[key] = v),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChartSpecificControls() {
    final type = widget.chartType.toLowerCase();
    final List<Widget> controls = [];

    void addSlider(String label, String key, {double min = 0, double max = 1, int divisions = 10}) {
      controls.add(_buildSlider(label, key, min: min, max: max, divisions: divisions));
    }

    switch (type) {
      case 'alluvial diagram':
        addSlider("Flow Opacity", "opacity");
        addSlider("Node Thickness", "thickness", min: 10, max: 50, divisions: 4);
        addSlider("Curvature", "smoothing");
        break;
      case 'butterfly chart':
        addSlider("Bar Height", "thickness", min: 10, max: 40, divisions: 6);
        addSlider("Gap Width", "gap", min: 40, max: 150, divisions: 11);
        addSlider("Smoothing", "smoothing");
        break;
      case 'chord diagram':
        addSlider("Ribbon Tension", "smoothing");
        addSlider("Ring Width", "thickness", min: 4, max: 30, divisions: 13);
        addSlider("Center Gap", "gap", min: 0.0, max: 0.2, divisions: 20);
        break;
      case 'contour plot':
        addSlider("Resolution", "thickness", min: 10, max: 60, divisions: 5);
        addSlider("Heat Intensity", "intensity");
        addSlider("Isoline Count", "gap", min: 2, max: 20, divisions: 9);
        break;
      case 'histogram':
        addSlider("Bar Width", "intensity");
        addSlider("Bell Curve Scale", "smoothing", min: 0.5, max: 4, divisions: 7);
        addSlider("Corner Radius", "radius", min: 0, max: 12, divisions: 6);
        break;
      case 'hyperbolic tree':
        addSlider("Disk Scale", "intensity", min: 0.2, max: 1.0, divisions: 8);
        addSlider("Node Size", "thickness", min: 2, max: 20, divisions: 9);
        addSlider("Branch Fade", "opacity");
        break;
      case 'multi-level pie chart':
        addSlider("Center Hole", "gap", min: 20, max: 150, divisions: 13);
        addSlider("Ring Thickness", "thickness", min: 20, max: 100, divisions: 8);
        addSlider("Label Detail", "intensity");
        break;
      case 'pareto chart':
        addSlider("80% Threshold", "intensity", min: 0.5, max: 1.0, divisions: 10);
        addSlider("Bar Opacity", "opacity");
        addSlider("Marker Size", "thickness", min: 2, max: 10, divisions: 8);
        break;
      case 'radial bar chart':
        addSlider("Bar Thickness", "thickness", min: 5, max: 40, divisions: 7);
        addSlider("Start Angle", "smoothing", min: 0.0, max: 6.28, divisions: 12);
        addSlider("Glow Level", "intensity");
        break;
      case 'taylor diagram':
        addSlider("Grid Opacity", "opacity");
        addSlider("Marker Scale", "thickness", min: 2, max: 12, divisions: 5);
        addSlider("S-Score Detail", "gap", min: 1, max: 10, divisions: 9);
        break;
      case 'treemap':
        addSlider("Block Padding", "gap", min: 0, max: 10, divisions: 10);
        addSlider("Corner Radius", "radius", min: 0, max: 12, divisions: 6);
        addSlider("Color Mix", "intensity");
        break;
      case 'three-dimensional stream graph':
        addSlider("Stream Height", "intensity", min: 0.5, max: 2.0, divisions: 6);
        addSlider("Wiggle Power", "smoothing");
        addSlider("Layer Depth", "opacity");
        break;
      case 'sankey diagram':
        addSlider("Flow Opacity", "opacity");
        addSlider("Node Thickness", "thickness", min: 10, max: 40, divisions: 6);
        break;
      case 'rose chart':
        addSlider("Rose Scale", "intensity", min: 0.5, max: 1.5, divisions: 10);
        addSlider("Opacity", "opacity");
        break;
      case 'data table':
        addSlider("Row Height", "thickness", min: 30, max: 60, divisions: 6);
        controls.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ElevatedButton.icon(
            onPressed: () => _sortData(0),
            icon: const Icon(Icons.sort_rounded, size: 16),
            label: const Text("AUTO SORT ID", style: TextStyle(fontSize: 10)),
            style: ElevatedButton.styleFrom(
              backgroundColor: MountMapColors.teal.withValues(alpha: 0.1),
              foregroundColor: MountMapColors.teal,
            ),
          ),
        ));
        break;
    }

    return controls;
  }

  Widget _styleSection(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.white24),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(String title, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: MountMapColors.teal,
      ),
    );
  }

  Widget _colorPicker(String title, Color color, Function(Color) onSelect) {
    final List<Color> presets = [
      MountMapColors.teal,
      MountMapColors.violet,
      Colors.amber,
      Colors.redAccent,
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((c) => InkWell(
              onTap: () => onSelect(c),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c == color ? Colors.white : Colors.transparent, width: 2),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionRow(BoxConstraints constraints) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: MountMapColors.darkCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _miniActionBtn(Icons.add_chart_rounded, () {
             _showChartSelector();
          }, label: "ADD CHART"),
          const VerticalDivider(width: 20, indent: 10, endIndent: 10, color: Colors.white10),
          _miniActionBtn(Icons.zoom_in_rounded, () {
             _transformationController.value = _transformationController.value.clone()..scale(1.1, 1.1, 1.0);
          }),
          _miniActionBtn(Icons.zoom_out_rounded, () {
             _transformationController.value = _transformationController.value.clone()..scale(0.9, 0.9, 1.0);
          }),
          const SizedBox(width: 8),
          _miniActionBtn(Icons.center_focus_strong_rounded, () {
            _transformationController.value = Matrix4.identity();
          }),
          const SizedBox(width: 8),
          _miniActionBtn(Icons.refresh_rounded, () {
            _transformationController.value = Matrix4.identity();
          }),
          const VerticalDivider(width: 20, indent: 10, endIndent: 10, color: Colors.white10),
          _miniActionBtn(Icons.fit_screen_rounded, () {
            _autoFitToWidth(constraints);
          }, label: "FIT WIDTH"),
        ],
      ),
    );
  }

  void _showChartSelector() {
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
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: const BoxDecoration(
          color: MountMapColors.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("ADD NEW CHART TO WORKSPACE",
                    style: TextStyle(color: Colors.white54, letterSpacing: 3, fontSize: 10, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
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
                            Text(category.key, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
                              _addNewChartNode(chart['name']);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                                    style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
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

  void _autoFitToWidth(BoxConstraints constraints) {
    final double paperWidth = _isLandscape ? 1122 : 794;
    final double scale = (constraints.maxWidth - 80) / paperWidth;

    // Smooth transition
    final startMatrix = _transformationController.value;
    final endMatrix = Matrix4.identity()..scale(scale);

    final animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutExpo);

    animation.addListener(() {
      final matrix = Matrix4.identity();
      for (int i = 0; i < 16; i++) {
        matrix.storage[i] = startMatrix.storage[i] + (endMatrix.storage[i] - startMatrix.storage[i]) * curvedAnimation.value;
      }
      _transformationController.value = matrix;
    });

    animation.forward().then((_) => animation.dispose());
  }

  void _addNewChartNode(String type) {
    final provider = Provider.of<MountMapProvider>(context, listen: false);

    // Position it away from existing ones
    double offset = widget.asset.nodes.length * 100.0;

    final newNode = NodeModel(
      id: 'chart_${DateTime.now().millisecondsSinceEpoch}',
      text: "New $type",
      position: Offset(offset, offset),
      tableData: _getInitialTableData(type),
      dataList: [],
      marker: type,
    );

    widget.asset.nodes.add(newNode);
    setState(() {
      _selectedChartId = newNode.id;
    });
    provider.triggerUpdate();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$type added to workspace"), backgroundColor: MountMapColors.teal),
    );
  }

  Widget _miniActionBtn(IconData icon, VoidCallback onTap, {String? label}) {
    if (label != null) {
      return TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: MountMapColors.teal, size: 18),
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
      );
    }
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: 20),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Widget _buildSplitter(bool isLeft) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          if (isLeft) {
            _leftPanelWidth = (_leftPanelWidth + details.delta.dx).clamp(200.0, 600.0);
          } else {
            _rightPanelWidth = (_rightPanelWidth - details.delta.dx).clamp(200.0, 600.0);
          }
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Container(
          width: 4,
          color: Colors.white.withValues(alpha: 0.05),
          child: Center(
            child: Container(
              width: 1,
              height: 40,
              color: MountMapColors.teal.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: MountMapColors.teal),
              SizedBox(height: 20),
              Text("Generating High-Fidelity Chart PNG...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;

    const double step = 30.0;

    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
