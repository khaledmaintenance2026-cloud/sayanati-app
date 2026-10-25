import 'package:flutter/material.dart';

import '../../models/leaves.dart';
import '../../services/leaves_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'leaves_widgets.dart';

/// ورقة «تسجيل المباشرة» بعد الإجازة. تُرجع true عند الحفظ. التاريخ الافتراضي اليوم؛
/// ويمكن اختيار يوم سابق (مباشرة سُجّلت متأخرة). لا يُقبل تاريخ بعد اليوم ولا قبل
/// اليوم التالي لبدء الإجازة (السيرفر يتحقق أيضًا).
Future<bool?> showLeaveReturnSheet(
  BuildContext context, {
  required LeaveEmployee employee,
  required LeaveRecord leave,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LeaveReturnSheet(employee: employee, leave: leave),
  );
}

class _LeaveReturnSheet extends StatefulWidget {
  final LeaveEmployee employee;
  final LeaveRecord leave;
  const _LeaveReturnSheet({required this.employee, required this.leave});

  @override
  State<_LeaveReturnSheet> createState() => _LeaveReturnSheetState();
}

class _LeaveReturnSheetState extends State<_LeaveReturnSheet> {
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime? get _firstAllowed {
    final s = leaveParseDate(widget.leave.start);
    if (s == null) return null;
    return DateTime(s.year, s.month, s.day + 1);
  }

  @override
  void initState() {
    super.initState();
    _date = _today;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await LeavesService.registerReturn(widget.leave.id, leaveIsoDate(_date));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = leavesErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final leave = widget.leave;
    final first = _firstAllowed;
    final today = _today;
    final canPick = first != null && !first.isAfter(today);

    final expected = leaveParseDate(leave.expected);
    String? lateNote;
    if (expected != null) {
      final diff = leaveDayDiff(_date, expected);
      if (diff > 0) {
        lateNote = 'التاريخ المختار بعد العودة المتوقعة بـ ${leaveDays(diff)}.';
      } else if (diff < 0) {
        lateNote = 'التاريخ المختار قبل العودة المتوقعة بـ ${leaveDays(-diff)} (عودة مبكرة).';
      }
    }

    final range = leave.expected == null
        ? 'بدأت ${leaveDateLabel(leave.start)} (بلا تاريخ عودة متوقعة)'
        : 'من ${leaveDateLabel(leave.start)} إلى ${leaveDateLabel(leave.expected)} (المتوقعة)';

    return LeavesSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('تسجيل المباشرة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(widget.employee.name, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('الإجازة: $range', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5)),
          const SizedBox(height: 16),
          if (canPick) ...[
            LeaveDateField(
              label: 'تاريخ المباشرة الفعلي',
              hint: 'اختر التاريخ',
              value: _date,
              firstDate: first ?? today,
              lastDate: today,
              onChanged: (d) {
                if (d != null) setState(() => _date = d);
              },
            ),
            if (lateNote != null) ...[
              const SizedBox(height: 10),
              InfoNote(text: lateNote, color: AppColors.warningText, icon: Icons.info_outline),
            ],
            const SizedBox(height: 10),
            const InfoNote(
              text: 'ستُحتسب مدة الإجازة الفعلية من يوم البدء حتى هذا التاريخ، وتُعاد حسابات الرصيد والمدفوع/بدون راتب تلقائيًا.',
              color: kLeavesColor,
              icon: Icons.calculate_outlined,
            ),
          ] else
            const InfoNote(
              text: 'لا يمكن تسجيل المباشرة قبل مرور يوم كامل على بدء الإجازة.',
              color: AppColors.warningText,
              icon: Icons.info_outline,
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            InfoNote(text: _error!, color: kLeavesDanger, icon: Icons.error_outline),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: _saving ? 'جارٍ الحفظ...' : 'تأكيد المباشرة',
            color: kLeavesColor,
            icon: Icons.how_to_reg_outlined,
            onPressed: (_saving || !canPick) ? null : _save,
          ),
        ],
      ),
    );
  }
}
