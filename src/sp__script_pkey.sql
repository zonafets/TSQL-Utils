/*  leave this
    l:see LICENSE file
    g:utility
    v:121003\s.zaglio: use of script_synonym
    v:121002\s.zaglio: script pkey or return list of fields
    t:sp__script_pkey null,'cfg',@opt='flds',@dbg=1
*/
CREATE proc sp__script_pkey
    @pkey nvarchar(4000) =null out,
    @obj sysname = null,
    @sep nvarchar(32) = null,
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
    -- @i int,-- @n int,                      -- index, counter
    -- @sql nvarchar(max),                 -- dynamic sql
    -- options
    @flds bit,@defs bit,
    @db sysname,
    @sql nvarchar(4000),
    @end_declare bit

-- =========================================================== initialization ==
select
    @pkey=null,
    @flds=charindex('|flds|',@opt),
    @defs=charindex('|defs|',@opt),
    @end_declare=1

-- ======================================================== second params chk ==
if isnull(@obj,'')='' goto help
if @defs=1 goto err_nos

if not parsename(@obj,4) is null goto err_svr

-- follow synonym
exec sp__script_synonym @obj out,@obj,@opt='path'

if object_id(@obj,N'U') is null goto ret

-- ===================================================================== body ==

select @db=isnull(parsename(@obj,3),db_name())

select @sql='
select @pkey=isnull(@pkey+@sep,'''')+columnname
from ['+@db+']..fn__script_idx(object_id(@obj,N''U''))
where [primary]=1
order by index_column_id
'
if @dbg=1 exec sp__printsql @sql
exec @ret=sp_executesql
            @sql,
            N'@pkey nvarchar(4000) out,@sep nvarchar(32),@obj sysname',
            @pkey out,@sep,@obj
if @@error!=0 or @ret!=0 goto err_sql

if @flds=0 goto err_nos

if @dbg=1 exec sp__printf '-- pkey=%s',@pkey

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- =================================================================== errors ==
err:        exec @ret=sp__err @e_msg,@proc,@p1=@e_p1,@p2=@e_p2,@p3=@e_p3,
                              @p4=@e_p4,@opt=@e_opt                     goto ret

err_nos:    select @e_msg='only "flds" option is admitted'              goto err
err_sql:    select @e_msg='into inside code'                            goto err
err_syn:    select @e_msg='cannot follow more than 3 levels of synonyms'goto err
err_svr:    select @e_msg='server not admitted in the name'             goto err
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    return list of fields of pk of @obj or alter code

Parameters
    @pkey   out of list or code
    @obj    is te name of obj; can be a synonym or contain db
    @sep    separator for fields (default is pipe |)
    @opt    options
            flds    list fields separated by @sep
            defs    list definitions (TODO)

Examples
    [example]
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__script_pkey