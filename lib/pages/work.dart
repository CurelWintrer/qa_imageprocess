import 'package:flutter/material.dart';

class Work extends StatefulWidget {
  const Work({super.key});

  @override
  State<Work> createState() => _WorkState();
}

class _WorkState extends State<Work> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }

    Widget _buildTitleSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          // 采集类目
          // _buildLevelDropdown(

          // ),
          // // 采集类型
          // _buildLevelDropdown(

          // ),

          // // 图片问题方向
          // _buildLevelDropdown(

          // ),
          // 搜索按钮
          ElevatedButton(
            onPressed: () => {

            },
            child: Text('查询'),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelDropdown({
    required String? value,
    required List<String> options,
    required String hint,
    bool enabled = true,
    ValueChanged<String?>? onChanged,
  }) {
    // 确保当前值存在于选项中
    final effectiveValue = options.contains(value) ? value : null;
    return Container(
      width: 180,
      child: DropdownButtonFormField<String>(
        value: effectiveValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(),
        ),
        items: [
          if (options.isEmpty)
            DropdownMenuItem(
              value: null,
              child: Text(
                enabled ? '选择 $hint' : '无可用选项',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...options.map(
              (title) => DropdownMenuItem(value: title, child: Text(title)),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

}