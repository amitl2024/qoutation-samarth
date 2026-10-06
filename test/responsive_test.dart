import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samarth_quotation/models/letterhead_density.dart';
import 'package:samarth_quotation/models/quotation_model.dart';
import 'package:samarth_quotation/screens/history_page.dart';
import 'package:samarth_quotation/screens/quotation_maker_screen.dart';
import 'package:samarth_quotation/widgets/editor/clean_form_editor.dart';
import 'package:samarth_quotation/widgets/fit_status_bar.dart';
import 'package:samarth_quotation/widgets/quotation_document_preview.dart';
import 'package:samarth_quotation/widgets/save_required_panel.dart';

/// Screen widths worth checking: the small phones, the two tablet sizes, and
/// the widths either side of every breakpoint in the app
/// (760 = compact app bar, 900 = app title, 1024 = two-column desktop).
const List<({String name, Size size})> _viewports = [
  (name: 'phone 320 (iPhone SE)', size: Size(320, 568)),
  (name: 'phone 360 (Android)', size: Size(360, 740)),
  (name: 'phone 375 (iPhone)', size: Size(375, 812)),
  (name: 'phone 414 (iPhone Plus)', size: Size(414, 896)),
  (name: 'phablet 600', size: Size(600, 960)),
  (name: 'tablet 759 (just under compact)', size: Size(759, 1024)),
  (name: 'tablet 760 (compact boundary)', size: Size(760, 1024)),
  (name: 'tablet 768 (iPad portrait)', size: Size(768, 1024)),
  (name: 'tablet 899 (just under title)', size: Size(899, 1024)),
  (name: 'tablet 900 (title boundary)', size: Size(900, 1024)),
  (name: 'laptop 1023 (just under desktop)', size: Size(1023, 768)),
  (name: 'laptop 1024 (desktop boundary)', size: Size(1024, 768)),
  (name: 'laptop 1280', size: Size(1280, 800)),
  (name: 'desktop 1440', size: Size(1440, 900)),
  (name: 'desktop 1920', size: Size(1920, 1080)),
];

/// Pump until the async work (the reference-number lookup) has settled, then
/// assert nothing overflowed. A single pump is not enough — the first frame
/// renders before the form is fully populated and hides real overflows.
Future<void> _expectNoOverflow(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull);
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

QuotationModel _quotation({int services = 2, int notes = 3}) {
  return QuotationModel.defaultTemplate(sequence: 146, today: DateTime(2026, 10, 2))
    ..clientName = 'M/S MASTIFF Hotel & Convention Centre Private Limited'
    ..clientCity = 'Sangli, Maharashtra'
    ..notes = List.generate(
        notes, (i) => 'Clause ${i + 1}: terms, conditions and statutory deductions apply.')
    ..items = List.generate(
      services,
      (i) => ServicePresets.presets[i % ServicePresets.presets.length].toItem(
        id: 'i$i',
        srNo: i + 1,
        shifts: i.isEven ? {DutyShift.day} : {DutyShift.day, DutyShift.night},
        skillLevels: i.isEven
            ? {SkillLevel.skilled}
            : {SkillLevel.skilled, SkillLevel.unskilled},
      ),
    );
}

Widget _host(Widget child, {double textScale = 1.0}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    );

