import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/technician.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class TechniciansTab extends StatelessWidget {
  const TechniciansTab({super.key});

  Future<void> _openForm(BuildContext context, {Technician? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final specialtyCtrl = TextEditingController(text: existing?.specialty ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final appState = context.read<AppState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'إضافة فني جديد' : 'تعديل بيانات الفني',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerRight, child: Text('الاسم', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              TextField(controller: nameCtrl, decoration: _decoration()),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerRight, child: Text('التخصص', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              TextField(controller: specialtyCtrl, decoration: _decoration(hint: 'مثال: كهرباء وميكانيكا')),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerRight, child: Text('رقم الجوال (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: _decoration(hint: '05xxxxxxxx')),
              const SizedBox(height: 18),
              PrimaryButton(
                label: existing == null ? 'إضافة الفني' : 'حفظ التعديلات',
                color: AppColors.maintenance,
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final specialty = specialtyCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  if (name.isEmpty) return;
                  if (existing == null) {
                    await appState.addTechnicianCloud(name: name, specialty: specialty, phone: phone.isEmpty ? null : phone);
                  } else {
                    await appState.updateTechnicianCloud(existing.id, name: name, specialty: specialty, phone: phone.isEmpty ? null : phone);
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Technician t) async {
    final appState = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الفني؟'),
        content: Text('سيُحذف "${t.name}" نهائيًا من قائمة الفنيين.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('حذف', style: TextStyle(color: Color(0xFFB3261E)))),
        ],
      ),
    );
    if (ok == true) await appState.removeTechnicianCloud(t.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.techniciansError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InfoNote(text: state.techniciansError!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
                ),
              Expanded(
                child: state.technicians.isEmpty
                    ? const Center(child: Text('لا يوجد فنيون بعد — اضغط + للإضافة', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: state.technicians.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final t = state.technicians[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.maintenance.withOpacity(0.1),
                                  child: Text(t.initials, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.maintenance)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                                      Text(t.specialty, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: t.available,
                                  activeColor: AppColors.maintenance,
                                  onChanged: (v) => state.updateTechnicianCloud(t.id, available: v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textMuted),
                                  onPressed: () => _openForm(context, existing: t),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFB3261E)),
                                  onPressed: () => _confirmDelete(context, t),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          child: FloatingActionButton(
            backgroundColor: AppColors.maintenance,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onPressed: () => _openForm(context),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

InputDecoration _decoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
  );
}
