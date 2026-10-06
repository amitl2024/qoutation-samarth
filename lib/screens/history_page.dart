import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/quotation_model.dart';
import '../services/history_service.dart';

/// Every reference number already issued, and the client it was raised for.
/// Tapping an entry reopens that quotation for editing.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  /// Pushes the page and returns the quotation the user chose to reopen, if any.
  static Future<QuotationModel?> open(BuildContext context) {
    return Navigator.of(context).push<QuotationModel>(
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
  }

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<QuotationHistoryEntry> _filter(List<QuotationHistoryEntry> entries) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries
        .where((e) =>
            e.refNumber.toLowerCase().contains(q) ||
            e.clientName.toLowerCase().contains(q) ||
            e.clientCity.toLowerCase().contains(q) ||
            e.subject.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _confirmDelete(QuotationHistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from history?'),
        content: Text(
          '${entry.refNumber}\n'
          '${entry.clientName.isEmpty ? "(no client name)" : entry.clientName}\n\n'
          'This deletes the saved record from Firestore. The reference number '
          'will not be reused.',
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await HistoryService.deleteEntry(entry.refNumber);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not remove: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
        title: const Text(
          'Quotation History',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A)),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 12, isMobile ? 16 : 24, 14),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13),
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by reference no, client or city',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          Expanded(
            child: StreamBuilder<List<QuotationHistoryEntry>>(
              stream: HistoryService.watchHistory(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error!);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data!;
                if (all.isEmpty) return _buildEmptyState();

                final visible = _filter(all);
                if (visible.isEmpty) return _buildNoMatchState();

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 32),
                  itemCount: visible.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _query.trim().isEmpty
                              ? '${all.length} quotation${all.length == 1 ? '' : 's'} issued'
                              : '${visible.length} of ${all.length} match',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      );
                    }
                    return _buildEntryCard(visible[index - 1]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 38, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            const Text(
              'Could not load the history',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFFCBD5E1)),
            SizedBox(height: 14),
            Text(
              'No quotations saved yet',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            SizedBox(height: 7),
            Text(
              'Tap "Save" on a quotation to record its reference number here. '
              'The next quotation then picks up the following number automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMatchState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 36, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text(
            'No matching quotation',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(QuotationHistoryEntry entry) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(entry.toQuotation()),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    entry.refNumber,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd MMM yyyy').format(entry.date),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 17, color: Color(0xFFDC2626)),
                  tooltip: 'Remove from history',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 8),
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(entry),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              entry.clientName.isEmpty ? '(no client name)' : entry.clientName,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: entry.clientName.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
              ),
            ),
            if (entry.clientCity.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text(
                      entry.clientCity,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              entry.servicesSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.35),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.edit_outlined, size: 13, color: Color(0xFF1E3A8A)),
                SizedBox(width: 4),
                Text(
                  'Tap to reopen and edit',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
