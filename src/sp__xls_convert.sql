/*  leave this
    l:see LICENSE file
    g:utility,xls
    v:100424\s.zaglio: create aid code to import data from xls
    t:sp__xls_convert 'anagrafica'
*/
CREATE proc sp__xls_convert @sheet sysname=null
as
begin
set nocount on
select @sheet='%'+coalesce(@sheet+'%','')
declare @crlf nchar(2)
select @crlf=crlf from dbo.fn__sym()
create table #src (lno int identity, line nvarchar(4000))
insert into #src
select name from sysobjects where name like 'xls[_]'+@sheet

update #src set
    line='select '+dbo.fn__str_exp(@crlf+
            '    [%%] = convert(nvarchar(4000),nullif(ltrim(rtrim([%%])),''''))',
            dbo.fn__flds_of(line,',',null),',')+@crlf
        +'into #'+line + @crlf
        +'from '+quotename(line) + @crlf + @crlf

exec sp__print_table '#src'

drop table #src
end