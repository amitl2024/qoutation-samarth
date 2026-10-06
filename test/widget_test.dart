import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:samarth_quotation/models/letterhead_density.dart';
import 'package:samarth_quotation/models/quotation_model.dart';
import 'package:samarth_quotation/services/history_service.dart';
import 'package:samarth_quotation/services/native_share/native_share.dart';
import 'package:samarth_quotation/services/pdf_generator.dart';

void main() {
  group('Reference number', () {
    test('is built in the house format with the month roman numeral', () {
      final ref = QuotationModel.buildRefNumber(146, DateTime(2026, 10, 2));
      expect(ref, 'Ref/146/Quots/S/X/2026');
    });

    test('round-trips through the sequence parser', () {
      final ref = QuotationModel.buildRefNumber(207, DateTime(2026, 12, 31));
      expect(ref, 'Ref/207/Quots/S/XII/2026');
      expect(HistoryService.sequenceOf(ref), 207);
    });

    test('becomes a legal Firestore document id', () {
      final id = HistoryService.docIdFor('Ref/146/Quots/S/X/2026');
      expect(id.contains('/'), isFalse);
      expect(id, 'Ref-146-Quots-S-X-2026');
    });
  });

  group('Default template', () {
    test('uses today for both the date and the inked stamp', () {
      final today = DateTime(2026, 10, 2);
      final q = QuotationModel.defaultTemplate(sequence: 146, today: today);

      expect(q.date, today);
      expect(q.formattedDate, '02/10/2026');
      expect(q.dateStampText, '02 OCT 2026');
      expect(q.signatoryDate, '02/10/2026');
      expect(q.refNumber, 'Ref/146/Quots/S/X/2026');
    });

    test('defaults to the current date when none is given', () {
      final q = QuotationModel.defaultTemplate();
      final now = DateTime.now();
      expect(q.date.year, now.year);
      expect(q.date.month, now.month);
      expect(q.date.day, now.day);
    });
  });

  group('Service lines', () {
    test('every requested designation is offered in the dropdown', () {
      final categories = ServicePresets.presets.map((p) => p.category).toList();
      expect(
        categories,
        containsAll([
          'Office Boy (Male)',
          'Office Boy (Female)',
          'Security Guard (Male)',
          'Security Guard (Female)',
          'Housekeeping Staff (Male)',
          'Housekeeping Staff (Female)',
          'Bouncer (Male)',
          'Bouncer (Female)',
          'Armed Security Guard (Gunman)',
        ]),
      );
    });

    test('shift and skill selections survive a JSON round-trip', () {
      final item = QuotationItem(
        id: 'i1',
        srNo: 1,
        category: 'Bouncer (Male)',
        shifts: {DutyShift.day, DutyShift.night},
        skillLevels: {SkillLevel.skilled, SkillLevel.unskilled},
      );

      final restored = QuotationItem.fromJson(item.toJson());
      expect(restored.shifts, {DutyShift.day, DutyShift.night});
      expect(restored.skillLevels, {SkillLevel.skilled, SkillLevel.unskilled});
      expect(restored.isSkilled, isTrue);
      expect(restored.isUnskilled, isTrue);
    });

    test('a line can cover both shifts and both classifications', () {
      final both = QuotationItem(
        id: 'b',
        srNo: 1,
        category: 'Security Guard (Male)',
        shifts: {DutyShift.night, DutyShift.day},
        skillLevels: {SkillLevel.unskilled, SkillLevel.skilled},
      );

      // Order is normalised so the document never reshuffles them.
      expect(both.shiftLabel, 'Day & Night');
      expect(both.skillLabel, 'Skilled & Unskilled');
      expect(both.shiftLabelWrapped, 'Day &\nNight');
      expect(both.orderedSkillLevels, [SkillLevel.skilled, SkillLevel.unskilled]);
    });

    test('a line can never end up with nothing selected', () {
      final empty = QuotationItem(
        id: 'e',
        srNo: 1,
        category: 'Office Boy (Male)',
        shifts: {},
        skillLevels: {},
      );
      expect(empty.shifts, {DutyShift.day});
      expect(empty.skillLevels, {SkillLevel.unskilled});
    });

    test('quotations saved before multi-select still load', () {
      // The old format stored a single name under `shift` / `skillLevel`.
      final restored = QuotationItem.fromJson({
        'id': 'legacy',
        'srNo': 1,
        'category': 'Housekeeping Staff (Male)',
        'shift': 'night',
        'skillLevel': 'skilled',
        'dutyHours': 8,
        'workingDays': 26,
        'ratePerPerson': 11500.0,
      });

      expect(restored.shifts, {DutyShift.night});
      expect(restored.skillLevels, {SkillLevel.skilled});
    });

    test('older saved items with no shift at all fall back to day/unskilled', () {
      final restored = QuotationItem.fromJson({
        'id': 'legacy',
        'srNo': 1,
        'category': 'Housekeeping Staff (Male)',
        'dutyHours': 8,
        'workingDays': 26,
        'ratePerPerson': 11500.0,
      });

      expect(restored.shifts, {DutyShift.day});
      expect(restored.skillLevels, {SkillLevel.unskilled});
    });

    test('presets carry sensible skill defaults', () {
      expect(
        ServicePresets.findByCategory('Armed Security Guard (Gunman)')!.defaultSkillLevel,
        SkillLevel.skilled,
      );
      expect(
        ServicePresets.findByCategory('Housekeeping Staff (Female)')!.defaultSkillLevel,
        SkillLevel.unskilled,
      );
      expect(
        ServicePresets.findByCategory('Office Boy (Male)')!.defaultWorkingDays,
        26,
      );
    });
  });

  group('PDF generation', () {
    QuotationModel sample({int serviceCount = 3}) {
      final presets = ServicePresets.presets;
      return QuotationModel.defaultTemplate(sequence: 146, today: DateTime(2026, 10, 2))
        ..clientName = 'M/S MASTIFF Hotel'
        ..clientCity = 'Sangli'
        ..items = List.generate(
          serviceCount,
          (i) => presets[i % presets.length].toItem(
            id: 'item_$i',
            srNo: i + 1,
            shifts: i.isEven ? {DutyShift.day} : {DutyShift.day, DutyShift.night},
          ),
        );
    }

    test('produces a non-empty PDF with the tick-mark column', () async {
      final bytes = await PdfGeneratorService.buildBytes(sample());
      expect(bytes.lengthInBytes, greaterThan(1000));
      // %PDF header
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('lays out across pages when many services are added', () async {
      final bytes = await PdfGeneratorService.buildBytes(sample(serviceCount: 30));
      expect(bytes.lengthInBytes, greaterThan(1000));
    });

    test('file name is derived from the reference number and client', () {
      final name = PdfGeneratorService.fileNameFor(sample());
      expect(name, 'Quotation_Ref_146_Quots_S_X_2026_M_S_MASTIFF_Hotel.pdf');
    });
  });

  group('Skill column', () {
    test('a single classification reads as just that one', () {
      final skilled = QuotationItem(
        id: 's', srNo: 1, category: 'Bouncer (Male)', skillLevels: {SkillLevel.skilled});
      final unskilled = QuotationItem(
        id: 'u', srNo: 2, category: 'Office Boy (Male)', skillLevels: {SkillLevel.unskilled});

      expect(skilled.skillLabel, 'Skilled');
      expect(skilled.isSkilled, isTrue);
      expect(skilled.isUnskilled, isFalse);
      expect(unskilled.skillLabel, 'Unskilled');
      expect(unskilled.isSkilled, isFalse);
      expect(unskilled.isUnskilled, isTrue);
    });

    test('shift labels are the words printed in the Shift column', () {
      expect(DutyShift.day.label, 'Day');
      expect(DutyShift.night.label, 'Night');
    });

    test('a PDF with both shifts and both classifications still builds', () async {
      final q = QuotationModel.defaultTemplate(sequence: 146, today: DateTime(2026, 10, 2))
        ..clientName = 'M/S MASTIFF Hotel'
        ..items = [
          QuotationItem(
            id: 'a',
            srNo: 1,
            category: 'Security Guard (Male)',
            shifts: {DutyShift.day, DutyShift.night},
            skillLevels: {SkillLevel.skilled, SkillLevel.unskilled},
          ),
        ];

      final result = await PdfGeneratorService.build(q);
      expect(result.pageCount, 1);
      expect(String.fromCharCodes(result.bytes.sublist(0, 4)), '%PDF');
    });
  });

  group('One-page fit', () {
    QuotationModel withServices(int n) {
      return QuotationModel.defaultTemplate(sequence: 146, today: DateTime(2026, 10, 2))
        ..clientName = 'M/S MASTIFF Hotel'
        ..clientCity = 'Sangli'
        ..items = List.generate(
          n,
          (i) => ServicePresets.presets[i % ServicePresets.presets.length]
              .toItem(id: 'i$i', srNo: i + 1),
        );
    }

    test('a short quotation prints at full size on one page', () async {
      final r = await PdfGeneratorService.build(withServices(3));
      expect(r.pageCount, 1);
      expect(r.density.scale, 1.0);
      expect(r.wasCompressed, isFalse);
      expect(r.fitSummary, contains('full size'));
    });

    test('a long quotation is squeezed onto one page instead of spilling', () async {
      final long = withServices(14);

      final unfitted = await PdfGeneratorService.build(long, fitToOnePage: false);
      expect(unfitted.pageCount, greaterThan(1),
          reason: '14 services overflow a full-size sheet');

      final fitted = await PdfGeneratorService.build(long);
      expect(fitted.pageCount, 1);
      expect(fitted.wasCompressed, isTrue);
      expect(fitted.density.scale, lessThan(1.0));
      expect(fitted.density.scale, greaterThanOrEqualTo(LetterheadDensity.readableFloor));
    });

    test('never shrinks below the readable floor', () async {
      final r = await PdfGeneratorService.build(withServices(40));
      expect(r.density.scale, greaterThanOrEqualTo(LetterheadDensity.readableFloor));
      // Too long to fit at all — the summary must say what to do about it.
      expect(r.fitsOnOnePage, isFalse);
      expect(r.fitSummary, contains('Remove a service line'));
    });

    test('turning the fit off keeps the full-size layout', () async {
      final r = await PdfGeneratorService.build(withServices(14), fitToOnePage: false);
      expect(r.density.scale, 1.0);
      expect(r.wasCompressed, isFalse);
      expect(r.fitAttempted, isFalse);
      // A deliberate two-pager is reported as a choice, not a failure.
      expect(r.fitSummary, contains('Printing at full size'));
      expect(r.fitSummary, isNot(contains('Remove a service line')));
    });

    test('density scales sizes down but never up', () {
      const tight = LetterheadDensity(0.8);
      expect(LetterheadDensity.full.d(10), 10);
      expect(LetterheadDensity.full.gap(10), 10);
      expect(tight.d(10), lessThan(10));
      expect(tight.gap(10), lessThan(tight.d(10)),
          reason: 'whitespace gives way before text does');
    });
  });

  group('Native share', () {
    test('reports unsupported off the web, so the caller falls back', () async {
      // Under the VM test runner the stub implementation is compiled in.
      expect(NativeShare.isSupported, isFalse);

      final result = await NativeShare.shareFile(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'x.pdf',
        mimeType: 'application/pdf',
      );
      expect(result, NativeShareResult.unsupported);
    });

    test('a cancelled share is distinct from an unsupported one', () {
      // Dismissing the sheet must not trigger a download fallback.
      expect(NativeShareResult.cancelled, isNot(NativeShareResult.unsupported));
      expect(NativeShareResult.values, hasLength(3));
    });
  });
}
