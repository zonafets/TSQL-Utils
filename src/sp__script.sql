/*  leave this
    l:see LICENSE file
    g:utility,script
    d:111027.1000\s.zaglio:sp__scropt
    v:171214\s.zaglio:added %license%(@license_tag) in #vars
    v:131107\s.zaglio:corrected a no output when scripting by 0xID
    v:131030\s.zaglio:reenabled script of comments in case of table or view
    v:130729.1001\s.zaglio:managed #objs
    v:130729,130723,130719,130718,130712,130710\s.zaglio:arranging templates
    r:130708,130701\s.zaglio:some deprecation, some innovation;moving code from sp__script_group
    v:130506,130403\s.zaglio:added test of same ver, diff user;changed ovrchk behaviour
    v:130325,121218\s.zaglio:removed extra warning;again around problem of \
    v:121212.1800\s.zaglio:semi-solved problem of "\"
    v:121108.1621\s.zaglio:reintroduced bug 111027 to understand where happen (see comm)
    v:121012\s.zaglio:now pass @opt to sp__script_code
    v:120731.1800\s.zaglio:ix->pk and remote sp__script
    v:120730.1700\s.zaglio:adding help for #src_def
    v:120717.1656\s.zaglio:adding opt OVRCHK
    v:120622\s.zaglio:added usage of related option
    v:120213,111028\s.zaglio:about obj as hex id;moved trigger scripting here
    v:111027\s.zaglio:solved problem with lines that end with \ that escape the return
    v:110629,110628\s.zaglio:a small bug on drop;added scripting of trigger on db
    v:110627,110614\s.zaglio:adapted to new hex codes;added encapsulation on drop
    v:110531,110510\s.zaglio:a small bug near help;removed external help
    v:110329\s.zaglio:removed @out (use ..tofile) and html opt and added number
    v:100919.1000\s.zaglio: a bug near scripting of obj of other db
    v:100919,100912\s.zaglio: added drop of constraint;resolved tremendous bug of print ''
    v:100724,100718\s.zaglio: more dbg info;added go separator on multi obj
    v:100515,100509\s.zaglio: a minimal chk on obj existance;bug opt not passed to sp__script_table
    v:100418.2200\s.zaglio:added reverse option fro remote svr call
    v:100411,100405\s.zaglio:added synonym;adapted for sp__Script_group added go before raiserror
    v:100404,100403\s.zaglio:divided into more sps;added replacements and out to dir/file
    r:100328\s.zaglio:third remake of scripting utility
    t:sp__script 'sp__script',@as='sp__scropnt',@dbg=1
    t:sp__script 'sp__script',@opt='select',@dbg=1
    t:sp__script 'log_ddl',@opt='drop'
    t:sp__script 'sp__script',@opt='upgrade',@dbg=1
*/
CREATE proc [dbo].[sp__script]
    @obj sysname=null,         -- single obj
    @as sysname=null,
    @license sysname=null,
    @opt sysname=null,         -- see help
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select
    @proc=object_name(@@procid),
    @ret=0,
    @opt=dbo.fn__str_quote(coalesce(@opt,''),'|')

if @obj is null goto help

-- ================================================================== declare ==

declare
    @type nvarchar(2),
    @drop nvarchar(4000),
    @i int, @n int,@sql nvarchar(4000),
    @db sysname,@sch sysname,@sch_id int,
    @lno_begin int,@lno_end int,
    @psep nchar(1),
    @pos int,@src_id int,@src_pos int,
    @crlf nvarchar(2),
    @tofile int,@vars_id int,
    @def bit,@upgrade bit,
    @nohdr bit,@nodecl bit,@nofot bit,
    @noprop bit,@notrg bit,
    @ver sysname,@aut sysname,
    @tgs sysname,@var_id int,
    @license_tag nvarchar(32)

-- ===================================================================== init ==

select
    @tgs='rv',
    @license_tag='%license%',
    @def=isnull(object_id('tempdb..#src_def'),0),
    @psep=psep,
    @crlf=crlf,
    @upgrade=charindex('|upgrade|',@opt),
    @nohdr=charindex('|nohdr|',@opt),
    @nofot=charindex('|nofot|',@opt),
    @nodecl=charindex('|nodecl|',@opt),
    @tofile=charindex('|tofile|',@opt),
    @noprop=charindex('|noprop|',@opt),
    @notrg=charindex('|notrg|',@opt),
    @src_id=object_id('tempdb..#src'),
    @var_id=object_id('tempdb..#vars')
from dbo.fn__sym()

if @src_id is null
    create table #src (lno int identity primary key,line nvarchar(4000))

if @upgrade=1 create table #out (lno int primary key,line nvarchar(4000))

-- for speed optimization, #tpl can be passed prefilled from sp__script_group
if object_id('tempdb..#tpl') is null
    begin
    create table #tpl (lno int identity,line nvarchar(4000))
--create table #tpl_sec(lno int identity,section sysname,line nvarchar(4000))
    create table #tpl_cpl(tpl binary(20),section sysname,y1 int,y2 int)
    end

