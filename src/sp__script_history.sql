/*  leave this
    l:see LICENSE file
    g:utility,script
    v:140108\s.zaglio: svr_id->srv_id
    r:120521\s.zaglio: added script header as -- or multi comment
    v:120517\s.zaglio: adapted to new fn__script_sysobjs
    v:120514\s.zaglio: added store of generic sql that begin with exec
    v:120509\s.zaglio: added store of generic sql
    r:120508\s.zaglio: adding store of generic sql
    r:120507\s.zaglio: added drop of objects and exists test on more crucial tables and index
    r:120504\s.zaglio: problem of drop fun X->create syn X
    r:120503\s.zaglio: introducing user in @obj to filter my objs
    v:120213\s.zaglio: adapted to new structures and fn__script_events
    r:120208\s.zaglio: adapting to new structures
    v:120206\s.zaglio: added usr column
    v:120126\s.zaglio: added top 100
    v:110830\s.zaglio: better help
    v:110624\s.zaglio: restyling of output and removed rev from scripting
    v:110622\s.zaglio: restyling of output
    r:110621\s.zaglio: fine filter on alter for non table objects
    r:110603\s.zaglio: added exclude
    r:110511\s.zaglio: added >= date
    r:110510\s.zaglio: generate script for historicized objects
    t:sp__Script_history '-60\\wsj\tempsa',@dbg=2
*/
CREATE proc sp__script_history
    @what       nvarchar(max) = null,
    @list       sysname = null,
    @grp        sysname = null,
    @opt        sysname = null,
    @dbg        int     = null
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
declare @top int select @top=100
if @what is null or object_id('log_ddl') is null goto help

-- ============================================================== declaration ==
declare
    @sql nvarchar(4000),@cond nvarchar(32),
    @id int,@dt datetime,@evot sysname,
    @tmp sysname,@sdt sysname,@usr sysname,
    @obj sysname, @obj_id sysname,@ev sysname,
    @drop bit,                                  -- option
    @i int,                                     -- index
    @iwhat sysname,                             -- inside truncated @what
    @crlf nvarchar(2),
    @lbl sysname

declare @excludes table(obj sysname)

-- insert before here --  @end_declare bit
if object_id('tempdb..#src') is null
    create table #src(lno int identity,line nvarchar(4000))

create table #objs(
    srv_id int,
    [db_id] int,
    id int,
    [name] sysname,
    [rel] sysname,
    [dt] datetime,
    ev sysname,
    evot sysname,       -- event object type
    [type] nvarchar(3) null,
    usr sysname null,
    uinfo sysname null,
    next_ev sysname null,
    next_evot sysname null
    )
alter table #objs add [sql] nvarchar(max)

-- =========================================================== initialization ==
select
    @drop=1-charindex('|nodrop|',@opt),
    @usr='',
    @crlf=crlf
from fn__sym()

while (left(ltrim(@what),len(@crlf))=@crlf)
    select @what=substring(rtrim(ltrim(@what)),len(@crlf)+1,len(@what))

select @iwhat=left(ltrim(@what),128)

-- ======================================================== second params chk ==
if left(@iwhat,1)='-'
    begin
    select @usr='\\'+dbo.fn__str_at(@iwhat,'\\',2)
    select @i=cast(dbo.fn__str_at(@iwhat,'\\',1) as int)
    select @dt=getdate()+@i
    select @iwhat=convert(sysname,@dt,126)+@usr
    end

-- ===================================================================== body ==

if left(@iwhat,7)='insert '
or left(@iwhat,3)='if '
or left(@iwhat,5)='exec '
or left(@iwhat,3)='-- '
or left(@iwhat,3)='/* '
    begin
    -- select * from fn__script_sysobjs((select ev from tids))
    exec sp__script_store
            @et='insert_data',@obj='data_script',
            @sql=@what,@dbg=@dbg
    goto ret
    end

insert @excludes(obj)
select token
from dbo.fn__str_table(replace(replace(@list,',','|'),';','|'),'|')

insert #src(line) select '/'+replicate('*',79)

