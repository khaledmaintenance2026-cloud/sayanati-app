import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/leaves.dart';
import '../../services/leaves_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'leaves_widgets.dart';

/// نموذج إجازة (جديدة أو تعديل). المدخلات تواريخ فقط (بدء + عودة متوقعة، وتاريخ
/// المباشرة عند تعديل إجازة سُجّلت مباشرتها)، وتحت الحقول «معاينة قبل الحفظ»
/// يحسبها السيرفر لحظيًا: الرصيد المتاح عند البدء + الأيام المدفوعة + أيام بدون راتب.
/// يُرجع true عند الحفظ.
class LeaveFormScreen extends StatefulWidget {
  final LeaveEmployee employee;
  final LeaveRecord? existing;

  const LeaveFormScreen({super.key, required this.employee, this.existing});

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  final TextEditingController _note = TextEditingController();
  final TextEditingController _replacement = TextEditingController();
  DateTime? _start;
  DateTime? _expected;
  DateTime? _actual;

  LeavePreview? _preview;
  String? _previewError;
  bool _previewLoading = false;
  Timer? _debounce;
  int _previewSeq = 0;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _start = leaveParseDate(ex?.start);
    _expected = leaveParseDate(ex?.expected);
    _actual = leaveParseDate(ex?.actual);
    if (_expected == null && _actual != null) _expected = _actual;
    _note.text = ex?.note ?? '';
    _replacement.text = ex?.replacement ?? '';
    if (_start != null && _expected != null) {
      _previewLoading = true;
      _debounce = Timer(const Duration(milliseconds: 50), _runPreview);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _note.dispose();
    _replacement.dispose();
    super.dispose();
  }

  // ------------------------------- المعاينة -------------------------------

  void _schedulePreview() {
    _debounce?.cancel();
    _previewSeq++; // أي رد قديم قيد الانتظار يُهمَل
    if (_start == null || _expected == null) {
      setState(() {
        _preview = null;
        _previewError = null;
        _previewLoading = false;
      });
      return;
    }
    setState(() {
      _previewLoading = true;
      _previewError = null;
    });
    _debounce = Timer(const Duration(milliseconds: 350), _runPreview);
  }

