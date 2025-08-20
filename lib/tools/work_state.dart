import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:qa_imageprocess/model/work_model.dart';
import 'package:qa_imageprocess/user_session.dart';

class WorkState {
  /// 提交工作任务并更新状态
  /// 
  /// 主要变更：成功回调中携带更新后的WorkModel对象
  /// 
  /// 参数:
  ///   [context] - 当前BuildContext（用于显示SnackBar）
  ///   [work] - 要更新的任务模型
  ///   [state] - 要设置的新状态值
  ///   [onSuccess] - 操作成功时的回调，携带更新后的WorkModel
  ///   [onError] - 操作失败时的回调，携带异常信息
  static Future<void> submitWork(
    BuildContext context,
    WorkModel work,
    int state, {
    // 修改成功回调：携带更新后的WorkModel对象
    ValueChanged<WorkModel>? onSuccess,
    ValueChanged<Exception>? onError,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${UserSession().baseUrl}/api/works/status/${work.workID}'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token ?? ''}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'state': state}),
      );

      print('API响应: ${response.body}');

      if (response.statusCode == 200) {
        // 解析API返回的JSON数据
        final jsonData = json.decode(response.body);
        
        // 验证API响应格式
        if (jsonData['data'] == null) {
          throw FormatException('API响应缺少数据字段');
        }
        
        // 将JSON转换为WorkModel对象
        final updatedWork = WorkModel.fromJson(jsonData['data']);
        
        // 显示成功通知
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交成功'))
        );
        
        // 执行成功回调并传递更新后的WorkModel
        if (onSuccess != null) onSuccess(updatedWork);
      } else {
        // 处理HTTP错误状态码
        final errorJson = json.decode(response.body);
        final errorMessage = errorJson['message'] ?? '未知错误';
        final statusMessage = '提交失败 (${response.statusCode}): $errorMessage';
        
        // 显示错误通知
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(statusMessage))
        );
        

      }
    } catch (e) {
      // 处理请求过程中的其他异常
      final errorMsg = '提交出错: ${e.toString()}';
      
      // 显示错误通知
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg))
      );

    }
  }
}

