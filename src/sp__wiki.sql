/*  leave this
    l:see LICENSE file
    g:utility
    v:110316\s.zaglio: a small adapt to new #blob managment
    v:100514\s.zaglio: added code for automanual (see help)
    v:100424\s.zaglio: some small bugs
    v:100405\s.zaglio: added *new+*
    v:100328\s.zaglio: added special *img* tag
    v:100221\s.zaglio: interpret the @txt and write down into #src a coded document
*/
CREATE proc [dbo].[sp__wiki]
    @txt nvarchar(4000)=null,
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc='sp__wiki',@ret=0

if @txt is null goto help

declare
    @buffer nvarchar(4000),@crlf nvarchar(2),@crlf_len int,
    @n int,@i int,@line nvarchar(4000),@p int,@lno int,
    @code bit,@j int,@sum_pos int,@token sysname,
    @lp sysname,@rp sysname,@title sysname,
    @ptr binary(16),@lbegin int,@lend int

if not object_id(@txt) is null
    begin

    create table #blob(id int identity,blob ntext)
    insert #blob(blob) select ''

    select top 1 @ptr=textptr(blob) from #blob where id=1

    declare cs cursor local for
        select ctext from syscomments where id=object_id(@txt) order by colid
    open cs
    while 1=1
        begin
        fetch next from cs into @line
        if @@fetch_status!=0 break
        updatetext #blob.blob @ptr null null @line
        end
    close cs
    deallocate cs

    exec sp__write_ntext_to_lines @crlf=0 -- split blob into lines, removing end crlf

    select top 1 @lbegin=lno from #src
    where ltrim(rtrim(line)) in ('/*wiki','/* wiki')
    order by lno

    select top 1 @lend  =lno from #src
    where ltrim(rtrim(line)) in ('wiki*/','wiki */')
    order by lno desc

    delete from #src where lno<=@lbegin or lno>=@lend

    drop table #blob

    goto ret
    end -- automanual

create table #summary(lno int, lev int, line nvarchar(4000))
create table #tmp (lno int identity(10,10),line nvarchar(4000))

declare cs cursor local for
    select lno,line from #src order by lno

select @crlf=dbo.fn__crlf(),@crlf_len=len(@crlf)

-- remove 1st crlf
if left(@txt,@crlf_len)=@crlf select @txt=substring(@txt,@crlf_len,4000)

-- adjust crlf (mssql editor fakes)
select @txt=replace(@txt,@crlf,char(13))
select @txt=replace(@txt,char(10),char(13))

if @dbg=1 exec sp__printf '----------------------------------\n%s',@txt

if not left(@txt,2) in ('[#','[:')
    begin
    -- split to more lines
    select @n=dbo.fn__str_count(@txt,char(13))
    select @i=1
    while (@i<=@n)
        begin
        select @line=dbo.fn__str_at(@txt,char(13),@i)
        insert #src select rtrim(@line)
        select @i=@i+1
        end
    end
