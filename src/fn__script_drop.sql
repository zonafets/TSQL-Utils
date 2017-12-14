/*  leave this
    l:see LICENSE file
    g:utility
    k:get,create,drop,script,if,exists
    v:131001.1100\s.zaglio: refined drop of pk
    r:130908\s.zaglio: return drop scripts
    t:sp__sysobjects_test
*/
CREATE function fn__script_drop(
    @obj sysname,
    @typ nvarchar(2),
    @schema sysname,
    @parent sysname,
    @opt sysname
    )
returns table
as
return
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
select
    @obj as [obj],
    @typ as [type],
    @schema as [schema],

    drop_script=
        case when @typ='PK'
             then 'alter table '+
                  isnull(q_schema+'.','')+q_parent+
                  ' drop constraint '+quotename(@obj)
        else
            'drop '+
            case when @typ in ('PK','UQ','F')
                 then 'index '+isnull(q_schema+'.','')
                              +isnull(q_parent+'.','')
                              +q_obj
            else
                case
                when @typ in ('FN','TF','IF')
                then 'function '
                when @typ in ('TR','TD')
                then 'trigger '
                when @typ='SN'
                then 'synonym '
                when @typ='U'
                then 'table '
                when @typ='P'
                then 'proc '
                when @typ='V'
                then 'view '
                when @typ='D'
                then 'constraint '
                when @typ in ('FN','IF','TF')
                then 'function '
                else '#!unktype '
                end+
                isnull(q_schema+'.','')+q_obj
            end+case @typ when 'TD' then ' on database' else '' end
        end, -- pk
    if_exists=
        'if exists('+crlf+
        case
        when @typ in ('IX','UQ')
        then
            '    select top 1 null from sys.indexes'+crlf+
            '    where name='''+@obj+''''+crlf+
            '    and object_id=object_id('''+
                 q_Schema+'.'+q_parent+
                 ''')'+crlf
        when @typ in ('TD')
        then
            '    select top 1 null from sys.triggers'+crlf+
            '    where name='''+@obj+''''+crlf
        else
            '    select top 1 null from sys.objects'+crlf+
            '    where name='''+@obj+''''+crlf+
            case relaxed
            when 1 then '' else '    and [type]='''+@typ+''''
            end+crlf+
            '    and schema_id=schema_id('''+def_schema+''')'+crlf
        end+
        '    )'

from fn__sym(),(
    select
        quotename(@schema) as q_schema,
        isnull(@schema,'dbo')as def_schema,
        quotename(@parent) as q_parent,
        quotename(@obj) as q_obj,
        charindex('|relaxed|','|'+isnull(@opt,'')+'|') as relaxed
    ) as params
-- fn__script_drop