  Future<void> _runPreview() async {
    final s = _start;
    final e = _expected;
    if (s == null || e == null) return;
    final a = _actual;
    final seq = ++_previewSeq;
    try {
      final p = await LeavesService.preview(
        employeeId: widget.employee.id,
        start: leaveIsoDate(s),
        expected: leaveIsoDate(e),
        actual: a == null ? null : leaveIsoDate(a),
        excludeLeaveId: widget.existing?.id,
      );
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _preview = p;
        _previewError = null;
        _previewLoading = false;
      });
    } catch (err) {
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _preview = null;
        _previewError = leavesErrorText(err);
        _previewLoading = false;
      });
    }
  }

  // ------------------------------- تغيّر الحقول -------------------------------

  void _onStart(DateTime? d) {
    if (d == null) return;
    _start = d;
    final e = _expected;
    if (e != null && !e.isAfter(d)) _expected = null;
    final a = _actual;
    if (a != null && !a.isAfter(d)) _actual = null;
    _error = null;
    _schedulePreview();
  }

  void _onExpected(DateTime? d) {
    if (d == null) return;
    _expected = d;
    _error = null;
    _schedulePreview();
  }

  void _onActual(DateTime? d) {
    if (d == null) return;
    _actual = d;
    _error = null;
    _schedulePreview();
  }

  // ------------------------------- الحفظ -------------------------------

  Future<void> _save() async {
    final s = _start;
    final e = _expected;
    if (s == null) {
      setState(() => _error = 'اختر تاريخ بدء الإجازة');
      return;
    }
    if (e == null) {
      setState(() => _error = 'اختر تاريخ العودة المتوقعة');
      return;
    }
    final a = _actual;
    final note = _note.text.trim();
    final replacement = _replacement.text.trim();
    final ex = widget.existing;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (ex == null) {
        await LeavesService.addLeave(
          widget.employee.id,
          start: leaveIsoDate(s),
          expected: leaveIsoDate(e),
          note: note,
          replacement: replacement,
        );
      } else {
        await LeavesService.updateLeave(
          ex.id,
          start: leaveIsoDate(s),
          expected: leaveIsoDate(e),
          actual: a == null ? null : leaveIsoDate(a),
          note: note,
          replacement: replacement,
        );
      }
      notifyLeavesChanged();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = leavesErrorText(err);
      });
    }
  }

  // ------------------------------- الواجهة -------------------------------

  Widget _line(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15.5 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final p = _preview;
    final children = <Widget>[
      const Text('معاينة قبل الحفظ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
    ];

    if (_start == null || _expected == null) {
      children.add(const Text(
        'اختر تاريخ البدء وتاريخ العودة المتوقعة لتظهر مدة الإجازة والرصيد والأيام المدفوعة وبدون راتب.',
        style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.6),
      ));
    } else if (_previewError != null) {
      children.add(InfoNote(text: _previewError!, color: kLeavesDanger, icon: Icons.error_outline));
    } else if (p == null) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kLeavesColor)),
            SizedBox(width: 10),
            Text('جارٍ حساب الرصيد...', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ],
        ),
      ));
    } else {
      children.add(_line('مدة الإجازة', leaveDays(p.duration), bold: true));
      if (!p.hasBalance || p.balanceAtStart == null || p.paid == null || p.unpaid == null) {
        children.add(const SizedBox(height: 4));
        children.add(InfoNote(
          text: p.message ?? 'لا يمكن حساب الرصيد: أدخل تاريخ مباشرة الموظف أولًا',
          color: AppColors.warningText,
          icon: Icons.info_outline,
        ));
      } else {
        final paid = p.paid ?? 0;
        final unpaid = p.unpaid ?? 0;
        children.add(const Divider(height: 14, color: AppColors.divider));
        children.add(_line('الرصيد المتاح عند البدء', leaveAmountDays(p.balanceAtStart ?? 0)));
        children.add(_line('أيام مدفوعة', leaveDays(paid), color: AppColors.successText, bold: true));
        children.add(_line('أيام بدون راتب', leaveDays(unpaid), color: unpaid > 0 ? kLeavesDanger : AppColors.textPrimary, bold: true));
        children.add(const SizedBox(height: 4));
        children.add(Text(
          p.paidRounding == 'nearest'
              ? 'يُقرَّب الرصيد لأقرب يوم عند احتساب الأيام المدفوعة.'
              : 'يُقرَّب الرصيد للأسفل عند احتساب الأيام المدفوعة.',
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ));
      }
    }

    return Opacity(
      opacity: _previewLoading && p != null ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.existing;
    final isEdit = ex != null;
    final emp = widget.employee;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(now.year + 3, 12, 31);
    final empStart = leaveParseDate(emp.startDate);
    final startFirst = empStart ?? DateTime(2015);
    final s = _start;
    final afterStart = s == null ? DateTime(2015) : DateTime(s.year, s.month, s.day + 1);
    final available = emp.available;

    return Scaffold(
      appBar: ScreenTopBar(title: isEdit ? 'تعديل الإجازة' : 'إجازة جديدة'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Text(emp.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(
            (emp.hasBalance && available != null)
                ? 'الرقم الوظيفي ${emp.numberLabel}  ·  الرصيد المتاح اليوم ${leaveAmountDays(available)}'
                : 'الرقم الوظيفي ${emp.numberLabel}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          LeaveDateField(
            label: 'تاريخ بدء الإجازة',
            hint: 'اختر تاريخ البدء',
            value: _start,
            firstDate: startFirst,
            lastDate: lastDate,
            onChanged: _onStart,
          ),
          const SizedBox(height: 12),
          LeaveDateField(
            label: 'تاريخ العودة المتوقعة',
            hint: 'اختر تاريخ العودة',
            value: _expected,
            firstDate: afterStart.isAfter(lastDate) ? lastDate : afterStart,
            lastDate: lastDate,
            onChanged: _onExpected,
          ),
          if (_actual != null) ...[
            const SizedBox(height: 12),
            LeaveDateField(
              label: 'تاريخ المباشرة الفعلي بعد الإجازة',
              hint: 'اختر التاريخ',
              value: _actual,
              firstDate: afterStart.isAfter(today) ? today : afterStart,
              lastDate: today,
              onChanged: _onActual,
            ),
          ],
          const SizedBox(height: 12),
          const Text('الموظف البديل (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _replacement,
            maxLength: 120,
            textInputAction: TextInputAction.next,
            decoration: fieldDecoration(hint: 'اسم من يقوم بعمله أثناء الإجازة'),
          ),
          const SizedBox(height: 4),
          const Text('ملاحظة (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 3,
            maxLength: 300,
            decoration: fieldDecoration(hint: 'أي ملاحظة تخص هذه الإجازة'),
          ),
          const SizedBox(height: 8),
          _previewCard(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InfoNote(text: _error!, color: kLeavesDanger, icon: Icons.error_outline),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: _saving ? 'جارٍ الحفظ...' : (isEdit ? 'حفظ التعديلات' : 'حفظ الإجازة'),
            color: kLeavesColor,
            icon: Icons.check,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
