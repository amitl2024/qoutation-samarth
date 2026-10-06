import 'package:flutter/material.dart';

import '../models/letterhead_density.dart';
import '../models/quotation_model.dart';
import '../services/history_service.dart';
import '../services/pdf_generator.dart';
import '../widgets/editor/clean_form_editor.dart';
import '../widgets/fit_status_bar.dart';
import '../widgets/quotation_document_preview.dart';
import '../widgets/save_required_panel.dart';
import 'history_page.dart';

class QuotationMakerScreen extends StatefulWidget {
  const QuotationMakerScreen({super.key});

  @override
  State<QuotationMakerScreen> createState() => _QuotationMakerScreenState();
}

class _QuotationMakerScreenState extends State<QuotationMakerScreen> {
  late QuotationModel _quotation;
  int _mobileTab = 0; // 0: Form, 1: A4 Preview
  bool _isSharing = false;
  bool _isSaving = false;

  /// The letterhead, the PDF and sharing all stay locked until the quotation
  /// is on record in Firestore. Any edit puts it back to unsaved.
  bool _isSaved = false;

  double _previewScale = 1.0;

  /// Whether to shrink a long quotation so it lands on a single sheet.
  bool _fitToOnePage = true;

  /// Page count + density of the last measured build, for the fit status bar
  /// and so the on-screen letterhead matches the print.
  PdfBuildResult? _fitResult;
  bool _isMeasuring = false;

  late final PageController _mobilePageController;

