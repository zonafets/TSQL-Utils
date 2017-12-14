/*  leave this
    l:see LICENSE file
    g:utility
    k:action,trigger,db,store,application,personalization
    v:130116\s.zaglio: +quotename(@db)
    v:121003\s.zaglio: follow synonym
    v:120907\s.zaglio: connect application scripts to db trigger
*/
CREATE proc sp__script_act
    @sp sysname = null,
    @obj sysname = null,
    @cmd nvarchar(4000) = null,
    @idx int = null,
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
    @hash_sp int,@hash_obj int,
    @db sysname,@sql nvarchar(4000),
    @end_declare bit

-- =========================================================== initialization ==
select
    @db=db_name(),
    @sp=upper(@sp),         -- for compatibility with sp__script_store
    @obj=upper(@obj),       -- for compatibility with sp__script_store
    @hash_sp=dbo.fn__crc32(@sp),
    @hash_obj=dbo.fn__crc32(parsename(@obj,1)),
    @end_declare=1

-- ======================================================== second params chk ==
if '' in (isnull(@sp,''),isnull(@obj,''),isnull(@cmd,'')) -- or@opt='||'
    goto help

-- follow synonym
exec sp__script_synonym @obj out,@obj,@opt='path'
if isnull(parsename(@obj,3),@db)!=@db
    begin
    select
        @sp=quotename(@db)+'.'+isnull(parsename(@sp,2),'')+'.'+parsename(@sp,1),
        @sql=N'exec @ret='+quotename(parsename(@obj,3))
            +'..sp__script_act @sp,@obj,@cmd'
    exec sp_executesql
        @sql, N'@sp sysname,@obj sysname,@cmd nvarchar(4000),@ret int out',
        @sp=@sp,@obj=@obj,@cmd=@cmd,@ret=@ret out
    goto ret
    end

if object_id(@sp) is null or object_id(@obj) is null goto err_unk

-- ===================================================================== body ==

update script_act set
    txt=@cmd,
    idx=@idx
where rid=@hash_sp
and pid=@hash_obj
if @@rowcount=0
    begin
    insert script_act(rid,pid,idx,txt)
    select @hash_sp,@hash_obj,@idx,@cmd
    end

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- =================================================================== errors ==
err:        exec @ret=sp__err @e_msg,@proc,@p1=@e_p1,@p2=@e_p2,@p3=@e_p3,
                              @p4=@e_p4,@opt=@e_opt                     goto ret

err_unk:    select @e_msg='not found "%s" or "%s"',@e_p1=@sp,@e_p2=@obj goto err

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    connect create/drop/alter of an object to local application code

Notes
    data is stored into table "script_act"

Parameters
    @sp     is the name of storec procedure that register the dynamic code
            and with @obj is used a primary key
    @obj    name of object to connect
    @cmd    sql code to execute
    @opt    options (not used)

Examples
    exec sp__script_act @proc,@tbl,@cmd

-- list of application triggers --
'
select
    (select name from sys.objects where dbo.fn__crc32(upper(name))=s.rid) sp,
    (select name from sys.objects where dbo.fn__crc32(upper(name))=s.pid) obj,
    s.txt as sql
into #tmp
from script_act s

exec sp__select_astext 'select * from #tmp',@header=1

drop table #tmp

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__script_act