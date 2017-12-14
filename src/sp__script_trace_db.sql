/*  leave this
    l:see LICENSE file
    g:utility,script
    v:131201.0900\s.zaglio: adapted to change of tids.svr->tids.srv
    v:131125\s.zaglio: moved manage of log_ddl into sp__utility_setup
    v:131002\s.zaglio: moved code from trigger db to sp__script_store
    v:120924\s.zaglio: added upgrade of log_ddl from 1477379425 to 45011731
    v:120907\s.zaglio: removed skip of objs %__% from tr
    v:120824\s.zaglio: bug when zero condition near drop of fn__script_trace
    v:120517\s.zaglio: bug about create of fn__script_trace
    v:120516\s.zaglio: adapted to new fn__script_sysobjs
    v:120512.1522\s.zaglio: managed new DML and CTRL events
    v:120213\s.zaglio: adapted to new fn__script_events
    v:120208\s.zaglio: removed identity in log_ddl and done fn__script_trace
    r:120207\s.zaglio: working
    r:120206\s.zaglio: modified fn__script_trace and log_ddl
    d:120103\s.zaglio: sp__util_ddl
    v:111205\s.zaglio: bug given by change of sp__script_compile beahviour
    v:110830\s.zaglio: adapted to new fn__buildin
    v:110629\s.zaglio: now trigger exclude %__%
    v:110628.1644\s.zaglio: managed not presence of sp__script_store
    v:110624\s.zaglio: added remove
    d:110623\s.zaglio: sp__script_trace
    v:110510\s.zaglio: added trace view filter by id and obj name
    v:110415.1712\s.zaglio: added test of cmptlvl and fn__strace generation
    v:110315\s.zaglio: reduced table size and introduced some checks and exclus.
    v:110313\s.zaglio: done vertioning of all db objects
    r:110312\s.zaglio: 1st draft
    t:sp__script_trace_db 'install' -- sp__Script_history
    t:sp__script_trace_db 'uninstall'
    t:sp__script_trace_db 'remove'
    t:select * from log_ddl order by dt desc
*/
CREATE proc sp__script_trace_db
    @opt nvarchar(4000)=null,
    @dbg bit=null
as
begin
set nocount on
/*
select t.name,*
from sys.trigger_events e
join sys.triggers t
on t.object_id=e.object_id
select * from sys.sql_modules where object_id=142675606
select * from sys.events
select * from sys.trigger_events e
*/
declare @proc sysname,@ret int
select  @proc=object_name(@@procid),@ret=0,@dbg=isnull(@dbg,0),
        @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

declare
    @sql nvarchar(max),@tr_name sysname,@events nvarchar(max),
    @tab2 sysname,@crlf nvarchar(2),@srv_id int,@db_id int,
    @tmp nvarchar(4000),@fdb smallint,
    @tsrv tinyint,@tdb tinyint,@thost tinyint,
    @tapp tinyint,@tsql tinyint,@tobj tinyint,
    @tev tinyint,
    @cond nvarchar(32),@db sysname,@srv sysname,
    @srv_hash int,@db_hash int,@udt datetime,
    @counter_id int,
    @cmd_install bit,@cmd_uninstall bit,
    @cmd_remove bit,@upgrade bit,
    @ftype smallint

select
    @counter_id =-2147483648,
    @upgrade    =0,
    @udt=   getutcdate(),
    @srv=   dbo.fn__servername(null),
    @db=    db_name(),
    @srv_hash=dbo.fn__crc32(@srv),
    @db_hash=dbo.fn__crc32(@db),
    @cmd_remove=charindex('|remove|',@opt),
    @cmd_install=charindex('|install|',@opt),
    @cmd_uninstall=charindex('|uninstall|',@opt),
    @srv_id=@counter_id+1,
    @db_id= @counter_id+2,
    @tr_name=replace(@proc,'sp_','tr_'),
    @crlf=crlf,@tab2='    '
from
    fn__sym()


-- prevent errors due change to tids,flags
if (@cmd_install=@cmd_uninstall and @cmd_remove=0) goto help

if @dbg=0 and exists(select null from sys.triggers t where t.name=@tr_name)
    begin
    exec('drop trigger ['+@tr_name+'] on database')
    if @@error!=0 goto err_rem
    else exec sp__printf 'DB trace trigger %s removed',@tr_name
    end

