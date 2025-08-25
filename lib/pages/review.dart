import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  
  // 编辑问题和答案相关
  bool _isEditing = false;
  TextEditingController _questionController = TextEditingController();
  TextEditingController _explanationController = TextEditingController();
  TextEditingController _cotController = TextEditingController();
  List<TextEditingController> _answerControllers = [];
  int _rightAnswerIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchWorkDetails();
  }
  
  // 初始化编辑控制器
  void _initEditControllers(QuestionModel question) {
    _questionController.text = question.questionText;
    _explanationController.text = question.explanation ?? '';
    _cotController.text = question.textCOT ?? '';
    
    // 清空旧的答案控制器
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    _answerControllers.clear();
    
    // 初始化答案控制器
    for (var answer in question.answers) {
      _answerControllers.add(TextEditingController(text: answer.answerText));
      if (answer.answerID == question.rightAnswer.answerID) {
        _rightAnswerIndex = question.answers.indexOf(answer);
      }
    }
  }
  
  // 开始编辑
  void _startEditing(QuestionModel question) {
    _initEditControllers(question);
    setState(() {
      _isEditing = true;
    });
  }
  
  // 取消编辑
  void _cancelEditing() {
    setState(() {
      _isEditing = false;
    });
  }
  
  // 添加答案选项
  void _addAnswer() {
    setState(() {
      _answerControllers.add(TextEditingController(text: ''));
    });
  }
  
  // 删除答案选项
  void _removeAnswer(int index) {
    if (_answerControllers.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少需要两个答案选项')),
      );
      return;
    }
    
    setState(() {
      _answerControllers[index].dispose();
      _answerControllers.removeAt(index);
      
      // 如果删除的是正确答案，重置正确答案索引
      if (_rightAnswerIndex == index) {
        _rightAnswerIndex = 0;
      } else if (_rightAnswerIndex > index) {
        _rightAnswerIndex--;
      }
    });
  }

  //删除图片
  Future<void> _deleteImage(int imageID) async {
    try {
      final response = await http.delete(
        Uri.parse('${UserSession().baseUrl}/api/image/$imageID'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token ?? ''}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
        final index = _images.indexWhere(
          (img) => img.imageID == imageID,
        );
        if (index != -1) {
          _images.removeAt(index);
        }
        _isEditing = false;
      });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除成功')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败')));
    }
  }
  
  // 提交编辑
  Future<void> _submitEdit(ImageModel image) async {
    // 验证输入
    final questionText = _questionController.text.trim();
    if (questionText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('问题不能为空')),
      );
      return;
    }
    
    // 收集答案
    final answers = <String>[];
    for (var controller in _answerControllers) {
      final text = controller.text.trim();
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('答案不能为空')),
        );
        return;
      }
      answers.add(text);
    }
    
    // 更新数据
    final updatedImage = await _updateImageQA(
      image: image,
      questionText: questionText,
      answers: answers,
      rightAnswerIndex: _rightAnswerIndex,
      explanation: _explanationController.text.trim(),
      textCOT: _cotController.text.trim(),
    );
    
    if (updatedImage != null) {
      setState(() {
        final index = _images.indexWhere(
          (img) => img.imageID == updatedImage.imageID,
        );
        if (index != -1) {
          _images[index] = updatedImage;
        }
        _isEditing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('问题和答案已更新')),
      );
    }
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

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_work?.workID.toString() ?? '质检任务'),
        actions: [
          if (_work != null) ...[            
            // 通过按钮
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
              tooltip: '通过任务',
              onPressed: _showPassWorkDialog,
            ),
            // 打回按钮
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              tooltip: '打回任务',
              onPressed: _showReturnWorkDialog,
            ),
          ],
        ],
      ),
      body: _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
          : _isLoading && _images.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    // 左侧图片列表
                    SizedBox(
                      width: 300,
                      child: _buildImageList(),
                    ),
                    // 分隔线
                    const VerticalDivider(width: 1, thickness: 1),
                    // 右侧图片详情
                    Expanded(
                      child: _selectedImageId != null
                          ? _buildImageDetail()
                          : const Center(child: Text('请选择一张图片')),
                    ),
                  ],
                ),
    );
  }
  
  // 构建图片列表
  Widget _buildImageList() {
    return Column(
      children: [
        // 列表头部
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[200],
          child: Row(
            children: [
              const Text('图片列表', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_isInSelectionMode) ...[                
                IconButton(
                  icon: Icon(_isAllSelected ? Icons.deselect : Icons.select_all),
                  tooltip: _isAllSelected ? '取消全选' : '全选',
                  onPressed: () {
                    setState(() {
                      if (_isAllSelected) {
                        _selectedImageIDs.clear();
                      } else {
                        _selectedImageIDs = _images.map((img) => img.imageID).toSet();
                      }
                      _isAllSelected = !_isAllSelected;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '退出多选',
                  onPressed: () {
                    setState(() {
                      _isInSelectionMode = false;
                      _selectedImageIDs.clear();
                      _isAllSelected = false;
                    });
                  },
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: '多选模式',
                  onPressed: () {
                    setState(() {
                      _isInSelectionMode = true;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
        // 图片列表
        Expanded(
          child: ListView.builder(
            itemCount: _images.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _images.length) {
                // 加载更多指示器
                _fetchMoreImages();
                return _buildLoadMoreIndicator();
              }
              
              final image = _images[index];
              final isSelected = _selectedImageId == image.imageID;
              final isProcessing = _processingImageIDs.contains(image.imageID);
              final isMultiSelected = _selectedImageIDs.contains(image.imageID);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: isSelected ? Colors.blue[50] : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    if (_isInSelectionMode) {
                      setState(() {
                        if (_selectedImageIDs.contains(image.imageID)) {
                          _selectedImageIDs.remove(image.imageID);
                        } else {
                          _selectedImageIDs.add(image.imageID);
                        }
                        _isAllSelected = _selectedImageIDs.length == _images.length;
                      });
                    } else {
                      setState(() {
                        _selectedImageId = image.imageID;
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        // 多选模式下的复选框
                        if (_isInSelectionMode)
                          Checkbox(
                            value: isMultiSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedImageIDs.add(image.imageID);
                                } else {
                                  _selectedImageIDs.remove(image.imageID);
                                }
                                _isAllSelected = _selectedImageIDs.length == _images.length;
                              });
                            },
                          ),
                        // 图片缩略图
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: isProcessing
                              ? const Center(child: CircularProgressIndicator())
                              : Image.network(
                                  '${UserSession().baseUrl}/${image.path}',
                                  fit: BoxFit.cover,
                                  headers: {
                                    'Authorization': 'Bearer ${UserSession().token}',
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(child: Icon(Icons.error));
                                  },
                                ),
                        ),
                        const SizedBox(width: 12),
                        // 图片ID和状态
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID: ${image.imageID}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              _buildImageStatusBadge(image.state),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // 底部操作栏
        if (_isInSelectionMode && _selectedImageIDs.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: Text('批量处理 (${_selectedImageIDs.length})'),
                  onPressed: _batchProcessImages,
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  // 构建图片详情
  Widget _buildImageDetail() {
    final selectedImage = _images.firstWhere(
      (img) => img.imageID == _selectedImageId,
      orElse: () => _images.first,
    );
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片信息头部
          Row(
            children: [
              Text(
                '(ID: ${selectedImage.imageID})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // AI处理按钮
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI处理'),
                onPressed: _processingImageIDs.contains(selectedImage.imageID)
                    ? null
                    : () => _executeAITask(selectedImage),
              ),
            ],
          ),
          const Divider(),
          
          // 图片详情内容
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图片基本信息
                  _buildImageInfoSection(selectedImage),
                  const SizedBox(height: 20),
                  IconButton(onPressed: ()=>{_deleteImage(selectedImage.imageID)}, icon: Icon(Icons.delete)),
                  // 问题和答案部分
                  if (selectedImage.questions != null && selectedImage.questions!.isNotEmpty) ...[
                    _buildQuestionAnswerSection(selectedImage.questions!.first),
                  ] else ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          '该图片尚未生成问题和答案，请点击"AI处理"按钮',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建图片基本信息部分
  Widget _buildImageInfoSection(ImageModel image) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias, // 添加裁剪以确保图片不会溢出卡片边界
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片预览 - 占据卡片的整个宽度和大部分高度
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 400),
            child: Image.network(
              '${UserSession().baseUrl}/${image.path}',
              fit: BoxFit.contain, // 保持图片比例并尽可能填充容器
              // headers: {
              //   'Authorization': 'Bearer ${UserSession().token}',
              // },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.broken_image, size: 100, color: Colors.grey),
                );
              },
            ),
          ),
          // 图片信息部分 - 在图片下方显示
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '图片信息',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                // 图片元数据
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildInfoItem('状态', ImageState.getStateText(image.state)),
                    _buildInfoItem('难度', image.difficulty != null ? '${ImageState.getDifficulty(image.difficulty??-1)}' : '未设置'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建信息项
  Widget _buildInfoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
  
  // 构建问题答案部分
  Widget _buildQuestionAnswerSection(QuestionModel question) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isEditing
            ? _buildEditForm()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 问题文本和编辑按钮
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          question.questionText,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: '编辑问题和答案',
                        onPressed: () => _startEditing(question),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 答案指示器和解析
                  _buildAnswerIndicators(question),
                ],
              ),
      ),
    );
  }
  
  // 构建编辑表单
  Widget _buildEditForm() {
    final selectedImage = _images.firstWhere(
      (img) => img.imageID == _selectedImageId,
      orElse: () => _images.first,
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和取消按钮
        Row(
          children: [
            const Text(
              '编辑问题和答案',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: '取消编辑',
              onPressed: _cancelEditing,
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 问题输入
        const Text('问题:', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _questionController,
          decoration: const InputDecoration(
            hintText: '输入问题',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        
        // 答案选项
        Row(
          children: [
            const Text('答案选项:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              tooltip: '添加答案选项',
              onPressed: _addAnswer,
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // 答案列表
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _answerControllers.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  // 正确答案选择
                  Radio<int>(
                    value: index,
                    groupValue: _rightAnswerIndex,
                    onChanged: (value) {
                      setState(() {
                        _rightAnswerIndex = value!;
                      });
                    },
                  ),
                  // 答案文本输入
                  Expanded(
                    child: TextField(
                      controller: _answerControllers[index],
                      decoration: InputDecoration(
                        hintText: '答案 ${String.fromCharCode(65 + index)}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  // 删除按钮
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    tooltip: '删除此选项',
                    onPressed: () => _removeAnswer(index),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        
        // 解析输入
        const Text('解析:', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _explanationController,
          decoration: const InputDecoration(
            hintText: '输入解析（可选）',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        
        // 思维链输入
        const Text('解题思维链:', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _cotController,
          decoration: const InputDecoration(
            hintText: '输入解题思维链（可选）',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        
        // 提交按钮
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('保存修改'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => _submitEdit(selectedImage),
          ),
        ),
      ],
    );
  }
  
  // 加载更多图片
  Future<void> _fetchMoreImages() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() {
      _currentPage++;
    });
    
    await _fetchWorkDetails();
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
