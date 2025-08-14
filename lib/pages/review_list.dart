import 'package:flutter/material.dart';
import 'package:qa_imageprocess/model/checkImageListState.dart';
import 'package:qa_imageprocess/model/checkImageList_model.dart';
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
  final int _pageSize = 10;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalTasks = 0;
  
  int _pendingCount = 0;
  int _inProgressCount = 0;
  int _completedCount = 0;
  
  bool _isLoading = false;
  List<CheckimagelistModel> _taskList = [];

  @override
  void initState() {
    super.initState();
    _fetchCheckList();
  }

  Future<void> _fetchCheckList() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('$_baseUrl/api/check/list?page=$_currentPage&pageSize=$_pageSize');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body)['data'];
        final List<dynamic> items = data['data'];
        
        // 更新任务列表
        setState(() {
          _taskList.addAll(items.map((item) => CheckimagelistModel.fromJson(item)).toList());
          _totalPages = data['totalPages'];
          _totalTasks = data['total'];
          
          // 重置状态计数器
          _pendingCount = 0;
          _inProgressCount = 0;
          _completedCount = 0;
          
          // 统计各种状态的数量
          for (var task in _taskList) {
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
      }
    } catch (e) {
      // 错误处理
      print('获取任务列表失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _refreshList() {
    setState(() {
      _currentPage = 1;
      _taskList.clear();
    });
    _fetchCheckList();
  }

  void _loadNextPage() {
    if (_currentPage < _totalPages && !_isLoading) {
      setState(() {
        _currentPage++;
      });
      _fetchCheckList();
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
                      _buildSummaryCard('未检查', '$_pendingCount', Icons.pending_actions),
                      _buildSummaryCard('检查中', '$_inProgressCount', Icons.hourglass_top),
                      _buildSummaryCard('已完成', '$_completedCount', Icons.check_circle),
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
            child: _isLoading && _taskList.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _taskList.isEmpty
                    ? const Center(child: Text('没有质检任务'))
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: _taskList.length + (_isLoading ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _taskList.length) {
                                  return const Center(child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ));
                                }
                                
                                final task = _taskList[index];
                                return _buildCheckListItem(task);
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
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

  Widget _buildCheckListItem(CheckimagelistModel task) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 任务信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '任务 ${task.checkImageListID}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${task.imageCount}张图片'),
                      const SizedBox(width: 16),
                      Text('已检查${task.accessCount}张'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '创建时间: ${task.createdAt.substring(0, 10)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            // 状态和控制按钮
            Column(
              children: [
                // 状态标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Checkimageliststate.getCheckImageListStateColor(task.state)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Checkimageliststate.getCheckImageListStateColor(task.state),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    Checkimageliststate.getCheckImageListState(task.state),
                    style: TextStyle(
                      color: Checkimageliststate.getCheckImageListStateColor(task.state),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // 按钮组
                Row(
                  children: [
                    // 检查按钮（显示在未完成状态）
                    if (task.state != 2)
                      ElevatedButton(
                        onPressed: () => _startChecking(task.checkImageListID),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          task.state == 0 ? '开始检查' : '继续检查',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    
                    // 放弃按钮（显示在检查中状态）
                    if (task.state !=2)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: OutlinedButton(
                          onPressed: () => _abandonTask(task.checkImageListID),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '放弃',
                            style: TextStyle(fontSize: 14, color: Colors.red),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}