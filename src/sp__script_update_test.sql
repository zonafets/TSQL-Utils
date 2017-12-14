/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    v:140204\s.zaglio: little refactor and added not practical test
    v:140203\s.zaglio: added different base code (regular,irregular)
    v:140130\s.zaglio: added tests for not commented and merge update
    v:140116\s.zaglio: added tests for ovr option
    v:131220\s.zaglio: test revision
    v:131217\s.zaglio: another global revision
    v:131216\s.zaglio: remake and relaxed tests
    v:131024\s.zaglio: added case 5
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:'sp__script_update_test @dbg=2'
*/
CREATE proc sp__script_update_test
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
    @id int,@name sysname,@sql nvarchar(4000),
    @crlf nvarchar(2),@st sysname,
    @msg nvarchar(2000),@log_id int,
    @obj_code nvarchar(max),
    @obj_name sysname,
    @typ char,
    @result sysname

-- =========================================================== initialization ==
select
    @obj_name='tst_sp__script_update_test_obj',
    @crlf=crlf
from fn__sym()
-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==

-- =============================================================== #tbls init ==

create table #test(
    id int identity primary key,
    name sysname,
    target_code char(1) check (target_code in ('R','I')),
    sql nvarchar(max),
    opt sysname,
    result char(1),
    status nvarchar(4000) null,
    log_id int null
    )

create table #targets(
    code char,
    sql nvarchar(max)
    )

-- =============================================================== test cases ==

if not object_id(@obj_name) is null exec('drop proc '+@obj_name)

-- ##########################
-- ##
-- ## source code
-- ##
-- ########################################################

insert #targets(code,sql)
-- irregular
select 'I','
/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    v:131216\s.zaglio: remake and relaxed tests
    v:131216\s.zaglio: not specified hhmm
    v:131024\s.zaglio: added case 5
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:sp__script_update_test
*/
create proc '+@obj_name+'
as
print ''hello''
'
union
-- regular
select 'R','
/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    v:131216\s.zaglio: not specified hhmm
    v:131024\s.zaglio: added case 5
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:sp__script_update_test
*/
create proc '+@obj_name+'
as
print ''hello''
'

-- ##########################
-- ##
-- ## upgrade code
-- ##
-- ########################################################

select @opt='',@obj_code=sql from #targets where code='I'
-- this first case must be first because the object
-- will be created from case test 2
insert #test(name,opt,result,target_code,sql)
select 'target not exists',@opt,'N','I',@obj_code
-----------------------------------------------------------
insert #test(name,opt,result,target_code,sql)
select 'target exists and has no comments',@opt,'U','I',@obj_code
-----------------------------------------------------------
union all select 'daily modification',@opt,'U','I','
/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    v:131216.1000\s.zaglio: remake and relaxed tests with small chg
    v:131216\s.zaglio: not specified hhmm
    v:131024\s.zaglio: added case 5
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:sp__script_update_test
*/
create proc '+@obj_name+'
as
print ''hello''
'
-----------------------------------------------------------
union all select 'fake daily modification',@opt,'C','I','
/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    v:131216.1000\s.zaglio: changed whole comment
    v:131216\s.zaglio: not specified hhmm
    v:131024\s.zaglio: added case 5
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:sp__script_update_test
*/
create proc '+@obj_name+'
as
print ''hello''
'
-----------------------------------------------------------
union all select 'older',@opt,'O','I','
/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    todo:calculate new correction dates on last+x
    d:131011\s.zaglio:sp_nothing
    v:131024\s.zaglio: added case 5
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:sp__script_update_test #1#2#3#4#5,@dbg=2
*/
create proc '+@obj_name+'
as
print ''hello''
'
-----------------------------------------------------------
union all select 'same',@opt,'S','I','
/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    v:131216\s.zaglio: remake and relaxed tests
    v:131216\s.zaglio: not specified hhmm
    v:131024\s.zaglio: added case 5
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:sp__script_update_test
*/
create proc '+@obj_name+'
as
print ''hello''
'
-----------------------------------------------------------
union all select 'newer for small comment correction',@opt,'U','I','
/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    v:131216\s.zaglio: remake and relaxed tests.
    v:131216\s.zaglio: not specified hhmm.
    v:131024\s.zaglio: added case 5
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:sp__script_update_test
*/
create proc '+@obj_name+'
as
print ''hello''
'
-----------------------------------------------------------
union all select 'conflict and missin hour',@opt+'|sd','C','I','
/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    todo:calculate new correction dates on last+x
    r:131216\s.zaglio: remake and relaxed tests.
    v:131024\s.zaglio: added case with missed hour
    v:131024\s.zaglio: added case 5.
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:sp__script_update_test #1#2#3#4#5,@dbg=2
*/
create proc '+@obj_name+'
as
print ''hello''
'
-----------------------------------------------------------
union all select 'compile error',@opt,'E','I','
/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    v:131217\s.zaglio: update but with compile error
    v:131216\s.zaglio: remake and relaxed tests
    v:131216\s.zaglio: not specified hhmm
    v:131024\s.zaglio: added case 5
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:sp__script_update_test
*/
create proc '+@obj_name+'
as
print hello
'
-----------------------------------------------------------
union all select 'conflict with two missing comment',@opt,'C','I','
/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    v:131217\s.zaglio: update but with compile error
    v:131024\s.zaglio: added case 5
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:sp__script_update_test
*/
create proc '+@obj_name+'
as
print ''hello''
'
-----------------------------------------------------------
union all select 'older but OVERWRITE','ovr|'+@opt,'U','I','
/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    todo:calculate new correction dates on last+x
    d:131011\s.zaglio:sp_nothing
    v:131024\s.zaglio: added case 5
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:sp__script_update_test #1#2#3#4#5,@dbg=2
*/
create proc '+@obj_name+'
as
print ''hello''
'
-----------------------------------------------------------
union all select 'update of merged','sd|'+@opt,'U','I','
/*  leave this
    l:see LICENSE file
    g:utility
    k:upgrade,conflict,author,different,check
    v:131216\s.zaglio: remake and relaxed tests
    v:131216\s.zaglio: not specified hhmm
    v:131216\a.ziglio: merged code
    v:131024\s.zaglio: added case 5
    v:131021\s.zaglio: final release
    r:131018\s.zaglio: added SD option test
    v:131008\s.zaglio: added more case
    r:131007\s.zaglio: test different cases
    t:sp__script_update_test
*/
create proc '+@obj_name+'
as
print ''hello''
'
-----------------------------------------------------------
union all select 'not practical code','sd|'+@opt,'E','I','
create proc '+@obj_name+'
as
print ''hello''
'
-----------------------------------------------------------