if @cmd_uninstall=1 goto ret

if @cmd_remove=1
    begin
    drop table LOG_DDL
    goto ret
    end

exec sp_executesql N'
select
    @tsrv=  tids.srv,
    @tdb=   tids.db,
    @thost= tids.host,
    @tapp=  tids.app,
    @tsql=  tids.code,
    @tobj=  tids.obj,
    @tev=   tids.ev,
    @fdb=   flags.db,
    @ftype= flags.[type]
from
    tids,flags
',N'
    @tsrv tinyint out,@tdb tinyint out,@thost tinyint out,
    @tapp tinyint out,@tsql tinyint out,@tobj tinyint out,
    @tev tinyint out,@fdb smallint out,@ftype smallint out
',
    @tsrv=@tsrv out,@tdb=@tdb out,@thost=@thost out,
    @tapp=@tapp out,@tsql=@tsql out,@tobj=@tobj out,
    @tev=@tev out,@fdb=@fdb out,@ftype=@ftype out

if @opt is null or (@cmd_install=@cmd_uninstall and @cmd_remove=0)
    goto help

create table #blob(id int identity,blob ntext)
create table #src(lno int identity,line nvarchar(4000))
create table #vars (id nvarchar(16),value sql_variant)

insert #vars select '%buildin%',dbo.fn__script_buildin(getdate(),1,@proc,'autogeneration')
insert #vars select '%proc%',   @proc
insert #vars select '%tr_name%',@tr_name
insert #vars select '%tsrv%',   @tsrv
insert #vars select '%tdb%',    @tdb
insert #vars select '%thost%',  @thost
insert #vars select '%tapp%',   @tapp
insert #vars select '%tsql%',   @tsql
insert #vars select '%tobj%',   @tobj

-- ================================================================= db trace ==

db_trace:

if (select cmptlevel
    from master..sysdatabases
    where [name]=@db
    )<90
    goto err_cml

-- ============================================================ upgrade table ==

    exec sp__utility_setup @opt='run|log_ddl'

-- =============================================== re-create reading function ==
    -- drop function fn__script_trace
    if  object_id('fn__script_trace') is null or
        exists(
        select null
        from dbo.fn__script_info('fn__script_trace','v',0)
        where val1!='131006.1100'
        )
        begin
        if not object_id('fn__script_trace') is null
            exec('drop function fn__script_trace')
        exec sp__printf '-- creating fn__script_trace'
        exec('/*  leave this
    l:see LICENSE file
    v:131006.1100\sp__script_trace: generated automatically
    t:select * from fn__script_trace(null,null,null) order by dt desc
*/
create function fn__script_trace(
    @obj sysname,
    @p2 bit,@p3 bit
    )
returns table
as
return
select
    l.id,
    l.srv srv_id,
    o.rid db_id,
    o.skey as obj,
    case l.tid
    when tids.code then case
        when l.flags & flg.ver=flg.ver then ''ver''
        else ''rel''
        end -- tsql
    else cast(l.flags as nvarchar)
    end as flags,
    u.skey as usr,
    substring(l.txt,1,4000) as code,
    l.ev,
    l.rel,
    l.dt
from tids,flags flg,log_ddl l with (readpast)
join log_ddl o with (readpast)
on o.tid=(select obj from tids) and o.id=l.rid
join log_ddl u with (readpast)
on u.tid=(select usr from tids) and u.id=l.pid
where l.tid=tids.code
and (@obj is null or
     l.rid=(select id
            from log_ddl
            where tid=(select obj from tids)
            and [key]=dbo.fn__crc32(@obj)
            and skey=@obj
            )
     )
-- end fn__script_trace
'
    )
    end

-- ============================================================= trigger code ==
insert #blob(blob)
select '/*  leave this
    g:utility,trace
    v:%buildin%
    d:110628\s.zaglio:tr__script_trace
*/'

insert #blob(blob)
select 'create trigger %tr_name%
on database
for

'

-- =================================================================== events ==

select identity(int,1,1) id,@tab2+cod ev
into #events
-- select *
from fn__script_sysobjs(@tev) ev
join dbo.fn__str_table(@opt,'|') op
on op.token!='' and ev.cod like '%'+op.token+'%'
where ev.flags&@fdb=@fdb
and ev.flags&@ftype=0

