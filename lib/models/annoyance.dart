import 'package:cloud_firestore/cloud_firestore.dart';

class Annoyance {
  final String id;
  final String uid;
  final DateTime timestamp;
  final String transcript;
  final String category;
  final String trigger;
  final bool safe;
  final bool audioLocal; // audio stays on device by default
  final bool modified; // true if user has edited this entry

  Annoyance({
    required this.id,
    required this.uid,
    required this.timestamp,
    required this.transcript,
    required this.category,
    required this.trigger,
    required this.safe,
    this.audioLocal = true,
    this.modified = false,
  });

  factory Annoyance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Annoyance(
      id: doc.id,
      uid: data['uid'] ?? '',
      timestamp: (data['ts'] as Timestamp).toDate(),
      transcript: data['transcript'] ?? '',
      category: data['category'] ?? '',
      trigger: data['trigger'] ?? '',
      safe: data['safe'] ?? true,
      audioLocal: data['audio_local'] ?? true,
      modified: data['modified'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'ts': Timestamp.fromDate(timestamp),
      'transcript': transcript,
      'category': category,
      'trigger': trigger,
      'safe': safe,
      'audio_local': audioLocal,
      'modified': modified,
    };
  }
  
  /// Create a copy of this annoyance with updated fields
  Annoyance copyWith({
    String? id,
    String? uid,
    DateTime? timestamp,
    String? transcript,
    String? category,
    String? trigger,
    bool? safe,
    bool? audioLocal,
    bool? modified,
  }) {
    return Annoyance(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      timestamp: timestamp ?? this.timestamp,
      transcript: transcript ?? this.transcript,
      category: category ?? this.category,
      trigger: trigger ?? this.trigger,
      safe: safe ?? this.safe,
      audioLocal: audioLocal ?? this.audioLocal,
      modified: modified ?? this.modified,
    );
  }
}

// Categories for v1
class AnnoyanceCategory {
  static const String boundaries = 'Boundaries';
  static const String environment = 'Environment';
  static const String systemsDebt = 'Systems Debt';
  static const String communication = 'Communication';
  static const String energy = 'Energy';

  static const List<String> all = [
    boundaries,
    environment,
    systemsDebt,
    communication,
    energy,
  ];
}


