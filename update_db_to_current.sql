-- =============================================================================
-- CẬP NHẬT DB ĐANG CHẠY LÊN SCHEMA HIỆN TẠI
--
-- DB production đã có sẵn và đang chạy => script này CHỈ THÊM, không sửa/xoá gì.
--
-- Delta (những gì code thêm mới, cần đưa vào DB):
--   1. AbpUsers.ChangePassWordForLogInNext      bit NOT NULL   ← KHÔNG có migration
--   2. AbpUsers.LastPasswordChangeTime          datetime2 NULL ← cần BACKFILL
--   3. AbpUsers.LastFailedLoginAttemptTime      datetime2 NULL
--   4. Bảng tenantBranding                      (27 cột)
--   5. 9 row đóng dấu vào __EFMigrationsHistory
--
-- KHÔNG đụng: AbpSettings (chỉ là row key-value, không đổi schema),
--             không ALTER COLUMN, không DROP, không rebuild bảng nào.
--
-- ⚠ KHÔNG chạy `dotnet ef database update` lên DB này: nó sẽ cố thực thi
--   InitialBaseline (1715 dòng CreateTable) và nổ "There is already an object
--   named 'AbpUsers'". Baseline chỉ được ĐÓNG DẤU, không chạy (BƯỚC 1).
--
-- ⚠ ChangePassWordForLogInNext KHÔNG có migration: nó bị nướng thẳng vào
--   InitialBaseline. Vì baseline không chạy => cột này sẽ không bao giờ được
--   tạo nếu chỉ dựa vào EF. AccountController.cs:153 đọc nó ở MỖI lần đăng
--   nhập => thiếu cột là KHÔNG AI ĐĂNG NHẬP ĐƯỢC.
--
-- Idempotent: chạy lại nhiều lần vẫn an toàn (mọi bước đều IF NOT EXISTS).
--
-- CÁCH DÙNG: chạy PHẦN 0 (chỉ đọc) -> backup -> PHẦN 1 -> PHẦN 2.
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- #############################################################################
-- PHẦN 0 — KIỂM TRA (CHỈ ĐỌC, không sửa gì)
-- #############################################################################
PRINT '=== KIỂM TRA ===';
PRINT 'Server : ' + CONVERT(nvarchar(200), @@SERVERNAME);
PRINT 'DB     : ' + DB_NAME();
PRINT 'Edition: ' + CONVERT(nvarchar(100), SERVERPROPERTY('Edition'));

IF OBJECT_ID(N'dbo.AbpUsers') IS NULL
BEGIN
    RAISERROR(N'>>> KHÔNG thấy bảng AbpUsers — SAI DATABASE. Dừng lại.', 16, 1);
    SET NOEXEC ON;
END
GO

SELECT
    Muc = v.Muc,
    TrangThai = CASE WHEN v.CoRoi = 1 THEN N'CÓ RỒI' ELSE N'>>> THIẾU — script sẽ tạo' END
FROM (VALUES
    (N'AbpUsers.ChangePassWordForLogInNext',
     CASE WHEN COL_LENGTH('dbo.AbpUsers','ChangePassWordForLogInNext') IS NULL THEN 0 ELSE 1 END),
    (N'AbpUsers.LastPasswordChangeTime',
     CASE WHEN COL_LENGTH('dbo.AbpUsers','LastPasswordChangeTime') IS NULL THEN 0 ELSE 1 END),
    (N'AbpUsers.LastFailedLoginAttemptTime',
     CASE WHEN COL_LENGTH('dbo.AbpUsers','LastFailedLoginAttemptTime') IS NULL THEN 0 ELSE 1 END),
    (N'bảng tenantBranding',
     CASE WHEN OBJECT_ID(N'dbo.tenantBranding') IS NULL THEN 0 ELSE 1 END),
    (N'bảng __EFMigrationsHistory',
     CASE WHEN OBJECT_ID(N'dbo.__EFMigrationsHistory') IS NULL THEN 0 ELSE 1 END)
) AS v(Muc, CoRoi);

-- Nếu thêm LastPasswordChangeTime mà KHÔNG backfill thì bấy nhiêu user này
-- sẽ bị ép đổi mật khẩu ngay lần đăng nhập kế tiếp (xem BƯỚC 4).
IF COL_LENGTH('dbo.AbpUsers','LastPasswordChangeTime') IS NULL
    SELECT N'Số user bị ép đổi mật khẩu NẾU không backfill' AS CanhBao,
           COUNT(*) AS SoUser
    FROM dbo.AbpUsers
    WHERE DATEDIFF(DAY, CreationTime, GETDATE()) >= 90;
GO


-- #############################################################################
-- PHẦN 1 — CẬP NHẬT
-- #############################################################################
BEGIN TRANSACTION;
BEGIN TRY

