/*  leave this
    l:see LICENSE file
    g:utility
    d:130906\s.zaglio:fn__parseurl
    v:130906.1000\s.zaglio:moved out tests,renamed and + parse of local path
    v:120125\s.zaglio:done
    r:120124\s.zaglio:working
    r:120123\s.zaglio:parse the unified resource locator
    d:120123\s.zaglio:fn__parsefilename
    t:sp__parse_url_test
*/
CREATE function [dbo].[fn__parse_url](
    @url nvarchar(4000),
    @opt sysname
    )
returns @t table(
    url nvarchar(4000) null,
    normalized nvarchar(4000) null,
    protocol sysname null,
    [uid] sysname null,
    [pwd] sysname null,
    host sysname null,
    port sysname null,              -- because can contain the drive/device
    [path] nvarchar(4000) null,
    page nvarchar(4000) null,
    query nvarchar(4000) null,
    dbg sysname null
    )
as
begin
declare
    @dsp as int,                -- double slash position is the fulcrum
    @nurl nvarchar(4000),       -- normalized url
    @ourl nvarchar(4000),       -- original url
    @protocol sysname,
    @uid sysname,
    @pwd sysname,
    @host sysname,
    @port sysname,
    @path nvarchar(4000),
    @page nvarchar(4000),
    @query nvarchar(4000),
    @puid int,@ppwd int,@ppath int,@pquery int,
    @pport int,@ppage int,@lpath int,
    @psep nvarchar(2),@revert bit,
    @dbg sysname

if @url is null goto ret

-- normalize name
select
    @ourl=@url,
    @url=replace(@url,'%20',' '),
    @psep=psep
from fn__sym()

-- reduce firefox long file url
select @url=replace(@url,'/////','//')

-- special check for local path
if @url like '[a-z]:\[^\]%'
    select @url='file:///'+@url,@revert=1
else
    select @revert=0


-- dsp must be specified
select
    @nurl=replace(@url,'\','/'),
    @dsp=charindex('//',@nurl),
    @ppath=charindex('/',@nurl,@dsp+2),
    @pquery=charindex('?',@nurl,@dsp+2)
if @dsp = 0 goto wrong
if @ppath = 0 select @ppath=len(@nurl)+1     -- ftp path can not have it
if @pquery=0 select @pquery=len(@nurl)+1

-- select * from dbo.fn__parse_url('c:\share\dir\file.ext',default)

select
    @protocol=left(@url,@dsp-1),
    @host=substring(@url,@dsp+2,@ppath-@dsp-2),
    @path=substring(@url,@ppath,@pquery-@ppath),
    @nurl=reverse(substring(@nurl,@ppath,@pquery-@ppath)),    -- used below
    @query=substring(@url,@pquery+1,4000),
    @ppwd=charindex(':',@host),
    @puid=charindex('@',@host)
    -- ,@dbg=@nurl

if @revert=1 select @path=replace(@path,'/','\')

if @protocol!=''
    begin
    if right(@protocol,1)!=':' goto wrong
    else select @protocol=left(@protocol,@dsp-2)
    end

if @ppwd>0
    select
        @pwd=left(@host,@ppwd-1),
        @uid=substring(@host,@ppwd+1,@puid-@ppwd-1),
        @host=substring(@host,@puid+1,128),
        @pport=charindex(':',@host)

if @pport>0
    begin
    select
        @port=substring(@host,@pport+1,16),
        @host=left(@host,@pport-1)
    if isnumeric(@port)=0 and @protocol!='file'
        goto wrong      -- or is the case to cause and error? No.
                        -- the parse check the syntax not the semantic
    end

-- parse page name if exists
select
    @lpath=len(@path),
    @ppath=@lpath-charindex('/',@nurl)+1,
    @ppage=charindex('.',@nurl)
    -- ,@dbg=@nurl

if @ppage>0 select @ppage=@lpath-@ppage+1

if @ppage>@ppath and @ppath>0
    select
        @page=substring(@path,@ppath+1,512),
        @path=left(@path,@ppath)
else
    select
        @page=''

if @protocol='file' and @host=''
    select
        @host=null,
        @port=substring(@path,2,charindex(':',@path)-1),
        @path=substring(@path,charindex(':',@path)+1,512)

insert @t(  url,        normalized,
            protocol,   [uid],  [pwd],  host,
            port,       [path], page,   query,
            dbg
         )
select      @ourl,      @url,
            @protocol,  @uid,   @pwd,   @host,
            @port,      @path,  @page,  @query,
            @dbg

ret:
return
wrong:
insert @t(  url,        normalized,
            protocol,   [uid],  [pwd],  host,
            port,       [path], page,   query,
            dbg
         )
select      @ourl,      null,
            null,       null,   null,   null,
            null,       null,   null,   null,
            null
return
end -- fn__parse_url