-- init templates
if @upgrade=1
    begin
    exec @ret=sp__script_templates 'script'
    if @ret!=0 goto ret
    end
-- ===================================================================== body ==
if left(@obj,2)='0x' -- script directly from log_ddl
    begin
    exec sp__script_code @obj,@opt=@opt,@dbg=@dbg
    goto output
    end

-- special case for temp objs
if left(@obj,1)='#'
    begin
    exec @ret=sp__script_code @obj
    goto ret
    end

select
    @db =db,
    @sch=sch,
    @obj=obj
from dbo.fn__parsename(@obj,0,1)

if @db!=db_name()
    begin
    -- roaming script to remote sp__script
    select @sql='use '+quotename(@db)+' '
               +'exec @ret=sp__script '''+@obj+''','
               +'@opt='''+@opt+''','
               +'@dbg='+convert(sysname,@dbg)
    exec sp_executesql @sql,N'@ret int out',@ret=@ret out
    if @@error!=0 goto err_rmt
    goto ret
    end

-- get local object info
select @sch_id=schema_id(@sch)

if @nohdr=0 -- 171214\s.zaglio -- and @upgrade=1
    begin
    /*
        sp__Script 'sp__script',@opt='upgrade',@license='test'
        only %license% can be replaced by @licence, because
        scripted code can contain tokens of itself
    */
    if not @var_id is null
        select
            @obj=case when id='%obj%' then cast(value as sysname)
                 else @obj end,
            @ver=case when id='%ver%' then cast(value as sysname)
                 else @ver end,
            @aut=case when id='%aut%' then cast(value as sysname)
                 else @aut end,
            @drop=case when id='%drop%' then cast(value as nvarchar(512))
                  else @drop end,
            @license=case when id=@license_tag then cast(value as sysname)
                  else @license end
        from #vars where id in ('%obj%','%ver%','%aut%','%drop%','%license%')
    else
        begin
        select
            @type=typ,
            @drop=if_exists+@crlf+'    '+drop_script
        from fn__sysobjects(@obj,@sch_id,'drop_script|if_exists')

        select
            @ver=cast(cast(val1 as decimal(10,4)) as sysname),
            @aut=val2
        from fn__script_info(@obj,@tgs,0)
        end
    end

if @type is null
    select @type=typ
    from fn__sysobjects(@obj,@sch_id,default)

if @def=1
    begin
    select @src_pos=isnull(max(lno),ident_seed('#src'))--+ident_incr('#src')
    from #src
    insert #src_def(xtype,cod,idx,flags)
    select @type,@obj,@src_pos,0
    end

-- ============================================================ script object ==

if @type is null goto err_typ

if @dbg=1 exec sp__printf '-- db:%s, obj:%s, xt:%s',@db,@obj,@type

if @upgrade=1
    begin
    if @nodecl=0 exec @ret=sp__script_template '%declarations%'
    if @nohdr=0
        exec @ret=sp__script_template
             @section='%obj_ver_chk%',
             @tokens='%obj%|%drop%|%ver%|%aut%',
             @v1=@obj,@v2=@drop,@v3=@ver,@v4=@aut
    if @ret!=0 goto ret -- if not catched by caller
    end -- upgrade

-- mark last row before the insert of new code
select @lno_begin=isnull(max(lno),0) from #src

-- real script generation is demanded to sub proc
if @type in ('U','S')
    exec sp__script_table @obj=@obj,@opt=@opt,@dbg=@dbg
else
    begin
    -- sp__script_code 'sp__Script'
    if @type in ('P','TR','FN','TF','IF','V','SN','TD')
        exec sp__script_code @obj=@obj,@opt=@opt,@dbg=@dbg
    else
        goto err_typ
    end

-- sp__comment 'sp__script','script an object'

-- fist script line of code
select @lno_begin=(
    select top 1 lno
    from #src
    where lno>@lno_begin
    order by lno
    )

-- last script line
select @lno_end=max(lno) from #src

if @dbg=1 exec sp__printf '-- begin:%d, end:%d',@lno_begin,@lno_end

-- script properties
if (@upgrade=1 and @noprop=0 and left(@obj,1)!='#')
or @type in ('U','V')
    exec sp__script_prop @obj=@obj,@dbg=@dbg

-- rename
if not @as is null
    update #src set line=replace(line,
        dbo.fn__sql_unquotename(ltrim(rtrim(@obj))),
        dbo.fn__sql_unquotename(ltrim(rtrim(@as)))
        )
    where lno between @lno_begin and @lno_end

-- apply vars
if not @license is null
    begin
    update #src set line=replace(line,@license_tag,@license)
    where charindex('l:'+@license_tag,line)>0
    end

if @upgrade=1
    begin
    /*  121108\s.zaglio: the \ at end of line, means:"continue on next line"
        and give compile problem so I add a \\crlfcrlf as in this example
        print '[1] foo\
        bar'
        print '[2] foo\\
        bar'
        print '[3] foo\\

        bar'

        [1] foo        bar
        [2] foo\        bar
        [3] foo\
                bar
    */
    update #src set
        line=case when right(line,1)='\'
             then line+'\'+@crlf+
                  -- 121218\s.zaglio
                  case @tofile
                    when 0 then @crlf   -- out to console
                    else ''             -- out to file
                  end
             else line
             end
    where lno between @lno_begin and @lno_end

    update #src set line=replace(line,'''','''''')
    where lno between @lno_begin and @lno_end

    update #src set
        line='exec dbo.sp_executesql @statement = N'''
            +line
    where lno=@lno_begin
    update #src set line=line+''''
    where lno=@lno_end
    end -- quote

