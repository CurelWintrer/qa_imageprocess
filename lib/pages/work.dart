import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/MyWidget/image_detail.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/user_session.dart';

class Work extends StatefulWidget {
  const Work({super.key});

  @override
  State<Work> createState() => _WorkState();
}

class _WorkState extends State<Work> {
  // 类目相关状态
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  // 采集类型相关状态
  List<Map<String, dynamic>> _collectorTypes = [];
  String? _selectedCollectorTypeId;

  // 问题方向相关状态
  List<Map<String, dynamic>> _questionDirections = [];
  String? _selectedQuestionDirectionId;

  // 添加必要的状态变量
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalItems = 0;
  List<ImageModel> _images = [];
  bool _isLoading = false;

  ImageModel? _selectedImage;

  @override
  void initState() {
    super.initState();
    _fetchCategories(); // 初始化时获取类目
  }

  // 新增: 显示图片详情弹窗的方法
  void _showImageDetailDialog(ImageModel image) {
    setState(() {
      _selectedImage = image;
    });
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ImageDetail(
        image: image,
        onImageUpdated: (updatedImage) {
          // 更新图片列表中的数据
          _updateImageInList(updatedImage);
        },
        onLongRunningTask: (task) => _handleBackgroundTask(task, image.imageID),
      ),
    ).then((_) {
      setState(() {
        _selectedImage = null;
      });
    });
  }

  // 新增: 更新列表中指定的图片
  void _updateImageInList(ImageModel updatedImage) {
    setState(() {
      final index = _images.indexWhere(
        (img) => img.imageID == updatedImage.imageID,
      );
      if (index != -1) {
        _images[index] = updatedImage;
      }
    });
  }

  // 新增: 处理后台任务
  Future<void> _handleBackgroundTask(
    Future<ImageModel> Function() task,
    int imageId,
  ) async {
    // 显示任务开始提示
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("后台任务开始执行...")));

    try {
      // 执行后台任务
      final updatedImage = await task();

      // 更新图片列表中的数据
      _updateImageInList(updatedImage);

      // 显示任务完成提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("后台任务已完成!")));
    } catch (e) {
      // 显示错误提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("后台任务出错: ${e.toString()}")));
    }
  }

  // 查询图片的方法
  Future<void> _fetchImages() async {
  setState(() {
    _isLoading = true;
  });

  try {
    final categoryName = _categories.firstWhere(
      (item) => item['id'] == _selectedCategoryId,
      orElse: () => {},
    )['name'];
    final collectorTypeName = _collectorTypes.firstWhere(
      (item) => item['id'] == _selectedCollectorTypeId,
      orElse: () => {},
    )['name'];
    final questionDirectionName = _questionDirections.firstWhere(
      (item) => item['id'] == _selectedQuestionDirectionId,
      orElse: () => {},
    )['name'];

    final endpoint =
        '/api/image/my?page=$_currentPage&pageSize=$_pageSize'
        '${categoryName != null ? '&category=$categoryName' : ''}'
        '${collectorTypeName != null ? '&collector_type=$collectorTypeName' : ''}'
        '${questionDirectionName != null ? '&question_direction=$questionDirectionName' : ''}';

    final response = await http.get(
      Uri.parse('${UserSession().baseUrl}$endpoint'),
      headers: {'Authorization': 'Bearer ${UserSession().token ?? ''}'},
    );

    print('API Response: ${response.body}'); // 添加详细日志

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // 根据响应结构解析数据
      final responseData = data['data'] as Map<String, dynamic>?;
      if (responseData == null) {
        throw Exception('Invalid API response: missing data field');
      }
      
      final innerData = responseData['data'] as Map<String, dynamic>?;
      if (innerData == null) {
        throw Exception('Invalid API response: missing inner data field');
      }
      
      final imagesData = innerData['images'] as List<dynamic>?;
      final pagination = innerData['pagination'] as Map<String, dynamic>?;

      if (imagesData != null && pagination != null) {
        setState(() {
          _images = imagesData
              .map<ImageModel>((item) => ImageModel.fromJson(item))
              .toList();
          _totalItems = pagination['total'] as int;
        });
      } else {
        throw Exception('Invalid API response structure');
      }
    } else {
      throw Exception('Failed to load images: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching images: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('加载图片失败: $e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
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

  // 根据类目ID获取采集类型
  Future<void> _fetchCollectorTypes(String? categoryId) async {
    if (categoryId == null) {
      setState(() {
        _collectorTypes = [];
        _selectedCollectorTypeId = null;
        _questionDirections = [];
        _selectedQuestionDirectionId = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTitleSelector(),
          Expanded(child: _buildImageGrid()),
        ],
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
              _selectedCategoryId = newValue;
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
              _selectedCollectorTypeId = newValue;
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

          // 查询按钮
          ElevatedButton(
            onPressed: () async {
              _currentPage = 1;
              await _fetchImages();
            },
            child: const Text('查询'),
          ),
        ],
      ),
    );
  }

  // 添加图片网格显示组件
  Widget _buildImageGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_images.isEmpty) {
      return const Center(
        child: Text('暂无图片数据', style: TextStyle(fontSize: 18)),
      );
    }

    // 计算网格列数（响应式设计）
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    if (width > 1200) {
      crossAxisCount = 4; // 大屏幕显示4列
    } else if (width > 900) {
      crossAxisCount = 3; // 中等屏幕显示3列
    } else if (width > 600) {
      crossAxisCount = 2; // 小屏幕显示2列
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7, // 卡片宽高比
            ),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              final image = _images[index];
              return _buildImageCard(image);
            },
          ),
        ),
        // 分页控件
        _buildPaginationControls(),
      ],
    );
  }

  // 构建图片卡片组件
  Widget _buildImageCard(ImageModel image) {
    final imageUrl = image.path != null
        ? '${Uri.parse(UserSession().baseUrl).origin}/${image.path}'
        : null;

    // 安全处理问题和答案
    String questionText = '';
    String answerText = '';

    // 注意：image.questions 可能为null，所以使用 ?. 操作符
    if (image.questions != null && image.questions!.isNotEmpty) {
      final firstQuestion = image.questions!.first;
      questionText = firstQuestion.questionText;

      // 使用rightAnswer的answerText
      answerText = firstQuestion.rightAnswer.answerText;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showImageDetailDialog(image),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardHeight = constraints.maxHeight;
              final imageHeight = 2 * cardHeight / 3;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: imageHeight,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: imageHeight,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.broken_image),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 5),
                  if (questionText.isNotEmpty)
                    Text(
                      "问题: $questionText",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (answerText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        "答案: $answerText",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const Spacer(),

                  const SizedBox(height: 1),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        image.originator.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateTime.parse(image.created_at).toIso8601String(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // 分页控件
  Widget _buildPaginationControls() {
    final totalPages = (_totalItems / _pageSize).ceil();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                    _fetchImages();
                  }
                : null,
          ),
          Text('$_currentPage / $totalPages'),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                    _fetchImages();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLevelDropdown({
    required String? value,
    required List<String> options,
    required String hint,
    required Map<String, String> displayValues,
    bool enabled = true,
    ValueChanged<String?>? onChanged,
  }) {
    return Container(
      width: 180,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: hint,
          border: const OutlineInputBorder(),
          enabled: enabled,
        ),
        items: options.map((id) {
          return DropdownMenuItem<String>(
            value: id,
            child: Text(
              displayValues[id] ?? '未知',
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
