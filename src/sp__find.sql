/*  leave this
    l:see LICENSE file
    g:utility
    v:140122\s.zaglio: commented search into tags
    r:130925\s.zaglio: used try-catch to ensure search continuity
    v:130612\s.zaglio: adapted to new fn__sym
    v:121025\s.zaglio: added option distinct
    v:120827\s.zaglio: added autoscale to %word% if nothing is found
    v:120726.1600\s.zaglio: help,svn context and added func/sub name in list
    v:120614.1715\s.zaglio: exclude "-" from symbols and managed [word]
    v:120601\s.zaglio: a bug in search of exact col
    v:120229\s.zaglio: extended correctly search to obj & cols name
    v:120208\s.zaglio: inverted logic and option NOSVN to SVN
    v:120207\s.zaglio: again a small bug near existance of db utility
    v:120203\s.zaglio: added #sp__find_out and removed a small bug
    v:120127\s.zaglio: done
    r:120125\s.zaglio: working
    r:120123\s.zaglio: adding svn management
    v:120116\s.zaglio: added @range and restyled
    v:111216\s.zaglio: added "s" as separator symbol
    v:111116\s.zaglio: about help
    v:111031\s.zaglio: removed @dbs, added opt "script" and improved generic search
    v:111011\s.zaglio: added () as symbols
    v:111003\s.zaglio: added tags search and correct a bug near @m2=@m3
    v:110920\s.zaglio: added tab symbol
    v:110914\s.zaglio: added symbols : and \, @obj and @xtype
    v:110713\s.zaglio: a bug near code search
    v:110712\s.zaglio: added sep. symbols .#10#13#32
    v:110623\s.zaglio: added table name near columns
    v:110331\s.zaglio: optimized
    v:110530\s.zaglio: remake
    t:sp__find 'sp__find',@dbg=1
    t:sp__find 'sp__job_status'
    t:sp__find 'PDA_DISABLE_MULTI_LABELLING',@opt='txt'
    t:sp__find '[utility]',@dbg=2
    t:sp__find '%[utility]',@dbg=2
*/
CREATE PROC sp__find
    @what  sysname = null,
    @obj   sysname = null,
    @xtype sysname = null,
    @range int     = null,
    @opt   sysname = null,
    @dbg   int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|'),
    @obj=dbo.fn__str_quote(@obj,'%')
-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
declare
    @m1 sysname,@m2 sysname,@m3 sysname,@m4 sysname,
    @left sysname,@right sysname,@db sysname,@sym sysname,
    @sql nvarchar(4000),@params nvarchar(4000),
    @dbs sysname,@tags bit,@rows int,@typ sysname,
    @cmd nvarchar(1024),@url nvarchar(1024),@tmp nvarchar(4000),
    @file sysname,@d datetime,@n bigint,
    @id int,@rid int,@rev sysname,
    @crlf nvarchar(4),@cr nvarchar(2),@lf nvarchar(2),@tab nvarchar(2),
    @target nvarchar(1024),@path nvarchar(1024),
    @svn_export nvarchar(1024),@svn_dir nvarchar(1024),
    @svn_list nvarchar(1024), @svn_del_target nvarchar(1024),
    @svn_diff nvarchar(1024),@i int,@emsg nvarchar(2048),
    @svn bit                -- nosvn option


declare @stdout table (lno int identity primary key, line nvarchar(4000))
declare @files table (id int null,rev int,name nvarchar(1024))
declare @paths table (name nvarchar(1024))

create table #sql(id int identity,typ sysname,sql nvarchar(4000))
create table #src(lno int identity,line nvarchar(4000))
create table #dbs(db sysname)
create table #sysobjects(id int,[name] sysname,xtype nvarchar(4))

if object_id('tempdb..#tmp_found') is null
    create table #tmp_found(
        db sysname null,
        id sql_variant null, number int null, colid int null,
        p1 int null,p2 int null,p3 int null,
        obj sysname null,
        xtype sysname null,
        [txt1_or_obj] sysname null,
        [txt2_or_type] sysname null,
        txt3 sysname null
        )

-- =========================================================== initialization ==

select
    @cr=cr,@lf=lf,@tab=tab,@crlf=crlf,
    @sym=bounds,
    @cmd='svn',
    @target='%temp%\'+replace(cast(newid() as sysname),'-','_')+'.txt'
from fn__sym()

