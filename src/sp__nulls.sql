/*  leave this
    l:see LICENSE file
    g:utility
    v:110213\s.zaglio: nullize the parameters
    t:
        declare @v sysname,@i int,@r real,@d datetime
        select @v='',@i=0,@d=0,@r=0.0
        exec sp__nulls @v out,@i out,@d out,@r out
        print isnull(@v,'(null)')
        print isnull(@i,0)
        print isnull(@r,0)
        print isnull(@d,0)
*/
create proc sp__nulls
    @v0 nvarchar(4000) = null out,
    @v1 nvarchar(4000) = null out,
    @v2 nvarchar(4000) = null out,
    @v3 nvarchar(4000) = null out,
    @v4 nvarchar(4000) = null out,
    @v5 nvarchar(4000) = null out,
    @v6 nvarchar(4000) = null out,
    @v7 nvarchar(4000) = null out,
    @v8 nvarchar(4000) = null out,
    @v9 nvarchar(4000) = null out,
    @dbg int=0
as
begin
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)

-- ========================================================= param formal chk ==
exec @ret=sp__chknulls @v0,@v1,@v2,@v3,@v4,@v5,@v6,@v7,@v8,@v9
if @ret=1 goto help

-- ============================================================== declaration ==
declare @d0 sysname
-- =========================================================== initialization ==
-- ======================================================== second params chk ==

-- ===================================================================== body ==
select @d0=convert(sysname,convert(datetime,0))

if isdate(@v0)=1 select @v0=convert(sysname,convert(datetime,@v0))
if @v0 in ('','0',@d0) select @v0=null

if isdate(@v1)=1 select @v1=convert(sysname,convert(datetime,@v1))
if @v1 in ('','0',@d0) select @v1=null

if isdate(@v2)=1 select @v2=convert(sysname,convert(datetime,@v2))
if @v2 in ('','0',@d0) select @v2=null

if isdate(@v3)=1 select @v3=convert(sysname,convert(datetime,@v3))
if @v3 in ('','0',@d0) select @v3=null

if isdate(@v4)=1 select @v4=convert(sysname,convert(datetime,@v4))
if @v4 in ('','0',@d0) select @v4=null

if isdate(@v5)=1 select @v5=convert(sysname,convert(datetime,@v5))
if @v5 in ('','0',@d0) select @v5=null

if isdate(@v6)=1 select @v6=convert(sysname,convert(datetime,@v6))
if @v6 in ('','0',@d0) select @v6=null

if isdate(@v7)=1 select @v7=convert(sysname,convert(datetime,@v7))
if @v7 in ('','0',@d0) select @v7=null

if isdate(@v8)=1 select @v8=convert(sysname,convert(datetime,@v8))
if @v8 in ('','0',@d0) select @v8=null

if isdate(@v9)=1 select @v9=convert(sysname,convert(datetime,@v9))
if @v9 in ('','0',@d0) select @v9=null

goto ret

-- =================================================================== errors ==

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    nullize the parameters if:
    "" in strings,0 in numbers and dates

Examples
    declare @v sysname,@i int,@r real,@d datetime
    select @v='',@i=0,@d=0,@r=0.0
    exec sp__nulls @v out,@i out,@d out,@r out
    print isnull(@v,''(null)'')
    print isnull(@i,0)
    print isnull(@r,0)
    print isnull(@d,0)
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__nulls