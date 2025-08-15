import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/model/user.dart';
import 'package:qa_imageprocess/model/work_model.dart';
import 'package:qa_imageprocess/user_session.dart';

class WorkManager extends StatefulWidget {
  const WorkManager({super.key});

  @override
  State<WorkManager> createState() => _WorkManagerState();
}

class _WorkManagerState extends State<WorkManager> {
  // 类目相关状态
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  // 采集类型相关状态
  List<Map<String, dynamic>> _collectorTypes = [];
  String? _selectedCollectorTypeId;

  // 问题方向相关状态
  List<Map<String, dynamic>> _questionDirections = [];
  String? _selectedQuestionDirectionId;

  // 用户相关状态 - 与其他选项隔离
  List<User> _users = [];
  String? _selectedUserId;
  User? _selectedUser;

  // 任务列表相关状态
  List<WorkModel> _works = [];
  bool _isLoading = false;
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalItems = 0;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetchCategories(); // 初始化时获取类目
    _fetchAllUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [_buildTitleSelector(), _buildWorkList()]
      ),
    );
  }

  Widget _buildTitleSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          // 采集类目下拉框
          _buildLevelDropdown(
            value: _selectedCategoryId,
            options: _categories.map((e) => e['id'] as String).toList(),
            hint: '采集类目',
            displayValues: _categories.fold({}, (map, item) {
              map[item['id']] = item['name'];
              return map;
            }),
            onChanged: (newValue) {
              setState(() {
                _selectedCategoryId = newValue;
              });
              _fetchCollectorTypes(newValue);
            },
          ),

          // 采集类型下拉框
          _buildLevelDropdown(
            value: _selectedCollectorTypeId,
            options: _collectorTypes.map((e) => e['id'] as String).toList(),
            hint: '采集类型',
            displayValues: _collectorTypes.fold({}, (map, item) {
              map[item['id']] = item['name'];
              return map;
            }),
            onChanged: (newValue) {
              setState(() {
                _selectedCollectorTypeId = newValue;
              });
              _fetchQuestionDirections(newValue);
            },
            enabled: _selectedCategoryId != null,
          ),

          // 问题方向下拉框
          _buildLevelDropdown(
            value: _selectedQuestionDirectionId,
            options: _questionDirections.map((e) => e['id'] as String).toList(),
            hint: '问题方向',
            displayValues: _questionDirections.fold({}, (map, item) {
              map[item['id']] = item['name'];
              return map;
            }),
            onChanged: (newValue) {
              setState(() {
                _selectedQuestionDirectionId = newValue;
              });
            },
            enabled: _selectedCollectorTypeId != null,
          ),

          // 用户下拉框
          _buildUserDropdown(),
          _buildSearchButton(),
        ],
      ),
    );
  }

  // 专门为用户下拉框创建的组件 - 添加空选项
  Widget _buildUserDropdown() {
    // 修复：直接构建菜单项列表
    final items = [
      // 添加空选项
      DropdownMenuItem<String?>(
        value: null,
        child: Text('未选择', style: TextStyle(color: Colors.grey)),
      ),
      // 添加其他用户选项
      ..._users.map((user) {
        return DropdownMenuItem<String?>(
          value: user.userID.toString(),
          child: Text(user.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    ];

    return Container(
      width: 180,
      child: DropdownButtonFormField<String?>(
        value: _selectedUserId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: '分配用户',
          border: OutlineInputBorder(),
        ),
        items: items,
        onChanged: (newValue) {
          setState(() {
            _selectedUserId = newValue;
            if (newValue != null) {
              _selectedUser = _users.firstWhere(
                (user) => user.userID.toString() == newValue,
                orElse: () => User(
                  userID: -1,
                  name: '未知用户',
                  email: '',
                  role: 0,
                  state: 0,
                ),
              );
            } else {
              _selectedUser = null; // 清空选择
            }
          });
        },
      ),
    );
  }

  // 修复普通下拉框 - 显式使用 String?
  Widget _buildLevelDropdown({
    required String? value,
    required List<String> options,
    required String hint,
    required Map<String, String> displayValues,
    bool enabled = true,
    ValueChanged<String?>? onChanged,
  }) {
    // 修复：直接构建菜单项列表
    final items = [
      // 添加空选项
      DropdownMenuItem<String?>(
        value: null,
        child: Text('未选择', style: TextStyle(color: Colors.grey)),
      ),
      // 添加其他选项
      ...options.map((id) {
        return DropdownMenuItem<String?>(
          value: id,
          child: Text(
            displayValues[id] ?? '未知',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    ];

    return Container(
      width: 180,
      child: DropdownButtonFormField<String?>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: hint,
          border: const OutlineInputBorder(),
          enabled: enabled,
        ),
        items: items,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  // 查询按钮
  Widget _buildSearchButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ElevatedButton(
        onPressed: _fetchWorks,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          // minimumSize: const Size(double.infinity, 50),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('查询任务', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  // 查询任务列表
  Future<void> _fetchWorks() async {
    setState(() => _isLoading = true);

    try {
      // 构建查询参数
      final Map<String, String> queryParams = {
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString(),
      };

      // 添加可选参数
      if (_selectedCategoryId != null) {
        final category = _categories.firstWhere(
          (c) => c['id'] == _selectedCategoryId,
          orElse: () => {'name': ''},
        );
        queryParams['category'] = category['name'];
      }

      if (_selectedCollectorTypeId != null) {
        final collectorType = _collectorTypes.firstWhere(
          (c) => c['id'] == _selectedCollectorTypeId,
          orElse: () => {'name': ''},
        );
        queryParams['collector_type'] = collectorType['name'];
      }

      if (_selectedQuestionDirectionId != null) {
        final questionDirection = _questionDirections.firstWhere(
          (q) => q['id'] == _selectedQuestionDirectionId,
          orElse: () => {'name': ''},
        );
        queryParams['question_direction'] = questionDirection['name'];
      }

      if (_selectedUserId != null) {
        queryParams['userID'] = _selectedUserId!;
      }

      // 构建URL
      final uri = Uri.parse(
        '${UserSession().baseUrl}/api/works/admin/user-works',
      ).replace(queryParameters: queryParams);

      // 发送请求
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${UserSession().token ?? ''}'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final worksData = data['data']['works'] as List? ?? [];
        final pagination =
            data['data']['pagination'] as Map<String, dynamic>? ?? {};

        setState(() {
          _works = worksData.map<WorkModel>((work) {
            return WorkModel.fromJson(work as Map<String, dynamic>);
          }).toList();

          // 安全处理可能为 null 的值
          _currentPage = (pagination['currentPage'] as int?) ?? _currentPage;
          _pageSize = (pagination['pageSize'] as int?) ?? _pageSize;
          _totalItems = (pagination['totalItems'] as int?) ?? _totalItems;
          _totalPages = (pagination['totalPages'] as int?) ?? _totalPages;
        });
      } else {
        throw Exception('Failed to load works: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching works: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载任务失败: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 任务列表
  Widget _buildWorkList() {
    if (_works.isEmpty && !_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('暂无任务数据', style: TextStyle(fontSize: 16)),
      );
    }

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _works.length,
          itemBuilder: (context, index) {
            final work = _works[index];
            return _buildWorkItem(work);
          },
        ),
        _buildPaginationControls(),
      ],
    );
  }

  // 单个任务项
  Widget _buildWorkItem(WorkModel work) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // 左侧信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '任务ID: ${work.workID}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('管理员: ${work.admin.name}'),
                  const SizedBox(height: 4),
                  Text('工作人员: ${work.worker.name}'),
                  const SizedBox(height: 4),
                  Text('目标数量: ${work.targetCount}'),
                  const SizedBox(height: 4),
                  Text('当前数量: ${work.currentCount}'),
                ],
              ),
            ),

            // 右侧状态和按钮
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 状态标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: WorkModel.getWorkStateColor(
                      work.state,
                    ).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: WorkModel.getWorkStateColor(work.state),
                    ),
                  ),
                  child: Text(
                    WorkModel.getWorkState(work.state),
                    style: TextStyle(
                      color: WorkModel.getWorkStateColor(work.state),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 查看按钮
                ElevatedButton(
                  onPressed: () => _viewWorkDetails(work),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue,
                  ),
                  child: const Text('查看详情'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewWorkDetails(WorkModel work) {
    // 这里可以跳转到任务详情页面
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('任务详情 - ${work.workID}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('管理员: ${work.admin.name}'),
              Text('工作人员: ${work.worker.name}'),
              Text('类目: ${work.category}'),
              Text('采集类型: ${work.collectorType}'),
              Text('问题方向: ${work.questionDirection}'),
              Text('难度: ${work.difficulty}'),
              Text('目标数量: ${work.targetCount}'),
              Text('当前数量: ${work.currentCount}'),
              Text('状态: ${WorkModel.getWorkState(work.state)}'),
              if (work.returnReason != null) Text('退回原因: ${work.returnReason}'),
              if (work.remark != null) Text('备注: ${work.remark}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 分页控件
  Widget _buildPaginationControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _fetchWorks();
                  }
                : null,
          ),
          Text('第 $_currentPage 页 / 共 $_totalPages 页'),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() => _currentPage++);
                    _fetchWorks();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  // 通用API请求方法
  Future<List<dynamic>> _fetchData(String endpoint) async {
    final response = await http.get(
      Uri.parse('${UserSession().baseUrl}$endpoint'),
      headers: {'Authorization': 'Bearer ${UserSession().token ?? ''}'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as List<dynamic>;
    } else {
      throw Exception('Failed to load data from $endpoint');
    }
  }

  // 获取所有用户信息的方法
  Future<void> _fetchAllUsers() async {
    try {
      final allUsers = await _fetchData('/api/user/all');
      setState(() {
        _users = (allUsers).map<User>((item) {
          return User.fromJson(item as Map<String, dynamic>);
        }).toList();
      });
    } catch (e) {
      print('Error fetching users: $e');
      setState(() {
        _users = [];
      });
    }
  }

  // 获取所有类目
  Future<void> _fetchCategories() async {
    try {
      final categories = await _fetchData('/api/category/');
      setState(() {
        _categories = categories.map<Map<String, dynamic>>((item) {
          return {
            'id': item['categoryID'].toString(),
            'name': item['categoryName'],
          };
        }).toList();
      });
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  // 根据类目ID获取采集类型 - 不清除用户选择
  Future<void> _fetchCollectorTypes(String? categoryId) async {
    if (categoryId == null) {
      setState(() {
        _collectorTypes = [];
        _selectedCollectorTypeId = null;
        _questionDirections = [];
        _selectedQuestionDirectionId = null;
        // 不再清除用户选择 - 保持独立
      });
      return;
    }

    try {
      final collectorTypes = await _fetchData(
        '/api/category/$categoryId/collector-types',
      );
      setState(() {
        _collectorTypes = collectorTypes.map<Map<String, dynamic>>((item) {
          return {
            'id': item['collectorTypeID'].toString(),
            'name': item['collectorTypeName'],
          };
        }).toList();
        _selectedCollectorTypeId = null;
        _questionDirections = [];
        _selectedQuestionDirectionId = null;
        // 不再清除用户选择 - 保持独立
      });
    } catch (e) {
      print('Error fetching collector types: $e');
    }
  }

  // 根据采集类型ID获取问题方向
  Future<void> _fetchQuestionDirections(String? collectorTypeId) async {
    if (collectorTypeId == null) {
      setState(() {
        _questionDirections = [];
        _selectedQuestionDirectionId = null;
      });
      return;
    }

    try {
      final questionDirections = await _fetchData(
        '/api/category/collector-types/$collectorTypeId/question-directions',
      );
      setState(() {
        _questionDirections = questionDirections.map<Map<String, dynamic>>((
          item,
        ) {
          return {
            'id': item['questionDirectionID'].toString(),
            'name': item['questionDirectionName'],
          };
        }).toList();
        _selectedQuestionDirectionId = null;
      });
    } catch (e) {
      print('Error fetching question directions: $e');
    }
  }
}
