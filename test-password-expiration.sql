-- Set trang thai het han mat khau cho tai khoan test1, de test tren giao dien.
-- Chay MOT trong 3 khoi ben duoi (bo comment khoi can dung).
--
-- Mo phong DUNG PasswordExpirationChecker (khong co "grace" nao ca):
--   tuoi mat khau = DATEDIFF(DAY, LastPasswordChangeTime ?? CreationTime, now)
--   @Validity = App.PasswordValidityDays      (mac dinh 90) -> HET HAN, bi chan, ep doi
--   @Request  = App.PasswordChangeRequestDays  (mac dinh 80) -> YEU CAU, nhac nhung van cho vao
--
--   Disabled : @Validity <= 0
--   Expired  : tuoi >= @Validity
--   Warning  : @Request > 0 AND @Request < @Validity AND tuoi >= @Request  (va tuoi < @Validity)
--   Valid    : con lai
--   (FirstLogin: ChangePassWordForLogInNext = 1 duoc kiem TRUOC Expired)
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

-- Doc setting theo dung thu tu uu tien cua ABP: user -> tenant -> application -> default
DECLARE @Validity INT = COALESCE(
    (SELECT TRY_CAST(Value AS INT) FROM AbpSettings
      WHERE Name = 'App.PasswordValidityDays' AND UserId = @UserId),
    (SELECT TRY_CAST(Value AS INT) FROM AbpSettings
      WHERE Name = 'App.PasswordValidityDays' AND TenantId = @TenantId AND UserId IS NULL),
    (SELECT TRY_CAST(Value AS INT) FROM AbpSettings
      WHERE Name = 'App.PasswordValidityDays' AND TenantId IS NULL AND UserId IS NULL),
    90);

DECLARE @Request INT = COALESCE(
    (SELECT TRY_CAST(Value AS INT) FROM AbpSettings
      WHERE Name = 'App.PasswordChangeRequestDays' AND UserId = @UserId),
    (SELECT TRY_CAST(Value AS INT) FROM AbpSettings
      WHERE Name = 'App.PasswordChangeRequestDays' AND TenantId = @TenantId AND UserId IS NULL),
    (SELECT TRY_CAST(Value AS INT) FROM AbpSettings
      WHERE Name = 'App.PasswordChangeRequestDays' AND TenantId IS NULL AND UserId IS NULL),
    80);


-------------------------------------------------------------------------------
-- (1) YEU CAU / CANH BAO: vao duoc app, topbar hien popup "het han sau N ngay"
--     Dat tuoi = @Request + 2, nam giua @Request va @Validity (mac dinh: 82).
-------------------------------------------------------------------------------
UPDATE AbpUsers
SET LastPasswordChangeTime = DATEADD(DAY, -(@Request + 2), GETDATE()),
    ChangePassWordForLogInNext = 0
WHERE Id = @UserId;


-------------------------------------------------------------------------------
-- (2) HET HAN: bi chan tai login, sang trang ForceChangePassword (ly do: Expired)
--     Dat tuoi = @Validity + 1 (mac dinh: 91).
-------------------------------------------------------------------------------
-- UPDATE AbpUsers
-- SET LastPasswordChangeTime = DATEADD(DAY, -(@Validity + 1), GETDATE()),
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
    @Validity AS PasswordValidityDays,
    @Request  AS PasswordChangeRequestDays,
    DATEDIFF(DAY, COALESCE(u.LastPasswordChangeTime, u.CreationTime), GETDATE()) AS PasswordAgeDays,
    CASE
        WHEN @Validity <= 0 THEN 'Disabled - tinh nang tat'
        WHEN u.ChangePassWordForLogInNext = 1 THEN 'Force change (FirstLogin)'
        WHEN DATEDIFF(DAY, COALESCE(u.LastPasswordChangeTime, u.CreationTime), GETDATE()) >= @Validity
            THEN 'Force change (Expired)'
        WHEN @Request > 0 AND @Request < @Validity
             AND DATEDIFF(DAY, COALESCE(u.LastPasswordChangeTime, u.CreationTime), GETDATE()) >= @Request
            THEN 'Warning'
        ELSE 'Valid'
    END AS ExpectedState
FROM AbpUsers u
WHERE u.Id = @UserId;

SELECT * FROM AbpUsers
WHERE UserName = 'kt_hethan';

UPDATE AbpUsers
SET LastPasswordChangeTime = DATEADD(DAY, -(90 + 1), GETDATE()),
    ChangePassWordForLogInNext = 0
WHERE UserName = 'kt_hethan';