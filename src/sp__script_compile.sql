/*  leave this
    l:see LICENSE file
    g:utility,script
    v:130605\s.zaglio: removed printf deprecated parameters
    v:120920\s.zaglio:ms2k5 version because some strange @crlf loses
    v:111205\s.zaglio:added noalter option
    v:110415\s.zaglio:added error return value
    v:110324\s.zaglio:added @opt and dep
    v:110213\s.zaglio:about automatic alter
    v:111130\s.zaglio:improved recodnition of "create xxxx"
    v:100919.1000\s.zaglio:improved help and more compatible with mssql2k
    v:100703\s.zaglio:do not alter create table
    v:100612\s.zaglio:more help
    v:100424\s.zaglio:added -- noalter as pragma option
    v:100405\s.zaglio:retested compile of @obj (saving original before!!!)
    v:100404\s.zaglio:added control for 100 blocks and null lines and chunking
    v:100328\s.zaglio:renamed old sp__script_recompile & integrated sp__Scrit_run
    v:100118\s.zaglio:added to group script
    v:091018\s.zaglio: recompile a big procedure passe with #src
    t:sp__script_compile 'sp__script_compile',@dbg=1
    t:sp__script_compile 'sp__script_table',@dbg=1
    t:exec sp__script_compile 'flags',@opt='dep'
    t:exec sp__script_trace_db 'install'
*/
CREATE proc [dbo].[sp__script_compile]
    @obj sysname=null,      -- an sp/function/view to recompile or #src
    @opt sysname=null,
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select  @proc=object_name(@@procid),@ret=0,
        @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

declare
    @i int,@n int,@s int,@line nvarchar(4000),@id int,
    @crlf nchar(2),@cr nchar(1),@m int,@block nvarchar(4000),
    @trace bit,@noalter bit

declare @src table(lno int identity(1,1) primary key, line nvarchar(4000))

select
    @crlf=crlf,@cr=cr,
    @trace=charindex('|trace|',@opt),
    @noalter=charindex('|noalter|',@opt)
from dbo.fn__sym()

if @obj is null
and not object_id('tempdb..#src') is null
    select @obj='#src'

if @obj is null goto help

-- read first line to determine if is a single or multiple script
if @obj='#src'
    begin
    declare cs cursor local for
        select coalesce(line,N'')
        from #src
        order by lno
    open cs

    fetch next from cs into @line

    if @line like '--%script%'
        begin                                   -- multi script
        while 1=1
            begin
            fetch next from cs into @line
            if @@fetch_status!=0 break

            if @dbg=1 exec sp__printf @line
            exec(@line)
            if @@error!=0
                begin
                exec sp__printf 'error in:\%s',@line
                select @ret=-2
                goto ret
                end
            end -- while
        close cs
        deallocate cs
        goto ret
        end -- execute line by line

    -- group lines of single script into blocks
    select @block='',@n=0,@i=0
    while 1=1
        begin
        select @i=@i+1
        if @dbg=1 exec sp__printf '%d %s',@i,@line
        if len(@block)+len(@line)+len(@crlf)>4000
            begin
            insert @src select @block
            select @block='',@n=@n+1
            end
        select @block=@block+@line+@crlf

        fetch next from cs into @line
        if @@fetch_status!=0 break
        end -- while

    if len(@block)>0    -- last chunk
        begin
        insert @src select @block
        select @block='',@n=@n+1
        end

    if @n>100 goto err_max

    close cs
    deallocate cs
    goto run
    end -- load lines of single script into blocks


-- used as store for sequence of objects
create table #dep(
    id int identity,
    uses bit null,
    obj sysname,
    buildin sysname null,
    usr sysname null,
    comment sysname null,
    [level] int null
    )

if charindex('|dep|',@opt)>0
    exec sp__script_dep @obj,@opt='uses'
else
    insert #dep(obj) select @obj

if @dbg=1 select * from #dep order by id

declare objs cursor local for
    select obj
    from #dep
    order by id
