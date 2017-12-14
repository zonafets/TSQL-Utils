/*  leave this
    l:see LICENSE file
    g:utility
    v:131107.1200\s.zaglio: removed list of objs when one found and about sys... objs
    v:131001,130906\s.zaglio: added shortcut info
    v:110926\s.zaglio: added sys management
    v:110916\s.zaglio: used readpast
    v:110706\s.zaglio: special behaviour on systypes
    v:110629\s.zaglio: added list of triggers
    v:110628\s.zaglio: added db trigger script
    v:110623\s.zaglio: added call of sp__style
    v:110406\s.zaglio: added script of triggers
    v:110307.1000\s.zaglio: a small bug on single sp
    v:110220\s.zaglio: added system tables
    v:110213\s.zaglio: replaced readpast with nolock
    v:110102\s.zaglio: added obj info
    v:110121\s.zaglio: added nolock
    v:101107\s.zaglio: added show of structure of temp tables
    v:100919\s.zaglio: added show of ##var## and #var#
    v:100616\s.zaglio: removed help after attached
    v:100529\s.zaglio: added use of #dbg
    v:100528\s.zaglio: a bug near local srv, other db obj position
    v:100518\s.zaglio: added temp vars to not disturbe scope of caller
    v:100423\s.zaglio: manage #tbls
    v:100422\s.zaglio: a minor enh
    v:100418\s.zaglio: added synonym management
    v:100228\s.zaglio: help developers;set this into tools\options menuù and connecto to CTRL+F1
    t:sp__info #test1_2#3   -- good
    t:sp__info 'sysobjects'
    t:fn__str, sp__emails, tr__script_trace_db
    t:sp__info 'sp__info'
    t:sp__info 'sp__server_ip'
*/
CREATE proc [sp__info] @what sysname=null
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0
declare @dbg bit select @dbg=0
declare @crlf nvarchar(2)

select @crlf=crlf from dbo.fn__sym()
-- cerate local temps
create table #src(lno int identity, line nvarchar(4000))
create table #vars (id nvarchar(16),value sql_variant)

if not object_id('tempdb..#dbg') is null
    begin
    if @what is null
        begin
        exec('#dbg')
        goto ret
        end
    exec sp_executesql N'exec @ret=#dbg @what',
                       N'@ret int out,@what sysname',
                       @ret=@ret out,@what=@what
    if @dbg=-1 exec sp__printf '#dbg:%d',@ret
    if @ret!=0 goto ret
    end

if not object_id('sp_info') is null
    begin
    if @what is null begin exec('sp_info') goto ret end
    exec @ret=sp_executesql
                N'@ret=sp_info @what',
                N'int @ret out,@what sysname',
                @ret=@ret out,@what=@what
    if @dbg=-11 exec sp__printf 'sp_info:%d',@ret
    if @ret!=0 goto ret
    end

if @what is null goto help

if @dbg=1 exec sp__printf '--- analyze'

declare
    @obj sysname,@type sysname,@objs nvarchar(4000),
    @n int,@i int,@sql nvarchar(4000),@id int,
    @svr sysname,@db sysname,@sch sysname,@sobj sysname,
    @synonym bit,@ok bit

select @ok=0

if left(@what,1)='#'
and dbo.fn__str_count(@what,'#')>=3
and right(@what,1)!='#'
    begin
    select @what=substring(replace(@what,'_',' '),2,4000)
    exec sp__style @what
    goto ret
    end

