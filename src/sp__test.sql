/*  leave this
    l:see LICENSE file
    g:utility,test
    k:test,sp,case
    v:130609\s.zaglio: done
    r:130608\s.zaglio: create case tests
    t:sp__test 'sp__test','','sp__test',@dbg=1  -- insert/update unnamed/default
    t:sp__test 'sp__test','.','sp__test'        -- error
    t:sp__test 'sp__test','test1','sp__test @dbg=1',@dbg=1 -- insert named
    t:sp__test 'sp__test',@opt='list' -- exec sp__test '0x80000027',@opt='sel'
    t:sp__test 'sp__test',@opt='list|sel'
    t:sp__test 'sp__test',@dbg=1 -- test (differ because change the last list
    t:sp__test 'sp__test',@name='%'
    t:sp__test '0x00000002',@opt='status'
    t:sp__test '0x00000001',@opt='source'
    t:sp__test '0x00000001',@opt='result'
    t:sp__test '0x00000002',@opt='del'              -- del test
    t:sp__test 'sp__test_demo',@opt='del'           -- purge test
    t:sp__test '0x00000001',@opt='source|result'    -- error
    t:truncate table tst
*/
CREATE proc sp__test
    @obj sysname = null,
    @name sysname = null,
    @tst nvarchar(4000) = null,
    @opt sysname = null,
    @dbg int=0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
-- @@nestlevel is >1 if called by other sp
-- set forceplan off -- (**)
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
    -- generic common
    @i int,@n int,                         -- index, counter
    @d datetime,
    @tmp nvarchar(max),                    -- dynamic sql
    -- options
    @opt_list bit,
    @opt_del bit,
    @opt_sel bit,
    @opt_testing bit,
    @opt_quiet bit,
    @opt_source bit,
    @opt_result bit,
    @opt_status bit,

    -- summary conditions
    @opt_detail bit,
    @purge bit,
    @disappeared bit,
    @testing bit,

    @code nvarchar(max),
    @result nvarchar(max),
    @status nvarchar(max),
    @crlf nvarchar(2),
    @non_word sysname,
    @non_sentence sysname,
    @id int,
    @rid int,
    @cmd nvarchar(1024),
    @err_test sysname,
    @err_osql sysname,
    @file nvarchar(1024),
    @msg nvarchar(1024),

    -- statuses
    @sts_untested nchar(2),
    @sts_passed nchar(2),
    @sts_error nchar(2),
    @sts_disappeared nchar(2),
    @sts_failed nchar(2),

    @end_declare bit

declare @out table (lno int identity primary key, line nvarchar(4000))

-- =========================================================== initialization ==
select
    -- constants
    @crlf=crlf,
    @rid=power(-2,31),
    @err_test='test failed',
    @err_osql='call of sqlcmd failed',
    @non_word=non_word,
    @non_sentence=non_sentence,
    -- parameters normalization/adjust
    @obj=nullif(ltrim(rtrim(@obj)),''),
    @id=case
        when left(isnull(@obj,''),2)='0x'
        then dbo.fn__hex2int(@obj)
        else null
        end,
    @name=case when ltrim(rtrim(@name))='' then 'default' else @name end,
    @tst=nullif(ltrim(rtrim(@tst)),''),
    -- options
    @opt_list=charindex('|list|',@opt),
    @opt_sel=charindex('|sel|',@opt),
    @opt_quiet=charindex('|quiet|',@opt),
    @opt_del=charindex('|del|',@opt),
    @opt_source=charindex('|source|',@opt),
    @opt_result=charindex('|result|',@opt),
    @opt_status=charindex('|status|',@opt),
    @opt_detail=@opt_source|@opt_result|@opt_status,
    @purge=case when @opt_del=1 and left(@obj,2)!='0x' then 1 else 0 end,
    @testing=case when @tst is null then 1 else 0 end,
    -- other vars
    @file='%temp%\tmp_'+replace(newid(),'-','_')+'.txt',
    -- end commodity
    @end_declare=1
from fn__sym() -- constant/symbol source

if not @id is null and @purge=0 select @obj='%'

