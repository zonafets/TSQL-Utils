/*  leave this
    l:see LICENSE file
    g:utility
    v:110509\s.zaglio: a bug near last line without crlf
    v:110329\s.zaglio: added @nosrc
    v:110316\s.zaglio: added multi blob management
    v:100919\s.zaglio: managed empty #blob
    v:100515\s.zaglio: added @crlf to remove line terminator
    v:100514\s.zaglio: rewritten
    t:
        create table #src(lno int identity(10,10),line nvarchar(4000))
        exec sp__write_ntext_to_lines 'select blob from gamon.ramses.dbo.SETUP0H_WIKIDOCS where id=971'
        exec sp__print_table '#src'
        drop table #src
*/
CREATE proc [dbo].[sp__write_ntext_to_lines]
    @sqlfield nvarchar(4000)=null,
    @crlf bit=1,
    @nosrc bit=0,
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0
if @sqlfield is null and object_id('tempdb..#blob') is null goto help

declare
    @drop bit,
    @n int,@i int,@p int,@j int,@id int,
    @ncrlf nvarchar(2),@cr nchar(1),@lf nchar(1),
    @lcrlf int

declare @lines table (pos int primary key,leng int)

select @dbg=isnull(@dbg,0),@crlf=isnull(@crlf,1),@nosrc=isnull(@nosrc,0)

if object_id('tempdb..#blob') is null
    begin
    create table #blob(blob ntext)
    exec('insert #blob '+@sqlfield)
    select @drop=1
    end
else
    select @drop=0

select @ncrlf=crlf,@cr=cr,@lf=lf,@lcrlf=len(crlf)
from dbo.fn__sym()

declare cs cursor local for
    select id
    from #blob
    where 1=1
open cs
while 1=1
    begin
    fetch next from cs into @id
    if @@fetch_status!=0 break

    delete from @lines

    -- identify row separator
    select top 1 @i=charindex(@cr,blob),@j=charindex(@lf,blob)
    from #blob b
    where b.id=@id

    if @i is null begin select @ret=-2 goto ret end

    if @i>0 and @j=0 select @ncrlf=@cr
    if @i=0 and @j>0 select @ncrlf=@lf
    if @i=@j+1 select @ncrlf=@lf+@cr
    -- else is @ncrlf

    select top 1 @i=1,@p=1,@j=1,@n=datalength(blob)/2
    from #blob where id=@id

    if @dbg=1 exec sp__printf 'i=%d,n=%d,id=%d',@i,@n,@id

    while 1=1
        begin
        select top 1 @i=charindex(@ncrlf,substring(blob,@j,4000))
        from #blob b
        where b.id=@id

        if @i=0
            begin
            -- last pieces that do not end with crlf
            -- if @dbg=1 exec sp__printf 'j:%d, i:%d, @n:%d',@j,@i,@n
            if @n>@j/*+@lcrlf*/-1 insert @lines select @j,@n-@j+1
            break
            end
        -- if @dbg=1 exec sp__printf 'j:%d, i:%d',@j,@i
        if @crlf=1 or @i-@lcrlf+1<0
            insert @lines select @j,@i
        else
            insert @lines select @j,@i-@lcrlf+1
        select @j=@j+@i+@lcrlf-1
        end -- while

    if @dbg=1
        begin
        select pos,leng,substring(blob,pos,leng) line
        from #blob b,@lines
        where b.id=@id
        order by pos desc
        end
    else
        begin
        if object_id('tempdb..#src') is null or @nosrc=1
            select substring(blob,pos,leng) line
            from #blob b,@lines
            where b.id=@id
            order by pos
        else
            insert into #src
            select substring(blob,pos,leng) line
            from #blob b,@lines
            where b.id=@id
            order by pos
        end
    end -- while of cursor
close cs
deallocate cs


if @drop=1 drop table #blob

goto ret

help:
exec sp__usage @proc,'
Scope
    explode blobs into lines

Params:
    @sqlfiled must be a query that return a text/ntext field
              or can be null but must exists #blob
    @crlf     (default 1) leave line terminator; 0 remove it
    @nosrc    ignore #src and out to stdout to insert into @src etc.

    create table #blob(id int identity,blob ntext)
    create table #src(lno int identity(10,10),line nvarchar(4000))
'
select @ret=-1

ret:
return @ret
end -- proc sp__write_ntext_to_lines