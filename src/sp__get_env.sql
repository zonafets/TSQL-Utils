/*  leave this
    l:see LICENSE file
    g:utility
    v:091018\s.zaglio: added help
    v:090910\s.zaglio: get os env var
    t:declare @tmp nvarchar(128) exec sp__get_env @tmp out,'allusersprofile' print @tmp
*/
CREATE proc [dbo].[sp__get_env]
    @val sysname=null output,
    @var sysname=null
as
begin
set nocount on
create table #lines (lno int identity, line nvarchar(4000))

declare @cmd nvarchar(4000), @crlf nchar(2)
set @cmd='set'
set @val=null

insert #lines (line)
exec master.dbo.xp_cmdshell @cmd--,no_output -- if use this don't work
if @var is null select * from #lines
else
    select @val=isnull(rtrim(substring(line,charindex('=',line)+1,256)),'')
    from #lines
    where line like @var+'=%'

drop table #lines
if @var is null exec sp__usage 'sp__get_env'
end