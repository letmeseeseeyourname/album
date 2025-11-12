// pages/folder_detail/folder_detail_state.dart

part of '../folder_detail_page_backup.dart';

/// 文件夹详情页面的状态管理类
/// 提供更好的状态封装和管理
class FolderDetailState {
  // 文件列表状态
  final List<FileItem> fileItems;
  final bool isLoading;
  final String? errorMessage;

  // 路径导航状态
  final List<String> pathSegments;
  final List<String> pathHistory;
  final String currentPath;

  // 选择状态
  final Set<int> selectedIndices;
  final bool isSelectionMode;

  // 视图和过滤状态
  final String filterType;
  final bool isFilterMenuOpen;
  final bool isGridView;

  // 上传状态
  final bool isUploading;
  final LocalUploadProgress? uploadProgress;

  // 预览状态
  final bool showPreview;
  final int previewIndex;
  final List<FileItem> mediaItems;

  const FolderDetailState({
    this.fileItems = const [],
    this.isLoading = false,
    this.errorMessage,
    this.pathSegments = const [],
    this.pathHistory = const [],
    this.currentPath = '',
    this.selectedIndices = const {},
    this.isSelectionMode = false,
    this.filterType = 'all',
    this.isFilterMenuOpen = false,
    this.isGridView = true,
    this.isUploading = false,
    this.uploadProgress,
    this.showPreview = false,
    this.previewIndex = -1,
    this.mediaItems = const [],
  });

  /// 创建状态的副本并更新指定字段
  FolderDetailState copyWith({
    List<FileItem>? fileItems,
    bool? isLoading,
    String? errorMessage,
    List<String>? pathSegments,
    List<String>? pathHistory,
    String? currentPath,
    Set<int>? selectedIndices,
    bool? isSelectionMode,
    String? filterType,
    bool? isFilterMenuOpen,
    bool? isGridView,
    bool? isUploading,
    LocalUploadProgress? uploadProgress,
    bool? showPreview,
    int? previewIndex,
    List<FileItem>? mediaItems,
  }) {
    return FolderDetailState(
      fileItems: fileItems ?? this.fileItems,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      pathSegments: pathSegments ?? this.pathSegments,
      pathHistory: pathHistory ?? this.pathHistory,
      currentPath: currentPath ?? this.currentPath,
      selectedIndices: selectedIndices ?? this.selectedIndices,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      filterType: filterType ?? this.filterType,
      isFilterMenuOpen: isFilterMenuOpen ?? this.isFilterMenuOpen,
      isGridView: isGridView ?? this.isGridView,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      showPreview: showPreview ?? this.showPreview,
      previewIndex: previewIndex ?? this.previewIndex,
      mediaItems: mediaItems ?? this.mediaItems,
    );
  }

  /// 检查是否有选中的项目
  bool get hasSelection => selectedIndices.isNotEmpty;

  /// 获取选中的文件项
  List<FileItem> get selectedItems {
    return selectedIndices
        .where((index) => index >= 0 && index < fileItems.length)
        .map((index) => fileItems[index])
        .toList();
  }

  /// 获取过滤后的文件列表
  List<FileItem> get filteredFiles {
    switch (filterType) {
      case 'image':
        return fileItems.where((item) => item.type == FileItemType.image).toList();
      case 'video':
        return fileItems.where((item) => item.type == FileItemType.video).toList();
      default:
        return fileItems;
    }
  }

  /// 计算选中文件的统计信息
  FileStatistics get selectedStatistics {
    double totalSize = 0;
    int imageCount = 0;
    int videoCount = 0;
    int folderCount = 0;

    for (int index in selectedIndices) {
      if (index >= 0 && index < fileItems.length) {
        final item = fileItems[index];
        totalSize += item.size;

        switch (item.type) {
          case FileItemType.image:
            imageCount++;
            break;
          case FileItemType.video:
            videoCount++;
            break;
          case FileItemType.folder:
            folderCount++;
            break;
        }
      }
    }

    return FileStatistics(
      totalSize: totalSize,
      imageCount: imageCount,
      videoCount: videoCount,
      folderCount: folderCount,
    );
  }
}

