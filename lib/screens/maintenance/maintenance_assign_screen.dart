import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/maintenance_report.dart';
import '../../models/technician.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class MaintenanceAssignScreen extends StatefulWidget {
  final MaintenanceReport report;
  const MaintenanceAssignScreen({super.key, required this.report});

  @override
  State<MaintenanceAssignScreen> createState() => _MaintenanceAssignScreenState();
}

class _MaintenanceAssignScreenState extends State<MaintenanceAssignScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = _selectedId != null ? state.technicians.firstWhere((t) => t.id == _selectedId) : null;

    return Scaffold(
      appBar: const ScreenTopBar(title: 'تعيين فني'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.maintenance.withOpacity(0.06),
                border: Border.all(color: AppColors.maintenance.withOpacity(0.16)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('${widget.report.equipment} — ${widget.report.line}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.maintenance)),
                      ),
                      const StatusPill(label: 'بلاغ طارئ', color: AppColors.warningText, background: AppColors.warningBg),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(widget.report.description, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF3A4250))),
                  const SizedBox(height: 6),
                  Text('رُفع بواسطة ${widget.report.reportedBy}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Align(alignment: Alignment.centerRight, child: Text('اختر فنيًا متاحًا', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: state.technicians.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final tech = state.technicians[i];
                  final isSelected = tech.id == _selectedId;
                  return _TechnicianTile(
                    technician: tech,
                    selected: isSelected,
                    onTap: tech.available ? () => setState(() => _selectedId = tech.id) : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: selected != null ? 'تعيين البلاغ لـ ${selected.name}' : 'اختر فنيًا للمتابعة',
              color: AppColors.maintenance,
              onPressed: selected == null
                  ? null
                  : () {
                      context.read<AppState>().assignTechnician(widget.report.id, selected.id);
                      Navigator.of(context).pop();
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicianTile extends StatelessWidget {
  final Technician technician;
  final bool selected;
  final VoidCallback? onTap;

  const _TechnicianTile({required this.technician, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final available = technician.available;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: selected ? AppColors.maintenance : AppColors.border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: available ? AppColors.maintenance.withOpacity(0.1) : AppColors.divider,
              child: Text(technician.initials,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: available ? AppColors.maintenance : AppColors.textMuted)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(technician.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: available ? AppColors.textPrimary : AppColors.textMuted)),
                  Text('تخصص: ${technician.specialty}', style: TextStyle(fontSize: 12, color: available ? AppColors.textMuted : AppColors.textFaint)),
                ],
              ),
            ),
            StatusPill(
              label: available ? 'متاح' : 'غير متاح',
              color: available ? AppColors.successText : const Color(0xFF9AA3AF),
              background: available ? AppColors.successBg : AppColors.divider,
            ),
          ],
        ),
      ),
    );
  }
}
