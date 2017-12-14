/*  keep this for MS compatibility
    l:see LICENSE file
    g:utility
    v:091018\s.zaglio:  mark objs that use datalength and exclusions of utils and temps
    v:090915\s.zaglio:  final tuning
    r:090914\s.zaglio:  some simple bugs
    r:090911\s.zaglio:  drops from together to one to one
    r:090910\s.zaglio:  revision to generate instead of mange directly
    r:090813.1700\s.zaglio:  generate script to trasform the db to unicode
    t:sp__util_tounicode @skip_code=1
*/
CREATE proc [dbo].[sp__util_tounicode]
    @uid sysname='sa',
    @pwd sysname='',
    @skip_code bit=0,
    @skip_scripts bit=0,
    @dbg bit=0
as
begin
set nocount on
/*
    Due use of not logical names we must use this approch:
    .
    .  begin transaction
    .  drop sp,fn,vi
    .  script upsized to unicode
    .  commit
    .
    .  drop fkeys
    .  for each table with varchar,char,text
    .    count rows
    .    make a backup
    .    count backup rows
    .    script table
    .    convert to unicode
    .    drop original
    .    recreate unicoded table
    .    disable eventual identity
    .    reinsert data
    .    compare rows and if eq drop temp data
    .    run script dri
    .
    .  run script fk
    .
    .  remove old scrips
*/
-- select distinct xtype from sysobjects
-- test per fkey
-- sp_fkeys 'am01_us'  -- sp_find 'FK_AM03_MM_FUNC_AM01_US'
-- select * from sysobjects where parent_obj=object_id('am01_us')
-- select * from sysobjects where parent_obj=object_id('AM03_MM_FUNC')
-- select * from sysindexes where id=object_id('am01_us')
-- select * from sysforeignkeys where rkeyid=object_id('am01_us')
-- select * from sysobjects where id=623341285  -- print object_name(313768175) -->AM03_MM_FUNC
-- drop index AM03_MM_FUNC.FK_AM03_MM_FUNC_AM01_US
-- test normale
-- select * from sysobjects where parent_obj=object_id('ot04_stock')
-- select * from sysindexes where id=object_id('ot04_stock')

declare
    @proc sysname,
    @i int,@n int,@j int,@step int,@k int,
    @obj sysname,@new sysname,@msg nvarchar(4000),
    @sql  nvarchar(4000), @flds nvarchar(4000),
    @xtype nvarchar(2),
    @oc_tbl smallint,
    @oc_dri smallint,
    @oc_trg smallint,
    @oc_prp smallint,
    @oc_fk smallint,
    @cur_db sysname,@cur_srv sysname,
    @ret int,@crlf nchar(2),
    @upsize_marker sysname,
    @timer datetime,
    @tmp sysname,
    @file sysname,
    @cmd nvarchar(512),
    @parent_obj int

select
    @proc='sp__util_tounicode',
    @oc_tbl=1,   -- table with owner and not chk
    @oc_dri=20,  -- pkey,idx and chk
    @oc_trg=32,  -- triggers only
    @oc_prp=128, -- ex props
    @oc_fk=1024, -- only fkeys
    @cur_db=db_name(),
    @cur_srv=@@servername,
    @ret=0, @crlf=nchar(13)+nchar(10),
    @upsize_marker='-- saved:'+convert(sysname,getdate(),126)

exec sp__printf '-- @cur_db=%s, @spid=%d, @procid=%d',@cur_db,@@spid,@@procid

create table #objs(id int identity(1,1),obj sysname,xtype nvarchar(2),parent_obj int) -- sp,fn,vi

declare @xt_vchar int,@xt_char int,@xt_text int
select @xt_vchar=xtype from systypes where name='varchar'
select @xt_char=xtype  from systypes where name='char'
select @xt_text=xtype  from systypes where name='text'

select @step=10

-- temp table
create table #src   (lno int identity(10,10),line nvarchar(4000))
create table #dri   (lno int identity(10,10),line nvarchar(4000))

/*
create table @exclude (id int identity,obj sysname)
insert into @exclude(obj) select token from dbo.fn__str_table(@excludes,'|')
select @i=min(id),@n=max(id) from @exclude
while (@i<=@n)
    begin
    select @obj=obj from @exclude where id=@i
    if charindex('%',@
    end
*/

