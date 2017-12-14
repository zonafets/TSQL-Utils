/*  leave this
    l:see LICENSE file
    g:utility
    v:130901.1000\s.zaglio:added begin/end params to grp setup
    v:130802.1804,130730,130725,130724\s.zaglio:collection of scripts
*/
CREATE proc sp__script_templates
    @opt sysname = null,
    @dbg int=0
as
begin try
set nocount on

declare @proc sysname, @ret int
select @ret=0

if @opt is null or @opt='' goto help

select @opt=dbo.fn__str_quote(@opt,'|')

-- =================================================================== script ==

if charindex('|script|',@opt)>0 exec @ret=sp__script_template '
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%declarations%:
declare
    @ver decimal(10,4),@aut sysname,@db sysname,
    @emsg nvarchar(2048),@esev int,@ests int
select @db=db_name()
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%obj_ver_chk%:
select @ver=null,@aut=null
exec sp_executesql N''
    select
        @ver=cast(val1 as decimal(10,4)),
        @aut=val2
    from dbo.fn__script_info(@obj,@typ,0)
    '',N''@obj sysname,@typ char(2),@ver numeric(10,4) out,@aut sysname out'',
    @obj=''%obj%'',@typ=''rv'',@ver=@ver out,@aut=@aut out
if not @ver is null
    begin
    if @ver=%ver%
        begin
        if @aut!=''%aut%''
            raiserror(''local "%s.%s" with same version but different author'',
                      16,1,@db,''%obj%'') with nowait
        raiserror(''skipped "%s.%s" because local is the same'',
                  10,1,@db,''%obj%'') with nowait
        goto skip_%obj%
        end
    if @ver>%ver%
        begin
        raiserror(''skipped "%s.%s" because local is more recent'',
                  10,1,@db,''%obj%'') with nowait
        goto skip_%obj%
        end
    end

raiserror(''re-creating "%s.%s"'',10,1,@db,''%obj%'') with nowait

%drop%

begin try
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%skip_obj%:
end try
begin catch
if not error_number() in (208,207)
    begin
    select @emsg=error_message(),@esev=error_severity(),@ests=error_state()
    raiserror(@emsg,@esev,@ests)
    end
end catch
skip_%obj%:
'

-- ==================================================================== group ==

if charindex('|group|',@opt)>0 exec sp__script_template '
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%scr_header%:
/*******************************************************
** generated in the:%dt% by %uid% from %db%
** latest objs to %latests_objs%
*******************************************************/
set nocount on
declare
    @db sysname,@svr sysname,
    @emsg nvarchar(2048),@esev int,@ests int

select @db=db_name(), @svr=@@servername

if @svr=''%svr%'' and @db=''%db_util%''                           --|utility|
    begin                                                         --|utility|
    raiserror(''Cannot execute from db where originated.'',       --|utility|
              11,1) with nowait                                   --|utility|
    goto end_of_script                                            --|utility|
    end                                                           --|utility|
                                                                  --|utility|
-- check local our target application name                        --|other|
if %config%(%app_name%)=''%app_name%'' goto end_of_script         --|other|
                                                                  --|other|
