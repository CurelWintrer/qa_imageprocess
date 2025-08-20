// 添加必要的导入
import 'package:flutter/material.dart';
import 'package:qa_imageprocess/navi/app_navigation_drawer.dart';
import 'package:qa_imageprocess/pages/export.dart';
import 'package:qa_imageprocess/pages/management_page.dart';
import 'package:qa_imageprocess/pages/review_list.dart';
import 'package:qa_imageprocess/pages/work.dart';
import 'package:qa_imageprocess/pages/work_list.dart';
import 'package:qa_imageprocess/pages/work_manager.dart';
import 'package:qa_imageprocess/user_session.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin,AutomaticKeepAliveClientMixin{
    // 自动保存状态
  @override
  bool get wantKeepAlive => true;

  int _selectedIndex = 0;

    // 使用PageStorageKey为每个页面保存独立状态
  final List<PageStorageKey> _pageKeys = [
    PageStorageKey('page0'),
    PageStorageKey('page1'),
    PageStorageKey('page2'),
    PageStorageKey('page3'),
    PageStorageKey('page4'),
    PageStorageKey('page5'),
    PageStorageKey('page6'),
    PageStorageKey('page7')
  ];

  // 用户信息
  Map<String, dynamic> _userInfo = {
    'name': '加载中...',
    'email': '加载中...',
    'avatar': Icons.person,
    'role': '',
    'joinDate': '',
  };

  late List<String> _pageTitles;
  late List<Widget> _pages;
  bool _isLoading = true; // 添加加载状态

  @override
  void initState() {
    super.initState();
    // 初始化用户信息和页面列表
    _pageTitles=[];
    _pages=[];
    _initializeUserInfo();
  }

  // 初始化用户信息
  void _initializeUserInfo() async {
    try {
      final userSession = UserSession();
      // 确保加载完成
      await userSession.loadFromPrefs();

      // 从UserSession获取用户角色
      final role = userSession.role;
      final name = userSession.name;
      final email = userSession.email;

      // 添加日志输出，帮助调试角色问题
      print('token=${userSession.token}');

      // 更新用户信息
      setState(() {
        _userInfo = {
          'name': name ?? '未知',
          'email': email ?? '未知',
          'avatar': Icons.person,
          'role': role == 1 ? '管理员' : '普通用户', // 根据数字显示角色名称
          'joinDate': '2024-01-01',
        };
      });

      // 初始化页面列表 - 使用数字角色判断
      bool isAdmin = role == 1;
      _initializePages(isAdmin);
    } catch (e) {
      _showMessage('初始化用户信息失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 根据用户角色初始化页面列表
  void _initializePages(bool isAdmin) {
    // 创建页面实例 - 使用GlobalKey保存状态
    final basePages = [
      {'title': 'Work', 'page':WorkList(key: _pageKeys[0],)},
      {'title':'质检','page':ReviewList(key: _pageKeys[1])}
    ];

    // 只有管理员才添加管理页面
    if (isAdmin) {
      basePages.add({'title': '账号管理', 'page': ManagementPage(key: _pageKeys[2])});
      basePages.add({'title':'任务管理','page':WorkManager(key: _pageKeys[3])});
      basePages.add({'title':'导出','page':Export(key: _pageKeys[4],)});
    }

    // 更新页面和标题列表
    setState(() {
      _pageTitles = basePages.map((item) => item['title'] as String).toList();
      _pages = basePages.map((item) => item['page'] as Widget).toList();
    });
  }

  /// 显示消息提示
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggleUserMenu() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showMessage('未登录');
      return;
    }

    try {
      // 刷新并获取当前用户信息
      final response = await http.post(
        Uri.parse('${UserSession().baseUrl}/api/user/refresh-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> user = jsonDecode(response.body)['user'];

        showDialog(
          context: context,
          builder: (context) {
            bool showReset = false;
            String currentPwd = '';
            String newPwd = '';

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('我的用户信息'),
                  content: SizedBox(
                    width: double.minPositive,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 用户基本信息
                        ListTile(
                          leading: const Icon(Icons.account_circle),
                          title: Text(user['name'] ?? '未知'),
                          subtitle: Text(
                            '${user['email']} · 角色: ${user['role']}',
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 初始只显示“重置密码”按钮
                        if (!showReset)
                          ElevatedButton(
                            onPressed: () => setState(() => showReset = true),
                            child: const Text('重置密码'),
                          ),
                        // 展开密码重置表单
                        if (showReset) ...[
                          TextField(
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: '当前密码',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => currentPwd = value,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: '新密码',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => newPwd = value,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final token = prefs.getString('token');
                              if (token == null) {
                                _showMessage('未登录');
                                return;
                              }
                              try {
                                final resp = await http.post(
                                  Uri.parse(
                                    '${UserSession().baseUrl}/api/user/reset-password',
                                  ),
                                  headers: {
                                    'Authorization': 'Bearer $token',
                                    'Content-Type': 'application/json',
                                  },
                                  body: jsonEncode({
                                    'currentPassword': currentPwd,
                                    'newPassword': newPwd,
                                  }),
                                );
                                if (resp.statusCode == 200) {
                                  _showMessage('密码重置成功');
                                  Navigator.of(context).pop();
                                } else {
                                  _showMessage('重置失败：${resp.statusCode}');
                                }
                              } catch (e) {
                                _showMessage('网络错误：$e');
                              }
                            },
                            child: const Text('提交'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('关闭'),
                    ),
                  ],
                );
              },
            );
          },
        );
      } else {
        _showMessage('获取用户信息失败: ${response.statusCode}');
      }
    } catch (e) {
      _showMessage('网络错误：$e');
    }
  }

  void _toggleSettings() {
    Navigator.pushNamed(context, '/systemSet');
  }

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    // 退出后导航到登录页面
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Row(
        children: [
          // 使用新的导航栏组件
          AppNavigationDrawer(
            userInfo: _userInfo,
            pageTitles: _pageTitles,
            selectedIndex: _selectedIndex,
            onItemSelected: (index) => setState(() => _selectedIndex = index),
            onToggleUserMenu: _toggleUserMenu,
            onToggleSettings: _toggleSettings,
            onLogout: logout,
            getIconForIndex: _getIconForIndex,
          ),

          // 右侧内容区域保持不变
          Expanded(
            child: Column(
              children: [
                // Container(
                //   height: 56,
                //   color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                //   alignment: Alignment.centerLeft,
                //   padding: const EdgeInsets.symmetric(horizontal: 20),
                //   child: Text(
                //     _pageTitles[_selectedIndex],
                //     style: Theme.of(context).textTheme.titleLarge,
                //   ),
                // ),
                // const Divider(height: 1),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _pages,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 根据索引获取对应的图标
  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.work;
      case 1:
        return Icons.search;
      case 2:
        return Icons.title;
      case 3:
        return Icons.image;
      case 4:
        return Icons.image_outlined;
      case 5:
        return Icons.download;
      case 6:
        return Icons.commit;
      case 7:
        return Icons.admin_panel_settings;
      default:
        return Icons.question_mark;
    }
  }
}
