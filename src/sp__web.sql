/*  leave this
    l:see LICENSE file
    g:utility,web
    k:soap,web,service,webservice,call,xml,get,pos,send
    v:130927.1800\s.zaglio: added integrated authentication and refactor of errors
    v:121022.1213\s.zaglio: removed ext.ns, now is optional and a bug
    v:121019\s.zaglio: done and tested
    r:121018\s.zaglio: smart soap call and decode
    d:121018\s.zaglio: sp__web_get
    r:121017\s.zaglio: normalized @rcq (cr,lf,tab)
    r:121016\s.zaglio: testing for bad requests
    r:121015\s.zaglio: get/set a web resource or call a webservice
    t:sp__web_test 1
*/
CREATE proc sp__web
    @uri varchar(2000) = null,
    @method varchar(2000) = null,
    @ctype nvarchar(255) = null,
    @rcq nvarchar(max) = null,
    @sa nvarchar(255) = null,
    @uid varchar(100) = null, -- Domain\UserName or UserName
    @pwd varchar(100) = null,
    @rsp nvarchar(max) = null out,
    @sts nvarchar(4000) = null out,
    @opt nvarchar(255) = null,
    @dbg int=0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp

/*
    a mixed evolution of:
    from http://www.vishalseth.com/post/2009/12/22/
         Call-a-webservice-from-TSQL-%28Stored-Procedure%29-using-MSXML.aspx
    and  https://sourceforge.net/projects/sqldom/
*/

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
    @opt=case when @opt is null then '||' else dbo.fn__str_quote(@opt,'|') end

-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
declare
    -- generic common
    @i int,@n int,                          -- index, counter
    -- @sql nvarchar(max),                  -- dynamic sql
    -- options
    @nodecode bit,@oxml bit,@soap bit,
    @ia bit,                                -- integrated autentication
    @to_resolve int, @to_connect int,       -- timeouts
    @to_send int, @to_receive int,
    @crlf varchar(2),@cr char(1),@lf char(1),@tab char(1),
    @oid int,@hr int,@cmd varchar(255),
    @len int,@hs_id int,
    @sa_ns nvarchar(1024),
    @soap_exception sysname,
    @params nvarchar(max),
    @rcqprms_id int,                        -- if params given
    @rcqhdrs_id int,                        -- if more headers given
    @hre char(2),                           -- common API error
    @end_declare bit

declare @blob table(blob nvarchar(max))
declare @utf table(utf sysname)

-- =========================================================== initialization ==
select
    @hre='hr',
    @sts=null,@rsp=null,            -- empy for sureness
    @soap_exception='<faultstring>System.Web.Services.Protocols.SoapException:',
    @nodecode=charindex('|nodecode|',@opt),
    @oxml=charindex('|oxml|',@opt),
    @ia=charindex('|ia|',@opt),
    @crlf=crlf,@cr=cr,@lf=@lf,@tab=tab,
    @rcqprms_id=isnull(object_id('tempdb..#rcqprms'),0),
    @rcqhdrs_id=isnull(object_id('tempdb..#rcqhdrs'),0),
    @end_declare=1
from fn__sym()

insert @utf select N'<?xml version="1.0" encoding="utf-8"?>'
insert @utf select N'<?xml version="1.0" encoding="utf-16"?>'
-- ======================================================== second params chk ==
if isnull(@uri,'')='' goto help

-- ===================================================================== body ==

-- timeouts
if charindex('|to:',@opt)>0
    begin
    -- sp__web 'test',@opt='to:1000,1000,1000',@dbg=1
    select
        @to_resolve=case pos when 1 then token else @to_resolve end,
        @to_connect=case pos when 2 then token else @to_connect end,
        @to_send   =case pos when 3 then token else @to_send    end,
        @to_receive=case pos when 4 then token else @to_receive end
    from dbo.fn__str_table(dbo.fn__str_between(@opt,'to:','|',default),',')
    if @dbg=1 exec sp__printf '-- to:%d,%d,%d,%d',
                              @to_resolve,@to_connect,@to_send,@to_receive
    if not coalesce(@to_resolve,@to_connect,@to_send,@to_receive) is null
    and (@to_resolve is null or @to_connect is null or
         @to_send is null or @to_receive is null)
        raiserror('all timeouts must be specified',16,1)
    end -- timeouts

if isnull(@sa,'')=''
    select
        @ctype=isnull(@ctype,'text/http'),
        @method=isnull(@method,'GET')
else
    select
        @ctype=isnull(@ctype,'text/xml;charset=UTF-8'),
        @method=isnull(@method,'POST')


