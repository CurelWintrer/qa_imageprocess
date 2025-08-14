import 'package:flutter/material.dart';
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
  final _editController = TextEditingController();
  String? _editingField;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.image;
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _startEditing(String fieldName, String currentValue) {
    _editingField = fieldName;
    _editController.text = currentValue;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("编辑${_fieldDisplayName(fieldName)}"),
        content: TextField(
          controller: _editController,
          autofocus: true,
          maxLines: fieldName == 'answer' || fieldName == 'question' ? 3 : 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _updateField(_editingField!, _editController.text);
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _updateField(String field, String value) {
    setState(() {
      if (field == 'question' &&
          _currentImage.questions != null &&
          _currentImage.questions!.isNotEmpty) {
        // 更新第一个问题的问题文本
        final firstQuestion = _currentImage.questions!.first;
        final updatedQuestion = firstQuestion.copyWith(questionText: value);
        _currentImage = _currentImage.copyWith(
          questions: [updatedQuestion, ..._currentImage.questions!.sublist(1)],
        );
      } else if (field == 'answer' &&
          _currentImage.questions != null &&
          _currentImage.questions!.isNotEmpty) {
        // 更新第一个问题的正确答案文本
        final firstQuestion = _currentImage.questions!.first;
        final updatedRightAnswer = firstQuestion.rightAnswer.copyWith(
          answerText: value,
        );
        final updatedQuestion = firstQuestion.copyWith(
          rightAnswer: updatedRightAnswer,
        );
        _currentImage = _currentImage.copyWith(
          questions: [updatedQuestion, ..._currentImage.questions!.sublist(1)],
        );
      } else {
        // 其他字段的更新
        _currentImage = _currentImage.copyWith(
          fileName: field == 'fileName' ? value : _currentImage.fileName,
          category: field == 'category' ? value : _currentImage.category,
          difficulty: field == 'difficulty' ? value : _currentImage.difficulty,
        );
      }
    });
    widget.onImageUpdated(_currentImage);
  }

  void _changeState(int newState) {
    setState(() {
      _currentImage = _currentImage.copyWith(state: newState);
    });
    widget.onImageUpdated(_currentImage);
  }

  Future<void> _runAiTask() async {
    if (widget.onLongRunningTask == null) {
      // 直接在组件中执行
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 3)); // 模拟耗时任务

      // 创建更新后的问题和答案
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
      });
      widget.onImageUpdated(updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("AI分析完成")));
    } else {
      // 将任务交给父组件处理
      final task = () async {
        await Future.delayed(const Duration(seconds: 3)); // 实际调用AI

        // 创建更新后的问题和答案
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

  String _fieldDisplayName(String field) {
    const names = {
      'fileName': '文件名',
      'category': '类别',
      'collectorType': '收集类型',
      'questionDirection': '问题方向',
      'question': '问题',
      'answer': '答案',
      'difficulty': '难度',
    };
    return names[field] ?? field;
  }

  Widget _buildDetailRow(String title, String? value, {bool editable = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: editable
                ? InkWell(
                    onTap: () =>
                        _startEditing(title.toLowerCase(), value ?? ''),
                    child: Text(
                      value ?? '未设置',
                      style: TextStyle(
                        color: value == null ? Colors.grey : null,
                      ),
                    ),
                  )
                : Text(value ?? '无'),
          ),
        ],
      ),
    );
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
            _buildDetailRow('文件名', _currentImage.fileName, editable: false),
            _buildDetailRow('类别', _currentImage.category, editable: false),
            _buildDetailRow(
              '收集类型',
              _currentImage.collectorType,
              editable: false,
            ),
            _buildDetailRow(
              '问题方向',
              _currentImage.questionDirection,
              editable: false,
            ),

            // 显示第一个问题的问题文本
            if (_currentImage.questions != null &&
                _currentImage.questions!.isNotEmpty)
              _buildDetailRow(
                '问题',
                _currentImage.questions!.first.questionText,
              ),

            // 显示第一个问题的正确答案文本
            if (_currentImage.questions != null &&
                _currentImage.questions!.isNotEmpty)
              _buildDetailRow(
                '答案',
                _currentImage.questions!.first.rightAnswer.answerText,
              ),

            _buildDetailRow('难度', _currentImage.difficulty),
            const SizedBox(height: 20),
            _buildStateInfo(),
            const SizedBox(height: 20),
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
            // color: ImageState.withOpacity(0.2),
            color: ImageState.getStateColor(
              _currentImage.state,
            ).withOpacity(0.2),
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
          // 宽屏布局：左右结构
          return Scaffold(
            body: Stack(
              children: [
                // 主内容
                Row(
                  children: [
                    _buildImageSection(),
                    const VerticalDivider(width: 1),
                    _buildInfoSection(),
                  ],
                ),
                // 添加关闭按钮（适合在弹窗中显示）
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
          // 窄屏布局：上下结构
          return Scaffold(
            body: Stack(
              children: [
                // 主内容
                Column(
                  children: [
                    _buildImageSection(),
                    const Divider(height: 1),
                    Expanded(child: _buildInfoSection()),
                  ],
                ),
                // 添加关闭按钮（适合在弹窗中显示）
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
