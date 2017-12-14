/*  leave this
    l:see LICENSE file
    g:utility
    k:deprecate,list
    d:140127\s.zaglio:fn__street
    d:140127\s.zaglio:sp_info
    d:140103\s.zaglio:sp_find
    d:130806\s.zaglio:sp__parse
    d:130806\s.zaglio:sp__parse_test
    v:140103\s.zaglio:list only objects to deprecate
*/
CREATE proc sp__deprecated
as
begin
set nocount on
declare @proc sysname
select  @proc=object_name(@@procid)
-- ===================================================================== help ==
exec sp__usage @proc,'
Scope
    give only a list of generic (old) objects deprecated or obsolete

Notes
    Eventually you can describe the reason here.

Examples
    sp__parse,sp__parse_test:   never used, will be replaced by a generic parser
                                extracted from golden parser
'

-- ===================================================================== exit ==
ret:
return -1
end -- sp__deprecated