-- script triggers for table
if @type in ('U')
and @notrg=0
    begin
    declare @trg sysname
    declare @tr_opt sysname
    select @tr_opt=@opt+'related'
    declare cs cursor local for
        select [name]
        from sysobjects o
        where parent_obj=object_id(@obj)
        and xtype='TR'
        -- ?? ctype='TR' ?? maybe in the future
    open cs
    while 1=1
        begin
        fetch next from cs into @trg
        if @@fetch_status!=0 break
        insert #src(line) select ''

        if @def=1
            begin
            select @src_pos=isnull(max(lno),ident_seed('#src'))--+ident_incr('#src')
            from #src
            insert #src_def(xtype,cod,idx,flags)
            select 'TR',@trg,@src_pos,0
            end

        if @db=db_name()
            exec sp__script_code @trg,@opt=@tr_opt,@dbg=@dbg
        else
            begin
            select @sql ='use ['+@db+'] exec sp__script_code @obj='''
                        +@trg+''',@opt='''+@tr_opt+''',@dbg='+convert(sysname,@dbg)
            exec(@sql)
            if @@error!=0 goto err_rmt
            end

        end -- while of cursor
    close cs
    deallocate cs
    end -- triggers

if @upgrade=1 and @nofot=0
    begin
    exec @ret=sp__script_template @section='%skip_obj%',
                                  @tokens='%obj%',
                                  @v1=@obj
    if @ret!=0 goto ret
    end -- upgrade

-- ============================================================ output result ==
output:

if charindex('|print|',@opt)!=0
or @src_id is null
    exec sp__print_table '#src'

if charindex('|select|',@opt)!=0
    select line from #src order by lno

goto ret

-- =================================================================== errors ==
err_onf:    exec @ret=sp__err 'object "%s" not found',@proc,@p1=@obj
            goto ret
err_typ:    exec @ret=sp__err 'unknow type or object for "%s"',@proc,@p1=@obj
            goto ret
err_rmt:    exec @ret=sp__err 'missing or wrong script utility on %s',@proc,@p1=@db
            goto ret
-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    script any object (or try to do that)

Parameters
    @obj    name of object to script
            id of release (see sp__script_history)
    @as     rename object (very simple replace;do not work always)
    @opt    options (and see options below sub sp)
            upgrade wrap code for upgrade (sp__script_group)
            nodecl  leave out the upgrade''s local variable declaration
            nohdr   leave out the upgrade''s header
            nofot   leave out the upgrade''s footer
            tofile  necessary because different behaviour of ending \
            noprop  do not script extended property
            print   force print as text
            select  show result as select

Notes
    * can be called from sp__script_group
    * call sp__script_code if @obj is an proc,func,view,synonim,trigger
    * call sp__script_table if @obj is a table
    * if table #src_def is defined (called by sp__script_align),
      fill it with definition info of sub objects
        create table #src_def(
            xtype varchar(2),   -- sysobjects.xtype
            id int identity,    -- parent id
            rid int,            -- property parent id
            flags smallint,     -- flags depend on xtype (see below)
            cod sysname,        -- object or property name
            val sql_variant,    -- value of property
            idx int             -- relative source position start
            )

        xtype&description (* = managed)             flags
        =========================================== ============================
        AF = Aggregate function (CLR)
        C = CHECK constraint
        D = Default or DEFAULT constraint
        F = FOREIGN KEY constraint
        L = Log
        FN =*Scalar function
        FS = Assembly (CLR) scalar-function
        FT = Assembly (CLR) table-valued function
        IF =*In-lined table-function
        IT = Internal table
        IX =*Index
        PK =*PrimayKey
        UQ =*vincolo UNIQUE (il tipo è K)
        P =*Stored procedure
        PC = Assembly (CLR) stored-procedure
        RF = Replication filter stored procedure
        S = System table
        SN =*Synonym
        SQ = Service queue
        TA = Assembly (CLR) DML trigger
        TF =*Table function
        TR =*SQL DML Trigger
        TD =*trigger database
        TT = Table type
        U =*User table
        V =*View
        X = Extended stored procedure
        --= comments
'
-- show other helps
exec sp__script_code
exec sp__printf ''
exec sp__script_table

ret:
return @ret
end -- sp__script