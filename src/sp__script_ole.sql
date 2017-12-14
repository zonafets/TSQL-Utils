/*  Leave this unchanged doe MS compatibility
    l:see LICENSE file
    g:utility,script
    v:100328\s.zaglio: renamed to sp__script_ole
    v:090801.1900\S.Zaglio: vertion 2.5 of sp__script (rewrite of old sp__generate_script)
    todo: test on checks, indexes, tables with foreign keys
    t:sp__script 'dtproperties',@print=0
    t:
        -- sp__script -- give us the help with #src structure
        create table #src (lno int identity(10,10),line nvarchar(4000))
        exec sp__script_ole 'sp__script_ole','#src'
        exec sp__script_ole '#src'                  -- this print the source
        drop table #src
    h: SQLDMO on MSDN see http://msdn.microsoft.com/en-us/library/aa258911(SQL.80).aspx
    h: for specific help see http://msdn.microsoft.com/en-us/magazine/bb985852.aspx
    h: for generic help see http://msdn.microsoft.com/en-us/magazine/cc301940.aspx
*/
CREATE proc [dbo].[sp__script_ole]
    @obj sysname=null out,         -- object name and output table name
    @out nvarchar(512)=null out,   -- file name or table or variale
    @conn sysname=null,            -- svr or svr|db or svr|db|uid or svr|db|uid|pwd
    @oc int=null,
    @step smallint=10,
    @print bit=1,
    @dbg bit=0
as
begin
set nocount on
/* Compatibility notes with MSSQL2005, MSSQL2008
To allow this sp to work with 2005 & 2008, must install backward feature on SQL2K and update on SQL2K5
download: http://download.microsoft.com/download/f/7/4/f74cbdb1-87e2-4794-9186-e3ad6bd54b41/SQLServer2005_BC.msi
(can need reboot)
Probably need also to disable some surface protection from SQL2005 surface area configuration such as:
- query remote ad hoc (enable openrowset, opendatase)
- ole automation
- enable xp_cmdshell
Can be done by code
EXECUTE sp_configure 'show advanced options', 1 RECONFIGURE WITH OVERRIDE
EXECUTE sp_configure
EXECUTE sp_configure 'xp_cmdshell', '1' RECONFIGURE WITH OVERRIDE
EXECUTE sp_configure 'Ole Automation Procedures', '1' RECONFIGURE WITH OVERRIDE
EXECUTE sp_configure 'SMO and DMO XPs', '1' RECONFIGURE WITH OVERRIDE
-- MSSQL2008
-- EXECUTE sp_configure 'Ad Hoc Distributed Queries',1 RECONFIGURE WITH OVERRIDE
EXECUTE sp_configure
EXECUTE sp_configure 'show advanced options', 0 RECONFIGURE WITH OVERRIDE
*/
declare @r int set @r=0
declare @msg nvarchar(4000)
declare @src_name sysname select @src_name='#src'
declare @dir nvarchar(256)
declare @file nvarchar(256)
declare @cmd sysname
declare @crlf nvarchar(2) set @crlf=char(13)+char(10)
declare @sql nvarchar(4000)
declare @n int,@i int, @k int, @drop_file bit
declare @line nvarchar(4000)
declare @out_var bit,@out_file bit,@out_tbl bit
declare @svr sysname,@db sysname,@uid sysname,@pwd sysname,@trusted bit
declare @own sysname
declare @ntype int
select @db=parsename(@obj,3)
select @own=parsename(@obj,2)
select @obj=parsename(@obj,1)
if @own is null set @own='dbo'
select @own=dbo.fn__sql_unquotename(@own)
select @obj=dbo.fn__sql_unquotename(@obj)
/*
    select @obj=@own+'.'+@obj
    --> give: cmd:addobjectbyname|source:ODSOLE Extended Procedure|desc:
        Incompatibilità tra tipi.|svr:16711422|@transf:
*/

if @obj=@src_name goto print_src
if @out=@src_name select @print=null

-- return db_name() and server if nulls
if @conn is null and @db is null select @db=db_name()
exec sp__parse_conn @conn,@svr out,@db out,@uid out,@pwd out,@trusted out

/*
if not @obj is null and charindex('.',@obj)>0 begin
    set @own=dbo.fn__str_at(@obj,'.',1)
    set @obj=dbo.fn__str_at(@obj,'.',2)
end
*/

