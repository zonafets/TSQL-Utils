/*  leave this
    l:see LICENSE file
    g:utility,script
    v:131006.1200\s.zaglio:refactor and changed data to store
    v:131002.1100,131001\s.zaglio:better messages;test for more dependant objs
    v:130908;130731.1000\s.zaglio:warning "in the future";changed newer/older warning
    v:130712\s.zaglio:disable test of 130604 on alter
    v:130606\s.zaglio:improved warning on test of bad v-r tags
    v:130604\s.zaglio:test for more than 2 months older release
    v:130317;120919\s.zaglio:a bug near fn__context_info use;tested script_act
    v:120906;120905\s.zaglio:around script_act;added refer to "script_act"
    v:120823;120731\s.zaglio:added chk if not complete header and dis,dbg options,#!@msg_fl
    r:120724;120523\s.zaglio:about messages;removed range 0-65535 and tested future release
    v:120518.1800\s.zaglio:adapted to new fn__script_sysobjs
    v:120509;120503\s.zaglio:about help and debug;adopted skip of range 0-65535 and uppers
    v:120223;1140;120213\s.zaglio: a overflow near release;adapted to new fn__script_events
    v:120208;120207\s.zaglio:replaced identity;adapting to new log_ddl
    v:120126;111205\s.zaglio:reversed means of @msg option,added context info comunication
    v:110921;110824\s.zaglio:added skip of maintenance code and trim;removed use of try/c.
    v:110624\s.zaglio:log_ddl.id is no longer a progressive and utcdate
    v:110622\s.zaglio:modified host separator \ with _
    v:110621\s.zaglio:added msg for every store and more help
    v:110527\s.zaglio:added exclusions of sysobjs_ and _sysobjs
    v:110510;110504\s.zaglio:added specific skips;added chk of diff. users
    v:110418;110415\s.zaglio:added skip of utilities;adapted to log_ddl
    v:110325;110324\s.zaglio:add check of tids and flags;better msg, no prop.if same ver
    v:110323.1818;110323\s.zaglio:add ver. overwr. test;exclus. of some event from test
    v:110322;110321\s.zaglio:added release;called by tr__script_trace_db
    t:sp__script_trace
    t:sp__script_history
*/
CREATE proc sp__script_store
    @et sysname = null,                 -- event type
    @obj sysname = null,
    @sql nvarchar(max) = null,
    @opt sysname = null,                -- if called by command line
    @dbg int = null
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on

declare
    @proc sysname, @err int, @ret int,@no_opt varchar(1)

select
    @proc=object_name(@@procid), @err=0, @ret=0,
    @dbg=isnull(@dbg,0), @no_opt=''

-- dependencies test
if @obj='fn__script_info_tags' goto ret
if @obj='log_ddl' and @et='drop_table' goto err_tbl

if object_id('tids') is null
or object_id('fn__sym') is null
or object_id('fn__crc16') is null
or object_id('fn__str_quote') is null
or object_id('fn__context_info') is null
or object_id('fn__servername') is null
or object_id('fn__script_info_tags') is null
or object_id('flags') is null
or object_id('log_ddl') is null
or object_id('fn__script_sysobjs') is null
    goto wrn_dep

select @opt=case
            when @opt is null  then @no_opt
            else dbo.fn__str_quote(@opt,'|')
            end

-- ##########################
-- ##
-- ## transaction into try/catch into trigger
-- ##
-- ########################################################
/*
    begin try
    save tran ...
    begin tran ...
    unfortunatelly into a trigger any form of sub transaction is not possibile
    because rollback automatically even if the error is managed
    The procedure must be perfect!
*/

-- ================================================================= declares ==

