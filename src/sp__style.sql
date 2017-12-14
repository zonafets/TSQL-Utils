/*  Keep this due MS compatibility
    l:see LICENSE file
    g:utility
    v:130909.0901,130906\s.zaglio: better help;added shortcut into
    v:130707\s.zaglio: added a and j tag
    v:130416\s.zaglio: added more help
    v:130127\s.zaglio: added tag o and b
    v:130107\s.zaglio: added lower/upper case in setup option
    v:121202\s.zaglio: optimized
    v:121118.1900\s.zaglio: added object based template
    v:121118\s.zaglio: changed proc style to support exceptions
    v:121115\s.zaglio: added AC
    v:121031\s.zaglio: section #tbls init
    v:121029\s.zaglio: test mode
    v:120920\s.zaglio: added setup
    v:120918\s.zaglio: adapted to new script_template
    v:120906\s.zaglio: added unpvt and procie
    v:120831.1500\s.zaglio: improve of PROC
    v:120823\s.zaglio: added func
    v:120724\s.zaglio: added cursor template
    r:120625\s.zaglio: a total remake
    t:sp__style 'proc#SP_TEST',@opt='select'
    t:sp__style 'setup' -- sp__style 'procie'
    t:sp__style 'func#test'
    t:sp__style 'h' -- sp__style 'header'
*/
CREATE proc [dbo].[sp__style]
    @params sql_variant=null,
    @opt    sysname=null,
    @dbg    smallint=null
as
begin
set nocount on
declare
    @proc sysname,      -- for sp__trace
    @ret int,           -- standard API: 0=OK else STATUS(negative if failed)
    @err int            -- user for pure sql statements

select
    @proc=object_name(@@procid),@ret=0,@err=0,
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|'),
    @dbg=isnull(@dbg,0)

declare
    @p1 sysname,
    @p2 sysname,
    @p3 sysname,
    @p4 sysname,
    @psep char(1),
    @procbody sysname,
    @excludes sysname,
    @dt datetime

create table #tpi(
    name sysname,
    params sysname,
    description sysname,
    section sysname null
    )

create table #src (lno int identity primary key,line nvarchar(4000))
create table #vars (id nvarchar(16),value sql_variant)
create table #tpl (lno int identity primary key,line nvarchar(4000))
create table #tpl_sec(lno int identity,section sysname,line nvarchar(4000))
create table #tpl_cpl(
                    tpl binary(20),section sysname,y1 int,y2 int,
                    constraint pk_tpl_cpl primary key (tpl,section)
                )

-- ===================================================================== init ==
if @dbg>0 exec sp__elapsed @dt out,'-- begin'

select
    @psep='#'
--                 name     params  description                         section
insert #tpi select 'proc',  'name', 'stored procedure',                 null
insert #tpi select 'prec',  'name', 'stored procedure without except.', null
insert #tpi select 'procwnt','name', 'stored proc. with nested trans.', 'proc'
insert #tpi select 'procio','name', 'sp for I/O',                       'proc'
insert #tpi select 'procie','name', 'sp for Import/Export',             'proc'
insert #tpi select 'cs',    'name', 'cursor',                           null
insert #tpi select 'func',  'name', 'function',                         null
insert #tpi select 'h',     '',     'header',                           'header'
insert #tpi select 'header','',     'header',                           null
insert #tpi select 'unpvt', '',     'unpivot table code',               'unpivot'
insert #tpi select 'setup', 'grp',  'sp for setup of group',            null
insert #tpi select 'ac',    'tbl',  'script alter constraint',          null

if @params is null goto help

-- ###############################################################  templates ##

exec sp__Script_template '
%proc%:
/*  leave this
    l:see LICENSE file
    g:[%groups%]
    k:[%keywords%]
    r:%builid%: short comment
    t:one line test
    t:
        multi line test
*/
create proc %proc_name%
    @opt sysname = null,
    @dbg int=0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
