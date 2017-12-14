/*  leave this
    l:see LICENSE file
    g:utility
    k:sp__err,test,old,style,new,style,try,catch
    r:130927\s.zaglio: test sp__err in various conditions
*/
CREATE proc sp__err_test
    @opt sysname = null,
    @dbg int=0
as
begin
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
-- =========================================================== initialization ==
-- ======================================================== second params chk ==
-- =============================================================== #tbls init ==
-- ===================================================================== body ==

select @ret=dbo.fn__crc32('exception')
exec sp__printf '-- "exception" error code:%d',@ret

exec sp__printf '-- 1) test new try-catch style with back compatibility'
begin try
raiserror('this is the raised error (the line position is correct)',16,1)
end try
begin catch
exec @ret=sp__err @cod=@proc,@opt='ex'
exec sp__printf 'returned code:%d',@ret
end catch

exec sp__printf '-- 2) test new try-catch style with redefined message'
begin try
raiserror('this is the error',16,1)
end try
begin catch
exec @ret=sp__err 'redefined message with %d param',@proc,@p1='one',@opt='ex'
exec sp__printf 'returned code:%d',@ret
end catch

exec sp__printf '-- 3) test new try-catch style with "error" strip'
begin try
select @err_msg='redefined message with %d param'
exec @ret=sp__err @err_msg out,@proc,@p1='A',@opt='noerr'
exec sp__printf 'raising:%s',@err_msg
raiserror(@err_msg,16,1)
end try
begin catch
exec @ret=sp__err @cod=@proc,@opt='ex'
exec sp__printf 'returned code:%d',@ret
end catch

exec sp__printf '-- 4) inner try'
begin try
    begin try
    select @err_msg='redefined message with %d param'
    exec @ret=sp__err @err_msg out,@proc,@p1='A',@opt='noerr'
    exec sp__printf 'raising:%s',@err_msg
    raiserror(@err_msg,16,1)
    end try
    begin catch
    exec @ret=sp__err @cod=@proc,@opt='ex'
    exec sp__printf 'returned code:%d',@ret
    end catch
end try
begin catch
end catch

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    [write here a short desc]

Parameters
    [param]     [desc]
    @opt        options
    @dbg        1=last most importanti info/show code without execute it
                2=more up level details
                3=more up ...

Examples
    [example]
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end -- proc sp__err_test