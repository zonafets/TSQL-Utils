/*  leave this
    l:see LICENSE file
    g:utility
    v:120208\s.zaglio: added code comment
    v:120126\s.zaglio: used cscript
    v:110125\s.zaglio: exp buf of cmdline to 256 instead of 128
    v:100919.1110\s.zaglio: a remake because outof return space (4000chars limit)
    v:100919.1100\s.zaglio: more info about processes
    v:100119\s.zaglio: int->bigint
    v:100105\s.zaglio: list windows processes
    t:sp__util_os list
*/
CREATE proc [dbo].[sp__util_os]
    @cmd sysname=null,
    @opt sysname=null,
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0

-- if @dbg=1 select *,dbo.fn__str_at(@cmd,'',pos) at from fn__str_table(@cmd,'')

if @cmd is null
or not dbo.fn__str_at(@cmd,'',1) in ('kill','list')
    goto help

select @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

declare @list table (pos int,token nvarchar(4000))
declare
    @i int,@n int,@line nvarchar(4000),
    @vbs nvarchar(4000),@sql nvarchar(4000),
    @tmp nvarchar(4000),@pid bigint,
    @csep nchar(1),@rsep nchar(1),
    @out bit,
    @p1 sysname

declare @stdout table (lno int identity,line nvarchar(4000))
create table #src(lno int identity,line nvarchar(4000))
create table #tpl(lno int identity primary key,line nvarchar(4000))

select
    @p1=isnull(dbo.fn__str_at(@cmd,'',2),''),
    @cmd=dbo.fn__str_at(@cmd,'',1)

if @dbg=1 exec sp__printf 'cmd=%s   p1=%s',@cmd,@p1

select @csep='|',@rsep=char(13)

if object_id('tempdb..#osprocs') is null
    begin
    create table #osprocs (
        pid bigint,
        [name] sysname,
        kb bigint,
        nWrites bigint,
        KTime bigint,
        UTime bigint,
        CmdLine nvarchar(1024)
        )
    select @out=1
    end
else
    select @out=0

/*
In alternative can use the WMIC utility
WMIC PROCESS get Caption,Commandline,Processid /Format:list
WMIC PROCESS where name="cmd.exe" get processid,commandline /format:list
WMIC PROCESS where processid=??? delete
*/

insert #tpl(line) select line from fn__ntext_to_lines('
%kill%:
sub KillProcessTree(objWMIService,process)
''wscript.echo process.name, process.handle,
''"is a child of",process.parentprocessid
wql = "select * from win32_process " & _
      "where ParentProcessID=" & process.handle
set results = objWMIService.execquery(wql)
for each childProcess in results
KillProcessTree objWMIService,childProcess
next
process.terminate
end sub

strComputer = "."
strConn="winmgmts:"
''strConn= _
''    "winmgmts:" & _
''    "{impersonationLevel=impersonate,(debug)}!\\" & _
''    strComputer & "oot\cimv2" _

Set objWMIService = GetObject( strConn )

Set colProcessList = objWMIService.ExecQuery _
("Select * from Win32_Process Where handle = %pid%")

For Each objProcess in colProcessList
set rootProcess = objWMIService.get( _
    "win32_process.handle=" & objProcess.Handle _
    )
KillProcessTree objWMIService,rootProcess
Next
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%list%:
Dim obj, obj1 , row , sql, cmdl
sql="SELECT " & _
    "name,WorkingSetSize,WriteOperationCount," & _
    "KernelModeTime,UserModeTime,CommandLine " & _
    "FROM Win32_Process " & _
    "WHERE name like ''%name%%''"
For Each obj In GetObject("winmgmts:").ExecQuery(sql)
    row = obj.handle & "|" & _
          obj.name & "|" & _
          obj.WorkingSetSize & "|" & _
          obj.WriteOperationCount & "|" & _
          obj.KernelModeTime & "|" & _
          obj.UserModeTime
    cmdl = obj.handle & "|" & obj.CommandLine
    Wscript.StdOut.WriteLine row
    Wscript.StdOut.WriteLine cmdl
Next
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
',0)

if @cmd='list'
    -- sp__util_os 'list cmd'
    -- sp__util_os list
    exec sp__script_template '%list%',@opt='mix',@tokens='%name%',@v1=@p1