-- this is used by #update_log
create table #update_log(
    id int identity,
    dt datetime default(getdate()) not null,
    who sysname default system_user+'@'+isnull(host_name(),'???'),
    obj sysname,
    sts char,    -- Updated,New,Same,Older,Conflict,Error
    msg nvarchar(2000)
    )

-- ===================================================================== body ==

-- drop existing base object of previour bug of test
if not object_id(@obj_name) is null exec('drop proc '+@obj_name)

declare cs cursor local for
select
    id,name,sql,opt,result,target_code
from #test
open cs
while 1=1
    begin
    fetch next from cs into @id,@name,@sql,@opt,@result,@typ
    if @@fetch_status!=0 break

    select @obj_code=sql from #targets where code=@typ

    if @dbg>1
        begin
        exec sp__prints 'target code'
        exec sp__printsql @obj_code
        end

    if @dbg>0
        begin
        select @name as [case],@opt as [option],@result as expected
        exec sp__prints 'case %s(%s):%s',@id,@typ,@name
        end

    -- after test 1, create base the object to modify
    -- case 2 obj without comments
    if @id=2 exec('create proc '+@obj_name+' as print ''hello''')
    if @id>2 exec(@obj_code)

    select @log_id=max(id)+1 from #update_log
    select @log_id=isnull(@log_id,1)

    select @st=cast(@dbg as sysname)
    select @sql='exec sp__script_update @opt='''+@opt+''',@dbg='
               +@st+',@src=N'''+replace(@sql,'''','''''')+''''
    if @dbg>1
        begin
        exec sp__printsql @sql
        exec sp__prints 'result'
        end

    begin try
    exec (@sql)
    select @msg=null
    end try
    begin catch
    select msg=error_message()
    end catch

    -- drop altered object
    exec('drop proc '+@obj_name)

    update test set
        log_id=@log_id,
        status=case
               when test.result=log.sts
               then 'ok'+isnull(':'+@msg,'')
               else 'ko'+isnull(':'+@msg,'')
               end
    from #test test
    join #update_log log on log.id=@log_id
    where test.id=@id

    end -- cursor cs
close cs
deallocate cs

select @sql='select ''#test'' tbl,log_id,id,name,status from #test'
exec(@sql)
select @sql='select ''#update_log'' tbl,* from #update_log'
exec(@sql)

if exists(select top 1 null from #test where status like 'ko%')
    raiserror('test failed',16,1)

-- ================================================================== dispose ==
dispose:
drop table #test
drop table #update_log

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    test different cases for sp__script_update

Parameters
    [param]     [desc]
    @opt        (not used)
    @dbg        passed to sp__script_update

Examples
    sp__script_update_test

-- list of test cases ---
'
exec sp__select_astext 'select id,name from #test order by id'

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
end catch   -- proc sp__script_update_test