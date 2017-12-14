/*  leave this
    l:see LICENSE file
    g:utility,script
    todo:manage version
    v:130903\s.zaglio:renamed from sp__deprecated
    v:121004.1614\s.zaglio: used to delete D tagged objects objects
    t:sp__deprecated 'test_scripting'
*/
CREATE proc sp__deprecate
    @obj sysname = null,
    @ver numeric(10,4) = null
as
begin
set nocount on
declare @proc sysname, @err int, @ret int, @type sysname,@sql nvarchar(4000)
select @proc=object_name(@@procid),@err=0,@ret=0
if isnull(@obj,'')='' goto help

select @type=[drop]
from fn__sysobjects(@obj,default,default)
if @type is null return @ret
-- select distinct [type] from sys.objects
select @sql='drop '+@type+' '+quotename(@obj)
if not @sql is null
    begin
    raiserror('drop deprecated "%s"(%s)',10,1,@obj,@type) with nowait
    exec(@sql)
    end

return @ret
help:
exec sp__usage @proc,'
Scope
    drop deprecated object is exists
    (fast and smaller version of sp__drop)
'
return -1
end -- proc sp__deprecated