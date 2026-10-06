
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/letterhead_density.dart';
import 'native_share/native_share.dart';
import '../models/quotation_model.dart';

/// Letterhead images, loaded once per PDF build.
class LetterheadAssets {
  pw.MemoryImage? headerBanner;
  pw.MemoryImage? isoBadge;
  pw.MemoryImage? signature;
  pw.MemoryImage? roundStamp;
  pw.MemoryImage? addressStamp;

  static Future<pw.MemoryImage?> _load(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static Future<LetterheadAssets> load() async {
    final assets = LetterheadAssets();
    assets.headerBanner = await _load('assets/images/header_banner.png');
    assets.isoBadge = await _load('assets/images/ISO.png');
    assets.signature = await _load('assets/images/sign.png');
    assets.roundStamp = await _load('assets/images/round_stamp.png');
    assets.addressStamp = await _load('assets/images/address_stamp.png');
    return assets;
  }
}

/// A built PDF plus what it took to fit it.
class PdfBuildResult {
  final Uint8List bytes;
  final int pageCount;
  final LetterheadDensity density;

  /// Whether the one-page fit was asked for. When it was not, a multi-page
  /// result is a deliberate choice rather than a problem.
  final bool fitAttempted;

  const PdfBuildResult({
    required this.bytes,
    required this.pageCount,
    required this.density,
    required this.fitAttempted,
  });

  bool get fitsOnOnePage => pageCount == 1;

  /// True when the quotation only fits because it was squeezed.
  bool get wasCompressed => density.isCompressed;

  /// Plain-language note for the UI.
  String get fitSummary {
    if (pageCount > 1) {
      if (!fitAttempted) {
        return 'Printing at full size across $pageCount pages. '
            'Turn on "Fit to 1 page" to shrink it onto one sheet.';
      }
      return 'This quotation needs $pageCount pages even at the smallest '
          'readable size. Remove a service line or shorten the notes to get it '
          'onto one page.';
    }
    if (wasCompressed) {
      return 'Fitted onto one page at ${(density.scale * 100).round()}% text size.';
    }
    return 'Fits on one page at full size.';
  }
}

class PdfGeneratorService {
  /// Build the letterhead at a given [density]. Use [buildBytes] instead unless
  /// you specifically need one fixed density.
  static Future<pw.Document> generatePdf(
    QuotationModel quotation, {
    LetterheadDensity density = LetterheadDensity.full,
    LetterheadAssets? preloadedAssets,
  }) async {
    final pdf = pw.Document(
      title: 'Quotation ${quotation.refNumber}',
      author: 'Samarth Security (Gadade Group)',
      subject: quotation.subject,
    );

    final assets = preloadedAssets ?? await LetterheadAssets.load();
    final z = density;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.only(
          left: z.d(32),
          right: z.d(32),
          top: 24,
          bottom: 18,
        ),
        header: (context) => context.pageNumber == 1
            ? _buildBanner(assets.headerBanner)
            : pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: _buildBanner(assets.headerBanner, height: 44),
              ),
        footer: (context) => _buildFooter(quotation, context),
        build: (pw.Context context) => [
          pw.SizedBox(height: z.gap(14)),

          // 1. REFERENCE, INKED DATE STAMP, ISO BADGE & RECIPIENT
          _buildAddressBlock(quotation, assets.isoBadge, z),

          pw.SizedBox(height: z.gap(14)),

          // 2. SUBJECT & KIND ATTENTION
          pw.Center(
            child: pw.Text(
              'Sub: ${quotation.subject}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: z.d(11.5),
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
          if (quotation.kindAttention.trim().isNotEmpty) ...[
            pw.SizedBox(height: z.gap(5)),
            pw.Center(
              child: pw.Text(
                'Kind Attention: ${quotation.kindAttention}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: z.d(11),
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
          ],

          pw.SizedBox(height: z.gap(14)),

          // 3. INTRO PARAGRAPH
          pw.Text(
            quotation.introParagraph,
            style: pw.TextStyle(fontSize: z.d(10.5), lineSpacing: z.d(2)),
          ),

          pw.SizedBox(height: z.gap(14)),

          // 4. SERVICES, SHIFT, SKILL & RATES TABLE
          _buildServicesTable(quotation, z),

          pw.SizedBox(height: z.gap(14)),

          // 5. NOTES & TERMS
          if (quotation.notes.isNotEmpty) ...[
            pw.Text(
              'Note:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: z.d(10.5)),
            ),
            pw.SizedBox(height: z.gap(4)),
            ...quotation.notes.asMap().entries.map((entry) {
              return pw.Padding(
                padding: pw.EdgeInsets.only(bottom: z.gap(3)),
                child: pw.Text(
                  '${entry.key + 1})${entry.value}',
                  style: pw.TextStyle(fontSize: z.d(10)),
                ),
              );
            }),
            pw.SizedBox(height: z.gap(14)),
          ],

          // 6. CLOSING STATEMENT
          pw.Center(
            child: pw.Text(
              quotation.closingNote,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: z.d(11)),
            ),
          ),

          pw.SizedBox(height: z.gap(14)),

          // 7. SIGN-OFF, STAMPS & CONTACT SECTION
          _buildSignOffBlock(quotation, assets, z),
        ],
      ),
    );

    return pdf;
  }

