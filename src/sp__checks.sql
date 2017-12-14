/*  leave this
    l:see LICENSE file
    g:utility
    v:080716\S.Zaglio: disable checks for all tables of optional other db
*/
CREATE PROCEDURE sp__checks
    @action nchar(2)='-?',
    @db_dst nvarchar(128)=null
AS
begin
declare @dbg bit
set @dbg=1
if @db_dst is null set @db_dst=db_name()

declare @sql nvarchar(512)
if @action='-?' goto usage
if @action='EA' -- enable all
    begin
    if @dbg=1 print 'enable all constraint'
    set @sql='use '+@db_dst+' alter table ? CHECK CONSTRAINT ALL '
    if @dbg=1 exec sp__inject @sql out,'print ''',''''
    exec sp__foreachobj 'TABLE',@sql
    end
if @action='DA' -- disable all
    begin
    if @dbg=1 print 'disable all constraint'
    set @sql='use '+@db_dst+' alter table ? NOCHECK CONSTRAINT ALL '
    if @dbg=1 exec sp__inject @sql out,'print ''',''''
    exec sp__foreachobj 'TABLE',@sql
    end
return
usage:
    print 'sp__checks'
    print '    @action nchar(2)=''-?'''
    print '    @tbl nvarchar(128)=''%'''
    print '    @db_dst nvarchar(128)=null'
    print 'usage:'
    print ' sp_t -? this help'
    print ' sp_t EA enable all triggers'
    print ' sp_t DA disable all triggers'
    return
test:
    exec sp__triggers 'DA',@tbl='a%'
end