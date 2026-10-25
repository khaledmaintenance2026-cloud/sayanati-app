import 'package:flutter/material.dart';

import '../../models/leaves.dart';
import '../../services/leaves_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'leaves_widgets.dart';

/// يفتح قائمة موظفي الإجازات مع بحث بالاسم أو الرقم الوظيفي، ويرجع الموظف
/// المختار، أو null لو رجع المستخدم بلا اختيار. يُستعمل لاختيار موظف «كشف الموظف»
/// في تبويب التقارير.
Future<LeaveEmployee?> pickLeaveEmployee(BuildContext context) {
  return Navigator.of(context).push<LeaveEmployee>(
    MaterialPageRoute(builder: (_) => const _LeaveEmployeePickPage()),
  );
}

class _LeaveEmployeePickPage extends StatefulWidget {
  const _LeaveEmployeePickPage();

  @override
  State<_LeaveEmployeePickPage> createState() => _LeaveEmployeePickPageState();
}

class _LeaveEmployeePickPageState extends State<_LeaveEmployeePickPage> {
  List<LeaveEmployee> _all = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await LeavesService.fetchEmployees();
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = leavesErrorText(e);
        _loading = false;
      });
    }
  }

  List<LeaveEmployee> get _visible {
    final raw = _query.trim();
    if (raw.isEmpty) return _all;
    final digits = leaveWesternDigits(raw);
    final out = <LeaveEmployee>[];
    for (final e in _all) {
      if (e.name.contains(raw) || (e.employeeNumber ?? '').contains(digits)) out.add(e);
    }
    return out;
  }

  Widget _tile(LeaveEmployee e) {
    final n = e.name.trim();
    final initial = n.isEmpty ? '؟' : n.substring(0, 1);
    final number = e.employeeNumber == null ? 'بدون رقم وظيفي' : 'الرقم الوظيفي: ${leaveEastern(e.employeeNumber!)}';
    return Material(
      color: leaveTileFill(e.status),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).pop(e),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: leaveTileBorder(e.status)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: kLeavesColor.withOpacity(0.1),
                child: Text(initial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kLeavesColor)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(number, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              LeaveStatusPill(status: e.status, label: e.statusLabel),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator(color: kLeavesColor));
    } else if (_error != null) {
      body = ListView(children: [LeavesErrorView(message: _error!, onRetry: _load)]);
    } else if (_all.isEmpty) {
      body = ListView(
        children: const [LeavesEmptyState(icon: Icons.groups_outlined, text: 'لا يوجد موظفون بعد — أضفهم من تبويب «الموظفون».')],
      );
    } else if (items.isEmpty) {
      body = ListView(
        children: const [LeavesEmptyState(icon: Icons.search_off, text: 'لا يوجد موظف يطابق البحث')],
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _tile(items[i]),
      );
    }

    return Scaffold(
      appBar: const ScreenTopBar(title: 'اختر الموظف'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: fieldDecoration(hint: 'بحث بالاسم أو الرقم الوظيفي').copyWith(
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