  /// Build the PDF, shrinking the body until it lands on a single sheet.
  ///
  /// Set [fitToOnePage] to false to always print at full size and let a long
  /// quotation run onto a second page.
  static Future<PdfBuildResult> build(
    QuotationModel quotation, {
    bool fitToOnePage = true,
  }) async {
    // Assets are the slow part — load once and reuse across attempts.
    final assets = await LetterheadAssets.load();

    if (!fitToOnePage) {
      final pdf = await generatePdf(quotation, preloadedAssets: assets);
      final pageCount = pdf.document.pdfPageList.pages.length;
      return PdfBuildResult(
        bytes: await pdf.save(),
        pageCount: pageCount,
        density: LetterheadDensity.full,
        fitAttempted: false,
      );
    }

    PdfBuildResult? last;
    for (final step in LetterheadDensity.fitSteps) {
      final density = LetterheadDensity(step);
      final pdf = await generatePdf(
        quotation,
        density: density,
        preloadedAssets: assets,
      );
      final pageCount = pdf.document.pdfPageList.pages.length;
      final result = PdfBuildResult(
        bytes: await pdf.save(),
        pageCount: pageCount,
        density: density,
        fitAttempted: true,
      );
      if (pageCount == 1) return result;
      last = result;
    }

    // Still too long even at the readable floor — hand back the tightest
    // version and let the caller tell the user what to cut.
    return last!;
  }

  /// How many pages the quotation needs, and at what text size, without
  /// keeping the bytes around. Used by the live "fits on one page" indicator.
  static Future<PdfBuildResult> measure(QuotationModel quotation) =>
      build(quotation, fitToOnePage: true);

  static pw.Widget _buildBanner(pw.MemoryImage? banner, {double height = 72}) {
    if (banner == null) return _buildFallbackHeader();
    return pw.Container(
      width: double.infinity,
      height: height,
      child: pw.Image(banner, fit: pw.BoxFit.fill),
    );
  }