if charindex('|dbs|',@opt)>0
    begin
    select @dbs='%'
    insert into #dbs(db)
    select [name]
    from master..sysdatabases
    where [name] like @dbs
    end
else
    insert #dbs(db) select db_name()

-- NB: escape not exists for patindex so I replace ] with ¬
select
    @what=  case
            when left(@what,1)='[' and right(@what,1)=']'
            then replace(replace(@what,']','¬'),'[','[[]')
            else @what
            end,
            -- dbo.fn__str_unquote(@what,'[]'),
    @tags=  charindex('|tags|',@opt),
    @range= case
            when @range is null
            then
                case
                when len(@what)+1>20
                then len(@what)+1
                else 20
                end
            else @range
            end,
    @left=  case
            when left(@what,1) like '[0-9a-Z]'
              or left(@what,1) = '['
            then '%[ ['+@sym+']'
            else '%'
            end,
    @right= case
            when right(@what,1) like '[0-9a-Z]'
              or right(@what,1) = '['
            then '[ ['+@sym+']%'
            else '%'
            end

select
    @m1=@left+@what+@right, -- single word
    @m2=@what+@right,
    @m3=@left+@what,
    @params='@what sysname,@m1 sysname,@m2 sysname,@m3 sysname,'
           +'@range int,@db sysname,@xtype sysname,@obj sysname,'
           +'@err int out,@rows int out,@dbg int'

-- ======================================================== second params chk ==
if @what is null goto help

-- ===================================================================== body ==

if @dbg>0 exec sp__printf 'declare
    @what sysname,@xtype sysname,@m1 sysname,@m2 sysname,@m3 sysname,
    @db sysname,@obj sysname

select
    @what=  ''%s'',
    @m1=    ''%s'',
    @m2=    ''%s'',
    @m3=    ''%s''
    ',@what,@m1,@m2,@m3

-- ##########################
-- ##
-- ## svn
-- ##
-- ########################################################

if charindex('|svn|',@opt)>0
or left(@what,4)='svn:'
    select @svn=1
else
    select @svn=0

