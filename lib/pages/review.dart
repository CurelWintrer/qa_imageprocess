import 'dart:collection';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/MyWidget/image_detail.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/model/work_model.dart';
import 'package:qa_imageprocess/tools/ai_service.dart';
import 'package:qa_imageprocess/tools/work_state.dart';
import 'package:qa_imageprocess/user_session.dart';

class Review extends StatefulWidget {
  final int workID;
  const Review({super.key, required this.workID});

  @override
  State<Review> createState() => _ReviewState();
}

class _ReviewState extends State<Review> {
  WorkModel? _work;
  List<ImageModel> _images = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String _errorMessage = '';

  // 当前选中的图片
  int? _selectedImageId;

  // 多选模式相关
  Set<int> _processingImageIDs = {};
  Set<int> _selectedImageIDs = {};
  bool _isInSelectionMode = false;

  // 全选状态变量
  bool _isAllSelected = false;
  //打回原因和备注
  TextEditingController _returnReasonController = TextEditingController();
  TextEditingController _remarkController = TextEditingController();

  TextEditingController _passReasonController = TextEditingController();
  TextEditingController _passRemarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchWorkDetails();
  }

  Future<void> _fetchWorkDetails() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final url = Uri.parse(
        '${UserSession().baseUrl}/api/works/${widget.workID}/details?page=$_currentPage&limit=10',
      );

      final headers = {
        'Authorization': 'Bearer ${UserSession().token}',
        'Content-Type': 'application/json',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 200) {
          final workData = data['data'];

          setState(() {
            _work = WorkModel.fromJson(workData['work']);
            final imageData = workData['images'];
            final pagination = imageData['pagination'];

            _currentPage = pagination['currentPage'];
            _totalPages = pagination['totalPages'];

            final newImages = (imageData['data'] as List)
                .map((imgJson) => ImageModel.fromJson(imgJson))
                .toList();

            _images.addAll(newImages);
            _hasMore = _currentPage < _totalPages;

            // 默认选中第一张图片
            if (_images.isNotEmpty && _selectedImageId == null) {
              _selectedImageId = _images.first.imageID;
            }
          });
        } else {
          throw Exception('API错误: ${data['message']}');
        }
      } else {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载数据失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadMoreImages() {
    if (_hasMore && !_isLoading) {
      _currentPage++;
      _fetchWorkDetails();
    }
  }

  void _handleImageUpdated(ImageModel updatedImage) {
    setState(() {
      final index = _images.indexWhere(
        (img) => img.imageID == updatedImage.imageID,
      );
      if (index != -1) {
        _images[index] = updatedImage;
      }
    });
  }

  // 切换到下一张图片
  void _nextImage() {
    if (_images.isEmpty) return;

    final currentIndex = _images.indexWhere(
      (img) => img.imageID == _selectedImageId,
    );

    int nextIndex = currentIndex + 1;
    if (nextIndex >= _images.length) {
      nextIndex = 0; // 循环到第一张
    }

    setState(() {
      _selectedImageId = _images[nextIndex].imageID;
    });
  }

  Widget _buildLeftListItem(ImageModel image) {
  final bool isProcessing = _processingImageIDs.contains(image.imageID);
  final bool isSelected = _selectedImageIDs.contains(image.imageID);
  final bool isCurrentSelected = _selectedImageId == image.imageID;
  final bool showCheckbox = _isInSelectionMode;
  final bool isAllSelected =
      _isInSelectionMode && _selectedImageIDs.length == _images.length;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: isCurrentSelected
          ? Colors.blue.withOpacity(0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isAllSelected
            ? Colors.blue
            : isCurrentSelected
                ? Colors.blue
                : Colors.grey.shade200,
        width: isAllSelected ? 2 : 1,
      ),
    ),
    child: Stack(
      children: [
        // 内容区域
        IntrinsicHeight(
          child: InkWell(
            onTap: () {
              if (_isInSelectionMode) {
                setState(() => _toggleImageSelection(image.imageID));
              } else {
                setState(() => _selectedImageId = image.imageID);
              }
            },
            onLongPress: () {
              setState(() {
                _isInSelectionMode = true;
                _toggleImageSelection(image.imageID);
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图片区域
                  Container(
                    width: 300,
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: image.path?.isNotEmpty == true
                          ? CachedNetworkImage(
                              imageUrl:
                                  '${UserSession().baseUrl}/${image.path}',
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.error, size: 30),
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 30,
                                ),
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 图片ID和状态标签
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '#${image.imageID}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildImageStatusBadge(image.state),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 左上角复选框
        if (showCheckbox)
          Positioned(
            top: 8,
            left: 8,
            child: GestureDetector(
              onTap: () =>
                  setState(() => _toggleImageSelection(image.imageID)),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            ),
          ),

        // 处理中覆盖层
        if (isProcessing)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.black26,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade800,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '处理中...',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

  // 多选模式相关方法
  void _toggleImageSelection(int imageID) {
    setState(() {
      if (_selectedImageIDs.contains(imageID)) {
        _selectedImageIDs.remove(imageID);
      } else {
        _selectedImageIDs.add(imageID);
      }

      if (_selectedImageIDs.isEmpty) {
        _isInSelectionMode = false;
      }
    });
  }

  void _selectAllImages() {
    setState(() {
      _selectedImageIDs = Set<int>.from(_images.map((img) => img.imageID));
    });
  }

  void _deselectAllImages() {
    setState(() {
      _selectedImageIDs.clear();
      // 当清空选择时退出多选模式
      if (_selectedImageIDs.isEmpty) {
        _isInSelectionMode = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Work #${widget.workID}'),
        actions: [
          SizedBox(
            width: 100,
            height: 30,
            child: ElevatedButton(
              onPressed: () => {_showPassWorkDialog()},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('通过'),
            ),
          ),
          SizedBox(width: 20),
          SizedBox(
            width: 100,
            height: 30,
            child: ElevatedButton(
              onPressed: () => {_showReturnWorkDialog()},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('打回'),
            ),
          ),
          IconButton(
            icon: Icon(_isInSelectionMode ? Icons.select_all : Icons.checklist),
            tooltip: _isInSelectionMode
                ? (_selectedImageIDs.length == _images.length ? '取消全选' : '全选')
                : '多选模式',
            onPressed: () {
              if (!_isInSelectionMode) {
                // 非多选模式时点击：进入多选模式
                setState(() => _isInSelectionMode = true);
              } else {
                // 多选模式时点击：切换全选状态
                if (_selectedImageIDs.length == _images.length) {
                  _deselectAllImages();
                } else {
                  _selectAllImages();
                }
              }
            },
          ),

          // 多选模式下显示的其他按钮
          if (_isInSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _batchProcessImages,
              tooltip: '批量处理',
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _deselectAllImages,
              tooltip: '退出多选',
            ),
          ],
        ],
      ),
      body: _buildSplitView(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.arrow_forward),
        onPressed: _nextImage,
        tooltip: '下一项',
      ),
    );
  }

  // 修改后的打回方法
  Future<void> _handleReturnWork(String returnReason, String remark) async {
    await WorkState.submitWork(
      context,
      _work!,
      5,
      returnReason: returnReason,
      remark: remark,
    );
    Navigator.pop(context); // 关闭弹窗
  }

  // 打回任务弹窗
  void _showReturnWorkDialog() {
    // 每次打开弹窗时清空输入内容
    _returnReasonController.clear();
    _remarkController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('打回任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '打回原因 (必填):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _returnReasonController,
                  decoration: const InputDecoration(
                    hintText: '请输入打回原因',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text(
                  '备注:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _remarkController,
                  decoration: const InputDecoration(
                    hintText: '可输入额外说明',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = _returnReasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('打回原因不能为空')));
                  return;
                }

                _handleReturnWork(reason, _remarkController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('确认打回'),
            ),
          ],
        );
      },
    );
  }

  // 处理通过任务的方法
  Future<void> _handlePassWork(String passReason, String remark) async {
    Navigator.pop(context); // 关闭弹窗
    await WorkState.submitWork(
      context,
      _work!,
      6,
      returnReason: passReason,
      remark: remark,
    );
  }

  // 通过任务弹窗
  void _showPassWorkDialog() {
    // 每次打开弹窗时清空输入内容
    _passRemarkController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('通过任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  '备注:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _passRemarkController,
                  decoration: const InputDecoration(
                    hintText: '可输入额外说明（可选）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                _handlePassWork(
                  _passReasonController.text.trim(),
                  _passRemarkController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('确认通过'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSplitView() {
    return Row(
      children: [
        // 左侧列表视图 (1/3宽度)
        Container(
          width: MediaQuery.of(context).size.width * 0.33,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: _buildLeftList(),
        ),

        // 右侧详情视图 (2/3宽度)
        Expanded(
          child: _selectedImageId != null
              ? _buildRightDetail()
              : const Center(child: Text('请从左侧选择一张图片')),
        ),
      ],
    );
  }

  Widget _buildLeftList() {
    if (_isLoading && _images.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchWorkDetails,
              child: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    if (_work == null) {
      return const Center(child: Text('加载工作信息失败'));
    }

    return Expanded(
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            _loadMoreImages();
          }
          return true;
        },
        child: ListView.builder(
          itemCount: _images.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _images.length) {
              return _buildLoadMoreIndicator();
            }
            return _buildLeftListItem(_images[index]);
          },
        ),
      ),
    );
  }

  //处理图片删除
  void _handleImageDeleted(int imageID) {
    setState(() {
      final index = _images.indexWhere((img) => img.imageID == imageID);
      if (index != -1) {
        _images.removeAt(index); // 通过索引删除元素
      }
    });
  }

  // 右侧图片详情
  Widget _buildRightDetail() {
  if (_selectedImageId == null) return const Center(child: Text('请从左侧选择一张图片'));

  try {
    final selectedImage = _images.firstWhere(
      (img) => img.imageID == _selectedImageId,
    );
    
    return Row(
      children: [
        // 左侧图片区域 (1/2宽度)
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: InteractiveViewer(
              boundaryMargin: EdgeInsets.all(20),
              minScale: 0.1,
              maxScale: 4.0,
              child: selectedImage.path?.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: '${UserSession().baseUrl}/${selectedImage.path}',
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.error, size: 30),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 30,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        
        // 右侧信息区域 (1/2宽度)
        Expanded(
          flex: 1,
          child: _buildInfoColumn(selectedImage),
        ),
      ],
    );
  } catch (e) {
    return const Center(child: Text('加载失败'));
  }
}

Widget _buildInfoColumn(ImageModel image) {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 基本信息区域
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 基本信息
                _buildInfoItem('文件名', image.fileName ?? '未命名'),
                _buildInfoItem('分类', image.category),
                _buildInfoItem('采集类型', image.collectorType),
                _buildInfoItem('问题方向', image.questionDirection),
                _buildInfoItem(
                  '难度',
                  ImageState.getDifficulty(image.difficulty ?? -1),
                ),
                _buildInfoItem(
                  '状态',
                  ImageState.getStateText(image.state),
                ),
                _buildInfoItem('创建日期', image.created_at),
                _buildInfoItem('更新日期', image.updated_at),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        IconButton(
          onPressed: () => {_handleImageDeleted(image.imageID)},
          icon: const Icon(Icons.delete),
          tooltip: '删除',
          hoverColor: Colors.redAccent,
        ),

        // 问题和答案区域
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // AI-QA按钮
                      IconButton(
                        onPressed: _processingImageIDs.contains(image.imageID) 
                            ? null 
                            : () => _executeAITask(image),
                        icon: const Icon(Icons.auto_awesome),
                        tooltip: 'AI-QA',
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),

                  // 标题
                  const Text(
                    '题目内容',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 问题和答案展示
                  if (image.questions != null && image.questions!.isNotEmpty)
                    ...image.questions!
                        .map((question) => _buildQuestionAnswer(question))
                        .toList()
                  else
                    const Text('暂无题目内容'),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
Widget _buildInfoItem(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value.isNotEmpty ? value : '未设置'),
        ),
      ],
    ),
  );
}

  Widget _buildQuestionAnswer(QuestionModel question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.questionText,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildAnswerIndicators(question),
        const SizedBox(height: 16),
      ],
    );
  }

  // 正确答案指示器
  Widget _buildAnswerIndicators(QuestionModel question) {
    if (question.answers.isEmpty) return const SizedBox();

    // 找到正确答案
    final rightAnswerId = question.rightAnswer.answerID;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 答案指示器
        Wrap(
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
                  color: isCorrect ? Colors.green : Colors.grey.shade300,
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
        ),

        const SizedBox(height: 16),

        // 解析部分
        if (question.explanation?.isNotEmpty ?? false) ...[
          const Text(
            '解析:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              question.explanation!,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 思维链部分
        if (question.textCOT?.isNotEmpty ?? false) ...[
          const Text(
            '解题思维链：',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              question.textCOT!,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }


  Future<void> _executeAITask(ImageModel image) async {
    if (mounted) {
      setState(() {
        _processingImageIDs.add(image.imageID);
      });
    }
    try {
      final qa = await AiService.getQA(image);
      if (qa == null) throw Exception('AI服务返回空数据');

      final updatedImage = await _updateImageQA(
        image: image,
        questionText: qa.question,
        answers: qa.options,
        rightAnswerIndex: qa.correctAnswer,
        explanation: qa.explanation,
        textCOT: qa.textCOT,
      );

      setState(() {
        final index = _images.indexWhere(
          (img) => img.imageID == updatedImage!.imageID,
        );
        if (index != -1) {
          _images[index] = updatedImage!;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片${updatedImage?.imageID}AI处理完成')),
        );
      }
    } catch (e, stackTrace) {
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

  

  Widget _buildImageStatusBadge(int state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ImageState.getStateColor(state).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildLoadMoreIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _hasMore
            ? const CircularProgressIndicator()
            : const Text('没有更多图片了', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  Future<void> _batchProcessImages() async {
    if (_selectedImageIDs.isEmpty) return;

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

    final imagesToProcess = List<int>.from(_selectedImageIDs);
    final totalCount = imagesToProcess.length;

    setState(() {
      _processingImageIDs.addAll(imagesToProcess);
      _deselectAllImages();
    });

    int processedCount = 0;
    final queue = Queue<Future>();
    const maxConcurrency = 5;

    for (final imageID in imagesToProcess) {
      while (queue.length >= maxConcurrency) {
        await Future.any(queue);
      }

      final image = _images.firstWhere((img) => img.imageID == imageID);
      final task = _executeAITask(image);

      queue.add(task);
      task
          .then((_) {
            processedCount++;
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
}
