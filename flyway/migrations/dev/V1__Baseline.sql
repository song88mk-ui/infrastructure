-- Auth

CREATE TABLE Auth.dbo.ActivityLog (
	Id int IDENTITY(1,1) NOT NULL,
	UserId nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Token nvarchar(3000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	UserAgent nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	IpAddress nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Country nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Date] datetimeoffset NULL,
	CONSTRAINT PK__Activity__3214EC07F334F6B0 PRIMARY KEY (Id)
);

CREATE TABLE Auth.dbo.AspNetRoles (
	Id nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Name nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	NormalizedName nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ConcurrencyStamp nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	UserGroupIdRef bigint NOT NULL,
	CONSTRAINT PK_AspNetRoles PRIMARY KEY (Id)
);

CREATE TABLE Auth.dbo.AspNetUserLogins (
	LoginProvider nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ProviderKey nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ProviderDisplayName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	UserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Auth.dbo.AspNetUserRoles (
	UserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	RoleId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Auth.dbo.AspNetUserTokens (
	UserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	LoginProvider nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Name nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Value nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	OperatorToken nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SessionExpirationDate datetime2 NULL
);

CREATE TABLE Auth.dbo.AspNetUsers (
	Id varchar(36) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	UserName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	NormalizedUserName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Email nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	NormalizedEmail nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	EmailConfirmed bit NULL,
	PasswordHash nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SecurityStamp nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ConcurrencyStamp nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	PhoneNumber nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	PhoneNumberConfirmed bit NULL,
	TwoFactorEnabled bit NULL,
	LockoutEnd datetimeoffset NULL,
	LockoutEnabled bit NULL,
	AccessFailedCount int NULL,
	NickName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MainUserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	AppId int NULL,
	AppName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	CreatedDate datetime2 NULL,
	IdRef bigint NULL,
	CONSTRAINT AspNetUsers_PK PRIMARY KEY (Id),
	CONSTRAINT AspNetUsers_UNIQUE UNIQUE (UserName)
);

CREATE TABLE Auth.dbo.Permission (
	PermissionId uniqueidentifier NOT NULL,
	CategoryId int NULL,
	CategoryName varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SubCategoryName varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	GroupName varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Name varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClaimType varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	HasReadOnly bit NULL,
	SortOrder int NULL,
	IsSubUser bit NULL,
	UserGroupTemplateIdRef int NULL,
	Version int NULL,
	CONSTRAINT Permission_PK PRIMARY KEY (PermissionId)
);

CREATE TABLE Auth.dbo.ReportRoles (
	RoleId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClaimType nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Url nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Auth.dbo.UserTokens (
	Id nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	UserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	TokenType nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	AccessToken nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	TokenExpiration datetime2 NULL,
	RefreshToken nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	RefreshExpiration datetime2 NULL
);

CREATE TABLE Auth.dbo.AspNetRoleClaims (
	Id int IDENTITY(1,1) NOT NULL,
	RoleId nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ClaimType nvarchar(256) COLLATE Latin1_General_CI_AS NULL,
	ClaimValue nvarchar(256) COLLATE Latin1_General_CI_AS NULL,
	CONSTRAINT PK_AspNetRoleClaims PRIMARY KEY (Id),
	CONSTRAINT FK_AspNetRoleClaims_AspNetRoles_RoleId FOREIGN KEY (RoleId) REFERENCES Auth.dbo.AspNetRoles(Id) ON DELETE CASCADE
);

CREATE TABLE Auth.dbo.AspNetUserClaims (
	Id int IDENTITY(1,1) NOT NULL,
	UserId varchar(36) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ClaimType nvarchar(1000) COLLATE Latin1_General_CI_AS NULL,
	ClaimValue nvarchar(1000) COLLATE Latin1_General_CI_AS NULL,
	CONSTRAINT PK_AspNetUserClaims PRIMARY KEY (Id),
	CONSTRAINT FK_AspNetUserClaims_AspNetUsers_UserId FOREIGN KEY (UserId) REFERENCES Auth.dbo.AspNetUsers(Id) ON DELETE CASCADE
);

-- Backoffice

CREATE TABLE Backoffice.dbo.ActivityLog2 (
	Id bigint IDENTITY(1,1) NOT NULL,
	Page nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
	Payload nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	Activity nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
	[From] nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
	[To] nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
	UserId nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
	UserName nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
	[TimeStamp] datetime2 DEFAULT sysutcdatetime() NOT NULL,
	CONSTRAINT PK__Activity__3214EC074A07C2E5 PRIMARY KEY (Id)
);
 CREATE NONCLUSTERED INDEX IX_ActivityLog2_TimeStamp ON Backoffice.dbo.ActivityLog2 (  TimeStamp DESC  )  
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;
 CREATE NONCLUSTERED INDEX IX_ActivityLog2_UserId ON Backoffice.dbo.ActivityLog2 (  UserId ASC  )  
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;

CREATE TABLE Backoffice.dbo.ClientBetSetting (
	ClientBetSettingId bigint IDENTITY(1,1) NOT NULL,
	ClientId bigint NOT NULL,
	CategoryId int NOT NULL,
	Setting nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	CreatedBy bigint NOT NULL,
	CreatedDate datetime2 DEFAULT sysutcdatetime() NOT NULL,
	ModifiedBy bigint NOT NULL,
	ModifiedDate datetime2 DEFAULT sysutcdatetime() NOT NULL,
	CurrencyCode nvarchar(10) COLLATE Latin1_General_CI_AS NULL,
	CONSTRAINT PK__ClientBe__B9A3358BBDE8CC8F PRIMARY KEY (ClientBetSettingId)
);
 CREATE NONCLUSTERED INDEX IX_ClientBetSetting_ClientId ON Backoffice.dbo.ClientBetSetting (  ClientId ASC  )  
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;


CREATE TABLE Backoffice.dbo.ClientInformation (
	ClientId int IDENTITY(1,1) NOT NULL,
	Name nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
	TelephoneNumber nvarchar(50) COLLATE Latin1_General_CI_AS NULL,
	Website nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
	StatusId int NOT NULL,
	MonthlyFee decimal(30,18) NOT NULL,
	ApplicationId int NOT NULL,
	CompanyShare decimal(30,18) NOT NULL,
	SportsbookShare decimal(30,18) NOT NULL,
	JackpotShare decimal(30,18) NOT NULL,
	RevenueShareSportsbook nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
	RevenueShareJackpot nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
	IsTierRevenueShare bit DEFAULT 0 NOT NULL,
	ClientShare decimal(30,18) NOT NULL,
	SetupFee decimal(30,18) NOT NULL,
	UserId bigint NOT NULL,
	Brand nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
	CreatedBy bigint NOT NULL,
	CreatedDate datetime2 DEFAULT sysutcdatetime() NOT NULL,
	ModifiedBy bigint NOT NULL,
	ModifiedDate datetime2 DEFAULT sysutcdatetime() NOT NULL,
	TaxConfig nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	Region nvarchar(50) COLLATE Latin1_General_CI_AS NULL,
	Email nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
	IsEmailNotification bit DEFAULT 0 NOT NULL,
	BetSlipMaxSelection int NOT NULL,
	IsDeleted bit DEFAULT 0 NOT NULL,
	CONSTRAINT PK__ClientIn__E67E1A24149803C2 PRIMARY KEY (ClientId)
);

-- Betting

CREATE TABLE Betting.dbo.Bet (
	BetId uniqueidentifier NOT NULL,
	UserId nvarchar(256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Stake decimal(26,12) NULL,
	TrueStake decimal(26,12) NULL,
	Odds decimal(26,12) NULL,
	OddsTypeId int NULL,
	OddsTypeName nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Payout decimal(26,12) NULL,
	WinLoss decimal(26,12) NULL,
	BetStatusId int NULL,
	BetStatusName nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Reason nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	CurrencyCode nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	LanguageCode nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ExchangeRate decimal(26,12) NULL,
	IPAddress nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Channel nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientIdRef int NULL,
	ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	LimitId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Endpoint nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	OperatorToken nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
	CompanyShare decimal(18,2) NULL,
	IsResettled bit NOT NULL,
	IsCashout bit NOT NULL,
	BetDate datetime2 NULL,
	BetDateOffset datetime2 NULL,
	SettlementDate datetime2 NULL,
	SettlementDateOffset datetime2 NULL,
	StakeTax decimal(26,12) NULL,
	WinningsTax decimal(26,12) NULL,
	TaxedStake decimal(26,12) NULL,
	TaxedWinnings decimal(26,12) NULL,
	ParlayBonus decimal(26,12) NULL,
	ParlayBonusWinnings decimal(26,12) NULL,
	StakeReal decimal(26,12) NULL,
	StakeBonus decimal(26,12) NULL,
	StakeRealPayout decimal(26,12) NULL,
	StakeBonusPayout decimal(26,12) NULL,
	IsFreeBet bit NOT NULL,
	BetTypeId int NULL,
	BetTypeName nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	OddsRef decimal(26,12) NULL,
	IsAgent bit NOT NULL,
	IsPartialCashout bit NOT NULL,
	BetIdRef nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientType nvarchar(20) COLLATE Latin1_General_CI_AS NULL,
	BonusId nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
	UserAgent nvarchar(750) COLLATE Latin1_General_CI_AS NULL,
	OperatorInfo nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
	OddsChangeTypeId smallint NULL,
	CONSTRAINT Bet_PK PRIMARY KEY (BetId DESC)
);

CREATE TABLE Betting.dbo.BetAudit (
	BetId uniqueidentifier NULL,
	UserId nvarchar(256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Stake decimal(26,12) NULL,
	TrueStake decimal(26,12) NULL,
	Odds decimal(26,12) NULL,
	OddsTypeId int NULL,
	OddsTypeName nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Payout decimal(26,12) NULL,
	WinLoss decimal(26,12) NULL,
	BetStatusId int NULL,
	BetStatusName nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Reason nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	CurrencyCode nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	LanguageCode nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ExchangeRate decimal(26,12) NULL,
	IPAddress nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Channel nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientIdRef int NULL,
	ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	LimitId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Endpoint nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	OperatorToken nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
	CompanyShare decimal(18,2) NULL,
	IsResettled bit NOT NULL,
	IsCashout bit NOT NULL,
	BetDate datetime2 NULL,
	BetDateOffset datetime2 NULL,
	SettlementDate datetime2 NULL,
	SettlementDateOffset datetime2 NULL,
	[Timestamp] datetime2 NULL,
	StakeTax decimal(26,12) NULL,
	WinningsTax decimal(26,12) NULL,
	TaxedStake decimal(26,12) NULL,
	TaxedWinnings decimal(26,12) NULL,
	ParlayBonus decimal(26,12) NULL,
	ParlayBonusWinnings decimal(26,12) NULL,
	StakeReal decimal(26,12) NULL,
	StakeBonus decimal(26,12) NULL,
	StakeRealPayout decimal(26,12) NULL,
	StakeBonusPayout decimal(26,12) NULL,
	IsFreeBet bit NOT NULL,
	BetTypeId int NULL,
	BetTypeName nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	OddsRef decimal(26,12) NULL,
	IsAgent bit NOT NULL,
	BetIdRef nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Id bigint IDENTITY(1,1) NOT NULL,
	OperatorInfo nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
	OddsChangeTypeId smallint NULL,
	CONSTRAINT PK_BetAudit_Id PRIMARY KEY (Id)
);

CREATE TABLE Betting.dbo.BetCancellationRetry (
	BetId uniqueidentifier NOT NULL,
	ClientId nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Reason nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	IsSuccess bit NULL,
	[Timestamp] datetime2 NULL,
	CONSTRAINT PK_BetCancellationRetry_BetId PRIMARY KEY (BetId)
);

CREATE TABLE Betting.dbo.BetConfig (
	ClientId uniqueidentifier NOT NULL,
	CurrencyCode nvarchar(15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	StakeLimitFixture decimal(30,8) NULL,
	MaxParlayPayout decimal(30,8) NULL,
	DefaultConfig nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	OverrideConfig nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ParlayConfig nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	CreatedDate datetime2 NULL,
	TaxConfig nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	PriceboostConfig nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	BetBuilderConfig nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	CONSTRAINT BetConfig_PK PRIMARY KEY (ClientId,CurrencyCode)
);

CREATE TABLE Betting.dbo.BetInfo (
	BetId uniqueidentifier NOT NULL,
	UserAgent nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Id bigint IDENTITY(1,1) NOT NULL,
	CONSTRAINT PK_BetInfo_Id PRIMARY KEY (Id)
);

CREATE TABLE Betting.dbo.BetMapping (
	BetId uniqueidentifier NOT NULL,
	BetIdRef nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientId nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	CONSTRAINT PK_BetMapping_BetId PRIMARY KEY (BetId)
);

CREATE TABLE Betting.dbo.BetPriceBoost (
	BetId uniqueidentifier NOT NULL,
	UserId nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	FixtureId bigint NOT NULL,
	MarketId bigint NOT NULL,
	BetStatusId int NOT NULL,
	BetStatusName nvarchar(30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	CONSTRAINT PK_BetPriceBoost_BetId PRIMARY KEY (BetId)
);

CREATE TABLE Betting.dbo.BetSelection (
	BetSelectionId uniqueidentifier NOT NULL,
	BetId uniqueidentifier NOT NULL,
	UserId nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SportId int NULL,
	SportName nvarchar(256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SegmentId int NULL,
	SegmentName nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	LeagueId int NULL,
	LeagueName nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureId bigint NULL,
	FixtureName nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	FixtureTypeId int NULL,
	FixtureTypeName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketTemplateId nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketId bigint NULL,
	MarketName nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	SelectionTemplateId nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SelectionId bigint NULL,
	SelectionName nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	FixtureStatusId int NULL,
	FixtureStatusName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Line nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Odds decimal(26,12) NULL,
	BetSelectionStatusId int NULL,
	BetSelectionStatusName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	IsSettled bit NOT NULL,
	IsResettled bit NOT NULL,
	FixtureSpecifier nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SelectionSpecifier nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureStartDate datetime2 NULL,
	BetScore nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SettlementScore nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	CorrelationId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Probability float NULL,
	WonProbability float NULL,
	LostProbability float NULL,
	VoidProbability float NULL,
	HalfWonProbability float NULL,
	HalfLostProbability float NULL,
	DeadHeatFactor decimal(26,12) NULL,
	OddsRef decimal(26,12) NULL,
	IsBinary bit NOT NULL,
	IsHandicap bit DEFAULT 0 NOT NULL,
	CONSTRAINT BetSelection_PK PRIMARY KEY (BetSelectionId,BetId)
);

CREATE TABLE Betting.dbo.BetSelectionAudit (
	BetId uniqueidentifier NULL,
	BetSelectionId uniqueidentifier NULL,
	UserId nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SportId int NULL,
	SportName nvarchar(256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SegmentId int NULL,
	SegmentName nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	LeagueId int NULL,
	LeagueName nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureId bigint NULL,
	FixtureName nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	FixtureTypeId int NULL,
	FixtureTypeName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketTemplateId nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketId bigint NULL,
	MarketName nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	SelectionTemplateId nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SelectionId bigint NULL,
	SelectionName nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	FixtureStatusId int NULL,
	FixtureStatusName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Line nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Odds decimal(26,12) NULL,
	BetSelectionStatusId int NULL,
	BetSelectionStatusName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	IsSettled bit NOT NULL,
	IsResettled bit NOT NULL,
	FixtureSpecifier nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SelectionSpecifier nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureStartDate datetime2 NULL,
	BetScore nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SettlementScore nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Probability float NULL,
	WonProbability float NULL,
	LostProbability float NULL,
	VoidProbability float NULL,
	HalfWonProbability float NULL,
	HalfLostProbability float NULL,
	CorrelationId nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Timestamp] datetime2 DEFAULT getdate() NULL,
	DeadHeatFactor decimal(26,12) NULL,
	OddsRef decimal(26,12) NULL,
	IsBinary bit DEFAULT 0 NOT NULL,
	Id bigint IDENTITY(1,1) NOT NULL,
	CONSTRAINT PK_BetSelectionAudit_Id PRIMARY KEY (Id)
);

CREATE TABLE Betting.dbo.ClientTopMarket (
	ClientId nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ClientCode nvarchar(30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ClientName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	CurrencyCode nvarchar(30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	FixtureId bigint NULL,
	FixtureName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketId bigint NULL,
	MarketName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketStatusId int NULL,
	MarketStatusName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	BetCount int NULL
);

CREATE TABLE Betting.dbo.League (
	Id int NOT NULL,
	SportId int NULL,
	SegmentId int NULL,
	Segment nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	LeagueId int NULL,
	LeagueName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Tier int NULL,
	SortOrder int NULL
);

CREATE TABLE Betting.dbo.ParlayBonusAudit (
	ClientIdRef bigint NULL,
	ClientId uniqueidentifier NULL,
	SelectionCount int NULL,
	ParlayBonus decimal(26,12) NULL,
	ParlayBonusMinOdds decimal(26,12) NULL,
	[Timestamp] datetime2 NULL,
	ParlayBonusMaxWinnings decimal(26,12) NULL,
	CurrencyCode nvarchar(30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ID bigint IDENTITY(1,1) NOT NULL
);

CREATE TABLE Betting.dbo.PartialCashoutAudit (
	Id uniqueidentifier NOT NULL,
	BetId uniqueidentifier NOT NULL,
	ClientId nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ClientCode nvarchar(30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	OriginalStake decimal(26,12) NULL,
	StakeUsed decimal(26,12) NULL,
	PreStake decimal(26,12) NULL,
	PostStake decimal(26,12) NULL,
	TrueStake decimal(26,12) NULL,
	TrueStakeUsed decimal(26,12) NULL,
	PreTrueStake decimal(26,12) NULL,
	PostTrueStake decimal(26,12) NULL,
	CashoutPercent decimal(26,12) NULL,
	CashoutAmount decimal(26,12) NULL,
	CashoutDate datetime2 NULL,
	CashoutDateOffset datetime2 NULL,
	TaxedStake decimal(26,12) NULL,
	TaxedWinnings decimal(26,12) NULL,
	NonTaxedPayout decimal(26,12) NULL
);

CREATE TABLE Betting.dbo.StakeLimitFixture (
	UserId nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	FixtureId bigint NULL,
	Remaining decimal(26,12) NULL
);
 CREATE UNIQUE CLUSTERED INDEX StakeLimitFixture_UserId_IDX ON Betting.dbo.StakeLimitFixture (  UserId ASC  , FixtureId ASC  )  
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;

CREATE TABLE Betting.dbo.Tier (
	TierId int NOT NULL,
	MaxStake decimal(30,18) NOT NULL,
	MaxPerGame decimal(30,18) NOT NULL
);

CREATE TABLE Betting.dbo.UserBetConfig (
	ClientId uniqueidentifier NOT NULL,
	UserId nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	CurrencyCode nvarchar(30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	VerticalConfig nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	CreatedDate datetime2 NULL
);
 CREATE UNIQUE CLUSTERED INDEX UserBetConfig_ClientId_IDX ON Betting.dbo.UserBetConfig (  ClientId ASC  , UserId ASC  , CurrencyCode ASC  )  
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;


-- Platform

CREATE TABLE Platform.dbo.Client (
	ClientId uniqueidentifier NOT NULL,
	ClientName nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ClientCode nvarchar(30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	LimitId nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	IsActive bit NOT NULL,
	CurrentCompanyShare decimal(18,2) NULL,
	EffectiveDate datetime2 NULL,
	NextCompanyShare decimal(18,2) NULL,
	Endpoint nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	CreatedDate datetime2 NULL,
	ClientIdRef int NULL,
	MonthlyFee decimal(18,2) NULL,
	IsAgent bit NOT NULL,
	CONSTRAINT pkClientClientId PRIMARY KEY (ClientId)
);

CREATE TABLE Platform.dbo.ConfidenceFactor (
	[Timestamp] bigint NOT NULL,
	UserId nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	CurrentCCF float NULL,
	PreviousCCF float NULL,
	IsSpecificSport bit NOT NULL,
	SportId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SportName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	AppliedTo nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Platform.dbo.ForexEUR (
	CurrencyCode nvarchar(16) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ExchangeRate decimal(26,12) NOT NULL,
	CONSTRAINT ForexEUR_PK PRIMARY KEY (CurrencyCode)
);

CREATE TABLE Platform.dbo.NegativeTest (
	ClientId uniqueidentifier NOT NULL,
	CONSTRAINT PK_NegativeTest PRIMARY KEY (ClientId)
);

CREATE TABLE Platform.dbo.OFOperatorLog (
	Id bigint IDENTITY(1,1) NOT NULL,
	Direction nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ClientId nvarchar(36) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ClientCode nvarchar(16) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	url nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	BetId nvarchar(36) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Info nvarchar(1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	OperatorToken nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
	CorrelationId nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Timestamp] datetime2 NOT NULL,
	CONSTRAINT pkOFOperatorLogId PRIMARY KEY (Id)
);

CREATE TABLE Platform.dbo.OFOperatorSettlementRetry (
	BetId uniqueidentifier NOT NULL,
	ClientId nvarchar(36) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ClientCode nvarchar(16) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Endpoint nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	MessageType nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Info nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	OperatorToken nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
	CorrelationId nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	RetryCount int DEFAULT 0 NOT NULL,
	IsRetry bit NOT NULL,
	IsSuccess bit NOT NULL,
	[Timestamp] datetime2 NOT NULL,
	CONSTRAINT pkOFOperatorSettlementRetryBetId PRIMARY KEY (BetId)
);

CREATE TABLE Platform.dbo.Operator (
	UserId uniqueidentifier NOT NULL,
	OperatorToken nvarchar(100) COLLATE Latin1_General_CI_AS NOT NULL,
	ClientId uniqueidentifier NOT NULL,
	Balance decimal(26,12) NOT NULL,
	CurrencyCode nvarchar(16) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	CreatedDate datetime2 NULL,
	CONSTRAINT Operator_PK PRIMARY KEY (UserId,OperatorToken,ClientId,CurrencyCode)
);

CREATE TABLE Platform.dbo.OperatorAudit (
	UserId uniqueidentifier NULL,
	OperatorToken nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
	ClientId uniqueidentifier NULL,
	BetId uniqueidentifier NULL,
	TransactionTypeId int NULL,
	TransactionTypeName nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	PreBalance decimal(26,12) NULL,
	Amount decimal(26,12) NULL,
	PostBalance decimal(26,12) NULL,
	CurrencyCode nvarchar(16) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	CreatedDate datetime2 NULL,
	TransactionId nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Id bigint IDENTITY(1,1) NOT NULL,
	CONSTRAINT PK_OperatorAudit_ID PRIMARY KEY (Id DESC)
);


CREATE TABLE Platform.dbo.OperatorLog (
	Direction nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ClientId nvarchar(36) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ClientCode nvarchar(16) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	url nvarchar(300) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	BetId nvarchar(36) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Info nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	OperatorToken nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
	CorrelationId nvarchar(40) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Timestamp] datetime2 NOT NULL,
	Id bigint IDENTITY(1,1) NOT NULL,
	CONSTRAINT PK_OperatorLog_Id PRIMARY KEY (Id DESC)
);

CREATE TABLE Platform.dbo.OperatorSettlementRetry (
	BetId uniqueidentifier NOT NULL,
	ClientId nvarchar(36) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientCode nvarchar(16) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Endpoint nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MessageType nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Info nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	OperatorToken nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
	CorrelationId nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	RetryCount int NULL,
	IsRetry bit NOT NULL,
	IsSuccess bit NOT NULL,
	[Timestamp] datetime2 NULL,
	CONSTRAINT pkOperatorSettlementRetryBetId PRIMARY KEY (BetId)
);

CREATE TABLE Platform.dbo.TestConfig (
	ClientId uniqueidentifier NOT NULL,
	IsFreeBet bit NOT NULL,
	StakeRealPercent decimal(26,12) NULL,
	StakeBonusPercent decimal(26,12) NULL
);

CREATE TABLE Platform.dbo.WebSocket (
	ConnectionId nvarchar(40) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	IPAddress nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	IPCountry nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Server nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	UserAgent nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientCode nvarchar(16) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	RequestURL nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ConnectedTimestamp datetime2 NULL,
	DisconnectedTimestamp datetime2 NULL
);


-- Sportsbook

CREATE TABLE Sportsbook.dbo.Announcements (
	Title nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	StartDate datetime2 NULL,
	EndDate datetime2 NULL,
	IsActive bit NOT NULL,
	IsDeleted bit NOT NULL,
	UserId nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	UserRoleId nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	Id int IDENTITY(1,1) NOT NULL,
	CONSTRAINT PK_Announcements PRIMARY KEY (Id)
);

CREATE TABLE Sportsbook.dbo.BetBuilderMarketTemplates (
	SportId int NULL,
	MarketTemplateId nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	Prematch smallint NULL,
	Live smallint NULL
);

CREATE TABLE Sportsbook.dbo.ClientAnnouncements (
	AnnouncementId int NULL,
	ClientId uniqueidentifier NULL,
	ClientCode nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL
);

CREATE TABLE Sportsbook.dbo.ClientLeagueOrder (
	ClientId uniqueidentifier NULL,
	SportId int NULL,
	SportName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SegmentId int NULL,
	SegmentName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	LeagueId int NULL,
	LeagueName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SortOrder int NULL
);

CREATE TABLE Sportsbook.dbo.ClientMarketTemplateGroup (
	ClientId uniqueidentifier NULL,
	SportId int NULL,
	FixtureStatusId int NULL,
	Name nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SortOrder int NULL,
	MarketTemplates nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	IsActive bit NULL,
	Id int IDENTITY(1,1) NOT NULL,
	CONSTRAINT PK_ClientMarketTemplateGroup_Id PRIMARY KEY (Id)
);

CREATE TABLE Sportsbook.dbo.ClientMarketTemplateOrder (
	ClientId uniqueidentifier NULL,
	SportId int NULL,
	MarketTemplateId nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SortOrder int NULL
);

CREATE TABLE Sportsbook.dbo.ClientSegmentLeagueOrder (
	ClientId uniqueidentifier NULL,
	SportId int NULL,
	SportName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SegmentId int NULL,
	SegmentName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	LeagueId int NULL,
	LeagueName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SortOrder int NULL
);

CREATE TABLE Sportsbook.dbo.ClientSegmentOrder (
	ClientId uniqueidentifier NULL,
	SportId int NULL,
	SportName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SegmentId int NULL,
	SegmentName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SortOrder int NULL
);

CREATE TABLE Sportsbook.dbo.ClientSelectorMarketTemplate (
	ClientId uniqueidentifier NULL,
	SportId int NULL,
	MarketTemplateId nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	MarketTemplateCode nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	AsiaSortOrder int NULL,
	EuroSortOrder int NULL,
	Identifier nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL
);

CREATE TABLE Sportsbook.dbo.ClientSelectorMarketTemplate2 (
	ClientId uniqueidentifier NULL,
	SportId int NULL,
	MarketTemplateId nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	MarketTemplateCode nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	AsiaSortOrder int NULL,
	EuroSortOrder int NULL,
	Identifier nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL
);

CREATE TABLE Sportsbook.dbo.ClientSportOrder (
	ClientId uniqueidentifier NULL,
	SportId int NULL,
	SportName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SortOrder int NULL,
	IsActive bit NOT NULL
);

CREATE TABLE Sportsbook.dbo.ClientSportOrderAudit (
	ClientCode nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	ChangesFrom nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	ChangesTo nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	UserId nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	UserName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	[TimeStamp] datetime2 NULL
);

CREATE TABLE Sportsbook.dbo.ClientTopFixture (
	ClientId uniqueidentifier NULL,
	FixtureId bigint NULL,
	SortOrder int NULL
);

CREATE TABLE Sportsbook.dbo.ClientTopLeague (
	ClientId uniqueidentifier NULL,
	SportId int NULL,
	SegmentId int NULL,
	LeagueId int NULL,
	SportName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SegmentName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	LeagueName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SortOrder int NULL
);

CREATE TABLE Sportsbook.dbo.Country (
	Id int NULL,
	Name nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SportSegmentIds nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL
);

CREATE TABLE Sportsbook.dbo.LanguageAnnouncements (
	AnnouncementId int NULL,
	LangCode nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	Description nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL
);

CREATE TABLE Sportsbook.dbo.MarketTemplateGroup (
	SportId int NULL,
	FixtureStatusId int NULL,
	Id int NULL,
	Name nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SortOrder int NULL,
	MarketTemplates nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL
);

CREATE TABLE Sportsbook.dbo.MarketTemplateGroup2 (
	SportId int NULL,
	FixtureStatusId int NULL,
	Name nvarchar(200) COLLATE Latin1_General_CI_AS NULL,
	SortOrder int NULL,
	MarketTemplates nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	ID int IDENTITY(1,1) NOT NULL
);

CREATE TABLE Sportsbook.dbo.MarketTemplateGroupLookup (
	SportId int NULL,
	FixtureStatusId int NULL,
	FixtureStatusName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	MarketTemplateGroupId int NULL,
	MarketTemplateGroupName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	MarketTemplateId int NULL
);

CREATE TABLE Sportsbook.dbo.MarketTemplatePlayerProps (
	SportId int NULL,
	FixtureStatusId int NULL,
	MarketTemplates nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL
);

CREATE TABLE Sportsbook.dbo.SelectorMarketTemplate (
	SportId int NULL,
	MarketTemplateId nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	MarketTemplateCode nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SortOrder int NULL
);

CREATE TABLE Sportsbook.dbo.SelectorMarketTemplate2 (
	SportId int NULL,
	MarketTemplateId nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	MarketTemplateCode nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SortOrder int NULL
);

CREATE TABLE Sportsbook.dbo.SportGroup (
	SportGroupId int NULL,
	SportGroupName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	Sports nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL
);

CREATE TABLE Sportsbook.dbo.SportGroup2 (
	SportGroupId int NULL,
	SportGroupName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	Sports nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL
);

CREATE TABLE Sportsbook.dbo.TempClientSportOrder (
	ClientId uniqueidentifier NULL,
	SportId int NULL,
	SportName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SortOrder int NULL
);

CREATE TABLE Sportsbook.dbo.TierLeagueOrder (
	SportId int NULL,
	SegmentId int NULL,
	LeagueId int NULL,
	SportName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SegmentName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	LeagueName nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	Tier int NULL,
	SortOrder int NULL
);

CREATE TABLE Sportsbook.dbo.UserFavorite (
	UserId nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SportId int NULL,
	Id nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	[HierarchyId] int NULL
);

-- Trading

CREATE TABLE Trading.dbo.ActivityLog (
	Id bigint NULL,
	Page nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Payload nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Activity nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[From] nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[To] nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	UserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[TimeStamp] datetime2 NULL
);

CREATE TABLE Trading.dbo.AspNetRoleClaims (
	Id int NULL,
	RoleId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClaimType nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClaimValue nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Trading.dbo.AspNetRoles (
	Id nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Name nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	NormalizedName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ConcurrencyStamp nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Trading.dbo.AspNetUserClaims (
	Id int NULL,
	UserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClaimType nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClaimValue nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Trading.dbo.AspNetUserLogins (
	LoginProvider nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ProviderKey nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ProviderDisplayName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	UserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Trading.dbo.AspNetUserRoles (
	UserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	RoleId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Trading.dbo.AspNetUserTokens (
	UserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	LoginProvider nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Name nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Value nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Trading.dbo.AspNetUsers (
	Id nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	UserName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	NormalizedUserName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Email nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	NormalizedEmail nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	EmailConfirmed smallint NULL,
	PasswordHash nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SecurityStamp nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ConcurrencyStamp nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	PhoneNumber nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	PhoneNumberConfirmed smallint NULL,
	TwoFactorEnabled smallint NULL,
	LockoutEnd datetimeoffset NULL,
	LockoutEnabled smallint NULL,
	AccessFailedCount int NULL
);

CREATE TABLE Trading.dbo.BoostedSettings (
	ClientId uniqueidentifier NULL,
	ClientName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Cap decimal(9,6) NULL
);

CREATE TABLE Trading.dbo.Client (
	ClientId uniqueidentifier NOT NULL,
	ClientName nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ClientCode nvarchar(40) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Email nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Trading.dbo.ClientLeagueConfig (
	ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SportId int NULL,
	SegmentId int NULL,
	LeagueId int NULL,
	ClientId uniqueidentifier NULL,
	IsActive smallint NULL
);

CREATE TABLE Trading.dbo.ClientLeagueConfig_Temp (
	ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SportId int NULL,
	SegmentId int NULL,
	LeagueId int NULL,
	ClientId uniqueidentifier NULL,
	IsActive smallint NULL
);

CREATE TABLE Trading.dbo.ClientMarketConfig (
	ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SportId int NULL,
	SegmentId int NULL,
	LeagueId int NULL,
	MarketTemplateId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureTypeId int NULL,
	ClientId uniqueidentifier NULL,
	IsActive smallint NULL,
	Prematch nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Live nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Trading.dbo.ClientMarketConfig_Temp (
	ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SportId int NULL,
	SegmentId int NULL,
	LeagueId int NULL,
	MarketTemplateId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureTypeId int NULL,
	ClientId uniqueidentifier NULL,
	IsActive smallint NULL,
	Prematch nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Live nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Trading.dbo.ClientOddsFeedConfiguration (
	ClientId uniqueidentifier NULL,
	SportId int NULL,
	PrematchOdds smallint NULL,
	LiveOdds smallint NULL,
	MaxFixtures int NULL
);

CREATE TABLE Trading.dbo.ClientOddsFeedLiveFixture (
	ClientId uniqueidentifier NULL,
	SportId int NULL,
	FixtureSpecifier nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureStartDate datetime2 NULL
);

CREATE TABLE Trading.dbo.ClientSportOrderAudit (
	ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ChangesFrom nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ChangesTo nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	UserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	UserName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[TimeStamp] datetime2 NULL
);

CREATE TABLE Trading.dbo.ConfigAudit (
	Id int NULL,
	[TimeStamp] datetime2 NULL,
	FixtureTypeId int NULL,
	ClientId uniqueidentifier NULL,
	ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SportsId int NULL,
	SportName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SegmentId int NULL,
	SegmentName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	LeagueId int NULL,
	LeagueName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketTemplateId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketTemplateName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	OldPrematchSettings nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	NewPrematchSettings nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	OldLiveSettings nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	NewLiveSettings nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	OldStatus smallint NULL,
	NewStatus smallint NULL,
	UserId uniqueidentifier NULL,
	Username nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	IsBulkUpload smallint NULL
);

CREATE TABLE Trading.dbo.ManualMarketSettlementAudit (
	SportId int NULL,
	SportName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SegmentId int NULL,
	SegmentName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	LeagueId int NULL,
	LeagueName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureId bigint NULL,
	FixtureName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureTypeId int NULL,
	FixtureTypeName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketTemplateId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketId bigint NULL,
	MarketName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SelectionTemplateId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SelectionId bigint NULL,
	SelectionName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureStatusId int NULL,
	FixtureStatusName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Line nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Odds decimal(26,12) NULL,
	ProviderFixtureId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureSpecifier nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketSpecifier nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SelectionSpecifier nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureStartDate datetime2 NULL,
	SettlementScore nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Probability float NULL,
	WonProbability float NULL,
	LostProbability float NULL,
	VoidProbability float NULL,
	HalfWonProbability float NULL,
	HalfLostProbability float NULL,
	CorrelationId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	DeadHeatFactor decimal(26,12) NULL,
	ManualSettledBy nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[TimeStamp] datetime2 NULL,
	Reason nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ToStatusId int NULL,
	ToStatusName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Id bigint IDENTITY(1,1) NOT NULL,
	CONSTRAINT PK_ManualMarketSettlementAudit PRIMARY KEY (Id)
);

CREATE TABLE Trading.dbo.ManualMessageSettlementAudit (
	Id bigint NULL,
	BetId uniqueidentifier NULL,
	BetDate datetime2 NULL,
	BetSelectionId uniqueidentifier NULL,
	SportId int NULL,
	SportName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SegmentId int NULL,
	LeagueId int NULL,
	FixtureId bigint NULL,
	FixtureName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketTemplateId int NULL,
	InitialBetSelectionStatusId int NULL,
	ProductId int NULL,
	SelectionSpecifier nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	FixtureSpecifier nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	RequestId int NULL,
	NodeId int NULL,
	Reason nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Response nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SettledBy nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[TimeStamp] datetime2 NULL
);

CREATE TABLE Trading.dbo.Notifications (
	Id uniqueidentifier NULL,
	ClaimType nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Page nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SportsId int NULL,
	Details nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	PageRedirect nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	DateCreated datetime2 NULL
);

CREATE TABLE Trading.dbo.NotificationsStatus (
	Id uniqueidentifier NULL,
	UserId uniqueidentifier NULL,
	DateRead datetime2 NULL,
	DateDeleted datetime2 NULL
);

CREATE TABLE Trading.dbo.Permission (
	PermissionId uniqueidentifier NULL,
	Category nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	Name nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClaimType nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	HasReadOnly smallint NULL,
	SortOrder int NULL
);

CREATE TABLE Trading.dbo.PriceBoostConfig (
	ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SportId int NULL,
	SegmentId int NULL,
	LeagueId int NULL,
	FixtureTypeId int NULL,
	ProviderFixtureId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketTemplateId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SelectionTemplateId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SelectionSpecifier nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	BoostedOdds decimal(26,12) NULL,
	UserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	UserName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[TimeStamp] datetime2 NULL,
	BoostedSelectionName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	BoostedSelectionTranslation nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketSpecifier nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Trading.dbo.PriceBoostConfigAudit (
	ClientCode nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SportId int NULL,
	SegmentId int NULL,
	LeagueId int NULL,
	FixtureTypeId int NULL,
	ProviderFixtureId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	MarketTemplateId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SelectionTemplateId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SelectionSpecifier nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	BoostedOdds decimal(26,12) NULL,
	UserId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	UserName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[TimeStamp] datetime2 NULL,
	ChangesMade nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	SportName nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

CREATE TABLE Trading.dbo.UserGroupClients (
	RoleId nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ClientCodes nvarchar(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
);

-- Translation

CREATE TABLE [Translation].dbo.BackofficeStatic (
	LanguageCode nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	Name nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	Value nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL
);

CREATE TABLE [Translation].dbo.SportsbookDynamic (
	ID bigint IDENTITY(1,1) NOT NULL,
	String_ID nvarchar(100) COLLATE Latin1_General_CI_AS NOT NULL,
	SOURCE_LANGUAGE_ID varchar(10) COLLATE Latin1_General_CI_AS NOT NULL,
	TARGET_LANGUAGE_ID varchar(10) COLLATE Latin1_General_CI_AS NOT NULL,
	SOURCE_TEXT nvarchar(MAX) COLLATE Latin1_General_CI_AS NOT NULL,
	TARGET_TEXT nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SOURCE_HASH AS (CONVERT([varchar](64),hashbytes('SHA2_256',[SOURCE_TEXT]),(2))) PERSISTED,
	GLOSSARY_VERSION int DEFAULT 1 NOT NULL,
	CREATED_AT datetime2 DEFAULT getdate() NOT NULL,
	UPDATED_AT datetime2 NULL,
	PROCESSED bit DEFAULT 0 NOT NULL,
	HAS_BET_PLACEMENT bit DEFAULT 0 NOT NULL,
	CONSTRAINT PK_SportsbookDynamic_v2 PRIMARY KEY (ID)
);
 CREATE NONCLUSTERED INDEX IX_SBD_HASH_LANG ON Translation.dbo.SportsbookDynamic (  SOURCE_HASH ASC  , SOURCE_LANGUAGE_ID ASC  , TARGET_LANGUAGE_ID ASC  , GLOSSARY_VERSION ASC  )  
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;
 CREATE NONCLUSTERED INDEX IX_SBD_MISSING ON Translation.dbo.SportsbookDynamic (  TARGET_LANGUAGE_ID ASC  )  
	 INCLUDE ( TARGET_TEXT ) 
	 WHERE  ([TARGET_TEXT] IS NULL)
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;
 CREATE NONCLUSTERED INDEX IX_SBD_PROCESS_QUEUE ON Translation.dbo.SportsbookDynamic (  SOURCE_LANGUAGE_ID ASC  , TARGET_LANGUAGE_ID ASC  )  
	 INCLUDE ( SOURCE_HASH , String_ID ) 
	 WHERE  ([PROCESSED]=(0))
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;
 CREATE NONCLUSTERED INDEX IX_SBD_PROCESS_QUEUE_v2 ON Translation.dbo.SportsbookDynamic (  SOURCE_LANGUAGE_ID ASC  , TARGET_LANGUAGE_ID ASC  , CREATED_AT ASC  , String_ID ASC  )  
	 INCLUDE ( SOURCE_HASH , SOURCE_TEXT ) 
	 WHERE  ([PROCESSED]=(0))
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;
 CREATE UNIQUE NONCLUSTERED INDEX UX_SBD_STRING_LANG ON Translation.dbo.SportsbookDynamic (  String_ID ASC  , TARGET_LANGUAGE_ID ASC  )  
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;

CREATE TABLE [Translation].dbo.SportsbookGlossary (
	ID bigint IDENTITY(1,1) NOT NULL,
	String_ID nvarchar(200) COLLATE Latin1_General_CI_AS NOT NULL,
	SOURCE_LANGUAGE_ID nvarchar(10) COLLATE Latin1_General_CI_AS NOT NULL,
	TARGET_LANGUAGE_ID nvarchar(10) COLLATE Latin1_General_CI_AS NOT NULL,
	SOURCE_TEXT nvarchar(MAX) COLLATE Latin1_General_CI_AS NOT NULL,
	TARGET_TEXT nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	SOURCE_HASH AS (CONVERT([varchar](64),hashbytes('SHA2_256',[SOURCE_TEXT]),(2))) PERSISTED,
	GLOSSARY_VERSION int DEFAULT 1 NOT NULL,
	CREATED_AT datetime DEFAULT getdate() NOT NULL,
	UPDATED_AT datetime NULL,
	PROCESSED bit DEFAULT 0 NOT NULL,
	HAS_BET_PLACEMENT bit DEFAULT 0 NOT NULL,
	CONSTRAINT PK_SportsbookGlossary PRIMARY KEY (ID)
);
 CREATE NONCLUSTERED INDEX IX_SBG_MISSING ON Translation.dbo.SportsbookGlossary (  TARGET_LANGUAGE_ID ASC  )  
	 WHERE  ([TARGET_TEXT] IS NULL)
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;
 CREATE UNIQUE NONCLUSTERED INDEX UX_SBG_STRING_LANG ON Translation.dbo.SportsbookGlossary (  String_ID ASC  , TARGET_LANGUAGE_ID ASC  )  
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;

CREATE TABLE [Translation].dbo.SportsbookStatic (
	LanguageCode nvarchar(10) COLLATE Latin1_General_CI_AS NOT NULL,
	Name nvarchar(200) COLLATE Latin1_General_CI_AS NOT NULL,
	Value nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	CONSTRAINT IX_SportsbookStatic UNIQUE (LanguageCode,Name)
);

CREATE TABLE [Translation].dbo.TranslationCache (
	SOURCE_HASH varchar(64) COLLATE Latin1_General_CI_AS NULL,
	SOURCE_LANGUAGE varchar(10) COLLATE Latin1_General_CI_AS NULL,
	TARGET_LANGUAGE varchar(10) COLLATE Latin1_General_CI_AS NULL,
	SOURCE_TEXT nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	TARGET_TEXT nvarchar(MAX) COLLATE Latin1_General_CI_AS NULL,
	CREATED_AT datetime2 NULL,
	GLOSSARY_VERSION int NULL,
	UPDATED_AT datetime2 NULL
);

CREATE TABLE [Translation].dbo.TranslationCache2 (
	ID bigint IDENTITY(1,1) NOT NULL,
	STRING_ID nvarchar(200) COLLATE Latin1_General_CI_AS NOT NULL,
	SOURCE_LANGUAGE varchar(10) COLLATE Latin1_General_CI_AS NOT NULL,
	SOURCE_TEXT nvarchar(250) COLLATE Latin1_General_CI_AS NOT NULL,
	TARGET_TEXT_ZH nvarchar(250) COLLATE Latin1_General_CI_AS DEFAULT N'' NOT NULL,
	TARGET_TEXT_ES nvarchar(250) COLLATE Latin1_General_CI_AS DEFAULT N'' NOT NULL,
	TARGET_TEXT_FR nvarchar(250) COLLATE Latin1_General_CI_AS DEFAULT N'' NOT NULL,
	HAS_BET_PLACEMENT bit DEFAULT 0 NOT NULL,
	CREATED_AT datetime2 NULL,
	PROCESSED bit DEFAULT 0 NOT NULL,
	UPDATED_AT datetime2 NULL,
	CONSTRAINT PK_TranslationCache2 PRIMARY KEY (ID)
);
 CREATE NONCLUSTERED INDEX IX_TC2_SOURCE_TEXT ON Translation.dbo.TranslationCache2 (  SOURCE_TEXT ASC  , SOURCE_LANGUAGE ASC  )  
	 INCLUDE ( STRING_ID , TARGET_TEXT_ES , TARGET_TEXT_FR , TARGET_TEXT_ZH ) 
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;
 CREATE NONCLUSTERED INDEX IX_TC2_UNPROCESSED ON Translation.dbo.TranslationCache2 (  ID ASC  )  
	 WHERE  ([PROCESSED]=(0))
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;
 CREATE UNIQUE NONCLUSTERED INDEX UX_TC2_STRING ON Translation.dbo.TranslationCache2 (  STRING_ID ASC  )  
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;

-- Wallet

CREATE TABLE Wallet.dbo.UserWallet (
	ClientId uniqueidentifier NOT NULL,
	UserId nvarchar(40) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	Balance decimal(26,12) NOT NULL,
	CurrencyCode nvarchar(16) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
);
 CREATE UNIQUE NONCLUSTERED INDEX UserWallet_ClientId_IDX ON Wallet.dbo.UserWallet (  ClientId ASC  , UserId ASC  , CurrencyCode ASC  )  
	 WITH (  PAD_INDEX = OFF ,FILLFACTOR = 100  ,SORT_IN_TEMPDB = OFF , IGNORE_DUP_KEY = OFF , STATISTICS_NORECOMPUTE = OFF , ONLINE = OFF , ALLOW_ROW_LOCKS = ON , ALLOW_PAGE_LOCKS = ON  )
	 ON [PRIMARY ] ;

CREATE TABLE Wallet.dbo.UserWalletAudit (
	Id bigint NOT NULL,
	ClientId uniqueidentifier NOT NULL,
	UserId nvarchar(40) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	PreBalance decimal(26,12) NULL,
	Amount decimal(26,12) NULL,
	PostBalance decimal(26,12) NULL,
	CurrencyCode nvarchar(30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	TransactionTypeId int NULL,
	TransactionTypeName nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	ReferenceId nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Timestamp] datetime2 NULL
);

CREATE TABLE Wallet.dbo.UserWalletReference (
	ClientId uniqueidentifier NOT NULL,
	UserId nvarchar(40) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	ReferenceId nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	TransactionTypeId int NULL,
	TransactionTypeName nvarchar(40) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Timestamp] datetime2 NULL
);
