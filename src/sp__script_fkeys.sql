/*  leave this
    l:see LICENSE file
    g:utility
    v:120117\s.zaglio: a small bug
    v:110406\s.zaglio: adapted to new form, removed #objs
    v:100919\s.zaglio: adapted to #objs
    v:100328\s.zaglio: adapted to new sp__script
    v:090813\s.zaglio: get fkeys script source
    s:http://blog.sqlauthority.com/2008/04/18/sql-server-generate-foreign-key-scripts-for-database/
    t:
        create table test_fk1(id int primary key, v sysname)
        create table test_fk2(ref_id int, v sysname)
        alter table dbo.test_fk2 add constraint fk_test_fk2_test_fk1
            foreign key(ref_id) references dbo.test_fk1(id) on update cascade
            on delete no action
        exec sp__script_fkeys 'test_fk1'
        exec sp__script_fkeys 'test_fk2'
        drop table test_fk2
        drop table test_fk1
    t:sp__script_fkeys '%'
*/
CREATE procedure [dbo].[sp__script_fkeys]
    @obj sysname=null,
    @opt sysname=null,
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0,
       @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

-- 090813\s.zaglio: get fkeys script source
if @obj is null goto help
/*
author : seenivasan
this procedure is used for generating foreign key script.
*/

declare @src table (lno int identity primary key,line nvarchar(4000))

declare @fkname nvarchar(128)
declare @fkcolumnname nvarchar(128)
declare @pkcolumnname nvarchar(128)
declare @fupdaterule int
declare @fdeleterule int
declare @fieldnames nvarchar(500)
declare @n int

create table #temp(
    pktable_qualifier nvarchar(128),
    pktable_owner nvarchar(128),
    pktable_name nvarchar(128),
    pkcolumn_name nvarchar(128),
    fktable_qualifier nvarchar(128),
    fktable_owner nvarchar(128),
    fktable_name nvarchar(128),
    fkcolumn_name nvarchar(128),
    key_seq int,
    update_rule int,
    delete_rule int,
    fk_name nvarchar(128),
    pk_name nvarchar(128),
    deferrability int)

declare @objs table (obj sysname)

if charindex('%',@obj)>0
    insert @objs select [name]
    from sysobjects
    where [name] like @obj
    and xtype='u'
else
    insert @objs select parsename(@obj,1)

declare ttablenames cursor local for
    select obj
    from @objs

open ttablenames

fetch next
from ttablenames
into @obj

while @@fetch_status = 0
    begin
    insert #temp
    exec dbo.sp_fkeys @obj
    fetch next
    from ttablenames
    into @obj
    end -- while
close ttablenames
deallocate ttablenames

set @fieldnames = ''
set @obj = ''
select distinct
    fk_name as fkname,fktable_name as ftname,
    @fieldnames as ftfields,pktable_name as stname,
    @fieldnames as stfields,@fieldnames as fktype
into #temp1
from #temp
order by fk_name,fktable_name,pktable_name

declare fk_cusror cursor for
select distinct fkname from #temp1

open fk_cusror
fetch
from fk_cusror into @fkname

while @@fetch_status = 0
    begin

    declare fk_fields_cusror cursor for
    select fkcolumn_name,pkcolumn_name,update_rule,delete_rule
    from #temp
    where fk_name = @fkname
    order by key_seq

    open fk_fields_cusror
    fetch
    from fk_fields_cusror into  @fkcolumnname,@pkcolumnname,
                                @fupdaterule,@fdeleterule
    while @@fetch_status = 0
        begin

        update #temp1 set ftfields =
        case when len(isnull(ftfields,'')) = 0
             then '['+@fkcolumnname+']'
             else ftfields+',['+@fkcolumnname+']'
             end
        where fkname = @fkname

        update #temp1 set stfields = case when len(isnull(stfields,''))
        = 0 then '['+@pkcolumnname+']'
        else stfields
        +',['+@pkcolumnname+']' end
        where fkname = @fkname

        fetch next
        from fk_fields_cusror into  @fkcolumnname,@pkcolumnname,
                                    @fupdaterule,@fdeleterule
        end -- fk_fields

    update #temp1 set fktype = case when @fupdaterule = 0
    then fktype + ' on update cascade'
    else fktype end
    where fkname = @fkname

    update #temp1 set fktype = case when @fdeleterule = 0
    then fktype + ' on delete cascade'
    else fktype end
    where fkname = @fkname

    close fk_fields_cusror
    deallocate fk_fields_cusror

    fetch next
    from fk_cusror into @fkname
    end -- fk_cursor

close fk_cusror
deallocate fk_cusror

if exists(select null from #temp1) insert into @src(line) select 'go'

insert into @src(line)
select 'alter table [dbo].['+ftname+'] with nocheck add constraint ['+fkname+'] foreign key ('+ftfields+')
references ['+stname+'] ('+stfields+') '+fktype
from #temp1

if object_id('tempdb..#src') is null
    select line from @src order by lno
else
    insert #src(line)
    select line from @src order by lno

goto ret

-- ===================================================================== help ==

help:
exec sp__usage @proc
select @ret=-1

ret:
set nocount off
return @ret
end -- sp__Script_fkeys