   /*  leave this
    l:see LICENSE file
    g:utility
    d:131117\s.zaglio: sp__config
    v:131117\s.zaglio: adapted to new cfg
    v:101019\s.zaglio: added autogeneration from sp__config.
    v:100424\s.zaglio: added inline-inmemory variables manag.
    v:100405\s.zaglio: uses of table if exists
    v:081218\S.Zaglio: usefull for personalization
    t:select dbo.fn__config('smtp_server',null)
    t:insert cfg select 0,0,'smtp_server','10.0.0.148'
*/
CREATE function [dbo].[fn__config](@var sysname,@default sql_variant=null)
returns sql_variant
as
begin
declare @v sql_variant
if left(@var,4)='mem.'
    begin
    select @var=substring(@var,5,128)
    select @v=
      case @var
      when 'mem.test1' then 'mem.test1' -- memory var test
      when 'mem.test' then 'mem.test' -- memory var test
      else null
      end -- case
    return @v
    end
if object_id('cfg') is null return @default
if left(@var,1) like '[0-9]'
    select @v=val from cfg where id=@var
else
    select @v=val from cfg where [key]=@var
return isnull(@v,@default)
end -- fn__config