import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/question_model.dart';
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
  Size? _imageSize;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    currentImage = widget.image;
    _getImageSize();
  }

  Future<void> _getImageSize() async {
    try {
      final imageUrl = '${UserSession().baseUrl}/img/${currentImage.path}';
      final ImageProvider imageProvider = NetworkImage(imageUrl);
      final Completer<Size> completer = Completer();

      imageProvider
          .resolve(createLocalImageConfiguration(context))
          .addListener(
            ImageStreamListener(
              (ImageInfo info, bool _) {
                if (!completer.isCompleted) {
                  completer.complete(
                    Size(
                      info.image.width.toDouble(),
                      info.image.height.toDouble(),
                    ),
                  );
                }
              },
              onError: (exception, StackTrace? stackTrace) {
                if (!completer.isCompleted) {
                  completer.complete(const Size(0, 0));
                }
              },
            ),
          );

      final size = await completer.future;
      if (size != null && mounted) {
        setState(() => _imageSize = size);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('获取图片尺寸失败: $e')));
      }
    }
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

  // 构建操作按钮
  Widget _buildActionButton(
    String tooltip,
    IconData icon,
    VoidCallback onPressed, {
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 24, color: color),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.grey[50],
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  // 执行AI操作（耗时任务）
  Future<void> _executeAITask() async {
    setState(() => _isProcessing = true);

    try {
      // 模拟耗时操作（真实场景替换为实际API调用）
      await Future.delayed(const Duration(seconds: 3));

      // 创建更新后的图片模型
      final updatedImage = currentImage.copyWith(
        fileName: '${currentImage.fileName} (AI处理)',
      );

      // 更新状态
      setState(() => currentImage = updatedImage);

      // 通知父组件图片已更新
      widget.onImageUpdated(updatedImage);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AI处理完成')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI处理失败: $e')));
    } finally {
      if (mounted) {
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
                  Row(
                    children: [
                      // 分辨率显示
                      if (_imageSize != null)
                        Chip(
                          label: Text(
                            '${_imageSize!.width.toInt()}×${_imageSize!.height.toInt()}',
                            style: TextStyle(
                              color:
                                  (_imageSize!.width < 720 ||
                                      _imageSize!.height < 720)
                                  ? Colors.red
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: Colors.grey[50],
                        ),

                      const Spacer(),

                      // 状态指示器
                      if (_isProcessing) ...[
                        const SizedBox(width: 8),
                        const CircularProgressIndicator(),
                        const SizedBox(width: 8),
                        Text(
                          '处理中...',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

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
                    currentImage.state == 0
                        ? '待处理'
                        : currentImage.state == 1
                        ? '已处理'
                        : '已发布',
                  ),
                  _buildInfoItem('创建日期', currentImage.created_at),
                  _buildInfoItem('更新日期', currentImage.updated_at),

                  const SizedBox(height: 16),

                  // 操作按钮区域
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildActionButton(
                        'AI处理',
                        Icons.auto_awesome,
                        _executeAITask,
                      ),
                      _buildActionButton(
                        '复制信息',
                        Icons.content_copy,
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('图片信息已复制')),
                        ),
                      ),
                      _buildActionButton('更多操作', Icons.more_vert, () {}),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 问题和答案区域
          if (currentImage.questions != null &&
              currentImage.questions!.isNotEmpty)
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
                      const Text(
                        '题目内容',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 遍历所有问题
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
}
