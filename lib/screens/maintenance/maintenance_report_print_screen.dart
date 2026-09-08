import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/maintenance_report.dart';
import '../../services/app_state.dart';
import '../../services/html_report_opener.dart';
import '../../services/maintenance_report_html.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// تقرير PDF قابل للطباعة/المشاركة لبلاغ صيانة واحد — يُبنى كـHTML بنفس هوية
/// تقرير الإنتاج ثم يُحوَّل لملف PDF عبر محرك عرض النظام (لا حاجة لخط عربي
/// خاص، النص يظهر بشكل سليم دائمًا) — على أندرويد فقط.
///
/// عند فتح هذه الشاشة نجلب تفاصيل أمر العمل كاملة من السيرفر أولًا (وليس
/// الاعتماد فقط على النسخة المحلية الممرَّرة من شاشة القائمة) — تحديدًا
/// القطع/المواد المستخدمة الفعلية واسم الفني، التي لا تصل ضمن قائمة أوامر
/// العمل العامة (راجع AppState.fetchWorkOrderDetail). لو تعذّر الجلب لأي
/// سبب (لا اتصال إنترنت مثلًا)، نستمر بالنسخة المحلية الممرَّرة بدل حجب
/// التقرير بالكامل.
///
/// ملاحظة مهمة: التحويل من HTML إلى PDF (Printing.convertHtml) يعمل فقط على
/// أندرويد، ويعتمد داخليًا على مكوّن Android System WebView على الجهاز. على
/// بعض الأجهزة (خصوصًا لو كان هذا المكوّن قديمًا أو معطّلًا) قد تتعلّق
/// العملية للأبد بدون أي خطأ ظاهر — لذلك نضع مهلة زمنية هنا، وإن انتهت نعرض
/// رسالة واضحة بدل شاشة تحميل لا تنتهي أبدًا.
///
/// على الويب، convertHtml غير مدعوم إطلاقًا (لا يوجد له أي تنفيذ في حزمة
/// printing على منصة الويب) ويرمي UnimplementedError فورًا — لذلك نفتح على
/// الويب نفس تقرير الـHTML في تبويب متصفح جديد بدلًا من ذلك (راجع
/// lib/services/html_report_opener.dart)، ليستخدم المستخدم خاصية الطباعة/
/// الحفظ كـPDF المدمجة في المتصفح نفسه (Ctrl+P).
class MaintenanceReportPrintScreen extends StatefulWidget {
  final MaintenanceReport report;
  const MaintenanceReportPrintScreen({super.key, required this.report});

  @override
  State<MaintenanceReportPrintScreen> createState() => _MaintenanceReportPrintScreenState();
}

class _MaintenanceReportPrintScreenState extends State<MaintenanceReportPrintScreen> {
  bool _timedOut = false;
  int _attempt = 0;
  late MaintenanceReport _report;
  bool _loadingDetail = true;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await context.read<AppState>().fetchWorkOrderDetail(widget.report.id);
      if (!mounted) return;
      setState(() {
        _report = detail;
        _loadingDetail = false;
      });
    } catch (_) {
      // نستمر بالنسخة المحلية الممرَّرة بلا رسالة خطأ مزعجة — أهم شيء
      // إظهار التقرير، حتى لو ببيانات قد تكون أقدم قليلًا (بدون القطع
      // المستخدمة الدقيقة مثلًا).
      if (!mounted) return;
      setState(() => _loadingDetail = false);
    }
  }

  Future<Uint8List> _build(dynamic format) async {
    final html = buildMaintenanceReportHtml(_report);
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
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator(color: AppColors.maintenance))
          : (kIsWeb
              ? _WebPrintView(
                  color: AppColors.maintenance,
                  onOpen: () => openHtmlReportInNewTab(buildMaintenanceReportHtml(_report)),
                )
              : (_timedOut
                  ? _ConversionTimeoutView(onRetry: _retry)
                  : PdfPreview(
                      key: ValueKey(_attempt),
                      build: _build,
                      allowSharing: true,
                      allowPrinting: true,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      pdfFileName: 'تقرير_بلاغ_${_report.id}.pdf',
                      loadingWidget: const Center(child: CircularProgressIndicator(color: AppColors.maintenance)),
                    ))),
    );
  }
}

/// شاشة فتح التقرير على الويب — بدل معاينة PDF داخل التطبيق (غير مدعومة على
/// الويب)، نعرض زرًا يفتح التقرير في تبويب جديد ليطبعه المستخدم أو يحفظه
/// كـPDF من نافذة الطباعة الخاصة بالمتصفح نفسه.
class _WebPrintView extends StatelessWidget {
  final Color color;
  final VoidCallback onOpen;
  const _WebPrintView({required this.color, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_outlined, size: 48, color: color),
            const SizedBox(height: 16),
            const Text(
              'التقرير جاهز للفتح',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'اضغط الزر بالأسفل لفتح التقرير في تبويب جديد، ثم استخدم خاصية '
              'الطباعة في المتصفح (Ctrl+P أو ⌘+P) واختر "حفظ كـ PDF" لحفظه، '
              'أو اختر طابعتك للطباعة مباشرة.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'فتح التقرير', color: color, icon: Icons.open_in_new, onPressed: onOpen),
          ],
        ),
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
