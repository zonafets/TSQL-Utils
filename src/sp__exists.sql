/*  leave this
    l:see LICENSE file
    g:utility
    v:100919\s.zaglio: show help about fn__Exists and can be used to test remote server obj existance
*/
CREATE proc sp__exists
    @dbg bit=0
as
begin
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname,  @ret int -- standard API: 0=OK -1=HELP, any=error id
select @proc='sp__exists', @ret=0

-- ========================================================= param formal chk ==
-- ============================================================== declaration ==
-- =========================================================== initialization ==
-- ======================================================== second params chk ==
-- ===================================================================== body ==
-- goto ret
-- =================================================================== errors ==
-- ===================================================================== help ==
help:
exec sp__usage 'fn__exists','
Scope
    show usage of fn__exists

Parameters
    @objects    name of obj or
            obj1,obj2,...   test if exists "obj1 and obj2 and ..."
            obj1|obj2|...   test if exists "obj1 or  obj2 or  ..."
                can verify existance of #temp objects
                sp__exists can test on remote servers (TODO)

    @type       can be null for any object or:
            fk  test if exists a foreign key for that object
            fl  meand that objX is a tbl.fld

    @dbg        run tests for all functionality (TODO)

Examples
    create table test_ex1(a int)
    print dbo.fn__exists(''test_ex1'',default)      -- 1
    print dbo.fn__exists(''test_ex1.a'',''fl'')     -- 1
    print dbo.fn__exists(''test_ex1.notx'',''fl'')  -- 0
    drop table test_ex1
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__exists