-- sqldmo_script_type vars
-- see: http://msdn.microsoft.com/en-us/library/aa225364(SQL.80).aspx
declare @sqldmoscript_default int , @sqldmoscript_drops int , @sqldmoscript_objectpermissions int
declare @sqldmoscript_primaryobject int , @sqldmoscript_clusteredindexes int , @sqldmoscript_triggers int
declare @sqldmoscript_databasepermissions int , @sqldmoscript_permissions int , @sqldmoscript_tofileonly int
declare @sqldmoscript_bindings int , @sqldmoscript_appendtofile int , @sqldmoscript_nodri int
declare @sqldmoscript_uddtstobasetype int , @sqldmoscript_includeifnotexists int , @sqldmoscript_nonclusteredindexes int
declare @sqldmoscript_indexes int , @sqldmoscript_aliases int , @sqldmoscript_nocommandterm int
declare @sqldmoscript_driindexes int , @sqldmoscript_includeheaders int , @sqldmoscript_ownerqualify int
declare @sqldmoscript_timestamptobinary int , @sqldmoscript_sorteddata int , @sqldmoscript_sorteddatareorg int
declare @sqldmoscript_transferdefault int , @sqldmoscript_dri_nonclustered int , @sqldmoscript_dri_clustered int
declare @sqldmoscript_dri_checks int , @sqldmoscript_dri_defaults int , @sqldmoscript_dri_uniquekeys int
declare @sqldmoscript_dri_foreignkeys int , @sqldmoscript_dri_primarykey int , @sqldmoscript_dri_allkeys int
declare @sqldmoscript_dri_allconstraints int , @sqldmoscript_dri_all int , @sqldmoscript_driwithnocheck int
declare @sqldmoscript_noidentity int , @sqldmoscript_usequotedidentifiers int

-- format output definitions
declare @sqldmoscript_4usequoted int -- only columns and without collate

-- sqldmo_script2_type vars
-- see: http://msdn.microsoft.com/en-us/library/aa225398(SQL.80).aspx
declare @sqldmoscript2_default int , @sqldmoscript2_ansipadding int , @sqldmoscript2_ansifile int
declare @sqldmoscript2_unicodefile int , @sqldmoscript2_nonstop int , @sqldmoscript2_nofg int
declare @sqldmoscript2_marktriggers int , @sqldmoscript2_onlyusertriggers int , @sqldmoscript2_encryptpwd int
declare @sqldmoscript2_separatexps int , @sqldmoscript2_extendedproperty int , @sqldmoscript2_extendedonly int
declare @sqldmoscript2_nocollation int
/*
    test:
    declare @tbl sysname, @new sysname
    select @tbl='put here the table',@new=@tbl+'_renamed'
    create table #src (lno int identity(10,10),line nvarchar(4000))
    exec sp__script_ole @tbl,'#src',@oc=1
    exec sp__script_ole @tbl,'#src',@oc=20
    exec sp__script_ole @tbl,'#src',@oc=32
    update #src set line=replace(line,@tbl,@new)
    select coalesce(line,'') as line from #src order by lno
    drop table #src
*/

-- sp__script options
declare
    @oc_tbl smallint,@oc_dri smallint,@oc_trg smallint,@oc_prp smallint,
    @oc_col smallint, @oc_fk smallint,
    @oc_end_declare bit
select
    @oc_tbl=1,
    @oc_dri=20,
    @oc_trg=32,
    @oc=coalesce(@oc,@oc_tbl),
    @oc_prp=128,
    @oc_col=512,
    @oc_fk=1024

-- sqldmo_script_type values
-- see: http://msdn.microsoft.com/en-us/library/aa225364(SQL.80).aspx
set @sqldmoscript_default = 4                       set @sqldmoscript_drops = 1
set @sqldmoscript_objectpermissions = 2             set @sqldmoscript_primaryobject = 4
set @sqldmoscript_clusteredindexes = 8              set @sqldmoscript_triggers = 16
set @sqldmoscript_databasepermissions = 32          set @sqldmoscript_permissions = 34
set @sqldmoscript_tofileonly = 64                   set @sqldmoscript_bindings = 128
set @sqldmoscript_appendtofile = 256                set @sqldmoscript_nodri = 512
set @sqldmoscript_uddtstobasetype = 1024            set @sqldmoscript_includeifnotexists = 4096
set @sqldmoscript_nonclusteredindexes = 8192        set @sqldmoscript_indexes = 73736
set @sqldmoscript_aliases = 16384                   set @sqldmoscript_nocommandterm = 32768
set @sqldmoscript_driindexes = 65536                set @sqldmoscript_includeheaders = 131072
set @sqldmoscript_ownerqualify = 262144             set @sqldmoscript_timestamptobinary = 524288
set @sqldmoscript_sorteddata = 1048576              set @sqldmoscript_sorteddatareorg = 2097152
set @sqldmoscript_transferdefault = 422143          set @sqldmoscript_dri_nonclustered = 4194304

