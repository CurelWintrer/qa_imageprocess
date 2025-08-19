import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/prompt/qa_response.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/tools/ai_service.dart';
import 'package:qa_imageprocess/user_session.dart';

typedef ImageUpdateCallback = void Function(ImageModel updatedImage);

class ImageDetail extends StatefulWidget {
  final ImageModel image;
  final VoidCallback? onClose;
  final ImageUpdateCallback onImageUpdated;

  const ImageDetail({
    super.key,
    required this.image,
    this.onClose,
    required this.onImageUpdated,
  });

  @override
  State<ImageDetail> createState() => _ImageDetailState();
}

class _ImageDetailState extends State<ImageDetail> {
  late ImageModel currentImage;
  bool _isProcessing = false;
  bool _isEditing = false; // 新增：编辑状态标志
  late List<TextEditingController> _answerControllers; // 答案文本控制器
  late TextEditingController _questionController; // 题目文本控制器
  late int _selectedCorrectIndex; // 选择的正确答案索引
  late TextEditingController _explanationController;
  late TextEditingController _textCOTController;

  @override
  void initState() {
    super.initState();
    currentImage = widget.image;
    _initEditControllers(); // 初始化控制器
  }

  // 初始化（刷新）编辑控制器
  void _initEditControllers() {
    // 检查当前图片是否有问题数据
    final question =
        currentImage.questions != null && currentImage.questions!.isNotEmpty
        ? currentImage.questions!.first
        : null;

    // 初始化题目控制器
    _questionController = TextEditingController(
      text: question?.questionText ?? '',
    );

    _explanationController = TextEditingController(
      text: question?.explanation ?? '',
    );

    _textCOTController = TextEditingController(text: question?.textCOT ?? '');

    // 初始化答案控制器
    _answerControllers = [];
    if (question != null && question.answers.isNotEmpty) {
      for (var answer in question.answers) {
        _answerControllers.add(TextEditingController(text: answer.answerText));
      }
      // 设置当前正确答案索引
      final correctAnswerId = question.rightAnswer.answerID;
      _selectedCorrectIndex = question.answers.indexWhere(
        (a) => a.answerID == correctAnswerId,
      );
      if (_selectedCorrectIndex == -1) _selectedCorrectIndex = 0;
    } else {
      // 默认添加两个空答案
      _answerControllers = [TextEditingController(), TextEditingController()];
      _selectedCorrectIndex = 0;
    }
  }

  // 开始编辑
  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  // 取消编辑
  void _cancelEditing() {
    // 重置为原始状态
    _initEditControllers();
    setState(() {
      _isEditing = false;
    });
  }

  // 添加答案选项
  void _addAnswer() {
    setState(() {
      _answerControllers.add(TextEditingController());
    });
  }

  // 移除答案选项
  void _removeAnswer(int index) {
    if (_answerControllers.length > 1) {
      setState(() {
        // 处理被删除的是正确答案的情况
        if (index == _selectedCorrectIndex) {
          _selectedCorrectIndex = 0;
        }
        // 处理删除后索引改变的情况
        else if (index < _selectedCorrectIndex) {
          _selectedCorrectIndex--;
        }

        final controller = _answerControllers.removeAt(index);
        controller.dispose();
      });
    }
  }

  // 提交编辑
  Future<void> _submitEdit() async {
    // 收集数据
    final questionText = _questionController.text.trim();
    if (questionText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入问题内容')));
      return;
    }

    final answers = <String>[];
    for (var controller in _answerControllers) {
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        answers.add(text);
      }
    }