-- @@nestlevel is >1 if called by other sp (not correct if called by remote sp)

set nocount on
set xact_abort on                                                      --|ntrn|

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    @err_msg nvarchar(2000)             -- used before raise

-- ======================================================== params set/adjust ==
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=nullif(@opt,''''),
    @opt=case when @opt is null then ''||'' else dbo.fn__str_quote(@opt,''|'') end
    -- @param=nullif(@param,''''),

-- nested transaction management                                       --|ntrn|
declare @trancount int                                                 --|ntrn|
select @trancount = @@trancount                                        --|ntrn|
if @trancount = 0                                                      --|ntrn|
    begin transaction                                                  --|ntrn|
else                                                                   --|ntrn|
    save transaction %proc_name%                                       --|ntrn|
                                                                       --|ntrn|
-- ============================================================== declaration ==
declare
    -- generic common
    @run bit,
    -- @i int,@n int,                      -- index, counter
    -- @sql nvarchar(max),                 -- dynamic sql
    -- options
    -- @sel bit,@print bit,                -- select and print option for utils
    @end_declare bit

-- =========================================================== initialization ==
select
    -- @sel=charindex(''|sel|'',@opt),@print=charindex(''|print|'',@opt),
    @run=charindex(''|run|'',@opt)|dbo.fn__isjob(@@spid)
        |cast(@@nestlevel-1 as bit),        -- when called by parent/master SP
    @end_declare=1

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
if  @run=0 goto help

/*  test if is it the test or development environment and               --|body|
    if not specified TEST option give an error because the sp can       --|body|
    steal data from production                                          --|body|
if dbo.fn__config(''%app_test_code%'','') in (''test'',''dev'')         --|body|
and charindex(''|test|'',@opt)=0                                        --|body|
    begin                                                               --|body|
    raiserror(''to run in test/dev env. need TEST option'',16,1)          --|body|
    goto err                                                            --|body|
    end                                                                 --|body|
*/                                                                      --|body|

-- =============================================================== #tbls init ==

-- ===================================================================== body ==

%proc_body%

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,''
Scope
    [write here a short desc]

Parameters
    [param]     [desc]
    @opt        options
    @dbg        debug level
                1   basic info and do not execute dynamic sql
                2   more details (usually internal tables) and execute dsql
                3   basic info, execute dsql and show remote info

Examples
    [example]
''

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end try

-- =================================================================== errors ==
begin catch
-- if @@trancount > 0 rollback -- for nested trans see style "procwnt"
                                                                       --|ntrn|
declare @xstate int                                                    --|ntrn|
select @xstate = xact_state();                                         --|ntrn|
if @xstate = -1                                                        --|ntrn|
    rollback;                                                          --|ntrn|
if @xstate = 1 and @trancount = 0                                      --|ntrn|
    rollback                                                           --|ntrn|
if @xstate = 1 and @trancount > 0                                      --|ntrn|
    rollback transaction usp_my_procedure_name;                        --|ntrn|

exec @ret=sp__err @cod=@proc,@opt=''ex''
return @ret
end catch   -- proc %proc_name%
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%prec%:
/*  leave this
    l:see LICENSE file
    g:[%groups%]
    k:[%keywords%]
    r:%builid%: short comment
    t:one line test
    t:
        multi line test
*/
create proc %proc_name%
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp  (not correct if called by remote sp)

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
    @opt=dbo.fn__str_quote(isnull(@opt,''''),''|'')

-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
declare
    -- generic common
    -- @i int,@n int,                      -- index, counter
    -- @sql nvarchar(max),                 -- dynamic sql
    -- options
    -- @opt1 bit,@opt2 bit,
    @end_declare bit

-- =========================================================== initialization ==
select
    -- @opt1=charindex(''|opt|'',@opt),
    @end_declare=1

-- ======================================================== second params chk ==
if @opt=''||'' -- charindex(''|run|'',@opt)=0
and dbo.fn__isjob(@@spid)=0      -- if can run from a job               --|body|
    goto help

/*  test if is it the test or development environment and               --|body|
    if not specified TEST option give an error because the sp can       --|body|
    steal data from production                                          --|body|
if dbo.fn__config(''%app_test_code%'','') in (''test'',''dev'')         --|body|
and charindex(''|test|'',@opt)=0                                        --|body|
    begin                                                               --|body|
    select @e_msg=''to run in test/dev env. need TEST option''          --|body|
    goto err                                                            --|body|
    end                                                                 --|body|
*/                                                                      --|body|

-- =============================================================== #tbls init ==

-- ===================================================================== body ==

%proc_body%

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- =================================================================== errors ==
/*
err:        exec @ret=sp__err @e_msg,@proc,@p1=@e_p1,@p2=@e_p2,@p3=@e_p3,
                              @p4=@e_p4,@opt=@e_opt                     goto ret

err_me1:    select @e_msg=''write here msg''                              goto err
err_me2:    select @e_msg=''write this %s'',@e_p1=@var                    goto err
*/
-- ===================================================================== help ==
help:
exec sp__usage @proc,''
Scope
    [write here a short desc]

Parameters
    [param]     [desc]

Examples
    [example]
''

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc %proc_name%
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%header%:
/*  leave this
    l:see LICENSE file
    g:[%groups%]
    k:[%keywords%]
    r:%builid%: short comment
    t:one line test
*/
create
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%cursor%:
declare %cs% cursor local for
    select %%flds%%
    from %%tbl%%
    where 1=1
open %cs%
while 1=1
    begin
    fetch next from %cs% into %%vars%%
    if @@fetch_status!=0 break
    end -- cursor %cs%
close %cs%
deallocate %cs%
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%func%:
/*  leave this
    l:see LICENSE file
    g:[%groups%]
    k:[%keywords%]
    r:%builid%: short comment
    t:one line test
*/
create function %name%(
    -- @opt sysname = null,
    -- @dbg int=0
    )
-- returns type
-- returns table @t(id int identity,...)
-- returns table as select ...
as
begin
declare @ret type
select @ret=
return @ret
end -- %name%
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%body%:
-- ...
-- if ??? goto err_sample
-- ...
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%bodyio%:
-- 1. input 1 row of data by params
-- 2. input 1 or more rows of data by #tbl of same structure os returned rs
-- 3. set command for: list, delete (ins, upd are deduced)
-- 4. load data into internal normalized tables
-- 5. ins/upd/del internal tables
-- 6. upd/ins/del storage with internal tables
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%bodyie%:
-- 1. import remote files and keep a local copy
-- 2. process files into #temp
-- 3. create middle tables and find correct PKey
   3.1 the name of source file cannot be part of the PK
   3.2 if the source file has a progressive, set regression as errors
-- 4. do other control
-- 5. send reports to technichan
-- 6. copy existing in a flat history file
-- 7. ins/upd new records on PK in a middle table
-- 8. eventually update remote files info renaming in .OK or .ERR
-- 9. reupdate middle data with codes associations
-- 10. ins/upd final data with last updates
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%unpivot%:
select
    col,
    val
from
    (
    select
        cast(ca as sql_variant) as ca,
        cast(cb as sql_variant) as cb
    from (
        select 1 as ca, 2 as cb
        union all
        select 3 as ca, 4 as cb
        ) my_table
    ) as t
    unpivot
    (
    val
    for col in (ca, cb)
    ) as unpvt
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%setup%:
/*  leave this
    l:see LICENSE file
    g:[%groups%]
    k:[%keywords%]
    r:%builid%: setup objects for group %grp%
    t:%grp%_setup @opt=''run''
*/
create proc %grp_ssp%
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp  (not correct if called by remote sp)
declare
    @proc sysname, @err int, @ret int -- @ret: 0=OK -1=HELP, any=error id
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=dbo.fn__str_quote(isnull(@opt,''''),''|'')
-- ========================================================= param formal chk ==
if charindex(''|run|'',@opt)=0 and dbo.fn__isjob(@@spid)=0 goto help

-- ============================================================== declaration ==
declare
    @util_ver sysname

-- =========================================================== initialization ==
select
    -- select dbo.fn__group_version(''utility'')
    @util_ver=dbo.fn__group_version(''utility'')

-- ======================================================== second params chk ==
if @util_ver<''%utility_ver%'' goto err_ver

-- ===================================================================== body ==

exec sp__printf ''-- %s: utility version is:%d'',@proc,@util_ver

-- ============================================= add base data if 1st install ==
-- if not exists(select * from %table% where ...)
-- if and not object_id(%sp%) is null exec ...

-- sp__printf''do others''

-- ============================================================== install job ==
/*
-- sp_setup_job get app name, smtp and support emails and call "sp__job"
if not object_id(''sp_setup_job'') is null    -- local application job initializer
    exec sp_setup_job ''%action%'',''sp_%action%'',''%at%'' --,@grp=''%grp%''
*/
-- ================================================================== dispose ==

dispose:if @@trancount>0 rollback
goto ret

-- =================================================================== errors ==
err_ver:
exec @ret=sp__err ''please update to latest utility version'',@proc
goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,''
Scope
    called before execute group script and after, create table and populate data

Notes
    this sp must be reentrant because is called before script where tables and
    stored do not exists and after and a second time again;
    so must use exists and object_id to test presence of data and objects

Parameters
    @opt    options
            run     to execute it (run automatically if executed from job)

Examples

''

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc %grp_ssp%

-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%ac%:
alter table [%tbl%] drop constraint %constraint%
alter table [%tbl%]
    add constraint %constraint% default (%val%) for %column%
'

-- ###############################################################  templates ##

if @dbg>0 exec sp__elapsed @dt out,'-- after templates'

-- ===================================================================== body ==

select @p1=dbo.fn__str_at(convert(sysname,@params),@psep,1)
select @p2=dbo.fn__str_at(convert(sysname,@params),@psep,2)
select @p3=dbo.fn__str_at(convert(sysname,@params),@psep,3)
select @p4=dbo.fn__str_at(convert(sysname,@params),@psep,4)

if @dbg>0 exec sp__printf '-- 1:%s, 2:%s, 3:%s, 4:%s',@p1,@p2,@p3,@p4

if not object_id(@p1) is null
    begin
    -- template base on similar object, excluding body section
    exec sp__script @p1             -- script the obj to #src
    update #src set line=replace(line,@p1,isnull(nullif(@p2,''),'%new_name%'))
    delete from #src
    where lno>
        (select lno from #src where line like '%= body =%')
    and  lno<
        (select lno from #src where line like '%= dispose =%')
    exec sp__print_table '#src'
    goto ret
    end -- object based template


-- common macro
insert #vars
select '%builid%',convert(sysname,getdate(),12)+'\%'+system_user+'%'

if @p1='setup'
    insert #vars
    select '%utility_ver%',dbo.fn__group_version('utility')

-- alter here info for common sections
select @procbody=case @p1
                 when 'procio' then '%bodyio%'
                 when 'procie' then '%bodyie%'
                 else '%body%'
                 end
select @excludes=replace(@procbody,'%','')
if @p1!='procwnt' select @excludes=@excludes+'|ntrn'

-- get main section
select @p1=isnull(section,name) from #tpi where name=@p1

if @dbg>0 exec sp__elapsed @dt out,'-- after inits'

-- main sections process
if @p1='proc'
    begin
    if isnull(@p2,'')='' select @p2='not_specified'
    insert #vars select '%proc_name%',@p2
    exec sp__script_template @procbody,'%proc_body%',@excludes=@excludes
    end -- proc

if @p1='prec'
    begin
    if isnull(@p2,'')='' select @p2='not_specified'
    insert #vars select '%proc_name%',@p2
    exec sp__script_template @procbody,'%proc_body%',@excludes=@excludes
    end -- prec

if @p1='func'
    begin
    if isnull(@p2,'')='' select @p2='not_specified'
    insert #vars select '%name%',@p2
    exec sp__script_template '%bodyio%','%body%',@excludes=@excludes
    end -- proc

if @p1='cs'
    begin
    select @p1='cursor'
    if isnull(@p2,'')='' select @p2='cs'
    insert #vars select '%cs%',@p2
    end -- proc

if @p1='setup'
    begin
    -- sp__style 'setup#test'
    -- sp__style 'setup#TEST'
    if isnull(@p2,'')='' select @p2='%grp%'
    insert #vars select '%grp%',@p2
    if @p2=lower(@p2) collate SQL_Latin1_General_CP850_BIN
        select @p2=@p2+'_setup'
    else
        select @p2=@p2+'_SETUP'
    insert #vars select '%grp_ssp%',@p2
    end -- proc

if @p1='ac'
    begin
    -- sp__style 'ac#tbl'
    if isnull(@p2,'')='' select @p2='%tbl%'
    insert #vars select '%tbl%',@p2
    end -- ac

select @p1='%'+@p1+'%'

if @dbg>0 exec sp__elapsed @dt out,'-- after templating'

exec sp__script_template @p1,@excludes=@excludes

if @dbg>0 exec sp__elapsed @dt out,'-- after mixing'

if charindex('|select|',@opt)>0
    select line from #src order by lno
else
    exec sp__print_table '#src'

if @dbg>0 exec sp__elapsed @dt out,'-- after print'

goto ret

/* =============================== errors ================================= */
err:        -- init of error management

/* ================================ help ================================== */
help:
-- sp__style
exec sp__usage @proc,@extra='
Comment tag styles
    v:one line short Version comment
    r:short Release comment
    t:single test line
    t:
      --example of multiple
      exec sp__printf ''test line''
    c:single or multile Comment line
    g:%group1%[,%group2%[,...]]
    s:See also,...
    d:deprecated target function (see notes)
    o:obsolete tag means that this object replaces the obj_name (see notes)
    k:%keywords%
    a:%alias% tag compile the object into a synonym of %alias%(if exists)
    j:reserved for future use for jobs
    b:%buildin% (not with common know mean) that align the date-version system
      to application/platform versioning system (see notes)
    p:profile

Press  F6  CTRL+A  CTRL+C  F6  CTRL+A  CTRL+V to copy & paste result
*** this is the better way (the 4th experimented in 3 years of develop),
in mssql200x, to develop test and debug tsql code

Notes
    * I normally associate this sp to shortcut CTRL+8
    * Tag V,R
      v:yymmdd[.hhmm][,old_ver]\author: comment[;comment of old_ver]
      Examples
        v:121104\s.zaglio: this is a tipical comment
        v:121103,121102\s.zaglio: this is the 121103 comment; this of 121102
    * Tag K
      On tag "k" do not repeat groups; do not use more that 4,5 keywords;
      do not use implicit or deductible words.
    * Tag D
      d:yymmdd\u.name:obj_name
                will delete obj_name on next sp__script_group
                The lst obj_name "V" tag can contain
                the motivation
    * Tag O
      o:yymmdd\u.name:obsolete_obj_name
                when an object is still used, cannot be deprecated so temporarily
                is marked as obsolete from current object; in the future will
                change to D tag
    * Tag b
      b:ver.rel.builin|modifiers
                can be used by an application/platform utility to place inform
                the sp__script_group to place the script into a specific place
    * Tag a
      see for example fn__hex that is a duplicate of new ms sys.fn_varbintohexstr
      or fn__str_table_fast that is a duplicate of fn__str_split

    * Tag p
      specilize the profile (or target or customer)


List of templates
'
exec sp__select_astext '#tpi',@header=1
select @ret=-1    -- generic Help error

ret:     -- procedure end...is better than return
return @ret
end -- sp__style