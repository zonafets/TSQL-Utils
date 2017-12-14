/*  leave this
    l:see LICENSE file
    g:utility
    v:131017\s.zaglio: test the sp__file_write_blob
*/
CREATE proc sp__file_write_blob_test
    @size int = null,
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
    -- generic common
    @huge bit,@small bit,@big bit,@d datetime

-- =========================================================== initialization ==
select
    -- @sel=charindex('|sel|',@opt),@print=charindex('|print|',@opt),
    @huge=charindex('|huge|',@opt),
    @small=charindex('|small|',@opt),@big=charindex('|big|',@opt)

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
if cast(@huge as int)+@small+@big>1 raiserror('please give only one option',16,1)
if @size is null and cast(@huge as int)+@small+@big=0 goto help

-- =============================================================== #tbls init ==

-- ===================================================================== body ==

declare @v varbinary(max)

if @small=1 select @size=3998
if @big=1 select @size=11998
if @huge=1 select @size=200000000

exec sp__elapsed @d out,'Begin test'
select @v=cast(
            'a'+replicate(cast('b' as varchar(max)),@size)+
            'z' as varbinary(max))
select @size=len(@v)
exec sp__elapsed @d out,'after generating blob a...z of %d bytes',@v1=@size

exec sp__file_write_blob
        @file='%temp%\sp__file_write_blob_test.txt',
        @blob=@v

exec sp__elapsed @d out,'after write'

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    test sp__file_write_blob, writing a huge text file (2gb)
    to %temp%\sp__file_write_blob_test.txt

Parameters
    [param]     [desc]
    @size       dynamic number of bytes to test
    @opt        options
                small   test a 4000 bytes blob
                big     test a 12000 bytes blob
                huge    test a 2.000.000.002 bytes blob
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
end try

-- =================================================================== errors ==
begin catch
-- if @@trancount > 0 rollback -- for nested trans see style "procwnt"

exec @ret=sp__err @cod=@proc,@opt='ex'
return @ret
end catch   -- proc sp__file_write_blob_test