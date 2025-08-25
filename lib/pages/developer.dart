import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:qa_imageprocess/model/release.dart';
import 'dart:io';

import 'package:qa_imageprocess/user_session.dart';

class Developer extends StatefulWidget {
  const Developer({super.key});

  @override
  State<Developer> createState() => _DeveloperState();
}

class _DeveloperState extends State<Developer> {
  List<Release> releases = [];
  File? selectedFile;
  String versionNumber = '';
  String softwareName = '';
  String releaseLog = '';
  bool isLoading = false;

  final TextEditingController _versionController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _logController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchReleases();
  }

  // 获取版本列表
  Future<void> fetchReleases() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final response = await http.get(
        Uri.parse('${UserSession().baseUrl}/api/releases'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          releases = (data['data'] as List)
              .map((item) => Release.fromJson(item))
              .toList();
        });
      } else {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(content: Text('获取版本列表失败: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text('获取版本列表出错: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 选择文件
  Future<void> selectFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    
    if (result != null) {
      setState(() {
        selectedFile = File(result.files.single.path!);
        // 自动填充软件名称
        if (_nameController.text.isEmpty) {
          _nameController.text = basename(selectedFile!.path);
        }
      });
    }
  }

  // 上传新版本
  Future<void> uploadRelease() async {
    if (selectedFile == null) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        const SnackBar(content: Text('请先选择文件')),
      );
      return;
    }
    
    if (versionNumber.isEmpty || softwareName.isEmpty) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        const SnackBar(content: Text('请填写版本号和软件名称')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${UserSession().baseUrl}/api/releases/upload'),
      );
      
      // 添加文件
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        selectedFile!.path,
      ));
      
      // 添加其他字段
      request.fields['versionNumber'] = versionNumber;
      request.fields['softwareName'] = softwareName;
      request.fields['releaseLog'] = releaseLog;
      
      var response = await request.send();
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          const SnackBar(content: Text('上传成功')),
        );
        // 清空表单
        _versionController.clear();
        _nameController.clear();
        _logController.clear();
        setState(() {
          selectedFile = null;
          versionNumber = '';
          softwareName = '';
          releaseLog = '';
        });
        // 刷新列表
        fetchReleases();
      } else {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(content: Text('上传失败: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text('上传出错: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开发者选项')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 上传新版本部分
                  const Text(
                    '上传新版本',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // 文件选择
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: selectFile,
                        child: const Text('选择文件'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          selectedFile?.path ?? '未选择文件',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 版本信息表单
                  TextField(
                    controller: _versionController,
                    decoration: const InputDecoration(
                      labelText: '版本号',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => versionNumber = value),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '软件名称',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => softwareName = value),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _logController,
                    decoration: const InputDecoration(
                      labelText: '发布日志',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (value) => setState(() => releaseLog = value),
                  ),
                  const SizedBox(height: 16),
                  
                  Center(
                    child: ElevatedButton(
                      onPressed: uploadRelease,
                      child: const Text('上传'),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // 版本列表
                  const Text(
                    '版本列表',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: releases.isEmpty
                        ? const Center(child: Text('暂无版本信息'))
                        : ListView.builder(
                            itemCount: releases.length,
                            itemBuilder: (context, index) {
                              final release = releases[index];
                              return Card(
                                child: ListTile(
                                  title: Text('${release.softwareName} - ${release.versionNumber}'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(release.releaseLog),
                                      const SizedBox(height: 4),
                                      Text('发布时间: ${release.releaseTime}'),
                                    ],
                                  ),
                                ),
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

