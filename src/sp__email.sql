/*  leave this
    l:see LICENSE file
    g:utility
    r:131223.1100\s.zaglio: unified sense of attached data table
    r:130305\s.zaglio: small bug and better help
    r:130106\s.zaglio: added test of sp_email and no more mssql2k compatible
    r:120724\s.zaglio: added @header=1
    r:120723\s.zaglio: added chk err of sp__select_astext
    r:110831\s.zaglio: a bug near @dbg when printing @lbody and removed extra output
    r:110531\s.zaglio: now delete attached files if come from selects
    r:110324\s.zaglio: added chk of html type into lbody
    r:110306\s.zaglio: added faciliy #src in @attach
    r:110213\s.zaglio: a small possible bug near #src and @lbody and expanded to max
    r:100919\s.zaglio: compatibility with mssql2k
    r:100612\s.zaglio: added #src
    r:100404\s.zaglio: added cc,bcc
    r:100403\s.zaglio: managed attach as sql
    r:100228\s.zaglio: send a mail
    t:sp__config 'smtp_server','????'  <- specify your smtp server
    t:sp__email 'stefano.zaglio@seltris.it','test','test'
    t:
        exec sp__email @to='stefano.zaglio@seltris.it',@cc='cc <stefano.zaglio@seltris.it>'
        exec sp__email @to='stefano.zaglio@seltris.it',@bcc='bcc <stefano.zaglio@seltris.it>'
    t:
        create table #src(lno int identity,line nvarchar(4000))
        insert #src select 'line1'
        insert #src select 'line2'
        exec sp__email @to='stefano.zaglio@seltris.it',@attach='#src'
        exec sp__email @to='stefano.zaglio@seltris.it',@body='#src'
        drop table #src
*/
CREATE proc [dbo].[sp__email]
    @to nvarchar(4000) = null,
    @subj nvarchar(4000) = null,
    @body nvarchar(max) = null,
    @from nvarchar(100) = null ,
    @smtp nvarchar(100) = null,
    @attach nvarchar(4000) = null,
    @id int = null out,
    @err nvarchar(4000) = null out,
    @at sysname = null,
    @cc nvarchar(4000) = null,@bcc nvarchar(4000)=null,
    @dbg int=0
    /*********************************************************************

    this stored procedure takes the parameters and sends an e-mail.
    all the mail configurations are hard-coded in the stored procedure.
    comments are added to the stored procedure where necessary.
    references to the cdosys objects are at the following msdn web site:
    http://msdn.microsoft.com/library/default.asp?url=/library/en-us/cdosys/html/_cdosys_messaging.asp

    http://support.microsoft.com/?scid=kb%3ben-us%3b312839&x=8&y=12
    ***********************************************************************/
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0

declare
    @hr int,@imsg int,@cmd varchar(255),
    @src varchar(255),@des varchar(500),
    @i int,@n int,@crlf nchar(2),@bit bit,
    @htmlbody bit,
    @obj nvarchar(4000),@tmp nvarchar(4000),@path nvarchar(512),
    @dt datetime,@ptr varbinary(64),
    @sql nvarchar(4000),
    @sp_email int,                      -- object id for sp_email
    @event int                          -- returned by sp_email

declare
    @temail tinyint,
    @tsubj smallint,@tto smallint,@tbody smallint,@tfrom smallint,
    @tsch smallint,@tattach smallint,@tsts smallint

declare @attachments table(id int identity,[name] sysname,del bit default(0))

/*  an idea...
    obj 'email.subj',@id=300 --> set sub id
    obj 'email.subj',@rid='email id',@dat1='subj',@dat2='attachments',@dt='insert time'
    obj 'email'             --> print below table
*/
select              --  rid         dat1            dat2                dt
    @temail =10,
    @tsubj  =300,   --  email id    subj            attachments         insert time
                    --  sched id    subj (when change and log is on ?)
    @tto    =301,   --  email id    -               to list             insert time
    @tbody  =302,   --  email id    -               body                insert time
    @tfrom  =303,   --  email id    from            -                   insert time
    @tattach=304,   --  email id    file/null       image file/select   insert time
    @tsch   =305,   --  email id    at param        -                   insert time
    @tsts   =306,   --  sched id    status/err nfo  -                   insert time

    @subj   =isnull(@subj,'(no subject)'),
    @body   =isnull(@body,''),
    @from   =isnull(@from,'noreply@noreply.com'),
    @crlf   =crlf
