/*  leave this
    l:see LICENSE file
    g:utility
    v:130605\s.zaglio: removed printf deprecated parameters
    v:110314\s.zaglio: renamed from deprecated sp__trace; use sp__log
    v:100205\s.zaglio: deprecated fn__injectN to fn__inject and added help
    v:090603\S.Zaglio: added @elapsed and %e
    v:090131\S.Zaglio: removed replace if @p? are all null
    v:090129\S.Zaglio: added @privacy
    v:090128\S.Zaglio: forced on @print to match correclty when error and replaced | with , in params
    v:090121\S.Zaglio: added outbuffer trace when @txt='sp__outbuffer'
    v:090117\S.Zaglio: added @force to sp_prinftf
    v:081223\S.Zaglio: added multilevel @dbg
    v:081215\S.Zaglio: a bug when print. Date style to 126
    v:081203\S.Zaglio: added @print, removed @trace from sp__printf
    v:081129\S.Zaglio: set erf_id as relative to simplify export to other server
    v:081120\S.Zaglio: added @last_id and @ref_id and @proc. Old compatible and auto add new log_trace col
    v:081030\S.Zaglio: convert in nvarchar (be careful with 4000 chars and ' inside)
    v:081014\S.Zaglio: added %t as replacer for iso date
    v:080925\S.Zaglio: added privacy
    v:080922\S.Zaglio: added @txt as numeric of @@error, replaced with sysmessages
    v:080918\S.Zaglio: added @trace_once out to simplify loop tracing (run only once)
    v:080628\S.Zaglio: fast log for debugging
    t:
        begin
        declare @txt nvarchar(4000) set @txt='12345'+space(3800)+' after 3800 spaces:67890'+space(85)+'abcdefghi'
        exec sp__trace 'first run fs',@init=1
        exec sp__trace @txt,@proc='sp_hello'
        exec sp__trace 'add %s','element'
        exec sp__trace 'added %d',12
        -- test long comments
        select dbo.fn__str_simplify(txt,default) as txt from log_trace where len(txt)>1000
        exec sp__trace -- print
        exec sp__trace 'second run fs',@init=1
        exec sp__trace 'add %s','element'
        exec sp__trace 'added ''%d''',12
        exec sp__trace -- print
        exec sp__trace @clean=1
        -- printf test/debugging
        exec sp__trace 'printf test',@init=1
        exec sp__trace 'im here',@print=1
        exec sp__trace -- print
        exec sp__trace @clean=1
        select dbo.fn__str_simplify(txt,default) as txt from log_trace where len(txt)>1000

        end
    t: sp__trace 'select x from opendatasource(datas,uid,password=xyz) where ...' select * from log_trace where id=(select max(id) from log_trace)
    t: -- test @ref_id,@last_id,@proc features
        begin
        truncate table log_trace
        declare @ref_id int
        exec sp__trace 'test for old compatibuility',@clean=1
        exec sp__trace 'parent',@last_id=@ref_id out
        exec sp__trace 'child1',@ref_id=@ref_id
        exec sp__trace 'child2',@ref_id=@ref_id
        exec sp__trace 'this is a new feature',@proc='mySP'
        exec sp__trace
        exec sp__trace @clean=1
        end
*/
CREATE proc [dbo].[sp__log_trace]
    @txt nvarchar(4000)=null,
    @p1 sql_variant=null,
    @p2 sql_variant=null,
    @p3 sql_variant=null,
    @p4 sql_variant=null,
    @p5 sql_variant=null,
    @p6 sql_variant=null,
    @p7 sql_variant=null,
    @p8 sql_variant=null,
    @init bit=0,
    @clean bit=0,
    @trace bit=1,                  -- spare to write on each call: if @trace=1 exec sp__trace ...
    @trace_once bit=1 out,         -- spare to write on each call: if @trace=1 exec sp__trace ...
    @last_id int=null out,         -- return last @@identity
    @ref_id int=null,
    @proc sysname=null,            -- short cut to %t|@proc|@txt format
    @print bit=0,
    @privacy bit=0,
    @elapsed datetime=null out,
    @dbg smallint=0
as
begin
declare @now datetime
declare @ms int
if not @elapsed is null
    begin
    set @now=getdate()
    set @ms=datediff(ms,@elapsed,@now)
    set @txt=replace(@txt,'%e',convert(nvarchar(48),@ms))
    set @elapsed=@now
    end

