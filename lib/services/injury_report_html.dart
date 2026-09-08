import '../models/injury_report.dart';
import 'arabic_format.dart';

/// يبني تقرير HTML بمقاس A4 لتحقيق إصابة عمل كامل (QMS-SAF-007) — بنفس الهوية
/// البصرية لتقرير الصيانة/الإنتاج — ليتحول لاحقًا لملف PDF عبر حزمة printing
/// (راجع lib/services/maintenance_report_html.dart لنفس الأسلوب بالضبط).
String buildInjuryReportHtml(InjuryReport r) {
  String row(String label, String value, {bool bold = false}) => '''
    <div style="display:flex; justify-content:space-between; padding:8px 0; border-bottom:1px solid #EDEFF2;">
      <span style="font-size:12.5px; color:#5C6673;">$label</span>
      <span style="font-size:13.5px; ${bold ? 'font-weight:700;' : ''} color:#1A2129; text-align:left;">$value</span>
    </div>
  ''';

  String sectionTitle(String title, String stepBadge) => '''
    <div style="display:flex; align-items:center; gap:10px; margin:22px 0 10px;">
      <div style="background:#2B3487; color:#fff; font-size:11px; font-weight:700; padding:3px 10px; border-radius:999px;">$stepBadge</div>
      <div style="font-size:15px; font-weight:700;">$title</div>
    </div>
  ''';

  String textBlock(String label, String? value) => '''
    <div style="margin-bottom:10px;">
      <div style="font-size:12px; color:#5C6673; margin-bottom:4px;">$label</div>
      <div style="background:#F5F6F8; border-radius:10px; padding:10px 12px; font-size:13px; line-height:1.7; color:#3A4250;">${(value == null || value.isEmpty) ? '—' : value}</div>
    </div>
  ''';

  String chipList(List<String> items) {
    if (items.isEmpty) return '<span style="font-size:12.5px; color:#8892A0;">—</span>';
    return items.map((t) => '''
      <span style="display:inline-block; background:#EAF3EF; color:#1F7A63; font-size:11.5px; font-weight:600; padding:4px 10px; border-radius:999px; margin:2px;">$t</span>
    ''').join('');
  }

  String yesNo(bool? v) => v == null ? '—' : (v ? 'نعم' : 'لا');

  final employeesHtml = r.employees.isEmpty
      ? '<div style="font-size:13px; color:#8892A0;">لا يوجد موظفون مصابون مسجّلون</div>'
      : r.employees.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final e = entry.value;
          return '''
      <div style="border:1px solid #EDEFF2; border-radius:12px; padding:14px 16px; margin-bottom:10px;">
        <div style="font-size:13.5px; font-weight:700; margin-bottom:8px; color:#2B3487;">مصاب رقم ${ArabicFormat.toEasternDigits(i)}: ${e.employeeName}${e.isFatality ? ' <span style="color:#B3261E; font-size:11.5px;">(حالة وفاة)</span>' : ''}</div>
        ${row('الجنسية', e.nationality ?? '—')}
        ${row('الرقم الوظيفي', e.employeeIdNo ?? '—')}
        ${row('العمر', e.age != null ? ArabicFormat.toEasternDigits(e.age!) : '—')}
        ${row('القسم / الإدارة', e.department ?? '—')}
        ${row('المسمى الوظيفي', e.jobTitle ?? '—')}
        ${row('الوردية', e.shift ?? '—')}
        ${row('نوع العقد', e.employmentType != null ? (kEmploymentTypeLabels[e.employmentType] ?? e.employmentType!) : '—')}
        ${row('عدد أشهر العمل بهذه الوظيفة', e.monthsInJob != null ? ArabicFormat.toEasternDigits(e.monthsInJob!) : '—')}
        ${row('عدد أشهر العمل بالشركة', e.monthsInCompany != null ? ArabicFormat.toEasternDigits(e.monthsInCompany!) : '—')}
        ${row('عدد أيام الغياب', ArabicFormat.toEasternDigits(e.lostWorkDays))}
        <div style="margin-top:8px;">
          <div style="font-size:12px; color:#5C6673; margin-bottom:4px;">الجزء المتضرر في الجسم</div>
          <div>${chipList(e.bodyPartsAffected.map((k) => kBodyPartLabels[k] ?? k).toList())}</div>
        </div>
        <div style="margin-top:8px;">
          <div style="font-size:12px; color:#5C6673; margin-bottom:4px;">طبيعة الإصابة (الأكثر شدة)</div>
          <div>${chipList(e.injuryNature.map((k) => kInjuryNatureLabels[k] ?? k).toList())}</div>
        </div>
        ${e.injuryNatureOther != null && e.injuryNatureOther!.isNotEmpty ? textBlock('تفاصيل إضافية عن الإصابة', e.injuryNatureOther) : ''}
      </div>
    ''';
        }).join('');

  final actionsRowsHtml = r.actions.isEmpty
      ? '<tr><td colspan="4" style="padding:12px; text-align:center; color:#8892A0; font-size:12.5px;">لا توجد إجراءات مسجّلة</td></tr>'
      : r.actions.map((a) {
          final statusLabel = a.done ? 'تم' : 'بانتظار التنفيذ';
          final statusColor = a.done ? '#1F7A63' : '#B45309';
          return '''
      <tr>
        <td style="padding:8px 10px; border-bottom:1px solid #EDEFF2; font-size:12.5px;">${a.actionDescription}</td>
        <td style="padding:8px 10px; border-bottom:1px solid #EDEFF2; font-size:12.5px;">${a.responsiblePerson ?? '—'}</td>
        <td style="padding:8px 10px; border-bottom:1px solid #EDEFF2; font-size:12.5px;">${a.targetDate != null ? ArabicFormat.date(a.targetDate!) : '—'}</td>
        <td style="padding:8px 10px; border-bottom:1px solid #EDEFF2; font-size:12.5px; color:$statusColor; font-weight:600;">$statusLabel</td>
      </tr>
    ''';
        }).join('');

  final investigatorsHtml = r.investigators.isEmpty
      ? '<div style="font-size:12.5px; color:#8892A0;">—</div>'
      : r.investigators.map((i) => '''
      <div style="display:flex; justify-content:space-between; padding:6px 0; border-bottom:1px solid #EDEFF2; font-size:12.5px;">
        <span>${i.name}</span>
        <span style="color:#5C6673;">${i.jobTitle ?? ''}</span>
      </div>
    ''').join('');

  final statusLabel = r.isClosed ? 'مُغلَق (معتمد)' : 'مفتوح (قيد التحقيق)';
  final statusColor = r.isClosed ? '#1F7A63' : '#B45309';

  return '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
  @page { size: A4; margin: 0; }
  body { margin: 0; }
  table { border-collapse: collapse; width: 100%; }
