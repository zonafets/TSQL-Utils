/*  leave this
    l:%licence%
    g:utility
    v:130802\s.zaglio: about drop of #drive_info
    v:130227\s.zaglio: added dbs and logs flds
    v:130216\s.zaglio: remake
    v:100212\s.zaglio: drives info
    c:from http://www.sqlteam.com/forums/topic.asp?TOPIC_ID=92571
    t:sp__util_drives run
*/
CREATE proc sp__util_drives
    @opt sysname = null,
    @dbg bit=null
as
begin
set nocount on

declare @proc sysname,@ret int

select
    @proc=object_name(@@procid),
    @ret=0,
    @dbg=isnull(@dbg,0),
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

declare @result int
    , @objfso int
    , @drv int
    , @cdrive nvarchar(13)
    , @size nvarchar(50)
    , @free nvarchar(50)
    , @label nvarchar(10)
    , @dbs nvarchar(4000)
    , @logs nvarchar(4000)
    , @flds nvarchar(4000)
    , @oid int

select @flds='
        letter nchar(1),
        total_mb bigint,
        free_mb bigint,
        label nvarchar(10),
        [% free] int,
        dbs nvarchar(4000),
        logs nvarchar(4000)
        ',
       @oid=object_id('tempdb..#drive_info')

-- ============================================================= check params ==
if charindex('|run|',@opt)=0 goto help

declare @sysdb table (db sysname)

create table #drive_space
    (
      letter nchar(1) not null,
      freemb nvarchar(10) not null
     )

if @oid is null
    begin
    create table #drive_info(id int identity)
    exec('alter table #drive_info add '+@flds)
    end

insert @sysdb select 'master' union select 'msdb' union select 'model'

insert into #drive_space
    exec master.dbo.xp_fixeddrives

-- iterate through drive letters.
declare  curdriveletters cursor local
    for select letter from #drive_space

declare @driveletter nchar(1)

open curdriveletters
fetch next from curdriveletters into @driveletter
while (@@fetch_status <> -1)
begin
    if (@@fetch_status <> -2)
    begin
    select @cdrive = 'getdrive("' + @driveletter + '")'
    exec @result = sp_oacreate 'scripting.filesystemobject', @objfso output
    if @result = 0 exec @result = sp_oamethod @objfso, @cdrive, @drv output
    if @result = 0 exec @result = sp_oagetproperty @drv,'totalsize', @size output
    if @result = 0 exec @result = sp_oagetproperty @drv,'freespace', @free output
    if @result = 0 exec @result = sp_oagetproperty @drv,'volumename', @label output
    if @result <> 0 exec sp_oadestroy @drv
    exec sp_oadestroy @objfso
    select @size = (convert(bigint,@size) / 1048576 )
    select @free = (convert(bigint,@free) / 1048576 )

    select @dbs=null
    select @dbs=isnull(@dbs+' | ','')+db_name(database_id)
    -- select *
    from sys.master_files
    where physical_name like @driveletter+':%'
    and type=0 and not db_name(database_id) in (select db from @sysdb)

    select @logs=null
    select @logs=isnull(@logs+' | ','')+db_name(database_id)
    from sys.master_files
    where physical_name like @driveletter+':%'
    and type=1 and not db_name(database_id) in (select db from @sysdb)

    insert into #drive_info(letter,total_mb,free_mb,label,dbs,logs)
        values (@driveletter, @size, @free, @label,@dbs,@logs)
    end
    fetch next from curdriveletters into @driveletter
end

close curdriveletters
deallocate curdriveletters

-- produce report.
update #drive_info set [% free]=cast(((convert(numeric(9,0),free_mb)
                               /convert(numeric(9,0),total_mb)) * 100) as int)

-- if @out is null select @sql='' else select @sql ='insert '+@out+' '
if @oid is null
    begin
    select * from #drive_info
    drop table #drive_info
    end

drop table #drive_space
goto ret

help:
exec sp__usage @proc,'
Scope
    list drives space info with list of dbs

See
    sp__util_vlf

Notes
    the table #drive_info is used return to caller
    the data

    create table #drive_info(%p1%)

Parameters
    @opt    options
            run     execute
    @dbg    not used
',@p1=@flds

select @ret=-1

ret:
return @ret
end -- sp__util_drives