/*  leave this
    l:see LICENSE file
    g:utility
    k:fn__script_drop,fn__sysobjects
    v:131002,131001\s.zaglio: test for fn__script_drop.fn__sysobjects
    t:sp__sysobjects_test @opt='run'
*/
CREATE proc sp__sysobjects_test
    @opt sysname = null,
    @dbg int=0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
-- @@nestlevel is >1 if called by other sp (not correct if called by remote sp)

set nocount on

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    @err_msg nvarchar(2000)             -- used before raise

-- ======================================================== params set/adjust ==
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=nullif(@opt,''),
    @opt=case when @opt is null then '||' else dbo.fn__str_quote(@opt,'|') end
    -- @param=nullif(@param,''),

-- ============================================================== declaration ==
declare
    @row_id int,@drop_script nvarchar(512),@if_exists nvarchar(512),
    @sql nvarchar(max),@run bit
-- =========================================================== initialization ==
select @run=charindex('|run|',@opt)
if @run=0 goto help
-- ======================================================== second params chk ==
-- =============================================================== #tbls init ==
-- ===================================================================== body ==
-- drop table #tmp
select
    identity(int,1,1) row_id,
    *,
    cast(null as nvarchar(2000)) drop_script_status,
    cast(null as nvarchar(2000)) if_exists_status
into #tmp
-- select *
from fn__sysobjects(default,default,'drop_script|if_exists')
where obj!='log_ddl'                    -- give error in sp__script_store
-- where drop_Script like '%fn__ntext%'
order by obj,typ

update #tmp set if_exists=replace(replace(if_exists,char(13),' '),char(10),' ')
while exists(select top 1 null from #tmp where charindex('  ',if_exists)>0)
    update #tmp set if_exists=replace(if_exists,'  ',' ')
while exists(select top 1 null from #tmp where charindex(' )',if_exists)>0)
    update #tmp set if_exists=replace(if_exists,' )',')')
while exists(select top 1 null from #tmp where charindex('( ',if_exists)>0)
    update #tmp set if_exists=replace(if_exists,'( ','(')

exec sp__script_store @opt='dis' -- disable

declare cs cursor local for
    select row_id,drop_Script,if_exists
    from #tmp
    -- select * from fn__sysobjects(default,default,'drop_script|if_exists')
    where 1=1 -- and obj='fn__ntext_to_lines'
    and not if_exists is null
    and not drop_script is null
    and not typ in ('D'/*constraint*/,
                    'SQ'/*service queue*/,
                    'IT'/*internal table*/,
                    'FS'/*clr fn*/)
    and not isnull(parent_typ,'') in ('IT')
    and not (typ='PK' and parent_typ!='U')
open cs
while 1=1
    begin
    fetch next from cs into @row_id,@drop_script,@if_exists
    if @@fetch_status!=0 break

    -- test if exists
    select @sql='
        select @err_msg=null
        begin tran savepoint
        begin try
        '+@if_exists+' select @err_msg=''ok'' else select @err_msg=''ko''
        rollback
        end try
        begin catch
        select @err_msg=''ko:''+error_message()+''(''+error_procedure()+'')''
        if @@trancount>0 rollback tran savepoint
        end catch'

    exec sp_executesql @sql,N'@err_msg nvarchar(2000) out',@err_msg=@err_msg out

    if @err_msg is null raiserror('inside error',16,1)
    -- if @err_msg='ko' exec sp__printsql @sql

    update #tmp set if_exists_status=@err_msg where row_id=@row_id

    -- test drop
    select @sql='
        select @err_msg=null
        begin tran savepoint
        begin try
        '+@drop_script+'
        select @err_msg=''ok''
        rollback
        end try
        begin catch
        select @err_msg=''ko:''+error_message()+''(''+error_procedure()+'')''
        if @@trancount>0 rollback tran savepoint
        end catch'

    exec sp_executesql @sql,N'@err_msg nvarchar(2000) out',@err_msg=@err_msg out
    -- if @err_msg!='ok' exec sp__printsql @sql

    if @err_msg is null raiserror('inside error',16,1)

    update #tmp set drop_script_status=@err_msg where row_id=@row_id

    end -- cursor cs
close cs
deallocate cs

select @sql='
    select
        drop_script_status,if_exists_status,sch,obj,typ,[drop],
        parent,parent_typ,drop_script,if_exists
        from #tmp
        order by drop_script_status,if_exists_status,obj,typ
    '
-- exec(@sql)
exec sp__select_astext @sql

exec sp__Script_store @opt='ena' -- enable

if exists(select top 1 null from #tmp where left(drop_script_status,2)='ko')
    raiserror('test failed',16,1)

-- ================================================================== dispose ==
dispose:
drop table #tmp

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    test fn__sysobjects and indirectly fn__script_drop
    also executing the scripts (into transactions with rollback)

Notes
    ### this sp drop all objects into a transaction that will be rollbacked ###

Parameters
    [param]     [desc]
    @opt        options
                run     execute the test
    @dbg        (not used)

Examples
    sp__sysobjects_test @opt="run"
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end try

-- =================================================================== errors ==
begin catch
-- if @@trancount > 0 rollback -- for nested trans see style "procwnt"
exec sp__Script_store @opt='ena' -- disable
exec sp__printsql @sql
exec @ret=sp__err @cod=@proc,@opt='ex'
return @ret
end catch   -- proc sp__sysobjects_test