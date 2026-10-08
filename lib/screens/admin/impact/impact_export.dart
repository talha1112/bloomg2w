import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../models/bloom_session.dart';
import '../../../services/session_service.dart';

const List<String> _reportHeaders = [
  'Session Title',
  'Program',
  'Age Group',
  'Date',
  'Registered',
  'Attended',
  'Attendance Rate %',
  'Completed',
  'Survey Responses',
  'Reported Learning %',
  'Reported Application %',
  'Comparable Confidence Pairs',
  'Avg Confidence Change',
];

List<List<String>> _buildImpactRows(List<BloomSession> sessions, Map<String, SessionImpactBundle> bundles) {
  final rows = <List<String>>[];
  for (final session in sessions) {
    final bundle = bundles[session.id];
    if (bundle == null) continue;
    rows.add([
      session.title,
      session.program,
      session.ageGroup,
      '${session.date.year}-${session.date.month.toString().padLeft(2, '0')}-${session.date.day.toString().padLeft(2, '0')}',
      '${bundle.registeredCount}',
      '${bundle.attendedCount}',
      bundle.attendanceRate.toStringAsFixed(1),
      '${bundle.completedCount}',
      '${bundle.surveyResponseCount}',
      bundle.reportedLearningPercent?.toStringAsFixed(1) ?? 'N/A',
      bundle.reportedApplicationPercent?.toStringAsFixed(1) ?? 'N/A',
      '${bundle.comparableConfidencePairCount}',
      bundle.avgConfidenceChange?.toStringAsFixed(2) ?? 'N/A',
    ]);
  }
  return rows;
}

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

Future<void> _shareFile(BuildContext context, String filename, List<int> bytes) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], subject: 'Bloom G2W Impact Report');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not export report: $e')));
  }
}

/// Exports the current dashboard's filtered sessions as a de-identified,
/// aggregated (session-level, not participant-level) CSV report — safe to
/// hand to grants/sponsors/board reviewers. Uses the OS share sheet so it
/// works the same way across every platform without a bespoke download UI.
Future<void> exportImpactReportCsv(
  BuildContext context, {
  required List<BloomSession> sessions,
  required Map<String, SessionImpactBundle> bundles,
}) async {
  final rows = [_reportHeaders, ..._buildImpactRows(sessions, bundles)];
  final csv = rows.map((row) => row.map(_csvEscape).join(',')).join('\n');
  await _shareFile(context, 'bloom_impact_report_${DateTime.now().millisecondsSinceEpoch}.csv', csv.codeUnits);
}

/// Same aggregated, de-identified data as the CSV export, as a real
/// styled .xlsx workbook.
Future<void> exportImpactReportExcel(
  BuildContext context, {
  required List<BloomSession> sessions,
  required Map<String, SessionImpactBundle> bundles,
}) async {
  final workbook = xls.Excel.createExcel();
  final sheet = workbook['Impact Report'];
  workbook.setDefaultSheet('Impact Report');

  final headerStyle = xls.CellStyle(
    bold: true,
    backgroundColorHex: xls.ExcelColor.fromHexString('#1A2E7A'),
    fontColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
  );

  for (var col = 0; col < _reportHeaders.length; col++) {
    final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
    cell.value = xls.TextCellValue(_reportHeaders[col]);
    cell.cellStyle = headerStyle;
  }

  final rows = _buildImpactRows(sessions, bundles);
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value = xls.TextCellValue(rows[r][c]);
    }
  }

  final bytes = workbook.save();
  if (bytes == null) return;
  await _shareFile(context, 'bloom_impact_report_${DateTime.now().millisecondsSinceEpoch}.xlsx', bytes);
}

const _pdfRoyalDeep = PdfColor.fromInt(0xFF101C52);
const _pdfRoyal = PdfColor.fromInt(0xFF1A2E7A);
const _pdfAdminGold = PdfColor.fromInt(0xFFD4AF37);
const _pdfInkSoft = PdfColor.fromInt(0xFF5B5E7E);

/// A formatted, presentation-ready PDF report using the Bloom G2W brand
/// colors — same aggregated, de-identified session-level data as CSV/Excel.
Future<void> exportImpactReportPdf(
  BuildContext context, {
  required List<BloomSession> sessions,
  required Map<String, SessionImpactBundle> bundles,
  String? programFilter,
  String? ageGroupFilter,
}) async {
  final doc = pw.Document();
  final rows = _buildImpactRows(sessions, bundles);
  final now = DateTime.now();

  final filterSummary = [
    if (programFilter != null) 'Program: $programFilter',
    if (ageGroupFilter != null) 'Age Group: $ageGroupFilter',
  ].join(' · ');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _pdfAdminGold, width: 2))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Bloom G2W — Impact Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _pdfRoyalDeep)),
                if (filterSummary.isNotEmpty) pw.Text(filterSummary, style: const pw.TextStyle(fontSize: 9, color: _pdfInkSoft)),
              ],
            ),
            pw.Text('Generated ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}', style: const pw.TextStyle(fontSize: 9, color: _pdfInkSoft)),
          ],
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _pdfInkSoft)),
      ),
      build: (context) => [
        pw.SizedBox(height: 12),
        pw.Text(
          'Aggregated, de-identified session-level data. Confidence change is reported only where a comparable pre/post pair exists for the same participant.',
          style: pw.TextStyle(fontSize: 8, color: _pdfInkSoft, fontStyle: pw.FontStyle.italic),
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: _reportHeaders,
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: _pdfRoyal),
          cellStyle: const pw.TextStyle(fontSize: 7.5),
          cellAlignment: pw.Alignment.centerLeft,
          border: null,
          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
        ),
      ],
    ),
  );

  final bytes = await doc.save();
  if (!context.mounted) return;
  await _shareFile(context, 'bloom_impact_report_${now.millisecondsSinceEpoch}.pdf', bytes);
}
