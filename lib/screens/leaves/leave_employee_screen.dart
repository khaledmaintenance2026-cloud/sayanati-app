import 'package:flutter/material.dart';

import '../../models/leaves.dart';
import '../../services/leaves_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'leave_form_screen.dart';
import 'leave_return_sheet.dart';
import 'leaves_employee_form_sheet.dart';
import 'leaves_widgets.dart';

/// صفحة موظف في قسم الإجازات: بياناته وحالته وتنبيهاته وأرصدته (متاح/مُستحَق/مستخدم/
/// سقط) وسجل إجازاته مع أزرار «تسجيل المباشرة» و«تعديل» و«حذف»، وزر «إجازة جديدة».
class LeaveEmployeeScreen extends StatefulWidget {
  final String employeeId;
  final String? initialName;

  const LeaveEmployeeScreen({super.key, required this.employeeId, this.initialName});

  @override
  State<LeaveEmployeeScreen> createState() => _LeaveEmployeeScreenState();
}

class _LeaveEmployeeScreenState extends State<LeaveEmployeeScreen> {
  LeaveEmployee? _emp;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final e = await LeavesService.fetchEmployee(widget.employeeId);
      if (!mounted) return;
      setState(() {
        _emp = e;
        _loading = false;
        _error = null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = leavesErrorText(err);
        _loading = false;
      });
    }
  }

  // ------------------------------- الإجراءات -------------------------------

  Future<void> _editEmployee() async {
    final e = _emp;
    if (e == null) return;
    final saved = await showLeaveEmployeeFormSheet(context, existing: e);
    if (saved == true) {
      notifyLeavesChanged();
      await _load();
    }
  }

  Future<void> _openLeaveForm({LeaveRecord? existing}) async {
    final e = _emp;
    if (e == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LeaveFormScreen(employee: e, existing: existing)),
    );
    if (saved == true) {
      if (mounted) showLeavesSnack(context, existing == null ? 'تم حفظ الإجازة' : 'تم حفظ التعديلات');
      await _load();
    }
  }

  Future<void> _registerReturn(LeaveRecord leave) async {
    final e = _emp;
    if (e == null) return;
    final saved = await showLeaveReturnSheet(context, employee: e, leave: leave);
    if (saved == true) {
      notifyLeavesChanged();
      if (mounted) showLeavesSnack(context, 'تم تسجيل المباشرة');
      await _load();
    }
  }

  Future<void> _deleteLeave(LeaveRecord leave) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإجازة؟'),
        content: Text(
          'سيُحذف سجل الإجازة التي بدأت ${leaveDateLabel(leave.start)}، وتُعاد حسابات الرصيد تلقائيًا. استخدم الحذف فقط لإجازة سُجّلت بالخطأ.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف', style: TextStyle(color: kLeavesDanger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final updated = await LeavesService.deleteLeave(leave.id);
      if (!mounted) return;
      setState(() => _emp = updated);
      notifyLeavesChanged();
      showLeavesSnack(context, 'تم حذف الإجازة');
    } catch (err) {
      if (!mounted) return;
      showLeavesSnack(context, leavesErrorText(err), error: true);
    }
  }

  // ------------------------------- أجزاء الواجهة -------------------------------

  IconData _alertIcon(String code) {
    switch (code) {
      case 'late':
        return Icons.schedule;
      case 'at_cap':
        return Icons.warning_amber_rounded;
      case 'soon':
        return Icons.event_outlined;
      case 'no_return':
        return Icons.event_busy;
      default:
        return Icons.info_outline;
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _kv(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(LeaveEmployee e) {
    final n = e.name.trim();
    final initial = n.isEmpty ? '؟' : n.substring(0, 1);
    final dept = e.department;
    return _card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: kLeavesColor.withOpacity(0.1),
            child: Text(initial, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: kLeavesColor)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(
                  dept == null ? 'الرقم الوظيفي: ${e.numberLabel}' : 'الرقم الوظيفي: ${e.numberLabel}  ·  $dept',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                LeaveStatusPill(status: e.status, label: e.statusLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _alerts(LeaveEmployee e) {
    final out = <Widget>[];
    for (final a in e.alerts) {
      out.add(InfoNote(text: a.text, color: leaveAlertColor(a.code), icon: _alertIcon(a.code)));
      out.add(const SizedBox(height: 8));
    }
    final needsData = e.hasAlert('missing_dates') || e.hasAlert('fix_number') || e.hasAlert('missing_number');
    if (needsData) {
      out.add(
        OutlinedButton.icon(
          onPressed: _editEmployee,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('استكمال بيانات الموظف'),
          style: OutlinedButton.styleFrom(foregroundColor: kLeavesColor, side: const BorderSide(color: kLeavesColor)),
        ),
      );
      out.add(const SizedBox(height: 8));
    }
    return out;
  }

  Widget _datesCard(LeaveEmployee e) {
    final service = e.serviceDays;
    return _card(
      child: Column(
        children: [
          _kv('تاريخ التعيين', leaveDateLabel(e.hireDate)),
          _kv('تاريخ المباشرة', leaveDateLabel(e.startDate)),
          if (service != null) _kv('مدة الخدمة', leaveServiceText(service)),
        ],
      ),
    );
  }

  Widget _balanceSection(LeaveEmployee e) {
    final available = e.available;
    if (!e.hasBalance || available == null) {
      return const InfoNote(
        text: 'لا يمكن حساب الأرصدة قبل إدخال تاريخ المباشرة. استخدم زر «استكمال بيانات الموظف».',
        color: AppColors.warningText,
        icon: Icons.info_outline,
      );
    }
    final cap = e.capDays;
    final tiles = <Widget>[
      LeaveStatTile(
        label: 'الرصيد المتاح الآن',
        value: leaveAmountDays(available),
        valueColor: e.atCap ? AppColors.warningText : kLeavesColor,
      ),
      LeaveStatTile(label: 'المُستحَق منذ المباشرة', value: leaveAmountDays(e.accrued ?? 0)),
      LeaveStatTile(label: 'المُستخدَم', value: leaveAmountDays(e.used ?? 0)),
      LeaveStatTile(label: 'سقط بعد انتهاء الصلاحية', value: leaveAmountDays(e.expired ?? 0)),
      LeaveStatTile(
        label: 'إجمالي أيام بدون راتب',
        value: leaveDays(e.unpaidTotal ?? 0),
        valueColor: (e.unpaidTotal ?? 0) > 0 ? kLeavesDanger : AppColors.textPrimary,
      ),
      LeaveStatTile(label: 'الحد الأقصى للرصيد', value: cap == null ? '—' : leaveAmountDays(cap)),
    ];
    return LeavesTilesGrid(tiles: tiles);
  }

  Widget _leaveCard(LeaveRecord l) {
    final to = l.expected == null ? 'بلا تاريخ عودة' : 'إلى ${leaveDateLabel(l.expected)}';
    final paid = l.paid;
    final unpaid = l.unpaid;
    final balance = l.balanceAtStart;
    final note = l.note;

    final lines = <Widget>[
      _kv('مدة الإجازة', l.provisional ? '${leaveDays(l.duration)} (مؤقتة حتى تسجيل المباشرة)' : leaveDays(l.duration), bold: true),
    ];
    if (l.actual != null) lines.add(_kv('تمت المباشرة في', leaveDateLabel(l.actual)));
    if (balance != null) lines.add(_kv('الرصيد عند البدء', leaveAmountDays(balance)));
    if (paid != null) lines.add(_kv('أيام مدفوعة', leaveDays(paid), color: AppColors.successText, bold: true));
    if (unpaid != null) {
      lines.add(_kv('أيام بدون راتب', leaveDays(unpaid), color: unpaid > 0 ? kLeavesDanger : AppColors.textPrimary, bold: true));
    }

    final buttons = <Widget>[];
    if (l.canRegisterReturn) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _registerReturn(l),
          icon: const Icon(Icons.how_to_reg_outlined, size: 18),
          label: const Text('تسجيل المباشرة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kLeavesColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
      buttons.add(const SizedBox(height: 8));
    }
    buttons.add(
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openLeaveForm(existing: l),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('تعديل'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kLeavesColor,
                side: const BorderSide(color: kLeavesColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _deleteLeave(l),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('حذف'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kLeavesDanger,
                side: const BorderSide(color: kLeavesDanger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'من ${leaveDateLabel(l.start)} $to',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              LeaveStatusPill(status: l.state, label: l.stateLabel),
            ],
          ),
          const SizedBox(height: 6),
          ...lines,
          if (note != null) ...[
            const SizedBox(height: 6),
            InfoNote(text: note, color: AppColors.warningText, icon: Icons.sticky_note_2_outlined),
          ],
          const SizedBox(height: 10),
          ...buttons,
        ],
      ),
    );
  }

  Widget _content(LeaveEmployee e) {
    final children = <Widget>[
      _header(e),
      const SizedBox(height: 12),
      ..._alerts(e),
      _datesCard(e),
      const SizedBox(height: 12),
      _balanceSection(e),
      const SizedBox(height: 16),
      PrimaryButton(
        label: 'إجازة جديدة',
        color: kLeavesColor,
        icon: Icons.add,
        onPressed: () => _openLeaveForm(),
      ),
      const SizedBox(height: 18),
      LeavesSectionTitle('سجل الإجازات (${leaveNum(e.leaves.length)})'),
    ];
    if (e.leaves.isEmpty) {
      children.add(const LeavesEmptyState(icon: Icons.beach_access_outlined, text: 'لا توجد إجازات مسجّلة لهذا الموظف'));
    } else {
      for (var i = 0; i < e.leaves.length; i++) {
        if (i > 0) children.add(const SizedBox(height: 10));
        children.add(_leaveCard(e.leaves[i]));
      }
    }
    return RefreshIndicator(
      color: kLeavesColor,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _emp;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator(color: kLeavesColor));
    } else if (e == null) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [LeavesErrorView(message: _error ?? 'تعذّر تحميل بيانات الموظف', onRetry: _load)],
      );
    } else {
      body = _content(e);
    }
    return Scaffold(
      appBar: ScreenTopBar(
        title: e?.name ?? widget.initialName ?? 'الموظف',
        actions: [
          if (e != null)
            IconButton(
              tooltip: 'تعديل بيانات الموظف',
              icon: const Icon(Icons.edit_outlined, color: kLeavesColor),
              onPressed: _editEmployee,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
    );
  }
}