-- svn file caching uses only one common table on utility db
if @svn=1
and exists(
    select null
    from master..sysdatabases
    where name='utility'
    )
    begin

    if object_id('utility..fnd') is null
        begin
        -- drop table fnd
        exec('
        create table utility..fnd(
            tid tinyint not null,   -- filename or text line
            id int identity constraint pk_fnd primary key,
            rid int not null,
            pid int not null,
            idx int not null,       -- file row number
            [key] int,              -- revision
            val nvarchar(4000)      -- name
            )
        create index ix_fnd on fnd(tid,rid,id)
        ')
        end -- fnd creation

    if db_name()!='utility' and object_id('fnd') is null
        exec('create view fnd as select * from utility..fnd')

    end -- creation of table or alias
else
    goto search

if object_id('fnd') is null
    begin
    select @svn=0
    goto search
    end

-- list or load new path, or refresh path
if left(@what,4)='svn:'
    insert @paths select @what
else
    -- refresh previous cached paths
    insert @paths
    select val from fnd,tids where fnd.tid=tids.url

-- for each new path or previous path
declare cs cursor local for
    select name
    from @paths
open cs
while 1=1
    begin
    fetch next from cs into @path
    if @@fetch_status!=0 break

    select
        @url=protocol+'://'+host+path,
        @file=page,
        @svn_export=@cmd+' export "'+@url+'%file%" '+@target+' -r HEAD',
        @svn_dir=@cmd+' ls -r HEAD '+@url,
        @svn_list=@cmd+' ls -r HEAD -R -v '+@url, -- username X --password Y
        @svn_diff=@cmd+' diff -r '+@rev+':HEAD --summarize '+@url,
        @svn_del_target='del '+@target
    from fn__parseurl(@path,default)

    if @dbg=1
        begin
        exec sp__printf 'svn_dir:%s',@svn_dir
        exec sp__printf 'target:%s',@target
        end -- dbg

    -- sp__find 'svn://svr/SOURCES',@dbg=1
    if isnull(@file,'')=''
        begin
        exec master..xp_cmdshell @svn_dir
        continue
        end

    -- list and import files
    -- select * from fnd -- drop table fnd
    -- sp__find 'svn://svr/SOURCES/prg/trunk/*.vb',@dbg=1

    select @rid=null,@d=null

    select
        @rid=id,
        @d=cast(cast(nullif([key],0) as binary(4)) as smalldatetime) /* ...
           ... contain last ins/update time */
    from fnd,tids
    where fnd.tid=tids.url
    and val=@path

    if @rid is null
        begin
        if charindex('|clean|',@opt)>0
            begin
            exec sp__printf '-- nothing to clean'
            continue
            end -- clean

        -- list all files
        select @d=getdate()
                -- store path and time to not overlap multiple imports
        insert fnd(
            tid,rid,pid,idx,
            [key],val
            )
        select top 1
            tids.url,0 as rid,0 as pid,0 as idx,
            cast(cast(@d as smalldatetime) as binary(4)),       -- lock import
            @what
        from tids
        select @rid=@@identity

        exec sp__printf '-- populating new path on id %d',@rid

        insert @stdout exec master..xp_cmdshell @svn_list

        select top 1 @tmp=line
        from @stdout
        where line like 'svn:%'
        order by lno

        -- if there is an error, unlock (deleting) the id
        if @@rowcount>0
            begin
            delete from fnd where id=@rid
            goto err_svn
            end

        select @n=count(*) from @stdout where line like replace(@file,'*','%')
        exec sp__elapsed @d out,'-- after get list to download %d files',@v1=@n
        if @n=0 goto ret

        -- extract columns and filtered files
        insert @files(rev,name)
        select left(line,7) rev,substring(line,44,512) [file]
        from @stdout
        where not line is null
        and line like replace(@file,'*','%')

        end -- populate files
    else
        begin
        -- sp__find 'svn://svr/SOURCES/prg/trunk/*.vb',@dbg=1

        if not @d is null               -- if locked
            begin

            if left(@what,4)!='svn:'
                begin
                -- skip msg if are searching
                select @d=null -- do not show svn times
                continue
                end

            if charindex('|unlock|',@opt)>0
                begin
                exec sp__printf '-- unlocked'
                update fnd set [key]=0 where id=@rid
                select @d=null  -- this skipp next if and not show svn times
                end

            if datediff(hh,@d,getdate())>1
                begin
                exec sp__elapsed @d,'-- automatic unlock of importing "%s"(id:%d) from',
                                 @v1=@path,@v2=@rid
                update fnd set [key]=0 where id=@rid
                end
            else
                begin
                exec sp__elapsed @d,'-- already importing "%s"(id:%d) from',
                                 @v1=@path,@v2=@rid
                select @d=null -- do not show svn times
                continue
                end
            end

        select @d=getdate()
        if charindex('|clean|',@opt)>0
            begin
            delete from fnd where pid=@rid
            select @n=@@rowcount
            exec sp__elapsed @d,'-- cleaned %d rows in',@v1=@n
            select @d=null -- do not show svn times
            continue
            end -- clean

        update fnd set
            [key]=cast(cast(@d as smalldatetime) as binary(4)) -- lock update
        where id=@rid

        -- search for last
        select @rev=max([key])
        from fnd,tids
        where fnd.tid=tids.obj and rid=@rid

        if left(@what,4)='svn:'
            exec sp__printf '-- get updated files from revision %s for path %s',
                            @rev,@path

        insert @stdout exec master..xp_cmdshell @svn_diff

        if exists(
            select top 1 null
            from @stdout
            where line like 'svn:%'
            order by lno
            )
            begin
            continue -- revision not found
            update fnd set [key]=0 where id=@rid
            end

        delete from @stdout

        -- list all files
        insert @stdout exec master..xp_cmdshell @svn_list

        -- extract columns
        insert @files(rev,name)
        select left(line,7) rev,substring(line,44,512) [file]
        from @stdout
        where not line is null
        and line like replace(@file,'*','%')

        -- unlist files of same revision
        delete f
        from @files f
        join fnd on f.name=fnd.val
        cross join tids
        where fnd.tid=tids.obj
        and rid=@rid
        and f.rev=fnd.[key]

        -- update ref id of existing files so can be replaced
        update f set id=fnd.id
        from @files f
        join fnd on f.name=fnd.val
        cross join tids
        where fnd.tid=tids.obj
        and rid=@rid

        end -- update path

    end -- while of cursor
close cs
deallocate cs

-- download files/refresh cache
if exists(select null from @files)
    begin
    select @i=0
    declare cs cursor local for
        select id,rev,name
        from @files
    open cs
    while 1=1
        begin
        fetch next from cs into @id,@rev,@file
        if @@fetch_status!=0 break

        -- get file from svn into a generic container
        select @tmp=replace(@svn_export,'%file%',@file)
        if @dbg=1 exec sp__printf '%s',@tmp

        -- export file from svn
        delete from @stdout
        insert @stdout exec master..xp_cmdshell @tmp

        if not exists(
            select top 1 null
            from @stdout
            where line like 'A %.txt'
            order by lno
            )
            goto err_svn

        -- import generic container
        truncate table #src
        exec @ret=sp__file_read_stream @target,@out='#src'

        if @ret=0
            begin
            if not @id is null
                -- replace old version
                delete from fnd where rid=@id

            select @id=null

            insert fnd(tid,rid,pid,idx,[key],val)
            select tids.obj,@rid,@rid,0,@rev,@file
            from tids

            select @id=@@identity

            insert fnd(tid,rid,pid,idx,val)
            select tids.code,@id,@rid,src.lno,ltrim(rtrim(src.line))
            from #src src,tids
            where ltrim(rtrim(isnull(line,'')))!=''
            order by lno
            select @n=@@rowcount
            exec sp__printf '-- downloaded %d lines from file %d:%s(r:%d)',
                            @n,@i,@file,@rev
            select @i=@i+1
            end -- load ok

        end -- while of cursor
    close cs
    deallocate cs

    -- unlock import
    update fnd set [key]=0 where id=@rid

    exec master..xp_cmdshell @svn_del_target,no_output

    end -- download files

if not @d is null exec sp__elapsed @d,'-- svn elaboration in'

if left(@what,4)='svn:'  goto ret

-- ##########################
-- ##
-- ## search
-- ##
-- ########################################################

search:

-- ##########################
-- ##
-- ## tags
-- ##
-- ########################################################
/*
insert #sql select 'tags','
use [%db%]
insert #tmp_found(
    db,id,obj,xtype,[txt1_or_obj],[txt2_or_type],txt3
    )
select
    @db db,
    obj_id,
    obj,
    tag+'':'',
    convert(sysname,val1) [txt1_or_obj],
    convert(sysname,val2) [txt2_or_type],
    convert(sysname,val3) txt3
from dbo.fn__script_info(default,''gkvrt'',default) tags
join sysobjects o on o.id=tags.obj_id
where 1=1
and not (val1 is null and val2 is null and val3 is null)
and (@xtype is null or o.xtype=@xtype)
and (  isnull(convert(sysname,val1),'''') like @m1
    or isnull(convert(sysname,val1),'''') like @m2
    or isnull(convert(sysname,val1),'''') like @m3
    or isnull(convert(sysname,val1),'''') = @what

    or isnull(convert(sysname,val2),'''') like @m1
    or isnull(convert(sysname,val2),'''') like @m2
    or isnull(convert(sysname,val2),'''') like @m3
    or isnull(convert(sysname,val2),'''') = @what

    or isnull(convert(sysname,val3),'''') like @m1
    or isnull(convert(sysname,val3),'''') like @m2
    or isnull(convert(sysname,val3),'''') like @m3
    or isnull(convert(sysname,val3),'''') = @what
    )
select @rows=@@rowcount
'
*/
-- ##########################
-- ##
-- ## code
-- ##
-- ########################################################
insert #sql select 'code','
use [%db%]
-- first fast pass filter
insert into #sysobjects(id,name,xtype)
select id,name,xtype
from sysobjects o with (nolock)
where 1=1
and (@xtype is null or ltrim(rtrim(o.xtype)) like @xtype)
and (@obj is null or o.name like @obj)
select @rows=@@rowcount
if @dbg=2 exec sp__printf ''-- found %d sysobjs'',@rows

-- second fast pass filter
declare @owhat sysname
select @owhat=replace(@what,''¬'','']'')
select c.id,number,colid,[text]
into #syscomments
from syscomments c with (nolock)
join #sysobjects o on o.id=c.id
where [text] like ''%''+@owhat+''%''
select @rows=@@rowcount
if @dbg=2 exec sp__printf ''-- found %d syscomments'',@rows

