-- GM-862: OperatorSettlementRetry held at most one row per bet (keyed on BetId alone), so a second
-- independent wallet-call failure on the same bet (a different cashout, settlement, or cancellation
-- attempt) silently overwrote an earlier still-pending retry, discarding it with no record it ever
-- existed. No tight race is needed to trigger this: every wallet-failure call site
-- (Platform.Operator.Servicev2/Repository/BettingRepository.cs) stores the row on the very first
-- failure with no synchronous retry cushion, and Job.Resettlement backs off on a Fibonacci schedule
-- (2,4,6,10,16,26,42 minutes), so a pending row stays overwritable for minutes up to roughly 1.75
-- hours.
--
-- CorrelationId is already minted fresh per independent attempt and preserved unchanged across
-- every replay of that same attempt (Job.Resettlement republishes the row's own CorrelationId, and
-- the Operator.Servicev2 consumer reads it back off the message envelope), so it is the correct
-- discriminator for "one failure episode" and needs no new column. Widening the primary key to
-- (BetId, CorrelationId) instead.
--
-- Idempotent: the nullability fix and ALTER run only while CorrelationId is still nullable; the key
-- swap runs only while the new composite constraint does not already exist, and only drops the old
-- single-column constraint if it is still there.

USE Platform;

IF EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'Platform.dbo.OperatorSettlementRetry')
      AND name = N'CorrelationId'
      AND is_nullable = 1
)
BEGIN
    UPDATE Platform.dbo.OperatorSettlementRetry
    SET CorrelationId = CONVERT(NVARCHAR(255), NEWID())
    WHERE CorrelationId IS NULL;

    ALTER TABLE Platform.dbo.OperatorSettlementRetry
        ALTER COLUMN CorrelationId NVARCHAR(255) NOT NULL;
END

IF NOT EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE name = N'pkOperatorSettlementRetryBetIdCorrelationId'
      AND parent_object_id = OBJECT_ID(N'Platform.dbo.OperatorSettlementRetry')
)
BEGIN
    IF EXISTS (
        SELECT 1
        FROM sys.key_constraints
        WHERE name = N'pkOperatorSettlementRetryBetId'
          AND parent_object_id = OBJECT_ID(N'Platform.dbo.OperatorSettlementRetry')
    )
        ALTER TABLE Platform.dbo.OperatorSettlementRetry
            DROP CONSTRAINT pkOperatorSettlementRetryBetId;

    ALTER TABLE Platform.dbo.OperatorSettlementRetry
        ADD CONSTRAINT pkOperatorSettlementRetryBetIdCorrelationId PRIMARY KEY (BetId, CorrelationId);
END
