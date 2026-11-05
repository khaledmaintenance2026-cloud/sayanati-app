import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_analysis_tab.dart';
import 'mamoul_faults_tab.dart';
import 'mamoul_machine_room_screen.dart';
import 'mamoul_machines_screen.dart';
import 'mamoul_runs_tab.dart';
import 'mamoul_widgets.dart';

/// اسم مصنع النساء كما يُخزَّن في حقل production_facility للمستخدم.
const String kMamoulWomenFacility = 'مصنع النساء';

/// من يرى تبويب "المعمول"؟ كل فريق الصيانة (مدير النظام، مسؤول الصيانة، الفني،
/// مسؤول المخزون، المصمم) + موظفو ومسؤولو الإنتاج المقيَّدون بمصنع النساء أو
/// غير المقيَّدين بمصنع. لا يراه إنتاج مصنع الرجال ولا السلامة ولا القسم العام
/// (قرار الإدارة 2026-10-07). هذه الدالة تُخفي التبويب في الواجهة فقط؛ القيد
/// الملزم فعليًا على السيرفر في routes/mamoulMonitor.js (MONITOR_ROLES +
/// requireFacility) — يجب أن تبقى القاعدتان متطابقتين.
bool canOpenMamoulMonitor(AppUser? user) {
  if (user == null) return false;
  final r = user.role;
  if (r == AppRole.admin || isMaintenanceRole(r) || isInventoryOnlyRole(r)) return true;
  if (isProductionRole(r)) {
    return user.productionFacility == null || user.productionFacility == kMamoulWomenFacility;
  }
  return false;
}

/// شاشة "مراقبة المعمول": ثلاثة تبويبات (التشغيلات، الأعطال، التحليل)، وزر
/// "المكائن" لإدارة المكائن والدخول لغرفة كل مكينة.
class MamoulHomeScreen extends StatefulWidget {
  const MamoulHomeScreen({super.key});

  @override
  State<MamoulHomeScreen> createState() => _MamoulHomeScreenState();
}

class _MamoulHomeScreenState extends State<MamoulHomeScreen> {
  @override
  void initState() {
    super.initState();
    reloadMamoulMachines();
  }

  void _openMachines() {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const MamoulMachinesScreen()));
  }

  void _openRoom(MamoulMachine machine) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => MamoulMachineRoomScreen(machine: machine)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مراقبة المعمول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          actions: [
            TextButton.icon(
              onPressed: _openMachines,
              icon: const Icon(Icons.precision_manufacturing_outlined, size: 20),
              label: const Text('المكائن', style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: kMamoulColor),
            ),
            const SizedBox(width: 6),
          ],
          bottom: const TabBar(
            labelColor: kMamoulColor,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: kMamoulColor,
            tabs: [
              Tab(text: 'التشغيلات'),
              Tab(text: 'الأعطال'),
              Tab(text: 'التحليل'),
            ],
          ),
        ),
        body: Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: mamoulMachinesLoaded,
              builder: (context, loaded, _) {
                return ValueListenableBuilder<List<MamoulMachine>>(
                  valueListenable: mamoulMachines,
                  builder: (context, machines, _) {
                    if (!loaded || machines.isNotEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _openMachines,
                        child: const InfoNote(
                          text: 'لم تُضف مكائن بعد — اضغط هنا (أو زر «المكائن») لإضافة مكينة المعمول الأولى.',
                          color: AppColors.warningText,
                          icon: Icons.info_outline,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const MamoulRunsTab(),
                  const MamoulFaultsTab(),
                  MamoulAnalysisTab(onOpenMachine: _openRoom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
