/*  leave this
    l:see LICENSE file
    g:utility
    todo: finish all tests and add more
    r:110213\s.zaglio: parse a formatted string date
    t:
        sp__parse_date 13,@dbg=1
        sp__parse_date '13 20.30',@dbg=1
        sp__parse_date -1,@dbg=1
        sp__parse_date '-1 00.00',@dbg=1
        sp__parse_date '-1 0',@dbg=1        -- todo: yersterday at midnight
        sp__parse_date '-1 0.0',@dbg=1        -- todo: yersterday at midnight
        sp__parse_date '-1 -1',@dbg=1        -- todo: yersterday one month ago
*/
create proc sp__parse_date
    @dates      nvarchar(64) = null,
    @date       datetime = null out,
    @lng        sysname = null,
    @dbg        int=0
as
begin
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)

-- ========================================================= param formal chk ==
if @dates is null goto help

-- ============================================================== declaration ==
declare
    @n int,@day int,@tk1 sysname,@tk2 sysname,@tk3 sysname,@tk4 sysname

-- =========================================================== initialization ==

-- ======================================================== second params chk ==

-- ===================================================================== body ==
if isnull(@lng,'')!=''
    begin
    set language @lng
    if @@error!=0 select @ret=-1
    if @ret!=0 goto ret
    end

if isdate(@dates)=1 begin select @date=convert(datetime,@dates) goto ret end
if isnumeric(@dates)=1
    begin
    select @day=convert(int,@dates)
    if @day>0
        begin
        select @date=getdate()
        select @date=@date-day(@date)+@day
        end
    else
        select @date=getdate()+@day
    goto dispose
    end

select @n=dbo.fn__str_count(@dates,'')
select @tk1=dbo.fn__str_at(@dates,'',1)
select @tk2=dbo.fn__str_at(@dates,'',2)
select @tk3=dbo.fn__str_at(@dates,'',3)
select @tk4=dbo.fn__str_at(@dates,'',4)
if isnumeric(@tk1)=1 and (charindex('.',@tk2)>0 or charindex(':',@tk2)>0)
    begin
    select @day=convert(int,@tk1)
    if @day>0
        begin
        select @date=getdate()
        select @date=@date-day(@date)+@day
        end
    else
        select @date=getdate()+@day
    select @dates=convert(sysname,@date,126)
    select @dates=substring(@dates,1,charindex('T',@dates))
    -- iso(126): yyyy-mm-ddThh:mm:ss.mmm
    select @tk2=replace(@tk2,'.',':')
    select @n=dbo.fn__str_count(@dates,':')
    if @n=1 select @tk2=@tk2+':00.000'
    select @dates=@dates+@tk2
    select @date=convert(datetime,@dates,126)
    goto dispose
    end -- day hour

dispose:
if @dbg=1 exec sp__printf 'dates=%s, date=%s, tk1=%s tk2=%s',@dates,@date,@tk1,@tk2

goto ret

-- =================================================================== errors ==

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    parse a formatted string date

Parameters
    @dates  date in string(input) format
    @date   the converted date
    @lng    language (default current; see set language or sys.syslanguages)
    return  a non zero value if an error

Examples
    value           convertion
    "full iso"      considered
    13              considered current day
    13 20.30        day 13 of current month/year, hour 20.30
    13 20:30        day 13 of current month/year, hour 20.30
    -1              today less one day
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__parse_date