declare
    @time datetime,
    @ms int,                                        -- milliseconds
    @i int,                                         -- index var
    @tmp nvarchar(max),

    @eq_body bit,                                   --
    @udt datetime,                                  -- last update time
    @flags smallint,
    @fver smallint,
    @pvft bit,                                      -- has version header

    @srv sysname,
    @app nvarchar(256),
    @usr nvarchar(256),
    @host nvarchar(256),
    @prev_usr nvarchar(256),
    @cmt nvarchar(4000),

    @id int,
    @start_id int,
    @counter_id int,
    @app_id int,
    @usr_id int,
    @host_id int,
    @event_id int,
    @obj_id int,
    @db_id int,
    @srv_id int,
    @parent_id int,

    -- hashes for faster search
    @app_hash int,
    @usr_hash int,
    @obj_hash int,
    @host_hash int,
    @db_hash int,
    @srv_hash int,

    -- type of records (tids)
    @tcnt tinyint,
    @tsql tinyint,
    @tdb tinyint,
    @tusr tinyint,
    @tobj tinyint,
    @tapp tinyint,
    @tsrv tinyint,
    @tev tinyint,
    @thost tinyint,
    /*  log_ddl content (select * from log_ddl)
        tid     rid         pid         txt             rel             flags
        ======= =========== =========== =============== =============== ======
        cnt     last id                 "id counter"
        svr     0           0           svr name
        db      svr id      0           db name
        obj     db id       0           obj name
        sql     obj_id      host id     code            last release    flg.ver
        host    svr id                  host name
        usr     host id     0           usr name
        app     host id                 app name
    */

    @tag nchar(1),                                  -- tag R or V
    @db sysname,
    @rel bigint,
    @old bigint,
    @old_flags smallint,
    @today_rel int,                                 -- calc. from date
    @dt datetime,                                   -- to calc cur_rel
    @prev_usr_id int,
    @hh nvarchar(32), @mi nvarchar(32),
    @info sysname,

    -- session config
    @msg_fl smallint,
    @msg nvarchar(1024),
    @moff sysname,@mon sysname,                     -- msg on/off codes ...
    @dis sysname,                                   -- disable
    @dbgswc sysname,                                -- debug switch

    @et_cmd nvarchar(32),                           -- right split of @et
    @et_cmd_typ nvarchar(32),                       -- left split of @et

    -- options
    @opt_dbg bit,                                   -- switch debug mode on/off
    @opt_dis bit,                                   -- disable store
    @opt_ena bit,                                   -- enable store
    @opt_moff bit,                                  -- message off
    @opt_mon bit,                                   -- message on
    @opt_mdef bit,                                  -- only system messages

    -- debug info
    @dbg_nfo1 sysname,
    @dbg_nfo2 sysname,
    @dbg_nfo3 sysname,
    @dbg_nfo4 sysname,

    @end_declare bit

-- ===================================================================== init ==

select
    @time  =getdate(),
    @dis   =@proc+':disable',
    @dbgswc=@proc+':debug',
    @mon   =@proc+':message_on',
    @moff  =@proc+':message_off',
    @msg_fl=case
            when dbo.fn__context_info(@mon)>0 then 1
            when dbo.fn__context_info(@moff)>0 then -1  -- OFF win on ON
            else 0
            end

-- options
if @opt!=@no_opt
    select
        @opt_dbg  = charindex('|dbg|',@opt),
        @opt_dis  = charindex('|dis|',@opt),
        @opt_ena  = charindex('|ena|',@opt),
        @opt_moff = charindex('|moff|',@opt),
        @opt_mon  = charindex('|mon|',@opt),
        @opt_mdef = charindex('|mdef|',@opt)

-- debug info
if @dbg=1
    select
        @dbg_nfo1='@tag=%s, @flags=%s, @tmp=%s',
        @dbg_nfo2='@hh=%s,@mi=%s,@rel=%s,@cur=%s',
        @dbg_nfo3='tag=%s,rel=%s,usr=%s',
        @dbg_nfo4='typ=%s, obj=%s, hast=%d, pid=%d'

-- ========================================================= param formal chk ==

