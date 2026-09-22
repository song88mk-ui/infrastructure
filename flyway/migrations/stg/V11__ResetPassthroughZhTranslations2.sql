-- Re-run of V10. On stg, V10's re-queued rows were drained by the translation-db-updater
-- CronJob (runs every 5 min) before its own script fix (helmfile/charts/translation-db-updater
-- glossary map, GM-784) had actually been deployed: an ops deploy mistake pushed the old
-- script content, so every re-queued row was translated again with glossary=None and landed
-- back in the same passthrough state (TARGET_TEXT_ZH = SOURCE_TEXT). The script fix is now
-- confirmed live and producing non-empty glossary lookups. Same statement as V10, which is
-- self-scoping/idempotent, so it simply re-queues whatever passthrough population exists now.

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
        + N' passthrough ZH rows to PROCESSED = 0 for re-translation (re-run of V10).';
END