declare @sql nvarchar(4000)
declare @sql1 nvarchar(4000)
if @txt='sp__outbuffer' begin set @txt='' exec sp__outputbuffer @txt out end

if @dbg<0 begin exec sp__printf '@@nestlevel=%d',@@nestlevel end
set nocount on

if isnumeric(@txt)=1 begin
    if exists(select top 1 error from master.dbo.sysmessages where error=convert(int,@txt))
        select top 1 @txt=description from master.dbo.sysmessages where error=convert(int,@txt)
end
if @init=1 or @clean=1
    begin
    if dbo.fn__exists('log_trace','U')=0
        begin
        set @sql='create table log_trace (id int identity, ref_id int, spid int, txt nvarchar(4000))'
        exec sp__printf '-- log_trace created'
        exec(@sql)
        end -- create
    else
        begin
        if @proc is null set @sql='delete from log_trace where spid='+convert(nvarchar(32),@@spid)
        else set @sql='delete from log_trace where dbo.fn__str_at(txt,''|'',2)='+@proc
        exec(@sql)
        end
    if @txt is null goto ret
    end -- @init=1

if @txt is null and @clean=0 goto help

if not @proc is null set @txt='%t|'+@proc+'|'+left(@txt,4000-20-len(@proc))
set @txt=replace(@txt,'%t',convert(nvarchar(48),getdate(),126))
if not @p1 is null or not @p2 is null or not @p3 is null or not @p4 is null or
   not @p5 is null or not @p6 is null or not @p7 is null or not @p8 is null
    begin
    set @p1=replace(convert(nvarchar(4000),@p1),'|',',') set @p2=replace(convert(nvarchar(4000),@p2),'|',',')
    set @p3=replace(convert(nvarchar(4000),@p3),'|',',') set @p4=replace(convert(nvarchar(4000),@p4),'|',',')
    set @p5=replace(convert(nvarchar(4000),@p5),'|',',') set @p6=replace(convert(nvarchar(4000),@p6),'|',',')
    set @p7=replace(convert(nvarchar(4000),@p7),'|',',') set @p8=replace(convert(nvarchar(4000),@p8),'|',',')
    set @txt=dbo.fn__printf(@txt,@p1,@p2,@p3,@p4,@p5,@p6,@p7,@p8,null,null)
    end
if left(ltrim(@txt),7) in ('select ','insert ','delete ','update ','execute','exec @r') set @txt=dbo.fn__str_simplify(@txt,default)
if @privacy=1 begin
    if @txt like '%OPENDATASOURCE%(%password%)%' begin -- kepp privacy
        declare @i int,@j int
        set @i=charindex('opendatasource',@txt)
        if @i>0 set @i=charindex('(',@txt,@i)
        set @j=charindex(')',@txt,@i)
        if @j<1 set @j=len(@txt)
        if @i>0 set @txt=substring(@txt,1,@i)+'***privacy***'+substring(@txt,@j,len(@txt))
    end
end -- privacy
if @print=1 begin
    if coalesce(@proc,'')='' set @sql=@txt
    else set @sql=dbo.fn__str_at(@txt,'|',3)
    exec sp__printf @sql
    end
if @trace=0 or @trace_once=0 goto ret
set @trace_once=0                  -- disable trace in loop (the caller must use out to enable this)
if @ref_id is null begin
    set @sql='insert into log_trace(spid,txt) values('+convert(nvarchar(32),@@spid)+','''
    set @sql1=dbo.fn__inject(@txt)
    if abs(@dbg)>=@@nestlevel exec sp__printf '%s%s'')',@sql,@sql1
    exec(@sql+@sql1+''')')
    end
else
    begin
    set @sql='insert into log_trace(ref_id,spid,txt) values('+convert(nvarchar(32),@ref_id)+'-ident_current(''log_trace''),'+convert(nvarchar(32),@@spid)+','''
    set @sql1=dbo.fn__inject(@txt)
    if abs(@dbg)>=@@nestlevel exec sp__printf '%s%s'')',@sql,@sql1
    exec(@sql+@sql1+''')')
    if @@error<>0 begin
        exec('alter table log_trace add ref_id int')
        exec(@sql+@sql1+''')')
        end
    end
set @last_id=ident_current('log_trace') -- @@identity
goto ret

help:
select @sql ='\nparameters:\n'
            +'\t@init\t\t1 create log_trace\n'
            +'\nsamples:\n'
            +'\tsp__trace ''test'''
exec sp__usage 'sp__trace',@sql

ret:
end -- [sp__log_trace]