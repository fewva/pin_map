import 'package:flutter/material.dart';

class AddPlaceDialog extends StatefulWidget {
  const AddPlaceDialog({super.key});

  @override
  State<AddPlaceDialog> createState() => _AddPlaceDialogState();
}

class _AddPlaceDialogState extends State<AddPlaceDialog> {
  Map<String, String>? _selectedTags;

  final List<_PlaceTypeOption> _options = [
    _PlaceTypeOption(
      label: 'Туалет',
      icon: Icons.wc,
      tags: {'amenity': 'toilets'},
    ),
    _PlaceTypeOption(
      label: 'Банкомат',
      icon: Icons.atm,
      tags: {'amenity': 'atm'},
    ),
    _PlaceTypeOption(
      label: 'WiFi',
      icon: Icons.wifi,
      tags: {'internet_access': 'wlan'},
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Добавить точку',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ..._options.map((option) {
              final isSelected = _selectedTags == option.tags;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedTags = option.tags;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          option.icon,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey[700],
                        ),
                        const SizedBox(width: 16),
                        Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedTags == null
                      ? null
                      : () {
                          Navigator.of(context).pop(_selectedTags);
                        },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Добавить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceTypeOption {
  final String label;
  final IconData icon;
  final Map<String, String> tags;

  _PlaceTypeOption({
    required this.label,
    required this.icon,
    required this.tags,
  });
}