    if (answers.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('至少需要两个有效答案')));
      return;
    }

    if (_selectedCorrectIndex >= answers.length) {
      _selectedCorrectIndex = 0;
    }

    // 显示处理中
    setState(() => _isProcessing = true);

    try {
      // 调用API更新
      final updatedImage = await _updateImageQA(
        imageId: currentImage.imageID,
        questionText: questionText,
        answers: answers,
        rightAnswerIndex: _selectedCorrectIndex,
        explanation: _explanationController.text,
        textCOT: _textCOTController.text,
      );

      if (updatedImage != null) {
        // 更新状态
        setState(() {
          currentImage = updatedImage;
          _isEditing = false;
        });

        // 通知父组件
        widget.onImageUpdated(updatedImage);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('题目更新成功')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // 构建编辑界面
  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 题目编辑区域
        TextField(
          controller: _questionController,
          decoration: InputDecoration(
            labelText: '题目内容',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _questionController.clear(),
            ),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 20),

        // 答案编辑区域
        const Text(
          '答案选项:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // 答案列表
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _answerControllers.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  // 单选按钮
                  Radio<int>(
                    value: index,
                    groupValue: _selectedCorrectIndex,
                    onChanged: (value) =>
                        setState(() => _selectedCorrectIndex = value!),
                  ),

                  // 答案输入框
                  Expanded(
                    child: TextField(
                      controller: _answerControllers[index],
                      decoration: InputDecoration(
                        hintText: '答案选项 ${String.fromCharCode(65 + index)}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),

                  // 删除按钮
                  if (_answerControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeAnswer(index),
                    ),
                ],
              ),
            );
          },
        ),

        // 添加答案按钮
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('添加答案'),
          onPressed: _addAnswer,
        ),
        const SizedBox(height: 20),

        //explanation编辑区
        TextField(
          controller: _explanationController,
          decoration: InputDecoration(
            labelText: '解析',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _explanationController.clear(),
            ),
          ),
          maxLines: 5,
        ),
        const SizedBox(height: 10),
        //textCOT编辑区
        TextField(
          controller: _textCOTController,
          decoration: InputDecoration(
            labelText: '解题思维链',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _textCOTController.clear(),
            ),
          ),
          maxLines: 5,
        ),

        SizedBox(height: 10),

        // 操作按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: _cancelEditing, child: const Text('取消')),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _isProcessing ? null : _submitEdit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('提交更新'),
            ),
          ],
        ),
      ],
    );
  }

  // 构建问题和答案展示组件
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

  // 构建图片信息卡片（添加了InteractiveViewer缩放功能）
  Widget _buildImageCard() {
    final fullImagePath = '${UserSession().baseUrl}/${currentImage.path}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: InteractiveViewer(
          panEnabled: true, // 启用平移
          scaleEnabled: true, // 启用缩放
          minScale: 0.1, // 最小缩放级别
          maxScale: 5.0, // 最大缩放级别
          child: Image.network(
            fullImagePath,
            fit: BoxFit.contain,
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
              return Container(
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '加载失败: ${error.toString()}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 构建信息展示项
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, overflow: TextOverflow.ellipsis, maxLines: 2),
          ),
        ],
      ),
    );
  }

  // 执行AI操作（耗时任务）
  Future<void> _executeAITask() async {
    // 显示加载弹窗
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    setState(() => _isProcessing = true);

    try {
      // 1. 调用AI服务
      final qa = await AiService.getQA(currentImage);
      if (qa == null) throw Exception('AI服务返回空数据');

      debugPrint('AI生成结果: ${qa.toString()}');

      // 2. 更新到后端API
      final updatedImage = await _updateImageQA(
        imageId: currentImage.imageID,
        questionText: qa.question,
        answers: qa.options,
        rightAnswerIndex: qa.correctAnswer,
        explanation: qa.explanation,
        textCOT: qa.textCOT,
      );

      if (updatedImage == null) throw Exception('图片更新失败');

      // 3. 更新UI状态
      if (mounted) {
        setState(() {
          currentImage = updatedImage;
          _initEditControllers();
          _isEditing = false;
        });
        widget.onImageUpdated(updatedImage);
      }

      // 4. 显示成功提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AI处理完成')));
    } catch (e, stackTrace) {
      debugPrint('AI处理错误: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('处理失败: ${e.toString()}')));
      }
    } finally {
      // 关闭加载弹窗
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isProcessing = false);
      }
    }
  }

  // 构建信息列（右侧/下方内容）
  Widget _buildInfoColumn() {
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
                  _buildInfoItem('文件名', currentImage.fileName ?? '未命名'),
                  _buildInfoItem('分类', currentImage.category),
                  _buildInfoItem('采集类型', currentImage.collectorType),
                  _buildInfoItem('问题方向', currentImage.questionDirection),
                  _buildInfoItem(
                    '难度',
                    currentImage.difficulty?.toString() ?? '未知',
                  ),
                  _buildInfoItem(
                    '状态',
                    ImageState.getStateText(currentImage.state),
                  ),
                  _buildInfoItem('创建日期', currentImage.created_at),
                  _buildInfoItem('更新日期', currentImage.updated_at),
                ],
              ),
            ),
          ),

          // 问题和答案区域
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Card(
              // ... 样式不变 ...
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
                          onPressed: _isProcessing ? null : _executeAITask,
                          icon: const Icon(Icons.auto_awesome),
                          tooltip: 'AI-QA',
                        ),
                        const SizedBox(width: 20),

                        // 编辑按钮
                        if (!_isEditing) // 仅非编辑模式显示
                          IconButton(
                            onPressed: _startEditing,
                            icon: const Icon(Icons.edit),
                            tooltip: '手动修改',
                          ),
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

                    // 切换编辑模式
                    if (_isEditing)
                      _buildEditForm()
                    else
                      // 原有问题和答案展示
                      ...currentImage.questions!
                          .map(_buildQuestionAnswer)
                          .toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行（右上角添加关闭按钮）
            Stack(
              children: [
                Center(
                  child: Text(
                    '${currentImage.imageID}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 右上角关闭按钮
                if (widget.onClose != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: widget.onClose,
                    ),
                  ),
              ],
            ),
            // 内容区域
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth > 700;

                  return isWideScreen
                      ? Row(
                          // 宽屏布局：左图右信息
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 5, child: _buildImageCard()),
                            const SizedBox(width: 20),
                            Expanded(flex: 5, child: _buildInfoColumn()),
                          ],
                        )
                      : Column(
                          // 窄屏布局：上图下信息
                          children: [
                            AspectRatio(
                              aspectRatio: 4 / 3,
                              child: _buildImageCard(),
                            ),
                            const SizedBox(height: 20),
                            Expanded(child: _buildInfoColumn()),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  //添加API更新方法
  Future<ImageModel?> _updateImageQA({
    required int imageId,
    required String questionText,
    String? explanation,
    String? textCOT,
    required List<String> answers,
    required int rightAnswerIndex,
  }) async {
    final url = '${UserSession().baseUrl}/api/image/$imageId/qa';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${UserSession().token ?? ''}',
    };
    final body = jsonEncode({
      'difficulty': currentImage.difficulty ?? 0,
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
}
