/*
    l:see LICENSE file
    g:utility
    v:100228\s.zaglio: added strip of space and condition on comment
    v:091018\s.zaglio: remove comments from @sql
    t:
        declare @sql nvarchar(4000)  select @sql=''
        create table #src (lno int identity(10,10),line nvarchar(4000))
        exec sp__script 'fn__sql_strip',@out='#src'
        select @sql=@sql+line+char(13)+char(10) from #src order by lno
        print @sql
        print '------------------------------------------------------'
        print dbo.fn__sql_strip(@sql,0)
        print '------------------------------------------------------'
        print dbo.fn__sql_strip(@sql,1)
        drop table #src
    t:sp__find 'fn__sql_strip'
*/
CREATE function [dbo].[fn__sql_strip](
    @sql nvarchar(4000),
    @comments bit=null
)
returns nvarchar(4000)
as
begin

declare @crlf nchar(2),@cr nchar(1),@lf nchar(1),@tab nchar(1)
select @crlf=crlf,@cr=cr,@lf=lf,@tab=tab from dbo.fn__sym()


select @sql=replace(@sql,@cr,' ')
select @sql=replace(@sql,@lf,' ')      -- newline
select @sql=replace(@sql,@tab,' ')       -- tab
select @sql=ltrim(rtrim(@sql))
while (charindex('  ',@sql)>0) select @sql=replace(@sql,'  ',' ')

if not @comments is null
    begin
    -- this bit strips out block comments. we need to strip them out before
    -- single line comments (like this one), because you could theoretically have
    -- a block comment like this:
    /* my comment
    -- is malformed */

    -- variables to hold the first and last character's positions in the "next" block
    -- comment in the string
    declare @codeblockstart int, @codeblockend int
    set @codeblockstart = patindex('%/*%', @sql)

    -- loop as long as we still have comments to exorcise ;)
    while @codeblockstart > 0
    begin
    -- grab the last character in the code block by searching for the first incidence
    -- of */ (close comment) in the string.
    set @codeblockend = patindex('%*/%', @sql)

    -- "cut" out the comment by concatenating everything the the "left" and "right"
    -- of the comment
    set @sql = left(@sql, @codeblockstart - 1)
    + right(@sql, len(@sql) - (@codeblockend + 1))

    -- fetch the first character's position in the next comment block, if there is one.
    set @codeblockstart = patindex('%/*%', @sql)
    end

    -- once code blocks are out, we can remove any lines commented by double dashes (like this one)
    -- variables to hold the first and last character's position in the "next" code block.
    declare @doubledashstart int, @doubledashlineend int

    -- grab the first double-dash (if there is one)
    set @doubledashstart = patindex('%--%', @sql)
    while @doubledashstart > 0
    begin
    -- search for the first "new line" after the first "double dash"
    -- we can use nchar(13) and nchar(10) to find the new line.
    -- since patindex doesn't have a "start" character, and we need to find
    -- the first new line after the double dash, we will search all characters
    -- after the double dash for the new line.
    set @doubledashlineend = patindex('%' + nchar(13) + nchar(10) + '%',
    right(@sql, len(@sql) - (@doubledashstart)))
    + @doubledashstart

    -- "cut" out the comment, as was done with the block comments.
    set @sql = left(@sql, @doubledashstart - 1) +
    right(@sql, len(@sql) - @doubledashlineend)

    -- check for the next incidence of a double dash, if there is one.
    set @doubledashstart = patindex('%--%', @sql)
    end

    -- return the uncommented string
    end -- comments

return @sql
end -- fn__sql_strip