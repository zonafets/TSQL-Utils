/*  leave this
    l:see LICENSE file
    g:utility
    v:140203\s.zaglio: bug near some end lines
    v:130729\s.zaglio: bug near %
    v:130530\s.zaglio: complete
    r:130529\s.zaglio: removed #src, using splitter, added @opt
    v:110518\s.zaglio: added more @sql...
    v:110315\s.zaglio: print sql code refactored
    t:
        declare @sql nvarchar(max)
        select @sql=''''+replace(definition,'''','''''')+''''
        from sys.sql_modules
        where object_id=object_id('sp__printsql')
        exec sp__printsql @sql
*/
CREATE proc sp__printsql
    @sql1 ntext = null,
    @sql2 ntext = null,
    @sql3 ntext = null,
    @sql4 ntext = null,
    @opt  sysname = 0,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
-- ========================================================= param formal chk ==
if @sql1 is null and @sql2 is null and @sql3 is null and @sql4 is null goto help

-- ============================================================== declaration ==
declare
    @sql nvarchar(max),@line nvarchar(4000),@crlf nvarchar(2),
    @i int,@j int,@n int,@lcrlf tinyint
-- =========================================================== initialization ==
select
    @sql=cast(@sql1 as nvarchar(max))
        +isnull(@crlf+cast(@sql2 as nvarchar(max)),'')
        +isnull(@crlf+cast(@sql3 as nvarchar(max)),'')
        +isnull(@crlf+cast(@sql4 as nvarchar(max)),''),
    @crlf=crlf,
    @lcrlf=len(crlf)
from fn__sym()
-- ======================================================== second params chk ==
-- ===================================================================== body ==
-- if substring(@sql1,1,4)='#src' exec sp__print_table '#src'


select @n=len(@sql),@i=1,@j=charindex(@crlf,@sql,@i)
while 1=1
    begin
    -- exec sp__printf 'i=%d, j=%d',@i,@j
    if @j=0 select @j=@n+1
    select @line=replace(substring(@sql,@i,@j-@i),'%','%%'),@j=@j+@lcrlf,@i=@j
    raiserror(@line,10,1)
    if @j>@n break
    select @j=charindex(@crlf,@sql,@i)
    end

goto ret

-- =================================================================== errors ==
-- err_sample1: exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    print long sql code eventually refactored
    (TODO: today this is only a marker for future full functional sp)

Parameters
    @sql1..4    sql code
    @opt        options (not used)

'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__printsql