void main() {
  group('Quotation maker screen lays out without overflow', () {
    for (final vp in _viewports) {
      testWidgets(vp.name, (tester) async {
        await _setViewport(tester, vp.size);
        await tester.pumpWidget(_host(const QuotationMakerScreen()));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Editor form lays out without overflow', () {
    for (final vp in _viewports) {
      testWidgets(vp.name, (tester) async {
        await _setViewport(tester, vp.size);
        await tester.pumpWidget(_host(
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CleanFormEditor(
                quotation: _quotation(services: 3),
                onChanged: (_) {},
                onGenerateRefNumber: () async {},
                onOpenHistory: () {},
              ),
            ),
          ),
        ));
        await _expectNoOverflow(tester);
      });
    }
  });

  group('Save-required panel lays out without overflow', () {
    for (final vp in _viewports) {
      testWidgets(vp.name, (tester) async {
        await _setViewport(tester, vp.size);
        await tester.pumpWidget(_host(
          Scaffold(
            body: SaveRequiredPanel(
              refNumber: 'Ref/146/Quots/S/X/2026',
              isSaving: false,
              blockingReason:
                  'Enter the client / company name first — the history is looked up by it.',
              onSave: () {},
            ),
          ),
        ));
        await _expectNoOverflow(tester);
      });
    }
  });

  group('Fit status bar lays out without overflow', () {
    // The longest message the bar can show.
    for (final vp in _viewports) {
      testWidgets('${vp.name} — measuring', (tester) async {
        await _setViewport(tester, vp.size);
        await tester.pumpWidget(_host(
          Scaffold(
            body: FitStatusBar(
              result: null,
              isMeasuring: true,
              fitToOnePage: true,
              onFitToOnePageChanged: (_) {},
            ),
          ),
        ));
        await _expectNoOverflow(tester);
      });
    }
  });

  group('Letterhead renders at every density', () {
    for (final scale in LetterheadDensity.fitSteps) {
      testWidgets('density ${(scale * 100).round()}%', (tester) async {
        await _setViewport(tester, const Size(1024, 1400));
        await tester.pumpWidget(_host(
          Scaffold(
            body: SingleChildScrollView(
              child: QuotationDocumentPreview(
                quotation: _quotation(services: 12),
                density: LetterheadDensity(scale),
              ),
            ),
          ),
        ));
        await _expectNoOverflow(tester);
      });
    }
  });

  group('Letterhead survives awkward content', () {
    testWidgets('very long client name and designations', (tester) async {
      await _setViewport(tester, const Size(1024, 1600));
      final q = _quotation(services: 2)
        ..clientName = 'M/S Vishwakarma Industrial Facility Management & '
            'Allied Services Private Limited, Unit II'
        ..items[0].category = 'Armed Security Guard (Gunman) — Night Patrol Division'
        ..items[0].customDutyText = '12 Hrs. rotating * 30 Days including weekly off';

      await tester.pumpWidget(_host(
        Scaffold(
          body: SingleChildScrollView(
            child: QuotationDocumentPreview(quotation: q),
          ),
        ),
      ));
      await _expectNoOverflow(tester);
    });

    testWidgets('no notes and no city', (tester) async {
      await _setViewport(tester, const Size(1024, 1400));
      final q = _quotation(services: 1, notes: 0)
        ..clientCity = ''
        ..kindAttention = '';

      await tester.pumpWidget(_host(
        Scaffold(
          body: SingleChildScrollView(
            child: QuotationDocumentPreview(quotation: q),
          ),
        ),
      ));
      await _expectNoOverflow(tester);
    });
  });

  group('History page lays out without overflow', () {
    // Firebase is not up in tests, so this exercises the unreachable-history
    // state — the one a user sees when they are offline.
    for (final vp in _viewports) {
      testWidgets(vp.name, (tester) async {
        await _setViewport(tester, vp.size);
        await tester.pumpWidget(_host(const HistoryPage()));
        await _expectNoOverflow(tester);
      });
    }
  });

  group('Survives larger system text', () {
    // Someone with poor eyesight turning the OS text size up.
    const scales = [1.3, 1.5, 2.0];
    const sizes = [Size(375, 812), Size(768, 1024), Size(1440, 900)];

    for (final scale in scales) {
      for (final size in sizes) {
        testWidgets('editor at ${size.width.toInt()}px, text x$scale', (tester) async {
          await _setViewport(tester, size);
          await tester.pumpWidget(_host(
            const QuotationMakerScreen(),
            textScale: scale,
          ));
          await _expectNoOverflow(tester);
        });
      }
    }
  });
}
