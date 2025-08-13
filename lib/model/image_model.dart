class ImageModel {
  final int imageID;
  final String? fileName;
  final String category;
  final String collectorType;
  final String questionDirection;
  final String? question;
  final String? answer;
  final String? difficulty;
  final String? path;
  final int state;
  final String created_at;
  final String updated_at;
  final int originatorID;
  final int? checkImageListID;
  final Originator originator;

  ImageModel({
    required this.imageID,
    this.fileName,
    required this.category,
    required this.collectorType,
    required this.questionDirection,
    this.question,
    this.answer,
    this.difficulty,
    this.path,
    required this.state,
    required this.created_at,
    required this.updated_at,
    required this.originatorID,
    this.checkImageListID,
    required this.originator,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    return ImageModel(
      imageID: json['id'] as int,
      fileName: json['file_name'] as String?,
      category: json['category'] as String,
      collectorType: json['collector_type'] as String,
      questionDirection: json['question_direction'] as String,
      question: json['question'] as String?,
      answer: json['answer'] as String?,
      difficulty: json['difficulty'] as String?,
      path: json['path'] as String?,
      state: json['state'] as int,
      created_at: json['created_at'] as String,
      updated_at: json['updated_at'] as String,
      // 从originator对象中获取id
      originatorID: (json['originator'] as Map<String, dynamic>)['id'] as int,
      checkImageListID: json['check_image_list_id'] as int?,
      originator: Originator.fromJson(json['originator'] as Map<String, dynamic>),
    );
  }

  ImageModel copyWith({
    int? imageID,
    String? fileName,
    String? category,
    String? collectorType,
    String? questionDirection,
    String? question,
    String? answer,
    String? difficulty,
    String? path,
    int? state,
    String? created_at,
    String? updated_at,
    int? originatorID,
    int? checkImageListID,
    Originator? originator,
  }) {
    return ImageModel(
      imageID: imageID ?? this.imageID,
      fileName: fileName ?? this.fileName,
      category: category ?? this.category,
      collectorType: collectorType ?? this.collectorType,
      questionDirection: questionDirection ?? this.questionDirection,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      difficulty: difficulty ?? this.difficulty,
      path: path ?? this.path,
      state: state ?? this.state,
      created_at: created_at ?? this.created_at,
      updated_at: updated_at ?? this.updated_at,
      originatorID: originatorID ?? this.originatorID,
      checkImageListID: checkImageListID ?? this.checkImageListID,
      originator: originator ?? this.originator,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': imageID,
      'file_name': fileName,
      'category': category,
      'collector_type': collectorType,
      'question_direction': questionDirection,
      'question': question,
      'answer': answer,
      'difficulty': difficulty,
      'path': path,
      'state': state,
      'created_at': created_at,
      'updated_at': updated_at,
      'originator_id': originatorID, // 这里保持与原始JSON一致
      'check_image_list_id': checkImageListID,
      'originator': originator.toJson(),
    };
  }

  @override
  String toString() {
    return 'ImageModel(imageID: $imageID, fileName: $fileName, category: $category)';
  }
}

class Originator {
  final int id;
  final String name;

  Originator({
    required this.id,
    required this.name,
  });

  factory Originator.fromJson(Map<String, dynamic> json) {
    return Originator(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  String toString() {
    return 'Originator(id: $id, name: $name)';
  }
}