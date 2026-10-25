import 'package:flutter/material.dart';

import '../../models/leaves.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'leaves_employee_picker.dart';
import 'leaves_report_print_screen.dart';
import 'leaves_widgets.dart';

/// تبويب «التقارير»: تقرير شامل لكل الموظفين (أو لحالة معيّنة) أو كشف موظف واحد،
/// بنفس أعمدة ملف الإكسل (الرقم الوظيفي، الاسم، القسم، المباشرة، بدء الإجازة،
/// العودة المتوقعة، المدة، العودة الفعلية، استحقاق الإجازة القادمة، الأيام المتبقية،
/// الحالة، الموظف البديل، الملاحظات). يُعرض للطباعة/PDF أو يُنزَّل Excel حقيقيًا.
/// كل الحسابات في السيرفر؛ هنا اختيار نوع التقرير فقط.
class LeavesReportsTab extends StatefulWidget {
  const LeavesReportsTab({super.key});

  @override
  State<LeavesReportsTab> createState() => _LeavesReportsTabState();
}

class _LeavesReportsTabState extends State<LeavesReportsTab> with AutomaticKeepAliveClientMixin {
  static const List<List<String>> _statuses = [
    ['all', 'الكل'],
    ['active', 'على رأس العمل'],
    ['on_leave', 'في إجازة'],
    ['upcoming', 'إجازة قادمة'],
    ['late', 'متأخر عن المباشرة'],
  ];

  bool _personMode = false;
  String _status = 'all';
  LeaveEmployee? _employee;

  @override
  bool get wantKeepAlive => true;

  String? get _statusParam => _status == 'all' ? null : _status;

  String? get _employeeParam => _personMode ? _employee?.id : null;

  bool get _ready => !_personMode || _employee != null;

  Future<void> _pickEmployee() async {
    final picked = await pickLeaveEmployee(context);
    if (picked != null && mounted) setState(() => _employee = picked);
  }

  void _openReport() {
    if (!_ready) {
      showLeavesSnack(context, 'اختر الموظف أولًا', error: true);
      return;
    }
    final employee = _employee;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LeavesReportPrintScreen(
          employeeId: _employeeParam,
          status: _personMode ? null : _statusParam,
          title: _personMode && employee != null ? 'كشف ${employee.name}' : 'تقرير إجازات الموظفين',
        ),
      ),
    );
  }

  Future<void> _downloadExcel() async {
    if (!_ready) {
      showLeavesSnack(context, 'اختر الموظف أولًا', error: true);
      return;
    }
    await downloadLeavesExcel(context, employeeId: _employeeParam, status: _personMode ? null : _statusParam);
  }

  Widget _kindOption({required bool person, required IconData icon, required String title, required String subtitle}) {
    final selected = _personMode == person;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _personMode = person),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? kLeavesColor.withOpacity(0.08) : AppColors.surface,
            border: Border.all(color: selected ? kLeavesColor : AppColors.border, width: selected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, size: 26, color: selected ? kLeavesColor : AppColors.textMuted),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: selected ? kLeavesColor : AppColors.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChips() {
    final chips = <Widget>[];
    for (final f in _statuses) {
      final selected = _status == f[0];
      chips.add(
        ChoiceChip(
          label: Text(
            f[1],
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? kLeavesColor : AppColors.textSecondary,
            ),
          ),
          selected: selected,
          selectedColor: kLeavesColor.withOpacity(0.14),
          backgroundColor: AppColors.surface,
          side: BorderSide(color: selected ? kLeavesColor : AppColors.border),
          onSelected: (_) => setState(() => _status = f[0]),
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _employeeField() {
    final e = _employee;
    final label = e == null ? 'اختر الموظف' : e.name;
    final sub = e == null
        ? null
        : (e.employeeNumber == null ? 'بدون رقم وظيفي' : 'الرقم الوظيفي: ${leaveEastern(e.employeeNumber!)}');
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: _pickEmployee,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_search_outlined, size: 22, color: kLeavesColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: e == null ? FontWeight.normal : FontWeight.bold,
                      color: e == null ? AppColors.textMuted : AppColors.textPrimary,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_left, size: 22, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final children = <Widget>[
      const LeavesSectionTitle('نوع التقرير'),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _kindOption(
              person: false,
              icon: Icons.groups_outlined,
              title: 'تقرير شامل',
              subtitle: 'كل الموظفين في جدول واحد',
            ),
            const SizedBox(width: 10),
            _kindOption(
              person: true,
              icon: Icons.person_outline,
              title: 'كشف موظف',
              subtitle: 'رصيد وسجل إجازات موظف واحد',
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
    ];

    if (_personMode) {
      children.add(const LeavesSectionTitle('الموظف'));
      children.add(_employeeField());
    } else {
      children.add(const LeavesSectionTitle('حالة الموظفين'));
      children.add(_statusChips());
    }

    children.addAll([
      const SizedBox(height: 16),
      InfoNote(
        text: _personMode
            ? 'يشمل الكشف: بيانات الموظف، الرصيد المتاح والمستحق والمستخدم وما سقط، تاريخ استحقاق الإجازة القادمة، وسجل كل إجازاته بالأيام المدفوعة وبدون راتب والموظف البديل.'
            : 'يشمل التقرير لكل موظف: الرقم الوظيفي والاسم والقسم وتاريخ المباشرة وبدء الإجازة والعودة المتوقعة والمدة والعودة الفعلية وتاريخ استحقاق الإجازة القادمة والأيام المتبقية والحالة والموظف البديل والملاحظات. ملف Excel يضيف ورقة بكل الإجازات وورقة ملخص.',
        color: kLeavesColor,
        icon: Icons.description_outlined,
      ),
      const SizedBox(height: 18),
      PrimaryButton(
        label: 'عرض وطباعة PDF',
        color: kLeavesColor,
        icon: Icons.picture_as_pdf_outlined,
        onPressed: _openReport,
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _downloadExcel,
        icon: const Icon(Icons.table_view_outlined, size: 20),
        label: const Text('تنزيل ملف Excel', style: TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: kLeavesColor,
          side: const BorderSide(color: kLeavesColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
      children: children,
    );
  }
}
