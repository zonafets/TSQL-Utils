/*  leave this
    l:see LICENSE file
    g:utility
    k:each,object,single,file,one,into
    v:151107\s.zaglio: better dbg info
    v:130903\s.zaglio: renamed group list to index.txt
    r:130902\s.zaglio: added group list
    r:130830,130829,130824\s.zaglio: script each object of a group into file
    d:130824\s.zaglio:sp__script_tofile
    t:sp__script_group_tofile 'utility@s.zaglio','%temp%\utility',@dbg=1
    t:sp__script_group_tofile 'sp__script_declares','%temp%\utility',@dbg=1
*/
CREATE proc sp__script_group_tofile
    @grp nvarchar(4000) = null,
    @out nvarchar(1024) = null,
    @exclude nvarchar(4000) = null,
    @include nvarchar(4000) = null,
    @opt sysname = null,
    @dbg int=0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
-- @@nestlevel is >1 if called by other sp

set nocount on

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    @err_msg nvarchar(2000)             -- used before raise

-- ======================================================== params set/adjust ==
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=nullif(@opt,''),
    @opt=case when @opt is null then '||' else dbo.fn__str_quote(@opt,'|') end
    -- @param=nullif(@param,''),

-- ============================================================== declaration ==
declare
    @i int,@aut sysname,@src_id int,@obj sysname,@xt nvarchar(2),
    @tag nvarchar(8),@ver sysname,@drop nvarchar(512),@ext sysname,
    @temp nvarchar(512),@path nvarchar(1024),@n int,
    @psep nchar(1),@cmd nvarchar(1024),@pext int,@pdir int,
    @fmt sysname,@list_filename nvarchar(1024),@cr nchar(1),@lf nchar(1),
    -- option
    @lo bit,
    @end_declare bit

if @src_id is null
    create table #src (lno int identity,line nvarchar(4000))

-- =========================================================== initialization ==
exec sp__get_temp_dir @temp out
select
    @psep=psep,
    @grp=nullif(@grp,''),
    @ext='.sql',
    @out=nullif(replace(@out,'%temp%',@temp),''),
    @cr=cr,@lf=lf,
    -- options
    @lo=charindex('|lo|',@opt)
from fn__sym()

-- ======================================================== second params chk ==
if @grp is null goto help

select
    @pext=dbo.fn__charindex('.',@out,-1),
    @pdir=dbo.fn__charindex(@psep,@out,-1)

if @pext>0 select @ext=''
if @pext>@pdir raiserror('@out must be a path ending with %s',16,1,@psep)
if right(@out,1)!=@psep select @out=@out+'\'

-- ========================================================= get objects list ==
-- normalize objects list if given
select @grp=replace(replace(@grp,@lf,@cr),@cr+@cr,@cr)
select @grp=replace(@grp,@cr,'|')

-- extract author to filter, if given
select @i=charindex('@',@grp)
if @i>0 select @aut=substring(@grp,@i+1,128),@grp=left(@grp,@i-1)

-- =============================================================== #tbls init ==
select top  0 * into #objs_list
from fn__script_group_select(default,default,default,default,default)

-- temp table for index file
select top 0
    -- identity(int,1,1) lno,
    obj,tag,ver,aut,des
into #group_file_list
from #objs_list

-- ===================================================================== body ==

insert into #objs_list
select *
from fn__script_group_select(@grp,@exclude,@include,'@'+@aut,default)

-- if no grp objects, test for single object
if @@rowcount=0 and not object_id(@grp) is null
    begin
    if @dbg>0 exec sp__printf 'adding single object, keeping directory'
    insert into #objs_list
    select g.*
    from fn__script_group_select(default,@exclude,@include,'@'+@aut,default) g
    cross apply fn__str_table_fast(@grp,'|') objs
    where obj like objs.token
    end
else    -- found grp's objects
    begin
    -- register info about group (now is in the name:@grp.csv)
    -- insert #group_file_list(obj,tag,ver,aut,des) select @grp,'','','',''
    -- drop target directory if exists
    if not @out is null
        begin
        select @cmd='rmdir /s /q "'+@out+'"'
        exec xp_cmdshell @cmd,no_output
        end
    end

