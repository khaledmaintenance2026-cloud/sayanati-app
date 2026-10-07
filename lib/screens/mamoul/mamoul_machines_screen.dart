import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mamoul_monitor.dart';
import '../../services/auth_service.dart';
import '../../services/mamoul_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_machine_room_screen.dart';
import 'mamoul_machine_sheet.dart';
import 'mamoul_widgets.dart';

/// قائمة مكائن المعمول: كل مكينة لها "غرفة" خاصة (تحليل وتشغيلات وأعطال
/// منفردة). الإضافة والتعديل والتعطيل والحذف لمسؤول الصيانة ومدير النظام فقط
/// (القيد الملزم على السيرفر)، وغيرهم يتصفّح القائمة ويدخل الغرف.
class MamoulMachinesScreen extends StatefulWidget {
  const MamoulMachinesScreen({super.key});

  @override
  State<MamoulMachinesScreen> createState() => _MamoulMachinesScreenState();
}

class _MamoulMachinesScreenState extends State<MamoulMachinesScreen> {
  bool _loading = true;
  String? _error;

  bool get _canManage {
    final role = context.read<AuthService>().currentUser?.role;
    return role != null && canManageMaintenance(role);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await reloadMamoulMachines();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  Future<void> _add() async {
    final added = await showAddMamoulMachineSheet(context);
    if (added != null && mounted) showMamoulSnack(context, 'أُضيفت المكينة «${added.name}»');
  }

  Future<void> _edit(MamoulMachine m) async {
    final saved = await showAddMamoulMachineSheet(context, existing: m);
    if (saved != null && mounted) showMamoulSnack(context, 'حُفظ تعديل المكينة');
  }

  Future<void> _toggleActive(MamoulMachine m) async {
    try {
      await MamoulMonitorService.updateMachine(m.id, active: !m.active);
      await reloadMamoulMachines();
      notifyMamoulChanged();
      if (!mounted) return;
      showMamoulSnack(context, m.active ? 'عُطّلت المكينة (لن تظهر عند تسجيل تشغيلة جديدة)' : 'فُعّلت المكينة');
    } catch (e) {
      if (!mounted) return;
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  Future<void> _delete(MamoulMachine m) async {
    final ok = await confirmMamoul(
      context,
      title: 'حذف المكينة؟',
      message: 'ستُحذف المكينة «${m.name}» نهائيًا. (لا يمكن حذف مكينة سُجّلت لها تشغيلات أو أعطال — عطّلها بدلًا من ذلك.)',
    );
    if (!ok || !mounted) return;
    try {
      await MamoulMonitorService.deleteMachine(m.id);
      await reloadMamoulMachines();
      notifyMamoulChanged();
      if (!mounted) return;
      showMamoulSnack(context, 'حُذفت المكينة');
    } catch (e) {
      if (!mounted) return;
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  void _openRoom(MamoulMachine m) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MamoulMachineRoomScreen(machine: m)),
    );
  }

  Widget _machineCard(MamoulMachine m, bool canManage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MamoulCard(
        onTap: () => _openRoom(m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (m.active ? kMamoulColor : AppColors.textFaint).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.precision_manufacturing_outlined, color: m.active ? kMamoulColor : AppColors.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (!m.active)
                        const StatusPill(label: 'معطّلة', color: AppColors.textSecondary, background: AppColors.divider),
                      StatusPill(
                        label: '${mamoulCount(m.runsCount)} تشغيلة',
                        color: kMamoulColor,
                        background: kMamoulColor.withOpacity(0.10),
                      ),
                      if (m.faultsOpen > 0)
                        StatusPill(
                          label: 'أعطال مفتوحة ${mamoulCount(m.faultsOpen)}',
                          color: AppColors.warningText,
                          background: AppColors.warningBg,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('اضغط لفتح غرفة المكينة', style: TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                ],
              ),
            ),
            if (canManage)
              PopupMenuButton<String>(
                tooltip: 'خيارات المكينة',
                onSelected: (v) {
                  if (v == 'edit') _edit(m);
                  if (v == 'toggle') _toggleActive(m);
                  if (v == 'delete') _delete(m);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem<String>(value: 'edit', child: Text('تعديل الاسم والرمز')),
                  PopupMenuItem<String>(value: 'toggle', child: Text(m.active ? 'تعطيل المكينة' : 'تفعيل المكينة')),
                  if (m.canDelete) const PopupMenuItem<String>(value: 'delete', child: Text('حذف المكينة')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _canManage;
    return Scaffold(
      appBar: const ScreenTopBar(title: 'مكائن المعمول'),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'mamoul_add_machine',
              backgroundColor: kMamoulColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('إضافة مكينة', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: SafeArea(
        child: ValueListenableBuilder<List<MamoulMachine>>(
          valueListenable: mamoulMachines,
          builder: (context, machines, _) {
            final children = <Widget>[];
            if (!canManage) {
              children.add(const InfoNote(
                text: 'إضافة المكائن وتعديلها من صلاحية مسؤول الصيانة.',
                color: AppColors.textSecondary,
                icon: Icons.info_outline,
              ));
              children.add(const SizedBox(height: 12));
            }
            if (_loading && machines.isEmpty) {
              children.add(const MamoulLoadingView());
            } else if (_error != null && machines.isEmpty) {
              children.add(MamoulErrorView(message: _error!, onRetry: _load));
            } else if (machines.isEmpty) {
              children.add(MamoulEmptyState(
                icon: Icons.precision_manufacturing_outlined,
                text: canManage
                    ? 'لا توجد مكائن بعد.\nاضغط «إضافة مكينة» لإضافة أول مكينة معمول.'
                    : 'لا توجد مكائن بعد. اطلب من مسؤول الصيانة إضافتها.',
              ));
            } else {
              for (final m in machines) {
                children.add(_machineCard(m, canManage));
              }
            }
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: children,
              ),
            );
          },
        ),
      ),
    );
  }
}
