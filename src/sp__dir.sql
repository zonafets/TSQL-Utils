/*  Leave this unchanged doe MS compatibility
    l:see LICENSE file
    g:utility
    v:131117.1000\s.zaglio:more detailed dbg info and enlarged @files.key size
    v:131021\s.zaglio:some correction near use of @kp
    v:131018\s.zaglio:corrected a bug if under mssql2k5
    v:131016.1000,131015,131014\s.zaglio: adding list of sub directory and unicode support
    v:130906,130904\s.zaglio: better help;added more debug info and (net) errors check
    v:130424,130227\s.zaglio: avoid #files when used with shortkey(* option);a small bug near full search
    v:130115,121116\s.zaglio: added grp: option;a bug near extra drop of #src
    v:121010\s.zaglio: in * opt, search _word% and word% added @isql
    v:120926,120919\s.zaglio: print instead of select and +select option;added # has wild char
    v:120918,120828,120209\s.zaglio: #files.size to bigint;added option *;remove #objs
    v:120112\s.zaglio: added read of format date from registry
    v:120111\s.zaglio: adapted to new #files format and a remake
    v:111103\s.zaglio: used fn__ntext_to_lines and dir when english settings
    v:110316\s.zaglio: adapted to last sp__write_ntext_to_lines upd
    v:100919.1115,100919.1100\s.zaglio: compatible with mssql2k;added special syntax
    v:100919.1000\s.zaglio: a bug in list of db objs and added out to #files
    v:100509,100508\s.zaglio: added @subdir;added DR flag and directory distinction
    v:100410,100405,100402\s.zaglio: added db search;added @out;a remake
    t:sp__dir '*str*',@dbg=1
    t:sp__dir '%temp%\*.*',@dbg=1
    t:sp__dir 'c:\*.ini',@opt='s',@dbg=1    -- 16 sec by cmdline, 18 by sp
    t:sp__dir @opt='*',@path='util'
    t:job
    t:sp__dir '\\lupin\tecnico\_SCRIPTS\SINTESI\3\3.02'
*/
CREATE proc [dbo].[sp__dir]
    @path   nvarchar(512)   =null,
    @isql   nvarchar(1024)  =null,
    @opt    sysname         =null,
    @dbg    int             =0
as
begin
set nocount on
declare @proc sysname,@ret int
select  @proc=object_name(@@procid),@ret=0,
        @opt=dbo.fn__Str_quote(isnull(@opt,''),'|')

declare
    @cmd nvarchar(4000),@d datetime,
    @db sysname,@sch sysname,@obj sysname,
    @sql nvarchar(4000),@file nvarchar(4000),
    @n int,@i int, @path_ex sysname,
    @top sysname,@oby sysname,
    @psep nvarchar(2),@dsep nvarchar(2),
    @fmt sysname,@select bit,@grp bit,@s bit,
    @blob varbinary(max),@text nvarchar(max),
    @start int,@end int,@dir nvarchar(4000),
    @lng char,@rid int,@files_id int,
    @kp bit                         -- keep path in name

declare @obj_order table(xt varchar(4),ord tinyint)

insert @obj_order
select 'u',10 union
select 'tr',15 union
select 'p',20 union
select 'v',30 union
select 'if',40 union
select 'tf',50 union
select 'fn',60 union
select 'sn',70 union
select 'pk',80 union
select 'f',90 union
select 'd',100

select
    @files_id=isnull(object_id('tempdb..#files'),0),
    @dsep=':',
    @select=charindex('|select|',@opt)|charindex('|sel|',@opt),
    @grp=charindex('|grp|',@opt),
    @s=charindex('|s|',@opt)|charindex('|sub|',@opt),
    @kp=charindex('|kp|',@opt)|1-@select|1-cast(@files_id as bit),
    @psep=psep,
    @path=case charindex('|*|',@opt)
          when 0
          then @path
          else replace(@path,'#','*')+'*'
          end,
    -- full search
    @path_ex=case charindex('|*|',@opt)
           when 0 then ''
           else '*'+replace(@path,'#','*')+'*'
           end
