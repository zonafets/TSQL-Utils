/*  leave this
    l:see LICENSE file
    g:utility
    v:140107\s.zaglio: adaptation to 64bit OS
    v:130604\s.zaglio: small improvements near #files cmds
    v:130603\s.zaglio: adapted to fn__ftp_parse_lst
    v:120620\s.zaglio: added ms.svr.dir output->#files
    v:120618\s.zaglio: a bug near winscp date
    v:120503\s.zaglio: winscp automatic if hostkey specified
    v:120502\s.zaglio: added hostkey parameter,help and files correct list
    v:120427\s.zaglio: tested winscp and correct a bug near console output
    r:120426\s.zaglio: adding support for winscp
    v:120413\s.zaglio: adopted @ftpout
    v:120404\s.zaglio: a bug near cmd #files (do not modify #ftpcmd)
    v:120204\s.zaglio: added support to #files for non unix svr
    v:120111\s.zaglio: added listing to #files
    v:111122\s.zaglio: added error 550 (cd)
    v:110715.1050\s.zaglio: added @cmd
    v:110530\s.zaglio: commented gen of ftpout and added trace of not managed error "file not found"
    v:110527\s.zaglio: added result ok rename ok
    v:110512\s.zaglio: added tests and delete ok
    v:110330\s.zaglio: call ms ftp.exe and execute content of #ftpcmd
    t:sp__ftp @opt='check'
*/
CREATE proc sp__ftp
    @login nvarchar(1024)=null,
    @cmds nvarchar(4000)=null,
    @opt sysname=null,
    @dbg int=0
as
begin
set nocount on
set language us_english -- this dont change caller language
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0),
       @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

-- ========================================================= param formal chk ==
if @login is null
or (object_id('tempdb..#ftpcmd') is null and @dbg=0 and @cmds is null)
    goto help

-- ============================================================== declaration ==
declare
    @tmp nvarchar(1024),@crlf nvarchar(2),
    @svr sysname,@db  sysname,@uid sysname,@pwd sysname,
    @ftp_svr sysname,@ftp_uid sysname,@ftp_pwd sysname,@ftp_path sysname,
    @ftp_key sysname,@winscp_path nvarchar(512),
    @i int,@ftp_cmd sysname,
    @file_path nvarchar(1024),@cmd nvarchar(4000),@file sysname,
    @files bit,@drop_files bit,@winscp bit,
    @pf nvarchar(512)                       -- path find


declare @ftpout table(lno int identity, line nvarchar(4000))
declare @ftp_msg table(code nvarchar(3))

if left(@cmds,6)='#files'
    begin
    -- if @cmds results null, are used commands of #ftpcmd
    select @files=1,@cmds='dir '+nullif(substring(@cmds,8,128),'')
    if object_id('tempdb..#files') is null
        begin
        select @drop_files=1
        create table #files (
            id int identity,
            rid int null,           -- for subdirs
            [flags] smallint,       -- if &32=32 is a <DIR>
            [key] nvarchar(256),    -- obj name
            dt datetime,            -- creation date
            n int null              -- size in bytes
            )
        end
    else
        select @drop_files=0
    end -- files cmd
else
    select @files=0

-- ok msg: do not return error
insert @ftp_msg(code)
        select '150'    -- Opening ASCII mode data connection for file list.
union   select '200'    -- command ok
union   select '220'    -- welcome or identification "Microsoft FTP Service"
union   select '226'    -- Transfer complete.
union   select '221'    -- quitted
union   select '230'    -- User XXXX logged in.
union   select '250'    -- file deleted succesfully
union   select '331'    -- Password required for wcarevivisol-mi3.
union   select '350'    -- File exists, ready for destination name. (rename)


create table #ftpsrc(lno int identity, line nvarchar(4000))

-- =========================================================== initialization ==
select
    @crlf=crlf,
    @winscp = charindex('|winscp|',@opt)
from fn__sym()

select
    @ftp_svr=dbo.fn__str_at(@login,'|',1),
    @ftp_uid=dbo.fn__str_at(@login,'|',2),
    @ftp_pwd=dbo.fn__str_at(@login,'|',3),
    @ftp_path=dbo.fn__str_at(@login,'|',4),
    @ftp_key=dbo.fn__str_at(@login,'|',5)

