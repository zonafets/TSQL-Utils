/*  leave this
    l:see LICENSE file
    g:utility
    v:091012\s.zaglio: show a table paged as in web
    c:from http://snipplr.com/view/112/sqlserver-2000-tsql-stored-procedure-for-providing-paginated-results/
    t:sp__paging @tables='[sysobjects]',@pk='[sysobjects].id',@sort='id',@pagenumber=1,@pagesize=5
*/
CREATE PROCEDURE sp__paging
(
    @TABLES nvarchar(1000),
    @PK nvarchar(100),
    @JoinStatements nvarchar(1000)='',
    @FIELDS nvarchar(4000) = '*',
    @Filter nvarchar(4000) = '1=1',
    @Sort nvarchar(200) = NULL,
    @PageNumber int = 1,
    @PageSize int = 10,
    @TotalRec int =0 Output,
    @GROUP nvarchar(1000) = NULL
)
AS
/*
Created by Kashif Akram
Email Muhammad_kashif@msn.com
The publication rights are reserved
You can use this procedure with out removing these comments
*/
DECLARE @strPageSize nvarchar(50)
DECLARE @strStartRow nvarchar(50)
SET @strPageSize = CAST(@PageSize AS nvarchar(50))
SET @strStartRow = CAST(((@PageNumber - 1)*@PageSize + 1) AS nvarchar(50))
--set @PK =' tbl_Items.ItemID '
CREATE TABLE #PageTable (PID bigint primary key IDENTITY (1, 1) , UID int)
CREATE TABLE #PageIndex (UID int)
/*
CREATE UNIQUE CLUSTERED
INDEX [PK_tbl_PageTable] ON #PageTable (PID)
*/
CREATE
INDEX [PK_tbl_PageIndex] ON #PageIndex (UID)
--'SELECT ' + @Fields + ' FROM ' + @Tables + '' + @JoinStatements +' WHERE ' + @strSortColumn + @operator + ' @SortColumn ' + @strSimpleFilter + ' ' + @strGroup + ' ORDER BY ' + @Sort + ' DESC '
exec ('
set rowcount 0
insert into #pageTable(UID)
SELECT ' + @PK + ' FROM ' + @TABLES + ' ' + @JoinStatements +' WHERE ' + @Filter + ' ' + @GROUP + ' ORDER BY ' + @Sort + '
DECLARE @SortColumn int
SET ROWCOUNT '+ @strStartRow +'
select @SortColumn=PID from #PageTable --option (keep plan)
print @SortColumn
SET ROWCOUNT '+ @strPageSize +'
insert into #pageIndex
select UID from #PageTable where PID >= @SortColumn -- option (keep plan)
SELECT ' + @FIELDS + ' FROM ' + @TABLES + ' ' + @JoinStatements +' WHERE ' + @Filter + ' and '+ @PK + ' in (Select UID from #pageIndex)' + @GROUP + ' ORDER BY ' + @Sort + ' '
)
SELECT @TotalRec=count(*) FROM #pageTable
DROP TABLE #PageTable
DROP TABLE #PageIndex
RETURN