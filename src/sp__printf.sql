/*  keep for MS compatibility
    l:see LICENSE file
    g:utility
    v:130606\s.zaglio: moved @force and @format_only into @opt
    v:130605\s.zaglio: added output of the result to @format,corrected help
    v:130424\s.zaglio: a small bug near leng>0 and resumed +1 of bug 130416
    v:130416\s.zaglio: a bug when called from printsql near crlf
    v:121010\s.zaglio: added {1}... markers
    v:110831\s.zaglio: a bug or misunderstanding near @format_only
    v:110705\s.zaglio: a bug near @tmp
    v:110607\s.zaglio: a bug near last \n
    v:110526\s.zaglio: a bug near last \n%s
    v:110518\s.zaglio: a bug near optimization
    v:110517\s.zaglio: a bug when more %s/d than supported
    v:110510\s.zaglio: escaped % in raiserror to exclude error 2787:Invalid format spec.
    v:110421\s.zaglio: used nvarchar(max) instead of ntext
    v:110314\s.zaglio: added split into 200 char's lines
    v:110312\s.zaglio: a semiremake of sp__printf to allow >4000 chars (mssql2k compatible)
    t:sp__printf_test
*/
CREATE proc [dbo].[sp__printf]
    @format nvarchar(max)=null out,
    @p1 sql_variant=null,
    @p2 sql_variant=null,
    @p3 sql_variant=null,
    @p4 sql_variant=null,
    @p5 sql_variant=null,
    @p6 sql_variant=null,
    @p7 sql_variant=null,
    @p8 sql_variant=null,
    @p9 sql_variant=null,
    @p0 sql_variant=null,
    @opt sysname=null,
    @dbg bit=null
    --,@err sysname=null    100106\s.zaglio: not so useful
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0
if not @opt is null select @opt=dbo.fn__Str_quote(@opt,'|')

-- ============================================================== declaration ==

declare
    @icrlf bit,@sep nvarchar(2),
    @p int,@j int,@i1 int,
    @crlf nvarchar(2),@macro nvarchar(4000),
    @cr nchar(1),@lf nchar(1),
    @tmp nvarchar(4000),
    @nm bit,                -- new markers
    @p1s nvarchar(4000),
    @p2s nvarchar(4000),
    @p3s nvarchar(4000),
    @p4s nvarchar(4000),
    @p5s nvarchar(4000),
    @p6s nvarchar(4000),
    @p7s nvarchar(4000),
    @p8s nvarchar(4000),
    @p9s nvarchar(4000),
    @p0s nvarchar(4000)

declare @out table(lno int identity primary key,line nvarchar(4000))

select @icrlf=0 -- not include crlf into splittings

declare @lines table (pos int primary key,leng int)
declare
    @i int,@n int,@k int,@st sysname,
    @bs int, -- buffer size or the width of output
    @format_only bit, @force bit, @test bit

select
    @bs=200,@dbg=isnull(@dbg,0),@crlf=crlf,@cr=cr,@lf=lf,
    @force=1-isnull(charindex('|print|',@opt),0),
    @format_only=isnull(charindex('|fo|',@opt),0),
    @test=isnull(charindex('|test|',@opt),0)
from dbo.fn__sym()

if @format is null goto help

-- optimization for empty strings
if @format=''
    begin
    if @test=0
        begin
        if @force=1 raiserror(@crlf,10,1) with nowait
        else print ''
        end
    insert @out select ''
    goto dispose
    end

if charindex('{1}',@format)>0
    begin
    select @nm=1
    select @p1s=isnull(convert(nvarchar(4000),@p1,126),'(null)')
    select @p2s=isnull(convert(nvarchar(4000),@p2,126),'(null)')
    select @p3s=isnull(convert(nvarchar(4000),@p3,126),'(null)')
    select @p4s=isnull(convert(nvarchar(4000),@p4,126),'(null)')
    select @p5s=isnull(convert(nvarchar(4000),@p5,126),'(null)')
    select @p6s=isnull(convert(nvarchar(4000),@p6,126),'(null)')
    select @p7s=isnull(convert(nvarchar(4000),@p7,126),'(null)')
    select @p8s=isnull(convert(nvarchar(4000),@p8,126),'(null)')
    select @p9s=isnull(convert(nvarchar(4000),@p9,126),'(null)')
    select @p0s=isnull(convert(nvarchar(4000),@p0,126),'(null)')
    end

