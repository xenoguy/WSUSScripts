IF object_id('tempdb..#tmpdelUpdates') is not null DROP TABLE #tmpdelUpdates
GO

CREATE TABLE #tmpdelUpdates
(
LocalUpdateID INT
)

INSERT INTO #tmpdelUpdates
exec susdb.dbo.spGetObsoleteUpdatesToCleanup;

DECLARE @myLocalUpdateID int

DECLARE MY_CURSOR CURSOR
LOCAL STATIC READ_ONLY FORWARD_ONLY
FOR
SELECT DISTINCT LocalUpdateID from #tmpdelUpdates

OPEN MY_CURSOR
FETCH NEXT FROM MY_CURSOR INTO @myLocalUpdateID
WHILE @@FETCH_STATUS = 0
BEGIN
PRINT @myLocalUpdateID
exec susdb.dbo.spDeleteUpdate @localUpdateID=@myLocalUpdateID
FETCH NEXT FROM MY_CURSOR INTO @myLocalUpdateID
END
CLOSE MY_CURSOR
DEALLOCATE MY_CURSOR
DROP TABLE #tmpdelUpdates