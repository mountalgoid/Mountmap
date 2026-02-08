import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/node_model.dart';
import '../theme/app_colors.dart';
import '../providers/mountmap_provider.dart';

class SearchTextEditingController extends TextEditingController {
  String _searchQuery = "";
  List<int> _matches = [];
  int _currentIndex = -1;

  void updateSearch(String query, List<int> matches, int index) {
    _searchQuery = query;
    _matches = matches;
    _currentIndex = index;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (_searchQuery.isEmpty || _matches.isEmpty) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }

    final List<TextSpan> children = [];
    final String text = value.text;
    int lastMatchEnd = 0;

    for (int i = 0; i < _matches.length; i++) {
      final int start = _matches[i];
      final int end = start + _searchQuery.length;

      if (start >= text.length) break;
      final actualEnd = end > text.length ? text.length : end;

      // Text before match
      if (start > lastMatchEnd) {
        children.add(TextSpan(text: text.substring(lastMatchEnd, start)));
      }

      // The match
      final bool isCurrent = i == _currentIndex;
      children.add(TextSpan(
        text: text.substring(start, actualEnd),
        style: style?.copyWith(
          backgroundColor: isCurrent
            ? MountMapColors.teal.withValues(alpha: 0.8)
            : Colors.yellow.withValues(alpha: 0.3),
          color: isCurrent ? Colors.white : style.color,
          fontWeight: isCurrent ? FontWeight.bold : style.fontWeight,
        ),
      ));

      lastMatchEnd = actualEnd;
    }

    // Remaining text
    if (lastMatchEnd < text.length) {
      children.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return TextSpan(style: style, children: children);
  }
}

class MinimapPainter extends CustomPainter {
  final String text;
  final double scrollOffset;
  final double maxScrollExtent;
  final double viewportHeight;

  MinimapPainter({
    required this.text,
    required this.scrollOffset,
    required this.maxScrollExtent,
    required this.viewportHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;

    final lines = text.split('\n');
    final double totalContentHeight = maxScrollExtent + viewportHeight;
    final double scale = size.height / totalContentHeight;

    // Draw text representation
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;

      final double y = (i * 14 * 1.6 + 16.0) * scale;
      if (y > size.height) break;

      // Render line length proportionally
      final double lineLen = (line.length * 2.0).clamp(2.0, size.width - 4);
      canvas.drawLine(Offset(2, y), Offset(2 + lineLen, y), paint);
    }

    // Draw Viewport Indicator
    final double viewTop = scrollOffset * scale;
    final double viewHeight = viewportHeight * scale;

    final viewPaint = Paint()
      ..color = MountMapColors.teal.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, viewTop, size.width, viewHeight), viewPaint);

    final borderPaint = Paint()
      ..color = MountMapColors.teal.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(Rect.fromLTWH(0, viewTop, size.width, viewHeight), borderPaint);
  }

  @override
  bool shouldRepaint(MinimapPainter oldDelegate) {
    return oldDelegate.text != text ||
           oldDelegate.scrollOffset != scrollOffset ||
           oldDelegate.maxScrollExtent != maxScrollExtent ||
           oldDelegate.viewportHeight != viewportHeight;
  }
}

class AttachmentViewerScreen extends StatefulWidget {
  final AttachmentItem item;

  const AttachmentViewerScreen({super.key, required this.item});

