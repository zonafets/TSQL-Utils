/*  leave this
    l:see LICENSE file
    g:utility
    v:091018\s.zaglio: added ip recodnize
    v:090127\S.Zaglio: added domain and now this function check if @svr is local, ignoring the domain if necessary
    v:081121\S.Zaglio: replace @@servername that can fail with virtual svr name when there is a real svr with same name
    t: print dbo.fn__servername(null)
    t: print dbo.fn__servername('server.domain\instance') ->server.domain\instance
    t: print dbo.fn__servername('server\instance') ->server\instance
    t: print dbo.fn__servername('ip\instance') ->ip\instance
*/
CREATE function fn__servername(@svr sysname)
returns sysname
as
begin
declare @r sysname
-- set @r=coalesce(@@servername,convert(sysname,serverproperty('servername')))
-- I don't remember why excluded @@servername
declare @key sysname,@domain sysname,@server sysname,@instance sysname,@ip sysname

select @ip=dbo.fn__global_get('server_ip')

SET @key = 'SYSTEM\ControlSet001\Services\Tcpip\Parameters\'
EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@key,@value_name='Domain',@value=@Domain OUTPUT
-- SELECT 'Server Name: '+@@servername + ' Domain Name:'+convert(varchar(100),@Domain)
set @server=convert(sysname,serverproperty('servername'))
declare @i int set @i=charindex('\',@server)
if @i>0 begin
    set @instance=substring(@server,@i,len(@server))
    set @server=left(@server,@i-1)
    end
else set @instance=''
set @r=@server+coalesce('.'+@domain,'')+@instance
if not @svr is null begin
    set @server=replace(@svr,'\','%\')
    set @ip=@ip+@instance
    if @r like @server set @r=@svr -- return name witch to check
    if @svr like @ip set @r=@svr
end
return @r
end