set @sqldmoscript_dri_clustered = 8388608           set @sqldmoscript_dri_checks = 16777216
set @sqldmoscript_dri_defaults = 33554432           set @sqldmoscript_dri_uniquekeys = 67108864
set @sqldmoscript_dri_foreignkeys = 134217728       set @sqldmoscript_dri_primarykey = 268435456
set @sqldmoscript_dri_allkeys = 469762048           set @sqldmoscript_dri_allconstraints = 520093696
set @sqldmoscript_dri_all = 532676608               set @sqldmoscript_driwithnocheck = 536870912
set @sqldmoscript_noidentity = 1073741824           set @sqldmoscript_usequotedidentifiers = -1

-- format
set @sqldmoscript_4usequoted =-1

-- sqldmo_script2_type values
-- see: http://msdn.microsoft.com/en-us/library/aa225398(SQL.80).aspx
set @sqldmoscript2_default = 0                      set @sqldmoscript2_ansipadding = 1
set @sqldmoscript2_ansifile = 2                     set @sqldmoscript2_unicodefile = 4
set @sqldmoscript2_nonstop = 8                      set @sqldmoscript2_nofg = 16
set @sqldmoscript2_marktriggers = 32                set @sqldmoscript2_onlyusertriggers = 64
set @sqldmoscript2_encryptpwd = 128                 set @sqldmoscript2_separatexps = 256
set @sqldmoscript2_extendedproperty = 4194304       set @sqldmoscript2_extendedonly=67108864
set @sqldmoscript2_nocollation = 8388608

-- convertion from sp__Script options to sqldmo options
declare @type nchar(2),@options2 int ,@options int
select @options=case
    when @oc=@oc_prp then           @sqldmoscript_default   -- if only xprops
    when @oc&64=64 then               @sqldmoscript_default
                                    | @sqldmoscript_ownerqualify
                                    | @sqldmoscript_dri_defaults
    when @oc&@oc_tbl=@oc_tbl then   @sqldmoscript_default
                                    | @sqldmoscript_dri_defaults
                                    | @sqldmoscript_ownerqualify
    when @oc&@oc_fk=@oc_fk then     @sqldmoscript_dri_foreignkeys
                                    | @sqldmoscript_nodri
                                    | @sqldmoscript_driwithnocheck
--    sp__script '%tbl%',@oc=134
    when @oc&@oc_dri=@oc_dri then   @sqldmoscript_nodri
                                    | @sqldmoscript_dri_primarykey
                                    | @sqldmoscript_nonclusteredindexes
                                    | @sqldmoscript_dri_clustered
                                    | @sqldmoscript_indexes
                                    -- | @sqldmoscript_dri_defaults -- this don't work
    when @oc&@oc_trg=@oc_trg then   @sqldmoscript_triggers
                                    | @sqldmoscript_nodri
                                    | 0
    else                            @sqldmoscript_default
                                    --| @sqldmoscript_nodri | @sqldmoscript_dri_defaults
                                    | @sqldmoscript_ownerqualify
                                    | @sqldmoscript_noidentity
    end

if (@options is null) select @options=@sqldmoscript_default

set @options2=  @sqldmoscript2_ansifile|@sqldmoscript2_unicodefile|
                case when @oc&@oc_prp=@oc_prp and @oc!=@oc_prp then @sqldmoscript2_extendedproperty
                when @oc=@oc_prp then @sqldmoscript2_extendedonly else 0 end|
                case when @oc&@oc_col=@oc_col then 0 else @sqldmoscript2_nocollation end
-- HELP

if (@obj='-?' or @obj is null) goto help