if (@et is null or @obj is null or @sql is null)
    begin
    if @opt!=@no_opt
        begin
        if @opt_dbg=1
            begin
            -- debug on/off
            if dbo.fn__context_info(@dbgswc)>0
                begin
                exec sp__context_info @dbgswc,@opt='del'
                print @proc+': debug disabled'
                end
            else
                begin
                exec sp__context_info @dbgswc
                print @proc+': debug enabled'
                end
            end
        if @opt_dis=1
            begin
            -- disable
            exec sp__context_info @dis
            end
        if @opt_ena=1
            begin
            -- enable
            exec sp__context_info @dis,@opt='del'
            end
        if @opt_moff=1
            begin
            -- system and normal messages off
            exec sp__context_info @mon,@opt='del'
            exec sp__context_info @moff
            end
        if @opt_mon=1
            begin
            -- all messages on
            exec sp__context_info @moff,@opt='del'
            exec sp__context_info @mon
            end
        if @opt_mdef=1
            begin
            -- default: print only system messages and when obj has tag
            exec sp__context_info @mon ,@opt='del'
            exec sp__context_info @moff,@opt='del'
            end
        goto ret
        end

    goto help
    end -- no params given

-- check for particular situation that skip store of script

if dbo.fn__context_info(@dbgswc)>0 and @dbg=0 select @dbg=1
if dbo.fn__context_info(@dis)>0 goto ret

select @sql=ltrim(rtrim(@sql))

select @tmp=left(@sql,512)

if charindex('[%group%]',@tmp)>0 goto err_hdr
if charindex('[%keywords%]',@tmp)>0 goto err_hdr
if patindex('%\[%]%[%]:%',@tmp)>0 goto err_hdr

-- skip specific maintenance
if @sql like 'ALTER INDEX % REORGANIZE WITH %' goto ret

-- skip MSOffice and specific application or system obj
-- select * from dbo.fn__script_sysobjs((select obj from tids))
if len(@obj)=3 goto ret             -- generically the sys obj are or 3 letters
if left(@obj,3) in ('dt_') goto ret

if @dbg=1
    begin
    raiserror(@proc,10,0) with nowait
    print 'obj:'+isnull(@obj,'???')
    print 'sql:'+isnull(@sql,'???')
    end

select
    @start_id=  power(-2,31),
    @dt=        getdate(),
    @today_rel= cast(convert(sysname,@dt,12)+
                     left(replace(convert(sysname,@dt,8),':',''),4)
                     as int
                    ),
    @tcnt=  1,
    @tsrv=  tids.srv,
    @tdb=   tids.db,
    @tusr=  tids.usr,
    @tapp=  tids.app,
    @tsql=  tids.code,
    @tobj=  tids.obj,
    @tev=   tids.ev,
    @thost= tids.host,
    @flags= 0,
    @srv=   upper(dbo.fn__servername(null)),
    @db=    upper(db_name()),
    @app=   upper(left(app_name(),256)),
    @host=  upper(left(system_user+'@'+host_name(),256)),
    @usr=   null,
    @obj=   upper(@obj),
    @srv_hash=dbo.fn__crc32(@srv),
    @db_hash =dbo.fn__crc32(@db),
    @app_hash=dbo.fn__crc32(@app),
    @obj_hash=dbo.fn__crc32(@obj),
    @host_hash=dbo.fn__crc32(@host),
    @fver=  flg.ver,
    @i=charindex('_',@et),
    @et_cmd = left(@et,@i-1),
    @et_cmd_typ = substring(@et,@i+1,128),
    @pvft=  case                                -- has version header
            when @et_cmd_typ
                 in ('proc','view','function','trigger')
            then 1
            else 0
            end,
    @udt=   getutcdate()
from tids,flags flg

-- excludes system objects derivated (prefix, postfix, same)
if exists(
    select top 1 null
    from dbo.fn__script_sysobjs(@tobj)
    where cod+'_'=left(@obj,4)
    or '_'+cod=right(@obj,4)
    or cod=@obj
    )
    goto ret

-- ============================================= check header and old version ==

select @tmp=null
select top 1
    @tag=tag,
    @tmp=convert(nvarchar,val1),
    @usr=convert(nvarchar,val2),
    @cmt=convert(nvarchar,val3)
from dbo.fn__script_info_tags(@sql,'rv',0)

if not @tag is null and @msg_fl!=-1 select @msg_fl=1

if @tag='v' or @tag is null select @flags=@flags|@fver

