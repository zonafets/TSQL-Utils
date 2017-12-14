/*  leave this
    l:see LICENSE file
    g:utility
    v:090517\S.Zaglio: create a link to a remote object
*/
create proc sp__link @obj sysname,@server sysname, @db sysname=null, @uid sysname='sa', @pwd sysname='',@drop bit=0,@dbg bit=0
as
begin
set nocount on
declare @wid sysname select @wid=''
declare @sql nvarchar(4000)

if @db is null select @db=db_name()
select @sql ='create view ['+@obj+ '] as '
            +'select * from opendatasource(''SQLOLEDB'','
            +''''
            +'Persist Security Info=True;UID='+@uid+';'
            +'Initial Catalog='+@db+';'
            +'SERVER='+@server+';'
            +'Use Procedure for Prepare=1;Auto Translate=True;Packet Size=4096;'
            +'Workstation ID='+@wid
            +'Use Encryption for Data=False;Tag with column collation when possible=False'
            +''''
            +').'+@db+'.dbo.['+@obj+'] rowset_1'

if @dbg=1 print @sql
if @drop=1 exec sp__drop @obj
exec(@sql)
end