if patindex('____-__-__T__:__:__.___',replace(@iwhat,' ','T'))>0
or patindex('____-__-__T__:__:__.___\\%',replace(@iwhat,' ','T'))>0
    begin
    if object_id('fn__script_trace') is null goto err_trc
    select
        @sdt=replace(dbo.fn__str_at(@iwhat,'\\',1),' ','T'),
        @usr='\\'+dbo.fn__str_at(@iwhat,'\\',2)
    if @usr='' select @usr='%'
    insert #src(line) select '** unScript from '+@iwhat
    -- sp__script_history '2012-02-08 14:37:14.057'
    -- drop table #objs
    -- select * from fn__script_trace(default,default,default) -- drop table #test
    -- declare @sql nvarchar(max),@iwhat sysname select @iwhat='2011-04-15T16:00:33.920'

    -- truncate table #objs
    -- declare @sql nvarchar(4000),@iwhat sysname select @iwhat='2011-06-20T18:04:57.800'
    -- declare @iwhat sysname select @iwhat='2012-02-08T14:37:14.057'
    truncate table #objs

    -- this encapsulation into exec allow update without dependency from fn__script_trace
    insert #objs(srv_id,db_id,usr,id,[name],[sql],rel,dt,ev,evot,[type])
    select
        a.srv_id,a.db_id,a.usr,a.id,a.[obj],a.[code],
        case
        when a.rel is null
        then convert(sysname,a.dt,12)+'.'+
             replace(left(convert(sysname,a.dt,8),5),':','')
        else convert(sysname,a.rel)
        end
        as rel,
        a.dt,
        upper(left(ev.cod,charindex('_',ev.cod)-1)) event,
        upper(substring(ev.cod,charindex('_',ev.cod)+1,128)) ev_obj_type,
        o.type
    -- select top 10 *
    from fn__script_trace(default,default,default) a
    -- obj must locally exists to ensure parent correct relations
    -- (drop of table do not involve trigger, index etc)
    left join sys.objects o with (nolock)
        on o.[name]=a.[obj]
    left join sys.indexes i with (nolock)
        on i.[name]=a.[obj]
    left join fn__script_sysobjs((select obj from tids)) so
        on so.cod=object_name(i.object_id)
    join fn__script_sysobjs((select ev from tids)) ev
        on a.ev=ev.id
    where dt>=@sdt
    and a.flags in ('ver')
    -- obj. and parent must exists (but include script for data)
    and not (coalesce(o.object_id,i.object_id) is null
             and a.[obj]!='DATA_SCRIPT'
            )
    -- exclude generated objs
    and not (charindex('generated by sp__script_alias',a.[code])
                between 20 and 80
             or
             charindex('g:sp__script_alias',a.[code])
                between 3 and 20
            )
    -- and a.udt is null
    and a.usr like @usr
    and so.id is null       -- and index do not refer to system obj
    order by dt,id

    -- exclude forwarded objs
    update o set
        uinfo=left(cast(oinfo.val2 as nvarchar(4000)),128)
    from #objs o
    cross apply fn__script_info(o.[name],'v','0') oinfo
    end -- date
else
    goto help

insert #src(line) select '** - objects in order of:'
insert #src(line) select '**    tables,indexes,functions,views,procs,synonym,triggers'
insert #src(line) select '** - dropped objects are not scripted'
insert #src(line) select '** - all the alteration of tables, idxs, etc.'
insert #src(line) select '** - only last of many alterations of fn & sp'
insert #src(line) select replicate('*',79)+'/'

if @dbg>1
    select *
    from #objs o
    order by dt desc,id desc

-- sp__script_history '2011-04-15 19:13:02.520' -- sp__script '2267'
-- select not dropped objects
-- drop table #obj_to_script
-- declare @excludes table(obj sysname)
select
    identity(int,1,1) as row,o.*,
    -- 110622\s.zaglio: round up to 10 minutes
    substring(dbo.fn__format(o.dt,'YYYYMMDD_HHMM',default),3,10)+'0'+usr.usr as usdt,
    uinfo
into #obj_to_script
-- select *
from (
    select
        [name],ev,evot,
        max(rel) as rel, max(dt) as dt,
        max(id) id
        -- case when count(*)>1 then max(id) else null end as id
    from #objs
    where ev!='DROP'
    group by [name],ev,evot
    -- ,case evot when 'table' then dt else 0 end -- causes duplicates
    ) o
left join (
    select
        [name],ev,evot,
        max(rel) as rel, max(dt) as dt,
        max(id) id
        -- case when count(*)>1 then max(id) else null end as id
    from #objs
    where ev='DROP'
    group by [name],ev,evot
    ) d -- ropped
on d.[name]=o.[name] and d.evot=o.evot /*and d.ev!=o.ev*/ and d.dt>=o.dt
join #objs usr on o.id=usr.id and (@usr='' or usr.usr=@usr)
left join @excludes ex on o.[name] like ex.[obj]
where d.ev is null
and   ex.[obj] is null
and   (not uinfo like 'generated by sp__script_%'
       or uinfo is null
      )
order by
    case o.evot
    when 'table' then 10
    when 'index' then 20
    when 'function' then 30
    when 'view' then 40
    when 'procedure' then 50
    when 'synonym' then 60
    when 'trigger' then 70      -- can use some other func/proc/view
    else 99
    end
    ,dt,id

drop table #objs

-- show list of filtered objects to allow visual exclusion
select name,ev,evot,rel,dt,uinfo from #obj_to_script

-- declare @id int,@usr sysname,@dt datetime,@evot sysname
-- truncate table #src
insert #src(line) select ''
select @tmp=''
declare cs cursor local for
    select name,ev,id,dt,usdt,evot
    -- select *
    from #obj_to_script
    order by row