-- ======================================================== second params chk ==
if coalesce(@ftp_key,'')!='' select @winscp=1

if @winscp=1
    begin
    select @winscp_path='winscp\winscp.com'
    exec sp__os_whereis @winscp_path out
    if @winscp_path is null goto err_wnf -- winscp not found
    end

-- ===================================================================== body ==

-- write the command file
exec sp__get_temp_dir @tmp out

select @file='tmp_'+replace(convert(sysname,newid()),'-','_')+'.txt'
select @file_path=@tmp+'\'+@file

if @dbg>0
    exec sp__printf 'svr:%s\nuid:%s\npwd:%s\npath:%s\nkey:%s',
                    @ftp_svr,@ftp_uid,@ftp_pwd,@ftp_path,@ftp_key

-- ftp login commands
if @winscp=0
    begin
    insert #ftpsrc(line) values('open '+@ftp_svr)
    insert #ftpsrc(line) values(@ftp_uid)
    insert #ftpsrc(line) values(@ftp_pwd)
    end
else
    insert #ftpsrc(line)
    select 'open '+@ftp_uid+':'+@ftp_pwd+'@'+@ftp_svr+
           case
           when coalesce(@ftp_key,'')!=''
           then ' -hostkey="'+@ftp_key+'"'
           else ''
           end

--insert #ftpsrc(line) values('prompt')
insert #ftpsrc(line) values('binary')
if coalesce(@ftp_path,'')!='' insert #ftpsrc(line) values('cd "'+@ftp_path+'"')
insert #ftpsrc(line) values('lcd "'+@tmp+'"')

if not object_id('tempdb..#ftpcmd') is null
and (@files=0 or @cmds is null)
    insert #ftpsrc(line) select line from #ftpcmd order by lno

if not @cmds is null
    begin
    if @files=1
        insert #ftpsrc(line) select @cmds
    else
        insert #ftpsrc(line)
        select token
        from fn__str_table(@cmds,'\\n')
        order by pos
    end

if @dbg=2
    begin
    insert #ftpsrc(line) values('put "'+@file_path+'"')
    insert #ftpsrc(line) values('ls')
    insert #ftpsrc(line) values('delete "'+@file+'"')
    end
insert #ftpsrc(line) values('bye')

exec sp__file_write @file_path,@table='#ftpsrc',@addcrlf=1

/*  120503\s.zaglio:
if @dbg>0
    begin
    select @cmd='dir "%s" & type "%s"'
    exec sp__str_replace @cmd out,'%s',@file_path
    exec master..xp_cmdshell @cmd
    end
*/

-- now ftp
-- if @dbg=1
if @winscp=0
    select @cmd='ftp -v -d -s:"%file%" '-- +@ftp_svr
else
    select @cmd=@winscp_path+' /script="%file%"'
-- else
--    select @cmd='ftp -v -s:"%file%" %svr%'

exec sp__str_replace @cmd out,'%file%|%svr%',@file_path,@ftp_svr

if @dbg>0 exec sp__printf 'cmd:%s',@cmd

-- ##########################
-- ##
-- ## call external ftp util
-- ##
-- ########################################################
insert @ftpout(line) exec @ret=master..xp_cmdshell @cmd

-- it looks like ftp client(or iis server) add a #13 at the end of each line so i simply drop all #13
update @ftpout set line=replace(rtrim(line),char(13),'')

-- manage not managed errors
if exists(
    select null from @ftpout
    where (lno>@i or @i is null)
    and (line like '%connection refused'
        or line like 'unknown host%'
        or line like 'host sconosciuto%'
        or line like 'accesso non riuscito%'
        or line like 'invalid command%'
        or line like 'comando non valido'
        or line like '%file not found'
        or line like '%file non trovato'
        )
    )
    select @ret=-3

if exists(
    select null
    from @ftpout
    where 1=1
    and isnumeric(left(line,3))=1 and substring(line,4,1)=' ' -- XXX_
    and not left(line,3) in (select code from @ftp_msg)
    )
    begin
    -- select * from ftpout
    /* 110530\s.zaglio:
    if object_id('ftpout') is null
        create table ftpout(lno int, code nvarchar(3),err bit,line nvarchar(4000))
    insert ftpout
    select lno,left(line,3) code,case when left(line,3) in (select code from @ftp_msg) then 1 else 0 end as err,line
    from #ftpout
    */
    select @ret=-2
    end

