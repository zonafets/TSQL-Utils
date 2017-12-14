/*  leave this
    l:see LICENSE file
    g:utility
    d:131208\s.zaglio:sp__get_tmp
    v:131208\s.zaglio:added opt TF and TEST
    v:130830.1000\s.zaglio:remove final \ if exists and added help
    v:100402\s.zaglio:returned dir is without final \
    v:090910\s.zaglio:adapted to use sp__get_env
    v:080414\s.zaglio:creation
    t:sp__get_temp_dir @opt='tf|test'
*/
CREATE proc [dbo].[sp__get_temp_dir]
    @dir nvarchar(512) = null output,
    @opt sysname = null
as
begin
set nocount on
declare @tf bit,@test bit
if not @opt is null
    begin
    select @opt='|'+@opt+'|'
    select @tf=charindex('|tf|',@opt),@test=charindex('|test|',@opt)
    end
else
    select @tf=0,@test=0

exec sp__get_env @dir out,'temp'
if right(@dir,1)='\' select @dir=left(@dir,len(@dir)-1)
if @tf=1 select @dir=@dir+'\tmp_'+replace(convert(sysname,newid()),'-','_')
if @test=0
and (@@nestlevel>1 -- in remote is 1 even if called by a local sp ...
or dbo.fn__isconsole()=0)    -- ... this solve the above problem
     return

if @test=1
    begin
    exec sp__printf '%s',@dir
    return
    end

declare @proc sysname
select @proc=object_name(@@procid)
exec sp__usage @proc,'
Scope
    return value of OS "temp" environment variable
    without last \.

Notes
    if called under a sp, this help will not shown

Parameters
    @dir    is the output var that will contain the path
    @opt    options
            tf      attach a temp file name from newid()
            test    print output

Example
    declare @tmp nvarchar(512)
    exec %proc% @tmp out
    print @tmp                      -- will return "%p1%"
',@p1=@dir
end -- sp__get_temp_dir