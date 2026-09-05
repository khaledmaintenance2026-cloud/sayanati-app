import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/maintenance_report.dart';
import '../../services/maintenance_report_html.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// تقرير PDF قابل للطباعة/المشاركة لبلاغ صيانة واحد — يُبنى كـHTML بنفس هوية
/// تقرير الإنتاج ثم يُحوَّل لملف PDF عبر محرك عرض النظام (لا حاجة لخط عربي
/// خاص، النص يظهر بشكل سليم دائمًا).
///
/// ملاحظة مهمة: التحويل من HTML إلى PDF (Printing.convertHtml) يعتمد داخليًا
/// على مكوّن Android System WebView على الجهاز. على بعض الأجهزة (خصوصًا لو
/// كان هذا المكوّن قديمًا أو معطّلًا) قد تتعلّق العملية للأبد بدون أي خطأ
/// ظاهر — لذلك نضع مهلة زمنية هنا، وإن انتهت نعرض رسالة واضحة بدل شاشة تحميل
/// لا تنتهي أبدًا.
class MaintenanceReportPrintScreen extends StatefulWidget {
  final MaintenanceReport report;
  const MaintenanceReportPrintScreen({super.key, required this.report});

  @override
  State<MaintenanceReportPrintScreen> createState() => _MaintenanceReportPrintScreenState();
}

class _MaintenanceReportPrintScreenState extends State<MaintenanceReportPrintScreen> {
  bool _timedOut = false;
  int _attempt = 0;

  Future<Uint8List> _build(dynamic format) async {
    final html = buildMaintenanceReportHtml(widget.report);
    try {
      final bytes = await Printing.convertHtml(format: format, html: html)
          .timeout(const Duration(seconds: 20));
      return bytes;
    } on TimeoutException {
      if (mounted) setState(() => _timedOut = true);
      rethrow;
    }
  }

  void _retry() => setState(() {
        _timedOut = false;
        _attempt++;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenTopBar(title: 'تقرير البلاغ'),
      body: _timedOut ? _ConversionTimeoutView(onRetry: _retry) : PdfPreview(
        key: ValueKey(_attempt),
        build: _build,
        allowSharing: true,
        allowPrinting: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'تقرير_بلاغ_${widget.report.id.substring(0, 8)}.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator(color: AppColors.maintenance)),
      ),
    );
  }
}

class _ConversionTimeoutView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ConversionTimeoutView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'تعذّر تجهيز ملف PDF لهذا التقرير',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'هذه الشاشة تعتمد على مكوّن "Android System WebView" في هاتفك لتحويل التقرير إلى PDF. '
              'إن استمرت المشكلة، جرّب تحديث هذا التطبيق من متجر Google Play (ابحث عن "Android System WebView") ثم أعد المحاولة.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'إعادة المحاولة', color: AppColors.maintenance, icon: Icons.refresh, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