-- search into source
insert #tmp_found(db,id,number,colid,p1,p2,p3)
select
    @db,id,number,colid,
    patindex(@m1,replace([text],'']'',''¬'')) p1,
    patindex(@m2,replace([text],'']'',''¬'')) p2,
    patindex(@m3,replace([text],'']'',''¬'')) p3
from #syscomments
where patindex(@m1,replace([text],'']'',''¬''))>0
or patindex(@m2,replace([text],'']'',''¬''))>0
or patindex(@m3,replace([text],'']'',''¬''))>0

-- if nothing found, autoscale to %word%
if @@rowcount=0
    insert #tmp_found(db,id,number,colid,p1,p2,p3)
    select
        @db,id,number,colid,
        patindex(''%''+@owhat+''%'',[text]) p1,
        0 p2,
        0 p3
    from syscomments c with (nolock)
    where [text] like ''%''+@owhat+''%''

update #tmp_found set
    obj=o.name,
    xtype=o.xtype,
    [txt1_or_obj]=
        case when p1>0
        then substring(c.[text],p1-@range,p1+@range-p1+@range)
        else ''''
        end,
    [txt2_or_type]=
        case when p2>0
        then substring(c.[text],p2-@range,p2+@range-p2+@range)
        else ''''
        end,
    txt3=
        case when p3>0
        then substring(c.[text],p3-@range,p3+@range-p3+@range)
        else ''''
        end
from #tmp_found t
join #sysobjects o with (nolock) on t.id=o.id
join #syscomments c with (nolock) on c.id=t.id and c.number=t.number and c.colid=t.colid
select @rows=@@rowcount
'

-- ##########################
-- ##
-- ## objects
-- ##
-- ########################################################
insert #sql select 'objs','
use [%db%]
-- search into objects
insert #tmp_found(db,id,obj,xtype)
select @db,id,[name],xtype
from #sysobjects o with (nolock)
where patindex(@m1,replace(o.name,'']'',''¬''))>0
or patindex(@m2,replace(o.name,'']'',''¬''))>0
or patindex(@m3,replace(o.name,'']'',''¬''))>0
or o.name=@what
select @rows=@@rowcount
'

-- ##########################
-- ##
-- ## columns
-- ##
-- ########################################################
insert #sql select 'cols','
use [%db%]
insert #tmp_found(
    db,id,obj,xtype,[txt1_or_obj],[txt2_or_type]
    )
select @db,c.id,c.[name],t.name,o.name,o.xtype
from syscolumns c with (nolock)
join systypes t on c.xusertype=t.xusertype
left join sysobjects o with (nolock) on c.id=o.id
where patindex(@m1,replace(c.name,'']'',''¬''))>0
or patindex(@m2,replace(c.name,'']'',''¬''))>0
or patindex(@m3,replace(c.name,'']'',''¬''))>0
or @what=c.name
select @rows=@@rowcount
'

-- ##########################
-- ##
-- ## job steps
-- ##
-- ########################################################
insert #sql select 'jsteps','
use [%db%]
insert #tmp_found(
    db,id,colid,obj,xtype,[txt1_or_obj],p1,p2,p3
    )
select
    @db,j.job_id,s.step_id,
    j.name,
    ''job.step'',
    left(s.step_name,128),
    patindex(@m1,replace(s.step_name,'']'',''¬'')),
    patindex(@m2,replace(s.step_name,'']'',''¬'')),
    patindex(@m3,replace(s.step_name,'']'',''¬''))
from msdb..sysjobsteps s with (nolock)
join msdb..sysjobs j with (nolock)
on s.job_id=j.job_id
where database_name=@db
and (
       patindex(@m1,replace(s.step_name,'']'',''¬''))>0
    or patindex(@m2,replace(s.step_name,'']'',''¬''))>0
    or patindex(@m3,replace(s.step_name,'']'',''¬''))>0
    )
select @rows=@@rowcount
'

-- ##########################
-- ##
-- ## job commands
-- ##
-- ########################################################
insert #sql select 'jcmds','
use [%db%]
-- search into jobs command
insert #tmp_found(
    db,id,colid,obj,xtype,[txt1_or_obj],p1,p2,p3
    )
select
    @db as db,j.job_id as id,s.step_id as colid,
    left(j.name+''.''+s.step_name,128) as obj,
    ''job.step.cmd'' as xtype,
    left(s.command,128) as [txt1_or_obj],
    patindex(@m1,replace(s.command,'']'',''¬'')) as p1,
    patindex(@m2,replace(s.command,'']'',''¬'')) as p2,
    patindex(@m3,replace(s.command,'']'',''¬'')) as p3
from msdb..sysjobsteps s with (nolock)
join msdb..sysjobs j with (nolock)
on s.job_id=j.job_id
where database_name=@db
and (
       patindex(@m1,replace(s.command,'']'',''¬''))>0
    or patindex(@m2,replace(s.command,'']'',''¬''))>0
    or patindex(@m3,replace(s.command,'']'',''¬''))>0
    )

update #tmp_found set
    [txt1_or_obj]=
        case when p1>0
        then substring(s.command,p1-@range,p1+@range-p1+@range)
        else ''''
        end,
    [txt2_or_type]=
        case when p2>0
        then substring(s.command,p2-@range,p2+@range-p2+@range)
        else ''''
        end,
    txt3=
        case when p3>0
        then substring(s.command,p3-@range,p3+@range-p3+@range)
        else ''''
        end
