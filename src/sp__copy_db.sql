/*  leave this
    l:see LICENSE file
    g:utility
    v:120612\s.zaglio: added errors test and run option
    v:110324\s.zaglio: modern version
    v:100119\s.zaglio: do a backup and restore together
    t:sp__copy_db 'test',@opt='tmp:d:\',@dbg=1
*/
CREATE proc sp__copy_db
    @to sysname=null,
    @from sysname=null,
    @opt sysname=1,
    @dbg bit=0
as
begin
declare @proc sysname,@ret int
select  @proc=object_name(@@procid),@ret=0,
        @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

declare @i int,@j int,@dev nvarchar(1024),@t datetime,@simul bit

if @to is null goto help
if @from is null select @from=db_name()

select @opt=replace(@opt,'|run|','|doit|')   -- compatible with old ver.
select @dev='%temp%'
select @i=charindex('|tmp:',@opt)+5,@j=charindex('|',@opt,@i)
if @dbg=1 exec sp__printf '@opt=%s i=%d, j=%d',@opt,@i,@j
if @i>5
    select @dev =substring(@opt,@i,@j-@i)
                +'%db%_%t%.bak'

if @dbg=1 exec sp__printf 'dev=%s',@dev

exec sp__elapsed @t out,'init'
exec @ret=sp__backup @dev out,@from,@opt=@opt
if @ret=0
    begin
    exec sp__elapsed @t out,'after backup'
    exec sp__restore @to,@dev,@opt=@opt
    exec sp__elapsed @t out,'after restore'
    end

goto ret

-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    duplicate a database into same server

Parameters
    @to     destination name (if not exists, will be created)
    @from   source db; if not specified current is used
    @opt    options
            run     secure code, disable default simulation
            tmp:??  uses ?? as alternative path that has more
                    free disk space

Examples
    sp__copy_db ''test'' -- copy this db to TEST db
'
select @ret=-1

ret:
return @ret
end -- sp__copy_db