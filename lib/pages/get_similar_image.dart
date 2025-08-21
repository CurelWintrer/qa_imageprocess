import 'package:flutter/material.dart';

class GetSimilarImage extends StatefulWidget {
  const GetSimilarImage({super.key});

  @override
  State<GetSimilarImage> createState() => _GetSimilarImageState();
}

class _GetSimilarImageState extends State<GetSimilarImage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('相似查询')),
    );
  }
}