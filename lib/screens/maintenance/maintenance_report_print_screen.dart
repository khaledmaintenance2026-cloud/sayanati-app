import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/maintenance_report.dart';
import '../../services/maintenance_report_html.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// تقرير PDF قابل للطباعة/المشاركة لبلاغ صيانة واحد — يُبنى كـHTML بنفس هوية
/// تقرير الإنتاج ثم يُحوَّل لملف PDF عبر محرك عرض النظام (لا حاجة لخط عربي
/// خاص، النص يظهر بشكل سليم دائمًا).
class MaintenanceReportPrintScreen extends StatelessWidget {
  final MaintenanceReport report;
  const MaintenanceReportPrintScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final html = buildMaintenanceReportHtml(report);

    return Scaffold(
      appBar: const ScreenTopBar(title: 'تقرير البلاغ'),
      body: PdfPreview(
        build: (format) => Printing.convertHtml(format: format, html: html),
        allowSharing: true,
        allowPrinting: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'تقرير_بلاغ_${report.id.substring(0, 8)}.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator(color: AppColors.maintenance)),
      ),
    );
  }
}
