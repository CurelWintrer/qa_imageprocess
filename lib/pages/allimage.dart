import 'dart:collection';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/MyWidget/image_detail.dart';
import 'package:qa_imageprocess/model/answer_model.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/tools/ai_service.dart';
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

  bool is_opinion = true;
  bool is_answer = true;
  bool is_COT = true;

  DateTime? _startDate;
  DateTime? _endDate;

  int _totalImageCount = 0;
  //正在处理的图片ID
  Set<int> _processingImageIDs = {}; // 记录正在处理AI的图片ID

  Set<int> _selectedImageIDs = {}; // 存储选中的图片ID
  bool _isInSelectionMode = false; // 是否处于多选模式

  //出错的图片
  List<ImageModel> _faultImages=[];

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
            ),
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
    if (_selectedDifficulty != null) {
      queryParams['difficulty'] = _selectedDifficulty.toString();
    }
    if (_startDate != null) {
      queryParams['startTime'] = _startDate!.millisecondsSinceEpoch.toString();
    }
    if (_endDate != null) {
      queryParams['endTime'] = _endDate!.millisecondsSinceEpoch.toString();
    }
    print('$_startDate    $_endDate');

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
          _totalImageCount = pagination['total'];
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

  void _selectAllImages() {
    setState(() {
      _selectedImageIDs = Set<int>.from(_images.map((img) => img.imageID));
      _isInSelectionMode = true;
    });
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
          // 添加复选框部分
          final checkboxSection = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCheckbox('意见', is_opinion, (value) {
                setState(() => is_opinion = value!);
              }),
              _buildCheckbox('答案', is_answer, (value) {
                setState(() => is_answer = value!);
              }),
              _buildCheckbox('COT', is_COT, (value) {
                setState(() => is_COT = value!);
              }),
              SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(color: Colors.yellowAccent),
                child: Text(
                  '当前数量：$_totalImageCount',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(width: 16),
              _buildDatePicker('开始时间', _startDate, (date) {
                setState(() => _startDate = date);
              }),
              const SizedBox(width: 8),
              _buildDatePicker('结束时间', _endDate, (date) {
                setState(() => _endDate = date);
              }),
              const SizedBox(width: 8),
              if (_isInSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: _selectedImageIDs.length == _images.length
                      ? _deselectAllImages
                      : _selectAllImages,
                  tooltip: _selectedImageIDs.length == _images.length
                      ? '取消全选'
                      : '全选',
                ),
                IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  onPressed: ()=>{_batchProcessImages(0)},
                  tooltip: '批量QA',
                  color: Colors.blue,
                ),
                IconButton(
                  icon: const Icon(Icons.question_answer),
                  onPressed: ()=>{_batchProcessImages(1)},
                  tooltip: '批量答案',
                  color: Colors.orangeAccent
                ),
                IconButton(
                  icon: const Icon(Icons.tips_and_updates),
                  onPressed: ()=>{_batchProcessImages(2)},
                  tooltip: '批量解析',
                  color: Colors.green
                ),
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: _deselectAllImages,
                  tooltip: '退出多选',
                  color: Colors.red
                ),
              ] else if (_images.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: () => setState(() => _isInSelectionMode = true),
                  tooltip: '多选模式',
                ),
              ],
            ],
          );
          final children = [
            _buildCategoryDropdown(),
            _buildCollectorTypeDropdown(),
            _buildQuestionDirectionDropdown(),
            _buildDifficultyDropdown(),
            // if (isWideScreen) checkboxSection, // 宽屏时复选框在同一行
            SizedBox(
              width: 100,
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
              width: 100,
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
          return Column(
            children: [
              Row(children: [Expanded(child: checkboxSection)]),
              const SizedBox(height: 16),
              Wrap(spacing: 16, runSpacing: 16, children: children),
            ],
          );
          //}
        },
      ),
    );
  }

  // 构建日期选择器
  Widget _buildDatePicker(
    String label,
    DateTime? selectedDate,
    ValueChanged<DateTime?> onDateSelected,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => _selectDate(context, selectedDate, onDateSelected),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedDate != null
                    ? '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'
                    : '选择日期',
                style: TextStyle(fontSize: 14),
              ),
              Icon(Icons.calendar_today, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // 选择日期
  Future<void> _selectDate(
    BuildContext context,
    DateTime? initialDate,
    ValueChanged<DateTime?> onDateSelected,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != initialDate) {
      onDateSelected(picked);
    }
  }

  Widget _buildCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(value: value, onChanged: onChanged),
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
      ],
    );
  }

  void _startExport() async {
    var ExportCategory = '';
    if (_selectedCategoryId != null) {
      final category = _categories.firstWhere(
        (c) => c['id'] == _selectedCategoryId,
        orElse: () => {'name': ''},
      );
      ExportCategory = category['name'];
    }

    // 使用复选框的值和时间戳作为参数
    exportService = ExportService(
      context: context,
      category: ExportCategory,
      is_opinion: is_opinion,
      is_answer: is_answer,
      is_COT: is_COT,
      startTime: _startDate?.millisecondsSinceEpoch.toString(),
      endTime: _endDate?.millisecondsSinceEpoch.toString(),
    );

    setState(() => isExporting = true);

    try {
      await exportService.exportImages();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片导出成功!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    } finally {
      setState(() => isExporting = false);
    }
  }

  Widget _buildGridItem(ImageModel image) {
    final firstQuestion = image.questions?.isNotEmpty == true
        ? image.questions?.first
        : null;
    final bool isProcessing = _processingImageIDs.contains(image.imageID);
    final bool isSelected = _selectedImageIDs.contains(image.imageID);

    return GestureDetector(
      onLongPress: () => {},
      onTap: () {
        // setState(() {
        //   _selectedImageId = image.imageID;
        // });
        _openImageDetail(image);
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
          //多选标识
                      // 多选框（悬浮在右上角）
            if (_isInSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (value) => setState(() {
                      _toggleImageSelection(image.imageID);
                    }),
                  ),
                ),
              ),
          //处理中标识
          if (isProcessing)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3.0,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

    // 添加辅助方法
  void _toggleImageSelection(int imageID) {
    if (_selectedImageIDs.contains(imageID)) {
      _selectedImageIDs.remove(imageID);
    } else {
      _selectedImageIDs.add(imageID);
    }

    // 如果没有选中任何图片，退出多选模式
    if (_selectedImageIDs.isEmpty) {
      _isInSelectionMode = false;
    }
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

  // int 类型的下拉框
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

  // 处理图片更新回调
  void _handleImageUpdated(ImageModel updatedImage) {
    setState(() {
      // 找到并更新图片列表中的对应图片
      final index = _images.indexWhere(
        (img) => img.imageID == updatedImage.imageID,
      );
      if (index != -1) {
        _images[index] = updatedImage;
      }
    });
  }

  //处理图片删除
  void _handleImageDeleted(int imageID) {
    setState(() {
      final index = _images.indexWhere((img) => img.imageID == imageID);
      if (index != -1) {
        _images.removeAt(index); // 通过索引删除元素
      }
    });
    Navigator.pop(context);
  }

  // 打开图片详情弹窗
  void _openImageDetail(ImageModel image) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ImageDetail(
            image: image,
            onImageUpdated: _handleImageUpdated,
            onClose: () => Navigator.pop(context),
            onImageDeleted: _handleImageDeleted,
            onImageOaUpdated: _handleImageQaUpadted,
            onExplanationUpdated: _handleExplanationUpdated,
            onAnswerUpdated: _handleAnswerUpdated,
          ),
        );
      },
    );
  }

  void _handleImageQaUpadted(ImageModel updatedImage) {
    _executeAITask(updatedImage);
  }

  Future<void> _executeAITask(ImageModel image) async {
    if (mounted) {
      setState(() {
        _processingImageIDs.add(image.imageID);
      });
    }
    try {
      // 1. 调用AI服务
      final qa = await AiService.getQA(
        image,
        questionDifficulty: _selectedDifficulty ?? 0,
      );
      if (qa == null) throw Exception('AI服务返回空数据');

      debugPrint('AI生成结果: ${qa.toString()}');

      // 2. 更新到后端API
      final updatedImage = await _updateImageQA(
        image: image,
        questionText: qa.question,
        answers: qa.options,
        rightAnswerIndex: qa.correctAnswer,
        explanation: qa.explanation,
        textCOT: qa.textCOT,
      );

      setState(() {
        // 找到并更新图片列表中的对应图片
        final index = _images.indexWhere(
          (img) => img.imageID == updatedImage!.imageID,
        );
        if (index != -1) {
          _images[index] = updatedImage!;
        }
      });

      if (updatedImage == null) throw Exception('图片更新失败');
      // 4. 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图片${updatedImage.imageID}AI处理完成')),
      );
    } catch (e, stackTrace) {
      debugPrint('AI处理错误: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('处理失败: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingImageIDs.remove(image.imageID);
        });
      }
    }
  }

  //图片批量处理
  Future<void> _batchProcessImages(int model) async {
    if (_selectedImageIDs.isEmpty) return;

    // 确认对话框
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认批量处理'),
            content: Text('确定要批量处理选中的 ${_selectedImageIDs.length} 张图片吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('开始处理'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    // 复制一份选中的图片ID，防止在处理过程中修改
    final imagesToProcess = List<int>.from(_selectedImageIDs);
    final totalCount = imagesToProcess.length;

    // 添加到处理队列并清空选择
    setState(() {
      _processingImageIDs.addAll(imagesToProcess);
      _deselectAllImages();
    });

    int processedCount = 0;

    // 使用队列控制并发数量
    final queue = Queue<Future>();
    const maxConcurrency = 8; // 最大并发数

    for (final imageID in imagesToProcess) {
      while (queue.length >= maxConcurrency) {
        await Future.any(queue);
      }

      final image = _images.firstWhere((img) => img.imageID == imageID);

      Future task;
      // 先声明 task 变量
      switch(model){
        case 0:
        task  = _executeAITask(image);
        case 1:
        task=_executeAIAnswerAnexplanation(image);
        case 2:
        task= _executeAIExplanationCOT(image);
        default:
        task=_executeAITask(image);
      };
      

      // 将任务添加到队列
      queue.add(task);

      // 使用 task 变量
      task
          .then((_) {
            processedCount++;
            if (processedCount % 5 == 0 || processedCount == totalCount) {
              // 每处理8张或全部完成时更新进度
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("处理进度: $processedCount/$totalCount")),
                );
              }
            }
            queue.remove(task);
          })
          .catchError((error) {
            queue.remove(task);
          });
    }

    await Future.wait(queue);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("批量处理完成! 成功: $processedCount/$totalCount")),
      );
    }
  }

  //清除选中图片
  void _deselectAllImages() {
    setState(() {
      _selectedImageIDs.clear();
      _isInSelectionMode = false;
    });
  }

  Future<ImageModel?> _updateImageQA({
    required ImageModel image,
    required String questionText,
    String? explanation,
    String? textCOT,
    required List<String> answers,
    required int rightAnswerIndex,
  }) async {
    final url = '${UserSession().baseUrl}/api/image/${image.imageID}/qa';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${UserSession().token ?? ''}',
    };
    final body = jsonEncode({
      'difficulty': image.difficulty ?? 0,
      'questionText': questionText,
      'answers': answers,
      'rightAnswerIndex': rightAnswerIndex,
      'explanation': explanation,
      'textCOT': textCOT,
    });

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print(response.body);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return ImageModel.fromJson(responseData['data']);
      } else {
        throw Exception('更新失败: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
      return null;
    }
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
    // 提取中文括号内的内容
    String extractChineseBracketContent(String text) {
      // 使用正则表达式匹配中文括号及其内容
      RegExp exp = RegExp(r'（([^）]+)）');
      Match? match = exp.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)!;
      }
      return text; // 如果没有匹配到中文括号，返回原文本
    }

    final items = [
      // 添加空选项
      DropdownMenuItem<String?>(
        value: null,
        child: Text('未选择', style: TextStyle(color: Colors.grey)),
      ),
      // 添加其他选项
      ...options.map((id) {
        String displayText = displayValues[id] ?? '未知';
        // 提取中文括号内的内容
        displayText = extractChineseBracketContent(displayText);

        return DropdownMenuItem<String?>(
          value: id,
          child: Text(displayText, overflow: TextOverflow.ellipsis),
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

  //寻找正确答案索引
  int _findRightAnswerIndex(List<AnswerModel> answers, int rightAnswerId) {
    for (int i = 0; i < answers.length; i++) {
      if (answers[i].answerID == rightAnswerId) {
        return i;
      }
    }
    return -1; // 未找到匹配项，返回-1
  }

  Future<void> _executeAIExplanationCOT(ImageModel image) async {
    if (mounted) {
      setState(() {
        _processingImageIDs.add(image.imageID);
      });
      try {
        final explanationCot = await AiService.getExplanationAndCOT(image);
        if (explanationCot == null) throw Exception('AI返回空数据');
        // QuestionModel

        final updatedImage = await _updateImageQA(
          image: image,
          questionText: image.questions!.first.questionText,
          answers: image.questions!.first.answers
              .map((answer) => answer.answerText)
              .toList(),
          rightAnswerIndex: _findRightAnswerIndex(
            image.questions!.first.answers,
            image.questions!.first.rightAnswer.answerID,
          ),
          explanation: explanationCot.explanation,
          textCOT: explanationCot.COT,
        );
        setState(() {
          final index = _images.indexWhere(
            (img) => img.imageID == updatedImage!.imageID,
          );
          if (index != -1) {
            _images[index] = updatedImage!;
          }
        });
        if (updatedImage == null) throw Exception('图片更新失败');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('成功生成答案和解析')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('答案生成失败$e')));
      } finally {
        if (mounted) {
          setState(() {
            _processingImageIDs.remove(image.imageID);
          });
        }
      }
    }
  }

  void _handleExplanationUpdated(ImageModel updatedImage) {
    _executeAIExplanationCOT(updatedImage);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('正在加载，可关闭弹窗')));
  }
    void _handleAnswerUpdated(ImageModel updatedImage) {
    _executeAIAnswerAnexplanation(updatedImage);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('正在加载，可关闭弹窗')));
  }

  Future<void> _executeAIAnswerAnexplanation(ImageModel image) async {
    if (mounted) {
      setState(() {
        _processingImageIDs.add(image.imageID);
      });
      try {
        final answers = await AiService.getAnswer(image);
        if (answers == null) throw Exception('AI返回空数据');
        final updatedImage = await _updateImageQA(
          image: image,
          questionText: image.questions!.first.questionText,
          answers: answers.answers,
          rightAnswerIndex: answers.rightAnswerIndex,
          explanation: answers.explanation,
          textCOT: answers.COT,
        );
        setState(() {
          final index = _images.indexWhere(
            (img) => img.imageID == updatedImage!.imageID,
          );
          if (index != -1) {
            _images[index] = updatedImage!;
          }
        });
        if (updatedImage == null) throw Exception('图片更新失败');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('成功生成答案和解析')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('答案生成失败$e')));
      } finally {
        if (mounted) {
          setState(() {
            _processingImageIDs.remove(image.imageID);
          });
        }
      }
    }
  }
}
