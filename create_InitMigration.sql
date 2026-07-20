IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL CREATE TABLE [__EFMigrationsHistory]
(
    [MigrationId] nvarchar(150) NOT NULL,
    [ProductVersion] nvarchar(32) NOT NULL,
    CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
);
IF NOT EXISTS (SELECT 1
FROM [__EFMigrationsHistory]
WHERE [MigrationId]=N'20260602080713_InitialBaseline') INSERT INTO [__EFMigrationsHistory]
    ([MigrationId],[ProductVersion])
VALUES(N'20260602080713_InitialBaseline', N'5.0.0');