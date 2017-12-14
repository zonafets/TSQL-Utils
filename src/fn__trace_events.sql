/*  leave this
    l:see LICENSE file
    g:utility
    v:131006\s.zaglio:svr->srv
    v:120213\s.zaglio:back to cod/des notation
    v:110312\s.zaglio:list sysobjects types
    t:select * from fn__trace_events(default,default,default)
    t:sp__find 'events'
*/
CREATE function fn__trace_events(@p1 bit=null,@p2 bit=null,@p3 bit=null)
returns @events table (
    id int,rid int,flags smallint null,
    cod sysname
    )
as
begin
-- see entire list in
-- ms-help://MS.SQLCC.v9/MS.SQLSVR.v9.it/udb9/html/fb2a7bd0-2347-488c-bb75-734098050c7c.htm
declare @svr smallint,@db smallint
select top 1 @svr=srv|ddl,@db=db|ddl from flags
insert @events(id,      rid,    flags,  cod)
        select 010,      null,   @svr,   'DDL_SERVER_LEVEL_EVENTS'
union   select 011,      010,    @svr,   'create_database'
union   select 012,      010,    @svr,   'alter_database'
union   select 013,      010,    @svr,   'drop_database'
union   select 070,      010,    @db,    'DDL_DATABASE_LEVEL_EVENTS'

union   select 080,      070,    @db,    'DDL_TABLE_VIEW_EVENTS'

union   select 090,      080,    @db,    'DDL_TABLE_EVENTS'
union   select 091,      090,    @db,    'create_table'
union   select 092,      090,    @db,    'alter_table'
union   select 093,      090,    @db,    'drop_table'

union   select 100,      080,    @db,    'DDL_TABLE_EVENTS'
union   select 101,      100,    @db,    'create_view'
union   select 102,      100,    @db,    'alter_view'
union   select 103,      100,    @db,    'drop_view'

union   select 110,      080,    @db,    'DDL_INDEX_EVENTS'
union   select 111,      110,    @db,    'create_index'
union   select 112,      110,    @db,    'alter_index'
union   select 113,      110,    @db,    'drop_index'
union   select 114,      110,    @db,    'create_xml_index'

union   select 130,      070,    @db,    'DDL_SYNONYM_EVENTS'
union   select 131,      130,    @db,    'create_synonym'
union   select 132,      130,    @db,    'drop_synonym'

union   select 140,      070,    @db,    'DDL_FUNCTION_EVENTS'
union   select 141,      140,    @db,    'create_function'
union   select 142,      140,    @db,    'alter_function'
union   select 143,      140,    @db,    'drop_function'

union   select 150,      070,    @db,    'DDL_PROCEDURE_EVENTS'
union   select 151,      150,    @db,    'create_procedure'
union   select 152,      150,    @db,    'alter_procedure'
union   select 153,      150,    @db,    'drop_procedure'

union   select 160,      070,    @db,    'DDL_TRIGGER_EVENTS'
union   select 161,      160,    @db,    'create_trigger'
union   select 162,      160,    @db,    'alter_trigger'
union   select 163,      160,    @db,    'drop_trigger'

union   select 170,      070,    @db,    'DDL_TYPE_EVENTS'
union   select 171,      170,    @db,    'create_type'
union   select 173,      170,    @db,    'drop_type'

union   select 200,      070,    @db,    'DDL_DATABASE_SECURITY_EVENTS'

union   select 220,      200,    @db,    'DDL_USER_EVENTS'
union   select 221,      220,    @db,    'create_user'
union   select 222,      220,    @db,    'alter_user'
union   select 223,      220,    @db,    'drop_user'

union   select 230,      200,    @db,    'DDL_ROLE_EVENTS'
union   select 231,      230,    @db,    'create_role'
union   select 232,      230,    @db,    'alter_role'
union   select 233,      230,    @db,    'drop_role'

union   select 250,      200,    @db,    'DDL_SCHEMA_EVENTS'
union   select 251,      250,    @db,    'create_schema'
union   select 252,      250,    @db,    'alter_schema'
union   select 253,      250,    @db,    'drop_schema'

union   select 260,      200,    @db,    'DDL_GDR_DATABASE_EVENTS'
union   select 261,      260,    @db,    'grant_database'
union   select 262,      260,    @db,    'deny_database'
union   select 263,      260,    @db,    'revoke_database'

return
end -- fn__trace_events