-- optimization for one line
select @macro=substring(@format,1,@bs)
if datalength(@format)<=@bs
and charindex(@cr,@macro)=0 and charindex('\n',@macro)=0
    begin
    if @format_only=1
        begin
        if @force=1
            begin
            -- avoid error 2787 not catched by try
            select @tmp=replace(@macro,'%','%%')
            -- raiserror ('test %s and %%s',10,1) with nowait -- test (null) and (null)
            if @test=0 raiserror (@tmp,10,1) with nowait
            insert @out select @macro
            end
        else
            if @test=0 print @macro
        end
    else
        begin
        select @macro=replace(@macro,'\t',char(9))
        select @macro=replace(@macro,'%t',getdate())
        if @nm=1
            begin
            select @macro=replace(replace(@macro,'{1}',@p1s),'{2}',@p2s)
            select @macro=replace(replace(@macro,'{3}',@p3s),'{4}',@p4s)
            select @macro=replace(replace(@macro,'{5}',@p5s),'{6}',@p6s)
            select @macro=replace(replace(@macro,'{7}',@p7s),'{8}',@p8s)
            select @macro=replace(replace(@macro,'{9}',@p9s),'{0}',@p0s)
            end
        else
            begin
            select @macro=replace(@macro,'%d','%s')
            select @macro=dbo.fn__printf(@macro,@p1,@p2,@p3,@p4,@p5,@p6,@p7,@p8,@p9,@p0)
            end
        if @force=1
            begin
            select @tmp=replace(@macro,'%','%%')
            if @test=0 raiserror (@tmp,10,1) with nowait
            insert @out select @macro
            end
        else
            begin
            if @test=0 print @macro
            insert @out select @macro
            end
        end -- format
    goto dispose
    end -- less than @bs

declare @params table (id int identity(1,1), macro sql_variant)

-- ===================================================================== init ==

select @format_only=isnull(@format_only,0),@force=isnull(@force,1)

if @format_only=0
and not (
    @p1 is null and @p2 is null and @p3 is null and
    @p4 is null and @p5 is null and @p6 is null and
    @p7 is null and @p8 is null and @p9 is null and
    @p0 is null)
    begin
    insert @params(macro) select isnull(@p1,'(null)')
    insert @params(macro) select isnull(@p2,'(null)')
    insert @params(macro) select isnull(@p3,'(null)')
    insert @params(macro) select isnull(@p4,'(null)')
    insert @params(macro) select isnull(@p5,'(null)')
    insert @params(macro) select isnull(@p6,'(null)')
    insert @params(macro) select isnull(@p7,'(null)')
    insert @params(macro) select isnull(@p8,'(null)')
    insert @params(macro) select isnull(@p9,'(null)')
    insert @params(macro) select isnull(@p0,'(null)')
    end -- macros

-- ======================== identify row separator and create splitting table ==

select top 1 @i=charindex(@cr,@format),@j=charindex(@lf,@format)
if @i is null begin select @ret=-2 goto ret end

if @i>0 and @j=0 select @crlf=@cr
if @i=0 and @j>0 select @crlf=@lf
if @i=@j+1 select @crlf=@lf+@cr
-- else is @crlf

-- piece of code from sp__write_ntext_to_lines
select top 1 @i=1,@p=1,@j=1,@n=datalength(@format)/2
while 1=1
    begin
    select @i=charindex(@crlf,substring(@format,@j,4000))
    select @i1=charindex('\n',substring(@format,@j,4000))
    if @i1>0 and (@i1<@i or @i=0) select @i=@i1,@sep='\n'
    else select @sep=@crlf
    if @i=0
        begin
        -- if @dbg=1 exec sp__printf 'j:%d, i:%d, @n:%d',@j,@i,@n
        if @n>=@j/*+@lcrlf*/-1 insert @lines select @j,@n-@j+1
        break
        end

    -- if @dbg=1 exec sp__printf 'j:%d, i:%d',@j,@i
    if @icrlf=1 or @i-len(@sep)+1<0
        insert @lines select @j,@i
    else
        insert @lines select @j,@i-len(@sep)+1-- 130416\s.zaglio

    select @j=@j+@i+len(@sep)-1
    end -- while

