import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/safety_permit.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class SafetyApprovalScreen extends StatelessWidget {
  final SafetyPermit permit;
  const SafetyApprovalScreen({super.key, required this.permit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenTopBar(title: 'مراجعة تصريح العمل'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.safety.withOpacity(0.12),
                      border: Border.all(color: AppColors.safety.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(permit.location, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.safetyText)),
                        const SizedBox(height: 8),
                        Text(permit.description, style: const TextStyle(fontSize: 13.5, height: 1.6, color: Color(0xFF3A4250))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(label: 'مقدّم الطلب', value: '${permit.requesterName} — ${permit.requesterRole}'),
                  _InfoRow(label: 'عدد العمال المطلوبين', value: permit.techniciansCount.toString()),
                  if (permit.relatedReportId != null) const _InfoRow(label: 'الحالة', value: 'مرتبط ببلاغ صيانة قائم'),
                  const SizedBox(height: 16),
                  const InfoNote(
                    text: 'موافقة قسم السلامة فقط — قسم الصيانة منفصل تمامًا ودوره الفني لا علاقة له بالاعتماد',
                    color: AppColors.safetyText,
                    icon: Icons.info_outline,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB3261E),
                        side: const BorderSide(color: Color(0xFFB3261E)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        context.read<AppState>().reviewPermit(permit.id, approve: false, reviewer: 'مسؤول السلامة');
                        Navigator.of(context).pop();
                      },
                      child: const Text('رفض', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: 'الموافقة على التصريح',
                    color: AppColors.safety,
                    icon: Icons.check,
                    onPressed: () {
                      context.read<AppState>().reviewPermit(permit.id, approve: true, reviewer: 'مسؤول السلامة');
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
