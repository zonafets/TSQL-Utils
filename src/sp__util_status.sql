/*  leave this
    l:see LICENSE file
    g:utility
    v:100328\s.zaglio: added help
    v:100212\s.zaglio: added drives free space inspect
    v:100131\s.zaglio: save and compare mssql configuration
    t:sp__util_status @reset=1,@dbg=1
    t:
        declare @r int
        exec @r=[sp__util_status] @dbg=1
        print @r
        select * from TBL_SAVED_CONFIGURATION where tid='dri'
*/
CREATE proc [dbo].[sp__util_status]
    @reset bit=0,
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@sql nvarchar(4000),@dt datetime,@i int,@n int,@j int,@r int
declare @first datetime,@last datetime

select
    @proc='sp__util_status',
    @dt=getdate(),
    @r=1

-- drop table TBL_SAVED_CONFIGURATION
if dbo.fn__exists('TBL_SAVED_CONFIGURATION','u')=0
    begin
    -- declare @proc sysname,@sql nvarchar(4000),@dt datetime,@i int,@n int
    select @sql='create table TBL_SAVED_CONFIGURATION (\n'
               +'\ttid char(4),\n\thdr bit default 0,id int identity,\n\tdt datetime'
    select @i=1,@n=30
    while @i<=@n select @sql=@sql+',\n\tv'+convert(sysname,@i)+' sysname null',@i=@i+1
    select @sql=@sql+')'
    select @sql=replace(@sql,'\n',char(13))
    select @sql=replace(@sql,'\t','    ')
    exec sp__printf '-- creating table '
    exec(@sql)
    select @reset=1
    end

-- delete last registration
select @first=min(dt),@last=max(dt) from TBL_SAVED_CONFIGURATION
if @first!=@last delete from TBL_SAVED_CONFIGURATION where dt=@last

create table #sp_configure (
    name sysname,
    minimum int,
    maximum int,
    config_value int,
    run_value int)

insert into #sp_configure exec sp_configure

-- select * from #sp_configure
select * into #databases from master..sysdatabases with (nolock)

select * into #servers from master..sysservers with (nolock)

create table #drives(name sysname,freeperc int)
exec sp__util_drives 'letter,pc','#drives',@dbg=1

if @reset=1
    begin
    exec sp__printf '-- 1st registration'
    truncate table TBL_SAVED_CONFIGURATION
    end

-- declare @j int,@i int,@n int,@sql nvarchar(4000),@dt datetime select @dt=getdate()
declare @flds nvarchar(4000),@tbls sysname,@tbl sysname,@tid sysname
select @tbls='#sp_configure:cfg,#databases:dbs,#servers:svrs,#drives:dri'
select @j=dbo.fn__str_count(@tbls,',')

while @j>0
    begin
    select @tbl=dbo.fn__str_at(@tbls,',',@j)
    select @tid=dbo.fn__str_at(@tbl,':',2)
    select @tbl=dbo.fn__str_at(@tbl,':',1),@j=@j-1
    exec sp__printf '-- saving %s',@tbl

    select @flds=dbo.fn__flds_of(@tbl,',',null)
    if @dbg=1 exec sp__printf '@tbl=%s, @flds=%s',@tbl,@flds

    select @i=1,@n=dbo.fn__str_count(@flds,',')
    if @n>30 select @n=30
    select @sql='insert into TBL_SAVED_CONFIGURATION (tid,hdr,dt'
    while @i<=@n select @sql=@sql+',v'+convert(sysname,@i),@i=@i+1
    select @sql =@sql+')\nselect '''+@tid+''',1,'''+convert(sysname,@dt,126)+''','
                +dbo.fn__str_exp('''%%''',@flds,',')
    select @sql=replace(@sql,'\n',char(13))
    if @dbg=1 exec sp__printf @sql
    exec(@sql)

    select @i=1,@n=dbo.fn__str_count(@flds,',')
    if @n>30 select @n=30
    select @sql='insert into TBL_SAVED_CONFIGURATION (tid,dt'
    while @i<=@n select @sql=@sql+',v'+convert(sysname,@i),@i=@i+1
    select @sql =@sql+')\nselect '''+@tid+''','''+convert(sysname,@dt,126)+''','
                +dbo.fn__str_exp('convert(sysname,%%)',@flds,',')
    select @sql=@sql+'from ['+@tbl+']'
    select @sql=replace(@sql,'\n',char(13))
    if @dbg=1 exec sp__printf @sql
    exec(@sql)
    end -- while

if @reset=0
    begin
    select @first=min(dt),@last=max(dt) from TBL_SAVED_CONFIGURATION
    select @sql='select isnull(a.tid,b.tid) tid,isnull(a.v1,b.v1) v1_key'
    select @i=2,@n=30
    while (@i<=@n)
        select @sql=@sql+',a.v'+convert(sysname,@i)+',b.v'+convert(sysname,@i),@i=@i+1

    select @sql=@sql+'
        from TBL_SAVED_CONFIGURATION a
        full outer join TBL_SAVED_CONFIGURATION b
        on a.tid=b.tid and a.v1=b.v1
        where a.dt='''+convert(sysname,@first,126)+''' and b.dt='''+convert(sysname,@last,126)+'''
        and (a.hdr=1'
    select @i=2
    select @sql=@sql+' or 1=case when a.tid=''dri'' and convert(int,b.v2)<11 then 1 when a.tid!=''dri'' and (1=0'
    while (@i<=@n)
        select @sql=@sql+' or isnull(a.v'+convert(sysname,@i)
                   +','''')!=isnull(b.v'+convert(sysname,@i)+','''')',@i=@i+1

    select @sql=@sql+') then 1 else 0 end)
        order by a.id'

    if @dbg=1 exec sp__printf @sql
    select @n=count(*)/2 from TBL_SAVED_CONFIGURATION where hdr=1
    exec(@sql)
    select @i=@@rowcount,@r=@@error
    if @i!=@n and @r=0 select @r=1 else select @r=0

    end -- compare

-- select * from TBL_SAVED_CONFIGURATION order by tid,id
-- update TBL_SAVED_CONFIGURATION set v2=v2+1 where id=54
drop table #sp_configure
drop table #databases
drop table #servers
drop table #drives

exec sp__usage @proc

return @r
end -- proc