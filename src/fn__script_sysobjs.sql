/*  leave this
    l:see LICENSE file
    g:utility,script
    v:131006\s.zaglio: adapted to change of flags.svr->flags.srv
    v:130926.1000,130217\s.zaglio:script_%;added enums(517)
    v:121031\s.zaglio:added script_act
    v:120517\s.zaglio:removed from core group
    v:120516.1900\s.zaglio: merged fn__script_events
    d:120516\s.zaglio: fn__script_events
    v:120504\s.zaglio: last change
    v:110620\s.zaglio: added typ field
    v:110527\s.zaglio: added new objs
    v:110510\s.zaglio: lists system objects
    t:select * from fn__script_sysobjs(default)
    t:select * from fn__script_sysobjs((select obj from tids))
    t:select * from fn__script_sysobjs((select ev from tids))
*/
CREATE function fn__script_sysobjs(@tid tinyint)
returns @objs table (
    tid tinyint,
    id int primary key,
    rid int,
    flags smallint,
    cod sysname
    )
as
begin
-- see entire list in
-- ms-help://MS.SQLCC.v9/MS.SQLSVR.v9.it/udb9/html/fb2a7bd0-2347-488c-bb75-734098050c7c.htm
-- http://msdn.microsoft.com/it-it/library/ms179503%28v=sql.105%29.aspx
declare
    @srv smallint,@db smallint,@tsrv smallint,@tdb smallint,
    @ts smallint,@tx smallint,@tt smallint,@tmask smallint,
    @ev tinyint, @obj tinyint, @grp tinyint

select top 1
    -- events
    @srv=srv|ddl,
    @db=db|ddl,
    @tsrv=[type]|srv|ddl,
    @tdb=[type]|db,
    -- sys.objects
    @ts=[sys],
    @tx=[exclude],
    @tt=[tmp]
from flags

select top 1
    @ev=ev,
    @obj=obj,
    @grp=grp
from tids

if @tid is null
insert @objs(   tid,    id,     rid,    flags,  cod)
        select  @grp,   500,     null,   @tmask, 'sys.objects'

if @tid is null or @tid=@obj
insert @objs(   tid,    id,     rid,    flags,  cod)
        select  @obj,   501,      500,   @ts,    'log'
union   select  @obj,   502,      500,   @ts,    'cfg'
union   select  @obj,   503,      500,   @ts,    'obj'
union   select  @obj,   504,      500,   @tt,    'tmp'
union   select  @obj,   505,      500,   @ts,    'ids'
union   select  @obj,   506,      500,   @ts,    'lng'
union   select  @obj,   507,      500,   @tx,    'dtproperties'
union   select  @obj,   508,      500,   @tt,    'tst'
union   select  @obj,   509,      500,   @tt,    'bak'
union   select  @obj,   510,      500,   @ts,    'flags'
union   select  @obj,   511,      500,   @ts,    'tids'
union   select  @obj,   512,      500,   @ts,    'log_ddl'
union   select  @obj,   513,      500,   @ts,    'tid'
union   select  @obj,   514,      500,   @ts,    'flg'
union   select  @obj,   515,      500,   @ts,    'iof'
union   select  @obj,   516,      500,   @ts,    'script_%'
union   select  @obj,   517,      500,   @ts,    'enums'
union   select  @obj,   518,      500,   @ts,    'act'

-- events
if @tid is null or @tid=@ev
insert @objs(   tid,    id,     rid,    flags,  cod)
        select  @ev,    010,      null,   @tsrv,  'DDL_SERVER_LEVEL_EVENTS'
union   select  @ev,    011,      010,    @srv,   'create_database'
union   select  @ev,    012,      010,    @srv,   'alter_database'
union   select  @ev,    013,      010,    @srv,   'drop_database'
union   select  @ev,    070,      010,    @tdb,   'DDL_DATABASE_LEVEL_EVENTS'

union   select  @ev,    080,      070,    @tdb,   'DDL_TABLE_VIEW_EVENTS'

