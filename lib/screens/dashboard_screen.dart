import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../providers/mountmap_provider.dart';
import '../models/mindmap_model.dart';
import '../theme/app_colors.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'chart_screen.dart';

class MountMapDashboard extends StatefulWidget {
  const MountMapDashboard({super.key});

  @override
  State<MountMapDashboard> createState() => _MountMapDashboardState();
}

class _MountMapDashboardState extends State<MountMapDashboard> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MountMapProvider>(context);
    final isDark = provider.currentTheme == AppThemeMode.dark;

    final List<MindMapAsset> displayAssets = _isSearching
        ? provider.assets
            .where((a) => a.title.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList()
        : provider.filteredAssets;

    return Scaffold(
      backgroundColor: provider.backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(provider),
          if (!_isSearching) _buildWorkflowStats(provider),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(25, 20, 25, 5),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_rounded, size: 14, color: MountMapColors.teal),
                  const SizedBox(width: 8),
                  Text(
                    _isSearching ? "SEARCH RESULTS" : "WORKFLOW STRUCTURE",
                    style: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!_isSearching && provider.currentFolderId != null)
             SliverToBoxAdapter(child: _buildUpLink(provider)),

          displayAssets.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState(_isSearching))
              : _buildMindMapWorkflow(displayAssets, provider),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MountMapColors.teal.withValues(alpha: 0.6),
              MountMapColors.violet.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text("NEW PEAK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
          onPressed: () => _showPickerMenu(context, provider),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(MountMapProvider provider) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: provider.backgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MountMapColors.violet,
                MountMapColors.teal,
              ],
            ),
          ),
          child: Opacity(
            opacity: 0.1,
            child: Container(color: Colors.black),
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: _isSearching
            ? _buildSearchField()
            : Row(
                children: [
                  Image.asset('assets/logo.png', width: 24, height: 24),
                  const SizedBox(width: 12),
                  const Text(
                    "DASHBOARD",
                    style: TextStyle(
                      letterSpacing: 5,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        if (provider.hasAssetClipboard)
          IconButton(
            icon: const Icon(Icons.assignment_returned_rounded, color: Colors.amber, size: 20),
            onPressed: () {
              provider.pasteAsset();
              provider.clearAssetClipboard();
            },
          ),
        IconButton(
          icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: Colors.white, size: 20),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchQuery = "";
                _searchController.clear();
              }
            });
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildWorkflowStats(MountMapProvider provider) {
    final folderCount = provider.assets.where((a) => a.isFolder).length;
    final mapCount = provider.assets.where((a) => !a.isFolder).length;

    return SliverToBoxAdapter(
      child: Container(
        height: 105,
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Row(
          children: [
            _statCard("PROJECTS", mapCount.toString(), MountMapColors.teal, flex: 15),
            const SizedBox(width: 10),
            _statCard("FOLDERS", folderCount.toString(), Colors.amber, flex: 15),
            const SizedBox(width: 10),
            Expanded(flex: 16, child: _buildAttendanceHeatmap(provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceHeatmap(MountMapProvider provider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // ISO-8601: Monday is 1, Sunday is 7.
    final startOffset = (today.weekday - 1);
    // Align to Monday of 5 weeks ago
    final startDate = today.subtract(Duration(days: startOffset + 28));
    final dayLetters = ["M", "T", "W", "T", "F", "S", "S"];

    final isDark = provider.currentTheme == AppThemeMode.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (int i = 0; i < 7; i++) ...[
                Expanded(
                  child: Center(
                    child: Text(
                      dayLetters[i],
                      style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3), fontSize: 6.5, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
                if (i < 6) const SizedBox(width: 2.5),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 2.5,
                crossAxisSpacing: 2.5,
                childAspectRatio: 1.0,
              ),
              itemCount: 35, // 5 weeks
              itemBuilder: (context, index) {
                final date = startDate.add(Duration(days: index));
                final dateStr = date.toIso8601String().split('T')[0];
                final bool isActive = provider.attendanceDates.contains(dateStr);
                final bool isToday = date.year == today.year && date.month == today.month && date.day == today.day;

                return Container(
                  decoration: BoxDecoration(
                    color: isActive ? MountMapColors.teal : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(1.2),
                    border: isToday ? Border.all(color: MountMapColors.teal.withValues(alpha: 0.5), width: 1) : null,
                  ),
                  child: isToday && !isActive ? Center(
                    child: Container(
                      width: 2.5, height: 2.5,
                      decoration: const BoxDecoration(color: MountMapColors.teal, shape: BoxShape.circle),
                    ),
                  ) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, {int flex = 10}) {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                label == "PROJECTS"
                    ? Image.asset(
                        'assets/logo.png',
                        width: 14,
                        height: 14,
                        color: color,
                      )
                    : Icon(
                        label == "FOLDERS" ? Icons.folder_rounded : Icons.terrain_rounded,
                        color: color,
                        size: 14,
                      ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 8.0, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBreadcrumbs(MountMapProvider provider) {
    final crumbs = provider.breadcrumbs;
    if (crumbs.isEmpty) return const SizedBox.shrink();
    final isDark = provider.currentTheme == AppThemeMode.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? MountMapColors.darkCard : MountMapColors.lightCard).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            InkWell(
              onTap: () => provider.enterFolder(null),
              child: Icon(Icons.home_rounded, size: 16, color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3)),
            ),
            for (var crumb in crumbs) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right_rounded, size: 14, color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
              ),
              InkWell(
                onTap: () => provider.enterFolder(crumb.id),
                child: Text(
                  crumb.title,
                  style: TextStyle(
                    color: crumb == crumbs.last ? MountMapColors.teal : (isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5)),
                    fontSize: 11,
                    fontWeight: crumb == crumbs.last ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpLink(MountMapProvider provider) {
    final isDark = provider.currentTheme == AppThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 45, top: 10),
      child: InkWell(
        onTap: () => provider.goBack(),
        child: Row(
          children: [
            CustomPaint(
              size: const Size(20, 30),
              painter: WorkflowLinePainter(isLast: false, isUp: true, isDark: isDark),
            ),
            Icon(Icons.arrow_upward_rounded, size: 14, color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2)),
            const SizedBox(width: 8),
            Text("Go back", style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2), fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildMindMapWorkflow(List<MindMapAsset> assets, MountMapProvider provider) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _buildBreadcrumbs(provider),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final isLast = index == assets.length - 1;
                return _buildWorkflowNode(assets[index], provider, isLast);
              },
              childCount: assets.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkflowNode(MindMapAsset asset, MountMapProvider provider, bool isLast) {
    final bool isFolder = asset.isFolder;
    final bool isChart = asset.id.startsWith("chart_");
    final bool isDocx = asset.folderName == "DocxMap";

    Color accentColor = MountMapColors.teal;
    String typeLabel = "MAP";
    List<Color> gradientColors = [MountMapColors.violet.withValues(alpha: 0.3), MountMapColors.teal.withValues(alpha: 0.1)];

    if (isFolder) {
      accentColor = Colors.amber;
      typeLabel = "FOLDER";
      gradientColors = [Colors.amber.withValues(alpha: 0.3), Colors.amber.withValues(alpha: 0.1)];
    } else if (isChart) {
      accentColor = Colors.purpleAccent;
      typeLabel = "CHART";
      gradientColors = [Colors.purpleAccent.withValues(alpha: 0.3), Colors.purpleAccent.withValues(alpha: 0.1)];
    } else if (isDocx) {
      accentColor = Colors.blueAccent;
      typeLabel = "DOCX";
      gradientColors = [Colors.blueAccent.withValues(alpha: 0.3), Colors.blueAccent.withValues(alpha: 0.1)];
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CONNECTION LINE
        Padding(
          padding: const EdgeInsets.only(left: 25),
          child: CustomPaint(
            size: const Size(40, 80),
            painter: WorkflowLinePainter(isLast: isLast, isDark: provider.currentTheme == AppThemeMode.dark),
          ),
        ),

        // ASSET CARD (The "Node")
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (isFolder) {
                    provider.enterFolder(asset.id);
                  } else if (asset.id.startsWith("chart_")) {
                    final chartType = asset.folderName.replaceFirst("Chart: ", "");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChartCanvasScreen(
                          chartType: chartType,
                          asset: asset,
                        ),
                      ),
                    );
                  } else {
                    provider.openAsset(asset);
                    Navigator.pushNamed(context, '/canvas');
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isFolder ? Colors.amber.withValues(alpha: 0.03) : (provider.currentTheme == AppThemeMode.dark ? MountMapColors.darkCard : MountMapColors.lightCard),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withValues(alpha: isFolder ? 0.3 : 0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: provider.currentTheme == AppThemeMode.dark ? 0.15 : 0.05), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Icon Node
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: isFolder 
                          ? Icon(
                              Icons.folder_rounded,
                              color: accentColor,
                              size: 22,
                            )
                          : Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  'assets/logo.png',
                                  color: accentColor,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),

                      // Metadata Node
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asset.title,
                              style: TextStyle(color: provider.currentTheme == AppThemeMode.dark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  typeLabel,
                                  style: TextStyle(color: accentColor.withValues(alpha: 0.6), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                                ),
                                const SizedBox(width: 8),
                                Container(width: 2, height: 2, decoration: BoxDecoration(color: (provider.currentTheme == AppThemeMode.dark ? Colors.white : Colors.black).withValues(alpha: 0.1), shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text(
                                  isFolder ? "Expand structure" : "${asset.nodeCount} branches",
                                  style: TextStyle(color: (provider.currentTheme == AppThemeMode.dark ? Colors.white : Colors.black).withValues(alpha: 0.2), fontSize: 9),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Action Menu
                      _buildAssetMenu(context, asset, provider),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Future<void> _handleImport(MountMapProvider provider) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        
        if (file.path.endsWith('.mountflow') || file.path.endsWith('.mountmap')) {
          await provider.importFromMountMap(file);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("File imported successfully!")),
            );
          }
        } else {
          throw "Please select a valid .mountflow or .mountmap file";
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
  
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: MountMapColors.teal,
      decoration: const InputDecoration(
        hintText: "Search files or folders...",
        hintStyle: TextStyle(color: Colors.white54),
        border: InputBorder.none,
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildEmptyState(bool isSearching) {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.terrain_outlined,
            size: 60,
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? "No results found for '$_searchQuery'" : "No Peaks Yet",
            style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetMenu(BuildContext context, MindMapAsset asset, MountMapProvider provider) {
    final isDark = provider.currentTheme == AppThemeMode.dark;
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 18),
      color: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (value) {
        if (value == 'rename') _showRenameDialog(context, asset, provider);
        if (value == 'delete') _showDeleteConfirm(context, asset, provider);
        if (value == 'move') _showMoveSheet(context, asset, provider);
        if (value == 'export') provider.exportToMountFlow(asset);

        if (value == 'duplicate') {
          provider.duplicateAsset(asset.id);
        }

        if (value == 'copy') {
          provider.copyAssetToClipboard(asset.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("'${asset.title}' disalin ke clipboard"),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      itemBuilder: (context) => [
        _menuItem("Ubah Nama", Icons.edit_note_rounded, "rename"),
        _menuItem("Duplikat", Icons.content_copy_rounded, "duplicate"),
        _menuItem("Salin (Copy)", Icons.copy_all_rounded, "copy"),
        _menuItem("Export .mountflow", Icons.save_alt_rounded, "export"),
        _menuItem("Pindah Folder", Icons.folder_copy_rounded, "move"),
        const PopupMenuDivider(height: 10),
        _menuItem("Hapus", Icons.delete_outline_rounded, "delete", isDelete: true),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String title, IconData icon, String value, {bool isDelete = false}) {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: isDelete ? Colors.redAccent : MountMapColors.teal),
        const SizedBox(width: 12),
        Text(title, style: TextStyle(color: isDelete ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87), fontSize: 13)),
      ]),
    );
  }

  void _showPickerMenu(BuildContext context, MountMapProvider provider) {
    final isDark = provider.currentTheme == AppThemeMode.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("ADD NEW ITEM", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, letterSpacing: 3, fontSize: 10)),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.black54),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.create_new_folder_rounded, color: Colors.amber),
              title: Text("Create Folder", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () { Navigator.pop(context); _showCreateDialog(context, provider, isFolder: true); },
            ),
            ListTile(
              leading: const Icon(Icons.add_chart_rounded, color: MountMapColors.teal),
              title: Text("Create MindMap", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () { Navigator.pop(context); _showCreateDialog(context, provider, isFolder: false); },
            ),
            ListTile(
              leading: const Icon(Icons.description_rounded, color: Colors.blueAccent),
              title: Text("Create DocxMap", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () { Navigator.pop(context); _showCreateDialog(context, provider, isFolder: false, isDocxMap: true); },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded, color: Colors.purpleAccent),
              title: Text("Create Charts", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () { 
                Navigator.pop(context); 
                _showChartTypePicker(context, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_open_rounded, color: Colors.blueAccent),
              title: Text("Import .mountflow File", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                _handleImport(provider);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
      "CREATIVE & BLANK": [
        {"name": "Blank Canvas", "icon": Icons.crop_free_rounded},
      ],
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? MountMapColors.darkCard : MountMapColors.lightCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("HIERARCHICAL CHART SELECTION",
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, letterSpacing: 3, fontSize: 10, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.black54),
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
                            Text(category.key, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
                              _showCreateChartDialog(context, provider, chart['name']);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
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
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 9, fontWeight: FontWeight.w600),
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

  void _showCreateChartDialog(BuildContext context, MountMapProvider provider, String chartType) {
    final TextEditingController controller = TextEditingController();
    _showStyledDialog(
      context,
      title: "New $chartType",
      icon: Icons.bar_chart_rounded,
      accentColor: Colors.purpleAccent,
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: provider.textColor),
        decoration: InputDecoration(
          hintText: "Enter chart name...",
          hintStyle: TextStyle(color: provider.textColor.withValues(alpha: 0.24)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: provider.textColor.withValues(alpha: 0.54)))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
          onPressed: () {
            if (controller.text.isNotEmpty) {
              final newAsset = provider.createNewChartAsset(controller.text, chartType);
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChartCanvasScreen(chartType: chartType, asset: newAsset)),
              );
            }
          },
          child: const Text("CREATE", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context, MountMapProvider provider, {bool isFolder = false, bool isDocxMap = false}) {
    final TextEditingController controller = TextEditingController();
    final Color activeColor = isDocxMap ? Colors.blueAccent : (isFolder ? Colors.amber : MountMapColors.teal);

    _showStyledDialog(
      context,
      title: isFolder ? "New Folder" : (isDocxMap ? "New DocxMap" : "New MindMap"),
      icon: isFolder ? Icons.create_new_folder_rounded : (isDocxMap ? Icons.description_rounded : Icons.add_chart_rounded),
      accentColor: activeColor,
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: provider.textColor),
        decoration: InputDecoration(
          hintText: "Enter name...",
          hintStyle: TextStyle(color: provider.textColor.withValues(alpha: 0.24)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: activeColor)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          style: TextButton.styleFrom(
            foregroundColor: provider.textColor.withValues(alpha: 0.54),
          ),
          child: const Text("CANCEL"),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: activeColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            if (controller.text.isNotEmpty) {
              if (isFolder) {
                provider.createNewFolder(controller.text);
              } else {
                provider.createNewAsset(controller.text, isDocxMap: isDocxMap);
              }
              Navigator.pop(context);
            }
          },
          child: const Text("CREATE", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _showMoveSheet(BuildContext context, MindMapAsset asset, MountMapProvider provider) {
    final availableFolders = provider.getAvailableFolders(asset.id);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
            Text("MOVE ITEM", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, letterSpacing: 4, fontSize: 10)),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.grid_view_rounded, color: isDark ? Colors.white38 : Colors.black38),
              title: Text("Main Directory (Root)", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () { provider.moveAsset(asset.id, null); Navigator.pop(context); },
            ),
            Divider(color: isDark ? Colors.white10 : Colors.black12),
            ...availableFolders.map((folder) => ListTile(
              leading: const Icon(Icons.folder_rounded, color: Colors.amber),
              title: Text(folder.title, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () { provider.moveAsset(asset.id, folder.id); Navigator.pop(context); },
            )),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, MindMapAsset asset, MountMapProvider provider) {
    TextEditingController controller = TextEditingController(text: asset.title);
    _showStyledDialog(
      context,
      title: "Rename",
      icon: Icons.edit_rounded,
      accentColor: MountMapColors.teal,
      content: TextField(
        controller: controller,
        style: TextStyle(color: provider.textColor),
        decoration: const InputDecoration(focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: MountMapColors.teal))),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          style: TextButton.styleFrom(
            foregroundColor: provider.textColor.withValues(alpha: 0.54),
          ),
          child: const Text("CANCEL"),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: MountMapColors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () { 
            provider.renameAsset(asset.id, controller.text); 
            Navigator.pop(context); 
          }, 
          child: const Text("RENAME", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _showDeleteConfirm(BuildContext context, MindMapAsset asset, MountMapProvider provider) {
    _showStyledDialog(
      context,
      title: "Delete?",
      icon: Icons.delete_forever_rounded,
      accentColor: Colors.redAccent,
      content: Text("Delete '${asset.title}' permanently?", style: TextStyle(color: provider.textColor.withValues(alpha: 0.7))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          style: TextButton.styleFrom(
            foregroundColor: provider.textColor.withValues(alpha: 0.54),
          ),
          child: const Text("CANCEL"),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () { 
            provider.deleteAsset(asset.id); 
            Navigator.pop(context); 
          },
          child: const Text("DELETE", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _showStyledDialog(BuildContext context, {required String title, required IconData icon, required Color accentColor, required Widget content, required List<Widget> actions}) {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final isDark = provider.currentTheme == AppThemeMode.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.85,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: accentColor, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        title, 
                        style: TextStyle(
                          color: provider.textColor,
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: provider.textColor.withValues(alpha: 0.54)),
                    onPressed: () => Navigator.pop(dialogContext),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Material(color: Colors.transparent, child: content),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end, 
                children: actions.map((action) {
                  if (action is TextButton && (action.child as Text).data == "CANCEL") {
                    return TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: action.style,
                      child: Text("CANCEL", style: TextStyle(color: provider.textColor.withValues(alpha: 0.24))),
                    );
                  }
                  return action;
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkflowLinePainter extends CustomPainter {
  final bool isLast;
  final bool isUp;
  final bool isDark;

  WorkflowLinePainter({required this.isLast, this.isUp = false, this.isDark = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    paint.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, size.height),
      [
        MountMapColors.violet.withValues(alpha: isDark ? 1.0 : 0.6),
        MountMapColors.teal.withValues(alpha: isDark ? 1.0 : 0.6),
      ],
    );

    final path = Path();

    if (isUp) {
      path.moveTo(size.width / 2, size.height);
      path.lineTo(size.width / 2, size.height / 2);
      path.lineTo(size.width, size.height / 2);
    } else {
      path.moveTo(0, 0);
      path.lineTo(0, isLast ? size.height / 2 : size.height);

      path.moveTo(0, size.height / 2);
      path.lineTo(size.width, size.height / 2);
    }

    canvas.drawPath(path, paint);

    if (!isUp) {
      final dotPaint = Paint()..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15);
      canvas.drawCircle(const Offset(0, 0), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
