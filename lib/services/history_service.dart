import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/quotation_model.dart';

/// One previously issued quotation, as stored in Firestore. Keeps the
/// reference number together with the client it was raised for, plus the full
/// quotation so it can be reopened and edited.
class QuotationHistoryEntry {
  final String refNumber;
  final int sequence;
  final String clientName;
  final String clientCity;
  final DateTime date;
  final String subject;
  final DateTime savedAt;
  final Map<String, dynamic> quotationJson;

  const QuotationHistoryEntry({
    required this.refNumber,
    required this.sequence,
    required this.clientName,
    required this.clientCity,
    required this.date,
    required this.subject,
    required this.savedAt,
    required this.quotationJson,
  });

  factory QuotationHistoryEntry.fromQuotation(QuotationModel q) => QuotationHistoryEntry(
        refNumber: q.refNumber,
        sequence: HistoryService.sequenceOf(q.refNumber),
        clientName: q.clientName,
        clientCity: q.clientCity,
        date: q.date,
        subject: q.subject,
        savedAt: DateTime.now(),
        quotationJson: q.toJson(),
      );

  QuotationModel toQuotation() => QuotationModel.fromJson(quotationJson);

  /// Service lines summarised for the history list.
  String get servicesSummary {
    final items = quotationJson['items'] as List<dynamic>? ?? const [];
    if (items.isEmpty) return 'No services';
    return items
        .map((i) => (i as Map<String, dynamic>)['category']?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .join(', ');
  }

  Map<String, dynamic> toFirestore() => {
        'refNumber': refNumber,
        'sequence': sequence,
        'clientName': clientName,
        'clientCity': clientCity,
        'date': Timestamp.fromDate(date),
        'subject': subject,
        'savedAt': Timestamp.fromDate(savedAt),
        'quotation': quotationJson,
      };

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  factory QuotationHistoryEntry.fromFirestore(Map<String, dynamic> data) => QuotationHistoryEntry(
        refNumber: data['refNumber'] as String? ?? '',
        sequence: (data['sequence'] as num?)?.toInt() ?? 0,
        clientName: data['clientName'] as String? ?? '',
        clientCity: data['clientCity'] as String? ?? '',
        date: _readDate(data['date']),
        subject: data['subject'] as String? ?? '',
        savedAt: _readDate(data['savedAt']),
        quotationJson: Map<String, dynamic>.from(
          data['quotation'] as Map<String, dynamic>? ?? const {},
        ),
      );
}

/// Quotation history, stored in Firestore under `quotation_history`.
/// Nothing else is kept in the cloud — the quotation being edited stays in
/// memory until it is saved.
class HistoryService {
  static const String collectionName = 'quotation_history';

  /// The company's paper trail ended at Ref/145, so the first quotation this
  /// app issues is 146.
  static const int seedSequence = 145;

  /// False when Firebase did not start — on desktop builds, or if the config
  /// is missing. The quotation maker still works; only the history is off.
  static bool get isAvailable => Firebase.apps.isNotEmpty;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(collectionName);

  static Object get _unavailable => StateError(
        'Firebase is not available on this platform, so the quotation '
        'history cannot be read or written.',
      );

  /// Firestore document ids cannot contain `/`, which the reference number does.
  static String docIdFor(String refNumber) =>
      refNumber.replaceAll('/', '-').replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  /// Pull the numeric part out of `Ref/146/Quots/S/X/2026`.
  static int sequenceOf(String refNumber) {
    for (final part in refNumber.split('/')) {
      final n = int.tryParse(part.trim());
      if (n != null) return n;
    }
    return 0;
  }

  /// Highest reference number issued so far, read straight off the history.
  static Future<int> lastSequence() async {
    if (!isAvailable) return seedSequence;
    final snap = await _collection.orderBy('sequence', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return seedSequence;
    final highest = (snap.docs.first.data()['sequence'] as num?)?.toInt() ?? seedSequence;
    return highest > seedSequence ? highest : seedSequence;
  }

  /// The number a brand-new quotation should carry.
  static Future<int> nextSequence() async => (await lastSequence()) + 1;

  /// Save [quotation] to the history. Re-saving the same reference number
  /// overwrites that entry rather than adding a duplicate.
  static Future<void> saveQuotation(QuotationModel quotation) async {
    if (!isAvailable) throw _unavailable;
    final entry = QuotationHistoryEntry.fromQuotation(quotation);
    await _collection.doc(docIdFor(quotation.refNumber)).set(entry.toFirestore());
  }

  /// All saved quotations, newest reference number first.
  static Future<List<QuotationHistoryEntry>> history() async {
    if (!isAvailable) return [];
    final snap = await _collection.orderBy('sequence', descending: true).get();
    return snap.docs.map((d) => QuotationHistoryEntry.fromFirestore(d.data())).toList();
  }

  /// Live history list, so the page updates as entries are added or removed.
  static Stream<List<QuotationHistoryEntry>> watchHistory() {
    if (!isAvailable) return Stream.error(_unavailable);
    return _collection.orderBy('sequence', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => QuotationHistoryEntry.fromFirestore(d.data())).toList(),
        );
  }

  /// The most recently issued quotation, used for the "previous" hints shown
  /// above the client name and reference number fields.
  static Future<QuotationHistoryEntry?> latestEntry() async {
    if (!isAvailable) return null;
    final snap = await _collection.orderBy('sequence', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return QuotationHistoryEntry.fromFirestore(snap.docs.first.data());
  }

  /// Backs the "Previous: …" hints. Stays quiet (emits null) when the history
  /// is unavailable, so the fields simply show no hint.
  static Stream<QuotationHistoryEntry?> watchLatestEntry() {
    if (!isAvailable) return Stream.value(null);
    return _collection
        .orderBy('sequence', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
            ? null
            : QuotationHistoryEntry.fromFirestore(snap.docs.first.data()))
        .handleError((_) => null);
  }

  static Future<void> deleteEntry(String refNumber) async {
    if (!isAvailable) throw _unavailable;
    await _collection.doc(docIdFor(refNumber)).delete();
  }
}