if @dbg>0
    begin
    select
        lno,
        case when
            isnumeric(left(line,3))=1 and substring(line,4,1)=' ' -- XXX_
            and not left(line,3) in (select code from @ftp_msg)
        then '***'
        else null
        end as err,
        line
    into #ftpoutdbg
    from @ftpout
    order by lno
    exec sp__select_astext 'select * from #ftpoutdbg order by lno',@header=1
    drop table #ftpoutdbg
    end

if @ret=0 and @files=1
    begin
    declare @lng sysname
    select @lng=@@language
    set language english -- for jan, ...
    insert #files([key],flags,dt,n)
    select [name],case dir when 'd' then 32 else 0 end,
           convert(datetime,[timestamp],100),size
    from @ftpout f
    cross apply fn__ftp_parse_list(f.lno,f.line,default)
    set language @lng
    end -- files

-- remove temp
-- if @dbg>0 goto skip_del      -- enable this only temporary because leave public tmp
select @cmd='del "'+@file_path+'"'
exec master..xp_cmdshell @cmd,no_output
skip_del:

if @files=1 and (@drop_files=1 or @dbg=1)
    begin
    if @dbg=1 exec sp__select_astext 'select * from #files',@header=1
    if @drop_files=1
        begin
        select * from #files
        drop table #files
        end
    end

if @dbg>0
    exec sp__select_astext 'select * from #ftpsrc order by lno',@header=1

if object_id('tempdb..#ftpout') is null
    select line from @ftpout order by lno
else
    insert #ftpout(line) select line from @ftpout order by lno

drop table #ftpsrc

goto ret

-- =================================================================== errors ==

err_wnf: exec @ret=sp__err 'WINSCP not found',@proc; goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    wrapper for MS ftp.exe and execute content of #ftpcmd
    and return results into #ftpout (if exists or are printed)

Parameters
    @login      ftp_svr|uid|pwd|[ftp_path]|[hostkey]

    @cmds       test or fast command (can be multiple if separated by \\n)
                Accept special command for files listing
                #files     or      #files:pattern     (use *)
                if present, stores results into
                    create table #files (
                        id int identity,
                        rid int null,           -- for subdirs
                        [flags] smallint,       -- if &32=32 is a <DIR>
                        [key] nvarchar(256),    -- obj name
                        dt datetime,            -- creation date
                        n int null              -- size in bytes
                        )
                (see sp__dir)

    @opt        options     description
                winscp      force use of winscp,
                            automatic if hostkey is specified

    @dbg        1=test connection and show dbg info
                2=test upload list and delete
    #ftpcmd     list of ftp commands to execute
    #ftpout     (optional) append the output to this (keeping original data)
    return      0 if ok, -1 if help, -2 if a non ok replies
                ok replies are
                200 type set to I
                220 Service ready for new user.
                221 Service closing control connection.
                    Logged out if appropriate.
                230 User logged in, proceed.
                250 file deleted succesfully
                331 User name okay, need password.
                350 File exists, ready for destination name. (rename)
                550 failed change directory (cd)

                For all others see http://www.ietf.org/rfc/rfc2821.txt

Notes
    create table #ftpcmd(lno int identity,line nvarchar(4000))
    create table #ftpout(lno int identity,line nvarchar(4000))

Examples
    sp__ftp "10.0.0.2|uid|pwd","ls"
    sp__ftp "10.0.0.1|uid|pwd||ssh-rsa 2048 5c:a4:...","ls",@opt="winscp"

'

select @winscp_path='winscp\winscp.com'
exec sp__os_whereis @winscp_path out
if not @winscp_path is null exec sp__printf '-- winscp path: %s',@winscp_path
select @winscp_path='ftp.exe'
exec sp__os_whereis @winscp_path out
if not @winscp_path is null exec sp__printf '-- ftp path: %s',@winscp_path

select @ret=-1

-- ===================================================================== exit ==
ret:
if @dbg>0 exec sp__printf 'return: %d',@ret
return @ret

end -- proc sp__ftp