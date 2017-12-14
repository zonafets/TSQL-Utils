/*  leave this
    l:see LICENSE file
    g:utility,xls
    v:130906\s.zaglio: adapted to fn__parse_url rename
    v:130217\s.zaglio: added resources into help and q option
    r:120314\s.zaglio: adapted to sql2k5 (32&64bit)
    v:100508\s.zaglio: removed convertion, used imex
    v:100501\s.zaglio: skip print/area/filters..and not real sheets; added imex and @nohd
    v:100424\s.zaglio: create views for xls files
    t:sp__xls_attach 'c:\shared_folders\backup_db\','xls_tests' ,@dbg=1
    t:sp__dir 'xls*' -- sp__drop 'xls_tests_*',@simul=0
*/
CREATE proc [dbo].[sp__xls_attach]
    @path nvarchar(512)=null,
    @root sysname=null,
    @opt sysname=null,
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0,
       @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

if @path is null goto help

-- ================================================================== declare ==
declare
    @cmd nvarchar(1024), @file nvarchar(512),
    @tbl sysname,@i int,@n bigint,
    @sql nvarchar(4000),@view sysname,
    @flds nvarchar(4000),@psep nchar(1),
    @crlf nvarchar(2),@tmp sysname,@obj sysname,
    @quiet bit
create table #xls(id int identity,[file] nvarchar(4000))
create table #tbls(
    id int identity,
    table_cat sysname null,
    table_schem sysname null,
    table_name sysname null,
    table_type sysname null,
    remarks sysname null,
    view_name sysname null
    )
create table #providers(
    cod sysname,
    parse sysname,
    des sysname
    )

-- ===================================================================== init ==
select
    @quiet=charindex('|q|',@opt)|charindex('|quiet|',@opt),
    @psep=psep,
    @crlf=crlf
from dbo.fn__sym()

if not right(@path,4)='.xls'
and not right(@path,5)='.xlsx'
    begin
    if right(@path,1)!='\' select @path=@path+'\'
    select @path=@path+'*.xls?'
    end

-- xp_cmdshell 'dir /b "d:\sapshare\xls_seltris\*.xls"'
select @cmd='dir /s /b "'+@path+'"'

-- drop table #stdout

-- ===================================================================== body ==

-- check providers
insert #providers exec xp_enum_oledb_providers
if not exists(
    select cod from #providers
    where cod in ('MSDASQL','Microsoft.ACE.OLEDB.12.0')
    )
    goto err_prv
-- OLEDB Provider for ODBC (MSDASQL)

if @dbg=1 exec sp__printf'path=%s',@path

insert #xls
exec xp_cmdshell @cmd
delete from #xls where [file] is null -- last null row

select @n=max(id) from #xls
if @n is null goto err_nof

declare cs cursor local for
    select [file]
    from #xls
    where 1=1
