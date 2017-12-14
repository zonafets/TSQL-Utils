/*  leave this
    l:see LICENSE file
    g:utility
    k:follow,synonym,object,table,view
    v:121003\s.zaglio: follow synonym and return real object or script
*/
CREATE proc sp__script_synonym
    @synonym nvarchar(max) = null out,
    @obj sysname = null,
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
    @i int,-- @n int,                      -- index, counter
    -- @sql nvarchar(max),                 -- dynamic sql
    -- options
    -- @opt1 bit,@opt2 bit,
    @db sysname,@sql nvarchar(4000),
    @crlf nvarchar(2),
    @end_declare bit

-- =========================================================== initialization ==
select
    @db=isnull(parsename(@obj,3),db_name()),
    -- @opt1=charindex('|opt|',@opt),
    @synonym=null,
    @crlf=crlf,
    @end_declare=1
from fn__sym()

-- ======================================================== second params chk ==
if isnull(@obj,'')='' -- @opt='||'
    goto help

-- ===================================================================== body ==
-- follow synonym
select @i=1
while not object_id(@obj,N'SN') is null and @i<4
    begin
    -- exec sp__printf '-- db=%s, obj=%s',@db,@obj
    select @sql='
        select @obj=base_object_name
        from ['+@db+'].sys.synonyms
        where name=parsename(@obj,1)
        '
    exec sp_executesql @sql,N'@obj sysname out',@obj out
    select @db=isnull(parsename(@obj,3),db_name())
    select @i=@i+1
    end

if charindex('|path|',@opt)>0
    select @synonym=@obj
else
    begin
    create table #src(lno int identity primary key,line nvarchar(4000))
    if @db!=db_name() insert #src select 'use ['+@db+']'
    exec sp__script @obj
    select @synonym=isnull(@synonym+@crlf,'')+line from #src order by lno
    drop table #src
    end -- script

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.
if @dbg=1 exec sp__printsql @synonym
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
    follow synonym and return real object or script

Parameters
    @synonym    output the real object path or script
    @obj        real object or synonym
    @opt        options
                path    force return of path of object instead of source

Examples
    [example]
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__script_synonym