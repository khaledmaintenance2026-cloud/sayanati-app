import 'package:flutter/material.dart';

import '../../models/leaves.dart';
import '../../services/leaves_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'leaves_widgets.dart';

/// ورقة إضافة/تعديل موظف في قسم الإجازات. تُرجع true عند الحفظ. الموظف هو نفسه
/// فرد قائمة «العمل الإضافي» (قائمة مشتركة): الاسم والرقم الوظيفي يظهران في القسمين.
Future<bool?> showLeaveEmployeeFormSheet(BuildContext context, {LeaveEmployee? existing}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LeaveEmployeeFormSheet(existing: existing),
  );
}

class _LeaveEmployeeFormSheet extends StatefulWidget {
  final LeaveEmployee? existing;
  const _LeaveEmployeeFormSheet({this.existing});

  @override
  State<_LeaveEmployeeFormSheet> createState() => _LeaveEmployeeFormSheetState();
}

class _LeaveEmployeeFormSheetState extends State<_LeaveEmployeeFormSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _number = TextEditingController(text: widget.existing?.employeeNumber ?? '');
  late final TextEditingController _department =
      TextEditingController(text: widget.existing == null ? 'مصنع الرجال' : (widget.existing?.department ?? ''));
  late DateTime? _hire = leaveParseDate(widget.existing?.hireDate);
  late DateTime? _start = leaveParseDate(widget.existing?.startDate);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _department.dispose();
    super.dispose();
  }

  void _onHireChanged(DateTime? d) {
    setState(() {
      _hire = d;
      // تاريخ المباشرة يساوي تاريخ التعيين غالبًا: نملؤه تلقائيًا لو كان فارغًا.
      if (d != null && _start == null) _start = d;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final number = leaveWesternDigits(_number.text.trim());
    final dept = _department.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اكتب اسم الموظف');
      return;
    }
    if (number.isEmpty) {
      setState(() => _error = 'اكتب الرقم الوظيفي');
      return;
    }
    final h = _hire;
    final s = _start;
    final hire = h == null ? null : leaveIsoDate(h);
    final start = s == null ? null : leaveIsoDate(s);
    final ex = widget.existing;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (ex == null) {
        await LeavesService.addEmployee(
          name: name,
          employeeNumber: number,
          department: dept.isEmpty ? null : dept,
          hireDate: hire,
          startDate: start,
        );
      } else {
        await LeavesService.updateEmployee(
          ex.id,
          name: name,
          employeeNumber: number,
          department: dept.isEmpty ? null : dept,
          hireDate: hire,
          startDate: start,
        );
      }
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

  Widget _label(String text) => Align(
        alignment: Alignment.centerRight,
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final now = DateTime.now();
    final first = DateTime(1990);
    final last = DateTime(now.year + 1, 12, 31);
    final missingDate = _hire == null || _start == null;

    return LeavesSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isEdit ? 'تعديل بيانات الموظف' : 'إضافة موظف جديد', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _label('الاسم'),
          const SizedBox(height: 6),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: fieldDecoration(hint: 'اسم الموظف'),
          ),
          const SizedBox(height: 12),
          _label('الرقم الوظيفي'),
          const SizedBox(height: 6),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: fieldDecoration(hint: 'مثال: 2145'),
          ),
          const SizedBox(height: 12),
          _label('القسم'),
          const SizedBox(height: 6),
          TextField(
            controller: _department,
            textInputAction: TextInputAction.done,
            decoration: fieldDecoration(hint: 'مصنع الرجال'),
          ),
          const SizedBox(height: 12),
          LeaveDateField(
            label: 'تاريخ التعيين',
            hint: 'اختر التاريخ',
            value: _hire,
            firstDate: first,
            lastDate: last,
            clearable: true,
            onChanged: _onHireChanged,
          ),
          const SizedBox(height: 12),
          LeaveDateField(
            label: 'تاريخ المباشرة (منه يبدأ احتساب الرصيد)',
            hint: 'اختر التاريخ',
            value: _start,
            firstDate: first,
            lastDate: last,
            clearable: true,
            onChanged: (d) => setState(() => _start = d),
          ),
          if (missingDate) ...[
            const SizedBox(height: 10),
            const InfoNote(
              text: 'بدون تاريخ التعيين والمباشرة لا يُحسب الرصيد، وسيظهر تنبيه «أدخل تاريخ التعيين والمباشرة».',
              color: AppColors.warningText,
              icon: Icons.info_outline,
            ),
          ],
          if (isEdit) ...[
            const SizedBox(height: 10),
            const InfoNote(
              text: 'تعديل الاسم أو الرقم يُحدَّث أيضًا في قائمة العمل الإضافي وسجلاته السابقة.',
              color: kLeavesColor,
              icon: Icons.info_outline,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            InfoNote(text: _error!, color: kLeavesDanger, icon: Icons.error_outline),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: _saving ? 'جارٍ الحفظ...' : (isEdit ? 'حفظ التعديلات' : 'إضافة الموظف'),
            color: kLeavesColor,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