/*
exec sp__drop 'tmp_*',@simul=0
*/

exec sp__elapsed @timer out,'-- script generation started at:'

-- select sp,fn,vi that have varchar,char,text
-- select top 1 * from sysusers
insert into #objs(obj,xtype,parent_obj)
select quotename(u.name)+'.'+quotename(o.name),o.xtype,o.parent_obj
from sysobjects o join sysusers u on o.uid=u.uid
where o.xtype in ('P','FN','IF','TF','V')
and (exists(
        select null from syscolumns c
        where c.id=o.id and c.xtype in (@xt_vchar,@xt_char,@xt_text)
        )
    or exists(
        select null from syscomments c
        where c.id=o.id
        and (
            charindex('varchar',[text])=1
            or charindex('char',[text])=1
            or charindex('text',[text])=1
            or charindex('[varchar',[text])>0
            or charindex('[char',[text])>0
            or charindex('[text',[text])>0
            or charindex(' varchar',[text])>0
            or charindex(' char',[text])>0
            or charindex(' text',[text])>0
            )
        )
    )
and not (
    o.name in ('dtproperties',@proc)
    or o.name like 'dt[_]%'
    or o.name like 'sys%'
    or o.name like 'tmp[_]%'
    or o.name like '[sfv][pni][__]%' -- sp__,fn__,vi__
    or o.name like '%[_]tmp'
    or o.name like '%[_]temp'
    or o.name like '%[_]tmp'
    or o.name like '%[_]backup'
    or o.name like '%[_]test'
    or o.name like '%[_][0-9][0-9][0-9][0-9][0-9][0-9][_][0-9][0-9][0-9][0-9]' -- *_AAMMGG_HHMM
    )
order by xtype,o.name

-- select tables that have varchar,char,text
-- select * from sysforeignkeys
insert into #objs(obj,xtype,parent_obj)
select quotename(u.name)+'.'+quotename(o.name),o.xtype,o.parent_obj -- case when o.xtype='F' then f.rkeyid else o.parent_obj end
from sysobjects o join sysusers u on o.uid=u.uid
-- left join sysforeignkeys f
-- on o.id=f.constid
where o.xtype='F'  -- foreignkeys
or (o.xtype='U'
    and (exists(
            select null from syscolumns c
            where c.id=o.id and c.xtype in (@xt_vchar,@xt_char,@xt_text)
            )
        or exists(
            select null from syscomments c
            where c.id=o.id
            and (
                charindex('varchar',[text])=1
                or charindex('char',[text])=1
                or charindex('text',[text])=1
                or charindex('[varchar',[text])>0
                or charindex('[char',[text])>0
                or charindex('[text',[text])>0
                or charindex(' varchar',[text])>0
                or charindex(' char',[text])>0
                or charindex(' text',[text])>0
                )
            )
        )
    and not (
            o.name in ('dtproperties',@proc)
            or o.name like 'dt[_]%'
            or o.name like 'sys%'
            or o.name like 'tmp[_]%'
            or o.name like '[sfv][pni][__]%' -- sp__,fn__,vi__
            or o.name like '%[_]tmp'
            or o.name like '%[_]temp'
            or o.name like '%[_]tmp'
            or o.name like '%[_]backup'
            or o.name like '%[_]test'
            or o.name like '%[_][0-9][0-9][0-9][0-9][0-9][0-9][_][0-9][0-9][0-9][0-9]' -- *_AAMMGG_HHMM
        )
    )
order by xtype,o.name


-- save old scrips
select @n=count(*) from #objs
if @n>0 exec sp__elapsed @timer out,'-- found %d objects to script in:',@v1=@n
else goto err_noobjs

exec sp__printf '-- NB: if occur an error copy and paste code into a new windows to not loose info'
exec sp__printf '-- NB: search for "keepeye" notes before run scrit'
exec sp__printf '-- prevent from a too fast F5 running'
exec sp__printf 'declare @secure bit select @secure=1 '
exec sp__printf 'if @secure=1 raiserror(''Disable @secure first'',20,1) with log '
exec sp__printf 'GO'

