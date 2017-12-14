/*  leave this
    l:see LICENSE file
    g:utility
    v:120726\s.zaglio: print more info
    v:110324\s.zaglio: modern version
    v:081130\S.Zaglio: rewrited version for general porpouse backup. See also sp__restore
    t:declare @r int exec @r=sp__backup '%temp%',@dbg=1,@opt='doit' exec sp__printf 'result:%s',@r
    t:xp__cmdshell 'del "%temp%\*.bak"'
*/
CREATE proc [dbo].[sp__backup]
    @device     nvarchar(1024)=null out,
    @db         sysname=null,
    @opt        sysname=null,
    @dbg        int=0
as
begin
set nocount on

declare @proc sysname,@ret int
select  @proc=object_name(@@procid),@ret=0,
        @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

if @device is null goto help

declare @tmp nvarchar(1024),@dt sysname,@sql nvarchar(4000)

if @db is null select @db=db_name()
select @dt=convert(nvarchar(16),getdate(),12)+'_'+left(replace(convert(nvarchar(16),getdate(),108),':',''),4)

exec sp__get_temp_dir @tmp out
select @tmp=@tmp+'\'+@db+'_'+@dt+'.bak'

if @dbg=1 exec sp__printf 'dev=%s, tmp=%s, db=%s, dt=%s',@device, @tmp,@db,@dt

-- return the temp file name
if @device='%temp%' select @device=@tmp

select @device=replace(@device,'%db%',@db)
select @device=replace(@device,'%t%',@dt)

if @dbg=1 exec sp__printf 'dev=%s, tmp=%s, db=%s, dt=%s',@device, @tmp,@db,@dt

-- if not dest path specified
if left(@device,2)='\\' goto err_net

/*
for net feature
if not @move_to is null begin

    declare @src nvarchar(512)
    declare @cmd nvarchar(1024)
    set @src=@dst
    set @bak=dbo.fn__str_at(@move_to,'|',1)
    set @uid=coalesce(dbo.fn__str_at(@move_to,'|',2),'')
    set @pwd=coalesce(dbo.fn__str_at(@move_to,'|',3),'')

    if @uid<>'' or @pwd<>'' begin
        set @i=charindex('\\',@bak)
        if @i<>0 set @i=@i+2
        set @i=charindex('\',@bak,@i)
        set @cmd='net use '+substring(@bak,1,@i-1)+' '+@pwd+' /user:'+@uid
        if @dbg=1 and @simul=0 print @cmd
        if @simul=1 print @cmd
        if @simul=0 exec sp__run_cmd @cmd,@tmp_table=@tmp_table out,@nodrop=1,@nooutput=@out
    end
    if @simul=0 begin            -- insert backup command
        set @cmd='insert into '+@tmp_table+' values ('''+dbo.fn__inject(@sql)+''')'
        exec(@cmd)
    end
-- t: sp__backup @device='\\gamon\Backup\%db_name%.bak|seldom\stefano|prova',@simul=0
    set @cmd='copy "'+@src+'" "'+@bak+'"'
    if @dbg=1 and @simul=0 print @cmd
    if @simul=0 exec sp__run_cmd @cmd,@tmp_table=@tmp_table out,@nodrop=1,@nooutput=@out
    else print @cmd
    if @uid<>''  or @pwd<>'' begin
        set @i=charindex('\\',@bak)
        if @i<>0 set @i=@i+2
        set @i=charindex('\',@bak,@i)
        set @cmd='net use '+substring(@bak,1,@i-1)+' /delete'
        if @dbg=1 and @simul=0 print @cmd
        if @simul=0 exec sp__run_cmd @cmd,@tmp_table=@tmp_table,@nodrop=1,@nooutput=@out
        else print @cmd
    end

    -- delete local backup
    set @cmd='del /q "'+@src+'"'
    if @dbg=1 and @simul=0 print @cmd
    if @simul=0 exec sp__run_cmd @cmd,@tmp_table=@tmp_table out,@nodrop=1,@nooutput=@out
    else print @sql
    end
*/
select @sql ='BACKUP DATABASE ['+isnull(@db,'?db?')+']'
            +' TO  DISK = ''' + isnull(@device,'?device?') + ''''
            +' WITH NAME = N''FROM SP__BACKUP'',  STATS = 10'

if charindex('|diff|',@opt)>0
    select @sql=@sql+',NOSKIP,NOINIT,NOUNLOAD,DIFFERENTIAL'
else
    select @sql=@sql+',INIT,FORMAT'

if charindex('|doit|',@opt)>0
or charindex('|run|',@opt)>0
    begin
    exec(@sql)
    if @@error!=0 select @ret=-2
    else
        exec sp__printf '-- sp__restore new_db,''%s'',@opt=''run''',@device
    end
else
    exec sp__printf '%s',@sql

dispose:
goto ret

-- =================================================================== errors ==
err_net:    exec @ret=sp__err 'not yet implemented',@proc goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    backup a db to a file that can be local, a temp dir or a network path

Parameters
    @device     file or net path or %temp% if want a fast backup into tmp dir
                if start with \\ can add usr and pwd at end, separated by |
                can contain %db%, %t% that will be replaced with db name and time stamp
    @db         if not current db
    @opt        options
                run     modern version of old "doit"
                doit    execute it effectivelly instead of print instruction
                diff    do a differential backup
'
select @ret=-1

ret:
return @ret
end -- sp__backup