-- GM-825: the REQUEST payload is missing from Platform.dbo.OperatorLog for parlay bets, while the
-- RESPONSE payload is always present.
--
-- Platform.Operator.Servicev2 writes two rows per operator call through AddOperatorLog
-- (BettingRepository.cs:586): Direction 'REQUEST' before the HTTP POST (line 707) and Direction
-- 'RESPONSE' after it (line 749). The two rows are identical apart from Info, each one runs in its
-- own TransactionScope, and the caller (Worker.cs:428) opens no ambient transaction, so the only
-- thing that can make the REQUEST row fail while the RESPONSE row succeeds is the size of Info.
--
-- Info is nvarchar(4000). Request payload sizes measured from production traces on 2026-09-15:
-- a single is 1,122 to 1,229 characters and a 2 leg parlay is 1,783, i.e. roughly 560 characters of
-- header plus 610 to 760 per selection. That crosses 4,000 at about 5 to 7 legs depending on league,
-- fixture and market name lengths. A single can never reach it and a response is about 365
-- characters, so only parlays lose their REQUEST row. SQL Server rejects the insert with "String or
-- binary data would be truncated" and AddOperatorLog swallows it: the build running in production
-- (platform-operator-service:0.1.120-prd) has an empty catch, and GM-801, which added an error log
-- there, is not deployed yet. That is why the failure leaves no trace in the application logs.
--
-- The same ceiling applies to the settlement, cash out and cancellation REQUEST rows, whose payload
-- (OperatorBetSettlementRequestDTO) also carries BetSelections.
--
-- Widening Info to nvarchar(MAX), matching Platform.dbo.OperatorSettlementRetry.Info in the same
-- database. NOT NULL and the SQL_Latin1_General_CP1_CI_AS collation are restated so that the ALTER
-- cannot silently make the column nullable or move it to the database default collation. Info
-- carries no index (PK_OperatorLog_Id on Id is the only key on the table), so there is no index key
-- size limit in the way.
--
-- OperatorLog is written on every bet placement and settlement, so the ALTER takes a brief
-- schema modification lock on a hot table. It is a metadata only change, and because AddOperatorLog
-- swallows every exception, a blocked write during the lock would drop a log row rather than affect
-- bet placement or settlement.
--
-- Idempotent: the ALTER runs only while Info is not already nvarchar(MAX), i.e. max_length <> -1.

USE Platform;

IF EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'Platform.dbo.OperatorLog')
      AND name = N'Info'
      AND max_length <> -1
)
    ALTER TABLE Platform.dbo.OperatorLog
        ALTER COLUMN Info nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL;
