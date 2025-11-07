// pages/album_library_page.dart
import 'package:flutter/material.dart';
import '../widgets/side_navigation.dart';
import '../widgets/custom_title_bar.dart';
import '../user/models/group.dart';

class AlbumLibraryPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomTitleBar(
        backgroundColor: Color(0xFFF5E8DC),
        rightTitleBgColor: Colors.white,
        showToolbar: false,
        child: Row(
          children: [
            SideNavigation(
              selectedIndex: selectedNavIndex,
              onNavigationChanged: onNavigationChanged,
              groups: groups,
              selectedGroup: selectedGroup,
              onGroupSelected: onGroupSelected,
              currentUserId: currentUserId,
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_outlined,
                        size: 120,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '相册图库',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '功能开发中...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}