open cs
while 1=1
    begin
    fetch next from cs into @file
    if @@fetch_status!=0 break

    if @quiet=0 exec sp__printf '-- link file %s',@file

    -- some sheet shave wrong cells other not work
    if exists(select null from master..sysservers where srvname='$xls')
        exec master.dbo.sp_dropserver @server=N'$xls', @droplogins='droplogins'

    -- declare @file sysname,@tmp sysname select @file='c:\shared_folders\backup_db\sqltest.xlsx'
    select @tmp='xls_'+replace(convert(sysname,newid()),'-','_')
    exec sp_addlinkedserver
        @server = @tmp,
        @srvproduct='xls',
        @provider='microsoft.ace.oledb.12.0',
        @datasrc=@file,
        @provstr='excel 12.0;readonly=1'

    -- sp__xls_attach 'c:\backup'
    declare @su sysname select @su=system_user
    exec sp_addlinkedsrvlogin @tmp, 'false', @su, N'ADMIN', NULL

    truncate table #tbls

    insert #tbls(table_cat,table_schem,table_name,table_type,remarks)
    exec master.dbo.sp_tables_ex @table_server = @tmp

    -- select * from #tbls

    if @dbg=0 exec master.dbo.sp_dropserver @server=@tmp, @droplogins='droplogins'

    if @dbg=1 exec sp__select_astext '#tbls',@header=1

    -- declare @file sysname,@root sysname select @file='c:\shared_folders\backup_db\sqltest.xlsx'

    if @root is null
        update #tbls set
            view_name='xls_'+replace(dbo.fn__format(@file,'AN',default),'__','_')+
                      '_'+table_name
        from #tbls
    else
        begin
        select
            @root+'_'+dbo.fn__format(page,'AN',default)+'_'+table_name
        from #tbls,dbo.fn__parse_url('file:///'+@file,default)

        update #tbls set
            view_name=@root+'_'+dbo.fn__format(page,'AN',default)+'_'+table_name
        from #tbls,dbo.fn__parse_url('file:///'+@file,default)
        end

    -- strip last dollar
    update #tbls set
        view_name=left(view_name,len(view_name)-1)
    where right(view_name,1)='$'

    -- create view for sheets with data

    declare sh cursor local for
        select table_name,quotename(view_name)
        from #tbls
        where right(table_name,1)='$' -- skip subsheets/view/filters/print areas...
    open sh
    while 1=1
        begin
        fetch next from sh into @tmp,@obj
        if @@fetch_status!=0 break

        select @sql='select @n=count(*) from openrowset(''MSDASQL'','+
        '''DRIVER=Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb);'+
        'UID=admin;UserCommitSync=Yes;Threads=3;SafeTransactions=0;ReadOnly=1;'+
        'PageTimeout=5;MaxScanRows=8;MaxBufferSize=2048;FIL=excel 14.0;DriverId=1046;'+
        'DBQ='+@file+''','''+
        ' select top 1 * from ['+@file+'].['+@tmp+']'')'

        select @n=null
        if @dbg=1 exec sp__printsql @sql
        exec sp_executesql @sql,N'@n bigint out',@n=@n out
        if isnull(@n,0)>0
            begin
            if not object_id(@obj) is null exec('drop view '+@obj)
            select @sql=
                'create view '+@obj+' as '+
                'select * from openrowset(''MSDASQL'','+
                '''DRIVER=Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb);'+
                'UID=admin;UserCommitSync=Yes;Threads=3;SafeTransactions=0;ReadOnly=1;'+
                'PageTimeout=5;MaxScanRows=8;MaxBufferSize=2048;FIL=excel 14.0;DriverId=1046;'+
                'DBQ='+@file+''','''+
                ' select * from ['+@file+'].['+@tmp+']'')'
            exec(@sql)
            end
        end -- while of cursor sheets
    close sh
    deallocate sh

    end -- while of cursor files
close cs
deallocate cs

dispose:
drop table #providers
drop table #xls
drop table #tbls
goto ret

-- =================================================================== errors ==
err_nof:    exec @ret=sp__err 'no xls files found',@proc
            goto ret
err_prv:    exec @ret=sp__err '"MSDASQL" and "Microsoft.ACE.OLEDB" providers are required',@proc
            goto ret

-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    Will search all XLS files under @path and create a xls_* view for each sheet

Parameters
    @path   is the path where search
    @root   is the root name for tview as root_file_sheet
            otherwise will be used xls_path_file_sheet
    @opt    options
            q|quiet     do not show messages

Notes
    * the new version uses only MSDASQL provider that require to install
      the MSAccess runtime.
    * if the file do not exists anymore, the select on view return
      a wrong message about gesitration of OLEDB that can be confused
      with previos point
    * can be necessary run this to exable linked server
        use msdb
        go
        sp_configure ''show advanced options'', 1
        go
        reconfigure with override
        go
        sp_configure ''ad hoc distributed queries'', 1
        go
        reconfigure with override
        go
    * resources:
      http://www.ashishblog.com/blog/importexport-excel-xlsx-or-xls-file-into-sql-server/

Examples
    sp__xls_attach "c:\shared_folders\backup_db\","xls_tests",@dbg=1
'

-- ===================================================================== exit ==

ret:
return @ret
end -- sp__xls_attach