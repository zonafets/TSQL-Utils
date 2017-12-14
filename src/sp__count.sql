/*  leave this
    l:see LICENSE file
    g:utility
    v:111214\s.zaglio: now @tables can use wild chars and restyled
    v:100221\s.zaglio: added @where
    v:091023\s.zaglio: added help
    v:090205\S.Zaglio: a little remake to better manage remote svr/db
    v:090127\S.Zaglio: added quotes around name because instance and - in some name
    v:090109\S.Zaglio: linked server extension only for table(not select)
    v:081020\S.Zaglio: count rows in select too
    v:081007\S.Zaglio: count rows in table
    t:begin declare @n int exec sp__count 'sysobjects',@n out,@dbg=1 print @n end
    t:begin declare @n int exec sp__count 'select * from sysobjects where xtype=''U''',@n out,@dbg=1 print @n end
    t:begin declare @n int exec sp__count 'sysobjects',@n out,@svr='loopback',@dbg=1 print @n end
    t:begin declare @n int exec sp__count 'sysobjects',@n out,@dbg=1,@where='id<0' print @n end
    t:begin declare @n int exec sp__count 'sys%',@n out,@opt='print',@dbg=1 print @n end
*/
CREATE proc [dbo].[sp__count]
    @table nvarchar(4000)=null,
    @n bigint=null out,
    @where nvarchar(4000)=null,
    @opt sysname=null,
    @dbg bit=null
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
if @table is null goto help

-- ============================================================== declaration ==
declare
    @sql nvarchar(4000),
    @crlf nvarchar(2),
    @own sysname,@errl int,
    @svr sysname,@db sysname,
    @nn bigint,@params sysname,
    @print bit

declare @tbls table(obj sysname)

-- =========================================================== initialization ==

select
    @print=charindex('|print|',@opt),
    @n=0,
    @crlf=crlf,
    @svr=parsename(@table,4),
    @db=parsename(@table,3),
    @db=case when @svr is null then @db else isnull(@db,db_name()) end,
    @own=case when @db is null then null else isnull(parsename(@table,2),'dbo') end,
    @svr=dbo.fn__sql_quotename(@svr),
    @db=dbo.fn__sql_quotename(@db),
    @params=N'@nn bigint out,@err int out'
from fn__sym()

-- ======================================================== second params chk ==
-- ===================================================================== body ==

-- simplify (n.b.: must converted into sp__sql_simplify or something similar. see also sp__count
select @table=replace(@table,@crlf,' ')
select @table=rtrim(ltrim(@table))
select @table=replace(@table,'        ',' ')
select @table=replace(@table,'    ',' ')
select @table=replace(@table,'  ',' ')
select @table=replace(@table,'  ',' ')

if left(ltrim(@table),7)='select '
    insert @tbls select '('+@table+') sq'
else
    insert @tbls(obj)
    select [name]
    from sysobjects
    where 1=1
    and xtype='U'
    and [name] like @table

declare cs cursor local for
    select obj
    from @tbls
open cs
while 1=1
    begin
    fetch next from cs into @table
    if @@fetch_status!=0 break

    select @sql =''
    select @sql =@sql+'select @nn=count(*) from '+@table
                + coalesce(' where '+@where,'')+' select @err=@@error'
    if not @db is null select @sql='use '+@db+' '+@sql

    if @dbg=1 exec sp__printsql @sql

    select @nn=0
    if @svr is null
        exec sp_executesql @sql,@params,@nn=@nn out,@err=@err out
    else
        begin
        select @sql ='exec '+@svr+'.'+@db+'..sp_executesql N'''
                    +dbo.fn__injectN(@sql)+''',N'''+@params
                    +''',@nn=@nn out,@err=@err out'
        exec sp_executesql @sql,@params,@nn=@nn out,@err=@err out
        select @errl=@@error
        end
    if @err!=0 or @errl!=0 goto err_tbl
    if @print=1 exec sp__printf '%s has %d rows',@table,@nn
    select @n=@n+@nn

    end -- while of cursor
close cs
deallocate cs

goto ret

-- =================================================================== errors ==
err_tbl: exec @ret=sp__err 'near table "%s"',@proc,@p1=@table goto ret
-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    count the numbers of lines of a local or remote set of tables

Parameters
    @table  is the table name; can be svr.db.dbo.tbl;
            can use % and _ but in this case the
            target svr.db must be a tween of this.

Options
    print   print the results
'
-- ===================================================================== exit ==
ret:
return @ret
end -- sp__count