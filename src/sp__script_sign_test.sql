/*  leave this
    l:see LICENSE file
    g:utility
    v:131123\s.zaglio: adapted to new fn__script_sign
    v:130923\s.zaglio: added help of fn__Script_sign
    v:130730,130729\s.zaglio: test fn__script_sign
    t:select dbo.fn__script_sign('fn__script_info_tags',null)   -- 105529698.0000
    t:select dbo.fn__script_sign('fn__script_info_tags',1)      -- 131129.0000
    t:select dbo.fn__script_sign('fn__script_info_tags',4)      -- 1796022540.0000
    t:select dbo.fn__script_sign('fn__script_info_tags',8)      -- 105529698.0000
*/
CREATE proc sp__script_sign_test
as
begin
set nocount on
declare
    @ret int,@proc sysname
select @ret=0,@proc=object_name(@@procid)
declare
    @id int,@obj sysname,@detail tinyint,
    @result numeric(14,4),@des sysname,
    @new_result numeric(14,4),@st sysname

declare @t table(
    id int,
    obj sysname,
    detail tinyint,
    result numeric(14,4),
    des sysname
    )
insert @t
select 1,'tst_fn__script_sign',null,141296445.0000,'rows only(!)'
union
select 2,'tst_fn__script_sign',1,755913805.0000,'with idx'
union
select 3,'tst_fn__script_sign',4,2136238363.0000,'as (!)-names'
union
select 4,'tst_fn__script_sign',8,577207619.0000,'with charset&collate'

union
select 5,'sp__script_sign_test',null,0.0000,'header'
union
select 6,'sp__script_sign_test',1,131123.0000,'body'
union
select 7,'sp__script_sign_test',4,0.0000,'types only'
union
select 8,'sp__script_sign_test',8,0.0000,'with charset&collate'

union
select 9,'fn__script_sign_test',null,974999305.0000,'header'
union
select 10,'fn__script_sign_test',1,131123.0000,'body'
union
select 11,'fn__script_sign_test',4,443965265.0000,'types only'
union
select 12,'fn__script_sign_test',8,974999305.0000,'with charset&collate'

exec sp__printf '-- test fn__script_sign correct results'

if not object_id('tst_fn__script_sign') is null
    drop table tst_fn__script_sign
exec('
create table tst_fn__script_sign(
    a int,
    b sysname collate Latin1_General_CI_AS null
    )
create index ix_tst_fn__script_sign_a on tst_fn__script_sign(a)
')

if not object_id('fn__script_sign_test') is null
    drop function fn__script_sign_test
exec('/*    leave this
    v:131123\s.zaglio: test creation
    */
create function fn__script_sign_test(@a int, @b sysname)
returns table
as
return select cast(1 as int) as a,cast(''b'' as sysname) as b
union  select @a,@b
')

declare cs cursor local for
    select id,obj,detail,result,des
    from @t
open cs
while 1=1
    begin
    fetch next from cs into @id,@obj,@detail,@result,@des
    if @@fetch_status!=0 break

    select @new_result=dbo.fn__script_sign(@obj,@detail)
    if @new_result=@result
        select @st='ok' else select @st='ko'
    exec sp__printf 'test %d:%s, %s, expected:%s, given:%s',
                    @id,@st,@obj,@result,@new_result
    if @st='ko' select @ret=1

    end -- cursor cs
close cs
deallocate cs

if not object_id('tst_fn__script_sign') is null
    drop table tst_fn__script_sign
if not object_id('fn__script_sign_test') is null
    drop function fn__script_sign_test

if @ret!=0 exec @ret=sp__err 'test failed',@proc

exec sp__printf ''
exec sp__usage @proc,'
Scope
    test fn__script_sign and give help for fn

Parameters
    @obj    name of object
    @detail specification of what it calculate the signature
            * details for table/sp/fn/views
            bit_val  meaning
            0/null   table columns or params of sp/fn, without defaults
            1        table columns with index or params of sp/fn with body
            2        table columns or params of sp/fn without names, without defaults
            4        table columns with index or params of sp/fn without names
            8        same as previous with charset&collate info
            * details for jobs
            0/null   names/status of jobs
            1        names/status of jobs with names,commands,flags,outfile of steps
            2        status of jobs
            6        status of jobs with commands,flags,outfile of steps without names
'

return @ret
end -- sp__script_sign_test