  /// Shared by the desktop and mobile editor panes — only one is mounted at a
  /// time, so loading a different quotation can reset either back to the top.
  final ScrollController _editorScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Today's date and the next reference number, both filled in automatically.
    _quotation = QuotationModel.defaultTemplate();
    _mobilePageController = PageController(initialPage: 0);
    _loadNextRefNumber();
  }

  @override
  void dispose() {
    _mobilePageController.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  void _scrollEditorToTop() {
    if (_editorScrollController.hasClients) _editorScrollController.jumpTo(0);
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Why saving is not possible yet, or null when it is.
  String? get _saveBlockedReason {
    if (!HistoryService.isAvailable) {
      return 'The history database is not reachable on this platform, so the '
          'quotation cannot be recorded.';
    }
    if (_quotation.clientName.trim().isEmpty) {
      return 'Enter the client / company name first — the history is looked up by it.';
    }
    if (_quotation.refNumber.trim().isEmpty) {
      return 'The quotation needs a reference number.';
    }
    if (_quotation.items.any((i) => i.category.trim().isEmpty)) {
      return 'One of the service lines has no designation. Pick one from the dropdown.';
    }
    return null;
  }

  void _onQuotationChanged(QuotationModel updated) {
    setState(() {
      _quotation = updated;
      _isSaved = false; // edits put it back behind the save gate
      _fitResult = null; // the page count no longer reflects what is on screen
    });
  }

  /// Ask Firestore for the next unused reference number and apply it.
  Future<void> _loadNextRefNumber({bool notifyOnError = false}) async {
    try {
      final sequence = await HistoryService.nextSequence();
      if (!mounted) return;
      setState(() {
        _quotation = _quotation.copyWith(
          refNumber: QuotationModel.buildRefNumber(sequence, _quotation.date),
        );
        _isSaved = false;
      });
    } catch (e) {
      if (notifyOnError) {
        _toast('Could not read the reference counter: $e', isError: true);
      }
    }
  }

  /// Record the quotation in the Firestore history under its reference number.
  /// Returns true when it is safely on record.
  Future<bool> _saveToHistory() async {
    final blocked = _saveBlockedReason;
    if (blocked != null) {
      _toast(blocked, isError: true);
      return false;
    }

    setState(() => _isSaving = true);
    try {
      await HistoryService.saveQuotation(_quotation);
      if (!mounted) return true;
      setState(() => _isSaved = true);
      _toast('Saved ${_quotation.refNumber} for ${_quotation.clientName}');
      await _measureFit();
      return true;
    } catch (e) {
      _toast('Could not save to history: $e', isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Save, then jump to the letterhead.
  Future<void> _saveAndShowLetterhead() async {
    final saved = await _saveToHistory();
    if (!saved || !mounted) return;
    if (_mobileTab != 1) {
      setState(() => _mobileTab = 1);
      if (_mobilePageController.hasClients) {
        _mobilePageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  /// Lay the quotation out and remember how many pages it needs.
  Future<void> _measureFit() async {
    setState(() => _isMeasuring = true);
    try {
      final result = await PdfGeneratorService.build(
        _quotation,
        fitToOnePage: _fitToOnePage,
      );
      if (mounted) setState(() => _fitResult = result);
    } catch (e) {
      if (mounted) setState(() => _fitResult = null);
      _toast('Could not lay out the PDF: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isMeasuring = false);
    }
  }

  void _setFitToOnePage(bool value) {
    setState(() => _fitToOnePage = value);
    _measureFit();
  }

  /// Generates the PDF and immediately opens the device's native share sheet.
  Future<void> _shareDirectly() async {
    if (!_isSaved) {
      _toast('Save the quotation first — then it can be shared.', isError: true);
      return;
    }
    setState(() => _isSharing = true);
    try {
      await PdfGeneratorService.sharePdf(_quotation, fitToOnePage: _fitToOnePage);
    } catch (e) {
      _toast('Share error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  /// Start a blank quotation on today's date with the next reference number.
  Future<void> _newQuotation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new quotation?'),
        content: Text(
          _isSaved
              ? 'The quotation on screen is saved. A blank one will be started '
                  'with the next reference number.'
              : 'The quotation on screen has NOT been saved and will be lost.',
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start new')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _quotation = QuotationModel.defaultTemplate();
      _isSaved = false;
      _fitResult = null;
      _mobileTab = 0;
    });
    if (_mobilePageController.hasClients) _mobilePageController.jumpToPage(0);
    _scrollEditorToTop();
    await _loadNextRefNumber(notifyOnError: true);
  }

  Future<void> _openHistory() async {
    final reopened = await HistoryPage.open(context);
    if (reopened == null || !mounted) return;
    setState(() {
      _quotation = reopened;
      _isSaved = true; // it came straight out of Firestore
      _fitResult = null;
    });
    _scrollEditorToTop();
    _toast('Opened ${reopened.refNumber}');
    await _measureFit();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isCompact = screenWidth < 760;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // The toolbar is chrome rather than content, so its text only scales so
      // far: past that the buttons would push each other off the bar.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
        titleSpacing: isCompact ? 10 : 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/gadade_logo.png',
              height: isCompact ? 24 : 30,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
            if (screenWidth >= 980) ...[
              const SizedBox(width: 10),
              // Flexible so the name gives way rather than overflowing the bar
              // when the text scale is turned up.
              const Flexible(
                child: Text(
                  'Samarth Security',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ],
        ),
            actions: _buildAppBarActions(isCompact, isDesktop: isDesktop),
          ),
        ),
      ),
      body: isDesktop ? _buildDesktopWorkspace() : _buildMobileWorkspace(),
    );
  }

  List<Widget> _buildAppBarActions(bool isCompact, {required bool isDesktop}) {
    final saveButton = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: _isSaved ? _buildSavedChip(isCompact) : _buildSaveButton(isCompact),
    );

    // Sharing belongs to the letterhead: on the two-tab layout the button only
    // appears once the letterhead itself is on screen, so the edit tab stays
    // uncluttered. The desktop layout always has the letterhead in view.
    final showShare = isDesktop || _mobileTab == 1;

    // Tapping Share opens the device's native share sheet with the PDF
    // attached (WhatsApp, Gmail, Drive, etc.).
    final shareButton = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: ElevatedButton.icon(
        onPressed: (_isSharing || !_isSaved) ? null : _shareDirectly,
        icon: _isSharing
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(_isSaved ? Icons.share_outlined : Icons.lock_outline, size: 16),
        label: Text(
          isCompact ? 'Share' : 'Share PDF',
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );

    return [
      _buildNavButton(
        icon: Icons.note_add_outlined,
        label: 'New',
        tooltip: 'Start a new quotation',
        onPressed: _newQuotation,
        labelled: !isCompact,
      ),
      const SizedBox(width: 6),
      _buildNavButton(
        icon: Icons.history,
        label: 'History',
        tooltip: 'Quotation history',
        onPressed: _openHistory,
        labelled: !isCompact,
      ),
      SizedBox(width: isCompact ? 8 : 10),
      saveButton,
      if (showShare) ...[
        SizedBox(width: isCompact ? 8 : 10),
        shareButton,
      ],
      SizedBox(width: isCompact ? 8 : 12),
    ];
  }

  /// A bordered toolbar button. Narrow screens drop the text and keep the
  /// icon, so New and History stay real buttons instead of a hidden menu.
  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
    required bool labelled,
  }) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF1E3A8A),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      padding: EdgeInsets.symmetric(horizontal: labelled ? 14 : 10),
      minimumSize: Size(labelled ? 0 : 40, 38),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Tooltip(
        message: tooltip,
        child: labelled
            ? OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 17),
                label: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: style,
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: style,
                child: Icon(icon, size: 18),
              ),
      ),
    );
  }

  Widget _buildSaveButton(bool isCompact) {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _saveToHistory,
      icon: _isSaving
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.save_outlined, size: 16),
      label: Text(
        _isSaving ? 'Saving…' : 'Save',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildSavedChip(bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 15, color: Color(0xFF15803D)),
          const SizedBox(width: 6),
          Text(
            isCompact ? 'Saved' : 'Saved to history',
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF15803D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return CleanFormEditor(
      quotation: _quotation,
      onChanged: _onQuotationChanged,
      onGenerateRefNumber: () => _loadNextRefNumber(notifyOnError: true),
      onOpenHistory: _openHistory,
    );
  }

  /// The letterhead, or the save gate when the quotation is not on record yet.
  Widget _buildLetterhead({required bool scaled}) {
    if (!_isSaved) {
      return SaveRequiredPanel(
        refNumber: _quotation.refNumber,
        isSaving: _isSaving,
        blockingReason: _saveBlockedReason,
        onSave: _saveAndShowLetterhead,
      );
    }

    final document = QuotationDocumentPreview(
      quotation: _quotation,
      density: _fitResult?.density ?? LetterheadDensity.full,
    );

    return Column(
      children: [
        FitStatusBar(
          result: _fitResult,
          isMeasuring: _isMeasuring,
          fitToOnePage: _fitToOnePage,
          onFitToOnePageChanged: _setFitToOnePage,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: scaled
                ? const EdgeInsets.symmetric(vertical: 24, horizontal: 16)
                : const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Center(
              child: scaled
                  ? Transform.scale(
                      scale: _previewScale,
                      alignment: Alignment.topCenter,
                      child: document,
                    )
                  : document,
            ),
          ),
        ),
      ],
    );
  }

  /// Clean, spacious 2-Column Desktop View
  Widget _buildDesktopWorkspace() {
    return Row(
      children: [
        // Left Column: Clean Form Editor
        SizedBox(
          width: 560,
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              controller: _editorScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: _buildEditor(),
            ),
          ),
        ),

        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),

        // Right Column: Live Letterhead Preview (locked until saved)
        Expanded(
          child: Container(
            color: _isSaved ? const Color(0xFFCBD5E1) : const Color(0xFFF1F5F9),
            child: Column(
              children: [
                // Preview Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Icon(
                        _isSaved ? Icons.description_outlined : Icons.lock_outline,
                        size: 16,
                        color: const Color(0xFF1E3A8A),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isSaved
                            ? 'Live A4 Quotation Letterhead'
                            : 'Letterhead locked until saved',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      if (_isSaved) ...[
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: () => setState(
                              () => _previewScale = (_previewScale - 0.1).clamp(0.6, 1.4)),
                          tooltip: 'Zoom Out',
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          '${(_previewScale * 100).toInt()}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: () => setState(
                              () => _previewScale = (_previewScale + 0.1).clamp(0.6, 1.4)),
                          tooltip: 'Zoom In',
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(Icons.restart_alt, size: 16),
                          onPressed: () => setState(() => _previewScale = 1.0),
                          tooltip: 'Reset Zoom (100%)',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ),

                Expanded(child: _buildLetterhead(scaled: true)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile / Tablet View with a two-tab switcher
  Widget _buildMobileWorkspace() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(child: _mobileTabButton(0, Icons.edit_note_rounded, 'Edit Fields')),
                Expanded(
                  child: _mobileTabButton(
                    1,
                    _isSaved ? Icons.picture_as_pdf_outlined : Icons.lock_outline,
                    'View Letterhead',
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: PageView(
            controller: _mobilePageController,
            onPageChanged: (index) {
              if (_mobileTab != index) setState(() => _mobileTab = index);
            },
            physics: const BouncingScrollPhysics(),
            children: [
              _KeepAliveTab(
                child: SingleChildScrollView(
                  controller: _editorScrollController,
                  padding: const EdgeInsets.all(16),
                  child: _buildEditor(),
                ),
              ),
              _buildLetterhead(scaled: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mobileTabButton(int index, IconData icon, String label) {
    final isSelected = _mobileTab == index;
    return GestureDetector(
      onTap: () {
        if (_mobileTab != index) {
          setState(() => _mobileTab = index);
          _mobilePageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