if @tag in ('r','v') and (isnull(@usr,'')='' or isnull(@cmt,'')='')
    goto err_hdr

-- if @cmt='' -- no comment or omitted author

if @dbg=1 exec sp__printf @dbg_nfo1,@tag,@flags,@tmp

select @msg=''
if @tmp is null
    begin
    if @pvft=1
        begin
        -- print dbo.fn__str_at('alter proc','',2)
        select @msg='no release info in "'+@obj+'"'
        end
    end
else
    begin
    select @i=charindex('.',@tmp)
    if @i=0
        select @mi='0000',@hh=@tmp
    else
        select  @hh=substring(@tmp,1,@i-1),
                @mi=right('0000'+substring(@tmp,@i+1,32),4)
    if len(@hh)!=6
        select @msg='wrong version near "%tmp%"'
    else
        begin
        if @hh+@mi like '%[^0-9]%'
            select @msg='bad release number near "%tmp%"'
        else
            begin
            select @rel=cast(@hh+@mi as bigint)
            if @dbg=1 exec sp__printf @dbg_nfo2,@hh,@mi,@rel,@today_rel
            if @rel>2147483648 goto err_int
            if @rel>@today_rel
                select @msg='obj version of "%tmp%" is in the future',
                       @tmp=@obj

            if @et_cmd='alter'
                begin
                declare @nrel float select @nrel=abs(@rel-@today_rel)
                if (@nrel>2000000) -- two months
                    select @msg='obj "%tmp%" newer or older than 2 months',
                           @tmp=@obj
                end -- if @et_cmd=

            end -- if ok yymmdd
        end -- if good release info
    end -- if not @tmp/src is null

if @msg_fl=1 and @msg!='' print @proc+':WARNING:'+replace(@msg,'%tmp%',@tmp)

if @dbg=1 exec sp__printf @dbg_nfo3,@tag,@rel,@usr
-- notes: when CATCH is released, error 3930 occur

-- ================================================= get/store srv/db/usr nfo ==

-- do not store utilities like sp__, fn__, ix__, ...
if substring(@obj,3,2)='__' goto ret

select
    @counter_id=case when l.tid=@tcnt  then id else @counter_id end,
    @srv_id=    case when l.tid=@tsrv  then id else @srv_id end,
    @db_id =    case when l.tid=@tdb   then id else @db_id  end
from log_ddl l
where l.tid in (@tsrv,@tdb,@tcnt)

if @counter_id is null
    begin
    select @counter_id=@start_id
    insert log_ddl(srv,id,tid,rid,pid,flags,txt,dt,[key])
    select @counter_id, @counter_id, 1,@counter_id+3, 0, 0, 'id counter', @udt, 0
    end

if @srv_id is null
    begin
    select @srv_id=@start_id+1
    insert log_ddl(srv,id,tid,rid,pid,flags,txt,dt,[key])
    select @srv_id, @srv_id, @tsrv, 0, 0 as flags, 0, @srv, @udt, @srv_hash
    end

if @db_id is null
    begin
    select @db_id=@start_id+2
    insert log_ddl(srv,id,tid,rid,pid,flags,txt,dt,[key])
    select @srv_id, @db_id, @tdb, @srv_id, 0, 0, @db, @udt, @db_hash
    end

-- search or insert host_id
select @host_id=id
from log_ddl [log] -- with (index(ix_log_ddl_key))
where srv=@srv_id
and tid=@thost
and [key]=@host_hash
and [log].skey=@host
and rid=@srv_id

if @host_id is null
    begin
    update log_ddl with (updlock) set
        @host_id=rid=rid+1
    where id=@counter_id
    insert log_ddl(srv,tid,id,rid,pid,flags,[key],txt,dt)
    select @srv_id,@thost,@host_id,@srv_id,0,0,@host_hash,@host,@udt
    end

-- search obj_id
select @obj_id=id
from log_ddl [log] -- with (index(ix_log_ddl_key))
where srv=@srv_id
and tid=@tobj
and [key]=@obj_hash
and [log].skey=@obj
and rid=@db_id

