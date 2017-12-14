/*  leave this
    l:see LICENSE file
    g:utility
    v:140109.1000\s.zaglio:moved call of sp__job_test into sp__utility_setup_test
    v:140103\s.zaglio:add call of sp__job_test
    v:131223.1110\s.zaglio:log_ddl.svr->srv
    v:131212\s.zaglio:removed use of sp__printf
    v:131125\s.zaglio:moved here the update of log_ddl
    v:130922\s.zaglio:about cfg
    v:130830\s.zaglio:managed a problem of fn__find when fnd is wrong
    v:130828\s.zaglio:due difficult to understand clr status I changed strategy
    v:130730.1800\s.zaglio:removed test of 130606 because too generic; added synonym
    v:130606\s.zaglio:added test for use of old sp__printf
    v:130528\s.zaglio:tuned test about CLR
    v:121209\s.zaglio:added check for awe m.m.
    v:121031\s.zaglio:commented clr and modified assembly for 2.0x32
    v:120920\s.zaglio:added opt run
    v:120907\s.zaglio:added script_act
    v:120824\s.zaglio:better 0 condition, removed sp__ dependencies
    d:120823\s.zaglio:sp__release
    d:120821\s.zaglio:sp__objs
    v:120724.1800\s.zaglio: create and upgrade objects
    t:sp__utility_setup 'run'
    t:sp__utility_setup 'run|log_ddl'
*/
CREATE proc [dbo].[sp__utility_setup]
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=isnull('|'+@opt+'|','')

-- ========================================================= param formal chk ==
if charindex('|run|',@opt)=0 goto help

-- ============================================================== declaration ==

declare
    @upg_log_ddl bit,
    @begin bit,@end bit,                -- called at begin of script or at end
    @tmp nvarchar(max),
    @sign sysname,
    @log_ddl bit

-- =========================================================== initialization ==

select
    @log_ddl=charindex('|log_ddl|',@opt),
    @begin=charindex('|begin|',@opt),
    @end=charindex('|end|',@opt)

-- ======================================================== second params chk ==
if @log_ddl=1 goto log_ddl

-- ##########################
-- ##
-- ## begin
-- ##
-- ########################################################

-- ===================================================================== body ==

log_ddl:
/*  131125\s.zaglio:moved here the upgrade of log_ddl because executed
                    before a function like fn__script_trace that uses this
                    table and that will fail on compilation
*/
if not object_id('log_ddl') is null
    begin
    -- ifolder version of utility or log_ddl
    if object_id('fn__script_sign') is null
        select @upg_log_ddl=1
    else
        -- select dbo.fn__script_sign('log_ddl_bak',default)
        -- select dbo.fn__script_sign('log_ddl',default)
        if dbo.fn__script_sign('log_ddl',default)=1612475947
            begin
            raiserror('-- minor upgrade of log ddl',10,1)
            exec sp_rename 'log_ddl.svr' , 'srv', 'column' --> 1679584815
            end
        if dbo.fn__script_sign('log_ddl',default)=1477379425
            select @upg_log_ddl=1

    if @upg_log_ddl=1
        begin
        raiserror('-- upgrading log_ddl',10,1)
        if not object_id('log_ddl_bak') is null drop table log_ddl_bak
        select * into log_ddl_bak from log_ddl
        drop table log_ddl
        end
    end -- upgrade log_ddl

-- drop table log_ddl
if object_id('log_ddl') is null
    begin
    -- drop table LOG_DDL
    create table LOG_DDL(
        svr int,                    -- fast and simple merge group
        id int,
        tid tinyint,
        rid int,                    -- parent id (tsql->obj->db) | app->host\usr
        pid int,                    -- host\usr->db(rid)         | app->...tsql...
        flags smallint,             -- at least 0
        skey as case
                when tid!=12        -- select code from tids
                then substring([txt],1,128)
                else null
                end,
        [key] int,                  -- crc32 of skey if tid!=code
        txt nvarchar(max) null,     -- tsql
        ev smallint null,           -- event
        rel int null,               -- release
        dt datetime,                -- at least getdate
        constraint PK_LOG_DDL primary key (id desc)
        )
    -- drop index  log_ddl.IX_LOG_DDL_KEY
    create index IX_LOG_DDL_KEY on log_ddl(tid,[key],dt desc)
    -- include (id) -- 100:13s:+21%
    include(id,svr,skey,rid)    -- 100:4s:+28%
    -- select id from log_ddl where tid=2 and [key]=2 and skey='test'
    raiserror('-- table log_ddl created',10,1)
    end -- create table

if @log_ddl=1 goto ret

-- ====================================================================== cfg ==
-- select dbo.fn__script_sign('cfg',default)
if not object_id('cfg') is null
and dbo.fn__script_sign('cfg',default) in (
    1865897288.0000,2083733301.0000
    )
    begin
    print '-- dropped old cfg '
    drop table cfg
    end

