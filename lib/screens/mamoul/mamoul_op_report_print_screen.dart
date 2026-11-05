import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../services/html_report_opener.dart';
import '../../services/mamoul_op_report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_widgets.dart';

/// طباعة «تقرير تشغيل المعمول» بنفس شكل الورقة (QMS-PD-006). السيرفر يبني
/// صفحة HTML من البيانات المدخلة، وهذه الشاشة تعرضها:
///
/// • أندرويد: تتحول إلى PDF عبر Printing.convertHtml (مع مهلة 20 ثانية ورسالة
///   واضحة بدل تحميل لا ينتهي) — قابل للطباعة والمشاركة.
/// • ويب: يُفتح التقرير في تبويب جديد للطباعة أو الحفظ PDF (Ctrl+P).
class MamoulOpReportPrintScreen extends StatefulWidget {
  final String reportId;
  final String batchNo;

  const MamoulOpReportPrintScreen({super.key, required this.reportId, required this.batchNo});

  @override
  State<MamoulOpReportPrintScreen> createState() => _MamoulOpReportPrintScreenState();
}

class _MamoulOpReportPrintScreenState extends State<MamoulOpReportPrintScreen> {
  String? _html;
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
      _error = null;
      _html = null;
    });
    try {
      final html = await MamoulOpReportService.fetchPrintHtml(widget.reportId);
      if (!mounted) return;
      setState(() => _html = html);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mamoulErrorText(e));
    }
  }

  String get _fileName {
    final safe = widget.batchNo.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'mamoul_operating_report_$safe.pdf';
  }

  Future<Uint8List> _build(dynamic format) async {
    try {
      return await Printing.convertHtml(format: format, html: _html!).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      if (mounted) setState(() => _timedOut = true);
      rethrow;
    }
  }

  void _retry() => setState(() {
        _timedOut = false;
        _attempt++;
      });

  void _openOnWeb() {
    final html = _html;
    if (html == null) return;
    final opened = openHtmlReportInNewTab(html);
    if (!opened && mounted) {
      showMamoulSnack(context, 'منع المتصفح فتح التبويب الجديد — اسمح للموقع بالنوافذ المنبثقة ثم أعد المحاولة', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_error != null) {
      body = Center(child: MamoulErrorView(message: _error!, onRetry: _load));
    } else if (_html == null) {
      body = const MamoulLoadingView();
    } else if (kIsWeb) {
      body = _WebPrintView(onOpen: _openOnWeb);
    } else if (_timedOut) {
      body = _TimeoutView(onRetry: _retry);
    } else {
      body = PdfPreview(
        key: ValueKey(_attempt),
        build: _build,
        allowSharing: true,
        allowPrinting: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: _fileName,
        loadingWidget: const Center(child: CircularProgressIndicator(color: kMamoulColor)),
      );
    }
    return Scaffold(
      appBar: const ScreenTopBar(title: 'طباعة تقرير التشغيل'),
      body: body,
    );
  }
}

class _WebPrintView extends StatelessWidget {
  final VoidCallback onOpen;
  const _WebPrintView({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 48, color: kMamoulColor),
            const SizedBox(height: 16),
            const Text(
              'التقرير جاهز بنفس شكل الورقة',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'اضغط الزر بالأسفل لفتح التقرير في تبويب جديد، ثم استخدم الطباعة في '
              'المتصفح (Ctrl+P) واختر طابعتك، أو اختر «حفظ كـ PDF».',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'فتح التقرير', color: kMamoulColor, icon: Icons.open_in_new, onPressed: onOpen),
          ],
        ),
      ),
    );
  }
}

class _TimeoutView extends StatelessWidget {
  final VoidCallback onRetry;
  const _TimeoutView({required this.onRetry});

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
              'هذه الشاشة تعتمد على مكوّن "Android System WebView" في الجوال لتحويل التقرير إلى PDF. '
              'إن استمرت المشكلة، حدّث هذا المكوّن من متجر Google Play ثم أعد المحاولة.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'إعادة المحاولة', color: kMamoulColor, icon: Icons.refresh, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
