/*  leave this
    l:see LICENSE file
    g:utility
    k:table,field,list,quote,name,synonym
    v:151106\s.zaglio: added collate database_default
    v:121118\s.zaglio: added quote
    v:121003\s.zaglio: return list of flds even of a synonym
    d:121003\s.zaglio: fn__flds_list
    d:121003\s.zaglio: sp__flds_of
    d:121003\s.zaglio: sp__search
    t:sp__flds_list null,'cfg',@dbg=1,@exclude='%id%'
    t:select * into #cfg from cfg
    t:sp__flds_list null,'#cfg',@dbg=1,@exclude='%id%'
*/
CREATE proc sp__flds_list
    @flds nvarchar(4000) = null out,
    @obj sysname = null,
    @sep nvarchar(32) = null,
    @exclude nvarchar(4000) = null,
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
if isnull(@obj,'')='' goto help

-- ============================================================== declaration ==
declare
    -- generic common
    -- @i int,@n int,                      -- index, counter
    -- @sql nvarchar(max),                 -- dynamic sql
    -- options
    -- @opt1 bit,@opt2 bit,
    @cols nvarchar(4000),@db sysname,@i int,
    @sql nvarchar(4000),@oid int,
    @params nvarchar(512),
    @end_declare bit

-- =========================================================== initialization ==
-- try to resolve synonym or synonym of synonym...
select
    @flds=null,
    @obj=case when left(@obj,1)='#' then 'tempdb..'+@obj else @obj end,
    -- @opt1=charindex('|opt|',@opt),
    @sep=isnull(@sep,'|'),
    @end_declare=1

-- follow synonym
exec sp__script_synonym @obj out,@obj,@opt='path'
select @db=isnull(parsename(@obj,3),db_name())

-- ======================================================== second params chk ==


-- ===================================================================== body ==

-- print parsename('[db..obj]',1)
-- print parsename('db..[obj]',1)

select @oid=object_id(@obj)
if @oid is null return null

/*  this fn is so slower that is better
    delete excludes to the end instead of while */

-- collect cols
select @sql=replace('
select @flds=isnull(@flds+@sep,'''')
            +case
             when dbo.fn__token_sql(c.name)=1
               or patindex(''%[^a-z0-9]%'',c.name collate database_default)>0
             then quotename(c.name)
             else c.name
             end
from [%db%].sys.columns c
where c.object_id=@oid
and not case c.is_identity when 1 then ''%id%'' else c.name collate database_default end in (
    select token from fn__str_table(@exclude,@sep)
    )
order by column_id
','%db%',@db)
if @dbg=1 exec sp__printsql @sql
select @params='@flds nvarchar(4000) out,@sep nvarchar(32),'
              +'@oid int,@exclude nvarchar(4000)'
-- exec sp__printsql @sql
exec sp_executesql @sql,
                   @params,@flds=@flds out,@sep=@sep,@exclude=@exclude,@oid=@oid

-- sp__flds_list null,'#cfg',@dbg=1,@exclude='%id%'
-- select * into #cfg from cfg  -- drop table #cfg
-- select * from [tempdb].sys.columns c where object_id=object_id('tempdb..#cfg')
if @dbg=1 exec sp__printf '-- db:%s, obj:%s, flds:%s',@db,@obj,@flds

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
    return list of flds even of a synonym

Notes
    fields with symbols or reserved words will be quoted

Parameters
    @flds       out variable
    @obj        table or synonym
    @sep        separator (default is pipe |)
    @excludes   list os fields to exclude, separated by @sep
                field %id% is a macro that means "identity field"
    @opt        options (not used)

Examples
    [example]
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__flds_list