-- ============================================================== print lines ==

if @dbg=1 select * from @lines

select @i=1 -- macro index
declare cs cursor local for
    select leng,substring(@format,pos,leng) line
    from @lines
    -- where leng>0
    order by pos
open cs
while 1=1
    begin
    fetch next from cs into @k,@macro
    if @@fetch_status!=0 break

    if @macro=''
        begin
        if @test=0 raiserror (@crlf,10,1) with nowait
        insert @out select ''
        continue
        end

    if @format_only=0
        begin
        select @macro=replace(@macro,'\t',char(9))
        select @macro=replace(@macro,'%t',getdate())
        if @nm=1
            begin
            select @macro=replace(replace(@macro,'{1}',@p1s),'{2}',@p2s)
            select @macro=replace(replace(@macro,'{3}',@p3s),'{4}',@p4s)
            select @macro=replace(replace(@macro,'{5}',@p5s),'{6}',@p6s)
            select @macro=replace(replace(@macro,'{7}',@p7s),'{8}',@p8s)
            select @macro=replace(replace(@macro,'{9}',@p9s),'{0}',@p0s)
            end
        else
            begin
            select @macro=replace(@macro,'%d','%s')

            select @i1=charindex('%s',@macro)
            while @i1>0
                begin
                if @dbg=1 raiserror('macro=%s, i1=%d, i=%d',10,1,@macro,@i1,@i)
                select top 1
                    @macro=  left(@macro,@i1-1)+
                             isnull(convert(nvarchar(4000),macro),'(null)')+
                             substring(@macro,@i1+2,4000)
                from @params where id=@i
                select @i1=charindex('%s',@macro,@i1+2),@i=@i+1
                if @i>11 goto err_out
                end
            end -- macro replace
        end -- format_only

    if @force=1 and @format_only=0
        begin
        -- raiserror has a limit of 200-255 chars
        if @k<=@bs
            begin
            -- print @macro
            select @tmp=replace(@macro,'%','%%')
            if @test=0 raiserror (@tmp,10,1) with nowait
            insert @out select @macro
            end
        else
            begin
            -- split into @bs char's line
            while @k>@bs
                begin
                select @i1=@bs
                while (@i1>0 and
                       not substring(@macro,@i1,1) in (' ','=',':','|',',',';')
                      )
                    select @i1=@i1-1
                if @i1=0 select @i1=@bs
                select @tmp=substring(@macro,1,@i1)
                insert @out select @tmp
                if @format_only=0 select @tmp=replace(@tmp,'%','%%')
                if @test=0 raiserror (@tmp,10,1) with nowait
                select @macro=substring(@macro,@i1+1,4000)
                select @k=len(@macro)
                end -- while k=len
            end
        end -- forse=1 and fmt_only=0
    else
        begin
        if @test=0 print @macro
        insert @out select @macro
        end

    end -- while of cursor
close cs
deallocate cs

select @ret=0

-- return printed strings to @format
dispose:
select @format = (
    (select line+@crlf
    from @out
    for xml path(''),type).value('.','nvarchar(max)')
    )

goto ret

-- ===================================================================== errs ==

err_out:    exec sp__err 'too many %?',@proc goto ret

-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    print a formatted string using raiserror(10) to ensure
    immediate output to well track the code execution.
    raiserror has a limit of 200/240 chars so the sp__printf
    break longs string into chunks trying to respect spaces
    and punctuations

See also
    sp__printframe,sp__printsql

Parameters
    @format         uses same C definitions with some limits
                    %s  marker for a string
                    %d  marker for a number
                    %t  expandend into date-time
                    {1},{2},{...} are specifically replaced by @p1,@p2,...
                    return the formatted string
    @p1..@p0        replaces %s,%d,...
    @opt            options
                    fo      format only :do not apply %s,%d,... replacement
                    print   print instead of raiserror to force output;
                            print is faster because enqueue but the output
                            do not appear after the sql command;
                            raiserror flush immediatelly the output buffer;
                    test    do not output, used by sp__printf_test or to format

'
select @ret=-1

ret:
return @ret
end -- sp__printf