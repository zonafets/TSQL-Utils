/*  leave this
    l:see LICENSE file
    g:utility
    v:130605\s.zaglio: removed printf deprecated parameters
    v:091018\s.zaglio: NB: to remake&reduce using sp__loop
    v:090130\S.Zaglio: added a note about an error unmanaged
    v:090127\S.Zaglio: updated use of fn__servername
    v:090121\S.Zaglio: added @err_msg out
    v:081230\S.Zaglio: added @noexec to show only syntax
    v:081224\S.Zaglio: added quoted name management
    v:081223\S.Zaglio: added multilevel @dbg and corrected a bug on import of remote trace
    v:081218\S.Zaglio: replace @import_remote_trace with @trace_import
    v:081211\S.Zaglio: added @simul param to count rows will affected
    v:081209\S.Zaglio: corrected a bug on import of remote not ordered log
    v:081201\S.Zaglio: added @trace_proc for sp__trace
    v:081128\S.Zaglio: added relation of msg err to id with ref_id
    v:081126\S.Zaglio: complete rewrite of old one (now sp__run_sql_old)
    t:
        begin
        declare @r int,@rs bigint,@e int
        -- test simple local sql
        exec @r=sp__run_sql 'select top 3 * from sysobjects',@rows=@rs out ,@err=@e out, @dbg=1
        exec sp__printf '@r=%d @rows=%d @err=%d',@r,@rs,@e
        -- test error
        exec @r=sp__run_sql 'select tap 3 * from sysobjects',@rows=@rs out ,@err=@e out, @dbg=1
        exec sp__printf '@r=%d @rows=%d @err=%d',@r,@rs,@e
        -- test multiple server & db
        exec @r=sp__run_sql 'select top 3 *,rand(id) as ord from sysobjects order by ord',
                @rows=@rs out ,@err=@e out, @svrs='WSJ-VRT|SELFLINK|SELFLINK',
                @dbs='master|msdb|tempdb', @trace=1,@dbg=1
        exec sp__printf '@r=%d @rows=%d @err=%d',@r,@rs,@e
        end
*/
CREATE proc [dbo].[sp__run_sql]
    @sql nvarchar(4000)=null,-- use /*o:???*/ for obj replacement
    @v1 sql_variant=null,    -- replacer for first %s or %d
    @v2 sql_variant=null,    -- replacer for next %s or %d
    @v3 sql_variant=null,    -- replacer for next %s or %d
    @v4 sql_variant=null,    -- replacer for next %s or %d
    @svrs nvarchar(4000)=null, -- must be a linked server, can be multiple svr1|svr2
    @dbs  nvarchar(4000)=null,
    @rows bigint=null out,     -- return inside/remote rowcount
    @err int=null out,
    @err_msg nvarchar(4000)=null out,
    @trace bit=0,
    @trace_import bit=1,
    @trace_proc sysname=null,
    @simul bit=0,
    @dbg smallint=0,
    @print bit=0,
    @noexec bit=0