exec sp__printf '-- goto single user mode'
exec sp__printf 'USE [master] '
exec sp__printf 'ALTER DATABASE [%s] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE',@cur_db
exec sp__printf 'ALTER DATABASE [%s] SET  SINGLE_USER ',@cur_db
exec sp__printf 'USE [%s] ',@cur_db
exec sp__printf 'GO'

exec sp__printf '-- ### scripts objects to convert and save to scripts_...: (%t) ### ',@force=0

-- convert code
if @skip_code=1 goto skip_code

exec sp__printf 'set nocount on',@force=0
exec sp__printf 'set transaction isolation level serializable',@force=0

select @obj=null,@i=min(id),@n=max(id) from #objs
while (@i<=@n)
    begin
    select @obj=obj,@xtype=xtype from #objs where id=@i
    select @i=@i+1
    if @xtype in ('U','F','TR') or @obj in ('sp__script','sp__script_reduce') continue

    truncate table #src
    insert #src(line) select 'GO'
    -- insert #src(line) select 'begin tran'
    insert #src(line) select 'raiserror(''Dropping & recreating '+@obj+'...'',10,1)'
    select @sql ='drop '
                +case
                    when @xtype in ('P') then 'proc '
                    when @xtype in ('FN','IF','TF') then 'function '
                    when @xtype in ('V') then 'view '
                    when @xtype in ('U') then 'table '
                 end
                +@obj
    insert #src(line) select @sql
    insert #src(line) select 'GO'
    exec sp__script @obj,'#src'
    exec sp__script_reduce @normalize=4 -- convert to unicode
    -- insert #src(line) select 'if @@error=0 commit'
    -- insert #src(line) select 'if @@trancount>0 begin print ''rollback of '+@obj+''' rollback end'
    insert #src(line) select 'GO'
    select @j=null
    select @k=count(*) from #src
    select @j=lno/10 from #src where line like '%ntext%syscomments%'
    if not @j is null
        begin
        insert into #src(line) select '-- keepeye: ntext near syscomments can be an error, '+convert(sysname,@k-@j)+' lines above'
        insert #src(line) select 'GO'
        end
    select @j=null
    select @k=count(*) from #src
    select @j=lno/10 from #src where line like '%substring%8000%' or line like '%left%8000%' or line like '%right%8000%'
    if not @j is null
        begin
        insert into #src(line) select '-- keepeye: 8000 into substring, left, right can be an error, '+convert(sysname,@k-@j)+' lines above'
        insert #src(line) select 'GO'
        end
    select @j=null
    select @k=count(*) from #src
    select @j=lno/10 from #src where line like '%datalength%'
    if not @j is null
        begin
        insert into #src(line) select '-- keepeye: use of datalength can cause error, '+convert(sysname,@k-@j)+' lines above'
        insert #src(line) select 'GO'
        end
    -- out the code
    exec sp__script '#src'
    end -- while
exec sp__elapsed @timer out,'-- done %d objects in:',@v1=@n

skip_code: -- end of code convertion

exec sp__printf '\n\n-- ### table conversion ###'

exec sp__printf '-- drop fkeys',@force=0
exec sp__printf 'raiserror(''%s'',10,1)','Dropping fkeys...',@force=0

select @obj=null,@i=min(id),@n=max(id) from #objs
while (@i<=@n)
    begin
    select @obj=null
    select @obj=obj,@xtype=xtype,@parent_obj=parent_obj from #objs where id=@i and xtype='F'
    select @i=@i+1
    if @obj is null continue -- skip non tables
    select @tmp=object_name(@parent_obj)
    select @sql=quotename(parsename(@obj,1))
    exec sp__printf 'alter table %s drop constraint %s',@tmp,@sql
    end