from dbo.fn__sym()

if @to is null and @id is null goto help

create table #blob(blob image)
declare @stdout table(lno int identity primary key,line nvarchar(4000))
create table #sp__email_tmp(lno int identity primary key,line nvarchar(4000))

if @smtp is null
    begin
    select @smtp=convert(sysname,dbo.fn__config('smtp_server',null))
    if @smtp is null goto err_smtp
    end

-- todo: if begin with +, is a wiki text page

-- called by Agent (sp__email @rid=??)
if not @id is null -- is the id of email record
    begin
    goto err_todo
    goto send_email
    end -- reschedule

-- adjust data
if isdate(@at)=1 select @dt=convert(datetime,@at)
if patindex(@at,'%get%date%')>0
    begin
    select @sql='set @dt='+@at
    exec sp_executesql @sql,N'@dt datetime out',@dt=@dt out
    end

select @to=replace(@to,',',';')
select @to=replace(@to,'|',';')
select @to=replace(replace(@to,'[','<'),']','>')
select @cc=replace(replace(@cc,'[','<'),']','>')
select @bcc=replace(replace(@bcc,'[','<'),']','>')

if @dbg>0
and (charindex('@',@to)=0 or charindex('@',isnull(@cc,'@'))=0)
    exec sp__printf '-- %s: warning, @ absent in @to and/or @cc',@proc

-- temp file for sql
exec sp__get_temp_dir @path out

if left(dbo.fn__sql_strip(substring(@body,1,32),null),7)='select '
    select  @attach=substring(@body,1,4000)+coalesce(';'+@attach,''),
            @body='see attachment'

