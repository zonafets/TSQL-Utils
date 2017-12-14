/*  leave this
    g:utility
    v:120528\s.zaglio: extract only what change
    t:
        select * from fn__str_unpattern('
        Messaggio 50000, livello 16, stato 1, procedura sp__err, riga 101
        error(-811561914) "local object "FN_GET_2OF5_CHECKDIGIT" is different" in "sp__script_alias"
        Messaggio 50000, livello 16, stato 1, procedura sp__err, riga 102
        error(-811561914) "local object "FN_GET_3OF9_CHECKDIGIT" is different" in "sp__script_alias"
        Messaggio 50000, livello 16, stato 1, procedura sp__err, riga 103
        error(-811561914) "local object "FN_GET_ID_ENTITY_FROM_CD_ERP_SHIPMENT" is different" in "sp__script_alias"
        Messaggio 50000, livello 16, stato 1, procedura sp__err, riga 103
        error(-811561914) "local object "SP_MANAGE_MAIL_QUEUE" is different" in "sp__script_alias"
        Messaggio 50000, livello 16, stato 1, procedura sp__err, riga 103
        error(-811561914) "local object "SP_REFRESH_VIEWS" is different" in "sp__script_alias"
        ','[0-9]%','unlike') -- excludes 101 and 102

*/
create function fn__str_unpattern(
    @blob ntext,            -- text
    @filter sysname,        -- value for optional condition
    @opt sysname            -- conditions
    )
returns @t table(lno int,line nvarchar(4000))
as
begin

declare
    @drop bit,
    @i int,@j int,@l int,@n int,@p int,
    @ncrlf nvarchar(2),@cr nchar(1),@lf nchar(1),
    @lcrlf int,@dbg bit,
    @line nvarchar(4000),@lno int,
    @diff int

select @dbg=0

declare @words table (word sysname)
declare @src table (lno int identity primary key,line nvarchar(4000))

select
    @ncrlf=crlf,@cr=cr,@lf=lf,
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
from fn__sym()

insert @src select ltrim(rtrim(line)) from fn__ntext_to_lines(@blob,0)

-- delete all identic lines
delete from @src
where line in (
    select line from @src group by line having count(*)>1
    )

-- isolate duplicated words
insert @words(word)
select token
from @src src
cross apply fn__str_table(line,'') b
group by token
having count(*)>1

-- remove duplicated from lines
declare cs cursor local for
    select lno,line
    from @src
open cs
while 1=1
    begin
    fetch next from cs into @lno,@line
    if @@fetch_status!=0 break
    update @words set @line=replace(@line,word,'') from @words
    select @line=ltrim(rtrim(@line))
    if isnull(@line,'')='' continue
    while left(@line,1) in ('''','"','[','(','{') and
          right(@line,1) in ('''','"',']',')','}')
        select @line=substring(@line,2,len(@line)-2)
    insert @t(lno,line) select @lno,@line
    end -- while of cursor
close cs
deallocate cs

if @opt!='||'
    begin
    if charindex('|unlike|',@opt)>0 and not @filter is null
        delete from @t where line like @filter
    if charindex('|like|',@opt)>0 and not @filter is null
        delete from @t where not line like @filter
    end

return
end -- fn__str_unpattern