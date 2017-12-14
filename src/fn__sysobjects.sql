/*  leave this
    l:see LICENSE file
    g:utility
    v:131029\s.zaglio:moved from utility_old back to utility
    v:131001.1000\s.zaglio:refined indexes (pk,uq)
    r:130908\s.zaglio:adapted to fn__script_drop
    v:121202\s.zaglio:added parent_id,schema_id,drop_script,if_exists and tested
    r:121201\s.zaglio:added indexes and removed mssql2k compatibility
    v:121012\s.zaglio:added drop column
    v:110629\s.zaglio:list all sysobjects
    t:select * from fn__sysobjects(default,default,default) where typ in ('td','tr')
    t:select * from fn__sysobjects(default,default,'if_exists') where typ in ('fn')
    t:select * from fn__sysobjects(default,default,'if_exists|relaxed') where typ in ('fn')
    t:sp__sysobjects_test
*/
CREATE function fn__sysobjects(
    @obj sysname,
    @schema_id int,
    @opt sysname    -- drop_script: fill the drop script info
                    -- if_exists: fill the [exists] column
                    -- relaxed: passed to fn__script_drop
    )
returns @t table(
    id int,
    sch sysname null,
    obj sysname,
    typ varchar(2),                     -- in sys.objects is char(2)
    [drop] sysname null,
    parent sysname null,
    parent_typ varchar(2) null,         -- in sys.objects is char(2)
    drop_script nvarchar(512) null,
    if_exists nvarchar(4000) null
    )
as
begin
declare @drop_script bit,@if_exists bit,@relaxed bit,@crlf nvarchar(4)
select @obj=isnull(@obj,'%'),@crlf=crlf from fn__sym()
if not @opt is null
    begin
    select @opt='|'+@opt+'|'
    select
        @drop_script=charindex('|drop_script|',@opt),
        @if_exists=charindex('|if_exists|',@opt),
        @relaxed=charindex('|relaxed|',@opt)
    end
else
    select
        @drop_script=0,@if_exists=0
/*
AF = funzione di aggregazione (CLR)
C = vincolo CHECK
D = DEFAULT (vincolo o valore autonomo)
F = vincolo FOREIGN KEY
FN = funzione scalare SQL
FS = Funzione scalare di assembly (CLR)
FT = funzione valutata a livello di tabella assembly (CLR)
IF = funzione SQL inline valutata a livello di tabella
IT = tabella interna
P = Stored procedure SQL
PC = Stored procedure di assembly (CLR)
PG = Guida di piano
PK = vincolo PRIMARY KEY
R = regola (tipo obsoleto, autonoma)
RF = procedura-filtro-replica
S = tabella di base di sistema
SN = sinonimo
SQ = coda di servizio
TA = trigger DML assembly (CLR)
TF = funzione valutata a livello di tabella SQL
TR = trigger DML SQL
TT = tipo tabella
U = tabella (definita dall'utente)
UQ = vincolo UNIQUE
V = vista
X = stored procedure estesa
*/
insert @t(id,sch,obj,typ,[drop],parent,parent_typ)
-- declare @schema_id int,@obj sysname select @obj='%'
select
    o.object_id,s.name,o.[name],o.[type],
    case
    when o.[type] = 'U' then 'table'
    when o.[type] = 'SN' then 'synonym'
    when o.[type] = 'P' then 'proc'
    when o.[type] = 'V' then 'view'
    when o.[type] = 'TR' then 'trigger'
    when o.[type] in ('FN','FS','FT','IF','TF') then 'function'
    when o.[type] = 'D' then 'constraint '
    when o.[type] in ('PK','UQ','F') then 'index '
    else '#!unktype '
    end,
    p.name,p.[type]
-- select top 10 *
from sys.objects o
left join sys.objects p on o.parent_object_id=p.object_id
join sys.schemas s on o.schema_id=s.schema_id
where not o.type in ('s'/*system*/,'tr'/*trigger are in sys.triggers*/)
and o.name like @obj
and (@schema_id is null or @schema_id=o.[schema_id])

union                                   -- db trigger

select
    t.object_id,null,t.name,
    case t.parent_id when 0 then 'TD' else 'TR' end,
    'trigger',p.name,p.[type]
-- select *
from sys.triggers t
left join sys.objects p
on t.parent_id=p.object_id
where t.is_ms_shipped=0
and t.name like @obj

union

select
    index_id,null,i.name,
    case when is_primary_key=1 then 'PK'
         when is_unique=1 then 'UQ'
         else 'IX'
         end,
    'index',p.name,p.[type]
-- select top 10 *
from sys.indexes i
join sys.objects p on i.object_id=p.object_id
join sys.schemas s on p.schema_id=s.schema_id
where 0 in (i.is_primary_key,i.is_unique)
and (p.type!='s'/* or @sys=1*/)
and i.name like @obj -- heep excluded because null name

/*
if @if_exists=1
    update @t set [exists]='if exists('+@crlf
                          +'    select top 1 null from '+location
                          +'    where name='''+obj+''''
                          +case
*/

if @drop_script=1 or @if_exists=1
    update @t set
        drop_Script=case @drop_script when 0 then null else f.drop_script end,
        if_exists=case @if_exists when 0 then '' else f.if_exists end
    from @t t
    cross apply fn__script_drop(t.obj,typ,sch,parent,case @relaxed
                                                     when 1
                                                     then 'relaxed'
                                                     else null
                                                     end) f

return
end -- fn__sysobjects