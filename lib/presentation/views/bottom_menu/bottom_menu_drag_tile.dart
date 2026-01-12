import 'package:flutter/material.dart';

class BottomMenuDragTile extends StatelessWidget {
  const BottomMenuDragTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      width: 40,
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }
}
