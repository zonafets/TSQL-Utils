/*  leave this
    l:see LICENSE file
    g:utility
    k:config,utility,application,fn_config,fn__config
    v:131125\s.zaglio: when not find into _config, do NOT search in __config
    v:131122\s.zaglio: mixed and moved code from sp__job_status
    r:131117\s.zaglio: multiple config search
    t:select dbo.fn__config_app('.test','nop')                      -- from _ or nop
    t:select dbo.fn__config_app('.test|test','nop')                 -- from _
    t:select dbo.fn__config_app('.test1|noexists1|test1','nop')     -- from __
    t:select dbo.fn__config_app('.test1|noexists1|noexists2','nop') -- nop
    t:select dbo.fn__config('test','nop'),dbo.fn__config('test1','nop')
    t:drop function fn_config
    t:select dbo.fn__config_app('.test|test','nop')                 -- from __
*/
CREATE function fn__config_app(@vars nvarchar(256), @default sql_variant)
returns sql_variant
as
begin
/*
drop function fn_config
create function fn_config(@param sysname,@defval sysname)
returns sysname as begin declare @s sysname
    select @s=isnull(case @param when 'TEST' then 'from _' else null end,@defval)
return @s
end
*/
declare @v sql_variant,@var sysname,@fn_id int
select @fn_id=isnull(object_id('fn_config'),0)
-- do a minimal check to ensure a sign compatibility with
-- generic application FN_CONFIG
declare cs cursor local for select token from fn__str_split(@vars,'|')
open cs
while 1=1
    begin
    fetch next from cs into @var
    if @@fetch_status!=0 break
    if left(@var,1)='.'
        begin
        select @var=substring(@var,2,256)
        if @fn_id!=0
            select @v=dbo.fn_config(@var,cast(@default as nvarchar(4000)))
        end
    else
        select @v=dbo.fn__config(@var,@default)

    if @v=@default select @v=null
    if not @v is null break
    end -- cursor cs
close cs
deallocate cs

select @v=isnull(@v,@default)
return @v
end  -- fn__config_app