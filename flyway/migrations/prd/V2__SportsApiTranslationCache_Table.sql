CREATE TABLE Translation.dbo.SportsApiTranslationCache (
    id                BIGINT IDENTITY(1,1) PRIMARY KEY,
    source_lang       VARCHAR(10)   NOT NULL CONSTRAINT DF_SATC_src   DEFAULT 'EN',
    source_text       NVARCHAR(250) COLLATE Latin1_General_100_CS_AS NOT NULL,
    target_text_zh    NVARCHAR(250) NOT NULL CONSTRAINT DF_SATC_zh    DEFAULT N'',
    target_text_pt_br NVARCHAR(250) NOT NULL CONSTRAINT DF_SATC_ptbr  DEFAULT N'',
    target_text_th    NVARCHAR(250) NOT NULL CONSTRAINT DF_SATC_th    DEFAULT N'',
    target_text_id    NVARCHAR(250) NOT NULL CONSTRAINT DF_SATC_id    DEFAULT N'',
    target_text_ko    NVARCHAR(250) NOT NULL CONSTRAINT DF_SATC_ko    DEFAULT N'',
    target_text_ja    NVARCHAR(250) NOT NULL CONSTRAINT DF_SATC_ja    DEFAULT N'',
    target_text_vi    NVARCHAR(250) NOT NULL CONSTRAINT DF_SATC_vi    DEFAULT N'',
    target_text_pt    NVARCHAR(250) NOT NULL CONSTRAINT DF_SATC_pt    DEFAULT N'',
    created_at        DATETIME2 NOT NULL CONSTRAINT DF_SATC_created   DEFAULT SYSUTCDATETIME(),
    updated_at        DATETIME2 NOT NULL CONSTRAINT DF_SATC_updated   DEFAULT SYSUTCDATETIME(),
    CONSTRAINT uq_SATC_source UNIQUE (source_text, source_lang)
);
