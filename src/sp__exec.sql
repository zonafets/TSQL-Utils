/*  leave this
    l:see LICENSE file
    g:utility
    v:130308\s.zaglio: better help and info
    v:121202\s.zaglio: better help; added dangerous like check; more options
    v:120611\s.zaglio: added %db% macro
    v:120523\s.zaglio: added @opt and run because sp too dangerouse
    v:101202\s.zaglio: added #objs test
    v:100919.1005\s.zaglio: added fast where
    v:100919\s.zaglio: added use of external #objs
    v:100723\s.zaglio: added %cols%
    v:100619\s.zaglio: added @fromdb,@p1..@p4
    v:100301\s.zaglio: execute a script for each object
    c:replaces old utilities sp__foreach??? into this one
    t:sp__exec 'print "%tbl%"',@opt='run',@dbg=1
    t:sp__exec 'print "[%tbl%].[%tbl_col%]"',@opt='run',@dbg=1
    t:sp__exec 'print "%syn%:%syn_base%"',@opt='run',@dbg=1
    t:sp__exec 'print "%isql%"',@where='charindex("_str_","%obj%")>0',@isql='print "%obj%(FN,TF)"'
    t:sp__exec 'print "%tbl%:%cols%"',@opt='run',@dbg=1
    t:sp__exec 'print "%db%"',@opt='run'
*/
CREATE proc sp__exec
    @sql nvarchar(4000)=null,
    @where nvarchar(4000)=null,
    @isql nvarchar(4000)=null,
    @fromdb sysname=null,
    @p1 sysname=null,
    @p2 sysname=null,
    @p3 sysname=null,
    @p4 sysname=null,
    @opt sysname=null,
    @dbg int=0
as
begin
set nocount on
declare @proc sysname,@ret int
select  @proc=object_name(@@procid),@ret=0,
        @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
if @sql is null goto help

declare @run bit,@db sysname,@nfo bit,@i int,@j int,@wrn bit

select
    @run=charindex('|run|',@opt),
    @nfo=charindex('|nfo|',@opt),
    @wrn=charindex('|wrn|',@opt),
    @i=patindex('% like %["''][%][[]%',@where),
    @j=patindex('%][%]["'']%',@where),
    @db=db_name()

if @i>0 and @j>@i and @wrn=0 goto err_like

if @where='#objs'
    begin
    if object_id('tempdb..#objs') is null goto err_objs
    select @where='"%tbl%" in (select obj from #objs)'
    end

if left(@where,6)='%tbl%='
    begin
    if charindex(',%col%=',@where)>0
        select @where='"%tbl%" like "'+substring(dbo.fn__str_at(@where,',',1),7,4000)+'" and '
                     +'"%col%" like "'+substring(dbo.fn__str_at(@where,',',2),7,4000)+'"'
    else
        select @where='"%tbl%" like "'+substring(@where,7,4000)+'"'
    end

-- declare @sql sysname select @sql='print "%obj%(u,v)"'
create table #objs_sp__exec(
    id int identity primary key,
    obj sysname,typ nvarchar(2),val sysname null,
    cols nvarchar(4000) null
    )
create table #syns (id int primary key,base sysname)   -- for compatibility with mssql2k
create table #typs (xtype nvarchar(2))
declare @col bit,@tsql nvarchar(4000)
declare @qfromdb sysname,@cols nvarchar(4000),@with_cols bit
select @col=0,@with_cols=0

select @fromdb=coalesce(dbo.fn__sql_unquotename(@fromdb),db_name())
select @qfromdb=dbo.fn__sql_quotename(@fromdb)

if dbo.fn__ismssql2k()=0
    insert #syns
    select [object_id],base_object_name
    from sys.synonyms

declare @prm table (id int,p nvarchar(4000) null)
insert @prm select 1,@sql
insert @prm select 2,@where
insert @prm select 3,@isql

if charindex('%cols%',@sql)>0
or charindex('%cols%',@isql)>0
    select @with_cols=1

-- check syntax
if exists(select null from @prm
          where charindex('%obj%',p)>0)
and not exists(select null from @prm
          where charindex('%obj%(',p)>0)
    goto err_syn

select
    @tsql=
        substring(
            p,
            charindex('%obj%(',p)+6,
            charindex(')',p,charindex('%obj%(',p))-charindex('%obj%(',p)-6
            )
from @prm
where charindex('%obj%(',p)>0

if not @tsql is null
    begin
    insert #typs
    select left(token,2)
    from dbo.fn__str_table(@tsql,',')
    end

