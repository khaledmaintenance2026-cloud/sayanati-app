import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../theme/app_theme.dart';
import 'mamoul_analysis_tab.dart';
import 'mamoul_faults_tab.dart';
import 'mamoul_runs_tab.dart';
import 'mamoul_widgets.dart';

/// "غرفة المكينة": مساحة خاصة بمكينة معمول واحدة فيها تحليل بياناتها منفردًا
/// (أفضل سرعات وأوزان هذه المكينة تحديدًا)، وتشغيلاتها، وأعطالها. نفس تبويبات
/// الشاشة الرئيسية لكن محصورة على [machine] (fixedMachineId).
class MamoulMachineRoomScreen extends StatelessWidget {
  final MamoulMachine machine;

  const MamoulMachineRoomScreen({super.key, required this.machine});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: ValueListenableBuilder<List<MamoulMachine>>(
            valueListenable: mamoulMachines,
            builder: (context, machines, _) {
              final current = mamoulMachineById(machine.id) ?? machine;
              return Text(
                'غرفة ${current.label}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              );
            },
          ),
          bottom: const TabBar(
            labelColor: kMamoulColor,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: kMamoulColor,
            tabs: [
              Tab(text: 'التحليل'),
              Tab(text: 'التشغيلات'),
              Tab(text: 'الأعطال'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MamoulAnalysisTab(fixedMachineId: machine.id),
            MamoulRunsTab(fixedMachineId: machine.id),
            MamoulFaultsTab(fixedMachineId: machine.id),
          ],
        ),
      ),
    );
  }
}