if not object_id(@body) is null or not object_id('tempdb..'+@body) is null
    begin
    select @obj=@body,@body=null
    if @obj!='#src'
        begin
        exec sp__select_astext @obj,@out='#sp__email_tmp',@header=1
        select @body=isnull(@body,'')+isnull(line,'')+@crlf
        from #sp__email_tmp order by lno
        end
    else
        begin try
        exec sp_executesql N'
        select @body=isnull(@body,'''')+isnull(line,'''')+@crlf
        from #src order by lno',N'@body nvarchar(max) out,@crlf nvarchar(4)',
        @body=@body out,@crlf=@crlf
        end try
        begin catch
        -- print error_message()
        goto err_src
        end catch
    end

if substring(@body,1,6)='<html>' select @htmlbody=1

if @dbg=1
    begin
    exec sp__printf '-- %s attach:%s',@proc,@attach
    exec sp__printf '-- %s body:',@proc
    exec sp__printsql @body
    end

/*  explore attachments into @attachments and generate temp files to send
    in case there are particular attachments
*/
if not @attach is null
    begin
    -- test if want attach a table,view,sp recordset
    -- if charindex('.',@attach)=0 and dbo.fn__exists(@attach,null)=1

    select @i=1,@n=dbo.fn__str_count(@attach,';')
    while @i<=@n
        begin
        select @obj=dbo.fn__str_at(@attach,';',@i),@i=@i+1
        -- print dbo.fn__str_at('select from order by t;c:\file',';',2)

        if @dbg=1 exec sp__printf 'attaching:%s',@obj

        if not object_id(@obj) is null or not object_id('tempdb..'+@obj) is null
            select @obj='select * from '+quotename(@obj)
        if left(dbo.fn__sql_strip(left(@obj,32),null),7)='select '
            begin   -- attach a result of a query stored into a temp xls file
            select @tmp=@path+'\'+replace(convert(sysname,newid()),'-','')+'.htm'
            if @dbg=1 exec sp__printf 'out to:%s',@tmp
            exec @ret=sp__select_astext @obj,@out=@tmp,@dbg=0,@header=1
            if @ret!=0 goto err_sat
            insert @attachments([name],del) select @tmp,1
            end
        else
            begin -- attach files
            if charindex('*',@obj)>0 or charindex('?',@obj)>0
                begin   -- multiple files
                select @cmd='dir /b "'+@obj+'"'
                delete from @stdout
                insert @stdout exec master..xp_cmdshell @cmd
                insert @attachments([name]) select line from @stdout
                end
            else        -- single file
                insert @attachments([name]) select @obj
            end -- attach files

        end -- while

    end -- attach

-- ##########################
-- ##
-- ## SP_EMAIL integration
-- ##
-- ########################################################
-- goto send_email
select @sp_email=object_id('SP_EMAIL')
if not @sp_email is null
    begin

    -- the sp_email must have same parameters + @event, all out
    if ((select count(*)+1
         from syscolumns
         where id=object_id(@proc)
        )
        =
        (select count(*)
         -- select [sp_email].*
         from syscolumns [sp_email]
         left join syscolumns [sp__email]
         on [sp__email].id=object_id(@proc)
         and [sp_email].name=isnull([sp__email].name,'@event')
         where [sp_email].id=@sp_email and [sp_email].isoutparam=1
        )
       )
        begin
        if @dbg=1 exec sp__printf '-- %s: redirect to sp_email',@proc
        exec @ret=sp_email
            @event=@event out,
            @to =@to out,
            @subj=@subj out,
            @body=@body out,
            @from=@from out,
            @smtp=@smtp out,
            @attach=@attach out,
            @err=@err out,
            @at=@at out,
            @id=@id out,
            @cc=@cc out,
            @bcc=@bcc out,
            @dbg=@dbg out
        if @event!=0 goto ret
        if @event is null goto err_evt
        if @dbg=1 exec sp__printf '-- %s: continue from sp_email',@proc
        end
    else
        begin
        if @dbg=1
            exec sp__printf '-- %s:sp_email exists but with different sign',
                            @proc
        end
    end -- sp_email

send_email:

-- if scheduled mail, load all attachment into table
if not @at is null
    begin
    select @i=min(id),@n=max(id) from @attachments
    while (@i<=@n)
        begin
        select @obj=[name] from @attachments where id=@i
        -- load file into blob
        exec sp__file_read_blob @obj,@out='#blob.blob'
        -- select @tattach,@rid,left(@attach,256),blob from #blob
        truncate table #blob
        select @i=@i+1
        end
    -- exec sp__job @run='exec sp__email @id=%d',@at=@at,@p1=@id
    /*
        instead of use sp__job
        better use directly use of jobs proc and schedule a new send after each sent
    */
    end -- load into tmp

--************* create the cdo.message object ************************
select @cmd='cdo.message'
exec @hr = sp_oacreate @cmd, @imsg out
if @hr <>0 goto err_obj

--***************configuring the message object ******************
-- this is to configure a remote smtp server.
-- http://msdn.microsoft.com/library/default.asp?url=/library/en-us/cdosys/html/_cdosys_schema_configuration_sendusing.asp
select @cmd='configuration.fields("http://schemas.microsoft.com/cdo/configuration/sendusing").value'
exec @hr = sp_oasetproperty @imsg, @cmd,'2'
if @hr <>0 goto err_obj

-- this is to configure the server name or ip address.
-- replace mailservername by the name or ip of your smtp server.
select @cmd='configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpserver").value'
exec @hr = sp_oasetproperty @imsg,@cmd, @smtp
if @hr <>0 goto err_obj

-- save the configurations to the message object.
select @cmd='configuration.fields.update'
exec @hr = sp_oamethod @imsg, @cmd, null
if @hr <>0 goto err_obj

-- set the e-mail parameters.
select @cmd='To'
exec @hr = sp_oasetproperty @imsg, @cmd, @to
if @hr <>0 goto err_obj

select @cmd='CC'
exec @hr = sp_oasetproperty @imsg, @cmd, @cc
if @hr <>0 goto err_obj

select @cmd='BCC'
exec @hr = sp_oasetproperty @imsg, @cmd, @bcc
if @hr <>0 goto err_obj

select @cmd='From'
exec @hr = sp_oasetproperty @imsg, @cmd, @from
if @hr <>0 goto err_obj

select @cmd='Subject'
exec @hr = sp_oasetproperty @imsg, @cmd, @subj
if @hr <>0 goto err_obj

if exists(select null from @attachments)
    begin
    declare @hattach int
    select @i=min(id),@n=max(id) from @attachments
    select @cmd='AddAttachment'
    while (@i<=@n)
        begin
        select @obj=[name],@bit=del from @attachments where id=@i
        select @hattach=null
        exec @hr = sp_oamethod @imsg, @cmd, @hattach out, @obj, null

        if @bit=1
            begin
            select @sql='del /q "'+@obj+'"'
            exec master..xp_cmdshell @sql,no_output
            end
        if @hr <>0 goto err_obj

        select @i=@i+1
        end -- while
    end -- attach

-- if you are using html e-mail, use 'htmlbody' instead of 'textbody'.
if @htmlbody=1 select @cmd='HTMLBody' else select @cmd='TextBody'

exec @hr = sp_oasetproperty @imsg, @cmd, @body
if @hr <>0 goto err_obj

select @cmd='Send'
exec @hr = sp_oamethod @imsg, @cmd, null
if @hr <>0 goto err_obj

if @dbg=1 exec sp__printf '-- %s: email sent through "%s"',@proc,@smtp

exec @hr=sp_oadestroy @imsg
select @imsg=null
if @hr <>0 goto err_obj

dispose:
if not object_id('tempdb..#sp__email_tmp') is null drop table #sp__email_tmp
if not object_id('tempdb..#blob') is null drop table #blob

goto ret

-- =================================================================== errors ==

err_obj:
exec @hr = sp_oageterrorinfo @imsg, @src out, @des out
select @err=@cmd+':'+coalesce(@src,'')+';'+coalesce(@des,'')
exec @ret=sp__err @err,@proc
if not @imsg is null exec @hr=sp_oadestroy @imsg
goto ret

err_smtp:
select @sql='set at least the smtp server with\n'
           +'\tsp__config(''smtp_server'',''???'')'
exec @ret=sp__err @sql,@proc
select @err='no smtp server'
goto ret

err_todo:
exec @ret=sp__err 'todo',@proc
goto ret

err_sat:
exec sp__err 'sp__select_astext error from sp__email',@proc
goto ret

err_evt:
exec sp__err 'sp_email did not handle @event',@proc
goto ret

err_src:
exec sp__err 'bad #src format, see help',@proc
goto ret

-- ===================================================================== help ==

help:
create table #vars (id nvarchar(16),value sql_variant)
insert #vars values(
    '%smtp_server%',dbo.fn__config('smtp_server',null)
    )
