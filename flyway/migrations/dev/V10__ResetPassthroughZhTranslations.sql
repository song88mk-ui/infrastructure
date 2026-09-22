-- GM-784: team and player names render as Latin text on the Chinese sportsbook even though
-- TranslationCache2 shows them translated and Backoffice displays them as handled.
--
-- Root cause is that the DeepL glossary has not been applied to any translation since
-- 2026-08-24. GM-748 switched update.py's TARGET_LANGUAGES from ["ZH"] to ["ZH-HANS"]
-- (helmfile/charts/translation-db-updater/scripts/update.py:78). That constant feeds two
-- boundaries that leave the script. GM-784 fixed the first, the v1/cachepreload announce
-- wire, by adding a code map. The second, fetch_glossary_entries, kept passing the raw
-- DeepL code into a SportsbookStatic lookup keyed by the platform code: staging holds
-- 12,860 rows under LanguageCode = 'ZH' and zero under 'ZH-HANS', so the query returned
-- nothing, ensure_glossary returned None, and every translate_text call ran with
-- glossary=None. Staging logs show it directly:
--     glossary_entries_loaded  entry_count=0  target_lang=ZH-HANS
--     glossary_empty           target_lang=ZH-HANS
-- With no glossary DeepL passes names through untransliterated, so the Chinese column was
-- written with the English source text. 42,651 staging rows were in that state on
-- 2026-09-21. The script fix ships alongside this migration.
--
-- A repaired glossary alone does not fix the existing rows. update.py's build_tasks
-- (update.py:247) sends a row to DeepL only when its target column is EMPTY; a row whose
-- TARGET_TEXT_ZH already holds the English text is treated as a cache hit and skipped, so
-- it would never reach the now working glossary. This migration clears that column and puts
-- the row back on the worklist (PROCESSED = 0) so the next pass re-translates it properly.
--
-- Scope. Only rows whose Chinese column is character for character equal to the English
-- source are touched, which is exactly the passthrough population; a genuinely translated
-- row differs from its source and is left alone. Rows whose source text contains no Latin
-- letter ("5+", "0-1", "2.5") are excluded: those read the same in every language, DeepL
-- would return them unchanged, and re-queueing them is pure churn. That guard mirrors
-- Backoffice.Shared/Utilities/TranslationTextHelper.RequiresTranslation. ES and FR are not
-- touched. The statement is self-scoping, so it clears whatever the population is in this
-- environment and is a no-op where there is none.
--
-- Ordering. This must run AFTER the update.py glossary fix is deployed. Run earlier and
-- DeepL is still called without a glossary, the rows are re-translated to the same English
-- passthrough, and nothing changes except wasted API calls.
--
-- Load. update.py drains the worklist at FETCH_LIMIT = 1000 per five minute pass, so a
-- 42k population takes roughly three and a half hours. Announcements are batched at
-- PRELOAD_BATCH_SIZE = 500 keys per POST and each POST becomes one OnTranslationChange
-- message, so this adds on the order of 85 messages to q.oe.translation rather than one per
-- row. OE.Translation.Service still does per-key Mongo work off each message.
--
-- Batched at 2000 rows to keep each transaction and its lock footprint small on a table the
-- translation pipeline writes continuously, matching the batched delete in
-- OE.Translation.Job/Repository/TranslationCleanupRepository.cs.
--
-- Idempotent: after a row is cleared its TARGET_TEXT_ZH is N'' , which no longer equals its
-- SOURCE_TEXT (the Latin letter guard means SOURCE_TEXT is never empty here), so the WHERE
-- clause matches nothing on a re-run and the loop exits on the first pass.

USE Translation;

IF OBJECT_ID(N'Translation.dbo.TranslationCache2') IS NOT NULL
BEGIN
    DECLARE @batch int = 2000;
    DECLARE @rows  int = 1;
    DECLARE @total int = 0;

    WHILE @rows > 0
    BEGIN
        UPDATE TOP (@batch) Translation.dbo.TranslationCache2
        SET    TARGET_TEXT_ZH = N'',
               PROCESSED      = 0,
               UPDATED_AT     = GETUTCDATE()
        WHERE  SOURCE_LANGUAGE = N'EN'
          AND  TARGET_TEXT_ZH IS NOT NULL
          AND  TARGET_TEXT_ZH = SOURCE_TEXT
          AND  SOURCE_TEXT LIKE N'%[a-zA-Z]%';

        SET @rows  = @@ROWCOUNT;
        SET @total = @total + @rows;
    END

    PRINT N'GM-784: reset ' + CAST(@total AS nvarchar(20))
        + N' passthrough ZH rows to PROCESSED = 0 for re-translation.';
END