if left(@what,2)='##' and right(@what,2)='##'
    begin
    if @dbg=1 exec sp__printf '--- ##cfg'
    -- ##smtp_server##
    select @sql=N'sp__config '''+substring(@what,3,len(@what)-4)+''''
    exec(@sql)
    end
else
    begin
    if left(@what,1)='#' and right(@what,1)='#'
        begin
        if @dbg=1 exec sp__printf '--- #cfg'
        select @sql=N'sp_config '''+substring(@what,2,len(@what)-2)+''''
        exec(@sql)
        end
    end

select @id=object_id(@what)
if @id is null and dbo.fn__ismssql2k()=0
    select @id=object_id,@type=[type]
    from sys.triggers
    where [name]=@what
if @dbg=1 exec sp__printf '@id=%d',@id
if @id is null and left(@what,1)='#' and right(@what,1)!='#'
    begin
    if @dbg=1 exec sp__printf '--- direct id'

    select @id=object_id('tempdb..'+@what),@type='u' -- could be a #proc: todo
    select fld,def into #tmptbldef
    from fn__sql_def_cols(@what,default,default)
    exec sp__select_astext
        'select fld,def from #tmptbldef with (nolock)',
        @header=1
    drop table #tmptbldef
    end

select @objs=coalesce(@objs+'|','')+[name]+'('+xtype+')',@type=xtype
from sysobjects with (nolock)
where [name] like replace(@what,'_','[_]')+'%'
if dbo.fn__ismssql2k()=0
    select @objs=coalesce(@objs+'|','')+[name]+'('+[type]+')',@type=[type]
    from sys.triggers with (nolock)
    where [name] like replace(@what,'_','[_]')+'%'
    and parent_id=0

-- sp__info sp_
select @n=dbo.fn__str_count(@objs,'|')
if @n>1 and @id is null
    begin
    if @dbg=1 exec sp__printf '--- multi find'
    select @n=max(len(token))+1 from dbo.fn__str_table(@objs,'|')
    select @sql=null
    declare @ll int select @ll=(132/@n*@n)+2
    -- select * from dbo.fn__str_table('a,b,c',',')
    select @sql =coalesce(@sql,'')+left(token+replicate(' ',@n),@n)
                +case when pos%(132/@n)=0 then @crlf else '  ' end
    from dbo.fn__str_table(@objs,'|')
    print @sql
    print '-------------------------------------------------------------------------'
    -- exec sp__printf '%s',@sql
    end

if not @id is null or @what like 'sys[0-9]%'
    begin
    if @dbg=1 exec sp__printf 'type is %s',@type
    if @type='sn'
        begin
        select @synonym=1
        select -- lower(sy.type_desc),sc.name + '.' + sy.name as synonym_name,sy.base_object_name,
            @sql=sy.base_object_name,
            @svr=parsename(sy.base_object_name,4),
            @db=parsename(sy.base_object_name,3),
            @sch=parsename(sy.base_object_name,2),
            @sobj=parsename(sy.base_object_name,1)
        from sys.synonyms sy with (nolock)
        join sys.schemas  sc with (nolock) on sc.schema_id = sy.schema_id
        where sy.[object_id] = @id

        exec sp__printf '-- synonym: -> %s.%s.%s.%s',@svr,@db,@sch,@sobj

        if @dbg=1 exec sp__printf '%s sv:%s db:%s sc:%s ob:%s',@sql,@svr,@db,@sch,@sobj
        select @sql='use [%db%] select @type=xtype from sysobjects with (nolock) where id=object_id(''[%sch%].[%obj%]'')'
        exec sp__str_replace @sql out,'%svr%|%db%|%sch%|%obj%',@svr,@db,@sch,@sobj
        select @sql=replace(@sql,'''','''''')
        if @svr is null
            select
                @sql='exec [%db%]..sp_executesql N'''+@sql+''',N''@type sysname out'',@type=@type out',
                @what=quotename(@db)+'.'+quotename(@sch)+'.'+quotename(@sobj)
        else
            select
                @sql='exec [%svr%].[%db%]..sp_executesql N'''+@sql+''',N''@type sysname out'',@type=@type out',
                @what=quotename(@svr)+'.'+quotename(@db)+'.'+quotename(@sch)+'.'+quotename(@sobj)

        exec sp__str_replace @sql out,'%svr%|%db%|%sch%|%obj%',@svr,@db,@sch,@sobj
        select @type=null
        exec sp_executesql @sql,N'@type sysname out',@type=@type out
        if @dbg=1 exec sp__printf '@sql:%s @type:%s @what:%s',@sql,@type,@what
        end

    -- fn_mc_and_wh
    if @what like 'sys[^0-9]%'
    and not @what in ('systypes','sysobjects','syscolumns','syscomments')
        select @what='master..'+@what
    if @what like 'sys%'
        select @sql='select * from '+@what+' with (nolock)'
    else
        select @sql='select top 10 * from '+@what+' with (nolock)'

        /* in the 110922, readpast caused in production the msg:
            Messaggio 650, livello 16, stato 1, riga 1
            You can only specify the READPAST lock in the READ COMMITTED or REPEATABLE READ isolation levels.
        */
    -- select xtype from sysobjects group by xtype
    if @type in ('p','fn','if','tf','tr')
        begin
        if @dbg=1 exec sp__printf '--script'
        exec sp__script @what,@opt='print'
        select @ok=1
        end
    if (@type in ('v','u') and @id is null) or (@type is null and not @id is null)
        begin
        if @dbg=1 exec sp__printf '-- show as text:\n%s',@sql
        exec sp__select_astext @sql
        select @ok=1
        end
    if @type in ('v','u') and not @id is null
        begin
        if @dbg=1 exec sp__printf '-- show data:\n%s',@sql
        exec(@sql)
        select @sql=quotename(@svr)+'.'+quotename(@db)+'.dbo.sp__script '''+@sobj+''',@opt=''reverse|print'''
        if @dbg=1 exec sp__printf '%s',@sql
        if @synonym=1 exec(@sql)
        if @dbg=1 exec sp__printf '-- script'
        else exec sp__script @what,@opt='print'            -- table or view
        select @ok=1
        end
    if @type is null and not @sql is null exec(@sql)
    end