if @@rowcount=0
    insert #events(ev)
    select @tab2+cod ev
    -- select *
    from fn__script_sysobjs(@tev) ev
    where ev.flags&@fdb=@fdb
    and ev.flags&@ftype=0

update #events set ev=ev+','
where id!=(select max(id) from #events)

insert #blob(blob) select ev from #events
if @@rowcount=0 goto err_ev

insert #blob(blob)
select 'as
begin
set nocount on
declare
    @et sysname,@obj sysname,@app nvarchar(256),
    @sql nvarchar(max)

select
    @app=left(app_name(),256)

if left(@app,8)=''SQLAgent'' return

select @et=EVENTDATA().value(''(/EVENT_INSTANCE/EventType)[1]'',''nvarchar(256)''),
       @obj=EVENTDATA().value(''(/EVENT_INSTANCE/ObjectName)[1]'',''nvarchar(256)''),
       @sql=EVENTDATA().value(''(/EVENT_INSTANCE/TSQLCommand)[1]'',''nvarchar(max)'')

if object_id(''sp__Script_store'') is null goto err_prc

exec sp__script_store @et,@obj,@sql
goto ret

-- =================================================================== errors ==
err_prc:    print ''%tr_name%: WARNING sp__script_store not found to store ''+@obj

ret:
end -- trigger %tr_name%
'
-- split blob into lines
exec sp__write_ntext_to_lines @crlf=0

-- replace macros
exec sp__str_replace '#src','#vars'

/*
<EVENT_INSTANCE>
    <EventType>type</EventType>
    <PostTime>date-time</PostTime>
    <SPID>spid</SPID>
    <ServerName>name</ServerName>
    <LoginName>name</LoginName>
    <UserName>name</UserName>
    <DatabaseName>name</DatabaseName>
    <SchemaName>name</SchemaName>
    <ObjectName>name</ObjectName>
    <ObjectType>type</ObjectType>
    <TSQLCommand>command</TSQLCommand>
</EVENT_INSTANCE>
*/

if @dbg=1 exec sp__printsql '#src'
else
    begin
    exec @ret=sp__script_compile @opt='noalter'
    if @ret!=0 exec sp__printsql '#src'
    else exec sp__printf 'DB trace trigger %s installed',@tr_name
    end

goto ret

-- =================================================================== errors ==
err_cml:    exec @ret=sp__err 'compatibility level to low; Use:
        declare @db sysname select @db=db_name()
        EXEC sp_dbcmptlevel @db, 90',@proc goto ret
err_rem:    exec @ret=sp__err 'trigget not removed',@proc goto ret
err_ev:     exec @ret=sp__err 'no events to attach',@proc goto ret
-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    install/upgrade/uninstall DDL trigger.
    (Data Definition Language)

Notes
    Create the fn__script_trace.
    The DB trigger call the "sp__script_store"
    and this run a job that call the "sp__script_sync".
    See also sp__script_history.

Parameters
    @opt    options
            install     install db trigger
            uninstall   uninstall db trigger
            event|...   limit

Examples
    sp__script_trace_db "install"

-- List of events
'
exec sp__select_astext '
    select
        ev.cod as [*event name*],
        case
        when ev.flags & flags.srv = flags.srv
        then ''srv''
        when ev.flags & flags.db = flags.db
        then ''db''
        end as [*type*]
    from flags,fn__script_sysobjs((select ev from tids)) ev
    where ev.flags&flags.db=flags.db
    and ev.flags&flags.[type]=0
    order by 1
    ',@header=1

help_trace_view:
if not object_id('fn__script_trace') is null
and not object_id('log_ddl') is null
    begin
    select @sql='
    select *
    from fn__script_trace(%obj%,default,default)
    where %cond%
    order by dt desc,id desc
    '
    if @db is null select @db='default',@cond='1=1'
    else
        if isnumeric(@db)=1
            select @cond='id='+@db,@db='default'
        else
            select @db=dbo.fn__str_quote(@db,''''),@cond='1=1'

    exec sp__str_replace @sql out,'%obj%|%cond%',@db,@cond
    exec(@sql)
    end
else
    exec sp__printf '\n*** fn__script_trace absent; will be installed from this sp ***'

ret:
return @ret
end -- sp__script_trace_db