open cs
while 1=1
    begin
    fetch next from cs into @obj,@ev,@id,@dt,@usr,@evot
    if @@fetch_status!=0 break
    if @usr!=@tmp
        begin
        insert #src(line) select ''
        insert #src(line)
            select '/*'+dbo.fn__format(@usr,'*< ',75)+' */'
        end

    select @obj_id=dbo.fn__hex(@id),
           @lbl='skip_'+lower(dbo.fn__format(@obj,'AN',default))

    if @drop=1
        begin

        -- try drop existing object if is not an alter table
        if @evot in ('procedure','function','synonym','view','trigger')
            exec sp__script @obj,@opt='drop'
        else
            begin
            if @evot ='table' and @ev='create'
                begin
                insert #src(line)
                select 'if exists(select null from sys.objects where name='''+@obj+''') '
                insert #src(line) select 'goto '+@lbl
                end
            if @evot ='index' and @ev='create'
                begin
                insert #src(line)
                select 'if exists(select null from sys.indexes where name='''+@obj+''') '
                insert #src(line) select 'goto '+@lbl
                end
            exec sp__script @obj_id,@opt='drop'
            end
        if @lbl!='skip_data_script'
            -- because all data_script has the same label
            insert #src select @lbl+':'
        end
    else
        begin
        if @evot in ('procedure','function') insert #src(line) select 'go'
        exec sp__script @obj_id
        insert #src(line) select 'go'
        end
    select @tmp=@usr
    end -- while of cursor
close cs
deallocate cs

insert #src(line) select ''
insert #src(line) select 'goto ret'
insert #src(line) select ''
insert #src(line) select 'err_drp:'
insert #src(line) select '  raiserror(''utilities must be installed before this operation'',11,1)'
insert #src(line) select '  goto ret'
insert #src(line) select 'ret:'

exec sp__print_table '#src'

drop table #src

goto ret

-- =================================================================== errors ==
err_trc:    exec @ret=sp__err 'fn__script_trace is required',@proc
            goto ret
err_log:    exec @ret=sp__err 'logddl not initialized',@proc
            goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    generate script for historicized objects.

Notes
    func,proc,synonym,

Parameters
    @what       can be:
                * name of a single object: will list last 1000 modifications
                * id of trace where to begin: will script it
                * ISO8601 date of trace where to begin
                  (aaaa-mm-ggThh:mm:ss.mmm) or (aaaa-mm-gg hh:mm:ss.mmm)
                  will script all objects from that date
                * ISO8601 date\\pc\usr will script from that date of objects
                  modified by "\\pc\usr"
                * a data script that begin with "IF " or "INSERT " or "exec "

    @list       list objects separated by |,;
                if @iwhat is a script instruction, the @list excludes objects
                if @iwhat is a group name, the @list define and re-define membership
                (sys objects are automatically excluded)
    @grp        (TODO)group name for objects selected between @iwhat and @excludes
    @opt        option          description
                nodrop          do not script as code using sp_executesql

Fields list mean
    tid     type of object
    id      row table id
    srv_id  server id
    db_id   database id
    lid     local object id
    flags   ver=version or 0(Zero)
    obj     object name or hash
    des     sql command
    usr_id  user id
    app_id  application id
    rel     release captured from header
    dt      utc datetime
    udt     sync datetime

Examples
    sp__script_history "2011-05-06 17:37:31.837"

    -- script all objs changed in the last 120 days by user X from pc Y
    sp__script_history "-120\\Y\X"

    -- insert data script
    sp__script_history  ''
                        if not exists(select null from tbl where id=123)
                        insert tbl(id,cd,txt)
                        select 123,''''cd'''',''''txt''''
                        ''
'
select @ret=-1

if object_id('log_ddl') is null
    begin
    exec sp__printframe 'The log_ddl table is absent.',
                        'Use sp__script_trace_db to install the tracer'
    goto ret
    end

help_trace_view:
select @iwhat=upper(@iwhat)

if not object_id('fn__script_trace') is null
    begin
    select @sql='
    select top (%top%)
        convert(binary(4),a.id) as id,
        convert(binary(4),a.srv_id) as srv_id,
        convert(binary(4),a.db_id) as db_id,
        a.obj,
        a.flags,
        a.usr,
        a.code,
        a.rel,
        upper(left(ev.cod,charindex(''_'',ev.cod)-1)) event,
        upper(substring(ev.cod,charindex(''_'',ev.cod)+1,128)) ev_obj_type,
        upper(left(ev.cod,charindex(''_'',ev.cod)-1)) event,
        a.dt
    from fn__script_trace(%what%,default,default) a
    join fn__script_sysobjs((select ev from tids)) ev
        on a.ev=ev.id
    where %cond%
    order by dt desc,id desc
    '
    if @iwhat is null select @iwhat='default',@cond='1=1'
    else
        if left(@iwhat,2)='0x'
            select @cond='id='+@iwhat,@iwhat='default'
        else
            select @iwhat=dbo.fn__str_quote(@iwhat,''''),@cond='1=1'

    exec sp__str_replace @sql out,'%top%|%what%|%cond%',@top,@iwhat,@cond
    if @dbg>0 exec sp__printsql @sql
    exec(@sql)
    if @@error!=0 and @dbg=0 exec sp__printsql @sql
    end
else
    exec sp__printf '\n*** fn__script_trace absent; will be installed from this sp ***'

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__script_history