from fn__sym()

if left(@path,4)='grp:' select @grp=1,@path=substring(@path,5,len(@path)-4)

declare @stdout table (lno int identity primary key,line nvarchar(4000))

declare @dirs table(s int,e int,dir nvarchar(4000))

declare @files table (
    id int identity primary key,
    [key] nvarchar(446),sdt nvarchar(32),dt datetime,
    sfsize nvarchar(64) null ,n bigint null, flags smallint,
    rid int null
    )

declare @objs table (
    id int identity primary key,
    obj sysname,
    xtype nvarchar(2)
    )

if @path is null goto help

create table #src(lno int identity primary key,line nvarchar(4000))

if @grp=1
    begin
    select
        *
    from fn__script_info(default,'g',0)
    where cast(val1 as sysname) like replace(@path,'*','%')
    goto ret
    end

-- =========================================================== list from disk ==

if charindex(@dsep,@path)>0 or charindex(@psep,@path)>0
    begin

    -- temp file for output of dir
    exec sp__get_temp_dir @file out
    select @file=@file+@psep+replace(convert(sysname,newid()),'-','_')

    if @dbg>0 exec sp__elapsed @d out

    -- this is the faster method found
    select @cmd ='cmd /u /c dir /4'+case @s when 1 then '/s' else '' end
                                   +' "'+@path+'" >'+@file+'.txt' -- 11 secs x 250000
                                   +' 2>'+@file+'.err'
    if @dbg>1 exec sp__printf '%s',@cmd
    delete from @stdout
    insert @stdout exec master..xp_cmdshell @cmd
    select @sql=null
    select top 1 @sql=line from @stdout where line is not null
    if not @sql is null goto err_dir

    if @dbg>0
        exec sp__elapsed @d out,'-- dir&err listed into %s in ',@v1=@file

