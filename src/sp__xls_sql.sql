/*  leave this
    l:see LICENSE file
    g:utility,xls
    todo: rearrange code for a better error management
    v:100508\s.zaglio: execute a sql command into the xls sheet
    c:see http://www.simple-talk.com/sql/t-sql-programming/sql-server-excel-workbench/
    t:sp__xls_sql 'c:\backup\test_form.xls','insert into test_form(id,i_val,f_val,d_val,v_val,t_val) select 1,2,3,4,5,6'
    t:sp__xls_sql 'c:\backup\test_form.xls','delete from test_form' -- delete not supported
    t:sp__xls_sql 'c:\backup\test_form.xls','update test_form set id=null where id=''0'''
    t:
        create trigger tr_xls_test_form_test_form
            on xls_test_form_test_form
            instead of insert,update,delete
        as
        begin
        exec sp__xls_sql 'c:\backup\test_form.xls','insert into test_form(id,i_val,f_val,d_val,v_val,t_val) select 1,2,3,4,5,6'
        end

        insert into xls_test_form_test_form select 1,2,3,4,5,6

        drop trigger tr_xls_test_form_test_form
*/
CREATE procedure [dbo].[sp__xls_sql]
    @xls nvarchar(512),
    @sql nvarchar(4000),
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc='sp__xls_sql',@ret=0

declare
    @objexcel int,
    @hr int,
    @command sysname,
    @strerrormessage sysname,
    @objerrorobject int,
    @objconnection int,
    @bucket int,
    @worksheet sysname,
    @connectionstring nvarchar(1024),
    @crlf nchar(2)

select @crlf=crlf from dbo.fn__sym()

select @connectionstring =
    'provider=microsoft.jet.oledb.4.0;data source=%ds%;extended properties=excel 8.0'

select @connectionstring=replace (@connectionstring, '%ds%', @xls)

select @strerrormessage='making adodb connection ',
            @objerrorobject=null
exec @hr=sp_oacreate 'adodb.connection', @objconnection out
if @hr=0
    select @strerrormessage='assigning connectionstring property "'
            + @connectionstring + '"',
            @objerrorobject=@objconnection
if @hr=0 exec @hr=sp_oasetproperty @objconnection,
            'connectionstring', @connectionstring
if @hr=0 select @strerrormessage
        ='opening connection to xls, for file create or append'
if @hr=0 exec @hr=sp_oamethod @objconnection, 'open'

-- todo: convert @tbl in create with sp__script ....
-- declare @tbl sysname,@sql nvarchar(4000),@crlf nchar(2) select @tbl='test_form',@crlf=char(13)+char(10)

if @hr=0 select @strerrormessage
        ='executing ddl "'+@sql+'"'
if @dbg=1 exec sp__printf '%s',@sql

-- first we have to delete existing
if @hr=0 exec @hr=sp_oamethod @objconnection, 'execute',
                  @bucket out , @sql
if @hr<>0
    begin
    declare
        @source varchar(255),
        @description varchar(255),
        @helpfile varchar(255),
        @helpid int

    execute sp_oageterrorinfo @objerrorobject, @source output,
        @description output,@helpfile output,@helpid output
    select @strerrormessage='error whilst '
        +coalesce(@strerrormessage,'doing something')+', '
        +coalesce(@description,'')
    raiserror (@strerrormessage,16,1)
    end

goto ret

help:
exec sp__usage @proc

ret:
if @objconnection!=0 exec @hr=sp_oadestroy @objconnection
return @ret
end -- sp__xls_create