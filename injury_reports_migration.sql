-- ترقية جدول injury_reports لدعم:
-- 1) اختيار أكثر من ضابط واحد في "هرم الضوابط" مع خانة تفاصيل مستقلة لكل ضابط.
-- 2) أسباب مخطط "عظم السمكة" (Fishbone) كاختيار متعدد حقيقي بدل صورة ثابتة.
-- شغّل هذا الملف مرة واحدة فقط على قاعدة البيانات، قبل نشر ملف
-- routes/injuryReports.js المحدَّث.

-- 1) هرم الضوابط: من نص واحد إلى مصفوفة نصوص (اختيار متعدد) — أي قيمة سابقة
--    محفوظة تُلفّ تلقائيًا داخل مصفوفة من عنصر واحد فلا تُفقد أي بيانات قديمة.
ALTER TABLE injury_reports
  ALTER COLUMN hierarchy_of_control TYPE TEXT[]
  USING CASE WHEN hierarchy_of_control IS NULL THEN '{}'::TEXT[] ELSE ARRAY[hierarchy_of_control] END;
ALTER TABLE injury_reports ALTER COLUMN hierarchy_of_control SET DEFAULT '{}';
ALTER TABLE injury_reports ALTER COLUMN hierarchy_of_control SET NOT NULL;
ALTER TABLE injury_reports RENAME COLUMN hierarchy_of_control TO hierarchy_of_controls;

-- 2) تفاصيل الضابط: من نص واحد مشترك إلى نص JSON بمفتاح لكل ضابط مختار —
--    القيمة القديمة (لو موجودة) تُحفَظ تحت مفتاح الضابط الذي كان مختارًا سابقًا.
ALTER TABLE injury_reports ADD COLUMN control_details_new TEXT;
UPDATE injury_reports SET control_details_new =
  CASE
    WHEN array_length(hierarchy_of_controls, 1) > 0 AND control_details IS NOT NULL AND control_details <> ''
      THEN json_build_object(hierarchy_of_controls[1], control_details)::text
    ELSE '{}'
  END;
ALTER TABLE injury_reports DROP COLUMN control_details;
ALTER TABLE injury_reports RENAME COLUMN control_details_new TO control_details;
ALTER TABLE injury_reports ALTER COLUMN control_details SET DEFAULT '{}';
ALTER TABLE injury_reports ALTER COLUMN control_details SET NOT NULL;

-- 3) عمود جديد لأسباب مخطط عظم السمكة (٣٦ سببًا محتملًا، اختيار متعدد).
ALTER TABLE injury_reports ADD COLUMN fishbone_causes TEXT[] NOT NULL DEFAULT '{}';
