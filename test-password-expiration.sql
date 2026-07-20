-- Set trang thai het han mat khau cho tai khoan test1, de test tren giao dien.
-- Chay MOT trong 3 khoi ben duoi (bo comment khoi can dung).
--
-- Luu y: dung GETDATE() chu khong phai GETUTCDATE(), vi Clock.Provider khong duoc
-- cau hinh nen ABP dung gio local cua server.

DECLARE @UserName NVARCHAR(256) = N'test1';

DECLARE @UserId BIGINT, @TenantId INT;
SELECT @UserId = Id, @TenantId = TenantId
FROM AbpUsers WHERE UserName = @UserName;

IF @UserId IS NULL
BEGIN
    RAISERROR('Khong tim thay user %s', 16, 1, @UserName);
    RETURN;
END

-- Doc PasswordExpirationDays theo dung thu tu uu tien cua ABP: user -> tenant -> application -> 90
DECLARE @Days INT = COALESCE(
    (SELECT TRY_CAST(Value AS INT) FROM AbpSettings
      WHERE Name = 'App.PasswordExpirationDays' AND UserId = @UserId),
    (SELECT TRY_CAST(Value AS INT) FROM AbpSettings
      WHERE Name = 'App.PasswordExpirationDays' AND TenantId = @TenantId AND UserId IS NULL),
    (SELECT TRY_CAST(Value AS INT) FROM AbpSettings
      WHERE Name = 'App.PasswordExpirationDays' AND TenantId IS NULL AND UserId IS NULL),
    90);

DECLARE @Grace INT = 5;   -- PasswordExpirationChecker.GraceDays


-------------------------------------------------------------------------------
-- (1) CANH BAO: vao duoc app, topbar hien popup "het han sau 3 ngay"
-------------------------------------------------------------------------------
UPDATE AbpUsers
SET LastPasswordChangeTime = DATEADD(DAY, -(@Days + 2), GETDATE()),
    ChangePassWordForLogInNext = 0
WHERE Id = @UserId;


-------------------------------------------------------------------------------
-- (2) HET HAN: bi chan tai login, sang trang ForceChangePassword (ly do: Expired)
-------------------------------------------------------------------------------
-- UPDATE AbpUsers
-- SET LastPasswordChangeTime = DATEADD(DAY, -(@Days + @Grace + 1), GETDATE()),
--     ChangePassWordForLogInNext = 0
-- WHERE Id = @UserId;


-------------------------------------------------------------------------------
-- (3) BINH THUONG: dang nhap thang, khong canh bao
-------------------------------------------------------------------------------
-- UPDATE AbpUsers
-- SET LastPasswordChangeTime = GETDATE(),
--     ChangePassWordForLogInNext = 0
-- WHERE Id = @UserId;


-- Kiem tra ket qua (mo phong dung logic cua PasswordExpirationChecker)
SELECT
    u.UserName,
    u.LastPasswordChangeTime,
    u.ChangePassWordForLogInNext,
    @Days AS ExpirationDays,
    DATEDIFF(DAY, COALESCE(u.LastPasswordChangeTime, u.CreationTime), GETDATE()) AS PasswordAgeDays,
    CASE
        WHEN @Days <= 0 THEN 'Disabled - tinh nang tat'
        WHEN u.ChangePassWordForLogInNext = 1 THEN 'Force change (FirstLogin)'
        WHEN DATEDIFF(DAY, COALESCE(u.LastPasswordChangeTime, u.CreationTime), GETDATE()) >= @Days + @Grace
            THEN 'Force change (Expired)'
        WHEN DATEDIFF(DAY, COALESCE(u.LastPasswordChangeTime, u.CreationTime), GETDATE()) >= @Days
            THEN 'Warning'
        ELSE 'Valid'
    END AS ExpectedState
FROM AbpUsers u
WHERE u.Id = @UserId;

UPDATE eKMapServer_dev.dbo.AbpUsers
SET LastPasswordChangeTime = GETDATE() - 97
WHERE UserName = 'test1';

------------------------------
