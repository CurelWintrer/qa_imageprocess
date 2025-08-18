import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/model/work_model.dart';
import 'package:qa_imageprocess/user_session.dart';

class WorkDetailScreen extends StatefulWidget {
  final int workID;

  const WorkDetailScreen({super.key, required this.workID});

  @override
  State<WorkDetailScreen> createState() => _WorkDetailScreenState();
}

class _WorkDetailScreenState extends State<WorkDetailScreen> {
  WorkModel? _work;
  List<ImageModel> _images = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String _errorMessage = '';
  int _columnCount = 4; // 默认4列

  @override
  void initState() {
    super.initState();
    _fetchWorkDetails();
  }

  // 列数切换方法
  void _toggleColumnCount() {
    setState(() {
      _columnCount = _columnCount >= 8 ? 4 : _columnCount + 1;
    });
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
            // 解析工作信息
            _work = WorkModel.fromJson(workData['work']);

            // 解析图片列表
            final imageData = workData['images'];
            final pagination = imageData['pagination'];

            _currentPage = pagination['currentPage'];
            _totalPages = pagination['totalPages'];

            final newImages = (imageData['data'] as List)
                .map((imgJson) => ImageModel.fromJson(imgJson))
                .toList();

            // 新增分页加载，追加图片
            _images.addAll(newImages);
            _hasMore = _currentPage < _totalPages;
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

  // 加载更多图片
  void _loadMoreImages() {
    if (_hasMore && !_isLoading) {
      _currentPage++;
      _fetchWorkDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('工作详情 #${widget.workID}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view),
            onPressed: _toggleColumnCount,
            tooltip: '切换列数',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: _toggleColumnCount,
        tooltip: '切换列数 ($_columnCount)',
        child: Text('$_columnCount列'),
      ),
    );
  }

  Widget _buildBody() {
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

    return Column(
      children: [
        // 网格布局
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              // 滚动到底部加载更多
              if (scrollInfo.metrics.pixels ==
                  scrollInfo.metrics.maxScrollExtent) {
                _loadMoreImages();
              }
              return true;
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columnCount,
                childAspectRatio: 0.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _images.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _images.length) {
                  return _buildLoadMoreIndicator();
                }
                return _buildGridItem(_images[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  // 网格项组件
  Widget _buildGridItem(ImageModel image) {
    final firstQuestion = image.questions?.isNotEmpty == true
        ? image.questions?.first
        : null;

    return Card(
      elevation: 2,
      child: Column(
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

          // 图片信息
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '图片 #${image.imageID}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
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
        ],
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

  // 加载更多指示器
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
}