if left(@out,1)='#' and @out!=@src_name goto err_tmptbl
select @sql=quotename(@own)+'.'+quotename(@obj)
if @conn is null and dbo.fn__exists(@sql,null)=0 goto err_objnf

-- use as @tmp
select @msg='tmp_'+replace(convert(nvarchar(64),newid()),'-','_')+'.sql'

-- a temp destination file is required by OLE method call
if @out=@src_name --- we presume that exist and is compatible to (lno,line,...)
    begin
    exec sp__get_temp_dir @file out
    set @file=@file+@msg
    end
else
    begin
    create table #src (lno int identity(10,10),line nvarchar(4000))
    if @out is null select @out=@msg,@drop_file=1
    if charindex('\',@out)=0 -- out can be: file [1], dir\ [2] , dir\file [3]
        begin
        exec sp__get_temp_dir @file out -- [1]
        select @file=@file+'\'+@out
        end
    else
        begin
        if right(@out,1)='\' select @file=@out+@msg -- [2]
        end
    end -- !=#src

select @msg=null
select @sql=N'select @type=xtype from ['+@db+']..sysobjects where [name]='''+@obj+''''
exec sp_executesql  @sql,N'@type nchar(2) out',
                    @type=@type out

/*
if @type in ('V','P','TF','FN','IF')
    begin
    todo: to refine better
    select @i=min(colid),@n=max(colid) from syscomments where id=object_id(@obj)
    while (@i<=@n)
        begin
        select @line=[ntext] from syscomments
        where id=object_id(@obj) and colid=@i
        select @i=@i+1
        insert into #src(line) select token from dbo.fn__str_table(@line,@crlf) order by pos
        end
    end -- source in syscomments
else
    begin
*/


declare @object_types nvarchar(50)
-- used to translate sysobjects.type into the bitmap that transfer requires
set @object_types='t     v  u  p     d  r  tr          fn tf if '
set @type=case @type when 'tf' then 'fn' when 'if' then 'fn' else @type end
set @ntype=power(2,(charindex(@type+' ',@object_types)/3))

declare @hr int

declare @server int, @transf int    -- handle objects

select @cmd='SQLDMO.SQLServer'
exec @hr=sp_oacreate @cmd, @server out if @hr<>0 goto err_dmo
select @cmd='SQLDMO.Transfer'
exec @hr=sp_OaCreate @cmd, @transf out if @hr<>0 goto err_dmo

if @trusted=1 begin
    if @dbg=1 print 'secure login'
    select @cmd='loginsecure'
    exec @hr = sp_oasetproperty @server, @cmd, 1 if (@hr <> 0) goto err_dmo
    select @cmd='connect'
    exec @hr = sp_oamethod @server, @cmd, null, @svr if (@hr <> 0) goto err_dmo
    end
else begin
    if @dbg=1 print 'connection'
    select @cmd='connect'
    if coalesce(@pwd,'')='' exec @hr = sp_oamethod @server, @cmd, null, @svr, @uid if (@hr <> 0) goto err_dmo
    else exec @hr = sp_oamethod @server, @cmd, null, @svr, @uid, @pwd if (@hr <> 0) goto err_dmo
end

select @cmd='copydata'
exec @hr = sp_oasetproperty @transf, @cmd, 0                            if (@hr <> 0) goto err_dmo
select @cmd='copyschema'
exec @hr = sp_oasetproperty @transf, @cmd, 1                          if (@hr <> 0) goto err_dmo
--if @type='ut'
--exec @hr = sp_oasetproperty @transf, 'includedependencies', 1                 if (@hr <> 0) goto err_dmo
select @cmd='addobjectbyname'
exec @hr = sp_oamethod @transf, @cmd, null, @obj, @ntype, @own   if (@hr <> 0) goto err_dmo
select @cmd='scripttype'
exec @hr = sp_oasetproperty @transf, @cmd, @options                   if (@hr <> 0) goto err_dmo
if @dbg=1 exec sp__printf 'options=%d',@options
select @cmd='script2type'
exec @hr = sp_oasetproperty @transf, @cmd, @options2                 if (@hr <> 0) goto err_dmo
if @dbg=1 exec sp__printf 'options2=%d',@options2


set  @cmd =   'Databases("' + @db + '").ScriptTransfer'
if @dbg=1 exec sp__printf '-- %s',@cmd
create table #devnul (t ntext) insert into #devnul -- prevent output
exec @hr=sp_oamethod @server, @cmd,null, @transf, 2, @file if (@hr <> 0) goto err_dmo
drop table #devnul

/*
-- sometimes cause an unk err and not accept the databases cmd
declare @object int
select @cmd='databases'
exec @hr = sp_oagetproperty @server, @cmd, @object out                 if (@hr <> 0) goto err_dmo
select @cmd='item'
exec @hr = sp_oamethod @object, @cmd, @object out, @db                      if (@hr <> 0) goto err_dmo
select @cmd='scripttransfer'
create table #devnul (t ntext) insert into #devnul
exec @hr = sp_oamethod @object, @cmd,null, @transf, 2, @file      if (@hr <> 0) goto err_dmo
drop table #devnul
*/

exec sp_oadestroy @transf set @transf=null
select @cmd='disconnect'
exec @hr=sp_oamethod @server, @cmd if (@hr <> 0) goto err_dmo
exec sp_oadestroy @server set @server=null

exec sp__file_read @file,@src_name,@step=@step,@dbg=@dbg
-- correct a problem that the editor introduce with a double #13 or #10
select @sql='update '+@src_name+' set line=replace(replace(line,char(13),'' ''),char(10),'' '')'
exec(@sql)
set @obj=@src_name

--end -- use of sqldmo

print_src:
exec sp__count @src_name,@n=@n out
if @n=0 exec sp__printf '-- no source rows found'
if @dbg=1 exec sp__printf '%d rows in source',@n

if @n>0 and @print=1
    begin
    if @dbg=1 exec sp__printf 'printing...'
    exec sp__print_table '#src'
    end -- print

if @print=0
    begin
    if @dbg=1 set @sql='select * from '+@obj+' order by lno'
    else set @sql='select line from '+@obj+' order by lno'
    exec (@sql)
    drop table #src
    end

-- c: see http://www.simple-talk.com/sql/t-sql-programming/the-tsql-of-text-files/

if @drop_file=1 begin
    set @sql='del /q "'+@file+'"'
    if @dbg=1 print @sql
    exec xp_cmdshell @sql,no_output
end

goto ret

help:

select @msg ='\ntmp decl: create table #src (lno int identity('+convert(sysname,@step)+','+convert(sysname,@step)+'),line nvarchar(4000))\n\n'
            +'@options can be (NB: cannot be combined):\n'
            +'\t@oc_tbl=1   -- table with owner and not chk\n'
            +'\t@oc_dri=20  -- pkey,idx and chk\n'
            +'\t@oc_trg=32  -- triggers only\n'
            +'\t@oc_prp=128 -- with extended properties or only extended prop. if alone\n'
            +'\t@oc_col=512 -- add collation definition\n'
            +'\t@oc_fk=1024 -- only foreign key(on obj table)\n'
            +'\tdefault=@oc_tbl\n'
            +'\tfor foreign keys source use "sp__script_fkeys @table"\n'
            +'\n'
            +'Examples\n'
            +'\tsp__script_ole ''sp__script'' -- print source\n'
            +'\tsp__script_ole ''sp__script'',@print=0 -- output a select\n'
            +'\tsp__script_ole ''sp__script'',@out=''#src'',@print=null -- append to standard temp #src table\n'
            +'\tsp__script_ole ''sp__script'',@out=''sp__script.sql'',@print=null -- output to %temp%\sp__script.sql\n'
            +'\n'

exec sp__usage 'sp__script_ole',@extra=@msg
select @msg=null
goto ret

err_tmptbl:select @msg='-- temp table name must be #src',@r=1 goto ret
err_objnf:select @msg='-- object "'+@obj+'" not found',@r=1 goto ret
err_dmo:
ret:
if not (@server is null and @transf is null)
    begin
    DECLARE @source nvarchar(255)
    DECLARE @description nvarchar(255)

    EXEC @hr = sp_OAGetErrorInfo @transf, @source OUT, @description OUT
    exec sp__printf '-- cmd:%s|source:%s|desc:%s|svr:%s|@transf:%d',@cmd,@source,@description,@server,@transf

    destory:
    if not @server is null exec sp_oadestroy @server
    if not @transf is null exec sp_oadestroy @transf
    end

if not @msg is null exec sp__printf @msg

return @r
end -- proc