from #tmp_found t
join msdb..sysjobsteps s with (nolock) on t.id=s.job_id and t.colid=s.step_id
where t.xtype=''job.step.cmd''
select @rows=@@rowcount
'

-- ##########################
-- ##
-- ## jobs name
-- ##
-- ########################################################
insert #sql select 'jobs','
insert #tmp_found(id,obj,xtype)
select
    j.job_id,
    j.name,
    ''job''
from msdb..sysjobs j with (nolock)
where j.name like @what
select @rows=@@rowcount
'

-- ##########################
-- ##
-- ## svn cache
-- ##
-- ########################################################
insert #sql select 'svn','
declare @d datetime select @d=getdate()
-- 1st fast pass filter
select c.rid as id,c.id as colid,[val] as [text],c.idx
into #syscomments
from fnd c with (nolock),tids
where c.tid=tids.code and [val] like ''%''+@what+''%''
if @dbg=1 exec sp__elapsed @d out,''-- after 1st pass''

-- search into source
declare @tobj tinyint
select @tobj=obj from tids
insert #tmp_found(id,colid,p1,p2,p3)
select
    id,colid,
    patindex(@m1,replace([text],'']'',''¬'')) p1,
    patindex(@m2,replace([text],'']'',''¬'')) p2,
    patindex(@m3,replace([text],'']'',''¬'')) p3