-- create ole
select @cmd='MSXML2.ServerXMLHTTP'
exec @hr = sp_oacreate @cmd, @oid out
IF @hr!=0 raiserror(@hre,16,1)

/*  note:
    exec @hr=sp_oacreate 'winhttp.winhttprequest.5.1',@@oid out
    look work well too but do not remembere what limit has
    need a search on internet
*/

-- set timeouts
if not @to_resolve is null
    begin
    select @cmd='setTimeouts'
    exec @hr = sp_OAMethod @oid, @cmd, null,
                           @to_resolve,@to_connect,@to_send,@to_receive
    IF @hr!=0 raiserror(@hre,16,1)
    end

-- open the destination URI with Specified method
select @cmd='open'
if @ia=0
    exec @hr = sp_OAMethod @oid, @cmd, null, @method, @uri, 'false', @uid, @pwd
else
    exec @hr = sp_OAMethod @oid, @cmd, null, @method, @uri, 'false'
IF @hr!=0 raiserror(@hre,16,1)

-- set request headers
select @cmd='setRequestHeader'
exec @hr = sp_OAMethod @oid, @cmd, null, 'Content-Type', @ctype
IF @hr!=0 raiserror(@hre,16,1)

-- send the request
if @rcqprms_id!=0
    begin
    if not @rcq is null
        raiserror('#rcqprms and @rcq cannot be used together',16,1)
    if isnull(@sa,'')='' raiserror('missing SOAP Action',16,1)
    select @rcq='<?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema">'
    +case @ia when 0 then '' else '
    <soap:Header>
    <Auth user="%uid%" pass="%pwd%" xmlns="%sa_ns%" />
    </soap:Header>'
    end+'
      <soap:Body>
        <%sa% xmlns="%sa_ns%">
          %params%
        </%sa%>
      </soap:Body>
    </soap:Envelope>'

    select @sa_ns=left(@uri,patindex('%[a-z0-9_\-\\]/[a-z0-9_\-\\]%',@uri))
    select @i=dbo.fn__charindex('/',@sa,-1)
    if @i>1 select @sa_ns=left(@sa,@i-1),@sa=substring(@sa,@i+1,len(@sa))

    select @params=isnull(@params+@crlf,'')+'<'+var+'>'+val+'</'+var+'>'
    from #rcqprms

    exec sp__str_replace @rcq out,'%sa%|%sa_ns%|%uid%|%pwd%',
                                  @sa,@sa_ns,@uid,@pwd
    select @rcq=replace(@rcq,'%params%',@params)

    select @sa=@sa_ns+'/'+@sa

    end -- use of #rcqprms

-- can be used fn__sql_trim but is slower in a repetitive call
while left(@rcq,2)=@crlf select @rcq=substring(@rcq,3,len(@rcq))
while left(@rcq,1)=@cr select @rcq=substring(@rcq,2,len(@rcq))
while left(@rcq,1)=@lf select @rcq=substring(@rcq,2,len(@rcq))
select @rcq=ltrim(rtrim(replace(@rcq,@tab,'    ')))

if nullif(@rcq,'') is null raiserror('undefined request',16,1)

if @dbg=1
    begin
    exec sp__printf '-- @uri=%s, @ctype=%s, @method=%s, @sa=%s\n-- request:',
                    @uri,@ctype,@method,@sa

    exec sp__printsql @rcq
    end

if isnull(@sa,'')!='' select @soap=1 else select @soap=0

-- set soap action
if @soap=1
    begin
    select @cmd='SOAPAction'
    exec @hr = sp_oamethod @oid, 'setRequestHeader', null, @cmd, @sa
    if @hr!=0 raiserror(@hre,16,1)
    set @len = len(@rcq)
    select @cmd='content-Length'
    exec @hr = sp_oamethod @oid, 'setRequestHeader', null, @cmd, @len
    if @hr!=0 raiserror(@hre,16,1)
    end

-- more headers
if @rcqhdrs_id!=0
    begin
    declare @key nvarchar(500), @val nvarchar(500)
    declare cs cursor local for
    select [key],[val]
    from #rcqhdrs
    where 1=1
        open cs
        while 1=1
            begin
            fetch next from cs into @key,@val
            if @@fetch_status!=0 break

            select @cmd='setRequestHeader'
            exec @hr = sp_oamethod @oid, @cmd, null, @key, @val
            if @hr!=0 break

            end -- cursor cs
        close cs
        deallocate cs
        if @hr!=0 raiserror(@hre,16,1)
    end -- more headers

