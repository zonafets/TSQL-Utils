/*  leave this
    l:see LICENSE file
    g:utility,draw
    k:draw,circle,text,buffer
    v:120924\s.zaglio: draw a circle into a text buffer
    t:sp__circle 77
*/
CREATE proc sp__circle
    @r int = null,
    @x int = null,
    @y int = null,
    @buffer nvarchar(max) = null,
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    -- error vars
    @e_msg nvarchar(4000),              -- message error
    @e_opt nvarchar(4000),              -- error option
    @e_p1  sql_variant,
    @e_p2  sql_variant,
    @e_p3  sql_variant,
    @e_p4  sql_variant

select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
declare
    -- generic common
    -- @i int,@n int,                      -- index, counter
    -- @sql nvarchar(max),                 -- dynamic sql
    -- options
    -- @opt1 bit,@opt2 bit,
    @i int,@j int,
    @crlf varchar(2),
    @diff int,
    @out bit,
    @end_declare bit

-- =========================================================== initialization ==
select
    -- @opt1=charindex('|opt|',@opt),
    @out=case when @buffer is null then 1 else 0 end,
    @buffer=isnull(@buffer,''),
    @crlf=crlf,
    @end_declare=1
from fn__sym()

-- ======================================================== second params chk ==
if @r is null -- @opt='||'
    goto help

-- ===================================================================== body ==

select @i=-@r
while @i<=@r
    begin
    select @j=-@r
    while @j<=@r
        begin
        select @diff=round(sqrt(@i*@i+@j*@j)-@r,0)
        select @buffer=@buffer+case @diff when 0 then '*' else ' ' end+' '
        select @j=@j+1
        end -- j
    select @buffer=@buffer+@crlf,@i=@i+1
    end -- i

if @out=1 exec sp__printsql @buffer

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- =================================================================== errors ==
/*
err:        exec @ret=sp__err @e_msg,@proc,@p1=@e_p1,@p2=@e_p2,@p3=@e_p3,
                              @p4=@e_p4,@opt=@e_opt                     goto ret

err_me1:    select @e_msg='write here msg'                              goto err
err_me2:    select @e_msg='write this %s',@e_p1=@var                    goto err
*/
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    draw a circle into buffer or video

Parameters
    @r      radius
    @x,@y   center (TODO)
    @buffer predefined @buffer
    @opt    options (not used)

Examples
    exec sp__circle 7
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__circle