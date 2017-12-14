/*  leave this
    l:see LICENSE file
    g:utility
    k:move, script, remote, server
    r:121010\s.zaglio: short comment
    t:
        sp__script_transfer
            'test',
            'continent|country|state|province|city|place|civic|
             palces|civics',@opt='sqlite'
            ,@dbg=2
*/
CREATE proc sp__script_transfer
    @dst sysname = null,
    @objs nvarchar(4000) = null,
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    -- error vars
    @e_msg nvarchar(4000),              -- message error
    @e_opt nvarchar(4000),              -- error option
    @e_p1  sql_variant,
    @e_p2  sql_variant,
    @e_p3  sql_variant,
    @e_p4  sql_variant

select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
declare
    -- generic common
    @i int,@n int,                      -- index, counter
    @sql nvarchar(max),                 -- dynamic sql
    -- options
    @nodata bit,
    @obj sysname,@typ sysname,
    @drop sysname,
    @crlf nvarchar(4),
    @end_declare bit

create table #src(lno int identity, line nvarchar(4000))
-- =========================================================== initialization ==
select
    @nodata=charindex('|nodata|',@opt),@opt=replace(@opt,'|nodata|','|'),
    @crlf=crlf,
    @end_declare=1
from fn__sym()

-- ======================================================== second params chk ==
if @opt='||' goto help

-- ===================================================================== body ==

declare cs cursor local for
    select o.token,so.typ,so.[drop]
    from fn__str_params(@objs,'|',default) o
    join fn__sysobjects(default,default,default) so
    on o.token=so.obj -- select top 1 * from  sys.objects
open cs
while 1=1
    begin
    fetch next from cs into @obj,@typ,@drop
    if @@fetch_status!=0 break

    exec sp__prints @obj

    truncate table #src
    exec sp__Script @obj,@opt=@opt
    select @sql='drop '+@drop+' if exists '+@obj+';'
    select @sql=isnull(@sql+@crlf,'')+line from #src order by lno
    select @sql='exec('+@crlf+
                ''''+replace(@sql,'''','''''')+''''+@crlf+
                ') at '+quotename(@dst)

    if @dbg>0 exec sp__printsql @sql
    if @dbg<2 exec(@sql)

    if @nodata=0 and @typ='U'
        begin
        select @sql=dbo.fn__sql_trim('
            insert openquery('+@dst+',
                             ''select * from '+@obj+'''
                            )
            select * from '+@obj)
        if @dbg>0 exec sp__printsql @sql
        if @dbg<2 exec(@sql)
        end -- @nodata

    end -- cursor cs
close cs
deallocate cs

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- =================================================================== errors ==
/*
err:        exec @ret=sp__err @e_msg,@proc,@p1=@e_p1,@p2=@e_p2,@p3=@e_p3,
                              @p4=@e_p4,@opt=@e_opt                     goto ret

err_me1:    select @e_msg='write here msg'                              goto err
err_me2:    select @e_msg='write this %s',@e_p1=@var                    goto err
*/
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    script objects one by one and execute on remote @dst server;
    useful for ODBC or non MSSQL engines

Parameters
    @dst    linked server
    @objs   list of objects separated by |
    @opt    options
            nodata  do not transfer data for tables
            ...     pass the option to sp__script
    @dbg    1 print sql and execute
            2 print sql but not execute

Examples
    [example]

-- list of remove servers --
'
exec sp__select_astext '
    select name,data_source,catalog,collation_name
    from sys.servers
    '


select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__script_transfer