import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/safety_permit.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'safety_approval_screen.dart';
import 'safety_permit_request_screen.dart';

class SafetyHomeScreen extends StatelessWidget {
  const SafetyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: const ScreenTopBar(title: 'السلامة'),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('تصاريح العمل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: state.permits.isEmpty
                      ? const Center(child: Text('لا توجد تصاريح', style: TextStyle(color: AppColors.textMuted)))
                      : ListView.separated(
                          itemCount: state.permits.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final permit = state.permits[i];
                            return _PermitCard(permit: permit);
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
              backgroundColor: AppColors.safety,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SafetyPermitRequestScreen()),
              ),
              child: const Icon(Icons.add, color: AppColors.safetyText),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermitCard extends StatelessWidget {
  final SafetyPermit permit;
  const _PermitCard({required this.permit});

  @override
  Widget build(BuildContext context) {
    final statusInfo = switch (permit.status) {
      PermitStatus.pending => (label: 'بانتظار الموافقة', color: AppColors.warningText, bg: AppColors.warningBg),
      PermitStatus.approved => (label: 'تمت الموافقة', color: AppColors.successText, bg: AppColors.successBg),
      PermitStatus.rejected => (label: 'مرفوض', color: const Color(0xFFB3261E), bg: const Color(0x1FB3261E)),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: permit.status == PermitStatus.pending
          ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SafetyApprovalScreen(permit: permit)))
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(permit.location, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                StatusPill(label: statusInfo.label, color: statusInfo.color, background: statusInfo.bg),
              ],
            ),
            const SizedBox(height: 6),
            Text(permit.description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text('مقدّم الطلب: ${permit.requesterName} — ${permit.requesterRole}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            if (permit.relatedReportId != null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('مرتبط ببلاغ صيانة قائم', style: TextStyle(fontSize: 11.5, color: AppColors.maintenance, fontWeight: FontWeight.w600)),
              ),
            if (permit.status == PermitStatus.rejected && permit.rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('سبب الرفض: ${permit.rejectionReason}', style: const TextStyle(fontSize: 11.5, color: Color(0xFFB3261E))),
              ),
          ],
        ),
      ),
    );
  }
}