open objs
while 1=1
    begin
    select @obj=null
    fetch next from objs into @obj
    if @@fetch_status!=0 break

    select @id=object_id(@obj)
    if @dbg=1 exec sp__printf '\n## fetched obj "%s" id "%d"',@obj,@id
    if @trace=1 exec sp__printf '-- recompiling: %s',@obj

    -- load obj source info memory table
    if @id is null goto err_onf

    delete from @src

    insert into @src(line)
    select [text]
    from syscomments
    where id=@id
    order by colid

    -- change create into alter
    select top 1 @i=lno,@line=line from @src order by lno

    declare @key1 sysname,@key2 sysname
    select  @key1=case when pos=1 then token else @key1 end,
            @key2=case when pos=2 then token else @key2 end
    from dbo.fn__str_table(@line,'') where pos in (1,2)

    -- specific generated code so existance is checked by caller
    select top 1 @n=lno,@line=line,@i=charindex(@crlf+'create ',@line)+len(@crlf)
    from @src where charindex(@crlf+'create ',@line)>0 order by lno

    declare @ln nvarchar(4000)
    select @ln=substring(@line,@i,charindex(@crlf,@line,@i)-@i)

    if @dbg=1 exec sp__printf '-- recompile: chg create to alter at line:%d, pos:%d, ln:%s',@n,@i,@ln
    /*if @dbg=1 begin
        -- sp__script_compile 'sp__script_compile',@dbg=1
        exec sp__printf 'i=%d, n=%d',@i,@n
        print substring(@line,@i,20)
    end*/
    select  @key1=case when pos=1 then token else @key1 end,
            @key2=case when pos=2 then token else @key2 end
    from dbo.fn__str_table(@ln,'')
    where pos in (1,2)

    select @line=substring(@line,1,@i-1)
                +'alter'+substring(@line,@i+len(@key1),4000)

    if @dbg=1 exec sp__printf 'k1:%s, k2:%s, ln:%s',@key1,@key2,@ln
    select @ln=substring(@line,@i-1,charindex(@crlf,@line,@i)-@i)

    update @src set line=@line
    where lno=@n

    if @dbg=1 exec sp__printf '@i=%d',@i

    run:
    /*
        select * into #tmp from @src order by lno
        exec sp__print_table '#tmp'
        return 0
    */

    /* this generate the code to execute a source bigger than 4000 chrs
    declare @sql nvarchar(4000),@nullize nvarchar(4000)
    declare @i int,@n int
    exec sp__printf 'select top 1 @i=lno from @src order by lno'
    select @i=0,@n=99,@sql=''
    while @i<=@n
        begin
        exec sp__printf 'declare @s%d nvarchar(4000);select @s%d=null,@s%d=line from @src where lno=@i+%d',
                        @i,@i,@i,@i
        select @sql=@sql+'@s'+convert(sysname,@i)+
               case when @i<@n then '+' else '' end+
               case when @i%12=0 then nchar(13)+nchar(10) else '' end
        select @i=@i+1
        end
    exec sp__printf ''
    exec sp__printf 'if @dbg=1 exec sp__printsql @s0'
    exec sp__printf ''
    exec sp__printsql 'exec(',@sql,')'
    -- copy and paste the result below, after close of comment
    */
    declare @sql nvarchar(max)
    select @sql= ''
    select @sql=@sql+line from @src order by lno
    if @sql is null goto err_cod
    exec(@sql)
    select @ret=@@error
    if @ret!=0 exec sp__printsql @sql

    if @obj='#src' goto ret
    end -- while objs

dispose:
close objs
deallocate objs
goto ret

-- =================================================================== errors ==

err_max:    exec sp__err '%d blocks but max 100 admitted',@proc,@p1=@m
            goto ret
err_onf:    exec @ret=sp__err 'object not found',@proc
            goto ret
err_cod:    exec @ret=sp__err 'inside code error',@proc
            goto ret

-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    Recompile an object or compile a source given in #src
    if 1st line is "-- script" esecute each line present in #src
    if 1st line is "-- noalter" do not automatically change create into alter
                                (see also option "noalter")

Parameters
    @obj    name of proc,view,function, etc.
    @opt    options
            dep         do not recompile @obj but all objects that use it
                        (sp__script_dep ''tids'',@opt=''uses'')
            noalter     do not automatically change

Table
    create table #src(lno int identity,line nvarchar(4000))
    insert #src(line) select ''-- scripts''
    insert #src(line) select ''print ''''row1''''''
    insert #src(line) select ''print ''''row2''''''
    exec sp__script_compile
    truncate table #src
    insert #src(line) select ''create proc sp_test as print ''''sp_test''''''
    exec sp__script_compile
    exec sp_test
    drop proc sp_test
    drop table #src
'
select @ret=-1

ret:
return @ret
end -- [sp__script_compile]