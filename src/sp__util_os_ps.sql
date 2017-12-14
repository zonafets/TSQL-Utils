/*  leave this
    l:see LICENSE file
    g:utility
    k:process,status,list
    v:131209\s.zaglio: list os processes using wmi
    t:sp__util_os_ps '%',@dbg=1
*/
CREATE proc sp__util_os_ps
    @name sysname = null,
    @opt sysname = null,
    @dbg int=0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
-- @@nestlevel is >1 if called by other sp (not correct if called by remote sp)

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
    @tmp nvarchar(512),
    @cmd nvarchar(4000),
    @txt nvarchar(max),
    @sql nvarchar(max),
    @cols sysname,
    @i int,
    @crlf nvarchar(2),
    @osprocs_id int

-- =========================================================== initialization ==

exec sp__get_temp_dir @tmp out,@opt='tf'

select
    @tmp=@tmp+'.txt',
    @crlf=crlf,
    @osprocs_id=isnull(object_id('tempdb..#osprocs'),0)
from fn__sym()

-- ======================================================== second params chk ==

if @name is null goto help

-- =============================================================== #tbls init ==

declare @src table(lno int identity primary key,line nvarchar(4000))
declare @osprocs table(
    pid bigint, [name] sysname null,
    kb bigint null, nWrites bigint null,
    KTime bigint null, UTime bigint null,
    CmdLine nvarchar(1024) null
    )

-- ===================================================================== body ==

-- http://msdn.microsoft.com/en-us/library/aa394372(v=vs.85).aspx
-- get * or nothing for all
-- the list output follow the alphabetic order
select @cols='Caption,Handle,CommandLine,Name,KernelModeTime,UserModeTime,'
            +'WorkingSetSize,WriteOperationCount'
select @cmd='wmic /output:"'+@tmp+'" process get '+@cols+' /format:value'

if @dbg=0
    exec xp_cmdshell @cmd,no_output
else
    begin
    exec sp__printf '%s',@cmd
    exec xp_cmdshell @cmd
    end
select @sql='select @txt=BulkColumn '
           +'from openrowset(bulk '''+@tmp+''',  single_nclob) as x'
if @dbg>0 exec sp__printsql @sql
exec sp_executesql @sql,N'@txt nvarchar(max) out',@txt=@txt out
if @dbg>0 exec sp__printsql @txt
select @cmd='del /f /q "'+@tmp+'"'
exec xp_cmdshell @cmd,no_output

insert @src(line) select line from fn__ntext_to_lines(@txt,0)

-- t:sp__util_os_ps '%',@dbg=1

;with
var_val as (
    select
        lno,
        left(line,charindex('=',line)-1) as [var],
        substring(line,charindex('=',line)+1,len(line)) as [val]
    from @src
    where line!=''
),
hdr as (
    select
        row_number() over(partition by 1 order by lno) as row,*
    from var_val
    where [var]='caption'
),
maxlno as (
    select max(lno) as mlno from @src
),
range as (
    select
        row_number() over(partition by 1 order by (select 1)) as gid,
        h1.lno llno,isnull(h2.lno-1,mlno) rlno
    from maxlno,hdr h1
    left join hdr h2
    on h1.row+1=h2.row
    ),
vals as (
    select b.gid,a.*
    from var_val a
    join range b on a.lno between b.llno and b.rlno
    ),
Handle as (
    select gid,val as handle
    from vals
    where [var]='handle'
    ),
Name as (
    select gid,val as Name
    from vals
    where [var]='name'
    ),
CommandLine as (
    select gid,left(val,1024) as CommandLine
    from vals
    where [var]='CommandLine'
    ),
KernelModeTime as (
    select gid,val as KernelModeTime
    from vals
    where [var]='KernelModeTime'
    ),
UserModeTime as (
    select gid,val as UserModeTime
    from vals
    where [var]='UserModeTime'
    ),
WorkingSetSize as (
    select gid,val as WorkingSetSize
    from vals
    where [var]='WorkingSetSize'
    ),
WriteOperationCount as (
    select gid,val as WriteOperationCount
    from vals
    where [var]='WriteOperationCount'
    )
insert @osprocs(
    pid,name,cmdline,
    KTime,UTime,
    kb,nWrites
)
select
    handle,name,commandline,
    KernelModeTime,UserModeTime,
    WorkingSetSize,WriteOperationCount
from handle
join name on handle.gid=name.gid
join commandline on handle.gid=commandline.gid
join KernelModeTime on handle.gid=KernelModeTime.gid
join UserModeTime on handle.gid=UserModeTime.gid
join WorkingSetSize on handle.gid=WorkingSetSize.gid
join WriteOperationCount on handle.gid=WriteOperationCount.gid
where name like @name

if @osprocs_id=0
    select * from @osprocs
else
    insert #osprocs select * from @osprocs

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    List OS processes with info.

Notes
    - called by sp__util_os
    - maybe compatible with all present and future version of Windows
      starting from XP (probably SP 3 and above)

Parameters
    [param]     [desc]
    @name       like expression over name
    #osprocs    returned table if exists
                create table #osprocs (
                    pid bigint,[name] sysname,
                    kb bigint, nWrites bigint,
                    KTime bigint,
                    UTime bigint,
                    CmdLine nvarchar(1024)
                    )
    @opt        options
    @dbg        1=last most importanti info/show code without execute it
                2=more up level details
                3=more up ...

Examples
    sp__util_os_ps "%"
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
end catch   -- proc sp__util_os_ps