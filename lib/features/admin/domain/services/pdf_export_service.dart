import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/attendance_report_model.dart';
import '../../../../core/services/app_translations.dart';

class PdfExportService {
  Future<Uint8List> generatePdf(
    AttendanceReport report,
    String langCode,
  ) async {
    final pdf = pw.Document();

    final fontRegular = langCode == 'ar'
        ? await PdfGoogleFonts.notoNaskhArabicRegular()
        : await PdfGoogleFonts.robotoRegular();
    final fontBold = langCode == 'ar'
        ? await PdfGoogleFonts.notoNaskhArabicBold()
        : await PdfGoogleFonts.robotoBold();

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('yyyy-MM-dd HH:mm');
    final hmFormat = DateFormat('HH:mm:ss');
    final textDirection =
        langCode == 'ar' ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        textDirection: textDirection,
        pageFormat: PdfPageFormat.a4.landscape, // Landscape for detailed table
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) =>
            _buildHeader(report, dateFormat, timeFormat, langCode),
        footer: (pw.Context context) => _buildFooter(context, langCode),
        build: (pw.Context context) => [
          _buildExecutiveSummary(report, langCode),
          pw.SizedBox(height: 20),
          ..._buildEmployeeSummary(report, langCode),
          pw.SizedBox(height: 20),
          ..._buildDetailedAttendance(report, dateFormat, hmFormat, langCode),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(
    AttendanceReport report,
    DateFormat dateFormat,
    DateFormat timeFormat,
    String langCode,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              AppTranslations.text(langCode, 'pdfReportTitle'),
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              '${AppTranslations.text(langCode, 'pdfGenerated')} ${timeFormat.format(report.generatedAt)}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${AppTranslations.text(langCode, 'pdfReportingPeriod')} ${dateFormat.format(report.startDate)} – ${dateFormat.format(report.endDate)}',
              style: const pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey800,
              ),
            ),
            pw.Text(
              '${AppTranslations.text(langCode, 'pdfGeneratedBy')} ${report.generatedBy} | ${AppTranslations.text(langCode, 'pdfScope')} ${AppTranslations.text(langCode, report.scope)}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.5, color: PdfColors.blueGrey400),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context, String langCode) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        '${AppTranslations.text(langCode, 'pdfPageOf')} ${context.pageNumber} ${AppTranslations.text(langCode, 'pdfOf')} ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  pw.Widget _buildExecutiveSummary(AttendanceReport report, String langCode) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            AppTranslations.text(langCode, 'pdfExecutiveSummary'),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                AppTranslations.text(langCode, 'xlsTotalEmployees'),
                report.totalEmployees.toString(),
              ),
              _buildSummaryItem(
                AppTranslations.text(langCode, 'xlsOverallAttendanceRate'),
                '${report.attendanceRate.toStringAsFixed(1)}%',
              ),
              _buildSummaryItem(
                AppTranslations.text(langCode, 'xlsPresent'),
                report.present.toString(),
              ),
              _buildSummaryItem(
                AppTranslations.text(langCode, 'xlsLate'),
                report.late.toString(),
              ),
              _buildSummaryItem(
                AppTranslations.text(langCode, 'xlsAbsent'),
                report.absent.toString(),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                AppTranslations.text(langCode, 'xlsLeave'),
                report.leaves.toString(),
              ),
              _buildSummaryItem(
                AppTranslations.text(langCode, 'xlsTotalWorkedHours'),
                report.totalWorkedHours.toStringAsFixed(1),
              ),
              _buildSummaryItem(
                AppTranslations.text(langCode, 'xlsTotalLateHours'),
                (report.totalLateMinutes / 60).toStringAsFixed(1),
              ),
              pw.SizedBox(width: 50), // Spacer
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  List<pw.Widget> _buildEmployeeSummary(
    AttendanceReport report,
    String langCode,
  ) {
    return [
      pw.Text(
        AppTranslations.text(langCode, 'pdfEmployeeSummary'),
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: [
          AppTranslations.text(langCode, 'pdfColEmployeeId'),
          AppTranslations.text(langCode, 'pdfColName'),
          AppTranslations.text(langCode, 'pdfColDept'),
          AppTranslations.text(langCode, 'pdfColSch'),
          AppTranslations.text(langCode, 'pdfColExpDays'),
          AppTranslations.text(langCode, 'pdfColPresent'),
          AppTranslations.text(langCode, 'pdfColLate'),
          AppTranslations.text(langCode, 'pdfColAbsent'),
          AppTranslations.text(langCode, 'pdfColHrs'),
          AppTranslations.text(langCode, 'pdfColRate'),
        ],
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 10,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue600),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellHeight: 20,
        data: report.employeeSummaries
            .map(
              (emp) => [
                emp.employeeId,
                emp.employeeName,
                emp.department,
                emp.schedule,
                emp.expectedWorkingDays.toString(),
                emp.present.toString(),
                emp.late.toString(),
                emp.absent.toString(),
                emp.totalWorkedHours.toStringAsFixed(1),
                '${emp.attendanceRate.toStringAsFixed(1)}%',
              ],
            )
            .toList(),
      ),
    ];
  }

  List<pw.Widget> _buildDetailedAttendance(
    AttendanceReport report,
    DateFormat dateFormat,
    DateFormat timeFormat,
    String langCode,
  ) {
    return [
      pw.Text(
        AppTranslations.text(langCode, 'pdfDetailedAttendance'),
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: [
          AppTranslations.text(langCode, 'pdfColDate'),
          AppTranslations.text(langCode, 'pdfColEmployee'),
          AppTranslations.text(langCode, 'pdfColExpected'),
          AppTranslations.text(langCode, 'pdfColIn'),
          AppTranslations.text(langCode, 'pdfColOut'),
          AppTranslations.text(langCode, 'pdfColStatus'),
          AppTranslations.text(langCode, 'pdfColLateHrs'),
          AppTranslations.text(langCode, 'pdfColHrs'),
        ],
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 10,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellHeight: 20,
        data: report.detailedRecords
            .map(
              (r) => [
                dateFormat.format(r.date),
                r.employeeName,
                r.expectedToWork
                    ? AppTranslations.text(langCode, 'yes')
                    : AppTranslations.text(langCode, 'no'),
                r.status.toLowerCase() != 'absent' && r.checkIn != null
                    ? timeFormat.format(r.checkIn!)
                    : '-',
                r.status.toLowerCase() != 'absent' && r.checkOut != null
                    ? timeFormat.format(r.checkOut!)
                    : '-',
                AppTranslations.text(langCode, r.status.toLowerCase())
                    .toUpperCase(),
                (r.lateMinutes / 60).toStringAsFixed(1),
                r.workHours.toStringAsFixed(1),
              ],
            )
            .toList(),
      ),
    ];
  }
}
