-- these indexes are not supported.  they are suggestions from SQL management studio, and in my case they improved performance significantly
USE [SUSDB]
GO
if 0 = (SELECT count(*) FROM sys.indexes WHERE name='IX_tbrevisionincategory' AND object_id = OBJECT_ID('[dbo].[tbRevisionInCategory]'))
    CREATE NONCLUSTERED INDEX [IX_tbrevisionincategory] ON [dbo].[tbRevisionInCategory] ([CategoryID],[Expanded]) INCLUDE ([RevisionID])
GO

if 0 = (SELECT count(*) FROM sys.indexes WHERE name='IX_tbLocalizedPropertyForRevision' AND object_id = OBJECT_ID('[dbo].[tbLocalizedPropertyForRevision]'))
    CREATE NONCLUSTERED INDEX [IX_tbLocalizedPropertyForRevision] ON [dbo].[tbLocalizedPropertyForRevision] ([LocalizedPropertyID])
GO

if 0 = (SELECT count(*) FROM sys.indexes WHERE name='IX_tbRevisionSupersedesUpdate' AND object_id = OBJECT_ID('[dbo].[tbRevisionSupersedesUpdate]'))
    CREATE NONCLUSTERED INDEX [IX_tbRevisionSupersedesUpdate] ON [dbo].[tbRevisionSupersedesUpdate]([SupersededUpdateID])
print 'indexes added'
