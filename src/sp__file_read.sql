/*  leave this
    l:see LICENSE file
    g:utility
    v:100127\s.zaglio:deprecated use of fn__inject and sp__readtable
    v:090928\s.zaglio:removed a double cmd execution and added remove of cr
    v:090731\S.Zaglio:added external temp table management
    v:090123\S.Zaglio:renamed old sp__readtextfile andreplaced in other sp
    v:081009\S.Zaglio:added @step
    v:080916\S.Zaglio:added @outputvar
    v:080815\s.zaglio:added @dbg as param and [] around outputable
    v:080414\s.zaglio:removed content variable
*/
CREATE proc [dbo].[sp__file_read]
    @textfilename sysname,
    @outputtable nvarchar(128) = null,
    @outputvar nvarchar(4000) =null out,
    @step int=1,
    @dbg bit=0
as
set nocount on
declare @tmp bit set @tmp=0
if @dbg=1 print 'sp__file_read'
if (@textfilename='-?') goto help
if @outputtable is null and @outputvar is null goto help

if @outputtable is null begin
    set @outputtable='tmp_'+convert(nvarchar(64),newid())
    set @tmp=1
end

if left(@outputtable,1)<>'[' set @outputtable='['+@outputtable+']'
declare @sql nvarchar(4000)
if left(@outputtable,2)<>'[#' -- if no external temp table generated
    begin
    set @sql='create table %outputtable% (lno int identity(%step%,%step%), line nvarchar(4000))'
    exec sp__str_replace @sql out,'%outputtable%|%step%',@outputtable,@step
    if @dbg=1 print @sql
    exec (@sql)
    end

declare @cmd nvarchar(4000), @crlf nchar(2)
set @cmd='type "'+@textfilename+'"'
set @crlf=char(13)+char(10)
if @dbg=1 print @cmd
-- exec master.dbo.xp_cmdshell @cmd,no_output

set @sql='insert '+@outputtable+' (line)'
set @sql=@sql+' exec master.dbo.xp_cmdshell '''+replace(@cmd,'''','''''')+''''
if @dbg=1 print @sql
exec(@sql)

if not @outputvar is null
    exec sp__err 'sp__readtable deprecated',@cod='sp__file_read'
-- exec sp__readtable @outputtable,@outputvar out,@dbg=@dbg
if @tmp=1 begin
    set @sql='drop table '+@outputtable
    exec(@sql)
end
return 0

help:
/*
exec sp_usage @objectname='sp_readtextfile',
@desc='reads the contents of a ntext file into a sql result set',
@parameters='@textfilename=name of file to read, @contents=optional output var
to receive contents of file (up to 8000 bytes)',
@author='ken henderson', @email='khen@khen.com',
@version='8',@revision='0',
@datecreated='19960501', @datelastchanged='20000120',
@example='sp_readtextfile ''d:\mssql7\log\errorlog'' '
*/
return -1