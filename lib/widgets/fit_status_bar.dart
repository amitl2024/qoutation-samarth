import 'package:flutter/material.dart';

import '../services/pdf_generator.dart';

/// Tells you, above the letterhead, whether the quotation lands on one sheet —
/// and when it only does so because the text was shrunk, offers the choice of
/// printing at full size across two pages instead.
class FitStatusBar extends StatelessWidget {
  final PdfBuildResult? result;
  final bool isMeasuring;
  final bool fitToOnePage;
  final ValueChanged<bool> onFitToOnePageChanged;

  const FitStatusBar({
    super.key,
    required this.result,
    required this.isMeasuring,
    required this.fitToOnePage,
    required this.onFitToOnePageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isMeasuring) {
      return _shell(
        background: const Color(0xFFF1F5F9),
        border: const Color(0xFFE2E8F0),
        icon: null,
        iconColor: const Color(0xFF64748B),
        text: 'Checking the page count…',
        textColor: const Color(0xFF475569),
        leading: const SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF64748B)),
        ),
      );
    }

    final r = result;
    if (r == null) return const SizedBox.shrink();

    // Runs onto more than one sheet.
    if (!r.fitsOnOnePage) {
      // Deliberate, because the fit was switched off — not a problem.
      if (!r.fitAttempted) {
        return _shell(
          background: const Color(0xFFF1F5F9),
          border: const Color(0xFFE2E8F0),
          icon: Icons.description_outlined,
          iconColor: const Color(0xFF475569),
          text: r.fitSummary,
          textColor: const Color(0xFF334155),
          trailing: _fullSizeToggle(const Color(0xFF334155)),
        );
      }
      return _shell(
        background: const Color(0xFFFEF2F2),
        border: const Color(0xFFFECACA),
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFB91C1C),
        text: r.fitSummary,
        textColor: const Color(0xFF991B1B),
        trailing: _fullSizeToggle(const Color(0xFF991B1B)),
      );
    }

    // Fits, but only because the body was compressed.
    if (r.wasCompressed) {
      return _shell(
        background: const Color(0xFFFFFBEB),
        border: const Color(0xFFFDE68A),
        icon: Icons.compress,
        iconColor: const Color(0xFFB45309),
        text: r.fitSummary,
        textColor: const Color(0xFF92400E),
        trailing: _fullSizeToggle(const Color(0xFF92400E)),
      );
    }

    // Comfortably one page.
    return _shell(
      background: const Color(0xFFF0FDF4),
      border: const Color(0xFFBBF7D0),
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF15803D),
      text: r.fitSummary,
      textColor: const Color(0xFF166534),
    );
  }

  Widget _fullSizeToggle(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Fit to 1 page',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
        ),
        const SizedBox(width: 4),
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value: fitToOnePage,
            onChanged: onFitToOnePageChanged,
            activeThumbColor: color,
          ),
        ),
      ],
    );
  }

  Widget _shell({
    required Color background,
    required Color border,
    required IconData? icon,
    required Color iconColor,
    required String text,
    required Color textColor,
    Widget? leading,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          leading ?? Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: textColor, height: 1.35),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }
}