-- ======================================================= load and split txt ==

    select @blob=null,@text=null
    select @sql='select @blob=BulkColumn '
               +'from openrowset(bulk '''+@file+'.txt'', single_blob) as x'
    exec sp_executesql @sql,N'@blob varbinary(max) out',@blob=@blob out

    select @text=cast(@blob as nvarchar(max))

    if @dbg>0 exec sp__elapsed @d out,'-- file TXT readed into memory'

    if @@error<>0
        exec sp__printf '%s','>>> If error 4861, see http://msdn.microsoft.com/en-us/library/ms188365.aspx'

    truncate table #src
    insert #src(line) select line from fn__ntext_to_lines(@text,0)
    -- 111102\s.zaglio:deprecated sp__write_ntext_to_lines

    if @dbg>0 exec sp__elapsed @d out,'-- TXT splitted into lines'

    if @dbg>1
        begin
        select '#src' [#src],* from #src
        exec sp__elapsed @d out,'-- after show of #src'
        end

-- ======================================================= load and split err ==

    select @blob=null,@text=null
    select @sql='select @blob=BulkColumn '
               +'from openrowset(bulk '''+@file+'.err'', single_blob) as x'
    exec sp_executesql @sql,N'@blob varbinary(max) out',@blob=@blob out

    select @text=cast(@blob as nvarchar(max))

    if @dbg>0 exec sp__elapsed @d out,'-- file ERR readed into memory'

    if @@error<>0
        exec sp__printf '%s','>>> If error 4861, see http://msdn.microsoft.com/en-us/library/ms188365.aspx'

    delete from @stdout
    insert @stdout(line) select line from fn__ntext_to_lines(@text,0)
    -- 111102\s.zaglio:deprecated sp__write_ntext_to_lines

    if @dbg>0 exec sp__elapsed @d out,'-- ERR splitted into lines'

    if @dbg>1 select 'stdout' [stdout],* from @stdout
    select @sql=null
    select top 1 @sql=line from @stdout where line is not null
    if not @sql is null goto err_dir

-- ======================================================== delete temp files ==

    select @cmd='del /q '+@file+'.txt&del /q '+@file+'.err'
    exec master..xp_cmdshell @cmd,no_output

-- ======================================================== split directories ==

    -- t:sp__dir 'c:\*.ini',@opt='s|select' ,@dbg=1
    -- t:sp__dir 'c:\*.ini',@opt='s' ,@dbg=1
    -- t:'sp__dir ''i:\temp\*'',@opt=''s'',@dbg=1'
    -- t:'sp__dir ''c:\*.ini'',@opt=''s'',@dbg=1'
    select @n=1
    if @s=0
        begin
        insert @dirs
        select min(lno),max(lno),
               case @kp when 1 then @path else '' end from #src
        goto skip_with
        end

    -- mssql 2k5 do not support with under if
    ;with dirs(lno,dir) as (
        select lno,right(line,charindex(' ',reverse(line),
                                        len(line)-charindex(@psep,line))-1
                        ) dir
        from #src where line like ' %directory %'+@psep+'%'
        )
    insert @dirs(s,e,dir)
    select
        s.lno+1 s_lno,
        isnull((select top 1 lno from dirs e where e.lno>s.lno),
               (select max(lno) from #src))-1
        as e_lno,
        s.dir
    from dirs s
    select @n=@@rowcount
    if @dbg>0 exec sp__elapsed @d out,'-- %d direcotries',@v1=@n

skip_with:

    if @dbg>0 exec sp__elapsed @d out,'-- tmp file deleted and split or dirs'

-- ============================================================= check region ==

    -- get local date format
    exec master.. xp_regread
            'HKEY_CURRENT_USER','Control Panel\International',
            'sShortDate',
            @fmt out
    -- or by cmd: REG QUERY "HKCU\Control Panel\International" /v sShortDate&
    -- exec master..xp_regenumvalues 'HKEY_CURRENT_USER','Control Panel\International'
    -- GRANT EXECUTE ON sys.xp cmdshell TO [BUILTIN\Users];

    /*  old solution by inspecting content
    if exists(
        select top 1 line
        from #src
        where substring(line,19,2) in ('PM','AM') -- english setting
        )
        select @eng=1
    else
        select @eng=0
    */
    if @fmt like 'd%/m%/y%' select @lng='I'
    if @fmt like 'm%/d%/y%' select @lng='E'
    if @lng is null goto err_fmt

-- ====================================================== list files with dir ==

    -- 18 by sp, 17 without fn__dir_parse_list
    declare cs cursor local for
        select s,e,dir
        from @dirs
        where 1=1
    open cs
    while 1=1
        begin

        fetch next from cs into @start,@end,@dir
        if @@fetch_status!=0 break

        select @rid=0
        insert @files(rid,sdt,sfsize,[key])
        select @rid,sdt,sfsize,case @kp when 1 then @dir+'\'+name else name end
        from #src cross apply fn__dir_parse_list(line,@lng)
        where line like '[0-9]%'
        and not line like '%.'
        and not line is null
        and lno between @start and @end

        end -- cursor cs
    close cs
    deallocate cs

    if @dbg>2 select '@files' [@files],* from @files

    -- convert strings
    update @files set
        [n]=case
            when isnumeric(sfsize)=1
            then convert(bigint,sfsize)
            else null
            end,
        [dt]=convert(datetime,sdt),
        flags=case when sfsize='<dir>' then 32 else 0 end

    select @n=@@rowcount
    if @dbg>0 exec sp__elapsed @d out,'-- %d files parsed in',@v1=@n

    if @dbg>2 select top 100 'top 100 upd' step,* from @files

    if @files_id=0 or charindex('|*|',@opt)>0
        begin
        if @select=1
            select
                [key] as path,
                flags,
                dt as creation_date,
                n as bytes
            from @files
            -- order by rid,[key]
        else
            begin
            -- insert #files([key],flags,dt,n)
            select id,[key],flags,dt,n
            into #files
            from @files
            -- order by rid,[key]
            exec sp__select_astext '
                select
                    dt as creation_date,n as bytes,flags,[key] as path
                from #files
                order by path'
            end
        end
    else
        begin
        insert #files([key],flags,dt,n)
        select [key],flags,dt,n from @files
        -- create an index on name
        if not exists(
            select null from tempdb..sysindexes
            where id=@files_id and name='#ix_files'
            )
            create index #ix_files on #files(rid,[key])
        end

    end     -- list files

-- ============================================================= list objects ==

else

    begin
    select @path=replace(@path,'_','[_]')
    select @path=replace(@path,'%','[%]')
    select @path=replace(@path,'?','_')
    select @path=replace(@path,'*','%')

    select @path_ex=replace(@path_ex,'_','[_]')
    select @path_ex=replace(@path_ex,'%','[%]')
    select @path_ex=replace(@path_ex,'?','_')
    select @path_ex=replace(@path_ex,'*','%')

    -- sp__dir @opt='*',@path='file'
    -- exec sp__printf 'p:%s, e:%s',@path,@path_ex
    -- sp__dir 'rep*','print ''%obj%'''

    insert @objs(obj,xtype)
    select [name],xtype
    from sysobjects
    where [name] like @path
    or [name] like @path_ex
    order by 2,1

    if isnull(@isql,'')!=''
        begin
        insert #src(line)
        select replace(@isql,'%obj%',obj)
        from @objs
        order by isnull(
                    (select ord from @obj_order where xt=xtype),
                    ascii(xtype)
                 ), obj
        if @select=1 select line from #src order by lno
        else exec sp__print_table '#src'
        end
    else
        begin
        if object_id('tempdb..#files') is null or charindex('|*|',@opt)>0
            begin
            if @select=1
                select * from @objs
                order by isnull(
                            (select ord from @obj_order where xt=xtype),
                            ascii(xtype)
                         ), obj
            else
                begin
                select identity(int,1,1) id,obj,xtype
                into #objs
                from @objs
                order by isnull(
                            (select ord from @obj_order where xt=xtype),
                            ascii(xtype)
                         ), obj

                exec sp__select_astext 'select * from #objs order by 1'
                drop table #objs
                end
            end
        else
            insert #files([key],flags)
            select
                obj,
                convert(smallint,cast(cast(xtype as varchar(2)) as binary(2)))
            from @objs
        end -- !@isql

    -- select @db=db,@sch=sch,@obj=obj from dbo.fn__parsename(@what,0,1)
    end -- db objs

dispose:
drop table #src
-- #files is dropped by engine
goto ret
-- =================================================================== errors ==
err_fmt:    exec @ret=sp__err 'unknown date setting %s',@proc,@p1=@fmt goto ret
err_dir:    exec @ret=sp__err '%s',@proc,@p1=@sql                      goto ret
-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    list objects or files of a db or dir
    (sp__ftp uses the same #files format)

Notes
    I normally associate this SP to CTRL+4 as "sp__dir @opt=''*'',@path="

Parameters
    @path   can be a dir path or name of object of db
            store the list into #files if exists
            accept wild card *,? for both objects
            if begin with "grp:" or grp option is specified,
            search into group names of db objects

            create table #files (
                id int identity primary key,
                rid int default(0),     -- for subdirs
                [flags] smallint,       -- if &32=32 is a <DIR>
                [key] nvarchar(446),    -- obj name
                dt datetime,            -- creation date
                n bigint null           -- size in bytes
                )

    @isql   macro code that is printed instead of list where %obj% were replaced
    @opt    options
            *       consider automtically @path as "@path% or %[_]@path%"
                    to attach to a shortkey of SSMS; # can used as jolly char
            select  select instead of print results
            grp     see @path parameter info
            s       same as /s of dir, run recursivelly into sub directories
            sub     alias of option s
            kp      keep path in name (key)
    @dbg    1   show base info and statistics
            2   show also internal tables content

Notes
    where bytes is null, there is a <DIR>
    and index #ix_files will created on rid,key

Examples
    exec sp__dir ''c:\test_if_exists''

    create table #files ...
    exec sp__dir ''c:\'',@dbg=1
    select * from #files
    drop table #files

'
-- ===================================================================== exit ==

ret:

return @ret
end -- sp__dir