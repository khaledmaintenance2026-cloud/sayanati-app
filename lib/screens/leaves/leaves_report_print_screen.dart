import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/leaves.dart';
import '../../services/html_report_opener.dart';
import '../../services/leaves_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'leaves_widgets.dart';

/// يفتح ملف Excel للتقرير في المتصفح الخارجي (رابط مباشر بنفس رمز الدخول)، فيُحفَظ
/// مباشرة على الجهاز. يُستعمل من تبويب التقارير ومن شاشة الطباعة.
Future<void> downloadLeavesExcel(BuildContext context, {String? employeeId, String? status}) async {
  final uri = LeavesService.excelUri(employeeId: employeeId, status: status);
  if (uri == null) {
    showLeavesSnack(context, 'سجّل الدخول أولًا ثم أعد المحاولة', error: true);
    return;
  }
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    showLeavesSnack(context, 'تعذّر فتح رابط التنزيل', error: true);
  }
}

/// تقرير الإجازات (شامل أو كشف موظف) كملف PDF قابل للطباعة والمشاركة — نفس آلية
/// تقرير العمل الإضافي: السيرفر يبني صفحة HTML بنفس أعمدة ملف الإكسل، ثم:
///
/// • أندرويد: تتحول إلى PDF عبر Printing.convertHtml (مكوّن Android System WebView)
///   بمهلة 20 ثانية ورسالة واضحة بدل تحميل لا ينتهي.
/// • ويب: convertHtml غير مدعوم، فتُفتح الصفحة في تبويب جديد ليطبعها المستخدم أو
///   يحفظها PDF بخاصية الطباعة في المتصفح (Ctrl+P).
///
/// وفي الشريط العلوي زر «تنزيل Excel» لنفس التقرير.
class LeavesReportPrintScreen extends StatefulWidget {
  /// null = تقرير شامل، وإلا كشف هذا الموظف.
  final String? employeeId;

  /// فلتر الحالة للتقرير الشامل (active | on_leave | upcoming | late) أو null للكل.
  final String? status;

  /// عنوان الشريط العلوي قبل وصول التقرير.
  final String title;

  const LeavesReportPrintScreen({super.key, this.employeeId, this.status, required this.title});

  @override
  State<LeavesReportPrintScreen> createState() => _LeavesReportPrintScreenState();
}

class _LeavesReportPrintScreenState extends State<LeavesReportPrintScreen> {
  LeaveReportData? _report;
  bool _loading = true;
  String? _error;
  bool _timedOut = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _timedOut = false;
    });
    try {
      final r = await LeavesService.fetchReport(employeeId: widget.employeeId, status: widget.status);
      if (!mounted) return;
      setState(() {
        _report = r;
        _loading = false;
        _attempt++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = leavesErrorText(e);
        _loading = false;
      });
    }
  }

  Future<Uint8List> _build(dynamic format) async {
    final r = _report;
    if (r == null) return Uint8List(0);
    // التقرير الشامل أفقي (A4 عرضي) وكشف الموظف طولي.
    dynamic target = format;
    if (r.isLandscape) {
      try {
        target = format.landscape;
      } catch (_) {
        target = format;
      }
    }
    try {
      final bytes = await Printing.convertHtml(format: target, html: r.html).timeout(const Duration(seconds: 20));
      return bytes;
    } on TimeoutException {
      if (mounted) setState(() => _timedOut = true);
      rethrow;
    }
  }

  void _retryConvert() => setState(() {
        _timedOut = false;
        _attempt++;
      });

  void _openOnWeb() {
    final r = _report;
    if (r == null) return;
    final opened = openHtmlReportInNewTab(r.html);
    if (!opened && mounted) {
      showLeavesSnack(context, 'منع المتصفح فتح التبويب الجديد — اسمح للموقع بالنوافذ المنبثقة ثم أعد المحاولة', error: true);
    }
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kLeavesColor));
    }
    final r = _report;
    if (r == null) {
      return ListView(children: [LeavesErrorView(message: _error ?? 'تعذّر تجهيز التقرير', onRetry: _load)]);
    }
    if (kIsWeb) return _WebPrintView(report: r, onOpen: _openOnWeb);
    if (_timedOut) return _ConversionTimeoutView(onRetry: _retryConvert);
    return PdfPreview(
      key: ValueKey(_attempt),
      build: _build,
      allowSharing: true,
      allowPrinting: true,
      canChangeOrientation: false,
      canChangePageFormat: false,
      pdfFileName: r.filename,
      loadingWidget: const Center(child: CircularProgressIndicator(color: kLeavesColor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return Scaffold(
      appBar: ScreenTopBar(
        title: r == null ? widget.title : r.title,
        actions: [
          IconButton(
            tooltip: 'تنزيل Excel',
            icon: const Icon(Icons.table_view_outlined, color: kLeavesColor),
            onPressed: () => downloadLeavesExcel(context, employeeId: widget.employeeId, status: widget.status),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _body(),
    );
  }
}

/// على الويب: زر يفتح التقرير في تبويب جديد للطباعة/الحفظ كـ PDF.
class _WebPrintView extends StatelessWidget {
  final LeaveReportData report;
  final VoidCallback onOpen;

  const _WebPrintView({required this.report, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 48, color: kLeavesColor),
            const SizedBox(height: 16),
            const Text(
              'التقرير جاهز للفتح',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              report.subtitle,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'اضغط الزر بالأسفل لفتح التقرير في تبويب جديد، ثم استخدم خاصية '
              'الطباعة في المتصفح (Ctrl+P) واختر "حفظ كـ PDF" لحفظه، '
              'أو اختر طابعتك للطباعة مباشرة.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'فتح التقرير', color: kLeavesColor, icon: Icons.open_in_new, onPressed: onOpen),
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
              'إن استمرت المشكلة، جرّب تحديث هذا المكوّن من متجر Google Play ثم أعد المحاولة، '
              'أو استخدم زر «تنزيل Excel» في أعلى الشاشة.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'إعادة المحاولة', color: kLeavesColor, icon: Icons.refresh, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
