/*  leave this
    l:see LICENSE file
    g:utility
    v:100919\s.zaglio: adapted to sp__err and other conventions
    v:100127\s.zaglio: added err return
    v:100104\s.zaglio: run a vbs
    c:originally from http://www.sql.ru/forum/actualthread.aspx?bid=1&tid=210409&hl
    t:
        declare @vbs nvarchar(4000),@out nvarchar(4000)
        select @vbs='
            function main()
            hello="hello world"
            ''print hello not allowed
            main=hello
            end function'
        exec sp__run_vbs @vbs,@out out
        print @out
        select @vbs='
            option explicit
            sub main()
            dim hello
            hello="hello"
            end sub'
        exec sp__run_vbs @vbs,@out out
        print @out
*/
CREATE proc [dbo].[sp__run_vbs]
    @vbs nvarchar(4000)=null,
    @out nvarchar(4000)=null out,
    @start sysname=null,
    @dbg bit=0
as
begin
set nocount on;
declare @proc sysname,@i int,@j int,@ret int
declare @hr int, @obj int,@msg nvarchar(4000),
        @cmd sysname

select @proc='sp__run_vbs',@out=null,@ret=0

if @vbs is null goto help

if @start is null
    begin
    select @i=charindex('function ',@vbs)
    select @j=charindex('(',@vbs,@i)
    if @i>0 and @j>0
        select @start=ltrim(rtrim(substring(@vbs,@i+9,@j-@i-9)))
    else
        begin
        select @i=charindex('sub ',@vbs)
        select @j=charindex('(',@vbs,@i)
        if @i>0 and @j>0
            select @start=ltrim(rtrim(substring(@vbs,@i+4,@j-@i-4)))
        end
    end
if @start is null goto err_start
if @dbg=1 exec sp__printf 'func:%s\ncode:\n%s',@start,@vbs

select @cmd='scriptcontrol'
execute @hr = sp_oacreate @cmd, @obj out;
if @hr!=0 goto err

select @cmd='language'
execute @hr = sp_oasetproperty @obj, @cmd, 'vbscript';
if @hr!=0 goto err

select @cmd='addcode'
execute @hr = sp_oamethod @obj, @cmd, null, @vbs;
if @hr!=0 goto err

select @cmd='run'
execute @hr = sp_oamethod @obj, @cmd, @out out, @start
if @hr!=0 goto err

if @dbg=1 exec sp__printf 'out:%s',@out
goto ret

err:
select @ret=@hr
declare @source varchar(255), @description varchar(255)
exec @hr = sp_oageterrorinfo @obj, @source out, @description out
exec @ret=sp__err 'cmd:%s; src:%s; des:%s; @out:%s',@proc,
                  @p1=@cmd,@p2=@source,@p3=@description,@p4=@out
goto ret

err_start:  exec @ret=sp__err 'starting function/sub not found or specified',@proc
            goto ret

help:
select @ret=-1

exec sp__usage @proc,'Parameters:
    @start  name of starting function or automatic
    '

ret:
if @obj!=0 exec sp_oadestroy @obj
return @ret
end -- [sp__run_vbs]