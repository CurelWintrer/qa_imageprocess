import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/model/user.dart';
import 'package:qa_imageprocess/tools/export_service.dart';
import 'package:qa_imageprocess/user_session.dart';

class Allimage extends StatefulWidget {
  const Allimage({super.key});

  @override
  State<Allimage> createState() => _AllimageState();
}

class _AllimageState extends State<Allimage> {
  // 类目相关状态
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  // 采集类型相关状态
  List<Map<String, dynamic>> _collectorTypes = [];
  String? _selectedCollectorTypeId;

  // 问题方向相关状态
  List<Map<String, dynamic>> _questionDirections = [];
  String? _selectedQuestionDirectionId;

  //难度选择状态
  int? _selectedDifficulty;

  int _currentPage = 1;
  int _pageSize = 30;
  bool _isLoading = false;
  bool _hasMore = true;
  int _columnCount = 4; // 默认4列

  List<ImageModel> _images = [];

  String _errorMessage = '';
  // 添加滚动控制器
  final ScrollController _scrollController = ScrollController();
  int _selectedImageId = 0; // 选中的图片ID

  late ExportService exportService;
  bool isExporting = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _fetchCategories(); // 初始化时获取类目
    // 添加滚动监听
    _scrollController.addListener(_scrollListener);
    
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 滚动监听函数
  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadNextPage();
      }
    }
  }

  // 加载下一页
  void _loadNextPage() {
    setState(() {
      _currentPage++;
      _isLoading = true;
    });
    _fetchImages();
  }

  // 悬浮按钮列数切换
  void _toggleColumnCount() {
    setState(() {
      _columnCount = _columnCount >= 7 ? 4 : _columnCount + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTitleSelector(),
          // 添加网格视图展示图片
          if (isExporting) ...[
              ValueListenableBuilder<double>(
                valueListenable: exportService.progress,
                builder: (context, progress, _) {
                  return LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey[300],
                  );
                },
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<String>(
                valueListenable: exportService.status,
                builder: (context, status, _) {
                  return Text(
                    status,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 30),
              OutlinedButton(
                onPressed: () {
                  setState(() => isExporting = false);
                  Navigator.pop(context);
                },
                child: const Text('取消导出'),
              )
            ],
          Expanded(
            child: _images.isEmpty && !_isLoading
                ? Center(
                    child: Text(_errorMessage.isEmpty ? '暂无数据' : _errorMessage),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      // 防止在加载过程中重复触发
                      if (!_isLoading &&
                          _hasMore &&
                          scrollNotification.metrics.pixels >=
                              scrollNotification.metrics.maxScrollExtent -
                                  200) {
                        _loadNextPage();
                      }
                      return true;
                    },
                    child: GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8.0),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _columnCount,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: _images.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _images.length) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return _buildGridItem(_images[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: _toggleColumnCount,
        tooltip: '切换列数 ($_columnCount)',
        child: Text('$_columnCount列'),
      ),
    );
  }

  void _handleSearch() {
    setState(() {
      _currentPage = 1;
      _images = [];
      _hasMore = true;
      _isLoading = true; // 显式设置加载状态
    });
    // 确保异步操作不会阻塞UI
    Future.microtask(() => _fetchImages());
  }

  Future<void> _fetchImages() async {
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
    if(_selectedDifficulty!=null){
      queryParams['difficulty'] = _selectedDifficulty.toString();
    }

    // 构建URL
    final uri = Uri.parse(
      '${UserSession().baseUrl}/api/image',
    ).replace(queryParameters: queryParams);

    try {
      // 发送请求
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${UserSession().token ?? ''}'},
      );
      // print(response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pagination = data['data'];
        final imageData = pagination['data'] as List;
        final totalPages = pagination['totalPages'];

        setState(() {
          _isLoading = false;

          if (_currentPage == 1) {
            _images = imageData.map((img) => ImageModel.fromJson(img)).toList();
          } else {
            _images.addAll(imageData.map((img) => ImageModel.fromJson(img)));
          }

          // 更新是否有更多数据的标志
          _hasMore = _currentPage < totalPages;
          _errorMessage = '';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('网络错误图片查询失败${response.statusCode}')),
        );
        _isLoading = false;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片查询失败$e')));
      _isLoading = false;
    }
  }

  Widget _buildTitleSelector() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 800;

          final children = [
            _buildCategoryDropdown(),
            _buildCollectorTypeDropdown(),
            _buildQuestionDirectionDropdown(),
            _buildDifficultyDropdown(),
            SizedBox(
              width: 60,
              height: 50,
              child: ElevatedButton(
                onPressed: () => {_handleSearch()},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('查询', style: TextStyle(fontSize: 16)),
              ),
            ),
            SizedBox(
              width: 60,
              height: 50,
              child: ElevatedButton(
                onPressed: () => {_startExport()},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('导出', style: TextStyle(fontSize: 16)),
              ),
            ),
          ];

          if (isWideScreen) {
            return Row(
              children: children
                  .map(
                    (child) => Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: child,
                      ),
                    ),
                  )
                  .toList(),
            );
          } else {
            return Wrap(spacing: 16, runSpacing: 16, children: children);
          }
        },
      ),
    );
  }

  void _startExport() async {
    var ExportCategory='';
    if (_selectedCategoryId != null) {
      final category = _categories.firstWhere(
        (c) => c['id'] == _selectedCategoryId,
        orElse: () => {'name': ''},
      );
      ExportCategory = category['name'];
    }
    exportService=ExportService(context: context, category: ExportCategory);
    setState(() => isExporting = true);
    
    try {
      await exportService.exportImages();
      // 成功后可选：显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片导出成功!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    } finally {
      setState(() => isExporting = false);
    }
  }

  Widget _buildGridItem(ImageModel image) {
    final firstQuestion = image.questions?.isNotEmpty == true
        ? image.questions?.first
        : null;

    return GestureDetector(
      onLongPress: () => {},
      onTap: () {
        setState(() {
          _selectedImageId = image.imageID;
        });
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片区域
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 图片显示
                    image.path?.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: '${UserSession().baseUrl}/${image.path}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Center(child: Icon(Icons.error)),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.image_not_supported),
                            ),
                          ),

                    // 图片状态标签（悬浮在右上角）
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildImageStatusBadge(image.state),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // 图片信息
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      '#${image.imageID}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Spacer(),
                  //快捷AI更新QA按钮
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: IconButton(
                      onPressed: () => {},
                      icon: Icon(Icons.auto_awesome),
                      iconSize: 20,
                      tooltip: 'AI-QA',
                    ),
                  ),
                ],
              ),

              // 问题摘要（显示第一个问题）
              if (firstQuestion != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 问题文本
                      Text(
                        firstQuestion.questionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),

                      const SizedBox(height: 6),

                      // 答案选项显示
                      _buildAnswerIndicators(firstQuestion),
                    ],
                  ),
                ),
              ],
              Text('${image.category}'),
            ],
          ),
        ],
      ),
    );
  }

  // 图片状态标签
  Widget _buildImageStatusBadge(int state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ImageState.getStateColor(state).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ImageState.getStateColor(state)),
      ),
      child: Text(
        ImageState.getStateText(state),
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 答案选项指示器
  Widget _buildAnswerIndicators(QuestionModel question) {
    // 找到正确答案
    final rightAnswerId = question.rightAnswer.answerID;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: question.answers.asMap().entries.map((entry) {
        final index = entry.key;
        final answer = entry.value;
        final isCorrect = answer.answerID == rightAnswerId;
        final letter = String.fromCharCode(65 + index); // A, B, C...

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isCorrect ? Colors.green[100] : Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isCorrect
                  ? Colors.green
                  : Colors.grey.shade300, // 使用 .shade 确保非空
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$letter.',
                style: TextStyle(
                  color: isCorrect ? Colors.green : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                answer.answerText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isCorrect ? Colors.green : Colors.black,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDifficultyDropdown() {
    final Map<int, String> difficultyOptions = {0: "简单", 1: "中等", 2: "困难"};

    return _buildIntLevelDropdown(
      // 使用新的整数版本组件
      value: _selectedDifficulty,
      options: difficultyOptions.keys.toList(),
      hint: '难度',
      displayValues: difficultyOptions,
      onChanged: (newValue) {
        setState(() {
          _selectedDifficulty = newValue;
        });
      },
    );
  }

  // 专门处理 int 类型的下拉框
  Widget _buildIntLevelDropdown({
    required int? value,
    required List<int> options,
    required String hint,
    required Map<int, String> displayValues,
    bool enabled = true,
    ValueChanged<int?>? onChanged,
  }) {
    // 构建菜单项
    final items = [
      DropdownMenuItem<int?>(
        value: null,
        child: Text('未选择', style: TextStyle(color: Colors.grey)),
      ),
      ...options.map((id) {
        return DropdownMenuItem<int?>(
          value: id,
          child: Text(
            displayValues[id] ?? '未知',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    ];

    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<int?>(
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

  Widget _buildCategoryDropdown() {
    return _buildLevelDropdown(
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
    );
  }

  Widget _buildCollectorTypeDropdown() {
    return _buildLevelDropdown(
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
    );
  }

  Widget _buildQuestionDirectionDropdown() {
    return _buildLevelDropdown(
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
    );
  }

  // 普通下拉框 - 显式使用 String?
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

    return SizedBox(
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
