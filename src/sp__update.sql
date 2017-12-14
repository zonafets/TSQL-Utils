/*  leave this
    l:see LICENSE file
    g:utility
    v:081219\S.Zaglio: added @rows
    v:081208\S.Zaglio: done simple random update
    c:(info at http://msdn.microsoft.com/en-us/library/aa175776(SQL.80).aspx)
    t:sp__update 'ot04_stock',@excludes='sync_id,sync_dt',@random=1,@dbg=1
    t:sp__update 'ot04_stock',@flds='ID_TRK_PRODUCER',@where='sync_id',@random=1,@dbg=1
*/
CREATE          proc [dbo].[sp__update]
    @table sysname,
    @flds nvarchar(4000)=null,@excludes nvarchar(4000)=null,
    @values nvarchar(4000)=null,
    @where nvarchar(4000)=null,
    @rows bigint=null out,
    @random bit=0,
    @dbg bit=0
as
begin
set nocount on
declare @crlf nvarchar(2) set @crlf=char(13)+char(10)
declare @sets nvarchar(4000)
declare @sql  nvarchar(4000)
declare @test nvarchar(4000)
declare @d datetime set @d=getdate()
if @flds is null set @flds=dbo.fn__flds_of(@table,',',@excludes)
if @random=1 begin
    if @where is null set @where=dbo.fn__flds_of(@table,',',null)
    set @sql='SELECT top 1 '+@where+' FROM '+@table+' ORDER BY newid() desc' -- get a random line
    set @values=''
    exec sp__select @sql,@body=@values out,@null='(/null/)',@dtstyle=126
    set @values=dbo.fn__inject(@values)
    set @where=replace(@where,',',' and ')
    set @where=dbo.fn__str_exp(dbo.fn__str_exp('%%=''@@''',@where,' and '),@values,'|')
    set @where=replace(@where,'=''(/null/)''',' is null ')
    set @sql='SELECT top 1 '+@flds+' FROM '+@table+' WHERE '+@where
    set @values=''
    set @test='SELECT top 1 '+@excludes+' FROM '+@table+' WHERE '+@where

    exec sp__select @sql,@body=@values out,@null='(/null/)',@dtstyle=126
    if coalesce(@values,'')='' begin print 'error:'+@sql+@crlf+'      '+dbo.fn__inject(@sql) goto ret end
    set @values=dbo.fn__inject(@values)
    set @sets =dbo.fn__str_exp(dbo.fn__str_exp('%%=''@@''',@flds,','),@values,'|')
    set @sets=replace(@sets,'=''(/null/)''','=null ')
end
if not @where is null set @where =' where '+@where else set @where=''
set @sql='update %tbl%\n set %sets%\n %where%'
exec sp__str_replace @sql out,'\n|%tbl%|%sets%|%where%',@crlf,@table,@sets,@where
if @dbg=1 exec sp__printf @sql
exec(@sql)
set @rows=@@rowcount
if @rows!=1 print 'no updated row'
--exec sp__printf dbo.fn__sql_format(@sql,80)
ret:
end