  static pw.Widget _buildAddressBlock(
    QuotationModel quotation,
    pw.MemoryImage? isoBadge,
    LetterheadDensity z,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: To Recipient
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('To,',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: z.d(11))),
              pw.SizedBox(height: z.gap(2)),
              pw.Padding(
                padding: pw.EdgeInsets.only(left: z.d(14)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      quotation.clientName.isEmpty ? '_______________' : quotation.clientName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: z.d(11.5)),
                    ),
                    if (quotation.clientCity.isNotEmpty) ...[
                      pw.SizedBox(height: z.gap(1)),
                      pw.Text(
                        quotation.clientCity,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: z.d(11)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Center: Inked Date Stamp
        pw.Expanded(
          flex: 3,
          child: pw.Center(
            child: quotation.showDateStamp && quotation.dateStampText.isNotEmpty
                ? pw.Container(
                    padding: pw.EdgeInsets.symmetric(
                      horizontal: z.d(10),
                      vertical: z.d(5),
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColor.fromInt(0xFF283593),
                        width: 1.5,
                      ),
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Text(
                      quotation.dateStampText,
                      style: pw.TextStyle(
                        fontSize: z.d(13),
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF1A237E),
                      ),
                    ),
                  )
                : pw.SizedBox(),
          ),
        ),

        // Right: Ref, Date, ISO Badge
        pw.Expanded(
          flex: 4,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      quotation.refNumber,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: z.d(10)),
                    ),
                    pw.SizedBox(height: z.gap(3)),
                    pw.Text(
                      'Date:${quotation.formattedDate}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: z.d(10)),
                    ),
                  ],
                ),
              ),
              if (quotation.showIsoBadge && isoBadge != null) ...[
                pw.SizedBox(width: z.d(8)),
                pw.Container(
                  width: z.d(52),
                  height: z.d(52),
                  child: pw.Image(isoBadge, fit: pw.BoxFit.contain),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Sr. No. | Category | Shift | Duty | Skilled / Unskilled | Rate Per Person
  static pw.Widget _buildServicesTable(QuotationModel quotation, LetterheadDensity z) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 1.0),
      columnWidths: {
        0: pw.FixedColumnWidth(z.d(32)),
        1: const pw.FlexColumnWidth(4.2),
        2: pw.FixedColumnWidth(z.d(46)),
        3: const pw.FlexColumnWidth(3.0),
        4: pw.FixedColumnWidth(z.d(74)),
        5: const pw.FlexColumnWidth(3.0),
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          children: [
            _buildHeaderCell('Sr.\nNo.', z),
            _buildHeaderCell('Category', z),
            _buildHeaderCell('Shift', z),
            _buildHeaderCell('Duty', z),
            _buildHeaderCell('Skilled /\nUnskilled', z, fontSize: 9.5),
            _buildHeaderCell('Rate Per\nPerson', z),
          ],
        ),
        // Table Rows
        ...quotation.items.map(
          (item) => pw.TableRow(
            children: [
              _buildTableCell('${item.srNo}', z, align: pw.TextAlign.center),
              _buildTableCell(item.category, z, isBold: true),
              _buildTableCell(item.shiftLabelWrapped, z, align: pw.TextAlign.center),
              _buildTableCell(item.displayDuty, z, align: pw.TextAlign.center),
              _buildSkillCell(item.orderedSkillLevels, z),
              _buildTableCell(item.displayRate, z, align: pw.TextAlign.center, isBold: true),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSignOffBlock(
    QuotationModel quotation,
    LetterheadAssets assets,
    LetterheadDensity z,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Left Side: Thanking you, For Samarth Security, Signature, Contacts, Address stamp
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(quotation.thankingText, style: pw.TextStyle(fontSize: z.d(10.5))),
              pw.SizedBox(height: z.gap(2)),
              pw.Text(
                quotation.forCompanyText,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: z.d(11.5)),
              ),
              pw.SizedBox(height: z.gap(4)),

              // Signature
              if (quotation.showSignature && assets.signature != null)
                pw.Container(
                  height: z.d(52),
                  child: pw.Image(assets.signature!, fit: pw.BoxFit.contain),
                )
              else
                pw.SizedBox(height: z.d(52)),

              pw.SizedBox(height: z.gap(2)),

              pw.Text(
                '${quotation.signatoryName}  |  ${quotation.signatoryDate}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: z.d(9.5)),
              ),

              pw.SizedBox(height: z.gap(4)),

              // Contacts
              pw.Text('Mob: ${quotation.contactMobile1}',
                  style: pw.TextStyle(fontSize: z.d(9))),
              if (quotation.contactMobile2.isNotEmpty)
                pw.Text(quotation.contactMobile2, style: pw.TextStyle(fontSize: z.d(9))),
              pw.Text(quotation.contactEmail, style: pw.TextStyle(fontSize: z.d(9))),

              pw.SizedBox(height: z.gap(6)),

              // Address Stamp
              if (quotation.showAddressStamp && assets.addressStamp != null)
                pw.Container(
                  width: z.d(165),
                  height: z.d(48),
                  child: pw.Image(assets.addressStamp!, fit: pw.BoxFit.contain),
                ),
            ],
          ),
        ),

        // Right Side: Round Stamp
        if (quotation.showRoundStamp && assets.roundStamp != null)
          pw.Padding(
            padding: pw.EdgeInsets.only(top: z.d(10), right: z.d(10)),
            child: pw.Container(
              width: z.d(95),
              height: z.d(95),
              child: pw.Image(assets.roundStamp!, fit: pw.BoxFit.contain),
            ),
          )
        else
          pw.SizedBox(width: z.d(95)),
      ],
    );
  }

  static pw.Widget _buildFooter(QuotationModel quotation, pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(color: PdfColors.black, thickness: 1.0),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'Branches : ${quotation.branches}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Center(
          child: pw.Text(
            'Reg. Off : ${quotation.registeredOffice}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Center(
          child: pw.Text(
            'Contact : ${quotation.contactMobile1}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
          ),
        ),
        pw.SizedBox(height: 3),

        // Social bar — scaled down rather than clipped, so an unusually long
        // e-mail or website still prints in full.
        pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('${quotation.instagramHandle}     |     ',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Text('${quotation.contactEmail}     |     ',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Text(quotation.contactWebsite, style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),

        // Page x of y, only when the quotation runs onto a second page
        if (context.pagesCount > 1)
          pw.Center(
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildFallbackHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'GADADE GROUP',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 16,
            ),
          ),
          pw.Text(
            'SAMARTH SECURITY',
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFFF59E0B),
              fontWeight: pw.FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeaderCell(
    String text,
    LetterheadDensity z, {
    double fontSize = 10,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: z.d(4), vertical: z.gap(6)),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: z.d(fontSize)),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text,
    LetterheadDensity z, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: z.d(4), vertical: z.gap(8)),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: z.d(10),
        ),
        textAlign: align,
      ),
    );
  }

  /// The single "Skilled / Unskilled" column: a tick followed by whichever
  /// classification applies.
  static pw.Widget _buildSkillCell(List<SkillLevel> levels, LetterheadDensity z) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: z.d(4), vertical: z.gap(8)),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < levels.length; i++) ...[
            if (i > 0) pw.SizedBox(height: z.gap(3)),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                _buildTick(z),
                pw.SizedBox(width: z.d(4)),
                pw.Text(
                  levels[i].label,
                  style: pw.TextStyle(fontSize: z.d(9.5), fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// A hand-drawn tick. Drawn as vector strokes because the built-in PDF fonts
  /// carry no check glyph.
  static pw.Widget _buildTick(LetterheadDensity z) {
    return pw.CustomPaint(
      size: PdfPoint(z.d(11), z.d(10)),
      painter: (PdfGraphics canvas, PdfPoint size) {
        canvas
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(z.d(1.4))
          ..setLineCap(PdfLineCap.round)
          ..setLineJoin(PdfLineJoin.round)
          // PDF y-axis points up: left-middle -> bottom vertex -> top-right.
          ..moveTo(size.x * 0.09, size.y * 0.55)
          ..lineTo(size.x * 0.38, size.y * 0.15)
          ..lineTo(size.x * 0.91, size.y * 0.90)
          ..strokePath();
      },
    );
  }

  /// Suggested file name, e.g. `Quotation_Ref-146_MASTIFF_Hotel.pdf`
  static String fileNameFor(QuotationModel quotation) {
    String clean(String s) => s
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    final ref = clean(quotation.refNumber);
    final client = clean(quotation.clientName);
    final parts = ['Quotation', if (ref.isNotEmpty) ref, if (client.isNotEmpty) client];
    return '${parts.join('_')}.pdf';
  }

  static Future<Uint8List> buildBytes(
    QuotationModel quotation, {
    bool fitToOnePage = true,
  }) async =>
      (await build(quotation, fitToOnePage: fitToOnePage)).bytes;

  /// Print or open platform print dialog
  static Future<PdfBuildResult> printQuotation(
    QuotationModel quotation, {
    bool fitToOnePage = true,
  }) async {
    final result = await build(quotation, fitToOnePage: fitToOnePage);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => result.bytes,
      name: fileNameFor(quotation),
    );
    return result;
  }

  /// Hand the PDF to the OS share sheet (WhatsApp, Gmail, Drive…).
  /// On the web this downloads the file instead.
  static Future<PdfBuildResult> sharePdf(
    QuotationModel quotation, {
    bool fitToOnePage = true,
  }) async {
    final result = await build(quotation, fitToOnePage: fitToOnePage);
    final fileName = fileNameFor(quotation);

    // On a phone browser this opens the device's own share sheet with the PDF
    // attached — WhatsApp, Gmail, Drive and the rest come from the OS.
    final shared = await NativeShare.shareFile(
      bytes: result.bytes,
      fileName: fileName,
      mimeType: 'application/pdf',
      title: 'Quotation ${quotation.refNumber}',
      text: _shareCaption(quotation),
    );

    switch (shared) {
      case NativeShareResult.shared:
      case NativeShareResult.cancelled:
        return result;
      case NativeShareResult.unsupported:
        // Android/iOS apps land here and get the real native sheet; desktop
        // browsers get a download, which is the sensible equivalent.
        await Printing.sharePdf(bytes: result.bytes, filename: fileName);
        return result;
    }
  }

  /// Short line that rides along with the shared file.
  static String _shareCaption(QuotationModel quotation) {
    final to = quotation.clientName.trim();
    return [
      'Quotation ${quotation.refNumber} from Samarth Security',
      if (to.isNotEmpty) 'For: $to',
      'Date: ${quotation.formattedDate}',
    ].join('\n');
  }
}
