import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/user_session.dart';

class GetSimilarImage extends StatefulWidget {
  const GetSimilarImage({super.key});

  @override
  State<GetSimilarImage> createState() => _GetSimilarImageState();
}

class _GetSimilarImageState extends State<GetSimilarImage> {

    // 类目相关状态
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  // 采集类型相关状态
  List<Map<String, dynamic>> _collectorTypes = [];
  String? _selectedCollectorTypeId;

  // 问题方向相关状态
  List<Map<String, dynamic>> _questionDirections = [];
  String? _selectedQuestionDirectionId;

  @override
  void initState(){
    super.initState();
    _fetchCategories();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('相似查询')),
      body: Column(
        children: [
          _buildTitleSelector()
        ],
      ),
    );
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
      child:Row(
        children: [
            _buildCategoryDropdown(),
            SizedBox(width: 20),
            _buildCollectorTypeDropdown(),
            SizedBox(width: 20),
            _buildQuestionDirectionDropdown(),
            SizedBox(width: 20),
            IconButton(onPressed: ()=>{}, icon: Icon(Icons.folder),tooltip: '选择文件夹'),
            SizedBox(width: 20),
            SizedBox(
              width: 150,
              height: 45,
              child: ElevatedButton(
                onPressed: () => {},
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
        ],
      ),
    );
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
    // 修复：直接构建菜单项列表
    final items = [
      // 添加空选项
      DropdownMenuItem<String?>(
        value: null,
        child: Text('未选择', style: TextStyle(color: Colors.grey)),
      ),
      // 添加其他选项
      ...options.map((id) {
        return DropdownMenuItem<String?>(
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

}