/// 文件统计信息
class FileStatistics {
  final double totalSize;
  final int imageCount;
  final int videoCount;
  final int folderCount;

  const FileStatistics({
    required this.totalSize,
    required this.imageCount,
    required this.videoCount,
    required this.folderCount,
  });

  /// 获取格式化的总大小
  String get formattedTotalSize {
    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;

    if (totalSize >= gb) {
      return '${(totalSize / gb).toStringAsFixed(2)} GB';
    } else if (totalSize >= mb) {
      return '${(totalSize / mb).toStringAsFixed(2)} MB';
    } else if (totalSize >= kb) {
      return '${(totalSize / kb).toStringAsFixed(2)} KB';
    } else {
      return '$totalSize B';
    }
  }

  /// 获取总文件数
  int get totalCount => imageCount + videoCount + folderCount;

  /// 获取媒体文件数（不包括文件夹）
  int get mediaCount => imageCount + videoCount;

  /// 生成描述文本
  String get description {
    final parts = <String>[];

    if (imageCount > 0) {
      parts.add('$imageCount张照片');
    }
    if (videoCount > 0) {
      parts.add('$videoCount条视频');
    }
    if (folderCount > 0) {
      parts.add('$folderCount个文件夹');
    }

    if (parts.isEmpty) {
      return '无选中项';
    }

    return parts.join(' · ');
  }
}

/// 文件夹详情页面的事件枚举
enum FolderDetailEvent {
  loadFiles,
  navigateToFolder,
  navigateBack,
  selectItem,
  selectAll,
  clearSelection,
  toggleView,
  changeFilter,
  openPreview,
  closePreview,
  startUpload,
  cancelUpload,
  refresh,
}

/// 文件夹详情页面的动作类
abstract class FolderDetailAction {
  const FolderDetailAction();
}

/// 加载文件动作
class LoadFilesAction extends FolderDetailAction {
  final String path;

  const LoadFilesAction(this.path);
}

/// 导航到文件夹动作
class NavigateToFolderAction extends FolderDetailAction {
  final String path;
  final String name;

  const NavigateToFolderAction(this.path, this.name);
}

/// 选择项目动作
class SelectItemAction extends FolderDetailAction {
  final int index;
  final bool isMultiSelect;

  const SelectItemAction(this.index, {this.isMultiSelect = false});
}

/// 改变过滤器动作
class ChangeFilterAction extends FolderDetailAction {
  final String filterType;

  const ChangeFilterAction(this.filterType);
}

/// 开始上传动作
class StartUploadAction extends FolderDetailAction {
  final List<FileItem> items;

  const StartUploadAction(this.items);
}

/// 文件排序选项
enum FileSortOption {
  name('名称'),
  size('大小'),
  type('类型'),
  date('日期');

  final String label;
  const FileSortOption(this.label);
}

/// 文件排序配置
class FileSortConfig {
  final FileSortOption option;
  final bool ascending;

  const FileSortConfig({
    this.option = FileSortOption.name,
    this.ascending = true,
  });

  FileSortConfig copyWith({
    FileSortOption? option,
    bool? ascending,
  }) {
    return FileSortConfig(
      option: option ?? this.option,
      ascending: ascending ?? this.ascending,
    );
  }

  /// 对文件列表进行排序
  List<FileItem> sortFiles(List<FileItem> files) {
    final sorted = List<FileItem>.from(files);

    sorted.sort((a, b) {
      // 文件夹总是优先
      if (a.type == FileItemType.folder && b.type != FileItemType.folder) {
        return -1;
      }
      if (a.type != FileItemType.folder && b.type == FileItemType.folder) {
        return 1;
      }

      // 根据选项排序
      int result;
      switch (option) {
        case FileSortOption.name:
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case FileSortOption.size:
          result = a.size.compareTo(b.size);
          break;
        case FileSortOption.type:
          result = a.type.index.compareTo(b.type.index);
          break;
        case FileSortOption.date:
        // 如果有修改日期，可以在这里比较
          result = 0;
          break;
      }

      return ascending ? result : -result;
    });

    return sorted;
  }
}