if object_id('cfg') is null
    begin
    create table [dbo].[cfg] (
        [id] int not null  identity(1,1) ,
        [flags] smallint not null,
        [rid] int not null ,
        [key] sysname collate Latin1_General_CI_AS not null ,
        [val] sql_variant not null
    ) on [PRIMARY]

    alter table [dbo].[cfg] add constraint [pk_cfg] primary key clustered (
    [id] DESC
    ) on [PRIMARY]

    create unique nonclustered index [ix_cfg] on [dbo].[cfg](
    rid,[key]
    ) on [PRIMARY]

    select @sign=dbo.fn__script_sign('cfg',1) -- with idx

    print '-- new cfg created with sign: '+@sign
    end -- cfg
else
    print '-- cfg already exists'

-- update fnd table or view (has the same sign)
if dbo.fn__script_sign('fnd',default)!=1649957971.0000
    begin
    exec sp__drop 'fnd'
    print '-- fnd dropped'
    end
else
    begin
    -- test if fnd a view/synonym to a not existant table
    if not object_id('fnd') is null
        begin try
        exec('declare @id int select top 0 @id=id from fnd')
        print '-- fnd of last version'
        end try
        begin catch
        exec sp__drop 'fnd'
        print '-- fnd dropped because point to nothing'
        end catch
    end

if object_id('script_act') is null
    begin
    -- drop table script_act
    create table script_act(
        id int identity constraint pk_script_act primary key,
        rid int,    -- crc32(@proc)
        pid int,    -- crc32(@obj)
        idx int,    -- execution order
        txt nvarchar(4000)
        )
    create unique index ix_script_act_rid_pid on script_act(rid,pid)

    end -- script_act

if object_id('sp__trace') is null
and not object_id('sp__log_trace') is null
    begin
    print '-- create synonym for sp__trace->sp__log_trace'
    create synonym sp__trace for sp__log_trace
    end

/* to check NET version
    xp_instance_regenumkeys 'HKEY_LOCAL_MACHINE',
                            'Software\Microsoft\NET Framework Setup\NDP'
*/

-- cause memory pressure this do not compile; must use AWE mode or have 64bit

