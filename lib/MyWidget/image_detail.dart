import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/model/answer_model.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/user_session.dart';

class ImageDetail extends StatefulWidget {
  final ImageModel image;
  final Function(ImageModel) onImageUpdated;
  final Function(Future<ImageModel> Function())? onLongRunningTask;

  const ImageDetail({
    super.key,
    required this.image,
    required this.onImageUpdated,
    this.onLongRunningTask,
  });

  @override
  State<ImageDetail> createState() => _ImageDetailState();
}

class _ImageDetailState extends State<ImageDetail> {
  late ImageModel _currentImage;
  final _questionController = TextEditingController();
  final _difficultyController = TextEditingController();
  List<TextEditingController> _answerControllers = [];
  int _correctAnswerIndex = 0;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEditingQA = false;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.image;
    _initializeControllers();
  }

  void _initializeControllers() {
    // 初始化问题控制器
    if (_currentImage.questions != null &&
        _currentImage.questions!.isNotEmpty) {
      _questionController.text = _currentImage.questions!.first.questionText;

      // 初始化答案控制器
      _answerControllers = _currentImage.questions!.first.answers
          .map((a) => TextEditingController(text: a.answerText))
          .toList();

      // 设置正确答案索引
      _correctAnswerIndex = _currentImage.questions!.first.answers.indexWhere(
        (a) =>
            a.answerID == _currentImage.questions!.first.rightAnswer.answerID,
      );
      if (_correctAnswerIndex == -1) _correctAnswerIndex = 0;
    } else {
      // 如果没有问题，初始化默认值
      _questionController.text = '';
      _answerControllers = [TextEditingController(), TextEditingController()];
      _correctAnswerIndex = 0;
    }

    // 初始化难度控制器
    _difficultyController.text = ImageState.getDifficulty(
      _currentImage.difficulty ?? 3,
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _difficultyController.dispose();
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changeState(int newState) {
    setState(() {
      _currentImage = _currentImage.copyWith(state: newState);
    });
    widget.onImageUpdated(_currentImage);
  }

  void _toggleQAEditing() {
    setState(() {
      _isEditingQA = !_isEditingQA;
      if (!_isEditingQA) {
        // 重置控制器状态
        _initializeControllers();
      }
    });
  }

  void _addAnswerOption() {
    setState(() {
      _answerControllers.add(TextEditingController());
    });
  }

  void _removeAnswerOption(int index) {
    setState(() {
      if (_answerControllers.length > 2) {
        _answerControllers.removeAt(index);
        if (_correctAnswerIndex == index) {
          _correctAnswerIndex = 0;
        } else if (_correctAnswerIndex > index) {
          _correctAnswerIndex--;
        }
      }
    });
  }

  Widget _buildQAEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 问题编辑
        const Text('问题:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _questionController,
          maxLines: 2,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '输入问题内容',
          ),
        ),
        const SizedBox(height: 16),

        // 答案选项编辑
        const Text('答案选项:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._answerControllers.asMap().entries.map((entry) {
          int idx = entry.key;
          TextEditingController controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Radio<int>(
                  value: idx,
                  groupValue: _correctAnswerIndex,
                  onChanged: (value) {
                    setState(() => _correctAnswerIndex = value!);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: '答案选项 ${idx + 1}',
                      suffixIcon: _answerControllers.length > 2
                          ? IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _removeAnswerOption(idx),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        // 添加答案按钮
        TextButton(
          onPressed: _addAnswerOption,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.add), Text('添加答案选项')],
          ),
        ),
        const SizedBox(height: 16),

        // 难度选择
        const Text('难度:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _difficultyController.text,
          items: ['简单', '中等', '困难']
              .map(
                (level) => DropdownMenuItem(value: level, child: Text(level)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              _difficultyController.text = value;
            }
          },
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),

        // 保存和取消按钮
        Row(
          children: [
            ElevatedButton(
              onPressed: _isSaving ? null : _updateQuestionAndAnswers,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存更改'),
            ),
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: _isSaving ? null : _toggleQAEditing,
              child: const Text('取消'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQAViewer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 问题显示
        const Text('问题:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          _currentImage.questions != null && _currentImage.questions!.isNotEmpty
              ? _currentImage.questions!.first.questionText
              : '未设置问题',
        ),
        const SizedBox(height: 16),

        // 答案选项显示
        const Text('答案选项:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_currentImage.questions != null &&
            _currentImage.questions!.isNotEmpty &&
            _currentImage.questions!.first.answers.isNotEmpty)
          ..._currentImage.questions!.first.answers.asMap().entries.map((
            entry,
          ) {
            AnswerModel answer = entry.value;
            bool isCorrect =
                answer.answerID ==
                _currentImage.questions!.first.rightAnswer.answerID;

            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isCorrect ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      answer.answerText,
                      style: TextStyle(
                        color: isCorrect ? Colors.green : null,
                        fontWeight: isCorrect ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList()
        else
          const Text('未设置答案选项'),
        const SizedBox(height: 16),

        // 难度显示
        const Text('难度:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(ImageState.getDifficulty(_currentImage.difficulty ?? 3)),
        const SizedBox(height: 20),

        // 编辑QA按钮
        ElevatedButton(onPressed: _toggleQAEditing, child: const Text('更改QA')),
      ],
    );
  }

  // 更新问题API调用
  Future<void> _updateQuestionAndAnswers() async {
    setState(() => _isSaving = true);

    try {
      // 收集答案文本
      List<String> newAnswerTexts = _answerControllers
          .where((c) => c.text.isNotEmpty)
          .map((c) => c.text)
          .toList();

      if (newAnswerTexts.length < 2) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请至少添加两个选项')));
        return;
      }

      if (_correctAnswerIndex >= newAnswerTexts.length) {
        _correctAnswerIndex = 0;
      }

      final response = await http.put(
        Uri.parse(
          '${UserSession().baseUrl}/api/image/${_currentImage.imageID}/qa',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${UserSession().token}',
        },
        body: json.encode({
          'difficulty': ImageState.getDifficultyValue(
            _difficultyController.text,
          ),
          'questionText': _questionController.text,
          'answers': newAnswerTexts,
          'rightAnswerIndex': _correctAnswerIndex,
        }),
      );

      print(response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['code'] == 200) {
          final updatedImage = ImageModel.fromJson(data['data']);
          setState(() {
            _currentImage = updatedImage;
            _isEditingQA = false;
          });
          widget.onImageUpdated(updatedImage);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('更新成功')));
        } else {
          throw Exception('API error: ${data['message']}');
        }
      } else {
        throw Exception('HTTP error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _runAiTask() async {
    if (widget.onLongRunningTask == null) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 3));

      final newQuestion = QuestionModel(
        questionID: 0,
        questionText: "AI生成的问题",
        rightAnswer: AnswerModel(answerID: 0, answerText: "AI生成的答案"),
        answers: [],
      );

      final updated = _currentImage.copyWith(questions: [newQuestion]);

      setState(() {
        _currentImage = updated;
        _isLoading = false;
        _initializeControllers();
      });
      widget.onImageUpdated(updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("AI分析完成")));
    } else {
      final task = () async {
        await Future.delayed(const Duration(seconds: 3));
        final newQuestion = QuestionModel(
          questionID: 0,
          questionText: "AI生成的问题",
          rightAnswer: AnswerModel(answerID: 0, answerText: "AI生成的答案"),
          answers: [],
        );
        return _currentImage.copyWith(questions: [newQuestion]);
      };
      widget.onLongRunningTask!(task);
    }
  }


  Widget _buildImageSection() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(100),
          minScale: 0.1,
          maxScale: 4.0,
          child: _currentImage.path != null
              ? Image.network(
                  '${UserSession().baseUrl}/${_currentImage.path}',
                  fit: BoxFit.contain,
                )
              : const Placeholder(),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '图片详情 (ID: ${_currentImage.imageID})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Text(
              '文件名: ${_currentImage.fileName ?? '未设置'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '类别: ${_currentImage.category}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '收集类型: ${_currentImage.collectorType}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '问题方向: ${_currentImage.questionDirection}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // QA编辑/查看区域
            _isEditingQA ? _buildQAEditor() : _buildQAViewer(),
            const SizedBox(height: 20),
            
            // 审核状态
            _buildStateInfo(),
            const SizedBox(height: 20),
            
            // 操作按钮
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStateInfo() {
    return Row(
      children: [
        const Text('审核状态: ', style: TextStyle(fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: ImageState.getStateColor(_currentImage.state).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            ImageState.getStateText(_currentImage.state),
            style: TextStyle(
              color: ImageState.getStateColor(_currentImage.state),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (_currentImage.state != 1)
          ElevatedButton(
            onPressed: () => _changeState(1),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('审核通过'),
          ),
        if (_currentImage.state != 2)
          ElevatedButton(
            onPressed: () => _changeState(2),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('审核拒绝'),
          ),
        ElevatedButton(
          onPressed: _isLoading ? null : _runAiTask,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('AI分析'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 800;
        final bool isInDialog =
            constraints.maxWidth < MediaQuery.of(context).size.width;

        if (isWide) {
          return Scaffold(
            body: Stack(
              children: [
                Row(
                  children: [
                    _buildImageSection(),
                    const VerticalDivider(width: 1),
                    _buildInfoSection(),
                  ],
                ),
                if (isInDialog)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
              ],
            ),
          );
        } else {
          return Scaffold(
            body: Stack(
              children: [
                Column(
                  children: [
                    _buildImageSection(),
                    const Divider(height: 1),
                    Expanded(child: _buildInfoSection()),
                  ],
                ),
                if (isInDialog)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
              ],
            ),
          );
        }
      },
    );
  }
}