select
    -- statuses constants
    @sts_untested='??',
    @sts_passed='ok',
    @sts_error='!#',
    @sts_failed='ko',
    @sts_disappeared='--'

if not @tst is null
and (patindex(@non_sentence,@name)>0 or patindex(@non_word,@obj)>0)
    raiserror('wild char cannot be used when ins/upd a test',16,1)

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1
if object_id('tst') is null
    begin
    -- drop table tst drop view tst_list
    exec('
    create table tst(
        id int identity constraint pk_tst primary key,
        obj sysname not null,
        name sysname not null,
        code nvarchar(4000) not null,
        result nvarchar(max) not null,
        status nvarchar(max) not null,
        ins_dt datetime not null,
        last_run_dt datetime not null,
        first_run_ms bigint null,
        last_run_ms bigint null
        )
    create unique index ix_obj_name on tst(obj,name)
    ')
    end

-- ======================================================== second params chk ==

if cast(@opt_source as tinyint)+@opt_result+@opt_status+@opt_del>1
    raiserror('source, result,status and del cannot be specified together',16,1)

if (@opt_list=1 and not @obj is null)
or (not @id is null and (@opt_del|@opt_detail)=0)
    begin
    select
        dbo.fn__hex(id) id,
        obj,name,
        case
        when status=@sts_disappeared then 'disappeared'
        when status=@sts_untested then 'untested'
        when status=@sts_passed then 'passed'
        when status=@sts_error then 'error'
        else 'failed' -- containt the two results
        end as [status],
        ins_dt,last_run_dt,last_run_ms,first_run_ms
    into #tmp
    from tst
    where obj like isnull(@obj,'%') and name like isnull(@name,'%')
    and (@id is null or id=@id)

    if @opt_sel=0 exec sp__select_astext 'select * from #tmp order by 2,3'
    else select * from #tmp order by 2,3

    drop table #tmp
    goto ret
    end

if not @obj is null goto ac_ins_upd_run

-- default action not managed, show help
goto help

-- =============================================================== #tbls init ==
ac_ins_upd_run:

-- ===================================================================== body ==

-- scan tests and apply actions specified by parameters or options
declare cs cursor local for
    select
        id,obj,name,code,result
    from tst
    where obj like @obj and name like isnull(@name,'%')
    and (@id is null or id=@id)
    order by obj,name
open cs
while 1=1
    begin
    fetch next from cs into
        @id,@obj,@name,@code,@result

    if @@fetch_status!=0 and @testing=1 break

    select @disappeared=case when object_id(@obj) is null then 1 else 0 end

    -- if to delete or purge
    if @opt_del=1
        begin
        if @purge=1 and @disappeared=0
            raiserror('cannot purge tests of existing objects',16,1)
        delete from tst where id=@id
        if @@rowcount=0 raiserror('not found',16,1)
        exec sp__printf '-- deleted "%x|%s|%s"',@id,@obj,@name
        continue
        end

    -- list details of specific test
    if @opt_detail=1
        begin
        if @opt_source=1
            select @tmp=code from tst where id=@id
        if @opt_result=1
            select @tmp=result from tst where id=@id
        if @opt_status=1
            select @tmp=status from tst where id=@id
        if @opt_sel=0 exec sp__printsql @tmp
        else select line from fn__ntext_to_lines(@tmp,0)
        break -- only one test ha sense to show...
        end

    select @msg='|'+left(dbo.fn__hex(@id)+'|'+@obj+'|'+@name
                     +replicate(' ',0),77)

    if @disappeared=1
        begin
        update tst set
            last_run_dt=getdate(),status=@sts_disappeared
        where id=@id
        select @msg=@sts_disappeared+@msg
        end
    else
        begin
        -- execute the test and store results
        select @cmd='sqlcmd -W -u -E ' -- compact, unicode
                   +'-S "'+@@servername+'" '
                   +'-d "'+db_name()+'" '
                   +'-Q "'+isnull(@tst,@code)+'" '
                   +'-o '+@file

        select @tmp='',@d=getdate()
        insert @out(line) exec @ret=xp_cmdshell @cmd
        select @n=datediff(ms,@d,getdate())
        if @dbg>0
            select lno,line
            from (
                select 0 lno,@cmd as line
                union
                select lno,line from @out
                ) o
            order by lno

        if @ret!=0 raiserror(@err_osql,16,1)

        exec sp__file_read_stream @file,@tmp out,@fmt='unicode'

        -- delete temp file
        select @cmd='del /q '+@file
        exec @ret=xp_cmdshell @cmd,no_output

        if @tmp is null raiserror(@err_osql,16,1)
        if @dbg>0 exec sp__printsql @tmp

        if patindex('%Messaggio %, livello %, stato %',@tmp)>0
        or patindex('%Message %, level %, state %',@tmp)>0
        -- sqlcmd when errors happen
        or patindex('HResult %, level %, state %',@tmp)>0
        or patindex('HResult %, livello %, stato %',@tmp)>0
            select @status=@sts_error
        else
            select @status=case @testing
                           when 1 then @sts_passed else @sts_untested
                           end

        if not @id is null                  -- update test info
            begin

            if @testing=1 and @disappeared=0
                begin
                if @result=@tmp
                    select @msg=@status+@msg
                else
                    begin
                    if @status=@sts_error select @msg=@sts_error+@msg
                    else select @msg=@sts_failed+@msg
                    select
                        @status
                           =dbo.fn__prints('8<resulted',null,null,null,null)+@crlf
                           +@tmp+@crlf
                           +dbo.fn__prints('8<expected',null,null,null,null)+@crlf
                           +@result+@crlf
                           +dbo.fn__prints('8<',null,null,null,null)+@crlf
                    end
                end
            else
                select @msg=@status+@msg

            if @testing=1
                begin
                update tst set
                    status=@status,last_run_dt=getdate(),last_run_ms=@n
                where id=@id
                end
            else
                begin
                update tst set
                    code=isnull(@tst,@code),result=@tmp,status=@status,
                    last_run_dt=getdate(),last_run_ms=@n
                where id=@id
                exec sp__printf '-- updated "%s"',@name
                break; -- consider in the future a full update?
                end

            end -- update/run test

        else

            begin

            if @dbg>0 exec sp__printsql @result

            select @d=getdate(),@code=@tst,@result=@tmp
            insert tst(obj,name,code,result,status,ins_dt,last_run_dt,first_run_ms,last_run_ms)
            select @obj,@name,@code,@result,@status,@d,@d,@n,@n

            exec sp__printf '-- inserted "%s"',@name

            break

            end -- insert new test

        end -- not disappeared

        if @opt_quiet=0 raiserror(@msg,10,1)

    end -- cursor cs

close cs
deallocate cs

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:

exec sp__usage @proc,'
Scope
    create case test and store it into tst table;
    ofcourse can test itself

Output
    ST|NNNNNNNN|OBJ|NAME
    ST is the status code
        ??  untested......: just inserted
        ok  passed........: the output is the same
        !#  error.........: inside sql error
        ko  failed........: the output is changed
        --  disappeared...: the object do not exists
    NNNNNNNN is the hexadecimal value of id

Parameters
    return      0 for ok; -1 for help; en error code
    @obj        the name of object to test or list or delete (accept %)
                if an ID (0x...between '''') show one line (see option too)
    @name       name/description of the test to run/del (accept %)
    @tst        the test code if different from sp
    @opt        options
                list    get a list of tests with results
                quiet   do not print output
                sel     return data as select instead of print
                purge   willing to @obj, remove tests without existing object
                del     if @obj is 0x... delete the test
                source  if @obj is 0x... show lines of source
                result  if @obj is 0x... show lines of result
                status  if @obj is 0x... show lines of status

    @dbg        debug level
                1       show dbg info

Examples
'

if not object_id('tst') is null
    begin
    exec sp__printf '\n-- list of tests grouped by obj --'
    exec sp__select_astext
        'select obj,count(*) n from tst group by obj order by obj'
    end

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end try

-- =================================================================== errors ==
begin catch
if @@trancount > 0 rollback -- for nested trans see style "procwnt"

-- exec sp__printf 'quit:%d, @failed:%s',@quiet,@failed
-- print error_message()
exec @ret=sp__err @cod=@proc,@opt='ex'

return @ret
end catch   -- proc sp__test