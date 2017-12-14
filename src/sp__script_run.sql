/*  leave this
    l:see LICENSE file
    g:utility
    k:download,web,get,internet
    v:140108.1506\s.zaglio: moved @dbs before @uri for fast db search
    v:131215\s.zaglio: @uri -> @src
    v:131208.0900\s.zaglio: refined load from smb
    v:130531\s.zaglio: excl. sys dbs and test, removed try-catch
    r:130529\s.zaglio: added dbs option
    r:130416\s.zaglio: added alter opt
    r:130415\s.zaglio: adding unpre opt
    r:130202\s.zaglio: run a script from @uri
    t:
        sp__script_run
            'forms|tasks',
            'i:\Documenti\dropbox\PAE\download\utility.sql'
            ,@dbg=1
    t:sp__script_run 'forms|tasks','\\localhost\xch\utility.sql',@dbg=1
    t:sp__script_run 'forms|tasks','http://localhost/downloads/utility.sql',@dbg=1
*/
CREATE proc sp__script_run
    @dbs sysname = null,
    @src nvarchar(max) = null,
    @opt sysname = null,
    @dbg int=0
as
begin
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
    -- generic common
    -- @run bit,
    @unpre bit,@alter bit,
    @crlf nvarchar(2),@cr nchar(1),@lf nchar(1),
    @i int,@n int,@j int,               -- index, counter
    -- options
    -- @sel bit,@print bit,             -- select and print option for utils
    @uri nvarchar(1024),
    @all_db nvarchar(4000),             -- option
    @db sysname,
    @end_declare bit

-- =========================================================== initialization ==
select
    -- @sel=charindex('|sel|',@opt),@print=charindex('|print|',@opt),
    -- @run=charindex('|run|',@opt)|dbo.fn__isjob(@@spid)
    --    |cast(@@nestlevel-1 as bit),        -- when called by parent/master SP
    @alter=charindex('|alter|',@opt),
    @crlf=crlf,@cr=cr,@lf=lf,
    @src=nullif(@src,''),
    @uri=ltrim(rtrim(isnull(left(@src,1024),''))),
    @db=db_name(),
    @dbs=nullif(@dbs,''),
    @end_declare=1
from fn__sym()

if charindex(@cr,@uri)>0 select @uri=left(@uri,charindex(@cr,@uri)-1)

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
if @dbs is null and @uri is null goto help

-- =============================================================== #tbls init ==

-- ===================================================================== body ==
select @dbs=isnull(@dbs,@db)

select @all_db=isnull(@all_db+',','')+name
-- select *
from sys.databases
cross apply fn__str_table(replace(@dbs,',','|'),'|')
where name like token
and not name in ('master','tempdb','model','msdb','Resource','Distribution')
and left(name,12)!='ReportServer'
order by name

/*
    t:sp__script_run '%'
    t:sp__script_run 'forms,ruler,tasks',
                     'I:\Documenti\dropbox\PAE\download\utility.sql',@dbg=1
    t:sp__script_run 'forms,ruler,tasks,xx'
*/

if (isnull(@all_db,'')!='' and @all_db!=@db) or @dbg>0
    exec sp__printf '-- to execute on:\n%s',@all_db

if isnull(@all_db,'')='' raiserror('no dbs found',16,1)
if dbo.fn__str_count(@all_db,',')<dbo.fn__str_count(@dbs,',')
    raiserror('selected dbs are less than filters',16,1)

-- list only dbs
if @uri is null goto ret

-- check king of uri
if left(@uri,6)='ftp://' raiserror('ftp not yet supported',16,1)
if @uri like '\\%@%' raiserror('smb path with uid&pwd not yer supported',16,1)