-- ##########################
-- ##
-- ## do not comment hex code, see sp__script, comment 121212
-- ##
-- ########################################################
declare @asm varbinary(max)
select @asm=0x\
4d5a90000300000004000000ffff0000b80000000000000040000000000000000000000000000000000000000000000000000000000000000000000080000000\
0e1fba0e00b409cd21b8014ccd21546869732070726f6772616d2063616e6e6f742062652072756e20696e20444f53206d6f64652e0d0d0a2400000000000000\
504500004c0103009c809b500000000000000000e00002210b0108000008000000060000000000001e2700000020000000400000000040000020000000020000\
04000000000000000400000000000000008000000002000000000000030040850000100000100000000010000010000000000000100000000000000000000000\
cc2600004f000000004000004803000000000000000000000000000000000000006000000c000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000200000080000000000000000000000082000004800000000000000000000002e74657874000000\
24070000002000000008000000020000000000000000000000000000200000602e72737263000000480300000040000000040000000a00000000000000000000\
00000000400000402e72656c6f6300000c0000000060000000020000000e00000000000000000000000000004000004200000000000000000000000000000000\
00270000000000004800000002000500642100006805000001000000000000000000000000000000000000000000000000000000000000000000000000000000\
0000000000000000000000000000000013300400510000000100001100026f0400000a16fe01130411042d04020d2b3b026f0500000a0a730600000a0b071717\
730700000a0c080616068e696f0800000a00086f0900000a00086f0a00000a00140c07730b00000a0d2b00092a0000001b300400820000000200001100026f04\
00000a16fe01130611062d050213052b6a026f0c00000a1617730700000a0a170b20102700000c088d0a0000010d730600000a1304002b0d0011040916076f08\
00000a0000060916086f0d00000a250b16fe02130611062ddf00de042600fe1a00de0c00066f0a00000a00140a00dc001104730b00000a13052b0011052a0000\
011c000000003900276000040b000001020039002e67000c000000001e02280e00000a2a42534a4201000100000000000c00000076322e302e35303732370000\
000005006c0000009c010000237e0000080200001802000023537472696e67730000000020040000080000002355530028040000100000002347554944000000\
380400003001000023426c6f620000000000000002000001471502000900000000fa013300160000010000000b0000000200000003000000020000000e000000\
0300000002000000010000000300000000000a00010000000000060056004f000a007e0069000600c900a9000600e900a9000a005401390106008e0184010e00\
b1019b010600bf0184010e00c6019b01060002024f0006000c024f00000000000100000000000100010001001000400000000500010001005020000000009600\
87000a000100b02000000000960094000a0002005c21000000008618a3001100030000000100690100000100e8011900a30015002100a30011002900a3001100\
11006e01be0011007901c2003100a30011003900a300c7004100d601d0004100dc0111004100e20111001100a300d8001100f701ea0041000702ef000900a300\
110020001b001a002e000b0005012e0013000e01de00f70004800000000000000000000000000000000007010000020000000000000000000000010046000000\
000002000000000000000000000001005d000000000002000000000000000000000001004f00000000000000003c4d6f64756c653e0073705f5f617373656d62\
6c795f45384346423742355f363842445f343130455f413944465f4631334539314332344546452e646c6c007574696c73006d73636f726c6962005379737465\
6d004f626a6563740053797374656d2e446174610053797374656d2e446174612e53716c54797065730053716c427974657300666e5f5f636f6d707265737300\
666e5f5f6465636f6d7072657373002e63746f720053797374656d2e52756e74696d652e436f6d70696c6572536572766963657300436f6d70696c6174696f6e\
52656c61786174696f6e734174747269627574650052756e74696d65436f6d7061746962696c6974794174747269627574650073705f5f617373656d626c795f\
45384346423742355f363842445f343130455f413944465f463133453931433234454645004d6963726f736f66742e53716c5365727665722e53657276657200\
53716c46756e6374696f6e41747472696275746500626c6f62006765745f49734e756c6c006765745f4275666665720053797374656d2e494f004d656d6f7279\
53747265616d0053797374656d2e494f2e436f6d7072657373696f6e004465666c61746553747265616d0053747265616d00436f6d7072657373696f6e4d6f64\
6500577269746500466c75736800436c6f736500636f6d70726573736564426c6f62006765745f53747265616d0042797465005265616400457863657074696f\
6e00000000032000000000001ee0c5882932964486d9ccf1d71714510008b77a5c561934e0890600011209120903200001042001010880a20100020054020f49\
7344657465726d696e6973746963015455794d6963726f736f66742e53716c5365727665722e5365727665722e446174614163636573734b696e642c20537973\
74656d2e446174612c2056657273696f6e3d322e302e302e302c2043756c747572653d6e65757472616c2c205075626c69634b6579546f6b656e3d6237376135\
63353631393334653038390a4461746141636365737300000000032000020420001d05082003011221112502072003011d0508080520010112210b07051d0512\
19121d1209020420001221072003081d0508080d0707121d08081d0512191209020801000800000000001e01000100540216577261704e6f6e45786365707469\
6f6e5468726f777301000000f426000000000000000000000e270000002000000000000000000000000000000000000000000000002700000000000000000000\
00005f436f72446c6c4d61696e006d73636f7265652e646c6c0000000000ff250020400000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000100100000001800008000000000000000000000000000000100010000003000008000000000000000000000000000000100\
000000004800000058400000ec0200000000000000000000ec0234000000560053005f00560045005200530049004f004e005f0049004e0046004f0000000000\
bd04effe00000100000000000000000000000000000000003f000000000000000400000002000000000000000000000000000000440000000100560061007200\
460069006c00650049006e0066006f00000000002400040000005400720061006e0073006c006100740069006f006e00000000000000b0044c02000001005300\
7400720069006e006700460069006c00650049006e0066006f0000002802000001003000300030003000300034006200300000002c0002000100460069006c00\
65004400650073006300720069007000740069006f006e000000000020000000300008000100460069006c006500560065007200730069006f006e0000000000\
30002e0030002e0030002e00300000008c003600010049006e007400650072006e0061006c004e0061006d0065000000730070005f005f006100730073006500\
6d0062006c0079005f00450038004300460042003700420035005f0036003800420044005f0034003100300045005f0041003900440046005f00460031003300\
4500390031004300320034004500460045002e0064006c006c0000002800020001004c006500670061006c0043006f0070007900720069006700680074000000\
200000009400360001004f0072006900670069006e0061006c00460069006c0065006e0061006d0065000000730070005f005f0061007300730065006d006200\
6c0079005f00450038004300460042003700420035005f0036003800420044005f0034003100300045005f0041003900440046005f0046003100330045003900\
31004300320034004500460045002e0064006c006c000000340008000100500072006f006400750063007400560065007200730069006f006e00000030002e00\
30002e0030002e003000000038000800010041007300730065006d0062006c0079002000560065007200730069006f006e00000030002e0030002e0030002e00\
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
002000000c0000002037000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

if (select value_in_use from sys.configurations where name like 'clr enabled')=0 or
   (select value from sys.dm_clr_properties where name='state')
   ='CLR initialization permanently failed'
    print '-- CLR disabled or CLR init failed'
else
    begin
    if not exists(select * from sys.assemblies where name='utility_core')
        begin try
        print '-- creating assembly utility core'
        -- drop assembly utility_core
        create assembly utility_core
        from @asm
        with permission_set = safe

        exec('
        create function [fn__compress] (@blob varbinary(max))
        returns varbinary(max)
        as external name utility_core.utils.fn__compress;')
        exec('
        create function [fn__decompress] (@compressedblob varbinary(max))
        returns varbinary(max)
        as external name utility_core.utils.fn__decompress;')
        end try
        begin catch
        -- select @err_msg=error_message()
        print '-- assembly utility core failed with msg:'
        print isnull(error_message(),'???')
        end catch -- assembly utility_core
    end -- clr tests

-- ##########################
-- ##
-- ## end
-- ##
-- ########################################################
/*
if @end=1
    begin
    end
*/
goto ret

-- =================================================================== errors ==
/*
err_sample1:
exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param
goto ret
*/
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    create or upgrade base system objects

Parameters
    @opt    options
            run         run the inside code
            log_ddl     init only this table (called by sp__script_trace_db)

'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__utility_setup