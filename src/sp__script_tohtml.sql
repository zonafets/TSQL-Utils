/*  Keep this due MS compatibility
    l:see LICENSE file
    g:utility
    v:110621\s.zaglio: changed syntaxhl. for compatibility with ffox4
    v:110614\s.zaglio: adapted to new script group
    v:100612\s.zaglio: added margins
    r:100405\s.zaglio: todo: omit headers is exists; manage a mix
    v:100404\s.zaglio: htmlize the code in #src
    t:sp__script_tohtml 'sp__script_tohtml'
*/
CREATE proc [dbo].[sp__script_tohtml]
    @obj sysname=null,
    @dbg smallint=0                      -- enable print of debug info
as
begin
set nocount on
if @dbg>=@@nestlevel exec sp__printf 'level of debugging:%d',@@nestlevel
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0
declare @crlf nvarchar(2),@txt nvarchar(4000)
select @crlf=crlf from fn__sym()

if @obj is null and object_id('tempdb..#src') is null goto help

if object_id('tempdb..#src') is null
    begin
    create table #src(lno int identity,line nvarchar(4000))
    exec sp__script @obj
    end

create table #tmp (lno int identity(10,10),line nvarchar(4000))
select @txt='<link type="text/css" rel="stylesheet"
    href="css/sh/SyntaxHighlighter.css"></link>
<script language="javascript" src="js/sh/shCore.js"></script>
<script language="javascript" src="js/sh/shBrushTSql.js"></script>
</head>
<body marginwidth="4" marginheight="4" topmargin="4" leftmargin="4" rightmargin="4" bottommargin="4"
    onload="
        dp.SyntaxHighlighter.ClipboardSwf = ''js/sh/clipboard.swf'';
        dp.SyntaxHighlighter.HighlightAll(''code'');
        ">
<pre name="code" class="tsql">'
insert #tmp select token from dbo.fn__str_table(@txt,@crlf)
insert #tmp select line from #src order by lno
insert #tmp select '</pre>'
--insert #tmp select '</pre>'
insert #tmp select '</body></html>'

truncate table #src
insert #src select line from #tmp order by lno

drop table #tmp

if not @obj is null select line from #src order by lno
goto ret

-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    encapsulate #src code into html

Parameters
    #src    source code
    @obj    direct name of obj
'
select @ret=-1

ret:
return @ret
end -- sp__Script_tohtml