-- check db version
if (select cmptlevel
    from master..sysdatabases
    where [name]=@db
    )<90
    begin
    raiserror(''DB compatibility level must be at least 90 (MSSql2k5)'',
              10,1) with nowait
    raiserror(''Please run "exec sp_dbcmptlevel ''''%s'''', 90"'',
              10,1,@db) with nowait
    raiserror('''',11,1) with nowait
    goto end_of_script
    end


if not object_id(''sp__script_store'') is null                    --|other|
    exec sp__script_store @opt=''moff''                           --|other|

-- for versioning
declare
    @aut sysname,                   -- store author
    @ver decimal(14,4),             -- used to store new obj version
    @msg nvarchar(128),             -- generic message string
    @repeat int                     -- number of repeat of script
                                    -- if error of unknow obj, script is
                                    -- repeated bacause dependencies

if object_id(''tempdb..#script_results'') is null
    create table #script_results(
        id int identity,
        dt datetime default(getdate()) not null,
        who sysname default system_user+''@''+isnull(host_name(),''???''),
        grp sysname not null,
        rep int null,
        number int null,
        message nvarchar(2048) not null,
        severity int not null,
        state int null,
        line int null,
        [procedure] sysname null
        )

if object_id(''tempdb..#script_catch'') is null
    exec(''
        %script_catch_implementation%
    '')

select
    @repeat=1

begin_of_script:
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%scr_footer%:

dispose:
/*  to manage dependencies we run eventually the script 2 or 3 times */
if exists(
    select top 1 null
    from #script_results
    where number in (208,207)  -- invalid object, invalid column name
    and rep=@repeat
    -- a difference between x32 and x64 of mssql 2k5/8
    and not message like ''%''''cpu_ticks_in_ms''''%''
    )
    begin
    select @repeat=@repeat+1
    select @msg=replicate(''#'',80)+'' REPEAT ''+cast(@repeat as char)
    raiserror(@msg,10,1)
    if @repeat<3
        goto begin_of_script
    else
        begin
        select db_name() db,* from #script_results
        raiserror(''script repeats failure'',16,1)
        end
    end

exec %grp_setup% @opt=''run|end''                                   --|setup|

-- select * from #script_results
-- drop table #script_results
exec sp__context_info @opt=''mdef''                               --|other|

end_of_script:

-- finished:%dt%
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%script_catch_definition%:
create proc #script_catch @grp sysname,@repeat int
as
begin
insert #script_results(dt,grp,rep,number,message,severity,state,line,[procedure])
select getdate(),@grp,@repeat,
       error_number(),isnull(error_message(),''n/s''),
       error_severity(),error_state(),
       error_line(),error_procedure()
end
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%disable_tracer%:

-- ##########################
-- ##
-- ## disable trace db;
-- ## hope nobody work on important things while upgrade
-- ##
-- ########################################################
if not object_id(''sp__script_trace_db'') is null
    exec sp__script_trace_db ''uninstall''

-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%enable_tracer%:

-- ##########################
-- ##
-- ## re-install/upgrade script tracer
-- ## upgrade LOG_DDL if necessary
-- ##
-- ########################################################
exec sp__script_trace_db ''install''
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%obj_core_chk%:
select @ver=dbo.fn__script_sign(''%obj%'',1)
if not @ver is null
and @ver=%ver%
    begin
    raiserror(''skipped "%s.%s" because is the same'',
              10,1,@db,''%obj%'') with nowait
    goto skip_%obj%
    end

raiserror(''re-creating "%s.%s"'',10,1,@db,''%obj%'') with nowait

%drop%

begin try
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%skip_obj%:
exec %grp_setup% @opt=''run|begin''                                  --|setup|

end try
begin catch
exec #script_catch ''%grp%'',@repeat
if not error_number() in (208,207)
    begin
    select @emsg=error_message(),@esev=error_severity(),@ests=error_state()
    raiserror(@emsg,@esev,@ests)
    end
end catch
skip_%obj%:
'

if charindex('|move|',@opt)>0 exec sp__script_template '
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%header%:
/*                                                                  --|dbg|
declare                                                             --|dbg|
    @trgs nvarchar(4000),@crlf nvarchar(2),@n int,@m int,           --|dbg|
    @proc sysname,@err int,@ret int,@d datetime,                    --|dbg|
    @ms_key int,@ms_ins int,@ms_del int, @ms_commit int,@ms_alt int,--|dbg|
    @log_id int,@top int                                            --|dbg|
select @crlf=crlf from fn__sym()                                    --|dbg|
*/                                                                  --|dbg|
declare @nm int

--=============================================================================
--== do some test to ensure that condition is not wrong
--=============================================================================
select @d=getdate()

begin try

select
    @n=count(*),
    @m=sum(case when %where% then 1 else 0 end)
from %main% (nolock)

if @n=@m
    begin
    raiserror("wrong condition try move all data",16,1)
    goto ret
    end

select @trgs=null                                           --|trgs|
select                                                      --|trgs|
    @trgs=isnull(@trgs+@crlf,"")                            --|trgs|
         +"alter table %dst% enable trigger "               --|trgs|
         +quotename(name)                                   --|trgs|
from %dst_db%.sys.triggers                                  --|trgs|
where parent_id=object_id("%dst%")                          --|trgs|
and is_disabled=0                                           --|trgs|
                                                            --|trgs|
select @idxs=null                                           --|idxs|
select                                                      --|idxs|
    @idxs=isnull(@idxs+@crlf,"")                            --|idxs|
         +"alter index "+quotename(name)                    --|idxs|
         +" on %dst% disable"                               --|idxs|
from %dst_db%.sys.indexes                                   --|idxs|
where object_id=object_id("%dst%")                          --|idxs|
and is_disabled=0                                           --|idxs|
and is_unique=0                                             --|idxs|
and [type]!=1                                               --|idxs|
                                                            --|idxs|
select                                                      --|idxs|
    @trgs=isnull(@trgs+@crlf,"")                            --|idxs|
         +"alter index "+quotename(name)                    --|idxs|
         +" on %dst% rebuild"                               --|idxs|
from %dst_db%.sys.indexes                                   --|idxs|
where object_id=object_id("%dst%")                          --|idxs|
and is_disabled=0                                           --|idxs|
and is_unique=0                                             --|idxs|
and [type]!=1                                               --|idxs|
                                                            --|idxs|
select                                                      --|trgs|
    @trgs=isnull(@trgs+@crlf,"")                            --|trgs|
         +"alter table %src% enable trigger "               --|trgs|
         +quotename(name)                                   --|trgs|
from sys.triggers                                           --|trgs|
where parent_id=object_id("%src%")                          --|trgs|
and is_disabled=0                                           --|trgs|
                                                            --|trgs|
-- for delete                                               --|trgs|
alter table %src% disable trigger all                       --|trgs|
-- for insert                                               --|trgs|
alter table %dst% disable trigger all                       --|trgs|
-- disable dst indexes                                      --|idxs|
exec(@idxs)                                                 --|idxs|
                                                            --|idxs|
if @dbg=1 exec sp__printf "%s",@idxs                        --|idxs|
                                                            --|idxs|
select @ms_alt=datediff(ms,@d,getdate()),@d=getdate()

-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%begin%:
begin tran  --------------------------------------------------- begin tran ----

-- select keys to move
-- TODO: collect keys for each table to avoid inverse order of deletetion
select %top% %pkey%
into %keys%
from %main%
where %where%
%orderby%
select @nm=@@rowcount
if @nm=0
    begin
    exec sp__printf "-- no rows to move for main table %src%"
    goto skip_move
    end

select @ms_key=datediff(ms,@d,getdate()),@d=getdate()

-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%end%:
commit  ------------------------------------------------------ commit tran ----
select @ms_commit=datediff(ms,@d,getdate()),@d=getdate()

%log_commit%

-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%body_group%:

-- ##########################
-- ##
-- ## %src%
-- ##
-- ########################################################

insert %dst%(
    %dst_flds%
    )
select
    %tbl_flds%
from %main% %main_alias%
join %keys% tmp
on %on_pkeys%
join %src% %alias%                      --|main|
on %join_on%                            --|main|

select @ms_ins=datediff(ms,@d,getdate()),@d=getdate()

-- delete from live                     --|move|
delete %alias%                          --|move|
from %main% %main_alias%                --|move|
join %keys% tmp                         --|move|
on %on_pkeys%                           --|move|
join %src% %alias%                      --|main|move|
on %join_on%                            --|main|move|

select @ms_del=datediff(ms,@d,getdate()),@d=getdate()

%log_times%
-------------------------------------------------------------------------------

-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%body_single_table%:

-- ##########################
-- ##
-- ## %src%
-- ##
-- ########################################################

-- select keys to move
-- TODO: collect keys for each table to avoid inverse order of deletetion
select %top% %pkey%
into %keys%
from %main%
where %where%
%orderby%
select @nm=@@rowcount
if @nm=0
    begin
    exec sp__printf "-- no rows to move for %src%"
    goto skip_%lbl%
    end

select @ms_key=datediff(ms,@d,getdate()),@d=getdate()

begin tran  --------------------------------------------------- begin tran ----

insert %dst%(
    %dst_flds%
    )
select
    %tbl_flds%
from %src% %alias%
join %keys% tmp
on %on_pkeys%

select @ms_ins=datediff(ms,@d,getdate()),@d=getdate()

-- delete from live                                             --|move|
delete %alias%
from %src% %alias%
join %keys% tmp
on %on_pkeys%

select @ms_del=datediff(ms,@d,getdate()),@d=getdate()
commit  ------------------------------------------------------ commit tran ----
select @ms_commit=datediff(ms,@d,getdate()),@d=getdate()

%log_times%

skip_%lbl%:

-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%footer%:
-- restore triggers                                             --|trgs|
exec(@trgs)                                                     --|trgs|
if @dbg=1 exec sp__printf "%s",@trgs                            --|trgs|

skip_move:
if @@trancount>0 rollback
end try ---------------------------------------------------------- end try ----
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%catch%:

begin catch
select @err=@@error
exec @ret=sp__err @cod=@proc,@opt="ex|warn"
if @@trancount>0 rollback

end catch
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%log_times_section%:
insert %log%(dt,tbl,n,ms_key,ms_alt,ms_ins,ms_del,ms_commit)        --|nfo|
select @dt_log,                                                     --|nfo|
       ''%src%'',@nm,@ms_key,@ms_alt,@ms_ins,@ms_del,@ms_commit    --|nfo|

-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%log_commit_section%:
insert %log%(dt,tbl,n,ms_key,ms_alt,ms_ins,ms_del,ms_commit)        --|nfo|
select @dt_log,''*'',0,0,0,0,0,@ms_commit                           --|nfo|

-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
'

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
select @proc=object_name(@@procid)
exec sp__usage @proc,'
Scope
    common templates for sp__script and sp__script_group

Parameters
    [param]     [desc]
    @opt        options
                script  templates for sp__script
                group   templates for sp__script_group
                move    templates for sp__script_move
    @dbg        1=last most importanti info/show code without execute it
                2=more up level details
                3=more up ...

Examples
    [example]
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end try

-- =================================================================== errors ==
begin catch
-- if @@trancount > 0 rollback -- for nested trans see style "procwnt"

exec @ret=sp__err @cod=@proc,@opt='ex'
return @ret
end catch   -- proc sp__script_templates