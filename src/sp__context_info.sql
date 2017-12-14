/*  leave this
    l:see LICENSE file
    g:utility
    v:120724\s.zaglio:changed structure
    v:111205\s.zaglio:set and reset context info
    t:sp__context_info @opt='reset'
    t:sp__context_info 'test',@dbg=1    -- d15f
    t:sp__context_info 'test1',@dbg=1   -- 5310
    t:sp__context_info 'test',@opt='del',@dbg=1
    t:select dbo.fn__context_info('test'),dbo.fn__context_info('test1')
    t:select dbo.fn__context_info('test2')
*/
CREATE proc sp__context_info
    @val sysname = null,
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
if @val is null and @opt='||' goto help

-- ============================================================== declaration ==
declare
    @i      int,
    @l      int,
    @j      int,                        --
    @info   varchar(256),
    @cinfo  varbinary(128),
    @code   binary(2),@tcode binary(2), -- temporary code
    @del    bit                         -- del option
-- =========================================================== initialization ==
select
    @cinfo= isnull(context_info(),0),
    @del  = charindex('|del|',@opt),
    @code = dbo.fn__crc16(@val)

-- ======================================================== second params chk ==
if charindex('|reset|',@opt)>0
    begin
    select @cinfo=0
    set context_info @cinfo
    goto ret
    end

-- ===================================================================== body ==
-- scan cinfo and add or delete
select @i=1,@l=len(@cinfo),@j=0
while (@i<@l)
    begin
    if @j=0 and substring(@cinfo,@i,2)=0 select @j=@i
    if substring(@cinfo,@i,2)=@code break
    select @i=@i+2
    end

if @del=1 select @code=0
if @i<@l select @j=@i
select @cinfo=substring(@cinfo,1,@j-1)+@code+substring(@cinfo,@j+2,128)
set context_info @cinfo
if @dbg>0 print dbo.fn__hex(@cinfo)

dispose:
goto ret

-- =================================================================== errors ==
err_len:    exec @ret=sp__err 'context info is full',@proc
            goto ret
-- ===================================================================== help ==
help:
select @info=dbo.fn__hex(context_info())

exec sp__usage @proc,'
Scope
    add or remove value to the process context info

Notes
    fn__context_info return the position if exists of zero.
    The position remain until somebody not delete and reinsert the value.

Parameters
    @val    string to codify and add to context info
    @opt    options
            del     remove the @val from context info
            reset   clean all context info

Examples
    exec sp__context_info "test"
    print dbo.fn__context_info("test")

-- Corrent context info is --
%p1%
',@p1=@info
select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__context_info