as
begin
if @dbg<0 begin exec sp__printf '@@nestlevel=%d',@@nestlevel end
set nocount on
set @rows=null
if @sql is null goto help
-- initialization
set @sql=replace(@sql,'"','''')
set @sql=dbo.fn__printf(@sql,@v1,@v2,@v3,@v4,null,null,null,null,null,null)
if @svrs is null set @svrs=dbo.fn__servername(null)
if @dbs is null set @dbs=db_name()
-- check extensions
declare @replacer sysname,@obj sysname
if @sql like '%/*%[%][%]%*/%' or @sql like '%/*%[_]%[%][%]%*/%' begin -- t: sp__run 'print "/*sp_%*/"'
    print 'replacer not implemented' goto ret
end
declare @crlf nvarchar(2) set @crlf=char(13)+char(10)
-- tracer
declare @x1 int, @x2 int
declare @tsql nvarchar(512)
set @tsql=' if exists (select * from dbo.sysobjects where id = object_id(N''[dbo].[log_trace]'') '+
          'and OBJECTPROPERTY(id, N''IsUserTable'') = 1) '
-- parameters
declare @ok int set @ok=dbo.fn__ok()
declare @r int
declare @params sysname  set @params='@x1 int out,@x2 int out, @rows bigint out,@err int out, @r int out'
declare @returns sysname set @returns='@x1=@x1 out,@x2=@x2 out,@rows=@rows out,@err=@err out,@r=@r out'
-- loops
declare @svr sysname, @db sysname, @osql nvarchar(4000)
declare @n_dbs int, @n_svrs int,@i int,@n int
set @n_dbs=dbo.fn__str_count(@dbs,'|')
set @n_svrs=dbo.fn__str_count(@svrs,'|')
set @i=1
set @osql=@sql
set @rows=0 set @err=null
while (@i<=@n_svrs) begin
    set @sql=@osql
    set @svr=dbo.fn__str_at(@svrs,'|',@i)
    if @n_dbs>1 set @db=dbo.fn__str_at(@dbs,'|',@i) else set @db=@dbs
    set @i=@i+1
    if dbo.fn__servername(@svr)=@svr set @svr=''
    if @db=db_name() set @db=''
    if @svr<>'' set @svr=dbo.fn__sql_quotename(@svr)
    if @db<>'' set @db=dbo.fn__sql_quotename(@db)
    if not @replacer is null set @sql=replace(@sql,@replacer,@obj)
    if @trace=0 and @svr='' and @db<>'' set @sql='use '+@db+ ' '+@sql
    if @svr<>'' or @db<>'' begin
        if @simul=1 set @sql='begin transaction '+@sql        set @sql=@sql+' select @err=@@error,@rows=@@rowcount '
        if @simul=1 set @sql=@sql+'rollback transaction '
    end
    -- read log_trace from other db of local server
    if @trace=1 and @trace_import=1 and @db<>'' begin
        set @sql=' use '+@db+' '+@tsql+' select @x1=coalesce(max(id),0)+1 from dbo.log_trace '+@sql+
                 ' '+@tsql+' select @x2=coalesce(max(id),0)   from dbo.log_trace '
    end
    if @svr<>'' and @db<>'' set @sql='exec '+@svr+'.'+@db+'.dbo.sp_executesql N'+dbo.fn__sql_quote(@sql)+
                                     ',N'+dbo.fn__sql_quote(@params)+','+@returns
    set @x1=null set @x2=null set @r=null
    if @svr<>'' or @db<>'' begin
        declare @m_rows bigint set @m_rows=null
        declare @m_err int     set @m_err=null
        -- if @dbg>=@@nestlevel print 'begin declare @x1 int,@x2 int,@rows bigint,@err int,@r int '+@sql+' print @err print @rows end'
        if abs(@dbg)>=@@nestlevel and @n_svrs>1 select '====== query server separator for '+@svr+'.'+@db+':'+
                                       @osql+' ----------------------'
        if @print=1 or @noexec=1  print @sql
        if @noexec=0 exec sp_executesql @sql,@params,@x1=@x1 out,@x2=@x2 out,@rows=@m_rows out,@err=@m_err out,@r=@r out
        set @rows=@rows+@m_rows
        if coalesce(@err,0)=0 set @err=@m_err
    end
    else begin
        if @print=1 or @noexec=1 print @sql
        if @noexec=0 exec(@sql)
        select @err=@@error,@rows=@rows+@@rowcount
    end

    declare @trc_id int
    if @trace=1 exec sp__trace @sql,@last_id=@trc_id out, @proc=@trace_proc,@dbg=@dbg

    -- manage and trace error
    set @err_msg=''
    if @err<>0 and @noexec=0 begin
        /* n.b.: in some situation this sp cause another error (maybe into stack) and leave
           without manage the error
        -- this will solve the above problem but for now don't work
        create table #dbccout (id int identity,col1 nchar(77))
        insert into #dbccout exec ('dbcc outputbuffer(@@spid)')
        select @i=min(id),@n=max(id) from #dbccout
        while (@i<=@n) begin
            select @err_msg = @err_msg + substring(col1, 62 + 1, 1) +
                                         substring(col1, 62 + 3, 1) +
                                         substring(col1, 62 + 5, 1) +
                                         substring(col1, 62 + 7, 1) +
                                         substring(col1, 62 + 9, 1) +
                                         substring(col1, 62 + 11, 1) +
                                         substring(col1, 62 + 13, 1) +
                                         substring(col1, 62 + 15, 1)
            from #dbccout where id=@i and left(col1, 8) <> replicate('0', 8)
            order  by col1
            set @i=@i+1
            end -- while
        drop table #dbccout
        -- exec sp__outputbuffer @err_msg out
        */
        if @svr is null begin -- if sql on server
            declare @lcid smallint
            select @lcid=lcid from master..syslanguages where langid=@@langid
            declare @msgerr sysname
            select @msgerr=description from master..sysmessages where error=@err and msglangid=@lcid
            if difference(@err_msg,@msgerr)<3 set @err_msg=@msgerr
        end
        if @svr is null
            set @err_msg=dbo.fn__printf('#!(%d):%s',@err,@err_msg,null,null,null,null,null,null,null,null)
        else
            set @err_msg=dbo.fn__printf('#!(%d) on %s:%s',@err,@svr,@err_msg,null,null,null,null,null,null,null)
        -- select top 1 @msg=description from master.dbo.sysmessages where error=@err
        if left(ltrim(@sql),7) in ('select ','insert ','delete ','update ','execute','exec @r','execute')
            set @sql=dbo.fn__str_simplify(@sql,default)
        set @err_msg=@err_msg+' ('+left(@sql,4000-len(@err_msg))+')'
        if @trace=1 exec sp__trace @err_msg,@ref_id=@trc_id , @proc=@trace_proc else exec sp__printf @err_msg
    end -- if @err

    if (@svr<>'' or @db<>'') and @trace=1 and @trace_import=1 and not @x1 is null and not @x2 is null
    begin
        -- import remota trace log
        if @svr<>'' and @db<>'' set @sql='insert into log_trace(spid,txt,ref_id) '+
                                         'select top 100 percent * from openquery(%svr%,"'+
                                            'select spid,txt,ref_id from %db%.dbo.log_trace '+
                                            'where id between %x1% and %x2% order by id")'
        if @svr= '' and @db<>'' set @sql='insert into log_trace(spid,txt,ref_id) '+
                                         'select top 100 percent spid,txt,ref_id from %db%.dbo.log_trace '+
                                         'where id between %x1% and %x2% order by id'
        exec sp__str_replace @sql out,'"|%svr%|%db%|%x1%|%x2%','''',@svr,@db,@x1,@x2
        if @dbg>=@@nestlevel print @sql
        exec(@sql)
    end -- import remote trace
end -- while svrs
goto ret
help: exec sp__usage 'sp__run_sql'
ret:
return coalesce(@r,@err,@ok)
end -- proc