insert #vars values(
    '%smtp_from%',coalesce(dbo.fn__config('smtp_from',null),@from)
    )

select @tmp='@event = @event out'
select @tmp=@tmp+','+@crlf+'        '+name+' = '+name+' out'
--select name -- sp__email
from syscolumns
where id=object_id(@proc)
order by colid

exec sp__usage @proc,'
Scope
    Send an email using the CDO.MESSAGE object.

Notes
    before do that, test the presence of SP_EMAIL and call it;
    if SP_EMAIL @event return a non zero value, exit without process
    because means that SP_EMAIL has managed data;
    SP_EMAIL must have same parameters all with out clause;

Parameters:
    @to     destination
    @subj   subject
    @from   by default is noreply@noreply.com
    @smtp   smtp server or ip (see global variables below)
    @err    returned error string by cdo.message.send command
    @at     (todo) schedule time
    @cc     carbon copy
    @bcc    black carbon copy
    @body   can be a text constant or a temp table name or a query
            if is a temp table, the content will be inserted into the body
            if is a query, the content will be attached as a HTML table file
    @attach can be single o multiple files separated by ;
            and wild card *,? are valid
            can be a query or a temp table
    @every  YYYYMMDD.HHmmSS or ... (todo)
    @dbg    not zero, show debug info

Glabal variables:
    With dbo.fn__global_set(''variable'',''value'')
    can be configured global variables for
        smtp_server     (actual:%smtp_server%)
        smtp_from       (actual:%smtp_from%)

Aids
    create table #src(lno int identity,line nvarchar(4000))
    exec sp_email
        %p1%
',@p1=@tmp
select @ret=-1
drop table #vars

-- ===================================================================== exit ==

ret:
return @ret
end -- sp__email