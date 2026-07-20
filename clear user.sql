-- Trước khi xóa, hãy kiểm tra các record có Id từ 5 đến 10
SELECT TOP (1000) *
FROM [eKMapServer_dev_job].[dbo].[AbpUsers]

-- Set CreatorUserId = NULL cho các record đang tham chiếu đến ID 5-10
UPDATE [eKMapServer_dev_job].[dbo].[AbpUsers]
SET CreatorUserId = NULL
WHERE CreatorUserId BETWEEN 5 AND 10;

-- Xóa records
DELETE FROM [eKMapServer_dev_job].[dbo].[AbpUsers]
WHERE Id = 11;

UPDATE [eKMapServer_dev_job].[dbo].[AbpUsers] 
SET ChangePassWordForLogInNext = 1 
where Id = 18