else -- not @id is null

    begin
    if @dbg=1 exec sp__printf '--- single wild found'
    if @objs is null -- try search with one char less
        select @objs=coalesce(@objs+'|','')+[name]+'('+xtype+')',@type=xtype
        from sysobjects with (nolock)
        where [name] like replace(left(@what,len(@what)-1),'_','[_]')+'%'

    exec sp__printf '%s',@objs
    goto ret
    end

    if @ok=1 goto ret

help:
exec sp__usage @proc,'
Scope
    Help developers printing some info

Notes
    I normally do this associations:
        ctrl+F1: sp__info
        ctrl+3:  connection info (see below)
        ctrl+4:  sp__dir @opt=''*'',@path=
        ctrl+5:  (free)
        ctrl+6:  sp__find
        ctrl+7:  declare @db sysname;select @db=db_name();exec sp_script @db=@db,@obj=
        ctrl+8:  sp__style
        ctrl+9:  sp__script_debug
        ctrl+0:  (free)

    Connection info (to put into single line before paste as shortcut):
        select
            @@servername svr,db_name() db,cn.connect_time,cn.client_net_address,cn.local_net_address
        from sys.dm_exec_connections cn
        where session_id=@@spid

    If exist into current db an SP_INFO, first are called this.
    If this return something !=0, stop execution otherwise continue showing info.

    Infos depends from parameter type:
    1. proc/function/trigger       show source
    2. view/table                  select first 10 records
    3. root of object              if find one, reapply 1 & 2
    3.1                            if find more, print list
    4. not 1,2,3                   use sp__find @what
    5. #...                        introduce a command
    5.1 #svn#sp__info#s_zaglio     call sp__svn... replace _ with . (TODO)
    5.2 ##var##                    call sp__config ''var''
    5.3 #var#                      call SP_CONFIG ''var''
'
exec sp__printf 'Parameter:%s (!!!! keep in mind "__")',@what
select @ret=-1
goto ret

ret:
drop table #src
drop table #vars
return @ret
end -- sp__info