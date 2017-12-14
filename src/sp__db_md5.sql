/*  leave this
    l:see LICENSE file
    g:utility
    v:090908/S.Zaglio: added some usefull query in comments
    v:081001/S.Zaglio: added calc of stored, function,view,triggers,
    v:080808/S.Zaglio: calculate hash md5 or entire list of table+colums def
    t:
    begin -- each call require 1 minute
    declare @m binary(16), @sql nvarchar(500)
    declare @dbg bit set @dbg=@dbg
    drop proc test_sp__db_md5
    drop table test_sp__db_md5
    print '' print 'original md5 of all db and retest'
    exec sp__db_md5 @m out,@dbg=@dbg print dbo.fn_hex(@m)
    exec sp__db_md5 @m out,@dbg=@dbg print dbo.fn_hex(@m)
    -- test differencies
    print '' print 'test add column to table'
    ALTER   table test_sp__db_md5 (a int)
    exec sp__db_md5 @m out,@dbg=@dbg print dbo.fn_hex(@m)
    ALTER  table test_sp__db_md5 add b bigint
    exec sp__db_md5 @m out,@dbg=@dbg print dbo.fn_hex(@m)
    drop table test_sp__db_md5
    print '' print 'test after drop table'
    exec sp__db_md5 @m out,@dbg=@dbg print dbo.fn_hex(@m)

    -- test proc
    print '' print 'test md5 all db after ALTER  proc'
    set @sql='ALTER  proc test_sp__db_md5 as print 1' exec(@sql)
    exec sp__db_md5 @m out,@dbg=@dbg print dbo.fn_hex(@m)
    print '' print 'test md5 of single proc'
    set @sql='alter proc test_sp__db_md5 as print 1' exec(@sql)
    exec sp__db_md5 @m out,'test_sp__db_md5',@dbg=@dbg print dbo.fn_hex(@m)
    print '' print 'test alter proc to same but probably create change to alter'
    set @sql='alter proc test_sp__db_md5 as print 1' exec(@sql)
    exec sp__db_md5 @m out,'test_sp__db_md5',@dbg=@dbg print dbo.fn_hex(@m)
    print '' print 'test alter proc to same again'
    set @sql='alter proc test_sp__db_md5 as print 1' exec(@sql)
    exec sp__db_md5 @m out,'test_sp__db_md5',@dbg=@dbg print dbo.fn_hex(@m)
    print '' print 'test alter 1 nchar of same proc'
    set @sql='alter proc test_sp__db_md5 as print 2' exec(@sql)
    exec sp__db_md5 @m out,'test_sp__db_md5',@dbg=@dbg print dbo.fn_hex(@m)
    drop proc test_sp__db_md5
    print '' print 'test not existance after drop proc'
    exec sp__db_md5 @m out,'test_sp__db_md5',@dbg=@dbg print dbo.fn_hex(@m)
    print '' print 'original md5 of all db'
    exec sp__db_md5 @m out,@dbg=@dbg print dbo.fn_hex(@m)
    end
*/
CREATE  proc [dbo].[sp__db_md5]
    @db_md5 binary(16)=null out,
    @objects nvarchar(4000)=null,
    @dbg bit=0
as
begin
set nocount on
create table #objs ([id] int, [name] sysname, [xtype] nchar(2), md5 binary(16))
declare @n int
declare @i int set @i=1
declare @id int, @last_id int, @colid smallint
declare @obj sysname
declare @xtype nchar(2)
declare @output bit
if @db_md5 is null set @output=1
if @objects is null insert into #objs([id],[name],[xtype])
    select [id],[name],[xtype] from sysobjects where xtype in ('U','V','P','FN','TR','D','IF','TF','F','UQ','PK','C','RF')
else begin
    set @n=dbo.fn__str_count(@objects,'|')
    while (@i<=@n) begin
        set @obj=dbo.fn__str_at(@objects,'|',@i)
        set @id=object_id(@obj)
        if @id is null and @dbg=@dbg print 'object '+@obj+' don''t exists'
        else begin
            select @xtype=xtype from sysobjects where id=@id
            insert into #objs(id,name,xtype) values(@id,@obj,@xtype)
        end
        set @i=@i+1
    end -- while
end
if @dbg=@dbg begin
    select @n=count(*) from #objs
    print 'objects selected '+convert(nvarchar(32),@n)
end
-- todo: indexes not pk,uq are excluded. Must be integreted
-- check tables
declare cst cursor local forward_only static read_only for
select    top 100 percent o.id, o.name as [name], o.name + '|' + c.name + '|' + t.name + '|' + convert(nvarchar(32), isnull(c.length, 0)) + '|' + convert(nvarchar(32),
          isnull(c.xprec, 0)) + '|' + convert(nvarchar(32), isnull(c.scale, 0)) as row
from      syscolumns c inner join
          #objs o on c.id = o.id inner join
          systypes t on c.xtype = t.xtype
where     o.xtype='U'
order by o.id, c.colid
declare @a bigint,@b bigint, @c bigint, @d bigint
set @db_md5=null
set @last_id=null
declare @row nvarchar(4000)
open cst
while (1=1) begin
    fetch next from cst into @id,@obj,@row
    if @@error!=0 or @@fetch_status!=0 break
    if coalesce(@last_id,0)<>@id and @dbg=@dbg print 'calculating md5 of table '+@obj
    if @last_id is null set @last_id=@id
    if @last_id<>@id set @last_id=@id
    exec sp__md5 @row,@db_md5 out,@a out,@b out,@c out,@d out
end -- while
close cst
deallocate cst
if @dbg=@dbg print 'calculate for other ojects'
-- check procs, funcs, views, etc.
declare csp cursor local forward_only static read_only for
select o.id,sc.colid,o.name
from syscomments sc
inner join #objs o on sc.id=o.id
where o.xtype != 'U'
order by sc.id,sc.colid
option (robust plan)
set @last_id=null
declare @row1 nvarchar(4000)
open csp
while (1=1) begin
-- Impossibile creare una riga di tabella di lavoro con dimensioni maggiori
-- della larghezza massima consentita. Rieseguire la query con l'hint ROBUST PLAN.
    fetch next from csp into @id,@colid,@obj
    if @@error!=0 or @@fetch_status!=0 break
    select @row=coalesce(substring([text],1,4000),''),@row1=coalesce(substring([text],4001,4000),'')
    from syscomments where id=@id and colid=@colid
    if coalesce(@last_id,0)<>@id and @dbg=@dbg print 'calculating md5 of object '+@obj
    if @last_id is null set @last_id=@id
    if @last_id<>@id set @last_id=@id
    if len(@row1)=0
        exec sp__md5 @row,@db_md5 out,@a out,@b out,@c out,@d out
    else begin
        exec sp__md5 @row ,@db_md5 out,@a out,@b out,@c out,@d out
        exec sp__md5 @row1,@db_md5 out,@a out,@b out,@c out,@d out
    end
end -- while
close csp
deallocate csp
drop table #objs
if @output=1 select @db_md5
end -- proc