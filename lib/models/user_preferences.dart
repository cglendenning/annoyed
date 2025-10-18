import 'package:cloud_firestore/cloud_firestore.dart';

class UserPreferences {
  final String uid;
  final String goodStart; // HH:mm format
  final String goodEnd; // HH:mm format
  final bool dndRespect;
  final DateTime? proUntil;

  UserPreferences({
    required this.uid,
    this.goodStart = '10:00',
    this.goodEnd = '19:00',
    this.dndRespect = true,
    this.proUntil,
  });

  factory UserPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return UserPreferences(uid: doc.id);
    }
    return UserPreferences(
      uid: doc.id,
      goodStart: data['good_start'] ?? '10:00',
      goodEnd: data['good_end'] ?? '19:00',
      dndRespect: data['dnd_respect'] ?? true,
      proUntil: data['pro_until'] != null
          ? (data['pro_until'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'good_start': goodStart,
      'good_end': goodEnd,
      'dnd_respect': dndRespect,
      'pro_until': proUntil != null ? Timestamp.fromDate(proUntil!) : null,
    };
  }

  bool get isPro {
    if (proUntil == null) return false;
    return DateTime.now().isBefore(proUntil!);
  }

  UserPreferences copyWith({
    String? uid,
    String? goodStart,
    String? goodEnd,
    bool? dndRespect,
    DateTime? proUntil,
  }) {
    return UserPreferences(
      uid: uid ?? this.uid,
      goodStart: goodStart ?? this.goodStart,
      goodEnd: goodEnd ?? this.goodEnd,
      dndRespect: dndRespect ?? this.dndRespect,
      proUntil: proUntil ?? this.proUntil,
    );
  }
}