from #syscomments c
where patindex(@m1,replace([text],'']'',''¬''))>0
or patindex(@m2,replace([text],'']'',''¬''))>0
or patindex(@m3,replace([text],'']'',''¬''))>0
select @rows=@@rowcount
if @dbg=1 exec sp__elapsed @d out,''-- after 2nd pass''

-- extract functions/sub name and line range

if @dbg=1 exec sp__elapsed @d out,''-- after 3rd pass''

update #tmp_found set
    db=substring(
        o.val,
        charindex(''://'',o.val),
        dbo.fn__charindex(''/'',o.val,-1)-charindex(''://'',o.val)
        ),
    obj=substring(o.val,dbo.fn__charindex(''/'',o.val,-1)+1,128),
    xtype=''svn'',
    [txt1_or_obj]=f.obj,
    [txt2_or_type]=
        case f.typ when 1 then ''sub'' else ''function'' end,
    txt3=
        case
        when p1>0
        then substring(c.[text],p1-@range*2,p1+@range-p1+@range*2)
        when p2>0
        then substring(c.[text],p2-@range*2,p2+@range-p2+@range*2)
        when p3>0
        then substring(c.[text],p3-@range*2,p3+@range-p3+@range*2)
        else ''''
        end
from #tmp_found t
join fnd o with (nolock) on o.tid=@tobj and t.id=o.id   -- extract path
join #syscomments c with (nolock) on c.id=t.id and c.colid=t.colid
join #func f on c.idx between f.[from] and f.[to] and c.id=f.rid
if @dbg=1 exec sp__elapsed @d out,''-- after 3rd pass''
'

-- ===================================================== parse functions/subs ==
if @svn=1 select * into #func from (
    select
        a.rid,-- f.val as [file],
        1 typ,
        ltrim(substring(a.val,charindex('sub ',a.val)+4,charindex('(',a.val)-charindex('sub ',a.val)-4)) as obj,
        a.idx [from],
        (select top 1 b.idx
         from fnd b
         where a.rid=b.rid and b.idx>a.idx
         and patindex('end sub%',ltrim(b.val))>0
         order by b.idx
        ) [to]
    from fnd a
    join fnd f on a.rid=f.id
    where left(ltrim(a.val),1)!=''''
    and patindex('end sub%',ltrim(a.val))=0
    and (patindex('sub %',a.val)>0
         or patindex('% sub %',a.val)>0
        )
    and patindex('delegate %',a.val)=0
    and patindex('% delegate %',a.val)=0
    and charindex('(',a.val)>charindex('sub ',a.val)

    union

    select
        a.rid,-- f.val as [file],
        0 typ,
        ltrim(substring(a.val,charindex('function ',a.val)+9,charindex('(',a.val)-charindex('function ',a.val)-9)) as obj,
        a.idx [from],
        (select top 1 b.idx
         from fnd b
         where a.rid=b.rid and b.idx>a.idx
         and patindex('end function%',ltrim(b.val))>0
         order by b.idx
        ) [to]
    from fnd a
    join fnd f on a.rid=f.id
    where left(ltrim(a.val),1)!=''''
    and patindex('end function%',ltrim(a.val))=0
    and (patindex('function %',a.val)>0
         or patindex('% function %',a.val)>0
        )
    and patindex('delegate %',a.val)=0
    and patindex('% delegate %',a.val)=0
    and charindex('(',a.val)>charindex('function ',a.val)
    ) subs_and_functions

-- =========================================================== scan databases ==

declare cs cursor local for
    select db
    from #dbs
    where 1=1
open cs
while 1=1
    begin
    fetch next from cs into @db
    if @@fetch_status!=0 break

    declare css cursor local for
        select typ,replace([sql],'%db%',@db)
        from #sql
        where (@tags=0)
        or (@tags=1 and typ='tags')
        order by id
    open css
    while 1=1
        begin
        fetch next from css into @typ,@sql
        if @@fetch_status!=0 break

        if @dbg=2 exec sp__prints @typ

        if @typ='svn' and @svn=0 continue

        begin try
        exec sp_executesql
                @sql,@params,
                @m1=@m1,@m2=@m2,@m3=@m3,@range=@range,@what=@what,@db=@db,
                @obj=@obj,@xtype=@xtype,@err=@err out,@rows=@rows out,
                @dbg=@dbg
        end try
        begin catch
        select @emsg=error_message()
        raiserror(@emsg,11,1)
        if @dbg>0 exec sp__printf 'error occurred into:'
        else exec sp__printf 'use @dbg=1 or @dbg=2 to see more info'
        if @dbg>0 exec sp__printsql @sql
        end catch
        if @err!=0 or @dbg=2 exec sp__printsql @sql
        if @dbg=2
            begin
            exec sp__printf '-- found:%d rows',@rows
            exec sp__select_astext 'select * from #tmp_found'
            exec sp__printf ''
            truncate table #tmp_found
            end
        end -- sqls
    close css
    deallocate css

    end -- db loop

close cs
deallocate cs


-- show results
display:

if charindex('|script|',@opt)>0
    begin
    delete from #tmp_found where obj='sp__find'
    select @sql=null
    select @sql=isnull(@sql+'|','')+obj
    from (
        select distinct obj
        from #tmp_found
        ) tmp
    order by obj
    exec sp__printf 'exec sp__drop ''%s'',@simul=0\nGO',@sql
    declare cs cursor local for
        select distinct obj
        from #tmp_found
        -- where xtype in ('p','
        -- select * from fn__xtype()
        order by obj
    open cs
    while 1=1
        begin
        fetch next from cs into @obj
        if @@fetch_status!=0 break
        exec sp__script @obj
        exec sp__printf 'GO'
        end -- while of cursor
    close cs
    deallocate cs

    goto dispose
    end

-- =========================================================== output results ==

if @dbg=1 select * from #sysobjects order by name

if object_id('tempdb..#sp__find_out') is null
    begin
    if @dbg!=2
        begin
        if charindex('|print|',@opt)=0
        and charindex('|html|',@opt)=0
            begin
            select @sql='
            select distinct db,obj,xtype,[txt1_or_obj],[txt2_or_type],txt3
            from #tmp_found a
            where not obj is null
            order by db,xtype,obj
            '
            if charindex('|distinct|',@opt)!=0
                select @sql=replace(@sql,'[txt1_or_obj],[txt2_or_type],txt3','
                    (select top 1 [txt1_or_obj] from #tmp_found b where b.db=a.db and b.obj=a.obj) txt1_or_obj,
                    (select top 1 [txt2_or_type] from #tmp_found b where b.db=a.db and b.obj=a.obj) txt2_or_type,
                    (select top 1 [txt3] from #tmp_found b where b.db=a.db and b.obj=a.obj) txt3
                    ')
            exec(@sql)
            end
        else
            begin
            select @sql='
                select distinct db,obj,xtype,[txt1_or_obj],[txt2_or_type],txt3
                from #tmp_found a
                where not obj is null
                order by 1,3,2
                '
            if charindex('|distinct|',@opt)!=0
                select @sql=replace(@sql,'[txt1_or_obj],[txt2_or_type],txt3','
                    (select top 1 [txt1_or_obj] from #tmp_found b where b.db=a.db and b.obj=a.obj) txt1_or_obj,
                    (select top 1 [txt2_or_type] from #tmp_found b where b.db=a.db and b.obj=a.obj) txt2_or_type,
                    (select top 1 [txt3] from #tmp_found b where b.db=a.db and b.obj=a.obj) txt3
                    ')
            if charindex('|html|',@opt)=0
                exec sp__select_astext @sql -- ,@dbg=1
            else
                exec sp__select_astext @sql,@opt='html',@header=1
            end
        end
    end
else
    insert #sp__find_out(
        db,obj,xtype,[txt1_or_obj],[txt2_or_type],txt3
        )
    select distinct db,obj,xtype,[txt1_or_obj],[txt2_or_type],txt3
    from #tmp_found
    where not obj is null
    order by db,xtype,obj


dispose:
drop table #tmp_found
drop table #sysobjects
drop table #dbs

goto ret

-- =================================================================== errors ==
err_svn: exec @ret=sp__err 'wrong svn request (%s)',@proc,@p1=@tmp goto ret

-- ===================================================================== help ==
help:

select @params=@cr+'|'+@lf+'|'+@tab+'|¬'
select @sym=replace(@sym,' ','{space}')
exec sp__str_replace @sym out,@params,'{carrige}','{line feed}','{tab}','[]'
exec sp__usage @proc,'
Scope

    search for word/s between symbols
        >|
         %p1%
         |<

Notes

    * If begin or end with "%" a normal LIKE is used
    * Due limits of 4k''s  MSSQL store method,
      if a word is split across two chunk (syscomments.text),
      will not found.
    * SVN data are cached into "utility..fnd" table and then refreshed
    automatically before every search.
    * sp__find uses a local "fnd" link to utility.fnd

Parameters

    @what   is the text to search
            or a svn path
    @obj    filter objects by %name% (can be multiple xx|yy|...)
    @xtype  filter for specific type (V,P,F_,etc.)
    @range  default 20, is the len of extracted chars before and after
            point where searched text was found

    @opt    options
            tags        search only info tags
                        (can add to MSSMS keyboard shortcut as
                         ctrl+? -> sp__find @opt=''tags'',@what=
                        )
            dbs         search in all databases
            script      script the objects found
            print       show result as text
            html        return a <table>...</table>
            distinct    show obj only once and the top 1 of txt1,2,3
            ------- svn options -----------------------------------------
            clean   delete all downloaded data for the specified svn path
            svn     enable update & search from svn cached data
            unlock  force unlock of (probable) broken "already importing"

    #sp__find_found     if exists, the output is stored here and not shown
                            create table #sp__find_out(
                                -- id int identity,
                                db sysname null,
                                obj sysname null,
                                xtype sysname null,
                                [txt1_or_obj] sysname null,
                                [txt2_or_type] sysname null,
                                txt3 sysname null
                                )
    @dbg    1: show preselected objects and likes @m1,@m2,@m3
            2: print code and relative results

Examples

    exec sp__find "sp__find"

    exec sp__find "moved"

    exec sp__find @opt="tags",@what="moved"

    exec sp__find "[utility]"       -- special search, as word "[utility]"
    exec sp__find "%[utility]"      -- this is an error because will search
                                       anithing that cotain u,t,i,l,y.

    exec sp__find "fn__test[1(]"
        -- search the calls to "fn__test(" or "sp__test1"
        -- usefull to replace old versions of a function

    -- ########## SVN ########## --
    exec sp__find "svn://svr/SOURCES"         -- list content recursivelly
    exec sp__find "svn://svr/SOURCES/*.vb"    -- set and do a download
                                              -- or update existing

-- list of svn downloads --
',@p1=@sym

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__find