/*  leave this due MS compatibility
    l:see LICENSE file
    g:utility
    v:090801\S.Zaglio:apply some code transformation
    t:
        create table #src (lno int identity(10,10),line nvarchar(4000))
        create table test_upzcode (id int, c nchar, v nvarchar(12), t ntext,t1[ntext],i int)
        exec sp__script 'test_upzcode',@out='#src'
        exec sp__script_reduce 12    -- 4=to unicode+8
        print '-----------------------------------'
        exec sp__script '#src'  -- print output
        print '-----------------------------------'
        drop table test_upzcode
        exec sp__recompile '#src',@dbg=1
        drop table #src
        drop table test_upzcode
*/
CREATE proc [dbo].[sp__script_reduce]
    @normalize tinyint=null,
    @step int=10,
    @dbg bit=0
as
begin
set nocount on
declare
    @sql nvarchar(4000),@msg nvarchar(4000),@proc sysname,
    @line nvarchar(4000),@i int,@n int,@crlf nchar(2),@j int,@m int,
    @t datetime,@keywords sysname,@replacers sysname,
    @replaced sysname,@keyword sysname,@replacer sysname,@exp sysname

select @proc='SP__SCRIPT_REDUCE'
if @normalize is null goto help

-- @normalize is used as integer but defined as bit for the future specialization

select @crlf=char(13)+char(10)

-- delete white lines
if (@normalize & 1)=1
    delete from #src where line is null

-- remove collates and constrains
if (@normalize & 2)=2
    update #src set line=dbo.fn__RegexReplace('\s(collate|constraint)\s[^\s]*','',line,1,1)

-- upsize nvarchar to nvarchar ad ntext to ntext and nchar to nchar
if (@normalize & 4)=4
    begin
    set @t=null
    /* todo:
    create function fn__word_find(@sentence nvarchar(4000),@word sysname,@lt sysname,@rt sysname) returns int
    create function fn__word_replace(@sentence nvarchar(4000),@word sysname,@replace sysname,@lt sysname,@rt sysname) returns nvarchar(4000)
    */

    select @keywords='varchar|char|text'
    select @replacers   ='(%tkn%,|'
                        +'(%tkn%)|'
                        +' %tkn% |'
                        +' %tkn%(|'
                        +'[%tkn%]|'
                        +'(%tkn%(|'
                        +char(9)+'%tkn%(|'
                        +' %tkn%,|'
                        +' %tkn%)|'
                        +' %tkn%'+char(13)+'|'
                        +char(9)+'%tkn%,'

    if @dbg=1 exec sp__elapsed @t out,'-- start convert to unicode:'
    select @i=1,@n=dbo.fn__str_count(@keywords,'|'),@m=dbo.fn__str_count(@replacers,'|')
    while (@i<=@n)
        begin
        select @keyword=dbo.fn__str_at(@keywords,'|',@i),@i=@i+1
        select @j=1
        while (@j<=@m)
            begin
            select @exp=dbo.fn__str_at(@replacers,'|',@j),@j=@j+1
            select @replacer=replace(@exp,'%tkn%',@keyword)
            select @replaced=replace(@exp,'%tkn%','n'+@keyword)
            -- exec sp__printf 'replacer=%s   replaced=%s',@replacer,@replaced
            update #src set line=replace(line,@replacer,@replaced)
            end -- while replacers
        end -- while keywords

    -- special replacement
    update #src set line=replace(line,'nvarchar(4000)','nvarchar(4000)')
    update #src set line=replace(line,'nchar(4000)','nchar(4000)')
    if @dbg=1 exec sp__elapsed @t out,'-- end in:'
    /*
    it looks like 60 times slower and difficult do find a correct regex
    update #src set line=dbo.fn__RegexReplace('(varchar|\[nvarchar])',' nvarchar ',line,1,1)
    if @dbg=1 exec sp__elapsed @t out,'-- varchar-->nvarchar:'
    update #src set line=dbo.fn__RegexReplace('(char|\[nchar])',' nchar ',line,1,1)
    if @dbg=1 exec sp__elapsed @t out,'-- char-->nchar:'
    update #src set line=dbo.fn__RegexReplace('(text|\[ntext])',' ntext ',line,1,1)
    if @dbg=1 exec sp__elapsed @t out,'-- text-->ntext:'
    update #src set line=replace(line,' nvarchar(4000)',' nvarchar(4000)')
    if @dbg=1 exec sp__elapsed @t out,'-- nvc8000-->4000:'
    */
    end

-- remove while line on top and bottom
if (@normalize & 8)=8
    begin
    select @i=min(lno),@n=max(lno) from #src
    while (@i<=@n)
        begin
        select @line=coalesce(line,'') from #src where lno=@i
        if @line in ('',@crlf,'GO') delete from #src where lno=@i else break
        select @i=@i+@step
        end
    while (@n>=@i)
        begin
        select @line=coalesce(line,'') from #src where lno=@n
        if @line in ('',@crlf,'GO') delete from #src where lno=@n else break
        select @n=@n-@step
        end
    end -- normalze 8

-- remove []
if (@normalize & 16)=16
    update #src set line=dbo.fn__RegexReplace('(\[|])','',line,1,1)

-- go..go
if (@normalize & 32)=32
    print 'todo'

-- remove go
if (@normalize & 64)=64
    update #src set line=null where line='GO'

goto ret

help:
select @msg ='@normalize can be a mix of:\n'
            +'\t1   delete null lines\n'
            +'\t2   remove collate and contraint clausees\n'
            +'\t4   upsize to unicode data type\n'
            +'\t8   remove white line on top and bottom\n'
            +'\t16  remove [] parentesis\n'
            +'\t64  remove GO lines (not compatible with memory compiling)\n'
exec sp__usage @proc,@extra=@msg
select @msg=null

ret:
if not @msg is null exec sp__printf @msg
end -- proc