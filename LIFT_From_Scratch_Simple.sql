/* Create the complete LIFT database from scratch. Run once in SSMS. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE DATABASE LIFT;
GO
USE LIFT;
GO

CREATE TABLE dbo.Users (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_Users PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    FullName nvarchar(120) NOT NULL,
    Email nvarchar(256) NOT NULL,
    PasswordHash nvarchar(500) NOT NULL,
    Role varchar(20) NOT NULL,
    Status varchar(20) NOT NULL CONSTRAINT DF_Users_Status DEFAULT 'active',
    Phone nvarchar(30) NULL,
    PhotoUrl nvarchar(1000) NULL,
    CreatedAt datetimeoffset NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT CK_Users_Role CHECK (Role IN ('client','coach','nutritionist','admin')),
    CONSTRAINT CK_Users_Status CHECK (Status IN ('active','pending','suspended','blocked','rejected'))
);

CREATE TABLE dbo.ClientProfiles (
    UserId uniqueidentifier NOT NULL CONSTRAINT PK_ClientProfiles PRIMARY KEY,
    Goal nvarchar(100) NULL, GoalNote nvarchar(500) NULL,
    BirthDate date NULL, HeightCm decimal(5,2) NULL, StartingWeightKg decimal(5,2) NULL,
    FitnessLevel nvarchar(40) NULL, ActivityLevel nvarchar(40) NULL,
    TrainingLocation nvarchar(40) NULL, SessionMinutes smallint NULL,
    PreferredTrainingTime nvarchar(40) NULL, SleepHours decimal(3,1) NULL,
    ScheduleNotes nvarchar(500) NULL, HealthNotes nvarchar(1000) NULL,
    FoodHabits nvarchar(500) NULL, DietaryPreferences nvarchar(500) NULL,
    CookingStyle nvarchar(40) NULL, Sport nvarchar(80) NULL,
    ProfileCompletedAt datetimeoffset NULL, UpdatedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT FK_ClientProfiles_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_ClientProfiles_Height CHECK (HeightCm IS NULL OR HeightCm BETWEEN 80 AND 250),
    CONSTRAINT CK_ClientProfiles_Weight CHECK (StartingWeightKg IS NULL OR StartingWeightKg BETWEEN 20 AND 500)
);

CREATE TABLE dbo.ClientTrainingDays (
    ClientId uniqueidentifier NOT NULL, DayOfWeek tinyint NOT NULL,
    CONSTRAINT PK_ClientTrainingDays PRIMARY KEY (ClientId, DayOfWeek),
    CONSTRAINT FK_ClientTrainingDays_ClientProfiles FOREIGN KEY (ClientId) REFERENCES dbo.ClientProfiles(UserId),
    CONSTRAINT CK_ClientTrainingDays_Day CHECK (DayOfWeek BETWEEN 1 AND 7)
);

CREATE TABLE dbo.SpecialistProfiles (
    UserId uniqueidentifier NOT NULL CONSTRAINT PK_SpecialistProfiles PRIMARY KEY,
    Specialty nvarchar(120) NOT NULL, Bio nvarchar(1000) NULL,
    ExperienceYears tinyint NULL, Capacity smallint NOT NULL DEFAULT 8,
    AcceptingNewClients bit NOT NULL DEFAULT 1,
    GoalsJson nvarchar(max) NULL, SportsJson nvarchar(max) NULL,
    TrainingLevelsJson nvarchar(max) NULL, LocationsJson nvarchar(max) NULL,
    DurationsJson nvarchar(max) NULL, CookingStylesJson nvarchar(max) NULL,
    ApprovedAt datetimeoffset NULL, ReviewedBy uniqueidentifier NULL,
    CONSTRAINT FK_SpecialistProfiles_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_SpecialistProfiles_Reviewer FOREIGN KEY (ReviewedBy) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_SpecialistProfiles_Capacity CHECK (Capacity BETWEEN 1 AND 8),
    CONSTRAINT CK_SpecialistProfiles_GoalsJson CHECK (GoalsJson IS NULL OR ISJSON(GoalsJson) = 1),
    CONSTRAINT CK_SpecialistProfiles_SportsJson CHECK (SportsJson IS NULL OR ISJSON(SportsJson) = 1)
);

CREATE TABLE dbo.SpecialistCertificates (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_SpecialistCertificates PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    SpecialistId uniqueidentifier NOT NULL, OriginalFileName nvarchar(255) NOT NULL,
    StorageKey nvarchar(1000) NOT NULL, UploadedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT FK_SpecialistCertificates_Specialist FOREIGN KEY (SpecialistId) REFERENCES dbo.SpecialistProfiles(UserId)
);

CREATE TABLE dbo.SubscriptionPlans (
    Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_SubscriptionPlans PRIMARY KEY,
    Code varchar(20) NOT NULL CONSTRAINT UQ_SubscriptionPlans_Code UNIQUE,
    Name nvarchar(80) NOT NULL, MonthlyPrice decimal(10,2) NOT NULL,
    IsActive bit NOT NULL DEFAULT 1,
    CONSTRAINT CK_SubscriptionPlans_Price CHECK (MonthlyPrice >= 0)
);

INSERT dbo.SubscriptionPlans (Code, Name, MonthlyPrice) VALUES
('free', N'Free Plan', 0),
('ai_coach', N'AI + Coach', 24.99),
('ai_nutritionist', N'AI + Nutritionist', 24.99),
('premium', N'Premium', 39.99);

CREATE TABLE dbo.PromoCodes (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_PromoCodes PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    Code nvarchar(50) NOT NULL CONSTRAINT UQ_PromoCodes_Code UNIQUE,
    DiscountPercent decimal(5,2) NOT NULL, IsActive bit NOT NULL DEFAULT 1,
    StartsAt datetimeoffset NULL, EndsAt datetimeoffset NULL,
    CONSTRAINT CK_PromoCodes_Discount CHECK (DiscountPercent BETWEEN 0 AND 100),
    CONSTRAINT CK_PromoCodes_Dates CHECK (EndsAt IS NULL OR StartsAt IS NULL OR EndsAt > StartsAt)
);

CREATE TABLE dbo.PromoCodePlans (
    PromoCodeId uniqueidentifier NOT NULL, PlanId int NOT NULL,
    CONSTRAINT PK_PromoCodePlans PRIMARY KEY (PromoCodeId, PlanId),
    CONSTRAINT FK_PromoCodePlans_Promo FOREIGN KEY (PromoCodeId) REFERENCES dbo.PromoCodes(Id),
    CONSTRAINT FK_PromoCodePlans_Plan FOREIGN KEY (PlanId) REFERENCES dbo.SubscriptionPlans(Id)
);

CREATE TABLE dbo.Subscriptions (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_Subscriptions PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    ClientId uniqueidentifier NOT NULL, PlanId int NOT NULL, PromoCodeId uniqueidentifier NULL,
    Status varchar(20) NOT NULL DEFAULT 'active',
    PriceAtStart decimal(10,2) NOT NULL, Currency char(3) NOT NULL DEFAULT 'USD',
    StartsAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(), EndsAt datetimeoffset NULL,
    ExternalBillingId nvarchar(200) NULL,
    CONSTRAINT FK_Subscriptions_Client FOREIGN KEY (ClientId) REFERENCES dbo.ClientProfiles(UserId),
    CONSTRAINT FK_Subscriptions_Plan FOREIGN KEY (PlanId) REFERENCES dbo.SubscriptionPlans(Id),
    CONSTRAINT FK_Subscriptions_Promo FOREIGN KEY (PromoCodeId) REFERENCES dbo.PromoCodes(Id),
    CONSTRAINT CK_Subscriptions_Status CHECK (Status IN ('active','pending','cancelled','expired')),
    CONSTRAINT CK_Subscriptions_Price CHECK (PriceAtStart >= 0),
    CONSTRAINT CK_Subscriptions_Dates CHECK (EndsAt IS NULL OR EndsAt > StartsAt)
);
CREATE UNIQUE INDEX UX_Subscriptions_IdClient ON dbo.Subscriptions(Id, ClientId);
CREATE UNIQUE INDEX UX_Subscriptions_OneActive ON dbo.Subscriptions(ClientId) WHERE Status = 'active';

-- Save the client's specialist choices while the subscription is pending.
-- Paid subscriptions become active only after payment succeeds and all required
-- choices are still available. Free subscriptions require no choices or payment.
CREATE TABLE dbo.SubscriptionSpecialistSelections (
    SubscriptionId uniqueidentifier NOT NULL,
    SpecialistRole varchar(20) NOT NULL,
    SpecialistId uniqueidentifier NOT NULL,
    SelectedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_SubscriptionSpecialistSelections PRIMARY KEY (SubscriptionId, SpecialistRole),
    CONSTRAINT FK_Selections_Subscription FOREIGN KEY (SubscriptionId) REFERENCES dbo.Subscriptions(Id),
    CONSTRAINT FK_Selections_Specialist FOREIGN KEY (SpecialistId) REFERENCES dbo.SpecialistProfiles(UserId),
    CONSTRAINT CK_Selections_Role CHECK (SpecialistRole IN ('coach','nutritionist'))
);
CREATE INDEX IX_Selections_Specialist ON dbo.SubscriptionSpecialistSelections(SpecialistId);

CREATE TABLE dbo.SpecialistAssignments (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_SpecialistAssignments PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    ClientId uniqueidentifier NOT NULL, SubscriptionId uniqueidentifier NOT NULL,
    SpecialistId uniqueidentifier NOT NULL,
    SpecialistRole varchar(20) NOT NULL, Status varchar(20) NOT NULL DEFAULT 'active',
    AssignedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    EndedAt datetimeoffset NULL,
    CONSTRAINT FK_Assignments_Client FOREIGN KEY (ClientId) REFERENCES dbo.ClientProfiles(UserId),
    CONSTRAINT FK_Assignments_Subscription FOREIGN KEY (SubscriptionId) REFERENCES dbo.Subscriptions(Id),
    CONSTRAINT FK_Assignments_SubscriptionClient FOREIGN KEY (SubscriptionId, ClientId)
        REFERENCES dbo.Subscriptions(Id, ClientId),
    CONSTRAINT FK_Assignments_Specialist FOREIGN KEY (SpecialistId) REFERENCES dbo.SpecialistProfiles(UserId),
    CONSTRAINT CK_Assignments_Role CHECK (SpecialistRole IN ('coach','nutritionist')),
    CONSTRAINT CK_Assignments_Status CHECK (Status IN ('pending','active','ended'))
);
CREATE UNIQUE INDEX UX_Assignments_ActiveRole ON dbo.SpecialistAssignments(ClientId, SpecialistRole) WHERE Status = 'active';
CREATE INDEX IX_Assignments_Specialist ON dbo.SpecialistAssignments(SpecialistId, Status);
GO

-- The application checks specialist availability before activating an assignment.

CREATE TABLE dbo.SpecialistChangeRequests (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_SpecialistChangeRequests PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    AssignmentId uniqueidentifier NOT NULL,
    ClientId uniqueidentifier NOT NULL,
    Reason nvarchar(1000) NOT NULL,
    Status varchar(20) NOT NULL DEFAULT 'pending',
    RequestedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    ReviewedBy uniqueidentifier NULL,
    ReviewedAt datetimeoffset NULL,
    AdminNote nvarchar(1000) NULL,
    ReplacementAssignmentId uniqueidentifier NULL,
    CONSTRAINT FK_ChangeRequests_Assignment FOREIGN KEY (AssignmentId) REFERENCES dbo.SpecialistAssignments(Id),
    CONSTRAINT FK_ChangeRequests_Client FOREIGN KEY (ClientId) REFERENCES dbo.ClientProfiles(UserId),
    CONSTRAINT FK_ChangeRequests_Reviewer FOREIGN KEY (ReviewedBy) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_ChangeRequests_Replacement FOREIGN KEY (ReplacementAssignmentId) REFERENCES dbo.SpecialistAssignments(Id),
    CONSTRAINT CK_ChangeRequests_Status CHECK (Status IN ('pending','completed','declined','cancelled')),
    CONSTRAINT CK_ChangeRequests_Reason CHECK (LEN(TRIM(Reason)) > 0)
);
CREATE UNIQUE INDEX UX_ChangeRequests_OnePending ON dbo.SpecialistChangeRequests(AssignmentId) WHERE Status = 'pending';

-- Ratings belong to a real client-specialist assignment, including ended ones.
CREATE TABLE dbo.SpecialistReviews (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_SpecialistReviews PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    AssignmentId uniqueidentifier NOT NULL CONSTRAINT UQ_SpecialistReviews_Assignment UNIQUE,
    Rating tinyint NOT NULL,
    Comment nvarchar(1000) NULL,
    CreatedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt datetimeoffset NULL,
    CONSTRAINT FK_SpecialistReviews_Assignment FOREIGN KEY (AssignmentId) REFERENCES dbo.SpecialistAssignments(Id),
    CONSTRAINT CK_SpecialistReviews_Rating CHECK (Rating BETWEEN 1 AND 5)
);

CREATE TABLE dbo.PlanVersions (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_PlanVersions PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    ClientId uniqueidentifier NOT NULL, PlanType varchar(20) NOT NULL,
    VersionNumber int NOT NULL, Source varchar(20) NOT NULL,
    CreatedBy uniqueidentifier NULL, ReviewedBy uniqueidentifier NULL,
    Status varchar(20) NOT NULL DEFAULT 'draft',
    Title nvarchar(200) NULL, Notes nvarchar(2000) NULL,
    Calories int NULL, ProteinGrams decimal(7,2) NULL,
    CarbsGrams decimal(7,2) NULL, FatGrams decimal(7,2) NULL,
    CreatedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    ApprovedAt datetimeoffset NULL, PublishedAt datetimeoffset NULL,
    CONSTRAINT FK_PlanVersions_Client FOREIGN KEY (ClientId) REFERENCES dbo.ClientProfiles(UserId),
    CONSTRAINT FK_PlanVersions_Creator FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_PlanVersions_Reviewer FOREIGN KEY (ReviewedBy) REFERENCES dbo.Users(Id),
    CONSTRAINT UQ_PlanVersions_Version UNIQUE (ClientId, PlanType, VersionNumber),
    CONSTRAINT CK_PlanVersions_Type CHECK (PlanType IN ('workout','nutrition')),
    CONSTRAINT CK_PlanVersions_Source CHECK (Source IN ('ai','specialist')),
    CONSTRAINT CK_PlanVersions_Status CHECK (Status IN ('draft','pending_review','approved','rejected')),
    CONSTRAINT CK_PlanVersions_VersionNumber CHECK (VersionNumber > 0)
);
CREATE INDEX IX_PlanVersions_ClientStatus ON dbo.PlanVersions(ClientId, PlanType, Status, PublishedAt DESC);

CREATE TABLE dbo.WorkoutPlanItems (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_WorkoutPlanItems PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    PlanVersionId uniqueidentifier NOT NULL, DayOfWeek tinyint NOT NULL,
    SortOrder smallint NOT NULL, ExerciseName nvarchar(160) NOT NULL,
    Sets smallint NULL, Reps nvarchar(50) NULL, DurationMinutes smallint NULL,
    Instructions nvarchar(1000) NULL,
    CONSTRAINT FK_WorkoutPlanItems_Plan FOREIGN KEY (PlanVersionId) REFERENCES dbo.PlanVersions(Id),
    CONSTRAINT CK_WorkoutPlanItems_Day CHECK (DayOfWeek BETWEEN 1 AND 7)
);

CREATE TABLE dbo.NutritionPlanMeals (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_NutritionPlanMeals PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    PlanVersionId uniqueidentifier NOT NULL, SortOrder smallint NOT NULL,
    MealName nvarchar(100) NOT NULL, Description nvarchar(1000) NULL,
    CONSTRAINT FK_NutritionPlanMeals_Plan FOREIGN KEY (PlanVersionId) REFERENCES dbo.PlanVersions(Id)
);

CREATE TABLE dbo.ActivityLogs (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_ActivityLogs PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    ClientId uniqueidentifier NOT NULL, PlanItemId uniqueidentifier NULL,
    ActivityType varchar(20) NOT NULL, ActivityDate date NOT NULL,
    Label nvarchar(200) NULL, CompletedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT FK_ActivityLogs_Client FOREIGN KEY (ClientId) REFERENCES dbo.ClientProfiles(UserId),
    CONSTRAINT CK_ActivityLogs_Type CHECK (ActivityType IN ('workout','meal','other'))
);
CREATE INDEX IX_ActivityLogs_ClientDate ON dbo.ActivityLogs(ClientId, ActivityDate DESC);

CREATE TABLE dbo.Measurements (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_Measurements PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    ClientId uniqueidentifier NOT NULL, RecordedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    WeightKg decimal(5,2) NOT NULL, BodyFatPercent decimal(5,2) NULL,
    MusclePercent decimal(5,2) NULL,
    CONSTRAINT FK_Measurements_Client FOREIGN KEY (ClientId) REFERENCES dbo.ClientProfiles(UserId),
    CONSTRAINT CK_Measurements_Weight CHECK (WeightKg BETWEEN 20 AND 500),
    CONSTRAINT CK_Measurements_Fat CHECK (BodyFatPercent IS NULL OR BodyFatPercent BETWEEN 0 AND 100),
    CONSTRAINT CK_Measurements_Muscle CHECK (MusclePercent IS NULL OR MusclePercent BETWEEN 0 AND 100)
);

CREATE TABLE dbo.Conversations (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_Conversations PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    Kind varchar(20) NOT NULL, Subject nvarchar(200) NULL,
    Status varchar(20) NOT NULL DEFAULT 'open',
    CreatedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT CK_Conversations_Kind CHECK (Kind IN ('coach','nutritionist','support')),
    CONSTRAINT CK_Conversations_Status CHECK (Status IN ('open','closed'))
);

CREATE TABLE dbo.ConversationParticipants (
    ConversationId uniqueidentifier NOT NULL, UserId uniqueidentifier NOT NULL,
    LastReadAt datetimeoffset NULL,
    CONSTRAINT PK_ConversationParticipants PRIMARY KEY (ConversationId, UserId),
    CONSTRAINT FK_ConversationParticipants_Conversation FOREIGN KEY (ConversationId) REFERENCES dbo.Conversations(Id),
    CONSTRAINT FK_ConversationParticipants_User FOREIGN KEY (UserId) REFERENCES dbo.Users(Id)
);

CREATE TABLE dbo.Messages (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_Messages PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    ConversationId uniqueidentifier NOT NULL, SenderId uniqueidentifier NOT NULL,
    Body nvarchar(max) NOT NULL, SentAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT FK_Messages_Conversation FOREIGN KEY (ConversationId) REFERENCES dbo.Conversations(Id),
    CONSTRAINT FK_Messages_Participant FOREIGN KEY (ConversationId, SenderId)
        REFERENCES dbo.ConversationParticipants(ConversationId, UserId),
    CONSTRAINT CK_Messages_Body CHECK (LEN(Body) BETWEEN 1 AND 4000)
);
CREATE INDEX IX_Messages_ConversationSent ON dbo.Messages(ConversationId, SentAt DESC);

CREATE TABLE dbo.MessageAttachments (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_MessageAttachments PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    MessageId uniqueidentifier NOT NULL, OriginalFileName nvarchar(255) NOT NULL,
    StorageKey nvarchar(1000) NOT NULL, ContentType nvarchar(100) NOT NULL,
    CONSTRAINT FK_MessageAttachments_Message FOREIGN KEY (MessageId) REFERENCES dbo.Messages(Id)
);

CREATE TABLE dbo.AiConversations (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_AiConversations PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    ClientId uniqueidentifier NOT NULL, Title nvarchar(200) NULL,
    CreatedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT FK_AiConversations_Client FOREIGN KEY (ClientId) REFERENCES dbo.ClientProfiles(UserId)
);

CREATE TABLE dbo.AiMessages (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_AiMessages PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    ConversationId uniqueidentifier NOT NULL, Role varchar(20) NOT NULL,
    Body nvarchar(max) NOT NULL, ModelName nvarchar(100) NULL,
    CreatedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT FK_AiMessages_Conversation FOREIGN KEY (ConversationId) REFERENCES dbo.AiConversations(Id),
    CONSTRAINT CK_AiMessages_Role CHECK (Role IN ('user','assistant','system'))
);
CREATE INDEX IX_AiMessages_ConversationTime ON dbo.AiMessages(ConversationId, CreatedAt);

CREATE TABLE dbo.AiPlanGenerations (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_AiPlanGenerations PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    ClientId uniqueidentifier NOT NULL, ConversationId uniqueidentifier NULL,
    PlanVersionId uniqueidentifier NULL, PlanType varchar(20) NOT NULL,
    Status varchar(20) NOT NULL DEFAULT 'pending', ModelName nvarchar(100) NULL,
    ErrorMessage nvarchar(1000) NULL,
    RequestedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CompletedAt datetimeoffset NULL,
    CONSTRAINT FK_AiPlanGenerations_Client FOREIGN KEY (ClientId) REFERENCES dbo.ClientProfiles(UserId),
    CONSTRAINT FK_AiPlanGenerations_Conversation FOREIGN KEY (ConversationId) REFERENCES dbo.AiConversations(Id),
    CONSTRAINT FK_AiPlanGenerations_PlanVersion FOREIGN KEY (PlanVersionId) REFERENCES dbo.PlanVersions(Id),
    CONSTRAINT CK_AiPlanGenerations_Type CHECK (PlanType IN ('workout','nutrition')),
    CONSTRAINT CK_AiPlanGenerations_Status CHECK (Status IN ('pending','completed','failed'))
);

CREATE TABLE dbo.Meetings (
    Id uniqueidentifier NOT NULL CONSTRAINT PK_Meetings PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    ClientId uniqueidentifier NOT NULL, SpecialistId uniqueidentifier NOT NULL,
    Topic nvarchar(200) NOT NULL, StartsAt datetimeoffset NOT NULL,
    DurationMinutes smallint NOT NULL, Status varchar(20) NOT NULL DEFAULT 'pending',
    MeetingUrl nvarchar(1000) NULL, CreatedAt datetimeoffset NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT FK_Meetings_Client FOREIGN KEY (ClientId) REFERENCES dbo.ClientProfiles(UserId),
    CONSTRAINT FK_Meetings_Specialist FOREIGN KEY (SpecialistId) REFERENCES dbo.SpecialistProfiles(UserId),
    CONSTRAINT CK_Meetings_Status CHECK (Status IN ('pending','accepted','declined','cancelled','completed')),
    CONSTRAINT CK_Meetings_Duration CHECK (DurationMinutes BETWEEN 15 AND 180)
);


