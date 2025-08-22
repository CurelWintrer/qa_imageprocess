import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/prompt/category_model.dart';
import 'package:qa_imageprocess/model/prompt/qa_response.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/user_session.dart';

class AiService {
  static final Duration _TimeOut = Duration(seconds: 50);

  static List<CategoryModel> categorys = [];
  static String rule = '';
  static String formatRule = '';

  static Future<void> initData() async {
    try {
      // 1. 加载JSON文件
      final jsonString = await rootBundle.loadString('assets/prompt.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // 2. 解析规则字符串
      rule = jsonData['rule']?.toString() ?? '';

      // 3. 解析formatRule为JSON字符串
      final formatRuleObj = jsonData['formatRule'];
      if (formatRuleObj != null) {
        formatRule = jsonEncode(formatRuleObj);
      }

      // 4. 解析分类数据
      final data = jsonData['data'] as Map<String, dynamic>?;
      final categoriesJson = data?['categorys'] as List<dynamic>?;

      if (categoriesJson != null) {
        categorys = categoriesJson.map((e) {
          return CategoryModel.fromJson(e as Map<String, dynamic>);
        }).toList();
      }
    } catch (e) {
      // 错误处理
      print('Error loading prompt data: $e');
      // 可以根据需要设置默认值
      rule = 'Failed to load rules';
      formatRule = 'Failed to load format rules';
    }
  }

  static Future<QaResponse?> getQA(
    ImageModel image, {
    int questionDifficulty = 0,
  }) async {
    try {
      // 1. 发送请求
      final response = await http.post(
        Uri.parse(UserSession().apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${UserSession().apiKey}',
        },
        body: await _getRequestBody(image),
      );

      // 2. 检查HTTP状态码
      if (response.statusCode != 200) {
        throw HttpException('请求失败，状态码: ${response.statusCode}');
      }

      // 3. 解析响应体
      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      print(responseBody);

      // 4. 提取content内容
      final content = _extractContent(responseBody);
      if (content == null) {
        throw FormatException('响应中缺少有效content');
      }

      // 5. 解析为QaResponse对象
      return QaResponse.parseContent(content);
    } on http.ClientException catch (e) {
      print('网络请求异常: $e');
      return null;
    } on FormatException catch (e) {
      print('JSON解析失败: $e');
      return null;
    } catch (e) {
      print('未知错误: $e');
      return null;
    }
  }

  // 辅助方法：从响应体中提取content
  static String? _extractContent(Map<String, dynamic> responseBody) {
    try {
      final choices = responseBody['choices'] as List;
      if (choices.isEmpty) return null;

      final firstChoice = choices.first as Map<String, dynamic>;
      return firstChoice['message']['content'] as String;
    } catch (e) {
      return null;
    }
  }

  static String getPrompt(
    List<CategoryModel> categorys,
    ImageModel image, {
    int questionDifficulty = 0,
  }) {
    // print(image.category);
    CategoryModel? category = categorys.firstWhere(
      (item) => item.categoryName == image.category,
    );
    print(category.categoryName);
    return '''请仔细观察这张图片，基于图片内容生成一个${category.categoryName}类问题。${category.prompt}
    问题必须符合以下要求：
    ${category.difficulties[image.difficulty ?? 0]};
    当前图片提问方向：${image.collectorType}的${image.questionDirection};
    难度等级：${image.difficulty}(${ImageState.getDifficulty(image.difficulty ?? 0)});
    ${getPromptRule(image,questionDifficulty: questionDifficulty)};
    【输出格式要求】：
    $formatRule
    (correct_answer是正确答案位置索引);
    ''';
  }
  //    问题参考样例：
    //${category.example};

  static String getPromptRule(ImageModel image, {int questionDifficulty = 0}) {
    switch (image.category) {
      case 'single_instance_reasoning（单实例推理）':
        switch (questionDifficulty) {
          case 0:
            return '''
            画面主体是${image.category},你要对画面主体的${image.questionDirection}结合相关的外部知识进行提问，满足基础的推理性问题;
          ''';
          case 1:
          return '''
            画面主体是${image.category},你要对画面主体的${image.questionDirection}结合相关的外部知识进行提问，满足较复杂的推理性问题;
          ''';
          default:
          return '';
        }

      case 'common reasoning（常识推理）'||'statistical reasoning（统计推理）'||'diagram reasoning（图表推理）':
        switch (questionDifficulty){
          case 0:
          return '''
            需要结合外部知识进行推理；
            对画面的${image.questionDirection}结合相关${image.collectorType}外部知识进行提问，满足单步的推理。
            ''';
          case 1:
          return '''
            需要结合外部知识进行推理；
            对画面的${image.questionDirection}结合相关${image.collectorType}外部知识进行提问，满足多部的推理。
            ''';
          default:
          return '';
        }
      case 'geography_earth_agri（地理&地球科学&农业）':
        switch (questionDifficulty){
          case 0:
          return '''
            对画面的${image.questionDirection}结合相关初中知识知识进行提问。
            ''';
          case 1:
          return '''
            对画面的${image.questionDirection}结合高中知识进行提问。
            ''';
          default:
          return '';
        }
      default:
        return '';
    }
  }

  static Future<String> _getRequestBody(
    ImageModel image, {
    int questionDifficulty = 0,
  }) async {
    String imageBase64 = await downloadImageAndConvertToBase64(
      '${UserSession().baseUrl}/${image.path}',
    );
    String prompt = getPrompt(
      categorys,
      image,
      questionDifficulty: questionDifficulty,
    );
    print('提示词：$prompt');
    final requestBody = {
      'model': UserSession().modelName,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
            },
          ],
        },
      ],
      'max_tokens': 3000,
      'temperature': 0.7,
    };

    return jsonEncode(requestBody);
  }

  // 下载图片并转换为base64
  static Future<String> downloadImageAndConvertToBase64(String imgUrl) async {
    try {
      final response = await http.get(Uri.parse(imgUrl));
      if (response.statusCode == 200) {
        return base64Encode(response.bodyBytes);
      } else {
        throw Exception('图片下载失败, HTTP状态码: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('图片处理错误: $e');
    }
  }
}
