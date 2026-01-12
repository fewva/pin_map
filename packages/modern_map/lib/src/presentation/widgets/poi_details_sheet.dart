import 'package:flutter/material.dart';

import '../../domain/entities/poi.dart';

class PoiDetailsSheet {
  static Future<void> show(BuildContext context, Poi poi) {
    return showModalBottomSheet(
      context: context,
      builder: (context) {
        final entries = poi.tags.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(poi.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(poi.category),
                const SizedBox(height: 12),
                SizedBox(
                  height: 240,
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        dense: true,
                        title: Text(entry.key),
                        subtitle: Text(entry.value),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

