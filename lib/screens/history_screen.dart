import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:io';
import '../providers/auth_state_manager.dart';
import '../providers/annoyance_provider.dart';
import '../models/annoyance.dart';
import '../widgets/category_chip.dart';
import 'entry_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _deleteAnnoyance(
    BuildContext context,
    Annoyance annoyance,
  ) async {
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final annoyanceProvider =
        Provider.of<AnnoyanceProvider>(context, listen: false);

    final uid = authStateManager.userId;
    if (uid != null) {
      await annoyanceProvider.deleteAnnoyance(annoyance.id, uid);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final annoyanceProvider = Provider.of<AnnoyanceProvider>(context);
    final annoyances = annoyanceProvider.annoyances;

    // Group by date
    final Map<String, List<Annoyance>> groupedAnnoyances = {};
    for (final annoyance in annoyances) {
      final dateKey = DateFormat('yyyy-MM-dd').format(annoyance.timestamp);
      if (!groupedAnnoyances.containsKey(dateKey)) {
        groupedAnnoyances[dateKey] = [];
      }
      groupedAnnoyances[dateKey]!.add(annoyance);
    }

    final sortedDates = groupedAnnoyances.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: annoyances.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No entries yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final dateKey = sortedDates[index];
                final dateAnnoyances = groupedAnnoyances[dateKey]!;
                final date = DateTime.parse(dateKey);

                String dateLabel;
                final now = DateTime.now();
                if (date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day) {
                  dateLabel = 'Today';
                } else if (date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day - 1) {
                  dateLabel = 'Yesterday';
                } else {
                  dateLabel = DateFormat('EEEE, MMMM d').format(date);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...dateAnnoyances.map((annoyance) {
                      return Slidable(
                        key: Key(annoyance.id),
                        endActionPane: ActionPane(
                          motion: Platform.isIOS 
                              ? const DrawerMotion() 
                              : const ScrollMotion(),
                          extentRatio: 0.25,
                          children: [
                            SlidableAction(
                              onPressed: (context) => _deleteAnnoyance(context, annoyance),
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ],
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    annoyance.transcript,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (annoyance.modified) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: Colors.blue.shade700,
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              DateFormat('h:mm a').format(annoyance.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: CategoryChip(category: annoyance.category),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EntryDetailScreen(annoyance: annoyance),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
    );
  }
}







