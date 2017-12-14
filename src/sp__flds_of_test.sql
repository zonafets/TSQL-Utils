/*  leave this
    l:see LICENSE file
    g:utility
    r:130730\s.zaglio: test fn__flds_of
*/
CREATE proc sp__flds_of_test
as
begin
set nocount on
declare @ret int,@proc sysname
select @ret=0,@proc=object_name(@@procid)

declare
    @d datetime,@i int,@flds nvarchar(4000),
    @id int,@tbl sysname,@sep char,@exclude nvarchar(4000),
    @result nvarchar(4000),@st sysname,@new_result nvarchar(4000)

if not object_id('tst_fn__flds_of') is null drop table tst_fn__flds_of
create table tst_fn__flds_of(
    id int identity,
    a int, b bit, c nvarchar(max),
    [_0] uniqueidentifier
    )
select * into #tst_fn__flds_of from tst_fn__flds_of

declare @test table(
    id int primary key,
    tbl sysname,
    sep char,
    exclude sysname null,
    result nvarchar(4000)
    )

insert @test select 1,'#tst_fn__flds_of',',',null,'id,a,b,c,_0'
insert @test select 2,'#tst_fn__flds_of',',','id,a','b,c,_0'
insert @test select 3,'#tst_fn__flds_of',',','%id%','a,b,c,_0'
insert @test select 4,'tst_fn__flds_of',',','a,%id%','b,c,_0'
insert @test select 5,'unk',',',null,null

declare cs cursor local for select id,tbl,sep,exclude,result from @test
open cs
while 1=1
    begin
    fetch next from cs into @id,@tbl,@sep,@exclude,@result
    if @@fetch_status!=0 break

    select @new_result=dbo.fn__flds_of(@tbl,@sep,@exclude)
    if @new_result=@result
    or @new_result is null and @result is null
        select @st='ok' else select @st='ko'
    exec sp__printf '%d:%s\nexpected:%s\nresult:%s',
                    @id,@st,@result,@new_result
    if @st='ko' select @ret=1

    end -- cursor cs
close cs
deallocate cs

exec sp__printf ''
exec sp__elapsed @d out
select @i=1000
while @i>0
    select  @flds=dbo.fn__flds_of('tst_flds_of',',',null),
            @i=@i-1
exec sp__elapsed @d out,'after 1000 loops of v:120413 with ident'
select @i=1000
while @i>0
    select  @flds=dbo.fn__flds_of('tst_flds_of',',','%id%'),
            @i=@i-1
exec sp__elapsed @d out,'after 1000 loops of v:120413 without ident'
-- before 120413: 1s 63ms
-- after 120413: 1s 540ms and 2s 433ms without

drop table #tst_fn__flds_of
drop table tst_fn__flds_of

if @ret!=0 exec sp__err 'test failed',@proc

return @ret
end -- sp__flds_of_test