import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// أمر عمل جديد لصيانة وقائية / أعمال أخرى — يبادر به مشرف الصيانة نفسه،
/// منفصل تمامًا عن بلاغات العطل الطارئ ولا علاقة له بقسم الإنتاج.
class MaintenanceWorkOrderScreen extends StatefulWidget {
  const MaintenanceWorkOrderScreen({super.key});

  @override
  State<MaintenanceWorkOrderScreen> createState() => _MaintenanceWorkOrderScreenState();
}

class _MaintenanceWorkOrderScreenState extends State<MaintenanceWorkOrderScreen> {
  String _line = 'خط ٧';
  final _descCtrl = TextEditingController();
  final _reminderCtrl = TextEditingController(text: '30');
  final Set<String> _selectedTechIds = {};

  final _lines = ['خط ٧', 'خط ٨', 'خط ٩', 'خط ١٠', 'خط ١١', 'خط ١٢'];

  @override
  void dispose() {
    _descCtrl.dispose();
    _reminderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canSubmit = _descCtrl.text.trim().isNotEmpty && _selectedTechIds.isNotEmpty;

    return Scaffold(
      appBar: const ScreenTopBar(title: 'أمر عمل وقائي جديد'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  const Text('الموقع / الخط', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _line,
                    decoration: _decoration(),
                    items: _lines.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() => _line = v ?? _line),
                  ),
                  const SizedBox(height: 14),
                  const Text('البيان (وصف العمل المطلوب)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descCtrl,
                    minLines: 3,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: _decoration(hint: 'مثال: فحص وتشحيم لوحة الكهرباء الدورية'),
                  ),
                  const SizedBox(height: 14),
                  const Text('الفني أو الفنيون (يمكن اختيار أكثر من واحد)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: state.technicians.map((t) {
                      final selected = _selectedTechIds.contains(t.id);
                      return FilterChip(
                        label: Text(t.name),
                        selected: selected,
                        selectedColor: AppColors.maintenance.withOpacity(0.14),
                        checkmarkColor: AppColors.maintenance,
                        labelStyle: TextStyle(color: selected ? AppColors.maintenance : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5),
                        side: BorderSide(color: selected ? AppColors.maintenance : AppColors.border),
                        onSelected: (v) => setState(() => v ? _selectedTechIds.add(t.id) : _selectedTechIds.remove(t.id)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('تكرار التذكير (كل كم يوم)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _reminderCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _decoration(hint: 'مثال: 30'),
                  ),
                  const SizedBox(height: 16),
                  const InfoNote(
                    text: 'عند حلول الموعد يصل تنبيه للمسؤول فقط — لا يُنشئ أمر عمل تلقائيًا، القرار لكم في كل مرة',
                    color: AppColors.maintenance,
                    icon: Icons.autorenew,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'إنشاء أمر العمل',
              color: canSubmit ? AppColors.maintenance : AppColors.textFaint,
              onPressed: canSubmit
                  ? () {
                      context.read<AppState>().createWorkOrder(
                            line: _line,
                            description: _descCtrl.text.trim(),
                            technicianIds: _selectedTechIds.toList(),
                            reminderIntervalDays: int.tryParse(_reminderCtrl.text.trim()),
                          );
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إنشاء أمر العمل الوقائي')),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _decoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
  );
}
