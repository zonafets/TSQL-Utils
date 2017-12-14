/*  leave this
    l:see LICENSE file
    g:utility
    v:120905\s.zaglio: moved out the help
    v:120827\s.zaglio: a small bug
    v:101211\s.zaglio: replace call of sp_lock
    v:100919\s.zaglio: added WITH NO_INFOMSGS to not show dbcc out
    v:100615\s.zaglio: added with nolock everywhare
    v:091221\s.zaglio: a different approach because alter table on # don't work. Better use select into
    v:091123\s.zaglio: replaced use of object_name because is blocked by transaction and not influenced by set trans...
    v:091116\s.zaglio: help find locks (replace also old sp__find_root_blocker)
    s:sp__lock_ex
    t:sp__lock @@spid
    t:sp__lock '#lock'
    t:sp__lock @dbg=1
    t:print @@trancount
    t:sp__lock @blocking=1 -- sp__lock 7 -- sp_lock
    t:select * from master..sysprocesses where spid=7
    t:sp__run_cmd 'net start' -- sp__run_cmd 'net stop "SQLAgent$WEBAPP" & net start "SQLAgent$WEBAPP"'
    t:sp__lock 70,@tsql=1
*/
CREATE proc [dbo].[sp__lock]
(
    @spid_obj_login_root sysname=null,
    @db sysname = null,
    @tsql bit=null,
    @blocking bit=0,
    @dbg bit=0
)
as
begin
-- declare @spid_obj_login_root sysname,@db sysname,@dbg bit set @dbg=1

set nocount on
set transaction isolation level read uncommitted
declare @spid int, @obj sysname, @name sysname,@proc sysname
declare @i int,@n int,@sql nvarchar(4000),@id int
declare @timer datetime

select @proc=object_name(@@procid)

declare @sysobjects table (id int, name sysname)

select @timer=current_timestamp

if @spid_obj_login_root is null exec sp__usage @proc
else select @tsql=1

select @tsql=coalesce(@tsql,0)


if isnumeric(@spid_obj_login_root)=1 select @spid=convert(int,@spid_obj_login_root)
else select @obj=@spid_obj_login_root+'%'

create table #lock1
(
    spid int,
    dbid int,
    objid int,
    indid int,
    type nchar(5),
    resource sysname,
    mode sysname,
    status sysname
)

-- select * from master..syslocks
exec sp__printf '-- sp__lock:%T: read from sp_lock','%t'  -- '%t' otherwise do not print date
insert into #lock1
select
    convert (smallint, req_spid) As spid,
    rsc_dbid As [dbid],
    rsc_objid As [ObjId],
    rsc_indid As IndId,
    substring (v.name, 1, 4) As Type,
    substring (rsc_text, 1, 32) as Resource,
    substring (u.name, 1, 8) As Mode,
    substring (x.name, 1, 5) As Status
-- select *
from
    master.dbo.syslockinfo with (nolock),
    master.dbo.spt_values v with (nolock),
    master.dbo.spt_values x with (nolock),
    master.dbo.spt_values u with (nolock)
-- SELECT * FROM sys.dm_tran_locks
where master.dbo.syslockinfo.rsc_type = v.number
and v.type = 'LR'
and master.dbo.syslockinfo.req_status = x.number
and x.type = 'LS'
and master.dbo.syslockinfo.req_mode + 1 = u.number
and u.type = 'L'
order by spid

-- select * from master..sysprocesses p
select * into #processes from master..sysprocesses p with (nolock)
-- where p.status!='sleeping' ! nope coz can be active lock on (h)old spid

exec sp__printf '-- sp__lock:%T: altering #lock','%t'  -- '%t' otherwise do not print date

select
    identity(int,1,1) as id,
    convert(sysname,null) as [db_name],
    convert(sysname,null) as obj_name,
    convert(sysname,null) as p_status,
    convert(sysname,null) as sql,
    convert(sysname,null) as login,
    convert(sysname,null) as host,
    convert(int,null) waittime,
    convert(int,null) open_trans,
    convert(datetime,null) last_batch,
    convert(int,null) blocking,
    convert(int,null) n_locks,
    #lock1.*
into #lock
from #lock1 with (nolock)

drop table #lock1
-- capture sql as first to not loose it

