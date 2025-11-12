// pages/album_library_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../album/provider/album_provider.dart';
import '../network/constant_sign.dart';
import '../widgets/media_viewer_page.dart';
import '../widgets/side_navigation.dart';
import '../widgets/custom_title_bar.dart';
import '../user/models/group.dart';
import '../user/models/resource_list_model.dart';
import '../services/album_download_manager.dart';
import '../models/media_item.dart';

class AlbumLibraryPage extends StatefulWidget {
  final int selectedNavIndex;
  final Function(int) onNavigationChanged;
  final List<Group>? groups;
  final Group? selectedGroup;
  final Function(Group)? onGroupSelected;
  final int? currentUserId;

  const AlbumLibraryPage({
    super.key,
    required this.selectedNavIndex,
    required this.onNavigationChanged,
    this.groups,
    this.selectedGroup,
    this.onGroupSelected,
    this.currentUserId,
  });

  @override
  State<AlbumLibraryPage> createState() => _AlbumLibraryPageState();
}

class _AlbumLibraryPageState extends State<AlbumLibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AlbumProvider _albumProvider = AlbumProvider();

  // 数据
  List<ResList> _allResources = [];
  Map<String, List<ResList>> _groupedResources = {};
  final Set<String> _selectedResIds = {};

  // 状态
  bool _isLoading = false;
  bool _isGridView = true;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _hoveredResId;

  // 滚动控制
  final ScrollController _scrollController = ScrollController();

  // 预览相关状态
  bool _showPreview = false;
  int _previewIndex = -1;
  List<ResList> _mediaItems = [];

  // 视频播放器相关
  Player? _videoPlayer;
  VideoController? _videoController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadResources();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _disposeVideoPlayer();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _resetAndLoad();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  void _resetAndLoad() {
    setState(() {
      _allResources.clear();
      _groupedResources.clear();
      _selectedResIds.clear();
      _currentPage = 1;
      _hasMore = true;
      _closePreview();
    });
    _loadResources();
  }

  Future<void> _loadResources() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final isPrivate = _tabController.index == 0;
      final response = await _albumProvider.listResources(
        _currentPage,
        isPrivate: isPrivate,
      );

      if (response.isSuccess && response.model != null) {
        final newResources = response.model!.resList;

        setState(() {
          _allResources.addAll(newResources);
          _groupResourcesByDate();
          _hasMore = newResources.length >= AlbumProvider.myPageSize;
        });
      }
    } catch (e) {
      debugPrint('加载相册资源失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    _currentPage++;
    await _loadResources();
  }

  void _groupResourcesByDate() {
    _groupedResources.clear();
    final dateFormat = DateFormat('yyyy年M月d日');

    for (var resource in _allResources) {
      final date = resource.photoDate ?? resource.createDate;
      if (date != null) {
        final dateKey = dateFormat.format(date);
        _groupedResources.putIfAbsent(dateKey, () => []);
        _groupedResources[dateKey]!.add(resource);
      }
    }
  }

  // ========== 预览相关方法 ==========

  void _openPreview(int index) {
    setState(() {
      _showPreview = true;
      _previewIndex = index;
      _mediaItems = _allResources;
    });
    _loadPreviewMedia();
  }

  void _closePreview() {
    _disposeVideoPlayer();
    setState(() {
      _showPreview = false;
      _previewIndex = -1;
      _mediaItems = [];
    });
  }

  void _loadPreviewMedia() {
    if (_previewIndex < 0 || _previewIndex >= _mediaItems.length) return;

    final item = _mediaItems[_previewIndex];

    if (item.fileType == 'V') {
      _initVideoPlayer(item.originPath ?? item.mediumPath ?? '');
    } else {
      _disposeVideoPlayer();
    }
  }

  void _initVideoPlayer(String url) {
    _disposeVideoPlayer();

    if (url.isEmpty) return;

    _videoPlayer = Player();
    _videoController = VideoController(_videoPlayer!);

    _videoPlayer!.open(Media(url));
    _videoPlayer!.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });
  }

  void _disposeVideoPlayer() {
    _videoPlayer?.dispose();
    _videoPlayer = null;
    _videoController = null;
    _isPlaying = false;
  }

  void _previousMedia() {
    if (_previewIndex > 0) {
      setState(() {
        _previewIndex--;
      });
      _loadPreviewMedia();
    }
  }

  void _nextMedia() {
    if (_previewIndex < _mediaItems.length - 1) {
      setState(() {
        _previewIndex++;
      });
      _loadPreviewMedia();
    }
  }

  void _togglePlayPause() {
    if (_videoPlayer != null) {
      _videoPlayer!.playOrPause();
    }
  }

  // ========== 双击打开全屏查看器 ==========
  void _openFullScreenViewer(int index) {
    final mediaItems = _allResources
        .map((res) => MediaItem.fromResList(res))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewerPage(
          mediaItems: mediaItems,
          initialIndex: index,
        ),
      ),
    );
  }

  // ========== 选择相关方法 ==========

  void _toggleSelection(String resId) {
    setState(() {
      if (_selectedResIds.contains(resId)) {
        _selectedResIds.remove(resId);
      } else {
        _selectedResIds.add(resId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedResIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      _selectedResIds.addAll(
        _allResources.where((r) => r.resId != null).map((r) => r.resId!),
      );
    });
  }

  String _getSelectedSizeInfo() {
    int totalSize = 0;
    int photoCount = 0;
    int videoCount = 0;

    for (var resource in _allResources) {
      if (resource.resId != null && _selectedResIds.contains(resource.resId)) {
        totalSize += resource.fileSize ?? 0;
        if (resource.fileType == 'P') {
          photoCount++;
        } else if (resource.fileType == 'V') {
          videoCount++;
        }
      }
    }

    String sizeStr = _formatFileSize(totalSize);
    return '已选：$sizeStr · ${photoCount}张照片/${videoCount}条视频';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomTitleBar(
        backgroundColor: const Color(0xFFF5E8DC),
        rightTitleBgColor: Colors.white,
        showToolbar: true,
        child: Row(
          children: [
            SideNavigation(
              selectedIndex: widget.selectedNavIndex,
              onNavigationChanged: widget.onNavigationChanged,
              groups: widget.groups,
              selectedGroup: widget.selectedGroup,
              onGroupSelected: widget.onGroupSelected,
              currentUserId: widget.currentUserId,
            ),
            Expanded(
              child: Row(
                children: [
                  // 主内容区域
                  Expanded(
                    flex: _showPreview ? 3 : 1,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          _buildHeader(),
                          // _buildToolbar(),
                          Expanded(
                            child: _buildContent(),
                          ),
                          if (_selectedResIds.isNotEmpty) _buildBottomBar(),
                        ],
                      ),
                    ),
                  ),
                  // 预览区域
                  if (_showPreview)
                    Expanded(
                      flex: 2,
                      child: _buildPreviewPanel(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPanel() {
    if (_previewIndex < 0 || _previewIndex >= _mediaItems.length) {
      return Container();
    }

    final item = _mediaItems[_previewIndex];
    final isVideo = item.fileType == 'V';

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // 媒体显示区域
          Center(
            child: isVideo ? _buildVideoPreview(item) : _buildImagePreview(item),
          ),

          // 左侧切换按钮
          if (_previewIndex > 0)
            Positioned(
              left: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 48, color: Colors.white),
                  onPressed: _previousMedia,
                ),
              ),
            ),

          // 右侧切换按钮
          if (_previewIndex < _mediaItems.length - 1)
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 48, color: Colors.white),
                  onPressed: _nextMedia,
                ),
              ),
            ),

          // 视频播放/暂停按钮
          if (isVideo)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    size: 80,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
            ),

          // 关闭按钮
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, size: 32, color: Colors.white),
              onPressed: _closePreview,
            ),
          ),

          // 文件名显示
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_previewIndex + 1}/${_mediaItems.length} - ${item.fileName ?? "未命名"}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(ResList item) {
    return Image.network(
      item.mediumPath ?? item.originPath ?? '',
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                loadingProgress.expectedTotalBytes!
                : null,
            color: Colors.white,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.error, color: Colors.white, size: 64),
        );
      },
    );
  }

  Widget _buildVideoPreview(ResList item) {
    if (_videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Video(
      controller: _videoController!,
      controls: NoVideoControls,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey.shade600,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(width: 3, color: Colors.black87),
              insets: EdgeInsets.symmetric(horizontal: 25),
            ),
            tabs: const [
              Tab(text: '个人'),
              Tab(text: '家庭'),
            ],
          ),
          const Spacer(),
          _buildToolbar()
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 8),
          Row(
            children: [
              if (_selectedResIds.isNotEmpty)
                TextButton(
                  onPressed: _clearSelection,
                  child: const Text(
                    '取消选择',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _resetAndLoad,
                tooltip: '刷新',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: _selectAll,
                tooltip: '全选',
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: _isGridView ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.grid_view,
                    color: _isGridView ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _isGridView = true;
                    });
                  },
                  tooltip: '网格视图',
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.list),
                onPressed: () {
                  setState(() {
                    _isGridView = false;
                  });
                },
                tooltip: '列表视图',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _allResources.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_allResources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无照片',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: _groupedResources.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _groupedResources.length) {
          return _isLoading
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
              : const SizedBox.shrink();
        }

        final dateKey = _groupedResources.keys.elementAt(index);
        final resources = _groupedResources[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            _buildGridView(resources),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildGridView(List<ResList> resources) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: resources.length,
      itemBuilder: (context, index) {
        final resource = resources[index];
        final globalIndex = _allResources.indexOf(resource);
        final isSelected = _selectedResIds.contains(resource.resId);
        final isHovered = _hoveredResId == resource.resId;
        final shouldShowCheckbox = isHovered || _selectedResIds.isNotEmpty;

        return MouseRegion(
          onEnter: (_) {
            setState(() {
              _hoveredResId = resource.resId;
            });
          },
          onExit: (_) {
            setState(() {
              if (_hoveredResId == resource.resId) {
                _hoveredResId = null;
              }
            });
          },
          child: GestureDetector(
            onTap: () {
              // 单击：打开预览或切换选中
              if (_selectedResIds.isNotEmpty || isHovered) {
                if (resource.resId != null) {
                  _toggleSelection(resource.resId!);
                }
              } else {
                _openPreview(globalIndex);
              }
            },
            onDoubleTap: () {
              // 双击：打开全屏查看器
              _openFullScreenViewer(globalIndex);
            },
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: Colors.orange, width: 3)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildThumbnail(resource),
                  ),
                ),
                if (resource.fileType == 'V')
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(resource.duration ?? 0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                if (shouldShowCheckbox)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        if (resource.resId != null) {
                          _toggleSelection(resource.resId!);
                        }
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.orange : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.orange : Colors.grey.shade400,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(ResList resource) {
    if (resource.thumbnailPath == null || resource.thumbnailPath!.isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        child: Center(
          child: Icon(
            resource.fileType == 'V' ? Icons.videocam : Icons.image,
            color: Colors.grey.shade600,
            size: 32,
          ),
        ),
      );
    }

    return Image.network(
      // resource.thumbnailPath!,
      "${AppConfig.minio()}/${resource.thumbnailPath!}",
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey.shade300,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade300,
          child: Center(
            child: Icon(
              resource.fileType == 'V' ? Icons.videocam : Icons.image,
              color: Colors.grey.shade600,
              size: 32,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getSelectedSizeInfo(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '硬盘剩余空间：320GB',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _selectedResIds.isEmpty
                ? null
                : () async {
              final selectedResources = _allResources
                  .where((r) =>
              r.resId != null && _selectedResIds.contains(r.resId))
                  .toList();

              if (selectedResources.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('没有选择要下载的资源')),
                );
                return;
              }

              final downloadPath =
              await AlbumDownloadManager.getDefaultDownloadPath();

              if (!mounted) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => DownloadProgressDialog(
                  resources: selectedResources,
                  savePath: downloadPath,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '下载',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}