union   select  @ev,    090,      080,    @tdb,   'DDL_TABLE_EVENTS'
union   select  @ev,    091,      090,    @db,    'create_table'
union   select  @ev,    092,      090,    @db,    'alter_table'
union   select  @ev,    093,      090,    @db,    'drop_table'

union   select  @ev,    100,      080,    @tdb,   'DDL_TABLE_EVENTS'
union   select  @ev,    101,      100,    @db,    'create_view'
union   select  @ev,    102,      100,    @db,    'alter_view'
union   select  @ev,    103,      100,    @db,    'drop_view'

union   select  @ev,    110,      080,    @tdb,   'DDL_INDEX_EVENTS'
union   select  @ev,    111,      110,    @db,    'create_index'
union   select  @ev,    112,      110,    @db,    'alter_index'
union   select  @ev,    113,      110,    @db,    'drop_index'
union   select  @ev,    114,      110,    @db,    'create_xml_index'

union   select  @ev,    130,      070,    @tdb,   'DDL_SYNONYM_EVENTS'
union   select  @ev,    131,      130,    @db,    'create_synonym'
union   select  @ev,    132,      130,    @db,    'drop_synonym'

union   select  @ev,    140,      070,    @tdb,   'DDL_FUNCTION_EVENTS'
union   select  @ev,    141,      140,    @db,    'create_function'
union   select  @ev,    142,      140,    @db,    'alter_function'
union   select  @ev,    143,      140,    @db,    'drop_function'

union   select  @ev,    150,      070,    @tdb,   'DDL_PROCEDURE_EVENTS'
union   select  @ev,    151,      150,    @db,    'create_procedure'
union   select  @ev,    152,      150,    @db,    'alter_procedure'
union   select  @ev,    153,      150,    @db,    'drop_procedure'

union   select  @ev,    160,      070,    @tdb,   'DDL_TRIGGER_EVENTS'
union   select  @ev,    161,      160,    @db,    'create_trigger'
union   select  @ev,    162,      160,    @db,    'alter_trigger'
union   select  @ev,    163,      160,    @db,    'drop_trigger'

union   select  @ev,    170,      070,    @tdb,   'DDL_TYPE_EVENTS'
union   select  @ev,    171,      170,    @db,    'create_type'
union   select  @ev,    173,      170,    @db,    'drop_type'

union   select  @ev,    200,      070,    @tdb,   'DDL_DATABASE_SECURITY_EVENTS'

union   select  @ev,    220,      200,    @tdb,   'DDL_USER_EVENTS'
union   select  @ev,    221,      220,    @db,    'create_user'
union   select  @ev,    222,      220,    @db,    'alter_user'
union   select  @ev,    223,      220,    @db,    'drop_user'

union   select  @ev,    230,      200,    @tdb,   'DDL_ROLE_EVENTS'
union   select  @ev,    231,      230,    @db,    'create_role'
union   select  @ev,    232,      230,    @db,    'alter_role'
union   select  @ev,    233,      230,    @db,    'drop_role'

union   select  @ev,    250,      200,    @tdb,   'DDL_SCHEMA_EVENTS'
union   select  @ev,    251,      250,    @db,    'create_schema'
union   select  @ev,    252,      250,    @db,    'alter_schema'
union   select  @ev,    253,      250,    @db,    'drop_schema'

union   select  @ev,    260,      200,    @tdb,   'DDL_GDR_DATABASE_EVENTS'
union   select  @ev,    261,      260,    @db,    'grant_database'
union   select  @ev,    262,      260,    @db,    'deny_database'
union   select  @ev,    263,      260,    @db,    'revoke_database'

-- special data events
union   select  @ev,    270,      null,   @tdb,   'DML_EVENTS'
union   select  @ev,    271,      270,    @tdb,   'insert_data'

-- special control events
union   select  @ev,    280,      null,   @tdb,   'CTRL_EVENTS'
union   select  @ev,    281,      280,    @tdb,   'group_objects'

return
end -- fn__script_sysobjs