if @obj_id is null
    begin
    update log_ddl with (updlock) set
        @obj_id=rid=rid+1
    where id=@counter_id
    insert log_ddl(srv,tid,id,rid,pid,flags,[key],txt,dt)
    select @srv_id,@tobj,@obj_id,@db_id,0,0,@obj_hash,@obj,@udt
    end

-- ================================================= compare with old version ==

select @event_id=id
from fn__script_sysobjs(@tev) ev
where ev.cod=@et

-- read last occurrence of same obj
-- sp__script_trace
select top 1
    @old_flags=flags,
    @eq_body=case when @sql=txt then 1 else 0 end,
    @old=rel,        -- rel/ver
    @prev_usr_id=pid
from log_ddl [log] -- with (nolock,index(ix_log_ddl_key))
where srv=@srv_id
and tid=@tsql
and [key]=@obj_hash
and rid=@obj_id
order by dt desc

-- update log_ddl set c5=1103221000,rid=1234 where id=7
-- delete from log_ddl where id=9
if @old>@rel
and @msg_fl=1
    begin
    select @msg=@proc+': WARNING :probable version conflict'+char(13)
               +'this '
               +substring(cast(@rel as nvarchar),1,6)+'.'
               +substring(cast(@rel as nvarchar),7,4)
               +'is older than previous '
               +substring(cast(@old as nvarchar),1,6)+'.'
               +substring(cast(@old as nvarchar),7,4)
               +' use sp__script_diff @obj to see differences'
    print @msg
    end
else
    begin
    if (@prev_usr_id!=@usr_id)
    and @msg_fl=1
        begin
        select top 1 @prev_usr=txt from log_ddl where id=@prev_usr_id
        select @msg=@proc+': WARNING :previously changed by user "'
                   +isnull(@prev_usr,'(unk)')+'".'
                   +' Use sp__script_diff @obj to see differences.'
        print @msg
        end
    end -- prev_host

select
    @eq_body=isnull(@eq_body,0),    -- if is new:
    @old_flags=isnull(@old_flags,0) -- is a release

if @old=@rel                    -- if version/release number is equal
and @old_flags&@fver=@fver      -- and prev. store is a ver. and not a rel.
and @eq_body=0                  -- but bodies are different
and @flags&@fver=@fver          -- and the new body is a version too,
    if @msg_fl=1
        begin
        select @msg=@proc+
                   +':WARNING:same version with different body will '
                   +'not be distributed'
        print @msg
        end

if @eq_body != 0 goto ret

-- ====================================================== store reference ids ==

-- search or insert usr_id
if @usr is null -- if drop ... try to go back to usr from host
    begin
    select @usr_id=id,@usr=skey
    from log_ddl [log] -- with (index(ix_log_ddl_key))
    where srv=@srv_id
    and tid=@tusr
    and rid=@host_id
    if @@rowcount=0 select @usr_id=@host_id
    end
else
    begin
    select @usr_hash=dbo.fn__crc32(@usr)

    select @usr_id=id
    from log_ddl [log] -- with (index(ix_log_ddl_key))
    where srv=@srv_id
    and tid=@tusr
    and [key]=@usr_hash
    and [log].skey=@usr
    and rid=@host_id

    if @usr_id is null
        begin
        update log_ddl with (updlock) set
            @usr_id=rid=rid+1
        where id=@counter_id
        insert log_ddl(srv,tid,id,rid,pid,flags,[key],txt,dt)
        select @srv_id,@tusr,@usr_id,@host_id,0,0,@usr_hash,@usr,@udt
        end
    end

-- search or insert app

-- app info are stored as stand alone
select @app_id=id
from log_ddl [log] -- with (index(ix_log_ddl_key))
where srv=@srv_id
and tid=@tapp
and [key]=@app_hash
and [log].skey=@app
and rid=@host_id

if @app_id is null
    begin
    update log_ddl with (updlock) set
        @app_id=rid=rid+1
    where id=@counter_id
    insert log_ddl(srv,tid,id,rid,pid,flags,[key],txt,dt)
    select @srv_id,@tapp,@app_id,@host_id,0,0,@app_hash,@app,@udt
    end