else
    begin
    if @txt in ('[:print:]','[:print.text:]')
        exec sp__print_table '#src'
    if @txt in ('[:print.html:]')
        begin

        -- find summary position
        select @sum_pos=lno from #src where line='[:summary:]'

        -- add end of line
        update #src set line=replace(line,char(13),'<br>'+@crlf)
        if @@error!=0 exec sp__printf '%s','!# error adding end of line'

        -- generate summary
        insert into #summary
        select lno,0,line from #src where lno>@sum_pos and left(line,1)='+'
        if @@error!=0 exec sp__printf '%s','!# error generating summary(0)'

        update #summary set lev=3,line=substring(line,4,4000) where left(line,3)='+++'
        if @@error!=0 exec sp__printf '%s','!# error generating summary(1)'
        update #summary set lev=2,line=substring(line,3,4000) where left(line,2)='++'
        if @@error!=0 exec sp__printf '%s','!# error generating summary(2)'
        update #summary set lev=1,line=substring(line,2,4000) where left(line,1)='+'
        if @@error!=0 exec sp__printf '%s','!# error generating summary(3)'

        -- add titles
        update #src set line='<h3><a name="'+substring(line,4,4000)+'">'+substring(line,4,4000)+'</a></h3>' where left(line,3)='+++'
        if @@error!=0 exec sp__printf '%s','!# error adding titles (1)'
        update #src set line='<h2><a name="'+substring(line,3,4000)+'">'+substring(line,3,4000)+'</a></h2>' where left(line,2)='++'
        if @@error!=0 exec sp__printf '%s','!# error adding titles (2)'
        update #src set line='<h1><a name="'+substring(line,2,4000)+'">'+substring(line,2,4000)+'</a></h1>' where left(line,1)='+'
        if @@error!=0 exec sp__printf '%s','!# error adding titles (3)'

        -- special replacer
        update #src set line=replace(line,'*new*','<img alt="New Icon" height="528" src="images/new-icon.jpg" '
                                         +'style="width: 30px; height: 20px" title="New Icon" width="592" />'+@crlf)
        if @@error!=0 exec sp__printf '%s','!# error in special replacer(1)'
        update #src set line=replace(line,'*new+*','<img alt="New Icon" height="528" src="images/new-icon.jpg" '
                                         +'style="width: 42px; height: 30px" title="New Icon" width="592" />'+@crlf)
        if @@error!=0 exec sp__printf '%s','!# error in special replacer(2)'

        -- add bold

        select @code=0

        open cs
        while 1=1
            begin
            fetch next from cs into @lno,@line
            if @@fetch_status!=0 break

            /*
            select @i=1,@l=len(@line),@
            while (@i<=@l)
                begin
                select @c=substring(@line,@i,1)
                if @c='[' select @token=@token+@c
                if @rule=0 and @c='*' select @rule=
            */

            select @token='[:code:'
            select @p=charindex(@token,@line)
            if @p>0
                select @line=left(@line,@p-1)+'<pre class="sh_sql">'
                            +substring(@line,@p+len(@token),4000),
                       @code=1

            -- select @code=@code+dbo.fn__occurrence(@line,'[')
            if @code>0 and left(ltrim(@line),1)=']'
                begin
                select @p=dbo.fn__charindex(']',@line,-1)
                if @p>0 select @line=left(@line,@p-1)+'</pre>'
                                    +substring(@line,@p+1,4000),
                               @code=0
                /*
                select @p=0
                if @code-dbo.fn__occurrence(@line,']')=1
                */
                end

            select @lp='%*[A-z,0-9]%',@rp='%[.,A-z,0-9]*%'
            select @p=patindex(@lp,@line)
            -- print patindex('%*[A-z,0-9]%','*test line')
            -- print patindex('%*[A-z,0-9]%','* test line')
            -- print patindex('%*[A-z,0-9]%','test)* line')
            while (@p>0)
                begin
                select @line=left(@line,@p-1)+'<b>'+substring(@line,@p+1,4000)
                select @p=patindex(@lp,@line)
                end
            -- print patindex('%[.,A-z,0-9]*%','test line.*')
            select @p=patindex(@rp,@line)
            while (@p>0)
                begin
                select @line=left(@line,@p)+'</b>'+substring(@line,@p+1,4000)
                select @p=patindex(@rp,@line)
                end
            update #src set line=@line where lno=@lno
            if @@error!=0 exec sp__printf '!# error updating\n%s',@line
            end -- lines
        close cs

        -- replace summary
        select @n=count(*) from #summary
        if not @sum_pos is null and @n>0
            begin
            truncate table #tmp
            insert #tmp select line from #src
            where lno<@sum_pos order by lno
            insert #tmp select
                replicate('&nbsp;',lev)+'<a href="#'+line+'">'+line+'</a>'
            from #summary
            if @@error!=0 exec sp__printf '%s','!# error updating summary (1)'
            insert #tmp select line from #src
            where lno>@sum_pos order by lno
            if @@error!=0 exec sp__printf '%s','!# error updating summary (2)'
            end -- summary
        truncate table #src
        insert #src select line from #tmp order by lno

        -- incapsulate into html and print
        select line from (
        select -100 lno,'<html>' line union
        select -099 lno,'<head>' line union
        -- from: http://shjs.sourceforge.net/doc/documentation.html
        -- or: http://softwaremaniacs.org/media/soft/highlight/test.html
        select -098 lno,'<script type="text/javascript" src="hl/js/sh_main.min.js"></script>' line union
        select -097 lno,'<script type="text/javascript" src="hl/lang/sh_sql.js"></script>' line union
        select -096 lno,'<link type="text/css" rel="stylesheet" href="hl/css/sh_acid.min.css">' line union
        select -095 lno,'</head>' line union
        select -094 lno,'<body onload="sh_highlightDocument();">' line union
        select -093 lno,'<pre>' line union
        select lno,line from #src union
        select 1E10 lno,'</pre>' line union
        select 2E20 lno,'</body></html>' line
        ) ssrc order by lno
        end -- if @txt in ('[:print.html:]')
    end -- left(@txt,2) in ('[#','[:')

deallocate cs

goto ret

help:
exec sp__usage @proc,'
Parameters
    @txt    is the text to add to #src

            if exist an object with name @txt, the source will be scanned
            to find a block between "/*wiki" and "wiki*/"

            So to write an sp with automanual:

                create table #src(lno int identity,line nvarchar(4000))
                exec sp__wiki @proc  -- myself
                exec sp__wiki ''[:print.text]''
                drop table #src
                /*wiki
                ....
                wiki*/

Wiki rules
    * a crlf keep the paragraph rogether
    * a "."+crlf become a <br>
    * 1st crlf in @txt is removed
    * a "."+space+crlf become a single paragraph
    * [:lng.XXX: ... ]  set syntax highligher for this language
    * [:print:],[:print.text:] compile the doc and print it as text
    * [:print.html:] compile and print with html tags
'

ret:
return @ret
end -- sp__wiki