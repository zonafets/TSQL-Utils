/*  leave this
    l:see LICENSE file
    g:utility
    v:090805\S.Zaglio: quotet db name
    v:080616\S.Zaglio: disable trigger for tables% of optional other db
*/
CREATE PROCEDURE [dbo].[sp__triggers]
    @action nchar(2)='-?',
    @tbl_like nvarchar(128)='%',
    @db_dst nvarchar(128)=null
AS
begin
declare @dbg bit
set @dbg=0
if @db_dst is null set @db_dst=db_name()
select @db_dst=dbo.fn__sql_quotename(@db_dst)
declare @sql nvarchar(512)
set @tbl_like=' and [name] like '''+@tbl_like+''''
if @action='-?' goto usage
if @action='EA' -- enable all
    begin
    if @dbg=1 print 'enable all triggers for '+@tbl_like
    set @sql='use '+@db_dst+' exec sp__foreachobj ''trigger'',@replacechar=''$'',@command1=''alter table ? enable  trigger $'',@whereand='' and parent_obj=object_id(''''?'''')'''
    if @dbg=1 exec sp__inject @sql out,'print ''',''''
    exec sp__foreachobj 'TABLE',@sql,@whereand=@tbl_like
    end
if @action='DA' -- disable all
    begin
    if @dbg=1 print 'disable all triggers for '+@tbl_like
    set @sql='use '+@db_dst+' exec sp__foreachobj ''trigger'',@replacechar=''$'',@command1=''alter table ? disable trigger $'',@whereand='' and parent_obj=object_id(''''?'''')'''
    if @dbg=1 exec sp__inject @sql out,'print ''',''''
    exec sp__foreachobj 'TABLE',@sql,@whereand=@tbl_like
    end
return
usage:
    print 'sp__triggers'
    print '    @action nchar(2)=''-?'''
    print '    @tbl_like nvarchar(128)=''%'''
    print '    @db_dst nvarchar(128)=null'
    print 'usage:'
    print ' sp_t -? this help'
    print ' sp_t EA enable all triggers'
    print ' sp_t DA disable all triggers'
    return
test:
    exec sp__triggers 'DA',@tbl_like='a%'
end