/*  leave this
    l:see LICENSE file
    g:utility
    v:081219\S.Zaglio: delete a random row of a table
    t:sp__delete 'ot04_stock',@random=1,@dbg=1  -- delete and reinsert a random line
    t:sp__delete 'as_f0005',@random=1,@dbg=1  -- delete and reinsert a random line
    t:sp__delete 'as_f0101j2',@where='abat1="w"',@random=1,@dbg=1  -- delete and reinsert a random line
*/
CREATE proc sp__delete
    @table sysname=null,
    @where nvarchar(4000)=null,
    @rows bigint=null out,
    @random bit=0,
    @dbg bit=0
as
begin
set nocount on
declare @crlf nvarchar(2) set @crlf=char(13)+char(10)
if @table is null begin
    exec sp__usage 'sp__delete'
    goto ret
end

declare    @from nvarchar(4000)
declare    @flds nvarchar(4000)
declare    @excludes nvarchar(4000)
declare    @col_sep nvarchar(8) set @col_sep='|'
declare    @row_sep nvarchar(8)

if @row_sep is null set @row_sep=@crlf

declare @i int, @col int, @cols int
declare @sql nvarchar(4000)
declare @values nvarchar(4000)
declare @row nvarchar(4000)
declare @value sysname
declare @consts bit set @consts=0
declare @s sysname
if @where='' set @where=null else set @where=replace(@where,'"','''')
if @random=1 begin
    set @flds=dbo.fn__flds_of(@table,',',@excludes)
    if @where is null begin
        set @sql='SELECT top 1 '+@flds+' FROM '+@table+' ORDER BY newid() desc' -- get a random line
    end
    else begin
        -- set @where=dbo.fn__inject(@where)
        if left(ltrim(@where),6)!='where ' set @where=' where '+@where
        set @sql='SELECT top 1 '+@flds+' FROM '+@table+' '+@where+' ORDER BY newid() desc' -- get a random line
    end
    set @values=''
    exec sp__select @sql,@body=@values out,@null='(/null/)',@dtstyle=126,@dbg=@dbg
    set @values=dbo.fn__inject(@values)
    set @flds=replace(@flds,',',' and ')
    set @flds=dbo.fn__str_exp(dbo.fn__str_exp('%%=''@@''',@flds,' and '),@values,'|')
    set @where =' WHERE '+@flds
    set @where=replace(@where,'=''(/null/)''',' is null ')
    set @sql='DELETE FROM '+@table+@where
    if @dbg=1 exec sp__printf @sql
    exec(@sql) set @rows=@@rowcount
    if @rows!=1 begin print 'no deleted row' goto err end
    goto ret
end
else print 'no other extensions done'
goto ret
err:
ret:
end -- proc