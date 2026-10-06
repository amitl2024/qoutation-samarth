import 'package:flutter/material.dart';

import '../../models/quotation_model.dart';
import '../../services/history_service.dart';

class CleanFormEditor extends StatefulWidget {
  final QuotationModel quotation;
  final ValueChanged<QuotationModel> onChanged;

  /// Issues the next unused reference number (comes from the screen, which
  /// reads the counter off the Firestore history).
  final Future<void> Function() onGenerateRefNumber;

  /// Opens the history page.
  final VoidCallback onOpenHistory;

  const CleanFormEditor({
    super.key,
    required this.quotation,
    required this.onChanged,
    required this.onGenerateRefNumber,
    required this.onOpenHistory,
  });

  @override
  State<CleanFormEditor> createState() => _CleanFormEditorState();
}

class _CleanFormEditorState extends State<CleanFormEditor> {
  late TextEditingController _clientNameCtrl;
  late TextEditingController _clientCityCtrl;
  late TextEditingController _refCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _attentionCtrl;
  late TextEditingController _introCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _clientNameCtrl = TextEditingController(text: widget.quotation.clientName);
    _clientCityCtrl = TextEditingController(text: widget.quotation.clientCity);
    _refCtrl = TextEditingController(text: widget.quotation.refNumber);
    _subjectCtrl = TextEditingController(text: widget.quotation.subject);
    _attentionCtrl = TextEditingController(text: widget.quotation.kindAttention);
    _introCtrl = TextEditingController(text: widget.quotation.introParagraph);
  }

  @override
  void didUpdateWidget(covariant CleanFormEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quotation.clientName != _clientNameCtrl.text) {
      _clientNameCtrl.text = widget.quotation.clientName;
    }
    if (widget.quotation.clientCity != _clientCityCtrl.text) {
      _clientCityCtrl.text = widget.quotation.clientCity;
    }
    if (widget.quotation.refNumber != _refCtrl.text) {
      _refCtrl.text = widget.quotation.refNumber;
    }
    if (widget.quotation.subject != _subjectCtrl.text) {
      _subjectCtrl.text = widget.quotation.subject;
    }
    if (widget.quotation.kindAttention != _attentionCtrl.text) {
      _attentionCtrl.text = widget.quotation.kindAttention;
    }
    if (widget.quotation.introParagraph != _introCtrl.text) {
      _introCtrl.text = widget.quotation.introParagraph;
    }
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientCityCtrl.dispose();
    _refCtrl.dispose();
    _subjectCtrl.dispose();
    _attentionCtrl.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.quotation.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) _applyDate(picked);
  }

  /// Changing the date also refreshes the inked stamp and the month roman
  /// numeral inside the reference number.
  void _applyDate(DateTime picked) {
    final sequence = HistoryService.sequenceOf(widget.quotation.refNumber);
    final refNumber = sequence > 0
        ? QuotationModel.buildRefNumber(sequence, picked)
        : widget.quotation.refNumber;

    widget.onChanged(widget.quotation.copyWith(
      date: picked,
      dateStampText: QuotationModel.buildDateStamp(picked),
      refNumber: refNumber,
    ));
  }

  void _addServiceItem([ServiceCategoryPreset? preset]) {
    final chosen = preset ??
        ServicePresets.findByCategory('Security Guard (Male)') ??
        ServicePresets.presets.first;

    final newItem = chosen.toItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      srNo: widget.quotation.items.length + 1,
    );

    widget.onChanged(
      widget.quotation.copyWith(items: [...widget.quotation.items, newItem]),
    );
  }

  void _removeServiceItem(int index) {
    if (widget.quotation.items.length <= 1) return;
    final updated = List<QuotationItem>.from(widget.quotation.items);
    updated.removeAt(index);
    for (int i = 0; i < updated.length; i++) {
      updated[i].srNo = i + 1;
    }
    widget.onChanged(widget.quotation.copyWith(items: updated));
  }

  void _updateServiceItem(int index, QuotationItem item) {
    final updated = List<QuotationItem>.from(widget.quotation.items);
    updated[index] = item;
    widget.onChanged(widget.quotation.copyWith(items: updated));
  }

  void _moveServiceItem(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= widget.quotation.items.length) return;
    final updated = List<QuotationItem>.from(widget.quotation.items);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    for (int i = 0; i < updated.length; i++) {
      updated[i].srNo = i + 1;
    }
    widget.onChanged(widget.quotation.copyWith(items: updated));
  }

  void _addNote([String? text]) {
    final updated = List<String>.from(widget.quotation.notes);
    updated.add(text ?? 'New note clause');
    widget.onChanged(widget.quotation.copyWith(notes: updated));
  }

  void _removeNote(int index) {
    final updated = List<String>.from(widget.quotation.notes);
    updated.removeAt(index);
    widget.onChanged(widget.quotation.copyWith(notes: updated));
  }

  void _updateNote(int index, String val) {
    final updated = List<String>.from(widget.quotation.notes);
    updated[index] = val;
    widget.onChanged(widget.quotation.copyWith(notes: updated));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION 1: CLIENT & QUOTATION DETAILS
        _buildSectionHeader('Client & Quotation Details', Icons.business_outlined),
        const SizedBox(height: 10),

        // The reference number and client name both carry a "previous" hint,
        // read live off the Firestore history.
        StreamBuilder<QuotationHistoryEntry?>(
          stream: HistoryService.watchLatestEntry(),
          builder: (context, snapshot) {
            final previous = snapshot.data;

            return _buildCard(
              children: [
                _buildInputField(
                  label: 'Client / Company Name',
                  hint: 'e.g. M/S MASTIFF Hotel',
                  controller: _clientNameCtrl,
                  previousHint: previous?.clientName.isNotEmpty == true
                      ? previous!.clientName
                      : null,
                  onChanged: (val) =>
                      widget.onChanged(widget.quotation.copyWith(clientName: val)),
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  label: 'City / Location',
                  hint: 'e.g. Sangli',
                  controller: _clientCityCtrl,
                  onChanged: (val) =>
                      widget.onChanged(widget.quotation.copyWith(clientCity: val)),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final refField = _buildInputField(
                      label: 'Reference No.',
                      hint: 'Ref/146/Quots/S/X/2026',
                      controller: _refCtrl,
                      previousHint: previous?.refNumber.isNotEmpty == true
                          ? previous!.refNumber
                          : null,
                      onChanged: (val) =>
                          widget.onChanged(widget.quotation.copyWith(refNumber: val)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.restart_alt, size: 17),
                        tooltip: 'Issue next reference number',
                        onPressed: () => widget.onGenerateRefNumber(),
                      ),
                    );

                    if (constraints.maxWidth < 360) {
                      return Column(
                        children: [
                          refField,
                          const SizedBox(height: 14),
                          _buildDateTile(),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(flex: 3, child: refField),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: _buildDateTile()),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  label: 'Subject',
                  hint: 'Quotation on Manpower Service Arrangements',
                  controller: _subjectCtrl,
                  onChanged: (val) => widget.onChanged(widget.quotation.copyWith(subject: val)),
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  label: 'Kind Attention',
                  hint: 'Director',
                  controller: _attentionCtrl,
                  onChanged: (val) =>
                      widget.onChanged(widget.quotation.copyWith(kindAttention: val)),
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  label: 'Proposal Text',
                  hint: 'We are pleased to forward you the following quotation...',
                  controller: _introCtrl,
                  maxLines: 3,
                  onChanged: (val) =>
                      widget.onChanged(widget.quotation.copyWith(introParagraph: val)),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // SECTION 2: SERVICES, SHIFT, SKILL & RATES
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: _buildSectionHeader('Services & Rates', Icons.security_outlined),
            ),
            Flexible(
              child: ElevatedButton.icon(
                onPressed: () => _addServiceItem(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add Service',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: widget.quotation.items.length,
          onReorder: (oldIndex, newIndex) {
            if (oldIndex < newIndex) newIndex -= 1;
            _moveServiceItem(oldIndex, newIndex);
          },
          proxyDecorator: (Widget child, int index, Animation<double> animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (BuildContext context, Widget? child) {
                final double animValue = Curves.easeInOutCubic.transform(animation.value);
                return Transform.scale(
                  scale: 1.0 + (animValue * 0.025),
                  child: Material(
                    elevation: (animValue * 12).clamp(0, 12),
                    color: Colors.transparent,
                    shadowColor: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },
          itemBuilder: (context, idx) {
            final item = widget.quotation.items[idx];
            return _AnimatedServiceCard(
              key: ValueKey(item.id),
              index: idx,
              item: item,
              canDelete: widget.quotation.items.length > 1,
              onChanged: (updated) => _updateServiceItem(idx, updated),
              onDelete: () => _removeServiceItem(idx),
            );
          },
        ),

        const SizedBox(height: 24),

        // SECTION 3: NOTES & TERMS
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: _buildSectionHeader('Notes & Terms', Icons.format_list_numbered),
            ),
            Flexible(
              child: TextButton.icon(
                onPressed: () => _addNote(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add Line',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF1E3A8A)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        _buildCard(
          children: [
            if (widget.quotation.notes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No note lines. Tap "Add Line" to add GST, tax or revision clauses.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ...widget.quotation.notes.asMap().entries.map((entry) {
              final idx = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${idx + 1})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('note_$idx'),
                        initialValue: entry.value,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        onChanged: (val) => _updateNote(idx, val),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      tooltip: 'Remove',
                      onPressed: () => _removeNote(idx),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDateTile() {
    final isToday = DateUtils.isSameDay(widget.quotation.date, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Date',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
            const Spacer(),
            if (!isToday)
              GestureDetector(
                onTap: () => _applyDate(DateTime.now()),
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text(
                    'Use today',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    widget.quotation.formattedDate,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.calendar_today, size: 15, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    Widget? suffixIcon,
    String? previousHint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
        ),
        if (previousHint != null) ...[
          const SizedBox(height: 3),
          _PreviousHintLabel(value: previousHint, onTap: widget.onOpenHistory),
        ],
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Small "Previous: …" label sitting just above a text field. Tapping it opens
/// the history page.
class _PreviousHintLabel extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _PreviousHintLabel({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            const Icon(Icons.history, size: 11, color: Color(0xFF94A3B8)),
            const SizedBox(width: 3),
            Text(
              'Previous: ',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)).copyWith(height: 1.2),
            ),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated card for each service line: category dropdown, day/night shift,
/// skilled/unskilled, duty hours, working days and rate.
class _AnimatedServiceCard extends StatefulWidget {
  final int index;
  final QuotationItem item;
  final bool canDelete;
  final ValueChanged<QuotationItem> onChanged;
  final VoidCallback onDelete;

  const _AnimatedServiceCard({
    super.key,
    required this.index,
    required this.item,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_AnimatedServiceCard> createState() => _AnimatedServiceCardState();
}

class _AnimatedServiceCardState extends State<_AnimatedServiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late TextEditingController _rateCtrl;
  late TextEditingController _customCatCtrl;
  final FocusNode _customCatFocus = FocusNode();

  /// True once the user picks "Other" from the dropdown, so the free-text field
  /// stays open even while the typed designation is still empty.
  bool _forceCustom = false;

  bool get _isCustom =>
      _forceCustom || ServicePresets.findByCategory(widget.item.category) == null;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _rateCtrl = TextEditingController(text: widget.item.ratePerPerson.toInt().toString());
    _customCatCtrl = TextEditingController(
      text: ServicePresets.findByCategory(widget.item.category) == null
          ? widget.item.category
          : '',
    );
    _animCtrl.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedServiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rateText = widget.item.ratePerPerson.toInt().toString();
    if (rateText != _rateCtrl.text) _rateCtrl.text = rateText;
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _rateCtrl.dispose();
    _customCatCtrl.dispose();
    _customCatFocus.dispose();
    super.dispose();
  }

  void _handleDelete() {
    _animCtrl.reverse().then((_) => widget.onDelete());
  }

  /// Picking a preset loads its standard shift length, working days, skill
  /// classification and rate; they stay editable afterwards.
  void _selectPreset(String? value) {
    if (value == null) return;

    if (value == ServicePresets.customOption) {
      setState(() => _forceCustom = true);
      widget.onChanged(widget.item.copyWith(category: _customCatCtrl.text));
      // Put the caret straight into the free-text field.
      WidgetsBinding.instance.addPostFrameCallback((_) => _customCatFocus.requestFocus());
      return;
    }

    final preset = ServicePresets.findByCategory(value);
    if (preset == null) return;

    setState(() => _forceCustom = false);
    widget.onChanged(widget.item.copyWith(
      category: preset.category,
      dutyHours: preset.defaultDutyHours,
      workingDays: preset.defaultWorkingDays,
      skillLevels: {preset.defaultSkillLevel},
      ratePerPerson: preset.defaultRate,
    ));
  }

  /// Shift and skill are each a single choice: one option, or "Both".
  void _setShifts(Set<DutyShift> shifts) =>
      widget.onChanged(widget.item.copyWith(shifts: shifts));

  void _setSkills(Set<SkillLevel> levels) =>
      widget.onChanged(widget.item.copyWith(skillLevels: levels));

  @override
  Widget build(BuildContext context) {
    final dropdownValue =
        _isCustom ? ServicePresets.customOption : widget.item.category;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: drag handle + delete
              Row(
                children: [
                  Flexible(
                    child: ReorderableDragStartListener(
                      index: widget.index,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // The hint is the first thing to go when the row
                            // gets tight: small phone, or large system text.
                            final showHint = constraints.maxWidth >=
                                MediaQuery.of(context).textScaler.scale(150);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.drag_indicator_rounded,
                                    size: 16, color: Color(0xFF1E3A8A)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Service #${widget.item.srNo}',
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    style: const TextStyle(
                                      color: Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (showHint) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Hold & Drag',
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (widget.canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      tooltip: 'Delete Service',
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      onPressed: _handleDelete,
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Category dropdown
              const Text(
                'Category / Designation',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: dropdownValue,
                isExpanded: true,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                  ),
                ),
                items: [
                  ...ServicePresets.presets.map(
                    (p) => DropdownMenuItem<String>(
                      value: p.category,
                      child: Text(p.category, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const DropdownMenuItem<String>(
                    value: ServicePresets.customOption,
                    child: Text(
                      ServicePresets.customOption,
                      style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
                onChanged: _selectPreset,
              ),

              // Free-text designation, shown only for "Other"
              if (_isCustom) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _customCatCtrl,
                  focusNode: _customCatFocus,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Type the designation as it should print',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFFFFBEB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                    ),
                  ),
                  onChanged: (val) {
                    widget.onChanged(widget.item.copyWith(
                      category: val,
                      workingDays: ServicePresets.detectWorkingDays(val),
                      skillLevels: {ServicePresets.detectSkillLevel(val)},
                    ));
                  },
                ),
              ],

              const SizedBox(height: 12),

              // Shift and skill sit side by side when the card is wide enough.
              // Single choice each: Day / Night / Both, Skilled / Unskilled / Both.
              LayoutBuilder(
                builder: (context, constraints) {
                  final both = widget.item.shifts.length > 1;
                  final shiftGroup = _buildToggleGroup(
                    label: 'Shift',
                    children: [
                      _togglePill(
                        label: 'Day',
                        icon: Icons.light_mode_outlined,
                        isSelected: !both && widget.item.coversDay,
                        onTap: () => _setShifts({DutyShift.day}),
                      ),
                      _togglePill(
                        label: 'Night',
                        icon: Icons.dark_mode_outlined,
                        isSelected: !both && widget.item.coversNight,
                        onTap: () => _setShifts({DutyShift.night}),
                      ),
                      _togglePill(
                        label: 'Both',
                        icon: Icons.brightness_6_outlined,
                        isSelected: both,
                        onTap: () => _setShifts({DutyShift.day, DutyShift.night}),
                      ),
                    ],
                  );

                  final bothSkills = widget.item.skillLevels.length > 1;
                  final skillGroup = _buildToggleGroup(
                    label: 'Skill',
                    hint: 'ticked in the PDF',
                    children: [
                      _togglePill(
                        label: 'Skilled',
                        icon: Icons.workspace_premium_outlined,
                        isSelected: !bothSkills && widget.item.isSkilled,
                        onTap: () => _setSkills({SkillLevel.skilled}),
                      ),
                      _togglePill(
                        label: 'Unskilled',
                        icon: Icons.person_outline,
                        isSelected: !bothSkills && widget.item.isUnskilled,
                        onTap: () => _setSkills({SkillLevel.unskilled}),
                      ),
                      _togglePill(
                        label: 'Both',
                        icon: Icons.groups_outlined,
                        isSelected: bothSkills,
                        onTap: () => _setSkills({SkillLevel.skilled, SkillLevel.unskilled}),
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        shiftGroup,
                        const SizedBox(height: 12),
                        skillGroup,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(child: shiftGroup),
                      const SizedBox(width: 16),
                      Flexible(child: skillGroup),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              // Duty hours, working days and rate
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  _buildToggleGroup(
                    label: 'Duty Hours',
                    children: [
                      _togglePill(
                        label: '8 Hours',
                        isSelected: widget.item.dutyHours == 8,
                        onTap: () => widget.onChanged(widget.item.copyWith(dutyHours: 8)),
                      ),
                      _togglePill(
                        label: '12 Hours',
                        isSelected: widget.item.dutyHours == 12,
                        onTap: () => widget.onChanged(widget.item.copyWith(dutyHours: 12)),
                      ),
                    ],
                  ),
                  _buildToggleGroup(
                    label: 'Working Days',
                    children: [
                      _togglePill(
                        label: '26 Days',
                        isSelected: widget.item.workingDays == 26,
                        onTap: () => widget.onChanged(widget.item.copyWith(workingDays: 26)),
                      ),
                      _togglePill(
                        label: '30 Days',
                        isSelected: widget.item.workingDays == 30,
                        onTap: () => widget.onChanged(widget.item.copyWith(workingDays: 30)),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 132,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rate Per Person',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _rateCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixText: 'Rs. ',
                            suffixText: '/-',
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                          onChanged: (val) {
                            widget.onChanged(
                              widget.item.copyWith(ratePerPerson: double.tryParse(val) ?? 0.0),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Summary of exactly what the document row will read
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.table_rows_outlined, size: 15, color: Color(0xFF1E40AF)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'PDF row:  ${widget.item.category.isEmpty ? "(no designation)" : widget.item.category}'
                        '  |  ${widget.item.shiftLabel}'
                        '  |  ${widget.item.displayDuty}'
                        '  |  ✓ ${widget.item.skillLabel}'
                        '  |  ${widget.item.displayRate}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleGroup({
    required String label,
    required List<Widget> children,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 5,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            if (hint != null)
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF94A3B8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        // Wrap, not Row: with a larger system text size the pills need to flow
        // onto a second line rather than run off the edge.
        Wrap(spacing: 6, runSpacing: 6, children: children),
      ],
    );
  }

  Widget _togglePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A tick on the chosen pills, so it reads as "any number of these"
            // rather than "pick exactly one".
            Icon(
              isSelected ? Icons.check : icon,
              size: 13,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
