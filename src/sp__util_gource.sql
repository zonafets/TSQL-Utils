/*  leave this
    l:see LICENSE file
    g:utility
    v:120823\s.zaglio: return a custom log for gource
    d:120823\s.zaglio: sp__script_svn_log
    t:sp__util_gource @opt='run|util'
    t:sp__util_gource @opt='run'
*/
CREATE proc sp__util_gource
    @opt sysname=null,
    @dbg int=0
as
begin
/*
gource.exe
--log-format svn -s 0.1 --stop-at-end --max-file-lag 10
--title "TSQL Utility" -640x480  --hide bloom,progress,dirnames
--disable-auto-rotate --key --file-idle-time 0 --camera-mode overview
utility.xml

ffmpeg
-y -r 60 -f image2pipe -vcodec ppm -i utility.ppm
-vcodec libx264 -preset ultrafast -crf 1 -threads 0 -bf 0 utility.avi
*/
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
if @opt is null or charindex('|run|',@opt)=0 goto help

-- ============================================================== declaration ==
declare
    @sdt sysname,@id int,@d sysname,@t sysname,@dt datetime,
    @util bit

-- insert before here --  @end_declare bit
create table #src(lno int identity, line nvarchar(4000))
-- =========================================================== initialization ==
select
    @util=charindex('|util|',@opt)
-- ======================================================== second params chk ==
-- ===================================================================== body ==
-- drop table #rel
select
    identity(int,1,1) as id,
    object_name(obj_id) name,
    case tag when 'd' then cast(isnull(val3,val1) as sysname) else obj end as obj,
    tag,
    cast(val1 as sysname) as sdt,
    cast(val2 as sysname) as author
into #rel
-- select top 100 *
from fn__script_info(default,'rvdx',default)
where not obj like '%[_]old'

if @util=1 delete from #rel where not obj like '%[_][_]%'
else delete from #rel where obj like '%[_][_]%'

alter table #rel add
    dt datetime,
    unix_timestamp sysname,
    grp sysname,
    color int,
    scolor varchar(6)

update #rel set
    obj=case @util when 1
        then substring(obj,charindex('__',obj)+2,128)
        else obj
        end,
    grp=case @util when 1
        then dbo.fn__str_between(obj,'__','_',default)
        else dbo.fn__str_between(obj,'_','_',default)
        end,
    author=lower(isnull(author,
        case @util when 1 then 's.zaglio' else 'unknown' end
        ))

update #rel set
    color=abs(dbo.fn__crc32(grp))/256

update #rel set grp=null,color=5592405*2.8 where grp=obj

update #rel set color=color+5592405 where color<5592405

update #rel set
    scolor=upper(right(dbo.fn__hex(color),6))

delete from #rel where isnumeric(sdt)=0 and tag='d'

-- select * from #rel where obj is null or isnumeric(sdt)=0
-- select * from #rel where sdt like '%24.100%'
-- set nocount on
-- declare @sdt sysname,@id int,@d sysname,@t sysname,@dt datetime
declare cs cursor local for
    select id,sdt
    from #rel
    where 1=1
open cs
while 1=1
    begin
    fetch next from cs into @id,@sdt
    if @@fetch_status!=0 break

    if @sdt='000000' select @sdt=convert(sysname,cast(0 as datetime),12)

    select
        @d= dbo.fn__format(left(@sdt,6),'@12-34-56',default),
        @t= case when charindex('.',@sdt)=0
            then '00:00:00'
            else dbo.fn__format(right(@sdt,4),'@12:34',default)+':00'
            end

    begin try
    select @dt=convert(datetime,@d,11)+convert(datetime,@t,8)
    update #rel set dt=@dt where id=@id
    end try
    begin catch
    exec sp__printf '-- cannot convert %d:%s(%s,%s)',@id,@sdt,@d,@t
    end catch

    end -- cursor cs
close cs
deallocate cs
-- select * from #rel where id in (379,487)
delete from #rel where dt is null

update #rel set unix_timestamp=dbo.fn__unix_timestamp(dt)

-- 1275543595|andrew|A|src/main.cpp|FF0000
select
    unix_timestamp + '|' +
    author + '|' +
    case tag when 'd' then 'D' else 'M' end + '|' +
    isnull(grp+'/','')+obj + '|' +
    scolor
    as line
from #rel
order by dt

-- exec sp__print_table '#src'

drop table #src

/* after generation, can use gourge. For me better results are with:

gource.exe utility.log -s 0.3 -r 25 --stop-at-end -800x600 --highlight-dirs
           --font-size 12 --font-colour 0000FF -o utility.ppm
           --key --title "utility" --max-files 0 --highlight-all-user -i 0

ffmpeg -y -b 3000K -r 30 -f image2pipe -vcodec ppm -i utility.ppm
       -vcodec libx264 -fpre "e:/share/ffmpeg/libx264-slow.ffpreset"
       -threads 0 utility.mp4
*/

goto ret

-- =================================================================== errors ==
-- err_sample1: exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    produce a custom log to use with gsource from build info of sp/fn of db

Parameters
    @opt    options
            util    script only utility or sp/fn with __ in the name
            run     produce the log

Notes
    After that you can save the output to a file and call gource:

    gource.exe
        --log-format svn -s 0.1 --stop-at-end --max-file-lag 10
        --title "myTitle" -640x480  --hide bloom,progress,dirnames
        --disable-auto-rotate --key --file-idle-time 0 --camera-mode overview
        -o output.ppm
        output.log

    ffmpeg
        -y -r 60 -f image2pipe -vcodec ppm -i output.ppm
        -vcodec libx264 -preset ultrafast -crf 1 -threads 0 -bf 0 output.avi
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__util_gource