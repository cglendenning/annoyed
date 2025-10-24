import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/annoyance.dart';
import '../providers/auth_state_manager.dart';
import '../providers/annoyance_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/category_chip.dart';
import 'package:intl/intl.dart';

class EntryDetailScreen extends StatefulWidget {
  final Annoyance annoyance;

  const EntryDetailScreen({
    super.key,
    required this.annoyance,
  });

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  late TextEditingController _transcriptController;
  late TextEditingController _triggerController;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController(text: widget.annoyance.transcript);
    _triggerController = TextEditingController(text: widget.annoyance.trigger);
    _selectedCategory = widget.annoyance.category;
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    _triggerController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final annoyanceProvider = Provider.of<AnnoyanceProvider>(context, listen: false);
    final uid = authStateManager.userId;

    if (uid != null) {
      final updatedAnnoyance = widget.annoyance.copyWith(
        transcript: _transcriptController.text,
        category: _selectedCategory,
        trigger: _triggerController.text,
        timestamp: DateTime.now(), // Update timestamp so it counts as "new" for coaching
        modified: true,
      );

      await annoyanceProvider.updateAnnoyance(updatedAnnoyance, uid);
      
      // Log analytics for entry edit (timestamp updated = counts as new for coaching)
      await AnalyticsService.logEvent('annoyance_edited', meta: {
        'category': _selectedCategory,
        'had_trigger': _triggerController.text.isNotEmpty,
      });

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _cancelEditing() {
    setState(() {
      _transcriptController.text = widget.annoyance.transcript;
      _triggerController.text = widget.annoyance.trigger;
      _selectedCategory = widget.annoyance.category;
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entry'),
        actions: [
          if (!_isEditing && !_isSaving)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (_isEditing && !_isSaving)
            TextButton(
              onPressed: _cancelEditing,
              child: const Text('Cancel'),
            ),
          if (_isEditing && !_isSaving)
            TextButton(
              onPressed: _saveChanges,
              child: const Text('Save'),
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date/time with modified indicator
                  Row(
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d, y • h:mm a').format(widget.annoyance.timestamp),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (widget.annoyance.modified) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit,
                                size: 12,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Edited',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Transcript
                  const Text(
                    'Transcript',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isEditing)
                    TextField(
                      controller: _transcriptController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter transcript',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        widget.annoyance.transcript,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Category and Trigger
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isEditing)
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items: AnnoyanceCategory.all.map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedCategory = value;
                                    });
                                  }
                                },
                              )
                            else
                              CategoryChip(category: widget.annoyance.category),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trigger',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isEditing)
                              TextField(
                                controller: _triggerController,
                                decoration: InputDecoration(
                                  hintText: 'Enter trigger',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  widget.annoyance.trigger,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Safety indicator (if not safe)
                  if (!widget.annoyance.safe) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'This entry contains crisis terms. Please reach out to a professional if needed.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