select @obj=null,@i=min(id),@n=max(id) from #objs
while (@i<=@n)
    begin
    select @obj=null
    select @obj=obj,@xtype=xtype from #objs where id=@i and xtype='U'
    select @i=@i+1
    if @obj is null continue -- skip non tables

    select @tmp=quotename('tmp_'+parsename(@obj,1))
    select @flds=dbo.fn__flds_of(@obj,',',null)
    set @flds=dbo.fn__flds_quotename(@flds,',')

    exec sp__printf 'raiserror(''Converting table %s...'',10,1)',@obj,@force=0
    exec sp__printf '\n\n-- converting table:%s:',@obj,@force=0
    exec sp__printf 'declare @rows bigint,@rows_s bigint,@msg sysname',@force=0
    exec sp__printf 'select @rows_s=count(*) from %s',@obj,@force=0
    exec sp__printf '-- make a backup of data',@force=0
    exec sp__printf 'if dbo.fn__exists(''%s'',''u'')=1 drop table %s',@tmp,@tmp,@force=0
    exec sp__printf 'select top 0 * into %s from %s with (tablockx)',@tmp,@obj,@force=0

    declare @has_id bit

    select @has_id=objectproperty(object_id(@obj),'TableHasIdentity')
    if @has_id=1 exec sp__printf 'set identity_insert %s on',@tmp,@force=0
    exec sp__printf 'insert into %s(%s) select %s from %s with (tablockx)',@tmp,@flds,@flds,@obj,@force=0
    if @has_id=1 exec sp__printf 'set identity_insert %s off',@tmp,@force=0
    exec sp__printf 'select @msg=convert(sysname,@rows)+'' rows exported''',@force=0
    exec sp__printf 'raiserror(@msg,10,1)',@force=0
    exec sp__printf 'select @rows=count(*) from %s',@tmp,@force=0
    exec sp__printf 'if @rows!=@rows_s raiserror(''there are differences with local backup'',20,1)',@force=0
    exec sp__printf 'drop table %s',@obj,@force=0

    truncate table #src
    exec sp__script @obj,'#src',@oc=@oc_tbl
    delete from #src where line='GO'
    exec sp__script_reduce @normalize=4 -- convert to unicode
    exec sp__script '#src'

    if @has_id=1 exec sp__printf 'set identity_insert %s on',@obj,@force=0
    exec sp__printf 'insert into %s(%s) select %s from %s',@obj,@flds,@flds,@tmp,@force=0
    if @has_id=1 exec sp__printf 'set identity_insert %s off',@obj,@force=0
    exec sp__printf 'select @rows=count(*) from %s',@tmp,@force=0
    exec sp__printf 'select @msg=convert(sysname,@rows)+'' rows imported''',@force=0
    exec sp__printf 'raiserror(@msg,10,1)',@force=0
    exec sp__printf 'if @rows!=@rows_s raiserror(''restore of data failed'',20,1)',@force=0
    truncate table #src
    exec sp__script @obj,'#src',@oc=@oc_prp
    exec sp__script '#src'
    truncate table #src
    exec sp__script @obj,'#src',@oc=@oc_dri
    exec sp__script @obj,'#src',@oc=@oc_trg
    exec sp__script_reduce @normalize=4 -- convert to unicode
    exec sp__script '#src'
    exec sp__printf 'drop table %s',@tmp,@force=0
    end -- while

exec sp__printf '-- reload fkeys'
select @obj=null,@i=min(id),@n=max(id) from #objs
while (@i<=@n)
    begin
    select @obj=null
    select @obj=obj,@xtype=xtype,@parent_obj=parent_obj from #objs where id=@i and xtype='U'
    select @i=@i+1
    if @obj is null continue -- skip non tables
    if dbo.fn__exists(@obj,'FK')=1
        begin
        exec sp__printf 'raiserror(''Recreating fkey for %s'',10,1)',@obj,@force=0
        exec sp__script @obj,@oc=@oc_fk
        end
    end

exec sp__printf '-- back to multiuser mode'
exec sp__printf 'USE [master] '
exec sp__printf 'ALTER DATABASE [%s] SET  MULTI_USER WITH ROLLBACK IMMEDIATE',@cur_db
exec sp__printf 'ALTER DATABASE [%s] SET  MULTI_USER ',@cur_db
exec sp__printf 'USE [%s] ',@cur_db

exec sp__elapsed @timer out,'-- end at %t table script gneration in:'

goto ret

err_noobjs:     select @msg='#!no objects to upsize' goto ret
err_noscode:    select @msg='#!no code found in script_code' goto ret
err_compcode:   select @msg='#!compiling sp,fn,v' goto ret
err_compdri:    select @msg='#!compiling dri' goto ret
err_computbl:   select @msg='#!compiling unicoded tables' goto ret

help:
select @msg ='Generate script to convert db to unicode'
exec sp__usage @proc,@extra=@msg
select @msg=null

ret:
if not @msg is null exec sp__printf @msg
end -- proc sp__util_tounicode