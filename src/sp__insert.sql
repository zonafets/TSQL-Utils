/*  leave this
    l:see LICENSE file
    g:utility
    r:090703\S.Zaglio: added transaction
    r:090626\S.Zaglio: used fn__flds_quotename
    r:090205\S.Zaglio: added header management
    r:090129\S.Zaglio: corrected management of ' in data
    r:081218\S.Zaglio: added random delete and reinsert or a single row and @rows
    r:081021\S.Zaglio: insert constant data or from a select or table
    t:sp__insert 'test','v1|v2|v3\v4|v5|v6',@row_sep='\',@dbg=1 select * from test
    t:sp__insert 'ot04_stock',@excludes='sync_dt',@random=1,@dbg=1  -- delete and reinsert a random line
    t:
        ALTER  table test(a int, b sysname, c sysname,d int, e sysname)
        declare @test nvarchar(4000)
        set @test='19|BATCH|OT03_BATCH_NUMBER|2|(null)
        20|BATCH|OT05_BATCH_DETAILS|3|(null)
        21|BATCH|OT06_BATCH_DOCS|4|(null)
        22|BATCH|A23_BATCH_DOCS|1|(null)
        '
        exec sp__insert 'test',@test,@null='(null)',@dbg=1
        select * from test
        drop table test
*/
CREATE   proc [dbo].[sp__insert]
    @into sysname=null,
    @from nvarchar(4000)=null,    -- values,table,select
    @flds nvarchar(4000)=null,    -- fields name
    @rows bigint=null out,
    @excludes nvarchar(4000)=null,
    @col_sep nvarchar(8)='|',
    @row_sep nvarchar(8)=null,
    @header bit=0,
    @random bit=0,
    @null nvarchar(16)=null,
    @trans bit=1 ,
    @dbg bit=0
as
begin
set nocount on
declare @crlf nvarchar(2) set @crlf=char(13)+char(10)
if @into is null begin
    exec sp__usage 'sp__insert'
    goto ret
end

if @row_sep is null set @row_sep=@crlf

declare @i int, @col int ,@cols int
declare @sql nvarchar(4000)
declare @values nvarchar(4000)
declare @where nvarchar(4000)
declare @table sysname
declare @row nvarchar(4000)
declare @value sysname
declare @consts bit set @consts=0
declare @s sysname
declare @err int

if @random=1 begin
    if @flds is null and @header=0 set @flds=dbo.fn__flds_of(@into,',',@excludes)
    set @table=@into
    if @where is null set @where=dbo.fn__flds_of(@table,',',@excludes)
    set @sql='SELECT top 1 '+@where+' FROM '+@table+' ORDER BY newid() desc' -- get a random line
    set @values=''
    exec sp__select @sql,@body=@values out,@null='(/null/)',@dtstyle=126
    set @values=dbo.fn__inject(@values)
    set @where=replace(@where,',',' and ')
    set @where=dbo.fn__str_exp(dbo.fn__str_exp('%%=''@@''',@where,' and '),@values,'|')
    set @where=replace(@where,'=''(/null/)''',' is null ')
    set @sql='DELETE FROM '+@table+' WHERE '+@where
    if @dbg=1 exec sp__printf @sql
    exec(@sql) set @rows=@@rowcount
    if @rows!=1 begin print 'no deleted row' goto err end
    set @values=dbo.fn__str_exp('''%%''',@values,'|')
    set @values=replace(@values,'|',',')
    set @sql='insert into %tbl%(%flds%)\n values(%values%)'
    exec sp__str_replace @sql out,'\n|%tbl%|%flds%|%values%|''(/null/)''',@crlf,@table,@flds,@values,'null'
    if @dbg=1 exec sp__printf @sql
    exec(@sql) set @rows=@@rowcount
    if @rows!=1 begin print 'no inserted row' goto err end
    goto ret
end

if charindex(@col_sep,@from)>0 or charindex(@row_sep,@from)>0 set @consts=1
if @consts=1 begin
    set @rows=dbo.fn__str_count(@from,@row_sep)
    set @cols=dbo.fn__str_count(@from,@col_sep)
end

set @i=1

-- populate flds statement
if @header=1 begin
    set @flds=replace(dbo.fn__str_at(@from,@row_sep,@i),@col_sep,',')
    set @i=@i+1
end
if @flds is null begin
    set @flds=dbo.fn__flds_of(@into,',',null)
    end

-- prepare fields names
set @flds=dbo.fn__flds_quotename(@flds,',')

if @trans=1 begin
    if @dbg=1 exec sp__printf 'begin transaction'
    begin transaction
    end
set @null=''''+@null+''''
while (@i<=@rows)
    begin
    set @row=dbo.fn__str_at(@from,@row_sep,@i)
    set @row=replace(@row,'''','''''')
    set @i=@i+1
    if @row='' continue
    /*
    if dbo.fn__exists(@into,'U')=0 begin
        set @sql='select into @tbl select '
        set @col=1 set @values=''
        while (@col<@cols) begin
            set @s=str(@col)
            set @value=dbo.fn__str_at(@row,@col_sep,@col)
            if isdate(@value)=1 set @value='getdate() as col'+@s else
            if isnumeric(@value)=1 set @value=str(@value)+' as col'+@s else
            set @value=''''+replicate('-',255)+''' as col'+@s
            if @values<>'' set @values=@values+','
            set @values=@values+@value
        end -- while
    */
    set @values='''%%'''
    set @values=dbo.fn__str_exp(@values,@row,@col_sep)
    set @values=replace(@values,@col_sep,',')
    set @values=replace(@values,@null,'null')
    set @sql='insert into @tbl(@flds) values(@from) set @err=@@error'

    /*
    if @consts=1 begin
        set @values=dbo.fn__str_exp('''%%''',@from,@col_sep)
        set @values=replace(@values,@col_sep,',')
        set @from='values('+@values+')'
    end
    */

    exec sp__str_replace @sql out,'@tbl|@flds|@from',@into,@flds,@values
    if @dbg=1 exec sp__printf @sql
    exec sp_executesql @sql,N'@err int out',@err=@err out
    if @err!=0 goto err
    end -- while

if @trans=1 begin
    if @dbg=1 exec sp__printf 'commit transaction'
    commit transaction
    end
goto ret

err:
if @trans=1 begin
    if @dbg=1 exec sp__printf 'rollback transaction'
    rollback
    end

ret:
end -- proc