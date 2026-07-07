-- ============================================================================
-- One-off backfill: ALL TranslationCache2 rows — fill empty per-language target
-- columns from the legacy TranslationCache (hash match) and, for ZH only, the
-- SportsbookStatic glossary table (exact Name match) as a second source.
--
-- Generalization of backfill-tc2-sport-segment-league.sql to every seeded row
-- (MaTe:/SeTe:/Te:/SpId:/SegId:/LeId: keys); running this makes the scoped
-- script unnecessary. Same semantics as the OE.Translation.Service
-- CacheBackfill bridge (TranslationRepository.BackfillTranslationCache2):
--   * TranslationCache has NO String_ID (PK: SOURCE_HASH, SOURCE_LANGUAGE,
--     TARGET_LANGUAGE), so rows are correlated by hashing TranslationCache2's
--     SOURCE_TEXT with the legacy persisted-column formula:
--     CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', <NVARCHAR text>), 2).
--   * SportsbookStatic (LanguageCode, Name, Value) is matched by exact Name =
--     SOURCE_TEXT (trimmed, case-insensitive collation) with LanguageCode='ZH'
--     — the same table update.py's fetch_glossary_entries() reads to build the
--     DeepL glossary. ASSUMPTION: when a source text has both a legacy
--     TranslationCache hit and a SportsbookStatic entry, the legacy cache wins
--     (matches this script's existing precedent as the primary source); flag
--     if SportsbookStatic should take priority instead.
--   * Only EMPTY target columns are filled; a target the external pipeline
--     already wrote is never overwritten.
--   * Legacy source language EN only; target languages ZH / ES / FR map to the
--     fixed columns — any other language has no column and is skipped. The
--     SportsbookStatic fallback is ZH-only per current request; ES/FR still
--     rely solely on the legacy TranslationCache hash match.
--   * Legacy/glossary TARGET_TEXT is unbounded, the flat columns are
--     NVARCHAR(250): defensively truncated.
--   * A row that received at least one backfilled target is marked
--     PROCESSED = 1 (a cache/glossary hit satisfied it — no DeepL pass
--     needed). If a configured language is still empty, the pipeline's
--     startup missing-language reset re-opens it. UPDATED_AT is left
--     untouched (liveness semantics belong to OE.Translation.Service).
--
-- Batched (TOP 20000 per iteration, own transaction each) so the whole-table
-- pass doesn't hold one long transaction; an updated row no longer satisfies
-- the WHERE (every fillable column is filled in its batch), so the loop
-- converges and the script is idempotent — a re-run updates 0 rows.
-- Run against the Translation database.
-- NOT shipped by the translation-db-updater chart (configmap only mounts
-- update.py) — apply manually via change control.
-- ============================================================================

SET XACT_ABORT ON;
SET NOCOUNT ON;

DECLARE @batch INT = 20000;
DECLARE @rows INT = 1;
DECLARE @total INT = 0;

WHILE @rows > 0
BEGIN
    BEGIN TRANSACTION;

    UPDATE TOP (@batch) tc2
    SET tc2.TARGET_TEXT_ZH = CASE WHEN tc2.TARGET_TEXT_ZH = N'' AND zh.TARGET_TEXT IS NOT NULL
                                  THEN LEFT(zh.TARGET_TEXT, 250)
                              WHEN tc2.TARGET_TEXT_ZH = N'' AND ss_zh.Value IS NOT NULL
                                  THEN LEFT(ss_zh.Value, 250)
                              ELSE tc2.TARGET_TEXT_ZH END,
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
    LEFT JOIN dbo.SportsbookStatic AS ss_zh
           ON LTRIM(RTRIM(ss_zh.Name)) COLLATE Latin1_General_CI_AS = LTRIM(RTRIM(tc2.SOURCE_TEXT)) COLLATE Latin1_General_CI_AS
          AND ss_zh.LanguageCode = 'ZH'
          AND ss_zh.Value IS NOT NULL AND LTRIM(RTRIM(ss_zh.Value)) <> N''
    LEFT JOIN dbo.TranslationCache AS es
           ON es.SOURCE_HASH = h.HASH AND es.SOURCE_LANGUAGE = 'EN' AND es.TARGET_LANGUAGE = 'ES'
          AND es.TARGET_TEXT IS NOT NULL AND es.TARGET_TEXT <> N''
    LEFT JOIN dbo.TranslationCache AS fr
           ON fr.SOURCE_HASH = h.HASH AND fr.SOURCE_LANGUAGE = 'EN' AND fr.TARGET_LANGUAGE = 'FR'
          AND fr.TARGET_TEXT IS NOT NULL AND fr.TARGET_TEXT <> N''
    WHERE (   (tc2.TARGET_TEXT_ZH = N'' AND (zh.TARGET_TEXT IS NOT NULL OR ss_zh.Value IS NOT NULL))
           OR (tc2.TARGET_TEXT_ES = N'' AND es.TARGET_TEXT IS NOT NULL)
           OR (tc2.TARGET_TEXT_FR = N'' AND fr.TARGET_TEXT IS NOT NULL));

    SET @rows = @@ROWCOUNT;
    SET @total = @total + @rows;

    COMMIT TRANSACTION;

    IF @rows > 0
        PRINT CONCAT('Batch backfilled ', @rows, ' rows (running total: ', @total, ')');
END;

PRINT CONCAT('TranslationCache2 rows backfilled from legacy TranslationCache / SportsbookStatic (ZH): ', @total);
