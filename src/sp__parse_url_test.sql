/*  leave this
    l:see LICENSE file
    g:utility
    k:url,uri,parse,path,web,internet
    v:130906.1000\s.zaglio: test and show use of fn__parse_url
    t:sp__parse_url_test
*/
CREATE proc sp__parse_url_test
    @opt sysname = null,
    @dbg int=0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
-- @@nestlevel is >1 if called by other sp

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
declare @urls table(url sysname)
declare @url sysname
-- =========================================================== initialization ==
insert @urls
-- select 'protocol://<username:password@>nomehost<:port></path><?querystring>' union
select 'svn://lupin/SOURCES\*.vb' union
select 'file:///C:/Documents%20and%20Settings/ste...' union
select 'file://///svr/share/dir/sdir/file.ext' union
select 'file://svr/share/dir/sdir/file.ext' union
select 'https://sap.mymeetingroom.com/?content...' union
select 'http://maps.google.com/maps/api/geocode/xml?sensor=false&address=8+soratino,+italy' union
select 'https//sap.mymeetingroom.com/?content...' union
select 'ftp://pwd:usr@site.org' union
select '\\svr\share\dir\file.ext' union
select '\\pwd:uid@svr\share\dir\file.ext' union
select 'c:\share\dir\file.ext'

-- ======================================================== second params chk ==
-- =============================================================== #tbls init ==

select top 0 cast(null as sysname) status,*
into #tmp
from dbo.fn__parse_url('',default)

-- ===================================================================== body ==

declare cs cursor local for select url from @urls
open cs
while 1=1
    begin
    fetch next from cs into @url
    if @@fetch_status!=0 break
    begin try
    insert #tmp select 'ok',* from fn__parse_url(@url,default)
    end try
    begin catch
    insert #tmp(status,url) select 'ko:'+error_message(),@url
    end catch
    end -- cursor cs
close cs
deallocate cs

update #tmp set status='ko' where normalized is null

select * from #tmp order by status
-- ================================================================== dispose ==
dispose:
drop table #tmp

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    test fn__parse_url

Parameters
    [param]     [desc]
    @opt        options (not used)
    @dbg        not used
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
end catch   -- proc sp__parseurl_test