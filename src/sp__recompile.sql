/*  leave this
    l:see LICENSE file
    g:utility
    v:090811\s.zaglio: removed apply of alter on #src'
    v:090801\s.zaglio: exapanded to use #src and sp__script_alter
    v:090720\s.zaglio: replaced ##tmp... with #src for multi thread
    v:090705\s.zaglio: added drop of tmp table
    v:090623\s.zaglio: recompile a nested/connected object
    t:sp__recompile 'fn_mat_all',@dbg=1
    t:sp__recompile 'fn_mat_all',@dbg=1,@svr='gamon',@db='ramses',@uid='sa',@pwd='',@tofile=1
    t:
        create table #src (lno int identity(10,10),line nvarchar(4000))
        set nocount on
        insert into #src(line) select 'create table test_sp_recompile ('
        insert into #src(line) select '         id int'
        insert into #src(line) select '         )'
        exec sp__recompile '#src',@dbg=1,@srv='gamon',@db='ramses',@uid='sa',@pwd='',@tofile=1
        select * from test_sp_recompile
        drop table test_sp_recompile
        drop table #src
*/
CREATE proc [dbo].[sp__recompile]
    @obj sysname=null,      -- if #src use this (without alter)
    @srv sysname=null,
    @db sysname=null,
    @uid sysname=null,
    @pwd sysname=null,
    @tofile bit=0,
    @dbg bit=0
as
begin
set nocount on
declare
    @r int,
    @t datetime,
    @msg nvarchar(4000),
    @sql nvarchar(4000),
    @sql1 nvarchar(4000),
    @sql2 nvarchar(4000),
    @sql3 nvarchar(4000),
    @line nvarchar(4000),
    @l int,@i int,@j int,@n int,@tmp sysname,@alter nvarchar(4000),
    @crlf nvarchar(2), @step smallint,
    @file sysname,
    @maxscp int

select
    @r=0,
    @crlf=char(13)+char(10),@step=10,@tmp='#src',
    @sql='',@sql1='',@sql2='',@sql3=''

if @obj is null goto help

if @obj!=@tmp
    begin
    create table #src (lno int identity(10,10),line nvarchar(4000))
    exec sp__script @obj,@out=@tmp,@step=@step -- ,@dbg=@dbg

    -- calculate size of script
    exec sp__script_size @i out,@msize=@maxscp out,@go=0   -- because alter want the 'go'
    if @i>@maxscp select @tofile=1
    -- change create [...] with alter [...]
    exec sp__script_alter @alter=1,@step=@step,@dbg=0
    end

exec sp__script_reduce @normalize=8 -- remove while line on top and bottom

if @tofile=1
    begin
    set @file='%temp%\tmp_'+replace(convert(nvarchar(48),newid()),'-','_')+'.sql'
    end

-- load script and compile it
if @tofile=0
    exec sp__script_cache @sql out,@sql1 out,@sql2 out,@sql3 out,@go=0
else    -- to file
    begin
    if @dbg=1 print 'output to file:'+coalesce(@file,'(null)')
    exec sp__file_write @file out,@table='#src',@addcrlf=1,@dbg=@dbg
    end

if @dbg=1 and @tofile=0 exec sp__script '#src'
if @dbg=1 exec sp__elapsed @t out,'recompiling at:'
if @tofile=0 and @dbg=1 print '(memory compiling)'
if @tofile=0 exec sp__script_run
if @tofile=1
    begin
    if @srv is null or @db is null or @uid is null or @pwd is null goto err_tofile
    declare @cmd nvarchar(4000)
    set @cmd='osql -S'+@srv+' -d'+@db+' -U'+@uid+' -P'+@pwd+' -i'+@file+' -n'
    if @dbg=1 print @cmd
    create table #cmdout (lno int identity,line nvarchar(4000))
    insert into #cmdout
    exec master..xp_cmdshell @cmd
    if @dbg=1 select * from #cmdout
    exec sp__drop @file  -- sp__usage 'sp__select'
    if exists(select * from #cmdout)
        begin
        select @r=1
        select @msg='#!'+coalesce(line,'') from #cmdout where lno=1
        select @msg=@msg+@crlf+coalesce(line,'') from #cmdout where lno=2
        select @msg=@msg+@crlf+coalesce(line,'') from #cmdout where lno=3
        select @msg=@msg+@crlf+coalesce(line,'') from #cmdout where lno=4
        if @msg='#!' select @msg=null,@r=0
        end
    end -- to file
if @dbg=1 exec sp__elapsed @t out,'compiled in ms:'

if @obj!=@tmp
    exec sp__drop @tmp

goto ret

err_nocreate:   select @r=-1,@msg='#!create keyword not found' goto ret
err_type:       select @r=-2,@msg='#!unk type' goto ret
err_con:        select @r=-3,@msg='#!no concurrency sp or error previous error' goto ret
err_src:        select @r=-4,@msg='#!source type not known' goto ret
err_tofile:     select @r=-5,@msg='#!login info mandatory' goto ret

help:
select @msg ='parameters:\n'
            +'\tcan be #src passed by caller formatted as "lno_line"\n'
            +'\tcan be a name of a table formatted as "lno_line"\n'
            +'\tcan be a file\n'
            +'The format "lno_line" is lno int,line nvarchar(4000)\n'
exec sp__usage 'sp__recompile',@extra=@msg
select @msg=null

ret:
if not @msg is null exec sp__printf @msg
return @r
end