select @cmd='send'
exec @hr = sp_oamethod @oid, @cmd, null, @rcq
if @hr!=0 raiserror(@hre,16,1)

-- Get status text
select @cmd='StatusText'
exec sp_OAGetProperty @oid, @cmd, @sts out
if @hr!=0 raiserror(@hre,16,1)
select @cmd='Status'
exec sp_OAGetProperty @oid, @cmd, @hs_id out
if @hr!=0 raiserror(@hre,16,1)
select @sts=cast(@hs_id as sysname) + '|'+ @sts

-- Get response text
select @cmd='responseText'
insert into @blob(blob)
exec @hr = sp_OAGetProperty @oid, @cmd -- , @rsp out
/*  sp_OAGetProperty or any extended sp, do not support varchar(max)
    however returning as a resulset will return long results        */

select top 1 @rsp=blob from @blob

if @nodecode=0 select @rsp=dbo.fn__web_html_decode(@rsp)
if @soap=1 and @oxml=0
    begin
    -- remove <?xml tags
    update @utf set @rsp=replace(@rsp,utf,'')
    select @i=charindex(N'<soap:Body>',@rsp)
    select @i=charindex(N'<',@rsp,@i+1)
    select @n=charindex(N'</soap:Body>',@rsp,@i)
    select @rsp=substring(@rsp,@i,@n-@i)

    -- remove most external namespaces
    select @i=charindex(N'xmlns="',@rsp)
    if @i>0
        begin
        select @n=charindex(N'"',@rsp,@i+7)
        if @n<@i or @n=0 raiserror('inside error stripping namespace',16,1)
        select @rsp=left(@rsp,@i-1)+substring(@rsp,@n+1,len(@rsp))
        end
    end -- xmp strip

if @dbg=1
    begin
    exec sp__printf '-- response:'
    exec sp__printsql @rsp
    end

if not @hs_id in (0,200)
    begin
    if charindex(@soap_exception,@rsp)>0
        raiserror('soap exception',16,1)
    else
        raiserror('status ko',16,1)
    end

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

if not @oid is null exec sp_OADestroy @oid

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    get an html page or call a webservice

Notes
    * see "sp__util_advopt" on how disable protection
    * remember to put N before strings to correctly send unicode chars
    * ensure that exists in your web.config the parameter:
        <system.web>
            <globalization requestEncoding="UTF-8" responseEncoding ="UTF-8"/>
    * soap exception and status error raise a error stored into @sts or @rsp
      (@sts is "500|Internal Server Error" and @rsp contain the
      System.Web.Services.Protocols.SoapException message)
    * SOAP ACTION and SOAP PARAMS are CASE SENSITIVE
    * because the namespace is self-determined by the @sa,
      some problems can arise where there are more than one namespace

Parameters
    @uri        web address
    @method     optional method (default is GET)
    @ctype      content type (default TEXT/HTTP)
    @rcq        data to send or request body
    @sa         optional SOAP action
    @uid        optional Domain\UserName or UserName
    @pwd        optional password
    @rsp        (out)response
    @sts        (out)HTTP Status as id|txt (200=ok, 404=not found, etc.)
    #rcqhdrs    optional multiple request headers
                create table #rcqhdrs([key] nvarchar(500),val nvarchar(500))
    #rcqprms    optional to auto fill xml structure to call del SOAP ws
                create table #rcqprms(
                    id int identity, rid int default(0),
                    var nvarchar(500),
                    val nvarchar(max)
                    )
    @opt        option      description
                ----------- ----------------------------------------------------
                nodecode    disable html decode for faster execution
                to:r,c,r,s  set timeouts(ms) for receive,connect,send,receive
                oxml        do not strip SOAP headers but return original xml
                wslist      (TODO) instead of get htm page, get the list of srvs
                wsdl        (TODO) instead of call the SOAP method, get the DL
                ia          @uid & @pwd are passed as integrated authentication

Examples
    see sp__web_ws_test
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end try

-- =================================================================== errors ==
begin catch
select @e_msg=error_message()
if @e_msg=@hre
    exec sp_oageterrorinfo @oid,@e_p2 out,@e_p3 out

-- destroy ole object
if not @oid is null exec sp_OADestroy @oid
select @oid=null

if @e_msg=@hre
    begin
    select @e_msg='cmd ole "%s" (src:%s; msg:%s)',@e_p1=@cmd
    exec @ret=sp__err @e_msg,@proc,@p1=@e_p1,@p2=@e_p2,@p3=@e_p3,@opt='ex'
    end
else
    exec @ret=sp__err @cod=@proc,@opt='ex'
return @ret
end catch -- proc sp__web