</style>
</head>
<body>
<div dir="rtl" lang="ar" style="width:794px; min-height:1123px; box-sizing:border-box; background:#FFFFFF; font-family:'IBM Plex Sans Arabic','Segoe UI',Tahoma,sans-serif; color:#1A2129; padding:50px 56px; display:flex; flex-direction:column;">

  <div style="display:flex; align-items:flex-start; justify-content:space-between; padding-bottom:18px; border-bottom:2px solid #2B3487;">
    <div style="display:flex; flex-direction:column; gap:6px;">
      <div style="font-size:20px; font-weight:700; color:#2B3487;">تقرير تحقيق إصابة عمل</div>
      <div style="font-size:12.5px; color:#5C6673;">QMS-SAF-007 — رقم الحادث: ${r.incidentNumber ?? '—'}</div>
    </div>
    <div style="text-align:left; font-size:12px; color:#8892A0;">
      <div>صيانتي — إدارة الصيانة والإنتاج والسلامة</div>
      <div style="margin-top:4px; display:inline-block; background:${r.isClosed ? '#EAF3EF' : '#FEF3E2'}; color:$statusColor; font-weight:700; padding:3px 10px; border-radius:999px;">$statusLabel</div>
    </div>
  </div>

  <div style="display:grid; grid-template-columns:repeat(3, minmax(0,1fr)); gap:14px; padding:18px 0;">
    <div style="background:#F5F6F8; border-radius:12px; padding:14px;">
      <div style="font-size:12px; color:#5C6673; margin-bottom:6px;">القسم</div>
      <div style="font-size:14.5px; font-weight:700; color:#2B3487;">${r.department}</div>
    </div>
    <div style="background:#F5F6F8; border-radius:12px; padding:14px;">
      <div style="font-size:12px; color:#5C6673; margin-bottom:6px;">تاريخ التحقيق</div>
      <div style="font-size:14.5px; font-weight:700;">${ArabicFormat.date(r.investigationDate)}</div>
    </div>
    <div style="background:#F5F6F8; border-radius:12px; padding:14px;">
      <div style="font-size:12px; color:#5C6673; margin-bottom:6px;">تاريخ ووقت الحادث</div>
      <div style="font-size:14.5px; font-weight:700; color:#7A5100;">${ArabicFormat.dateTime(r.occurredAt)}</div>
    </div>
  </div>

  <div style="margin-bottom:6px;">
    <div style="font-size:12px; color:#5C6673; margin-bottom:6px;">طبيعة الحادث</div>
    <div>${chipList(r.natureOfAccident.map((k) => kNatureOfAccidentLabels[k] ?? k).toList())}</div>
  </div>
  <div style="margin:10px 0 6px;">
    <div style="font-size:12px; color:#5C6673; margin-bottom:6px;">نوع الإصابة/المرض</div>
    <div>${chipList(r.injuryTypes.map((k) => kInjuryTypeLabels[k] ?? k).toList())}</div>
  </div>

  ${sectionTitle('الموظفون المصابون', 'الخطوة ١')}
  <div style="margin-bottom:6px; font-size:12.5px; color:#5C6673;">
    عدد المصابين: ${ArabicFormat.toEasternDigits(r.injuredCount)}${r.fatalitiesCount > 0 ? ' — عدد الوفيات: ${ArabicFormat.toEasternDigits(r.fatalitiesCount)}' : ''}
  </div>
  $employeesHtml

  ${sectionTitle('ظروف الحادث', 'الخطوة ٢')}
  ${row('موقع الحادث بالتفصيل', r.incidentLocation, bold: true)}
  ${row('جزء الدوام الذي وقع فيه الحادث', r.workdayPart != null ? (kWorkdayPartLabels[r.workdayPart] ?? r.workdayPart!) : '—')}
  ${row('خطابات شهود مكتوبة', yesNo(r.witnessStatements))}
  ${row('صور من الموقع', yesNo(r.photographsTaken))}
  ${row('رسوم / مخططات', yesNo(r.mapsDrawings))}
  <div style="margin-top:10px;">
    <div style="font-size:12px; color:#5C6673; margin-bottom:6px;">معدات الحماية الشخصية المستخدمة أثناء الحادث</div>
    <div>${chipList(r.ppeUsed.map((k) => kInjuryPpeLabels[k] ?? k).toList())}</div>
  </div>
  ${textBlock('وصف الحادثة خطوة بخطوة', r.incidentDescription)}

  ${sectionTitle('تحليل السبب الجذري', 'الخطوة ٣')}
  ${textBlock('ما سبب وجود الظروف غير الآمنة؟', r.unsafeConditionReason)}
  ${textBlock('ما سبب حدوث التصرفات غير الآمنة؟', r.unsafeActReason)}
  ${row('هل هناك مكافأة قد تشجّع على الظروف/الأفعال غير الآمنة؟', yesNo(r.hadRewardIncentive))}
  ${row('هل تم الإبلاغ عن هذه الظروف/الأفعال قبل الحادث؟', yesNo(r.reportedBefore))}
  ${row('هل حدثت حوادث أو أخطار كامنة مماثلة سابقًا؟', yesNo(r.similarIncidentsBefore))}

  ${sectionTitle('هرم الضوابط وإجراءات الوقاية', 'الخطوة ٤')}
  ${row('الضابط المختار', r.hierarchyOfControl != null ? (kHierarchyOfControlLabels[r.hierarchyOfControl] ?? r.hierarchyOfControl!) : '—', bold: true)}
  ${textBlock('تفاصيل الضابط المختار', r.controlDetails)}
  <div style="margin:10px 0 6px;">
    <div style="font-size:12px; color:#5C6673; margin-bottom:6px;">التغييرات المطلوبة لمنع تكرار الحادث</div>
    <div>${chipList(r.preventionChanges.map((k) => kPreventionChangeLabels[k] ?? k).toList())}</div>
  </div>
  ${textBlock('ما الذي يجب تنفيذه لتحقيق ذلك؟', r.preventionNotes)}

  <div style="font-size:13px; font-weight:700; margin:14px 0 8px;">جدول متابعة الإجراءات</div>
  <table>
    <thead>
      <tr style="background:#F5F6F8;">
        <th style="padding:8px 10px; text-align:right; font-size:11.5px; color:#5C6673;">الإجراء</th>
        <th style="padding:8px 10px; text-align:right; font-size:11.5px; color:#5C6673;">المسؤول</th>
        <th style="padding:8px 10px; text-align:right; font-size:11.5px; color:#5C6673;">الموعد المستهدف</th>
        <th style="padding:8px 10px; text-align:right; font-size:11.5px; color:#5C6673;">الحالة</th>
      </tr>
    </thead>
    <tbody>
      $actionsRowsHtml
    </tbody>
  </table>

  ${sectionTitle('مراجعة واعتماد التقرير', 'الخطوة ٥')}
  ${row('كتب التقرير بواسطة', r.writtenBy ?? '—')}
  ${row('المسمى الوظيفي', r.writtenByTitle ?? '—')}
  <div style="margin:10px 0 6px;">
    <div style="font-size:12px; color:#5C6673; margin-bottom:6px;">أعضاء فريق التحقيق</div>
    $investigatorsHtml
  </div>
  ${row('تم الاعتماد بواسطة', r.approvedBy ?? 'بانتظار الاعتماد')}
  ${row('المسمى الوظيفي', r.approvedByTitle ?? '—')}
  ${row('تاريخ الاعتماد', r.approvedAt != null ? ArabicFormat.dateTime(r.approvedAt!) : '—')}

  <div style="margin-top:auto; padding-top:24px; border-top:1px solid #EDEFF2; font-size:11px; color:#B4BAC2; display:flex; justify-content:space-between;">
    <span>تم إنشاء هذا التقرير تلقائيًا من تطبيق صيانتي — أُبلِغ عنه بواسطة: ${r.reportedBy}</span>
    <span>${ArabicFormat.dateTime(DateTime.now())}</span>
  </div>

</div>
</body>
</html>
''';
}
