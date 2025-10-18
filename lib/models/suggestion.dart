import 'package:cloud_firestore/cloud_firestore.dart';

class Suggestion {
  final String id;
  final String uid;
  final String annoyanceId;
  final DateTime timestamp;
  final String text;
  final String category;
  final String type; // 'reframe' | 'behavior'
  final int durationDays;
  final String? resonance; // 'hell_yes' | 'meh' | null
  final DateTime? resonanceTimestamp;
  final DateTime? completedTimestamp;

  Suggestion({
    required this.id,
    required this.uid,
    required this.annoyanceId,
    required this.timestamp,
    required this.text,
    required this.category,
    required this.type,
    required this.durationDays,
    this.resonance,
    this.resonanceTimestamp,
    this.completedTimestamp,
  });

  factory Suggestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Suggestion(
      id: doc.id,
      uid: data['uid'] ?? '',
      annoyanceId: data['annoyance_id'] ?? '',
      timestamp: (data['ts'] as Timestamp).toDate(),
      text: data['text'] ?? '',
      category: data['category'] ?? '',
      type: data['type'] ?? 'behavior',
      durationDays: data['duration_days'] ?? 5,
      resonance: data['resonance'],
      resonanceTimestamp: data['resonance_ts'] != null
          ? (data['resonance_ts'] as Timestamp).toDate()
          : null,
      completedTimestamp: data['completed_ts'] != null
          ? (data['completed_ts'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'annoyance_id': annoyanceId,
      'ts': Timestamp.fromDate(timestamp),
      'text': text,
      'category': category,
      'type': type,
      'duration_days': durationDays,
      'resonance': resonance,
      'resonance_ts':
          resonanceTimestamp != null ? Timestamp.fromDate(resonanceTimestamp!) : null,
      'completed_ts':
          completedTimestamp != null ? Timestamp.fromDate(completedTimestamp!) : null,
    };
  }

  Suggestion copyWith({
    String? id,
    String? uid,
    String? annoyanceId,
    DateTime? timestamp,
    String? text,
    String? category,
    String? type,
    int? durationDays,
    String? resonance,
    DateTime? resonanceTimestamp,
    DateTime? completedTimestamp,
  }) {
    return Suggestion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      annoyanceId: annoyanceId ?? this.annoyanceId,
      timestamp: timestamp ?? this.timestamp,
      text: text ?? this.text,
      category: category ?? this.category,
      type: type ?? this.type,
      durationDays: durationDays ?? this.durationDays,
      resonance: resonance ?? this.resonance,
      resonanceTimestamp: resonanceTimestamp ?? this.resonanceTimestamp,
      completedTimestamp: completedTimestamp ?? this.completedTimestamp,
    );
  }
}


