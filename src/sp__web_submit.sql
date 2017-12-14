/*  leave this
    l:see LICENSE file
    g:utility
    k:form, post, submit, simulate, simulation
    v:120905\s.zaglio: removed dbg info
    v:120830.1000\s.zaglio: submit html form
*/
CREATE proc sp__web_submit
    @url varchar(4000) = null,
    @params varchar(4000) = null,
    @ResponseText nvarchar(4000) = null out,    -- NO vcMAX!
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
    @proc sysname, @err int, @ret int -- @ret: 0=OK -1=HELP, any=error id
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
select
    @url=isnull(@url,''),
    @params=isnull(@params,'')

if (@url='' or @params ='') -- and @opt='||'
    goto help

-- ============================================================== declaration ==
declare
    @obj int,
    @hr int,
    @src varchar(1000),
    @desc varchar(1000),
    @cmd varchar(128)

-- =========================================================== initialization ==
-- select -- insert before here --  @end_declare=1
-- ======================================================== second params chk ==
-- ===================================================================== body ==

if @dbg=1 exec sp__printf '-- url:%s\n-- p:%s',@url,@params

select @cmd='Msxml2.ServerXMLHTTP.3.0'
exec @hr = sp_oaCreate @cmd, @obj OUTPUT
if @hr!=0 goto err_ole

select @cmd='Open'
exec @hr = sp_OAMethod @obj, @cmd, null, 'POST',@url, 0
if @hr!=0 goto err_ole

select @cmd='setRequestHeader'
exec @hr = sp_OAMethod @obj, @cmd, null,
                             'Content-Type',
                             'application/x-www-form-urlencoded'
if @hr!=0 goto err_ole

select @cmd='send'
exec @hr = sp_OAMethod @obj, @cmd, null, @params
if @hr!=0 goto err_ole

select @cmd='responseText'
exec @hr = sp_OAGetProperty @obj, @cmd, @ResponseText OUT
if @hr!=0 goto err_ole

-- Destroy the object
dispose:
exec @hr = sp_OADestroy @obj
select @obj=null

goto ret

-- =================================================================== errors ==
err_ole:
exec sp_OAGetErrorInfo @obj, @src OUT, @desc OUT
exec @ret=sp__err '"%s" in "%s" for OLE cmd %s',@proc,
                  @p1=@desc,@p2=@src,@p3=@cmd
goto dispose

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    submit html form

Parameters
    @url            target address (tipical ACTION tag)
    @params         form parameters (tipical INPUT tag):
                    param1=val1&param2=val2&param3=...
    @ResponseText   the returned html/text
    @opt            options (not used)
    @dbg            debug
                    1 print some info

Examples
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__web_submit