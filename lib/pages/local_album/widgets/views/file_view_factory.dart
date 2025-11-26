// widgets/views/file_view_factory.dart
import 'package:flutter/material.dart';
import '../../../../models/file_item.dart';

/// 视图模式枚举
enum ViewMode {
  grid,       // 网格视图
  list,       // 列表视图
  equalHeight // 等高视图
}

/// 文件项目回调
class FileItemCallbacks {
  final Function(int index) onTap;
  final Function(int index) onDoubleTap;
  final Function(int index) onLongPress;
  final Function(int index) onCheckboxToggle;

  const FileItemCallbacks({
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onCheckboxToggle,
  });
}

/// 文件视图配置
class FileViewConfig {
  final List<FileItem> items;
  final Set<int> selectedIndices;
  final bool isSelectionMode;
  final FileItemCallbacks callbacks;
  final EdgeInsets padding;

  const FileViewConfig({
    required this.items,
    required this.selectedIndices,
    required this.isSelectionMode,
    required this.callbacks,
    this.padding = const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
  });

  /// 是否选中指定索引
  bool isSelected(int index) => selectedIndices.contains(index);

  /// 是否显示复选框
  bool showCheckbox(int index) => isSelectionMode || selectedIndices.contains(index);
}

/// 文件视图构建器接口
abstract class FileViewBuilder {
  Widget build(BuildContext context, FileViewConfig config);
}

/// 文件视图工厂
class FileViewFactory {
  static final Map<ViewMode, FileViewBuilder> _builders = {};

  /// 注册视图构建器
  static void register(ViewMode mode, FileViewBuilder builder) {
    _builders[mode] = builder;
  }

  /// 获取视图构建器
  static FileViewBuilder? getBuilder(ViewMode mode) {
    return _builders[mode];
  }

  /// 构建视图
  static Widget build(
      BuildContext context,
      ViewMode mode,
      FileViewConfig config,
      ) {
    final builder = _builders[mode];
    if (builder != null) {
      return builder.build(context, config);
    }

    // 默认返回空提示
    return const Center(
      child: Text('未注册的视图模式'),
    );
  }

  /// 检查是否已注册
  static bool hasBuilder(ViewMode mode) {
    return _builders.containsKey(mode);
  }
}

/// 空状态组件
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyStateWidget({
    super.key,
    this.message = '此文件夹为空',
    this.icon = Icons.folder_open,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}