-- =============================================================================
-- BƯỚC 1 — Đóng dấu InitialBaseline (KHÔNG chạy nội dung)
--   DB vốn đã có sẵn toàn bộ schema của baseline. Chỉ ghi sổ để EF biết.
-- =============================================================================
IF OBJECT_ID(N'dbo.__EFMigrationsHistory') IS NULL
    CREATE TABLE dbo.__EFMigrationsHistory
    (
        MigrationId    nvarchar(150) NOT NULL,
        ProductVersion nvarchar(32)  NOT NULL,
        CONSTRAINT PK___EFMigrationsHistory PRIMARY KEY (MigrationId)
    );

IF NOT EXISTS (SELECT 1 FROM dbo.__EFMigrationsHistory
               WHERE MigrationId = N'20260602080713_InitialBaseline')
    INSERT INTO dbo.__EFMigrationsHistory (MigrationId, ProductVersion)
    VALUES (N'20260602080713_InitialBaseline', N'5.0.0');

PRINT '[1] Đã đóng dấu InitialBaseline.';

-- =============================================================================
-- BƯỚC 2 — AbpUsers.ChangePassWordForLogInNext   ★ KHÔNG CÓ MIGRATION ★
--   DEFAULT 0: user hiện có đang dùng hệ thống bình thường, không ép ai đổi
--   mật khẩu. Chỉ user tạo mới với cờ = 1 mới bị ép (AccountController.cs:153).
-- =============================================================================
IF COL_LENGTH('dbo.AbpUsers', 'ChangePassWordForLogInNext') IS NULL
BEGIN
    ALTER TABLE dbo.AbpUsers
        ADD ChangePassWordForLogInNext bit NOT NULL
            CONSTRAINT DF_AbpUsers_ChangePassWordForLogInNext DEFAULT (0);
    PRINT '[2] Đã thêm ChangePassWordForLogInNext (DEFAULT 0 — không ép ai đổi mật khẩu).';
END
ELSE PRINT '[2] ChangePassWordForLogInNext đã có — bỏ qua.';

