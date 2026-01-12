import 'package:flutter/material.dart';

class PoiFilterWidget extends StatelessWidget {
  final Set<String> selectedCategories;
  final Function(String category) onCategoryToggled;

  const PoiFilterWidget({
    super.key,
    required this.selectedCategories,
    required this.onCategoryToggled,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(context, 'WiFi', 'wlan', Icons.wifi),
          const SizedBox(width: 8),
          _buildFilterChip(context, 'Туалет', 'toilets', Icons.wc),
          const SizedBox(width: 8),
          _buildFilterChip(context, 'Банкомат', 'atm', Icons.atm),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    String categoryKey,
    IconData icon,
  ) {
    final isSelected = selectedCategories.contains(categoryKey);
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onCategoryToggled(categoryKey),
      backgroundColor: Colors.white,
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.3),
        ),
      ),
      elevation: 2,
      pressElevation: 4,
    );
  }
}