  @override
  State<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends State<AttachmentViewerScreen> {
  // Video & Audio Controllers
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // WebView Controller
  WebViewController? _webController;
  bool _isWebLoading = false;

  // Text Editor Controller
  final SearchTextEditingController _textController = SearchTextEditingController();
  final UndoHistoryController _undoController = UndoHistoryController();
  final ScrollController _verticalScroll = ScrollController();
  final FocusNode _editorFocus = FocusNode();

  bool _isEditingText = false;
  bool _isSaving = false;
  bool _isLoadingText = false;
  String _lastText = "";

  bool _isAudioPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  // Search State
  List<int> _searchMatches = [];
  int _currentSearchIndex = -1;

  @override
  void initState() {
    super.initState();
    _verticalScroll.addListener(_onScrollChange);
    if (widget.item.type == 'link') {
      _initWebView();
    } else {
      _initViewer();
    }
  }

  void _onScrollChange() {
    if (mounted) setState(() {});
  }

  void _initWebView() {
    setState(() => _isWebLoading = true);
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isWebLoading = true),
          onPageFinished: (url) => setState(() => _isWebLoading = false),
          onWebResourceError: (error) => debugPrint("WebView Error: ${error.description}"),
        ),
      );

    // [NOTE] DOM Storage is usually enabled by default in modern webview_flutter.
    // Explicitly enabling it requires correct platform-specific controller which
    // depends on the exact version of webview_flutter_android.

    _webController!.loadRequest(Uri.parse(widget.item.value));
  }

  void _initViewer() {
    final ext = widget.item.value.toLowerCase();
    if (ext.endsWith('.mp4') || ext.endsWith('.mp5') || ext.endsWith('.mov') || ext.endsWith('.mkv')) {
      _initVideo();
    } else if (ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.m4a')) {
      _initAudio();
    } else if (ext.endsWith('.txt')) {
      _loadTextFile();
    }
  }

  Future<void> _loadTextFile() async {
    setState(() => _isLoadingText = true);
    try {
      final content = await File(widget.item.value).readAsString();
      _textController.text = content;
      _lastText = content;
      _isEditingText = true;
    } catch (e) {
      debugPrint("Error loading text: $e");
    } finally {
      if (mounted) setState(() => _isLoadingText = false);
    }
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.file(File(widget.item.value));
    await _videoController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoController!.value.aspectRatio,
      materialProgressColors: ChewieProgressColors(
        playedColor: MountMapColors.teal,
        handleColor: MountMapColors.teal,
        backgroundColor: Colors.white10,
        bufferedColor: Colors.white24,
      ),
    );
    setState(() {});
  }

  void _initAudio() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isAudioPlaying = state == PlayerState.playing);
      }
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _audioDuration = duration);
    });
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _audioPosition = position);
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _audioPlayer.dispose();
    _textController.dispose();
    _undoController.dispose();
    _verticalScroll.dispose();
    _editorFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MountMapProvider>(context);
    final ext = widget.item.value.toLowerCase();
    final isTxt = ext.endsWith('.txt');
    final isLink = widget.item.type == 'link';

    return Scaffold(
      backgroundColor: provider.backgroundColor,
      appBar: AppBar(
        title: Text(widget.item.name, style: TextStyle(fontSize: 16, color: provider.textColor)),
        backgroundColor: provider.cardColor,
        iconTheme: IconThemeData(color: provider.textColor),
        elevation: 0,
        actions: [
          if (isTxt)
            _isSaving
              ? const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: MountMapColors.teal))))
              : IconButton(
                  icon: const Icon(Icons.save_rounded, color: MountMapColors.teal),
                  onPressed: _saveTextFile,
                ),
        ],
      ),
      body: _buildBody(ext, provider),
      bottomNavigationBar: isTxt ? _buildMiniToolbar(provider) : (isLink ? _buildWebToolbar(provider) : null),
    );
  }

  Future<void> _saveTextFile() async {
    setState(() => _isSaving = true);
    try {
      await File(widget.item.value).writeAsString(_textController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File berhasil disimpan"), backgroundColor: MountMapColors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan file: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildBody(String ext, MountMapProvider provider) {
    if (widget.item.type == 'link') {
      return _buildWebViewer();
    }
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.webp')) {
      return _buildImageViewer();
    } else if (ext.endsWith('.txt')) {
      return _buildTextViewer(provider);
    } else if (ext.endsWith('.mp4') || ext.endsWith('.mp5') || ext.endsWith('.mov') || ext.endsWith('.mkv')) {
      return _buildVideoViewer();
    } else if (ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.m4a')) {
      return _buildAudioViewer(provider);
    }
    return Center(child: Text("Format tidak didukung untuk pratinjau in-app", style: TextStyle(color: provider.textColor)));
  }

  Widget _buildWebViewer() {
    if (_webController == null) return const Center(child: CircularProgressIndicator());
    return Stack(
      children: [
        WebViewWidget(controller: _webController!),
        if (_isWebLoading)
          const LinearProgressIndicator(color: MountMapColors.teal, backgroundColor: Colors.transparent),
      ],
    );
  }

  Widget _buildWebToolbar(MountMapProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: provider.cardColor,
        border: Border(top: BorderSide(color: provider.textColor.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: MountMapColors.teal),
            onPressed: () async {
              if (await _webController?.canGoBack() ?? false) {
                await _webController?.goBack();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20, color: MountMapColors.teal),
            onPressed: () async {
              if (await _webController?.canGoForward() ?? false) {
                await _webController?.goForward();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22, color: MountMapColors.teal),
            onPressed: () => _webController?.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20, color: MountMapColors.teal),
            onPressed: () async {
              final url = await _webController?.currentUrl();
              if (url != null) {
                await Clipboard.setData(ClipboardData(text: url));
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("URL disalin ke clipboard")));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded, size: 22, color: MountMapColors.teal),
            onPressed: () async {
              final url = await _webController?.currentUrl() ?? widget.item.value;
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.file(
          File(widget.item.value),
          errorBuilder: (context, error, stackTrace) => const Center(child: Text("Gagal memuat gambar", style: TextStyle(color: Colors.red))),
        ),
      ),
    );
  }

  Widget _buildTextViewer(MountMapProvider provider) {
    if (_isLoadingText) {
      return const Center(child: CircularProgressIndicator(color: MountMapColors.teal));
    }
    if (_isEditingText) {
      return _textEditor(provider);
    }
    return const Center(child: Text("Gagal memuat file", style: TextStyle(color: Colors.red)));
  }

  void _handleAutoIndent(String text) {
    if (text.length > _lastText.length) {
      final cursorPosition = _textController.selection.baseOffset;
      if (cursorPosition > 0 && text[cursorPosition - 1] == '\n') {
        final beforeCursor = text.substring(0, cursorPosition - 1);
        final lines = beforeCursor.split('\n');
        final prevLine = lines.last;
        final match = RegExp(r'^(\s+)').firstMatch(prevLine);
        if (match != null) {
          final indent = match.group(1)!;
          final newText = text.substring(0, cursorPosition) + indent + text.substring(cursorPosition);
          _textController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: cursorPosition + indent.length),
          );
        }
      }
    }
    _lastText = _textController.text;
    setState(() {}); // Update line numbers
  }

  Widget _textEditor(MountMapProvider provider) {
    final lineCount = '\n'.allMatches(_textController.text).length + 1;
    final bool isDark = provider.currentTheme == AppThemeMode.dark;

    return Container(
      color: isDark ? const Color(0xFF0D1117) : (provider.currentTheme == AppThemeMode.warm ? const Color(0xFFFDF6E3) : Colors.white),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _verticalScroll,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line Numbers
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 16, 8, 16),
                    color: provider.textColor.withValues(alpha: 0.05),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(lineCount, (i) => Text(
                        "${i + 1}",
                        style: TextStyle(
                          color: provider.textColor.withValues(alpha: 0.2),
                          fontSize: 14,
                          fontFamily: 'monospace',
                          height: 1.6,
                        ),
                      )),
                    ),
                  ),

                  // Text Editor
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 110),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: IntrinsicWidth(
                          child: TextField(
                            controller: _textController,
                            undoController: _undoController,
                            focusNode: _editorFocus,
                            maxLines: null,
                            autofocus: true,
                            onChanged: _handleAutoIndent,
                            style: TextStyle(
                              color: provider.textColor,
                              fontSize: 14,
                              fontFamily: 'monospace',
                              height: 1.6,
                              letterSpacing: 0.8,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              hintText: "Mulai menulis...",
                              hintStyle: TextStyle(color: provider.textColor.withValues(alpha: 0.24)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Minimap Scroller
          _buildMinimap(provider),
        ],
      ),
    );
  }

  Widget _buildMinimap(MountMapProvider provider) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        _scrollFromMinimap(details.localPosition.dy, box.size.height);
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        _scrollFromMinimap(details.localPosition.dy, box.size.height);
      },
      child: Container(
        width: 50,
        decoration: BoxDecoration(
          color: provider.textColor.withValues(alpha: 0.02),
          border: Border(left: BorderSide(color: provider.textColor.withValues(alpha: 0.05))),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: MinimapPainter(
                text: _textController.text,
                scrollOffset: _verticalScroll.hasClients ? _verticalScroll.offset : 0.0,
                maxScrollExtent: _verticalScroll.hasClients ? _verticalScroll.position.maxScrollExtent : 1.0,
                viewportHeight: _verticalScroll.hasClients ? _verticalScroll.position.viewportDimension : 1.0,
              ),
            );
          },
        ),
      ),
    );
  }

  void _scrollFromMinimap(double y, double minimapHeight) {
    if (!_verticalScroll.hasClients) return;

    final double totalContentHeight = _verticalScroll.position.maxScrollExtent + _verticalScroll.position.viewportDimension;
    final double scrollTarget = (y / minimapHeight) * totalContentHeight - (_verticalScroll.position.viewportDimension / 2);

    _verticalScroll.jumpTo(scrollTarget.clamp(0.0, _verticalScroll.position.maxScrollExtent));
  }

  Widget _buildMiniToolbar(MountMapProvider provider) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: provider.cardColor,
        border: Border(top: BorderSide(color: provider.textColor.withValues(alpha: 0.05))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _toolbarBtn(provider, Icons.undo_rounded, "Undo", () => _undoController.undo()),
                  _toolbarBtn(provider, Icons.redo_rounded, "Redo", () => _undoController.redo()),
                  _toolbarBtn(provider, Icons.content_paste_rounded, "Tempel", _pasteText),
                  _toolbarBtn(provider, Icons.select_all_rounded, "Semua", () => _textController.selection = TextSelection(baseOffset: 0, extentOffset: _textController.text.length)),
                  _toolbarBtn(provider, Icons.search_rounded, "Cari", _showSearchReplace),
                  _toolbarBtn(provider, Icons.chevron_left_rounded, "Kiri", () => _moveCursor(-1)),
                  _toolbarBtn(provider, Icons.chevron_right_rounded, "Kanan", () => _moveCursor(1)),
                  _toolbarBtn(provider, Icons.save_rounded, "Simpan", _saveTextFile),
                  _toolbarBtn(provider, Icons.close_rounded, "Tutup", () => Navigator.pop(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarBtn(MountMapProvider provider, IconData icon, String label, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: MountMapColors.teal),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: provider.textColor.withValues(alpha: 0.7), fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pasteText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      final val = _textController.value;
      final newText = val.text.replaceRange(val.selection.start, val.selection.end, data!.text!);
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: val.selection.start + data.text!.length),
      );
      _handleAutoIndent(_textController.text);
    }
  }

  void _moveCursor(int delta) {
    final current = _textController.selection.baseOffset;
    final newPos = (current + delta).clamp(0, _textController.text.length).toInt();
    _textController.selection = TextSelection.collapsed(offset: newPos);
  }

  void _findMatches(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchMatches = [];
        _currentSearchIndex = -1;
        _textController.updateSearch("", [], -1);
      });
      return;
    }

    final String text = _textController.text;
    final List<int> matches = [];
    int index = text.indexOf(query);
    while (index != -1) {
      matches.add(index);
      index = text.indexOf(query, index + query.length);
    }

    setState(() {
      _searchMatches = matches;
      if (matches.isNotEmpty) {
        _currentSearchIndex = 0;
        _textController.updateSearch(query, matches, 0);
        _scrollToMatch(matches[0], query.length, requestFocus: false);
      } else {
        _currentSearchIndex = -1;
        _textController.updateSearch(query, [], -1);
      }
    });
  }

  void _scrollToMatch(int offset, int length, {bool requestFocus = true}) {
    _textController.selection = TextSelection(
      baseOffset: offset,
      extentOffset: offset + length,
    );

    // Auto-scroll logic
    if (_verticalScroll.hasClients) {
      final textBefore = _textController.text.substring(0, offset);
      final lineIndex = '\n'.allMatches(textBefore).length;
      const double lineHeight = 14 * 1.6;
      const double topPadding = 16.0;

      // Calculate target scroll to bring the line into view (centered)
      final viewportHeight = _verticalScroll.position.viewportDimension;
      // Change from / 3 to / 2 to center the match in the screen
      final targetScroll = (topPadding + (lineIndex * lineHeight)) - (viewportHeight / 2);

      _verticalScroll.animateTo(
        targetScroll.clamp(0.0, _verticalScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    if (requestFocus) {
      _editorFocus.requestFocus();
    }
  }

  void _showSearchReplace() {
    final provider = Provider.of<MountMapProvider>(context, listen: false);
    final searchCtrl = TextEditingController(text: _searchMatches.isNotEmpty ? _textController.text.substring(_searchMatches[0], _searchMatches[0] + (_textController.selection.end - _textController.selection.start)) : "");
    final replaceCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: provider.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Cari dan Ganti", style: TextStyle(color: provider.textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  if (_searchMatches.isNotEmpty)
                    Text(
                      "${_currentSearchIndex + 1} dari ${_searchMatches.length}",
                      style: const TextStyle(color: MountMapColors.teal, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchCtrl,
                style: TextStyle(color: provider.textColor),
                onChanged: (val) {
                  _findMatches(val);
                  setModalState(() {});
                },
                decoration: _dialogInputDecor(provider, "Cari teks...").copyWith(
                  suffixIcon: searchCtrl.text.isNotEmpty ? IconButton(
                    icon: Icon(Icons.clear, color: provider.textColor.withValues(alpha: 0.38), size: 20),
                    onPressed: () {
                      searchCtrl.clear();
                      _findMatches("");
                      setModalState(() {});
                    },
                  ) : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replaceCtrl,
                style: TextStyle(color: provider.textColor),
                decoration: _dialogInputDecor(provider, "Ganti dengan..."),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _searchMatches.isEmpty ? null : () {
                      setState(() {
                        _currentSearchIndex = (_currentSearchIndex - 1 + _searchMatches.length) % _searchMatches.length;
                        _textController.updateSearch(searchCtrl.text, _searchMatches, _currentSearchIndex);
                        _scrollToMatch(_searchMatches[_currentSearchIndex], searchCtrl.text.length, requestFocus: false);
                      });
                      setModalState(() {});
                    },
                    icon: const Icon(Icons.arrow_upward_rounded),
                    color: MountMapColors.teal,
                    disabledColor: Colors.white10,
                  ),
                  IconButton(
                    onPressed: _searchMatches.isEmpty ? null : () {
                      setState(() {
                        _currentSearchIndex = (_currentSearchIndex + 1) % _searchMatches.length;
                        _textController.updateSearch(searchCtrl.text, _searchMatches, _currentSearchIndex);
                        _scrollToMatch(_searchMatches[_currentSearchIndex], searchCtrl.text.length, requestFocus: false);
                      });
                      setModalState(() {});
                    },
                    icon: const Icon(Icons.arrow_downward_rounded),
                    color: MountMapColors.teal,
                    disabledColor: Colors.white10,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _searchMatches.isEmpty ? null : () {
                      if (_currentSearchIndex != -1) {
                        final start = _searchMatches[_currentSearchIndex];
                        final end = start + searchCtrl.text.length;
                        final text = _textController.text;
                        final newText = text.replaceRange(start, end, replaceCtrl.text);

                        _textController.text = newText;
                        _lastText = newText;

                        _findMatches(searchCtrl.text); // Refresh matches
                        setModalState(() {});
                      }
                    },
                    child: const Text("Ganti", style: TextStyle(color: MountMapColors.teal)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: MountMapColors.teal),
                    onPressed: () {
                      if (searchCtrl.text.isNotEmpty) {
                        final newText = _textController.text.replaceAll(searchCtrl.text, replaceCtrl.text);
                        _textController.text = newText;
                        _lastText = newText;
                        _findMatches(""); // Clear matches
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semua berhasil diganti")));
                      }
                    },
                    child: const Text("Ganti Semua", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dialogInputDecor(MountMapProvider provider, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: provider.textColor.withValues(alpha: 0.24)),
      filled: true,
      fillColor: provider.textColor.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildVideoViewer() {
    if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized) {
      return Chewie(controller: _chewieController!);
    }
    return const Center(child: CircularProgressIndicator(color: MountMapColors.teal));
  }

  Widget _buildAudioViewer(MountMapProvider provider) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: provider.cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note_rounded, size: 80, color: MountMapColors.teal),
            const SizedBox(height: 20),
            Text(widget.item.name, style: TextStyle(color: provider.textColor, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            Slider(
              activeColor: MountMapColors.teal,
              inactiveColor: provider.textColor.withValues(alpha: 0.1),
              value: _audioPosition.inSeconds.toDouble(),
              max: _audioDuration.inSeconds.toDouble() > 0 ? _audioDuration.inSeconds.toDouble() : 1.0,
              onChanged: (value) {
                _audioPlayer.seek(Duration(seconds: value.toInt()));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_audioPosition), style: TextStyle(color: provider.textColor.withValues(alpha: 0.54), fontSize: 12)),
                  Text(_formatDuration(_audioDuration), style: TextStyle(color: provider.textColor.withValues(alpha: 0.54), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 64,
                  icon: Icon(_isAudioPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded),
                  color: MountMapColors.teal,
                  onPressed: () {
                    if (_isAudioPlaying) {
                      _audioPlayer.pause();
                    } else {
                      _audioPlayer.play(DeviceFileSource(widget.item.value));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
