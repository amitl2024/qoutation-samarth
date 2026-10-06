import 'package:flutter/material.dart';
import '../models/letterhead_density.dart';
import '../models/quotation_model.dart';

/// On-screen A4 letterhead. Rendered at the same [density] the PDF will print
/// at, so what is on screen is what comes out of the printer.
class QuotationDocumentPreview extends StatelessWidget {
  final QuotationModel quotation;
  final LetterheadDensity density;

  const QuotationDocumentPreview({
    super.key,
    required this.quotation,
    this.density = LetterheadDensity.full,
  });

  /// Scale a size the way the PDF does.
  double _d(double v) => density.d(v);

  /// Scale a vertical gap the way the PDF does.
  double _g(double v) => density.gap(v);

  TextStyle _serif(double size, {FontWeight? weight, TextDecoration? decoration}) {
    return TextStyle(
      fontFamily: 'serif',
      fontSize: _d(size),
      fontWeight: weight,
      decoration: decoration,
      color: Colors.black,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          width: 595, // Standard A4 width in points
          constraints: const BoxConstraints(minHeight: 842), // A4 height in points
          padding: EdgeInsets.symmetric(horizontal: _d(32), vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP HEADER BANNER — fixed furniture, never shrinks
              Image.asset(
                'assets/images/header_banner.png',
                width: double.infinity,
                height: 72,
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => _buildFallbackBanner(),
              ),

              SizedBox(height: _g(14)),

              // 2. REFERENCE, INKED DATE STAMP, ISO BADGE & RECIPIENT
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: To
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('To,', style: _serif(13, weight: FontWeight.bold)),
                        SizedBox(height: _g(2)),
                        Padding(
                          padding: EdgeInsets.only(left: _d(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quotation.clientName.isEmpty
                                    ? '_______________'
                                    : quotation.clientName,
                                style: _serif(13.5, weight: FontWeight.w900),
                              ),
                              if (quotation.clientCity.isNotEmpty) ...[
                                SizedBox(height: _g(1)),
                                Text(
                                  quotation.clientCity,
                                  style: _serif(13, weight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Center: Inked Date Stamp
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: quotation.showDateStamp && quotation.dateStampText.isNotEmpty
                          ? Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: _d(10),
                                vertical: _d(5),
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF1E3A8A), width: 1.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                quotation.dateStampText,
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: _d(15),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: _d(1.2),
                                  color: const Color(0xFF1E3A8A),
                                ),
                              ),
                            )
                          : const SizedBox(),
                    ),
                  ),

                  // Right: Ref No, Date, ISO Badge
                  Expanded(
                    flex: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                quotation.refNumber,
                                textAlign: TextAlign.right,
                                style: _serif(10, weight: FontWeight.bold),
                              ),
                              SizedBox(height: _g(2)),
                              Text(
                                'Date:${quotation.formattedDate}',
                                style: _serif(10, weight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        if (quotation.showIsoBadge) ...[
                          SizedBox(width: _d(6)),
                          Image.asset(
                            'assets/images/ISO.png',
                            width: _d(44),
                            height: _d(44),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: _g(14)),

              // 3. SUBJECT & KIND ATTENTION
              Center(
                child: Text(
                  'Sub: ${quotation.subject}',
                  textAlign: TextAlign.center,
                  style: _serif(13,
                      weight: FontWeight.bold, decoration: TextDecoration.underline),
                ),
              ),
              if (quotation.kindAttention.trim().isNotEmpty) ...[
                SizedBox(height: _g(5)),
                Center(
                  child: Text(
                    'Kind Attention: ${quotation.kindAttention}',
                    textAlign: TextAlign.center,
                    style: _serif(12.5,
                        weight: FontWeight.bold, decoration: TextDecoration.underline),
                  ),
                ),
              ],

              SizedBox(height: _g(14)),

              // 4. INTRO PARAGRAPH
              Text(
                quotation.introParagraph,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: _d(12),
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),

              SizedBox(height: _g(14)),

              // 5. SERVICES, SHIFT, SKILL & RATES TABLE
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Table(
                  columnWidths: {
                    0: FixedColumnWidth(_d(32)),
                    1: const FlexColumnWidth(4.2),
                    2: FixedColumnWidth(_d(46)),
                    3: const FlexColumnWidth(3.0),
                    4: FixedColumnWidth(_d(74)),
                    5: const FlexColumnWidth(3.0),
                  },
                  border: TableBorder.all(color: Colors.black, width: 1),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // Header Row
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: [
                        _TableHeadCell('Sr.\nNo.', density: density),
                        _TableHeadCell('Category', density: density),
                        _TableHeadCell('Shift', density: density),
                        _TableHeadCell('Duty', density: density),
                        _TableHeadCell('Skilled /\nUnskilled', density: density, fontSize: 11),
                        _TableHeadCell('Rate Per\nPerson', density: density),
                      ],
                    ),
                    // Item Rows
                    ...quotation.items.map(
                      (item) => TableRow(
                        children: [
                          _TableBodyCell('${item.srNo}',
                              density: density, align: TextAlign.center),
                          _TableBodyCell(item.category, density: density, isBold: true),
                          _TableBodyCell(item.shiftLabelWrapped,
                              density: density, align: TextAlign.center),
                          _TableBodyCell(item.displayDuty,
                              density: density, align: TextAlign.center),
                          _SkillCell(levels: item.orderedSkillLevels, density: density),
                          _TableBodyCell(item.displayRate,
                              density: density, align: TextAlign.center, isBold: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: _g(14)),

              // 6. NOTES & TERMS
              if (quotation.notes.isNotEmpty) ...[
                Text('Note:', style: _serif(12, weight: FontWeight.bold)),
                SizedBox(height: _g(4)),
                ...quotation.notes.asMap().entries.map((entry) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: _g(3)),
                    child: Text(
                      '${entry.key + 1})${entry.value}',
                      style: _serif(11.5),
                    ),
                  );
                }),
                SizedBox(height: _g(14)),
              ],

              // 7. CLOSING TEXT
              Center(
                child: Text(
                  quotation.closingNote,
                  textAlign: TextAlign.center,
                  style: _serif(12, weight: FontWeight.bold),
                ),
              ),

              SizedBox(height: _g(14)),

              // 8. SIGN-OFF, STAMPS & CONTACT SECTION
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(quotation.thankingText, style: _serif(11.5)),
                        SizedBox(height: _g(2)),
                        Text(
                          quotation.forCompanyText,
                          style: _serif(12.5, weight: FontWeight.bold),
                        ),
                        SizedBox(height: _g(4)),

                        // Signature
                        if (quotation.showSignature)
                          Image.asset(
                            'assets/images/sign.png',
                            height: _d(52),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                SizedBox(height: _d(52)),
                          )
                        else
                          SizedBox(height: _d(52)),

                        SizedBox(height: _g(2)),

                        Text(
                          '${quotation.signatoryName}  |  ${quotation.signatoryDate}',
                          style: _serif(10, weight: FontWeight.bold),
                        ),

                        SizedBox(height: _g(4)),

                        // Contacts
                        Text('Mob: ${quotation.contactMobile1}', style: _serif(10.5)),
                        if (quotation.contactMobile2.isNotEmpty)
                          Text(quotation.contactMobile2, style: _serif(10.5)),
                        Text(quotation.contactEmail, style: _serif(10.5)),

                        SizedBox(height: _g(8)),

                        // Address Stamp
                        if (quotation.showAddressStamp)
                          Image.asset(
                            'assets/images/address_stamp.png',
                            width: _d(165),
                            height: _d(48),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(),
                          ),
                      ],
                    ),
                  ),

                  // Right Side: Round Stamp
                  if (quotation.showRoundStamp)
                    Padding(
                      padding: EdgeInsets.only(top: _d(10), right: _d(16)),
                      child: Image.asset(
                        'assets/images/round_stamp.png',
                        width: _d(95),
                        height: _d(95),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            SizedBox(width: _d(95)),
                      ),
                    )
                  else
                    SizedBox(width: _d(95)),
                ],
              ),