if @tsql=1
    begin
    create table #dbccout(language_event sysname,parameters INT,event_info NVARCHAR(4000))

    exec sp__printf '-- sp__lock:%T: get cmds','%t'  -- '%t' otherwise do not print date

    select @i=min(id),@n=max(id) from #lock with (nolock)
    while (@i<=@n)
        begin
        select @id=spid from #lock with (nolock) where id=@i
        truncate table #dbccout

        select @sql='insert into #dbccout exec(''dbcc inputbuffer('+convert(sysname,@id)+') with no_infomsgs'')'
        if @dbg=1 exec sp__printf @sql
        exec(@sql)
        update l set sql=left(ltrim(rtrim(d.event_info)),128)
        from #lock l with (nolock) join #dbccout d with (nolock) on l.spid=@id
        select @i=@i+1
        end -- while

    drop table #dbccout
    end -- @tsql

exec sp__printf '-- sp__lock:%T: update other data','%t'  -- '%t' otherwise do not print date

-- update other data    (select * from #processes)
update l set
    host=p.hostname,waittime=p.waittime,
    p_status=p.status,
    [login]=p.loginame,
    open_trans=p.open_tran,last_batch=p.last_batch,
    blocking=p2.spid,
    n_locks=(select count(*) from #lock with (nolock) where #lock.spid=l.spid group by(spid))
from #lock l with (nolock)
join #processes p with (nolock) on l.spid=p.spid
left join #processes p2 with (nolock) on p.spid=p2.blocked

-- format 1st row to conditionate the output
/*
insert into #lock(spid,n_locks,
    [db_name],obj_name,[type],mode,[login],host,[sql])
select 0,999,
    '-db_name-','-obj_name----','--','--','-login-','-host-','-sql----------------'
*/
exec sp__printf '-- sp__lock:%T: complete db name and object name','%t'  -- '%t' otherwise do not print date

update l set [db_name]=d.name
from #lock l with (nolock) join master..sysdatabases d with (nolock)
on l.dbid=d.dbid

/*
declare @last_id int,@last_name sysname
select @i=min(id),@n=max(id) from #lock with (nolock)
while (@i<=@n)
    begin
    select @id=l.objid,@name=l.[db_name] from #lock l with (nolock) where id=@i
    if @last_id is null or @last_id!=@id
        begin
        select @sql='select @name=name from '+quotename(@name)+'..sysobjects with (nolock) where id='+convert(sysname,@id)+''
        if @dbg=1 exec sp__printf @sql
        select @name=@name+'('+convert(sysname,@id)+')'
        exec sp_executesql @sql,N'@name sysname out',@name=@name out
        end
    update #lock set obj_name=@name where id=@i
    select @i=@i+1,@last_id=@id,@last_name=@name
    end -- while
*/
-- sp__lock @dbg=1
select @sql=null
select @sql=coalesce(@sql,'')+'
    update #lock set obj_name=o.name
    from #lock l with (nolock)
    join '+quotename([db_name])+'..sysobjects o with (nolock)
    on l.objid=o.id'
from #lock l
group by [db_name]
if @dbg=1 and len(@sql)>3990 exec sp__printf '%s',@sql
exec(@sql)

exec sp__printf '-- sp__lock:%T: output','%t'  -- '%t' otherwise do not print date

-- select count(*) from #lock
if @dbg=1 select [db_name],spid from #lock with (nolock)
-- master..xp_fixeddrives
/*
    show lock in order:
    * more locked objs
    * lock most far (waittime desc or last_batch-current_timestamp)
    * that have more open_trans
    * that have a object name
    * lock of different login name
*/
select @n=count(*) from #lock l with (nolock)
exec sp__printf '-- sp__lock:%T: filtering %d records by:%s or spid %d',@n,@obj,@spid

-- declare @timer datetime
select  l.spid,l.[db_name],replace(l.obj_name,'___','.') as obj_name,l.type,l.mode,
        left(l.login,16) as [login],l.host,l.sql,l.p_status,l.resource,l.open_trans,l.status,
        datediff(ss,l.last_batch,@timer) as rsecs,l.blocking,l.n_locks
from #lock l with (nolock)
where (@spid is null or l.spid=@spid)
and (
    (@obj is null or l.obj_name like @obj)
    or (@obj is null or l.login like @obj)
    )
and ([type]!='DB' and mode!='S') -- shared db locks
and (not l.blocking is null or @blocking=0)
order by n_locks desc,l.spid,[db_name],obj_name -- datediff(ss,l.last_batch,@timer) desc,l.open_trans desc,l.obj_name desc

exec sp__printf '-- sp__lock:%T: drop temp tables','%t'  -- '%t' otherwise do not print date

drop table #processes
drop table #lock

end -- sp__lock