import 'package:flutter/material.dart';

import '../../models/leaves.dart';
import '../../services/leaves_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'leave_employee_screen.dart';
import 'leaves_employee_form_sheet.dart';
import 'leaves_widgets.dart';

/// تبويب «الموظفون»: كل موظفي مصنع الرجال مع الرصيد المتاح والحالة وأهم تنبيه،
/// وبحث بالاسم أو الرقم الوظيفي وفلترة بالحالة. الضغط على موظف يفتح صفحته.
class LeavesEmployeesTab extends StatefulWidget {
  const LeavesEmployeesTab({super.key});

  @override
  State<LeavesEmployeesTab> createState() => _LeavesEmployeesTabState();
}

class _LeavesEmployeesTabState extends State<LeavesEmployeesTab> with AutomaticKeepAliveClientMixin {
  static const List<List<String>> _filters = [
    ['all', 'الكل'],
    ['active', 'على رأس العمل'],
    ['on_leave', 'في إجازة'],
    ['upcoming', 'إجازة قادمة'],
    ['late', 'متأخر عن المباشرة'],
    ['missing', 'بلا تواريخ'],
    ['cap', 'الحد الأقصى'],
  ];

  List<LeaveEmployee> _all = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _filter = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    leavesChanged.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    leavesChanged.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await LeavesService.fetchEmployees();
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = leavesErrorText(e);
        _loading = false;
      });
    }
  }

  bool _matchesFilter(LeaveEmployee e) {
    switch (_filter) {
      case 'active':
      case 'on_leave':
      case 'upcoming':
      case 'late':
        return e.status == _filter;
      case 'missing':
        return e.hasAlert('missing_dates');
      case 'cap':
        return e.atCap;
      default:
        return true;
    }
  }

  List<LeaveEmployee> get _visible {
    final raw = _query.trim();
    final digits = leaveWesternDigits(raw);
    final out = <LeaveEmployee>[];
    for (final e in _all) {
      if (!_matchesFilter(e)) continue;
      if (raw.isNotEmpty && !(e.name.contains(raw) || (e.employeeNumber ?? '').contains(digits))) continue;
      out.add(e);
    }
    return out;
  }

  void _openEmployee(LeaveEmployee e) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => LeaveEmployeeScreen(employeeId: e.id, initialName: e.name)),
    );
  }

  Future<void> _addEmployee() async {
    final saved = await showLeaveEmployeeFormSheet(context);
    if (saved == true) notifyLeavesChanged();
  }

  Widget _filterChips() {
    final chips = <Widget>[];
    for (final f in _filters) {
      final selected = _filter == f[0];
      chips.add(
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ChoiceChip(
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
            onSelected: (_) => setState(() => _filter = f[0]),
          ),
        ),
      );
    }
    return SizedBox(
      height: 42,
      child: ListView(scrollDirection: Axis.horizontal, children: chips),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final items = _visible;

    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator(color: kLeavesColor));
    } else if (_error != null && _all.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [LeavesErrorView(message: _error!, onRetry: _load)],
      );
    } else if (_all.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          LeavesEmptyState(
            icon: Icons.groups_outlined,
            text: 'لا يوجد موظفون بعد.\nاضغط «إضافة موظف» أو شغّل استيراد الموظفين من السيرفر.',
          ),
        ],
      );
    } else if (items.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [LeavesEmptyState(icon: Icons.search_off, text: 'لا يوجد موظف يطابق البحث أو الفلتر')],
      );
    } else {
      content = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 90),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _EmployeeTile(employee: items[i], onTap: () => _openEmployee(items[i])),
      );
    }

    final filtered = items.length != _all.length;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: fieldDecoration(hint: 'بحث بالاسم أو الرقم الوظيفي').copyWith(
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 10),
              _filterChips(),
              if (!_loading && _all.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    filtered
                        ? 'يظهر ${leaveNum(items.length)} من ${leaveNum(_all.length)} موظفًا'
                        : 'عدد الموظفين: ${leaveNum(_all.length)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              if (_error != null && _all.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: InfoNote(text: _error!, color: kLeavesDanger, icon: Icons.error_outline),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: _loading ? content : RefreshIndicator(color: kLeavesColor, onRefresh: _load, child: content),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          child: FloatingActionButton.extended(
            backgroundColor: kLeavesColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onPressed: _addEmployee,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('إضافة موظف', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final LeaveEmployee employee;
  final VoidCallback onTap;

  const _EmployeeTile({required this.employee, required this.onTap});

  String get _initial {
    final n = employee.name.trim();
    return n.isEmpty ? '؟' : n.substring(0, 1);
  }

  String get _numberLine {
    final dept = employee.department;
    final number = employee.employeeNumber == null ? 'بدون رقم وظيفي' : 'الرقم الوظيفي: ${leaveEastern(employee.employeeNumber!)}';
    return dept == null ? number : '$number  ·  $dept';
  }

  @override
  Widget build(BuildContext context) {
    final e = employee;
    final leave = e.leave;
    final alert = e.topAlert;
    final available = e.available;
    final balanceText = (e.hasBalance && available != null) ? leaveAmount(available) : '—';

    final details = <Widget>[];
    if (leave != null) {
      final to = leave.expected == null ? 'بلا تاريخ عودة' : 'إلى ${leaveDateLabel(leave.expected)}';
      details.add(const SizedBox(height: 4));
      details.add(
        Text('إجازة: من ${leaveDateLabel(leave.start)} $to', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      );
    }
    if (alert != null) {
      details.add(const SizedBox(height: 4));
      details.add(
        Text(alert.text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: leaveAlertColor(alert.code), height: 1.4)),
      );
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: kLeavesColor.withOpacity(0.1),
                child: Text(_initial, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kLeavesColor)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(_numberLine, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    LeaveStatusPill(status: e.status, label: e.statusLabel),
                    ...details,
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    balanceText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: e.atCap ? AppColors.warningText : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text('رصيد متاح', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
