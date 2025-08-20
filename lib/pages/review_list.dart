import 'package:flutter/material.dart';
import 'package:qa_imageprocess/model/work_model.dart';
import 'package:qa_imageprocess/user_session.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ReviewList extends StatefulWidget {
  const ReviewList({super.key});

  @override
  State<ReviewList> createState() => _ReviewListState();
}

class _ReviewListState extends State<ReviewList> {
  String _token = UserSession().token ?? '';
  String _baseUrl = UserSession().baseUrl;
  final int _pageSize = 20;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalTasks = 0;

  int _pendingCount = 0;
  int _inProgressCount = 0;
  int _completedCount = 0;

  bool _isLoading = false;
  List<WorkModel> _works = [];

  @override
  void initState() {
    super.initState();
    _fetchWorks();
  }

  Future<void> _fetchWorks() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/api/works/inspection-tasks?page=$_currentPage&pageSize=$_pageSize',
        ),
        headers: {
          'Authorization': 'Bearer ${UserSession().token ?? ''}',
          'Content-Type': 'application/json',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body)['data'];
        final List<dynamic> items = data['works'];
        setState(() {
          // 重置第一页数据，追加后续分页数据
          if (_currentPage == 1) _works.clear();
          _works.addAll(items.map((item) => WorkModel.fromJson(item)).toList());
          _totalPages = data['totalPages'];
          _totalTasks = data['totalItems'];

          // 重置状态计数器
          _pendingCount = 0;
          _inProgressCount = 0;
          _completedCount = 0;

          // 统计各种状态的数量
          for (var task in _works) {
            switch (task.state) {
              case 0:
                _pendingCount++;
                break;
              case 1:
                _inProgressCount++;
                break;
              case 2:
                _completedCount++;
                break;
            }
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('任务加载成功')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('任务加载错误$e')));
    }
  }

  void _refreshList() {
    setState(() {
      _currentPage = 1;
    });
    _fetchWorks();
  }

  // 修复分页参数自增逻辑
  void _loadNextPage() {
    if (_currentPage < _totalPages && !_isLoading) {
      setState(() => _currentPage++);
      _fetchWorks();
    }
  }

  void _startChecking(int taskId) {
    // TODO: 实现开始检查逻辑
    print('开始检查任务：$taskId');
  }

  void _abandonTask(int taskId) {
    // TODO: 实现放弃任务逻辑
    print('放弃任务：$taskId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryCard('总任务数', '$_totalTasks', Icons.list),
                      _buildSummaryCard(
                        '未检查',
                        '$_pendingCount',
                        Icons.pending_actions,
                      ),
                      _buildSummaryCard(
                        '检查中',
                        '$_inProgressCount',
                        Icons.hourglass_top,
                      ),
                      _buildSummaryCard(
                        '已完成',
                        '$_completedCount',
                        Icons.check_circle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => {},
                  tooltip: '拉取新任务',
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: _refreshList,
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新列表',
                ),
              ],
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // 当滚动到底部且非加载中时触发新页加载
                if (notification is ScrollEndNotification &&
                    notification.metrics.extentAfter == 0 &&
                    !_isLoading &&
                    _currentPage < _totalPages) {
                  _loadNextPage();
                }
                return true;
              },
              child: _isLoading && _works.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _works.isEmpty
                  ? const Center(child: Text('没有质检任务'))
                  : ListView.builder(
                      itemCount: _works.length + 1, // +1 用于显示底部加载指示器
                      itemBuilder: (context, index) {
                        // 显示底部分页加载状态
                        if (index == _works.length) {
                          return _buildLoadMoreIndicator();
                        }
                        return _buildWorkItem(_works[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 新增底部加载指示器组件
  Widget _buildLoadMoreIndicator() {
    // 无更多数据时显示提示
    if (_currentPage >= _totalPages) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('没有更多数据')),
      );
    }
    // 加载中显示进度条
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkItem(WorkModel work) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：ID和状态
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '任务 ID: ${work.workID}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusBadge(work.state),
              ],
            ),

            const SizedBox(height: 2),

            // 任务信息 - 改为双列布局
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左列：管理员和类目
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWorkInfoRow('管理员', work.admin.name),
                      _buildWorkInfoRow('类目', work.category),
                    ],
                  ),
                ),

                // 右列：采集类型、问题方向和难度
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildWorkInfoRow('采集类型', work.collectorType),
                      _buildWorkInfoRow('问题方向', work.questionDirection),
                      _buildWorkInfoRow(
                        '难度',
                        WorkModel.getDifficulty(work.difficulty),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 2),
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // if (work.state == 0 || work.state == 1)
                TextButton(
                  onPressed: () => _showReturnDialog(work.workID),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('打回'),
                ),
                const SizedBox(width: 8),
                if (work.state != 3)
                  ElevatedButton(onPressed: () => {}, child: const Text('通过')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () => {}, child: const Text('检查')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 放弃任务确认对话框
  void _showReturnDialog(int workID) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认打回任务'),
          content: const Text('确定要打回这个任务吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('确认打回'),
            ),
          ],
        );
      },
    );
  }

  // 状态标签
  Widget _buildStatusBadge(int state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: WorkModel.getWorkStateColor(state).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WorkModel.getWorkStateColor(state)),
      ),
      child: Text(
        WorkModel.getWorkState(state),
        style: TextStyle(
          color: WorkModel.getWorkStateColor(state),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 任务信息行
  Widget _buildWorkInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
