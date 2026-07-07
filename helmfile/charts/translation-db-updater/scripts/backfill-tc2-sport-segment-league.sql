-- ============================================================================
-- One-off backfill: sport / segment / league translations from the legacy
-- TranslationCache into TranslationCache2's per-language columns.
--
-- SQL port of the OE.Translation.Service CacheBackfill bridge
-- (TranslationRepository.BackfillTranslationCache2), scoped to SpId:/SegId:/LeId:
-- rows. Semantics mirrored exactly:
--   * TranslationCache has NO String_ID (PK: SOURCE_HASH, SOURCE_LANGUAGE,
--     TARGET_LANGUAGE), so rows are correlated by hashing TranslationCache2's
--     SOURCE_TEXT with the same formula as the legacy persisted column:
--     CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', <NVARCHAR text>), 2).
--     Only rows already seeded in TranslationCache2 can therefore be migrated —
--     new rows cannot be created from TranslationCache (no key to build).
--   * Only EMPTY target columns are filled ("non existing" translations);
--     a target the external pipeline already wrote is never overwritten.
--   * Legacy source language EN only; legacy target languages map to the fixed
--     columns ZH / ES / FR — any other language has no column and is skipped.
--   * Legacy TARGET_TEXT is unbounded, the flat columns are NVARCHAR(250):
--     defensively truncated.
--   * A row that received at least one backfilled target is marked
--     PROCESSED = 1 (the legacy cache satisfied it — no DeepL pass needed).
--     If a configured language is still empty, the pipeline's startup
--     missing-language reset re-opens it. UPDATED_AT is left untouched
--     (liveness semantics belong to OE.Translation.Service).
--
-- Run against the Translation database. Idempotent: a second run finds no
-- empty column with a legacy match and updates 0 rows.
-- NOT shipped by the translation-db-updater chart (configmap only mounts
-- update.py) — apply manually via change control.
-- ============================================================================

SET XACT_ABORT ON;
SET NOCOUNT ON;

-- Preview (optional): uncomment to inspect what would be backfilled.
-- SELECT tc2.STRING_ID, tc2.SOURCE_TEXT,
--        zh.TARGET_TEXT AS NEW_ZH, es.TARGET_TEXT AS NEW_ES, fr.TARGET_TEXT AS NEW_FR
-- FROM dbo.TranslationCache2 AS tc2
-- CROSS APPLY (SELECT CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', tc2.SOURCE_TEXT), 2) AS HASH) AS h
-- LEFT JOIN dbo.TranslationCache AS zh
--        ON zh.SOURCE_HASH = h.HASH AND zh.SOURCE_LANGUAGE = 'EN' AND zh.TARGET_LANGUAGE = 'ZH'
--       AND zh.TARGET_TEXT IS NOT NULL AND zh.TARGET_TEXT <> N''
-- LEFT JOIN dbo.TranslationCache AS es
--        ON es.SOURCE_HASH = h.HASH AND es.SOURCE_LANGUAGE = 'EN' AND es.TARGET_LANGUAGE = 'ES'
--       AND es.TARGET_TEXT IS NOT NULL AND es.TARGET_TEXT <> N''
-- LEFT JOIN dbo.TranslationCache AS fr
--        ON fr.SOURCE_HASH = h.HASH AND fr.SOURCE_LANGUAGE = 'EN' AND fr.TARGET_LANGUAGE = 'FR'
--       AND fr.TARGET_TEXT IS NOT NULL AND fr.TARGET_TEXT <> N''
-- WHERE (tc2.STRING_ID LIKE N'SpId:%' OR tc2.STRING_ID LIKE N'SegId:%' OR tc2.STRING_ID LIKE N'LeId:%')
--   AND (   (tc2.TARGET_TEXT_ZH = N'' AND zh.TARGET_TEXT IS NOT NULL)
--        OR (tc2.TARGET_TEXT_ES = N'' AND es.TARGET_TEXT IS NOT NULL)
--        OR (tc2.TARGET_TEXT_FR = N'' AND fr.TARGET_TEXT IS NOT NULL));

BEGIN TRANSACTION;

UPDATE tc2
SET tc2.TARGET_TEXT_ZH = CASE WHEN tc2.TARGET_TEXT_ZH = N'' AND zh.TARGET_TEXT IS NOT NULL
                              THEN LEFT(zh.TARGET_TEXT, 250) ELSE tc2.TARGET_TEXT_ZH END,
    tc2.TARGET_TEXT_ES = CASE WHEN tc2.TARGET_TEXT_ES = N'' AND es.TARGET_TEXT IS NOT NULL
                              THEN LEFT(es.TARGET_TEXT, 250) ELSE tc2.TARGET_TEXT_ES END,
    tc2.TARGET_TEXT_FR = CASE WHEN tc2.TARGET_TEXT_FR = N'' AND fr.TARGET_TEXT IS NOT NULL
                              THEN LEFT(fr.TARGET_TEXT, 250) ELSE tc2.TARGET_TEXT_FR END,
    tc2.PROCESSED      = 1
FROM dbo.TranslationCache2 AS tc2
CROSS APPLY (SELECT CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', tc2.SOURCE_TEXT), 2) AS HASH) AS h
LEFT JOIN dbo.TranslationCache AS zh
       ON zh.SOURCE_HASH = h.HASH AND zh.SOURCE_LANGUAGE = 'EN' AND zh.TARGET_LANGUAGE = 'ZH'
      AND zh.TARGET_TEXT IS NOT NULL AND zh.TARGET_TEXT <> N''
LEFT JOIN dbo.TranslationCache AS es
       ON es.SOURCE_HASH = h.HASH AND es.SOURCE_LANGUAGE = 'EN' AND es.TARGET_LANGUAGE = 'ES'
      AND es.TARGET_TEXT IS NOT NULL AND es.TARGET_TEXT <> N''
LEFT JOIN dbo.TranslationCache AS fr
       ON fr.SOURCE_HASH = h.HASH AND fr.SOURCE_LANGUAGE = 'EN' AND fr.TARGET_LANGUAGE = 'FR'
      AND fr.TARGET_TEXT IS NOT NULL AND fr.TARGET_TEXT <> N''
WHERE (tc2.STRING_ID LIKE N'SpId:%' OR tc2.STRING_ID LIKE N'SegId:%' OR tc2.STRING_ID LIKE N'LeId:%')
  AND (   (tc2.TARGET_TEXT_ZH = N'' AND zh.TARGET_TEXT IS NOT NULL)
       OR (tc2.TARGET_TEXT_ES = N'' AND es.TARGET_TEXT IS NOT NULL)
       OR (tc2.TARGET_TEXT_FR = N'' AND fr.TARGET_TEXT IS NOT NULL));

PRINT CONCAT('TranslationCache2 sport/segment/league rows backfilled: ', @@ROWCOUNT);

COMMIT TRANSACTION;