              SizedBox(height: _g(24)),

              // 9. FOOTER — fixed furniture, never shrinks
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.black, width: 1)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Branches : ${quotation.branches}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reg. Off : ${quotation.registeredOffice}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.bold,
                        fontSize: 9.5,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Contact : ${quotation.contactMobile1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Socials — scaled down rather than clipped, so an unusually
                    // long e-mail or website still prints in full.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_outlined, size: 12, color: Colors.black87),
                          const SizedBox(width: 4),
                          Text(quotation.instagramHandle,
                              style: const TextStyle(fontSize: 9.5, color: Colors.black)),
                          const SizedBox(width: 14),
                          const Icon(Icons.email_outlined, size: 12, color: Colors.black87),
                          const SizedBox(width: 4),
                          Text(quotation.contactEmail,
                              style: const TextStyle(fontSize: 9.5, color: Colors.black)),
                          const SizedBox(width: 14),
                          const Icon(Icons.language, size: 12, color: Colors.black87),
                          const SizedBox(width: 4),
                          Text(quotation.contactWebsite,
                              style: const TextStyle(fontSize: 9.5, color: Colors.black)),
                        ],
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

  Widget _buildFallbackBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF0A192F),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('GADADE GROUP',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('SAMARTH SECURITY',
              style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _TableHeadCell extends StatelessWidget {
  final String text;
  final double fontSize;
  final LetterheadDensity density;

  const _TableHeadCell(this.text, {required this.density, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: density.d(4), vertical: density.gap(6)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'serif',
          fontWeight: FontWeight.w900,
          fontSize: density.d(fontSize),
          color: Colors.black,
        ),
      ),
    );
  }
}

class _TableBodyCell extends StatelessWidget {
  final String text;
  final TextAlign align;
  final bool isBold;
  final LetterheadDensity density;

  const _TableBodyCell(
    this.text, {
    required this.density,
    this.align = TextAlign.left,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: density.d(4), vertical: density.gap(8)),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontFamily: 'serif',
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: density.d(11.5),
          color: Colors.black,
        ),
      ),
    );
  }
}

/// The single "Skilled / Unskilled" column: a tick plus whichever
/// classification applies.
class _SkillCell extends StatelessWidget {
  final List<SkillLevel> levels;
  final LetterheadDensity density;

  const _SkillCell({required this.levels, required this.density});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: density.d(4), vertical: density.gap(8)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < levels.length; i++) ...[
            if (i > 0) SizedBox(height: density.gap(3)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check, size: density.d(12), color: Colors.black),
                SizedBox(width: density.d(3)),
                Flexible(
                  child: Text(
                    levels[i].label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontWeight: FontWeight.bold,
                      fontSize: density.d(10.5),
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