-- ==================================================================== store ==

update log_ddl with (updlock) set
    @id = rid = rid+1
where id=@counter_id
insert log_ddl(
    srv,tid,id,rid,pid,flags,
    [key],txt,ev,rel,dt
    )
select
    @srv_id,@tsql,@id,@obj_id,@usr_id,@flags,
    @obj_hash,@sql,@event_id,@rel,@udt

select @i=@@rowcount
-- select @id=lid from log_ddl where id=@id
select @ms=datediff(ms,@time,getdate())
if @msg_fl=1
    print @proc+': "'+@obj+'" computed and stored in '+convert(sysname,@ms)
               +'ms with id '
               +substring(dbo.fn__hex(@id),3,8)
               +' on ['+@db+']. See SP__SCRIPT_HISTORY.'

-- application triggers
if not object_id('script_act') is null
    begin
    /*  if is an index (todo:rule & constraint), search for parent */
    if @et_cmd_typ='index'
        begin
        -- unfortunatelly drop index is not catched because
        -- do not exists anymore
        select @parent_id=object_id from sys.indexes where name=@obj
        select @obj=name,@obj_hash=dbo.fn__crc32(upper(name))
        from sys.objects o
        where object_id=@parent_id
        end
    if @dbg=1 exec sp__printf @dbg_nfo4,@et_cmd_typ,@obj,@obj_hash,@parent_id

    select @sql=null
    select @sql=isnull(@sql+char(13),'')+txt
    from script_act
    where pid=@obj_hash
    order by idx
    if isnull(@sql,'')!=''
        begin
        exec(@sql)  -- use of try-catch will rollback all in case of error
        if @@error!=0 exec sp__printsql @sql
        end
    end

/*  removed because sqlagent errors
if not object_id('sp__script_sync') is null exec sp__script_sync @opt='run'
*/

goto ret

-- =================================================================== errors ==
err_tbl:
raiserror('before drop this table, disable trace db trigger',11,1)
rollback

err_int:
select @msg='release out of range (>214748.3648).'+
            'Your TSQL was executed but not stored.'
raiserror (@msg,11,1)
goto ret

err_rel:
select @msg='obj %s compiled but not stored because '+
            'you specified a version in the future or 2 months older:'+
            ' %s.%s VS %d'
raiserror(@msg,11,1,@obj,@hh,@mi,@today_rel)
goto ret

err_hdr:
select @msg='WRONG HEADER: missing AUTHOR or COMMENT in tag R,V '
           +'or %%group%%, %%keywords%%.'
raiserror (@msg,11,1)
rollback
goto ret

wrn_dep:
print @proc+': WARNING :not executed because a base utility is absent.'
goto ret

-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    Called by tr__trace or sp__trace_event,
    store info about DDL event in table LOG_DDL.
    Called by sp__script_history,
    store info about DML event in table LOG_DDL.

Notes
    * Show only messages when object has tags. See MOFF,MDEF options.
    * if a reference is present into "script_act", do that action.
      (this is like a trigger related to any action about an object)

Parameters
    @et     see db trigger
    @obj    see db trigger
    @sql    see db trigger
    @opt    options
            moff    hide all messages
            mon     show all messages
            mdef    reset to default
            dis     disable the store in case of inside error
            ena     re/enable the store
            dbg     enable debug info

'

-- check for foundamental objects presence
select @i=1,@tmp='tids|flags|log_ddl|fn__script_sysobjs'
while 1=1
    begin
    select @obj=dbo.fn__str_at(@tmp,'|',@i),@i=@i+1
    if @obj is null break
    if object_id(@obj) is null
        exec sp__printf 'WARNING:%s is a foundamental object',@obj
    end

exec sp__printf '
List prefix,postfix or object name that will be excluded by this sp
'
select @tobj=obj from tids
exec sp__select_astext
    'select cod as sysobj from dbo.fn__script_sysobjs({1})',
    @header=0,@p1=@tobj
select @ret=-1
ret:
return @ret
end -- drop proc sp__script_store