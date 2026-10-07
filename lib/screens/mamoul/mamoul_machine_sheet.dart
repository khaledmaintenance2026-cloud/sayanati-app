import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../services/mamoul_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_widgets.dart';

/// نافذة إضافة مكينة جديدة (أو تعديل اسم/رمز [existing]). تُحدّث القائمة
/// المشتركة [mamoulMachines] عند الحفظ وتعيد المكينة المحفوظة (أو null لو أُغلقت).
/// الصلاحية الملزمة على السيرفر: مسؤول الصيانة / مدير النظام فقط.
Future<MamoulMachine?> showAddMamoulMachineSheet(BuildContext context, {MamoulMachine? existing}) {
  return showMamoulSheet<MamoulMachine>(context, (ctx) => _MamoulMachineForm(existing: existing));
}

class _MamoulMachineForm extends StatefulWidget {
  final MamoulMachine? existing;

  const _MamoulMachineForm({this.existing});

  @override
  State<_MamoulMachineForm> createState() => _MamoulMachineFormState();
}

class _MamoulMachineFormState extends State<_MamoulMachineForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _code.text = e.code ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اكتب اسم المكينة');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final code = _code.text.trim();
      final e = widget.existing;
      final MamoulMachine saved;
      if (e == null) {
        saved = await MamoulMonitorService.addMachine(name: name, code: code.isEmpty ? null : code);
      } else {
        // الرمز الفارغ يُرسَل نصًا فارغًا ليُمسح الرمز القديم.
        saved = await MamoulMonitorService.updateMachine(e.id, name: name, code: code);
      }
      await reloadMamoulMachines();
      notifyMamoulChanged();
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = mamoulErrorText(err);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(height: 14),
        Text(editing ? 'تعديل المكينة' : 'إضافة مكينة', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        const MamoulFieldLabel('اسم المكينة', required: true),
        MamoulTextField(controller: _name, hint: 'مثال: مكينة المعمول ١', maxLength: 80),
        const SizedBox(height: 12),
        const MamoulFieldLabel('الرمز (اختياري)'),
        MamoulTextField(controller: _code, hint: 'مثال: M1', maxLength: 40),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontSize: 13, color: kMamoulDanger, height: 1.5)),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: _saving ? 'جارٍ الحفظ...' : (editing ? 'حفظ التعديل' : 'إضافة المكينة'),
          color: kMamoulColor,
          icon: Icons.check,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
