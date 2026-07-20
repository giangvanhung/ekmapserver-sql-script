-- =============================================
-- BƯỚC 1: Insert data gốc
--   LogoClass = 'max-h-90px' để trông y như mặc định hiện tại.
--   Các cột Style/Class khác để rỗng.
-- =============================================
INSERT INTO dbo.tenantBranding
  (TenantId, CompanyName, LogoUrl, FaviconUrl, LoginBackgroundUrl,
   LogoStyle, FaviconStyle, LoginBackgroundStyle,
   LogoClass, FaviconClass, LoginBackgroundClass,
   Slogan, SloganStyle, SloganClass,
   PrimaryColor, SecondaryColor, FontFamily, CreationTime, IsDeleted)
VALUES
  (1, N'Khách hàng A',
   '/resources/images/logo-text.png',
   '/favicon.ico',
   '/libs-ext/metronic/assets/media/bg/Gis-login3.png',
   N'', N'', N'',                 -- Style: rỗng
   N'max-h-90px', N'', N'',       -- Class: logo giữ kích thước mặc định
   N'GIS Software' + CHAR(13) + CHAR(10) + N'Make in' + CHAR(13) + CHAR(10) + N'Viet Nam',  -- Slogan mặc định (xuống dòng)
   N'', N'',                      -- SloganStyle, SloganClass: rỗng
   '#187DE4', '#0D1B2A', NULL, GETUTCDATE(), 0);

-- =============================================
-- BƯỚC 2: Check data gốc
-- =============================================
SELECT *
FROM dbo.tenantBranding
WHERE CompanyName = N'Khách hàng A'
ORDER BY CreationTime DESC;

-- =============================================
-- BƯỚC 3: Update data (sửa theo nhu cầu test)
--   Ví dụ dưới minh hoạ CẢ HAI cách chỉnh logo:
--     - LogoStyle: viết CSS tay (phóng to logo)
--     - LogoClass: dùng class Metronic có sẵn
--   (Chọn 1 trong 2 là đủ; ở đây để cả hai cho bạn thấy.)
-- =============================================
UPDATE dbo.tenantBranding
SET
    CompanyName = N'Khách hàng A - Updated - test',
    LogoUrl = 'https://upload.wikimedia.org/wikipedia/commons/2/2f/Google_2015_logo.svg',
    FaviconUrl = 'https://www.google.com/favicon.ico',
    LoginBackgroundUrl = 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=1200&h=600&fit=crop',
    LogoStyle = N'width:180px;',                 -- ← CSS tay: phóng to logo
    LoginBackgroundStyle = N'opacity:0.9;',      -- ← CSS tay cho ảnh nền
    LogoClass = N'max-h-120px',                  -- ← class Metronic thay cho max-h-90px
    LoginBackgroundClass = N'bgi-size-cover',    -- ← class Metronic: nền phủ kín
    Slogan = N'Bản đồ số' + CHAR(13) + CHAR(10) + N'cho doanh nghiệp',  -- ← slogan mới (xuống dòng)
    SloganStyle = N'font-size:2.5rem;',          -- ← CSS tay cho slogan
    SloganClass = N'text-warning',               -- ← class Metronic đổi màu slogan
    PrimaryColor = '#FF6B35',
    SecondaryColor = '#004E89',
    FontFamily = N'Segoe UI'
WHERE CompanyName = N'Khách hàng A'
  AND TenantId = 1;

-- =============================================
-- BƯỚC 4: Verify sau khi update
-- =============================================
SELECT *
FROM dbo.tenantBranding
WHERE CompanyName = N'Khách hàng A - Updated - test';

-- =============================================
-- BƯỚC 5: REVERT về giá trị gốc (nếu test xong)
-- =============================================
UPDATE dbo.tenantBranding
SET
    CompanyName = N'Khách hàng A',                          -- ← revert
    LogoUrl = '/resources/images/logo-text.png',           -- ← revert
    FaviconUrl = '/favicon.ico',                           -- ← revert
    LoginBackgroundUrl = '/libs-ext/metronic/assets/media/bg/Gis-login3.png',  -- ← revert
    LogoStyle = N'',                                        -- ← revert
    FaviconStyle = N'',                                     -- ← revert
    LoginBackgroundStyle = N'',                             -- ← revert
    LogoClass = N'max-h-90px',                             -- ← revert
    FaviconClass = N'',                                     -- ← revert
    LoginBackgroundClass = N'',                             -- ← revert
    Slogan = N'GIS Software' + CHAR(13) + CHAR(10) + N'Make in' + CHAR(13) + CHAR(10) + N'Viet Nam',  -- ← revert
    SloganStyle = N'',                                     -- ← revert
    SloganClass = N'',                                     -- ← revert
    PrimaryColor = '#187DE4',                              -- ← revert
    SecondaryColor = '#0D1B2A',                            -- ← revert
    FontFamily = NULL
WHERE CompanyName = N'Khách hàng A - Updated - test'
  AND TenantId = 1;

-- =============================================
-- BƯỚC 6: Verify sau revert
-- =============================================
SELECT *
FROM dbo.tenantBranding
WHERE CompanyName = N'Khách hàng A'
ORDER BY CreationTime DESC;
