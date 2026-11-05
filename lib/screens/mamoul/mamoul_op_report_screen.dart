import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../models/mamoul_op_report.dart';
import '../../services/arabic_format.dart';
import '../../services/mamoul_op_report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_op_report_form_screen.dart';
import 'mamoul_op_report_print_screen.dart';
import 'mamoul_widgets.dart';

/// تفاصيل «تقرير تشغيل المعمول» بنفس ترتيب الورقة، مع أزرار الطباعة والتعديل
/// والإخفاء (حسب صلاحية المستخدم كما يرسلها السيرفر).
class MamoulOpReportScreen extends StatefulWidget {
  final String reportId;
  final MamoulOpConfig config;

  const MamoulOpReportScreen({super.key, required this.reportId, required this.config});

  @override
  State<MamoulOpReportScreen> createState() => _MamoulOpReportScreenState();
}

class _MamoulOpReportScreenState extends State<MamoulOpReportScreen> {
  MamoulOpReport? _report;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await MamoulOpReportService.fetchReport(widget.reportId);
      if (!mounted) return;
      setState(() => _report = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mamoulErrorText(e));
    }
  }

  void _print(MamoulOpReport r) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MamoulOpReportPrintScreen(reportId: r.id, batchNo: r.batchNo)),
    );
  }

  Future<void> _edit(MamoulOpReport r) async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MamoulOpReportFormScreen(
          config: widget.config,
          initialDate: mamoulParseDate(r.ballMakeDate) ?? DateTime.now(),
          existing: r,
        ),
      ),
    );
    if (id != null && mounted) _load();
  }

  Future<void> _hide(MamoulOpReport r) async {
    final ok = await confirmMamoul(
      context,
      title: 'إخفاء التقرير',
      message: 'سيختفي تقرير الدفعة «${r.batchNo}» من القائمة. لا يُحذف من قاعدة البيانات.',
      confirmLabel: 'إخفاء',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await MamoulOpReportService.hideReport(r.id);
      notifyMamoulOpChanged();
      if (!mounted) return;
      showMamoulSnack(context, 'أُخفي تقرير الدفعة ${r.batchNo}');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _body(MamoulOpReport r) {
    final times = <String>[
      if (r.startTime != null) 'من ${mamoulTimeLabel(r.startTime!)}',
      if (r.endTime != null) 'إلى ${mamoulTimeLabel(r.endTime!)}',
    ];
    final weight = r.batchWeightG == null ? '—' : '${mamoulGramsText(r.batchWeightG)} (${mamoulKgText(r.batchWeightG)})';
    final meta = <String>[
      if (r.createdBy != null) 'أدخله: ${r.createdBy}',
      if (r.createdAt != null) ArabicFormat.dateTime(r.createdAt!),
      if (r.updatedBy != null && r.updatedBy != r.createdBy) 'آخر تعديل: ${r.updatedBy}',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: [
        MamoulCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mamoul Operating Report',
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 22),
              _row('اسم المنتج', r.productName),
              _row('رقم الدفعة', r.batchNo),
              _row('تاريخ تكوير الكرات', mamoulDateLabel(r.ballMakeDate)),
              _row('وزن الدفعة', weight),
              _row('الوقت', times.isEmpty ? '—' : times.join(' ')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MamoulCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('أسماء العاملات (Workers names)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (r.groups.isEmpty)
                const Text('لم تُسجَّل مكائن ولا عاملات', style: TextStyle(fontSize: 13, color: AppColors.textMuted))
              else
                for (final g in r.groups)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'المكائن: ${g.machines.trim().isEmpty ? '—' : g.machines}',
                          style: const TextStyle(fontSize: 13, color: kMamoulColor, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        if (g.workers.isEmpty)
                          const Text('بلا عاملات', style: TextStyle(fontSize: 12.5, color: AppColors.textFaint))
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final w in g.workers)
                                StatusPill(label: w.label, color: AppColors.textPrimary, background: AppColors.divider),
                            ],
                          ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MamoulCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('ملاحظات (NOTE)', r.notes ?? '—'),
              _row('المشغّلة (Operate by)', r.operatorName ?? '—'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 128,
                      child: Text('التوقيع (Signature)', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                    ),
                    Expanded(
                      child: r.signaturePng != null
                          ? Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Image.memory(r.signaturePng!, height: 56, fit: BoxFit.contain),
                            )
                          : const Text('بلا توقيع', style: TextStyle(fontSize: 13, color: AppColors.textFaint)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(meta.join(' — '), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'طباعة التقرير (نفس شكل الورقة)',
          color: kMamoulColor,
          icon: Icons.print_outlined,
          onPressed: _busy ? null : () => _print(r),
        ),
        if (r.canEdit) ...[
          const SizedBox(height: 10),
          MamoulOutlineButton(label: 'تعديل التقرير', icon: Icons.edit_outlined, onPressed: _busy ? null : () => _edit(r)),
        ],
        if (widget.config.canManage) ...[
          const SizedBox(height: 10),
          MamoulOutlineButton(
            label: 'إخفاء التقرير',
            icon: Icons.visibility_off_outlined,
            color: kMamoulDanger,
            onPressed: _busy ? null : () => _hide(r),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    Widget body;
    if (r != null) {
      body = _body(r);
    } else if (_error != null) {
      body = ListView(children: [MamoulErrorView(message: _error!, onRetry: _load)]);
    } else {
      body = const MamoulLoadingView();
    }
    return Scaffold(
      appBar: ScreenTopBar(title: r == null ? 'تقرير التشغيل' : 'دفعة ${r.batchNo}'),
      body: body,
    );
  }
}
