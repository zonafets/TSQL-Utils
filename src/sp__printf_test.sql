/*  leave this
    l:see LICENSE file
    g:utility
    k:sp__printf,test
    v:130725\s.zaglio: updated
    v:130607\s.zaglio: final ok message and managed option
    v:130606\s.zaglio: done
    r:130605\s.zaglio: test for sp__printf
    t:sp__printf_test @opt='run',@dbg=1
    t:sp__printf_test @opt='run|managed',@dbg=1
*/
CREATE proc sp__printf_test
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
-- @@nestlevel is >1 if called by other sp

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
    @id int,@tst nvarchar(max),@rst nvarchar(max),@otst nvarchar(max),
    @p1 sql_variant,@p2 sql_variant,@p3 sql_variant,@p4 sql_variant,
    @run bit,@ok bit,@v nvarchar(max),@i int,@crlf nvarchar(2),
    @n int,@nok int,@managed bit,@d datetime

declare @test table (
    id int,
    tst nvarchar(max),
    p1 sql_variant null,
    p2 sql_variant null,
    p3 sql_variant null,
    p4 sql_variant null,
    opt sysname null,
    rst nvarchar(max)
    )

-- =========================================================== initialization ==
select
    @nok=0, @n=0,
    @crlf=crlf,
    @run=isnull(charindex('|run|',@opt),0),
    @managed=isnull(charindex('|managed|',@opt),0),
    @d=getdate()
from fn__sym()

-- ======================================================== second params chk ==
-- =============================================================== #tbls init ==

-- ===================================================================== body ==

insert @test(id,tst,rst)
select 10,
'simple test',
'simple test'

insert @test(id,tst,rst)
select 20,
'line one\nline two',
'line one
line two'

insert @test(id,tst,rst)
select 30,
'line one\n\nline two\n',
'line one

line two
'

insert @test(id,tst,rst)
select 40,
'',
''

insert @test(id,tst,p1,p2,p3,rst)
select 50,
'today:%t\np1=%s\np2=%d\np3=%s',1,'two',3,
'today:%
p1=1
p2=two
p3=3'

insert @test(id,tst,opt,rst)
select 60,'test %s format %d only %t','fo',
'test %s format %d only %t'

insert @test(id,tst,p1,p2,rst)
select 70,'%s\n%s','test1','test2',
'test1
test2'

insert @test(id,tst,p1,p2,p3,rst)
select 80,'test {1}\ntest {2}','t1','t2','t3',
'test t1
test t2'

insert @test(id,tst,p1,p2,rst)
select 84,'test (%s,%s)','%drop%','%drop%',
'test (%drop%,%drop%)'

insert @test(id,tst,p1,rst)
select 85,'hex test %x',-1,
'hex test 0xffffffff'

insert @test(id,tst,p1,rst)
select 86,'hex test %x',123123123123123,
'hex test 0x0f000001b37304d6fa6f0000'

insert @test(id,tst,p1,p2,p3,p4,rst)
select 87,'%s%s%s%s','test(','',12,')',
'test(12)'

insert @test(id,tst,p1,p2,p3,rst)
select 88,'%%%s%%%s%%%s%%','test(','',')',
'%test(%%)%'

-- mega test
select @i=10000,@v='start\n'
while (@i>0) select @v=@v+'01234567890\n',@i=@i-1
select @v=@v+'end'
insert @test(id,tst,rst)
select 90,@v,replace(@v,'\n',@crlf)

-- test with lines of more than 200 chars
select @v='start\n'
select @i=20
while (@i>0) select @v=@v+'0123456789;',@i=@i-1
select @i=20
while (@i>0) select @v=@v+'01234567890',@i=@i-1
select @v=@v+'\nend'
insert @test(id,tst,rst)
select 100,@v,
'start
0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;0123456789;
0123456789;0123456789;
01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001
end'

if @run=0 goto help

-- sp__printf_test @dbg=2

-- the output of printf add virtually the last crlf of the out of console
update @test set rst=rst+@crlf
-- ================================================================ run tests ==

declare cs cursor local for
    select id,tst,p1,p2,p3,p4,opt,rst from @test
open cs
while 1=1
    begin
    fetch next from cs into @id,@otst,@p1,@p2,@p3,@p4,@opt,@rst
    if @@fetch_status!=0 break

    select @n=@n+1

    if @dbg>0 exec sp__prints @id
    select @tst=@otst

    select @opt=case when @managed=1 or @dbg=0 then 'test|' else '' end
               +isnull(@opt,'')
    exec sp__printf @tst out,@p1,@p2,@p3,@p4,@opt=@opt

    select @ok=0
    if @tst is null
        begin
        select @err_msg='error in sp__printf for %s'
        raiserror(@err_msg,11,1,@otst)
        if @ret=0 exec @ret=sp__err @err_msg,@opt='noerr'
        end

    if charindex('%t',@otst)>0 and charindex('|fo',@opt)=0
        begin
        if @dbg>2 exec sp__printf '-- tst like'
        if @tst like @rst select @ok=1
        end
    else
        begin
        if @dbg>2 exec sp__printf '-- tst eq'
        if @tst=@rst select @ok=1
        end

    if @ok=0
        begin
        select @err_msg='^^ failed test %d'
        select @ret=@id
        if @managed=1 break
        raiserror(@err_msg,11,1,@id)
        if @dbg>0
            begin
            select @tst=replace(replace(@tst,char(13),'\r'),char(10),'\n'),
                   @rst=replace(replace(@rst,char(13),'\r'),char(10),'\n')
            raiserror('^^ test %d:"%s" failed with:"%s"',11,1,@id,@tst,@rst)
            end
        end
    else
        select @nok=@nok+1

    end -- cursor cs
close cs
deallocate cs

if @dbg>0 exec sp__prints 'end'

if @managed=0 exec sp__elapsed @d,'%d/%d tests passed',@v1=@nok,@v2=@n

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    check know formats of sp__printf

Parameters
    @opt        options
                run     run tests
                managed when used by caller, stop at 1st error and return the id
    @dbg        1=show passages info
                3=show dbg info

'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end -- proc sp__printf_test