if @cmd='kill'
    begin
    -- sp__util_os 'kill 4984',@dbg=1
    if isnumeric(@p1)=1
        exec sp__script_template '%kill%',@opt='mix',
                                 @tokens='%pid%',@v1=@p1
    else
        goto err_pid
    end -- kill

if @dbg=1 select * from #src

select
    @vbs='%temp%\'+replace(cast(newid() as sysname),'-','_')+'.vbs',
    @line='cscript //T:60 //Nologo '+@vbs
    -- @line='cscript '+@vbs
exec sp__file_write_stream @vbs,@fmt='ascii'

insert @stdout exec xp_cmdshell @line

select @line='del '+@vbs
exec xp_cmdshell @line,no_output

select @line=null

select top 1 @line=line
from @stdout
where line like '%'+@vbs+'(%,%)%'
if not @line is null goto err_vbs

if @cmd='kill' goto ret

if @dbg=1
    select *
    from @stdout o
    cross apply fn__str_words(o.line,'|',default)
    where o.lno%2=1

-- out objects cols order is different from select
insert #osprocs(pid,name,kb,nwrites,ktime,utime)
select
    convert(bigint,c00) as pid,
    convert(sysname,c01) as name,
    convert(bigint,c02)/1024 as kb,
    convert(bigint,c03) as nwrites,
    convert(bigint,c04) as ktime,
    convert(bigint,c05) as utime
from @stdout o
cross apply fn__str_words(o.line,'|',default)
where o.lno%2=1

-- update with 2nd line : pid|cmdline
update p set
    cmdline=substring(o.line,charindex('|',o.line)+1,1024)
from #osprocs p
join @stdout o on p.pid=left(o.line,charindex('|',o.line)-1)
where o.lno%2=0

if @out=1
    begin
    select * from #osprocs
    where [name] like isnull(dbo.fn__str_at(@cmd,'',2)+'%','%')
    drop table #osprocs
    end
else
    delete from #osprocs
    where not [name] like isnull(dbo.fn__str_at(@cmd,'',2)+'%','%')

goto ret

-- =================================================================== errors ==
err_vbs:    exec @ret=sp__err '%s',@proc,@p1=@line goto ret
err_pid:    exec @ret=sp__err 'not numeric PID',@proc goto ret
/*
class Win32_Process : CIM_Process
{
  string   Caption;
  string   CommandLine;
  string   CreationClassName;
  datetime CreationDate;
  string   CSCreationClassName;
  string   CSName;
  string   Description;
  string   ExecutablePath;
  uint16   ExecutionState;
  string   Handle;
  uint32   HandleCount;
  datetime InstallDate;
  uint64   KernelModeTime;
  uint32   MaximumWorkingSetSize;
  uint32   MinimumWorkingSetSize;
  string   Name;
  string   OSCreationClassName;
  string   OSName;
  uint64   OtherOperationCount;
  uint64   OtherTransferCount;
  uint32   PageFaults;
  uint32   PageFileUsage;
  uint32   ParentProcessId;
  uint32   PeakPageFileUsage;
  uint64   PeakVirtualSize;
  uint32   PeakWorkingSetSize;
  uint32   Priority;
  uint64   PrivatePageCount;
  uint32   ProcessId;
  uint32   QuotaNonPagedPoolUsage;
  uint32   QuotaPagedPoolUsage;
  uint32   QuotaPeakNonPagedPoolUsage;
  uint32   QuotaPeakPagedPoolUsage;
  uint64   ReadOperationCount;
  uint64   ReadTransferCount;
  uint32   SessionId;
  string   Status;
  datetime TerminationDate;
  uint32   ThreadCount;
  uint64   UserModeTime;
  uint64   VirtualSize;
  string   WindowsVersion;
  uint64   WorkingSetSize;
  uint64   WriteOperationCount;
  uint64   WriteTransferCount;
};
*/
help:
exec sp__usage @proc,'
Scope
    List OS processes

Parameters
    @cmd        commands and parameters
        kill    PID
        list    [process]
                list processes
                if exists #osprocs, return in this table the processes info

                create table #osprocs (
                    pid bigint,[name] sysname,
                    kb bigint, nWrites bigint,
                    KTime bigint,
                    UTime bigint,
                    CmdLine nvarchar(1024)
                    )

Examples
    sp__util_os list smss
'

select @ret=-1

ret:
return @ret
end -- sp__util_os