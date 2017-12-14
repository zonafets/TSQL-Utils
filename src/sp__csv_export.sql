/*  leave this
    l:see LICENSE file
    g:utility
    k:export,csv
    v:151106\s.zaglio: added collate database_default
    v:121118.1800\s.zaglio: a bug when #obj
    v:121117\s.zaglio: export a tbl/view to csv file
    t:exec sp__csv_export 'cfg','c:\temp\tbl.csv',@dbg=1
*/
CREATE proc sp__csv_export
    @obj sysname = null,
    @path nvarchar(1024) = null,
    @where sysname = null,
    @opt sysname = null,
    @dbg int=0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp

declare
    @proc sysname, @err int, @ret int  -- @ret: 0=OK -1=HELP, any=error id

-- ======================================================== params set/adjust ==

select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=nullif(@opt,''),
    @opt=case when @opt is null then '||' else dbo.fn__str_quote(@opt,'|') end,
    @where=replace(nullif(@where,''),'"',''''),
    @path=nullif(@path,'')

-- ============================================================== declaration ==
declare
    -- generic common
    -- @i int,@n int,                   -- index, counter
    @sql nvarchar(max),                 -- dynamic sql
    @flds nvarchar(4000),
    -- options
    @noq bit,                           -- no quotes
    @noh bit,                           -- no header
    @crlf nvarchar(2),
    @cn nvarchar(128),
    @temp nvarchar(4000),               -- temp path
    @line nvarchar(4000),
    @out bit,
    @obj_id int,
    @psep nchar(1),                     -- path separator
    @dt datetime,
    @end_declare bit

declare @cols table(
    pos int,col sysname,
    last bit,
    cc nvarchar(4000),                  -- convert cmd
    hdr sysname null,
    ct sysname null,                    -- column type
    cs nvarchar(4)                      -- convert style
    )

-- =========================================================== initialization ==
exec sp__get_temp_dir @temp out

select
    @dt=getdate(),
    @noq=charindex('|noq|',@opt),
    @noh=charindex('|noh|',@opt),
    @crlf=crlf,
    @path=replace(@path,'%temp%',@temp),
    -- sp__format
    @path=replace(@path,'%dt%',dbo.fn__format(@dt,'yyyymmdd_hhmmss',default)),
    @path=replace(@path,'%yyyymmdd%',convert(sysname,@dt,112)),
    @path=replace(@path,'%yymmdd%',convert(sysname,@dt,12)),
    @path=replace(@path,'%hhmmss%',dbo.fn__format(@dt,'hhmmss',default)),
    @path=replace(@path,'%hhmm%',dbo.fn__format(@dt,'hhmm',default)),
    @out=isnull(object_id('tempdb..#out'),0),
    @obj_id=isnull(object_id(case when left(@obj,1)='#'
                             then 'tempdb..'+@obj
                             else @obj
                             end),0),
    @end_declare=1
-- select *
from fn__sym()

-- ======================================================== second params chk ==
if @obj is null and @path is null goto help

if @out=0
    create table #out(lno int identity primary key,line nvarchar(4000))

-- ===================================================================== body ==

if @obj_id=0 and @out=0     raiserror('object "%s" not found',16,1,@obj)
if @path is null and @out=0 raiserror('path not specified',16,1)
if right(@path,1)=@psep     raiserror('path without file name',16,1)
if @path is null and @obj_id=0 and @out=1
                            raiserror('path or obj must specified',16,1)

if @obj_id=0 goto file_write

exec sp__flds_list @flds out,@obj

if @flds is null raiserror('no fields found for specified table',16,1)

insert @cols(pos,col)
select pos,token
from dbo.fn__str_table(@flds,'|')

update c set
    ct=token,
    cs=case when token like '%date%' collate database_default then ',126' else ',0' end
from @cols c
join dbo.fn__str_table(dbo.fn__flds_type_of(@obj,',',null),',') t
on c.pos=t.pos

select @cn='convert(nvarchar(4000),isnull('
update @cols set last=1 where pos=(select max(pos) from @cols)

update @cols
set cc =case @noq when 1 then '' else '''"''+' end
       +case @noq when 1
        then @cn+col+','''')'+cs+')'
        else 'replace('+@cn+col+','''')'+cs+'),''"'',''""'')'
        end
       +case @noq when 1 then '' else '+''"''' end,
    hdr=case @noq when 1 then '' else '"' end
       +case @noq when 1
        then parsename(col,1)
        else replace(parsename(col,1),'"','""')
        end
       +case @noq when 1 then '' else '"' end

if @dbg=1 select * from @cols

if @noh=0
    begin
    select @line=null
    select @line=isnull(@line+',','')+hdr from @cols
    insert #out(line) select @line
    end -- header

-- compound the select
select @sql =isnull(@sql+'+'',''+'+@crlf,'')+cc
from @cols
order by pos

if @sql is null raiserror('bad inside code generation',16,1)

select @sql ='insert #out(line)'+@crlf
            +'select '+@crlf
            +@sql
            +@crlf+'as line '
            +@crlf+'from ['+@obj+'] '+@crlf
            +case when not @where is null
             then 'where '+@where
             else ''
             end

if @dbg>0 exec sp__printsql @sql

exec(@sql)
/*
drop table #out
sp__csv_export 'cfg' -- error test
create table #out(lno int identity primary key,line nvarchar(4000))
select * into #cfg from cfg -- select * from #cfg
truncate table #out exec sp__csv_export '#cfg',@opt='noh' select * from #out
sp__csv_export @path='%temp%\text.txt'

sp__csv_export 'cfg',@path='%temp%\text.txt',@where='[key] like "%"',@dbg=1
xp_cmdshell 'type %temp%\text.txt'
xp_cmdshell 'del %temp%\text.txt'
*/

file_write:
if @dbg>0 select @path,* from #out
if not @path is null
    exec @ret=sp__file_write_stream @path,@fmt='ascii',@opt='out'

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.
if @out=0 drop table #out
goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    export an object(table or view) to a text file, formatted as CSV
    (Comma Separated Values).

Notes
    when a comma is present in the value, automatically will be quoted "";
    when a " is present in the value, automatically will be doubled;
    default export format is ASCII

Parameters
    @obj    name of object to export; can be a #tbl
    @path   path of destination file; supporto macros:
            %temp%      value of cmd line environment
            %DT%        same of YYYYMMDD_HHMMSS
            %YYYYMMDD%  year month day
            %YYMMDD%    year month day
            %HHMMSS%    hour minutes seconds
            %HHMM%      hour minutes
    #out    if @path is null, insert lines into #out
            if @path is valued and @obj is null, save #out to @path
            create table #out(lno int identity primary key,line nvarchar(4000))
    @where  optional condition for @obj
    @opt    options
            noq     suppress quotes " around the value of each field
                    (if value will contain a , will cause a bad input)
            noh     suppress export of 1st line containing column names

Examples
    exec %proc% "tbl","%temp%\tbl.csv"
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end try
-- =================================================================== errors ==
begin catch
exec @ret=sp__err @cod=@proc,@opt='ex'
return @ret
end catch   -- proc sp__csv_export