-- remove (t,t,t,...)
update @prm set
    p=left(p,charindex('%obj%(',p)+4)
     +substring(p,charindex(')',p,charindex('%obj%(',p))+1,4000)
where charindex('%obj%(',p)>0

-- reload adjusted params
select @sql=p   from @prm where id=1
select @where=p from @prm where id=2
select @isql=p  from @prm where id=3


if exists(select null from @prm where charindex('%tbl%',p)>0)
    insert #typs select 'U'
if exists(select null from @prm where charindex('%view%',p)>0)
    insert #typs select 'V'
if exists(select null from @prm where charindex('%syn%',p)>0)
    insert #typs select 'SN'
if exists(select null from @prm
          where charindex('%col%',p)>0
          or charindex('%view_col%',p)>0
          or charindex('%tbl_col%',p)>0
         )
    begin
    select @col=1
    if charindex('%col%',@sql)>0
    or charindex('%col%',@isql)>0
        insert #typs select 'U' union select 'V'
    if charindex('%tbl_col%',@sql)>0
    or charindex('%tbl_col%',@isql)>0
        insert #typs select 'U'
    if charindex('%view_col%',@sql)>0
    or charindex('%view_col%',@isql)>0
        insert #typs select 'V'

    select @tsql='
    insert #objs_sp__exec(obj,typ,val,cols)
    select o.[name],o.xtype,c.name,'+
        case when @with_cols=1
             then 'dbo.fn__flds_of(o.[name],'','',null)'
             else 'null'
        end+'
    from '+@qfromdb+'..sysobjects o
    join '+@qfromdb+'..syscolumns c on c.id=o.id
    left join #syns s on o.id=s.id and o.xtype=''SN''
    where o.xtype in (select xtype from #typs)
    order by o.xtype,c.colorder
    '
    exec(@tsql)

    end -- insert cols
else
    begin
    select @tsql='
    insert #objs_sp__exec(obj,typ,val,cols)
    select o.[name],o.xtype,s.base,'+
        case when @with_cols=1
             then 'dbo.fn__flds_of(o.[name],'','',null)'
             else 'null'
        end+'
    from '+@qfromdb+'..sysobjects o
    left join #syns s on o.id=s.id and o.xtype=''SN''
    where o.xtype in (select xtype from #typs)
    order by o.xtype
    '
    exec(@tsql)
    end

-- if @dbg=1 exec sp__select_astext 'select * from #objs_sp__exec'

select @sql=replace(@sql,'"','''')
select @where=replace(@where,'"','''')
select @isql=replace(@isql,'"','''')

declare @tkns nvarchar(4000)
select @tkns='%tbl%|%view%|%syn%|%tbl_col%|%view_col%|%syn_base%|%base%|%col%'

exec sp__str_replace
        @sql out,
        @tkns,
        '%obj%','%obj%','%obj%','%val%','%val%','%val%','%val%','%val%'
if not @isql is null
    exec sp__str_replace
            @isql out,
            @tkns,
            '%obj%','%obj%','%obj%','%val%','%val%','%val%','%val%','%val%'
if not @where is null
    exec sp__str_replace
            @where out,
            @tkns,
            '%obj%','%obj%','%obj%','%val%','%val%','%val%','%val%','%val%'

if not exists(select null from #objs_sp__exec)
and (charindex('%db%',@sql)>0 or charindex('%fromdb%',@sql)>0)
    insert #objs_sp__exec(obj) select @fromdb

declare @b bit,@obj sysname,@xt nvarchar(2),@val sysname,@n int
select @n=0
declare cs cursor local for
    select obj,typ,val,cols
    from #objs_sp__exec
    order by id
open cs
while 1=1
    begin
    fetch next from cs into @obj,@xt,@val,@cols
    if @@fetch_status!=0 break

    -- if @dbg=1 exec sp__printf 'processing (%s,%s,%s) with (%s)',@obj,@xt,@val,@sql

    select @b=1
    if not @where is null
        begin
        select @b=0
        select @tsql='if ('+@where+') select @b=1'
        exec sp__str_replace
                @tsql out,
                '%obj%|%xt%|%val%|%fromdb%|%db|',
                @obj,@xt,@val,@fromdb,@db
        exec sp_executesql @tsql,
            N'@b bit out,@obj sysname,@xt sysname,@val sysname',
            @b=@b out,@obj=@obj,@xt=@xt,@val=@val
        if @@error!=0 exec sp__printf 'error in where:\n%s',@tsql
        if @dbg=2 exec sp__printf 'b:%s; sql:%s; @val:%s;',@b,@tsql,@val
        end

    if @b=1
        begin
        select @tsql=@sql
        if not @isql is null
            select @tsql=replace(@tsql,'%isql%',replace(@isql,'''',''''''))

        -- prepare final sql
        exec sp__str_replace
                @tsql out,
                '%obj%|%xt%|%val%|%fromdb%|%cols%|%db%',
                @obj,@xt,@val,@fromdb,@cols,@db

        if not @p1 is null select @tsql=replace(@tsql,'%p1%',@p1)
        if not @p2 is null select @tsql=replace(@tsql,'%p2%',@p2)
        if not @p3 is null select @tsql=replace(@tsql,'%p3%',@p3)
        if not @p4 is null select @tsql=replace(@tsql,'%p4%',@p4)

        select @n=@n+1

        if @dbg=1 or @run=0
            exec sp__printf '%s',@tsql
        else
            begin
            exec(@tsql)
            if @@error!=0 and @dbg=0 exec sp__printf '-- error in:%s',@tsql
            end
        end
    end -- loop objs

close cs
deallocate cs

if @n=0 exec sp__printf '-- no objects match condition; use @dgb 2 to see'

goto ret

-- =================================================================== errors ==
err_syn:
    exec @ret=sp__err 'expected ( after %obj%',@proc
    goto ret
err_objs:
    exec @ret=sp__err '#objs not found; see help',@proc
    goto ret
err_like:
    exec @ret=sp__err 'likes like "%[...]%" are not admitted (see wrn option)',
                      @proc
    goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    execute script for each object of db

Parameters
    @sql    sql template to execute for each object identified
    @isql   is the inside sql used to replace macro %isql%
    @fromdb to load object name from db different from current
    @dbg    1 cmd will be printed and not executed even if RUN is specified
            2 print search sql
    @p1...  replace %p1%,... after macro
    @where  contain an expression that filter objects trought macros
            can be a fast expression like:
            "#objs"     : become: "%tbl% in (select obj from #objs)"
            %tbl%=...   : become: "%tbl%" like "..."
            Macros
                @obj    object name
                @xt     object type (U,V,...)
                @val    in case of synonyms, is the for clause
                        in other cases is the column name
            Notes
                likes like "%[...]%" are not admitted

Options
    run     since 120523, this sp show code only because is to dangerouse.
            Use this option to run it.
    wrn     skip error of dangerouse like

Macros
    %obj%(t,...)is a replacer for each object of specified type
    %tbl%       is a replacer for tables
    %view%      is a replacer for views
    %syn%       is a replacer for synonym
    %syn_base%  is a replacer for synonym reference
    %col%       is a replacer for columns of view or table
    %cols%      is a replacer for "col1,col2,..." of view or table
    %tbl_col%   is a replacer for [table].[column]
    %view_col%  is a replacer for [table].[column]
    %typ%       is a replacer for type(size)    (TODO)
    %master%    is a replacer for master server name in sync system (TODO)
    %master%    is a replacer for slave  server name in sync system (TODO)
    %isql%      is a replacer for inner sql (param @isql)
    %fromdb%    is a replacer from @fromdb
    %db%        is a replacer for db_name()
    "           is a replacer for double quotes

Each macro enable collection of relative object

Examples
    sp__exec ''print "%tbl%"'',@dbg=1
    sp__exec ''print "[%tbl%].[%tbl_col%]"'',@dbg=1
    sp__exec ''print "%sym%:%sym_base%"'',@dbg=1
    sp__exec ''print "%isql%"'',@where=''charindex("_str_","%obj%")>0'',@isql=''print "%obj%(FN,TF)"'',@dbg=1

Objects types
    AF = funzione di aggregazione (CLR)
    C = vincolo CHECK
    D = DEFAULT (vincolo o valore autonomo)
    F = vincolo FOREIGN KEY
    PK = vincolo PRIMARY KEY
    P = stored procedure SQL
    PC = stored procedure assembly (CLR)
    FN = funzione scalare SQL
    FS = funzione scalare assembly (CLR)
    FT = funzione valutata a livello di tabella assembly (CLR)
    R = regola (tipo obsoleto, autonoma)
    RF = procedura-filtro-replica
    S = tabella di base di sistema
    SN = sinonimo
    SQ = coda di servizio
    TA = trigger DML assembly (CLR)
    TR = trigger DML SQL
    IF = funzione SQL inline valutata a livello di tabella
    TF = funzione valutata a livello di tabella SQL
    U = tabella (definita dall''utente)
    UQ = vincolo UNIQUE
    V = vista
    X = stored procedure estesa
    IT = tabella interna

'

-- ===================================================================== exit ==
ret:
return @ret
end -- proc sp__exec