if not @out is null
    begin
    select @list_filename=@out+@grp+'.csv'
    -- create target directory
    select @cmd='mkdir "'+@out+'"'
    exec xp_cmdshell @cmd,no_output
    end

-- ======================================================= create/update list ==
-- reload file if exists
if not @out is null
    begin
    if @dbg>0 exec sp__printf 'list to: %s',@list_filename

    exec xp_fileexist @list_filename, @i output
    if @i!=0 exec sp__csv_import @list_filename,'#group_file_list',@opt='noh'

    if @dbg>0 select @n=count(*) from #group_file_list
    end

-- update/add released/versioned
update gl set ver=ol.ver, aut=ol.aut, des=ol.des
from #group_file_list gl join #objs_list ol
on gl.obj=ol.obj and gl.tag=ol.tag
if @dbg>0 select @n=@@rowcount

insert #group_file_list(obj,tag,ver,aut,des)
select ol.obj,ol.tag,ol.ver,ol.aut,ol.des
from #group_file_list gl right join #objs_list ol
on gl.obj=ol.obj and gl.tag=ol.tag
where ol.tag in ('r','v') and gl.obj is null
if @dbg>0 select @n=@@rowcount

-- update/add deprecated
update gl set ver=ol.ver, aut=ol.aut, des=ol.des
from #objs_list ol
join #group_file_list gl on gl.obj=ol.des and gl.tag=ol.tag
where ol.tag in ('d')
if @dbg>0 select @n=@@rowcount

insert #group_file_list(obj,tag,ver,aut,des)
select distinct ol.des,ol.tag,ol.ver,ol.aut,'in '+ol.obj
from #objs_list ol
left join #group_file_list gl on gl.obj=ol.des and gl.tag=ol.tag
where ol.tag in ('d') and gl.obj is null
if @dbg>0 select @n=@@rowcount

-- print list if no to out-put
if @out is null
    begin
    exec sp__select_astext '#group_file_list'
    goto ret
    end

-- save list to file
if 0=(select count(*) from #group_file_list)
    raiserror('generating group file list',16,1)

exec sp__csv_export '#group_file_list',@list_filename,@opt='noh'

if @lo=1 goto dispose

-- ========================================= loop into list, script and store ==

declare cs cursor local fast_forward for
    select grp.obj,grp.xt,grp.tag,grp.ver,grp.aut,grp.[drop]
    from #objs_list grp
    where tag in ('r','v')
    order by grp.ord,grp.obj

open cs
while 1=1
    begin
    fetch next from cs into @obj,@xt,@tag,@ver,@aut,@drop
    if @@fetch_status!=0 break

    -- refine path
    select @path=@out+@obj+@ext

    if @dbg>1
        exec sp__printf 'to script obj:%s(%s) ver:%s aut:%s',@obj,@xt,@ver,@aut
    else
        begin
        truncate table #src
        exec @ret=sp__script @obj
        select @n=count(*) from #src
        if @dbg>0
            exec sp__printf 'scripting obj:%s(%s) ver:%s aut:%s lines:%d to:%s',
                            @obj,@xt,@ver,@aut,@n,@path
        if @ret=0 exec @ret=sp__file_write_stream @path,@fmt=@fmt
        if @ret!=0 goto ret -- sp has written its error
        end

    end -- while
    close cs
    deallocate cs

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    script each object of a group into a single file

Notes
    - a file index.txt is created and populated with the list of
      versions in CSV format:
            obj,tag,version,author,last comment

    - when single objects are scripted, the content of directory is kept and
      the list updated

Parameters
    [param]     [desc]
    @grp        group name with optional prefix @author or list of objects
                separated by | or CR/LF
    @out        destination path (a directory where put obj_name.sql and index.txt)
                if null index.txt is shown to console to be used by sp__upgrade
    @opt        options
                lo      list only, fill #objs_list without store files
    @dbg        1=show execution info
                2=show objects to script without script and save to file
                3=more up ...

Examples
    sp__script_group_tofile ''utility@s.zaglio'',''%temp%\utility''
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end try

-- =================================================================== errors ==
begin catch
-- if @@trancount > 0 rollback -- for nested trans see style "procwnt"

exec @ret=sp__err @cod=@proc,@opt='ex'
return @ret
end catch   -- proc sp__script_group_tofile