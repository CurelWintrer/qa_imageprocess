import 'package:flutter/material.dart';
import 'package:qa_imageprocess/model/checkImageListState.dart';
import 'package:qa_imageprocess/model/checkImageList_model.dart';
import 'package:qa_imageprocess/user_session.dart';

class ReviewList extends StatefulWidget {
  const ReviewList({super.key});

  @override
  State<ReviewList> createState() => _ReviewListState();
}

class _ReviewListState extends State<ReviewList> {
  String _token = UserSession().token ?? '';
  String _baseUrl = UserSession().baseUrl;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryCard('总任务数', '', Icons.list),
                      _buildSummaryCard('未检查', '', Icons.pending_actions),
                      _buildSummaryCard('检查中', '', Icons.hourglass_top),
                      _buildSummaryCard('已完成', '', Icons.check_circle),
                    ],
                  ),
                ),
                SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => {},
                  tooltip: '拉取新任务',
                ),
                SizedBox(width: 20),
                IconButton(
                  onPressed: () => {},
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新列表',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckListItem(CheckimagelistModel checkImageList_model) {
    return Row(
      children: [
        //任务ID
        Column(
          children: [
            Text('任务 ${checkImageList_model.checkImageListID.toString()}'),
            Row(
              children: [
                Text('${checkImageList_model.imageCount.toString()}张图片'),
                Text('已检查${checkImageList_model.accessCount.toString()}张'),
              ],
            ),
          ],
        ),

        Text('类目：'),

        Column(
          children: [
            // 状态标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Checkimageliststate.getCheckImageListStateColor(
                  checkImageList_model.state,
                ).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Checkimageliststate.getCheckImageListStateColor(
                    checkImageList_model.state,
                  ),
                  width: 1,
                ),
              ),
              child: Text(
                Checkimageliststate.getCheckImageListState(
                  checkImageList_model.state,
                ),
                style: TextStyle(
                  color: Checkimageliststate.getCheckImageListStateColor(
                    checkImageList_model.state,
                  ),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

            ElevatedButton(
              onPressed: () => {
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('质检', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }

  // Future<void> _fetchAllTasks() async {
  //   if (_token == null || isLoading) return;
  //   setState(() {
  //     isLoading = true;
  //     errorMessage = null;
  //     allTasks = []; // 重置任务列表
  //     allDataLoaded = false; // 重置加载状态
  //     currentPage = 1; // 重置到第一页
  //   });

  //   try {
  //     int page = 1;
  //     List<dynamic> loadedTasks = [];
  //     bool hasMore = true;

  //     // 循环加载所有数据
  //     while (hasMore && !allDataLoaded) {
  //       final response = await http.get(
  //         Uri.parse(
  //           '${UserSession().baseUrl}/api/check-tasks/user?page=$page&limit=100', // 一次加载较多数据以减少请求次数
  //         ),
  //         headers: {'Authorization': 'Bearer $token'},
  //       );

  //       if (response.statusCode == 200) {
  //         final data = json.decode(response.body);
  //         loadedTasks.addAll(data['tasks']);
  //         totalTasks = data['total'];

  //         if (loadedTasks.length >= data['total'] || data['tasks'].isEmpty) {
  //           hasMore = false;
  //           allDataLoaded = true;
  //         }

  //         page++;
  //       } else {
  //         hasMore = false;
  //         if (response.statusCode == 401) {
  //           setState(() {
  //             errorMessage = '未授权或token无效';
  //           });
  //         } else {
  //           setState(() {
  //             errorMessage = '服务器错误: ${response.statusCode}';
  //           });
  //         }
  //       }
  //     }

  //     setState(() {
  //       allTasks = loadedTasks;
  //       totalPages = (allTasks.length / itemsPerPage).ceil();
  //       _updateDisplayedTasks();
  //     });
  //   } catch (e) {
  //     setState(() {
  //       errorMessage = '网络错误: $e';
  //     });
  //   } finally {
  //     setState(() {
  //       isLoading = false;
  //       _updateDisplayedTasks(); // 确保更新显示的任务
  //     });
  //   }
  // }
}