-- =============================================================================
-- BƯỚC 3 — AbpUsers.LastPasswordChangeTime   ⚠ PHẢI BACKFILL
--
--   PasswordExpirationChecker.cs:37
--       ageDays = Clock.Now - (user.LastPasswordChangeTime ?? user.CreationTime)
--
--   NULL => rơi về CreationTime. Mặc định hết hạn 90 ngày và BẬT sẵn
--   (AppSettingProvider.cs:65) => user cũ bị Expired ngay => ép đổi mật khẩu
--   hàng loạt. Backfill = GETDATE(): coi như vừa đổi lúc nâng cấp.
--
--   GETDATE() chứ KHÔNG phải GETUTCDATE(): repo không cấu hình Clock.Provider
--   => ABP dùng ClockProviders.Unspecified => Clock.Now = DateTime.Now = giờ
--   LOCAL của server. Backfill bằng UTC sẽ lệch 7 giờ.
--
--   Chỉ backfill đúng lúc cột được tạo => chạy lại không đè lên dữ liệu thật.
-- =============================================================================
IF COL_LENGTH('dbo.AbpUsers', 'LastPasswordChangeTime') IS NULL
BEGIN
    ALTER TABLE dbo.AbpUsers ADD LastPasswordChangeTime datetime2 NULL;

    -- Cột vừa thêm không tham chiếu được trong cùng batch => bọc EXEC.
    EXEC(N'UPDATE dbo.AbpUsers
             SET LastPasswordChangeTime = GETDATE()
           WHERE LastPasswordChangeTime IS NULL;');

    PRINT '[3] Đã thêm LastPasswordChangeTime + BACKFILL GETDATE() cho toàn bộ user.';
END
ELSE PRINT '[3] LastPasswordChangeTime đã có — bỏ qua (không đè lên dữ liệu thật).';

-- =============================================================================
-- BƯỚC 4 — AbpUsers.LastFailedLoginAttemptTime
--   Không backfill: NULL chính là trạng thái đúng ("chưa sai lần nào").
--   UserManager.cs:69 chặn bằng .HasValue; dòng 80 set NULL khi đăng nhập đúng.
-- =============================================================================
IF COL_LENGTH('dbo.AbpUsers', 'LastFailedLoginAttemptTime') IS NULL
BEGIN
    ALTER TABLE dbo.AbpUsers ADD LastFailedLoginAttemptTime datetime2 NULL;
    PRINT '[4] Đã thêm LastFailedLoginAttemptTime.';
END
ELSE PRINT '[4] LastFailedLoginAttemptTime đã có — bỏ qua.';

-- =============================================================================
-- BƯỚC 5 — Bảng tenantBranding (gộp 6 migration branding, tạo thẳng trạng thái cuối)
--   Bảng mới hoàn toàn => không đụng dữ liệu đang chạy.
-- =============================================================================
IF OBJECT_ID(N'dbo.tenantBranding') IS NULL
BEGIN
    CREATE TABLE dbo.tenantBranding
    (
        Id                   int             IDENTITY(1,1) NOT NULL,
        TenantId             int             NULL,
        CompanyName          nvarchar(200)   NULL,

        LogoUrl              nvarchar(500)   NULL,
        FaviconUrl           nvarchar(500)   NULL,
        LoginBackgroundUrl   nvarchar(500)   NULL,

        LogoStyle            nvarchar(500)   NULL,
        FaviconStyle         nvarchar(500)   NULL,
        LoginBackgroundStyle nvarchar(500)   NULL,

        LogoClass            nvarchar(500)   NULL,
        FaviconClass         nvarchar(500)   NULL,
        LoginBackgroundClass nvarchar(500)   NULL,

        Slogan               nvarchar(1000)  NULL,
        SloganStyle          nvarchar(500)   NULL,
        SloganClass          nvarchar(500)   NULL,

        ReverseLayout        bit             NOT NULL CONSTRAINT DF_tenantBranding_ReverseLayout DEFAULT (0),
        FormOnly             bit             NOT NULL CONSTRAINT DF_tenantBranding_FormOnly      DEFAULT (0),

        PrimaryColor         nvarchar(20)    NULL,
        SecondaryColor       nvarchar(20)    NULL,
        FontFamily           nvarchar(100)   NULL,

        -- FullAuditedEntity
        CreationTime         datetime2       NOT NULL,
        CreatorUserId        bigint          NULL,
        LastModificationTime datetime2       NULL,
        LastModifierUserId   bigint          NULL,
        IsDeleted            bit             NOT NULL,
        DeleterUserId        bigint          NULL,
        DeletionTime         datetime2       NULL,

        CONSTRAINT PK_tenantBranding PRIMARY KEY (Id)
    );
    PRINT '[5] Đã tạo bảng tenantBranding (27 cột).';
END
ELSE PRINT '[5] tenantBranding đã có — bỏ qua.';

-- =============================================================================
-- BƯỚC 6 — Đóng dấu 8 migration còn lại
--   Sau bước này `dotnet ef database update` sẽ báo "already up to date".
-- =============================================================================
DECLARE @applied TABLE (MigrationId nvarchar(150));
INSERT INTO @applied (MigrationId) VALUES
    (N'20260708031832_Tenant_Branding'),
    (N'20260708064908_Add_Logo_Layout'),
    (N'20260708071136_Add_Logo_Class'),
    (N'20260708072142_Add_Slogan'),
    (N'20260708095623_Add_Reverse_Layout'),
    (N'20260709021823_Add_FormOnly'),
    (N'20260714025730_Add_LastPasswordChangeTime'),
    (N'20260715022326_Add_LastFailedLoginAttemptTime');

INSERT INTO dbo.__EFMigrationsHistory (MigrationId, ProductVersion)
SELECT a.MigrationId, N'5.0.0'
FROM @applied a
WHERE NOT EXISTS (SELECT 1 FROM dbo.__EFMigrationsHistory h
                  WHERE h.MigrationId = a.MigrationId);

PRINT '[6] Đã đóng dấu ' + CONVERT(nvarchar(10), @@ROWCOUNT) + ' migration.';

COMMIT TRANSACTION;
PRINT '=== HOÀN TẤT — ĐÃ COMMIT ===';

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    PRINT '=== LỖI — ĐÃ ROLLBACK, DB KHÔNG ĐỔI GÌ ===';
    PRINT 'Dòng     : ' + CONVERT(nvarchar(10), ERROR_LINE());
    PRINT 'Thông báo: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO


-- #############################################################################
-- PHẦN 2 — HẬU KIỂM
-- #############################################################################

-- 1) Phải đủ 9 row
SELECT MigrationId FROM dbo.__EFMigrationsHistory ORDER BY MigrationId;

-- 2) tenantBranding phải đủ 27 cột
SELECT COUNT(*) AS TenantBranding_SoCot_PhaiLa27
FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.tenantBranding');

-- 3) ⚠ QUAN TRỌNG NHẤT — cả hai phải bằng 0
SELECT
    (SELECT COUNT(*) FROM dbo.AbpUsers WHERE LastPasswordChangeTime IS NULL)
        AS User_NULL_LastPasswordChangeTime_PhaiLa0,
    (SELECT COUNT(*) FROM dbo.AbpUsers WHERE ChangePassWordForLogInNext = 1)
        AS User_BiEpDoiMatKhau_PhaiLa0;
GO

SET NOEXEC OFF;
GO