if patindex('http%://%',@uri)>0
    begin
    if @dbg>0 exec sp__printf '-- getting via web'
    exec sp__web @uri,@rsp=@src out,@rcq='get'
    if charindex('<pre>',@src)>0
    and (charindex('/>',@src)>0 or charindex('</pre>',@src)>0)
        select @unpre=charindex('|unpre|',@opt)

    -- select @src=replace(@src,@crlf+@crlf,@crlf)
    if @unpre=1
        begin
        /*
        sp__script_run
            'http://xoomer.virgilio.it/stezagl/io/eng/my_works/source/sp_source/code_sql/fn__at.htm',
            @dbg=1,@opt='unpre|alter'
        */
        select @i=charindex('<pre ',@src),@j=charindex('>',@src,@i),@i=@j+1
        select @j=charindex('</pre>',@src)
        select @src=substring(@src,@i,@j-@i)
        while left(@src,1) in (@cr,@lf) select @src=substring(@src,2,len(@src))
        while right(@src,1) in (@cr,@lf) select @src=left(@src,len(@src)-1)
        end
    select @uri=null
    end

-- file /uri) path to windows path
if left(@uri,8)='file:///'
    select @uri=replace(substring(@uri,9,1024),'/','\')

if patindex('%:%\%',@uri)>0 or left(@uri,2)='\\'
    begin
    if @dbg>0 exec sp__printf '-- reading file %s',@uri
    -- not the faster but read 2MB in 7 seconds on localmachine
    select @src=''
    exec sp__file_read_stream @uri,@out=@src out

    -- sp__file_read_stream 'I:\Documenti\web_sites\PAE\download\utility.sql'

    select @n=len(@src)
    if @dbg>0 exec sp__printf '-- loaded %d chars',@n
    select @uri=null
    end

if @alter=1
    begin
    select @i=charindex('create function',@src)
    if @i=0 select @i=charindex('create proc',@src)
    if @i=0 select @i=charindex('create procedure',@src)
    if @i=0 select @i=charindex('create view',@src)
    if @i>0 select @src=left(@src,@i-1)+'alter '+substring(@src,@i+7,len(@src))
    end

-- ##########################
-- ##
-- ## execute script
-- ##
-- ########################################################
if @src is null goto err_ems

-- if is a direct code
if not @uri is null
    begin
    -- remove initial returns
    while left(@src,1) in (@cr,@lf) select @src=stuff(@src,1,1,N'')
    -- encapsulate
    select @src='exec('''+replace(@src,'''','''''')+''')'
    end

if @dbg>0 exec sp__printsql @src

declare cs cursor local for select token from fn__str_table(@all_db,',')
open cs
while 1=1
    begin
    fetch next from cs into @db
    if @@fetch_status!=0 break

    if (isnull(@dbs,'')!='' and @dbs!=@db) or @dbg>0
        exec sp__printframe 'updating %s',@db

    if @dbg=0
        begin
        exec('use ['+@db+']'+@crlf+@src)
        end
    else
        exec sp__printf 'use [%s] ...',@db

    end -- cursor cs
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
    load a script from a file or a url or a remote server or a contant
    and execute it on local db or on multiple dbs

Parameters
    @dbs    multi like expression separated by comma or pipe
            where run the script
    @src    can be the source code of script
            or the path of the file or web address
            %:% or %\% or file:///% is a file
            \\% or %:%@\\% is a smb file            (not yet supported)
            ftp://[usr:pwd@]... is a ftp file       (not yet supported)
    @opt    options
            alter       replace create function/view/proc with alter
    @dbg    debug level
            1   show basic info and do not execute the script

Examples
    sp__script_run "%"                  -- list all dbs (w.out sys.dbs)
    sp__script_run "%tst%|%bak%"        -- list all dbs that likes tst or bak
    -- run script.sql in all selected dbs
    sp__script_run "%tst%|%bak%","c:\script.sql"
    -- get the script from internet and run into local db
    sp__script_run @src="http\\site.com\utility.sql"
    -- run constant script over all (non system) dbs
    sp__script_run "%","select db_name()"
'

select @ret=-1
goto ret

-- =================================================================== errors ==
err_ems:    exec sp__err 'empty script',@proc                           goto ret

-- ===================================================================== exit ==
ret:
return @ret
end  -- proc sp__script_run