/*  leave this
    l:see LICENSE file
    g:utility
    v:090914\s.zaglio: added nocollation
    v:090909\s.zaglio: create a script of all db with dependencies, users, roles, ext.prop
    t:
        exec sp__run_cmd 'del %temp%\%@@servername%_%db_name()%.sql /q'
        exec sp__script_db
        exec sp__run_cmd 'type %temp%\%@@servername%_%db_name()%.sql'
        exec sp__run_cmd 'del %temp%\%@@servername%_%db_name()%.sql /q /f'
        -- exec sp__run_cmd 'dir %temp%\*.*'
        -- exec sp__run_cmd 'del %temp%\*.* /q /s /f'
*/
CREATE procedure [dbo].[sp__script_db]
    @srv    nvarchar(100)=null,--the name of the source server
    @db     nvarchar(100)=null,--the name of the source database
    @uid    nvarchar(100)=null,--the login to the source server
    @pwd    nvarchar(100)=null,--the password to the source server
    @out    sysname=null,
    @dbg    bit=0
as
begin
set nocount on
if @srv is null select @srv=@@servername
if @db is null select @db=db_name()
declare
    @hr int,
    @filename nvarchar(100),
    @oserver int,
    @otransfer int,
    @errorobject int,
    @strcommand nvarchar(255),
    @strresult nvarchar(255),
    @errormessage nvarchar(2000),
    @strobjectname nvarchar(100),
    @slice int

declare @tmp sysname
exec sp__get_temp_dir @tmp out

if right(@out,1)='\' select @out=left(@out,len(@out)-1)
if not @out is null and right(@out,4)!='.sql' and @out!='#src'
    select @filename=@out
else
    set @filename = @tmp
select @filename=@filename+'\'+@srv+'_'+@db+'.sql'

if @dbg=1 exec sp__printf 'out to:%s',@filename

exec @hr = sp_oacreate 'sqldmo.sqlserver', @oserver out
if @hr=0 exec @hr = sp_oacreate 'sqldmo.transfer', @otransfer out
if @pwd is null or @uid is null
    begin
    --use a trusted connection
    if @hr=0 select @errormessage='setting login to windows authentication on '+@srv, @errorobject=@oserver
    if @hr=0 exec @hr = sp_oasetproperty @oserver, 'loginsecure', 1
    if @hr=0 select @errormessage='logging in to the requested server using windows authentication on '+@srv
    if @uid is null and @hr=0 exec @hr = sp_oamethod @oserver, 'connect', null, @srv
    if @uid is not null and @hr=0 exec @hr = sp_oamethod @oserver, 'connect', null, @srv ,@uid
    end
else
    begin
    if @hr=0 select @errormessage = 'connecting to '''+@srv+
        ''' with user id '''+@uid+'''', @errorobject=@oserver
    if @hr=0 exec @hr = sp_oamethod @oserver, 'connect', null, @srv ,
                         @uid , @pwd
    end
if @hr=0 select @errorobject=@otransfer,
        @errormessage='assigning values to parameters'

if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'copyallobjects', 1
if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'copydata', 0
if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'copyschema', 1

--if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'copyalldefaults', 0
--if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'copyallobjects', 0
--if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'copyallrules', 0
--if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'copyallstoredprocedures', 0
--if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'copyalltables', 0
--if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'copyalluserdefineddatatypes', 0
--if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'copyalltriggers', 0
--if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'copyallviews', 0
--
-- if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'dropobjectsfirst', 0
if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'includedependencies', 1
if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'includegroups', 1
if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'includelogins', 1
if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'includeusers', 1
if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'includedb', 1

-- sqldmo_script_type vars
-- see: http://msdn.microsoft.com/en-us/library/aa225364(SQL.80).aspx
-- see: http://msdn.microsoft.com/en-us/library/aa225398(SQL.80).aspx

if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'scripttype', 68  -- print 4|64 -- def|tofile
if @hr=0 exec @hr = sp_oasetproperty @otransfer, 'script2type', 12582918 -- print 4194304|4|2|8388608 -- ext.prop|unicode|nocollation

select @strcommand = 'databases("' + @db + '").scripttransfer'

if @hr=0
    begin
    create table #devnul (t ntext) insert into #devnul -- prevent output
    exec @hr = sp_oamethod @oserver, @strcommand, null, @otransfer, 2, @filename
    drop table #devnul
    end

if @hr=0 select @errorobject=@oserver,@errormessage='using method '+@strcommand
if @hr<>0
    begin
    declare
        @source nvarchar(255),
        @description nvarchar(255),
        @helpfile nvarchar(255),
        @helpid int

    execute sp_oageterrorinfo  @errorobject,
        @source output,@description output,@helpfile output,@helpid output

    select @errormessage='error whilst '+@errormessage+', '+@description
    raiserror (@errormessage,16,1)
    end
exec sp_oadestroy @otransfer
exec sp_oadestroy @oserver
return @hr
end -- proc