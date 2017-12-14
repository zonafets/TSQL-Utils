/*  leave this
    l:see LICENSE file
    g:utility
    v:130710\s.zaglio: added lkey for logic keys
    v:130211\s.zaglio: bug that causes a lost of last added fld(see code)
    v:120413\s.zaglio: add. exclusion of identity fld
    v:120113\s.zaglio: added code for correct compare
    v:110407\s.zaglio: added @no_ins,no_upd and code option
    v:110406\s.zaglio: added @excludes
    v:110322\s.zaglio: better help; added @where
    v:100928\s.zaglio: append mode, when @keys = @flds_tbl
    v:100730.1100\s.zaglio: more help
    v:100724\s.zaglio: added cmp option
    r:100718\s.zaglio: insert/update into one solution
    t:drop proc sp__merge
    t:sp__merge 'test_form','id'
*/
CREATE proc sp__merge
    @tbl        sysname =null,
    @flds_tbl   nvarchar(4000) =null,   -- or from
    @from       sysname =null,          -- or keys
    @flds_from  nvarchar(4000) =null,
    @keys       nvarchar(4000) =null,
    @flds_cmp   nvarchar(4000) =null,   -- upd fields
    @where      nvarchar(4000) =null,
    @no_ins     nvarchar(4000) =null,
    @no_upd     nvarchar(4000) =null,
    @error      int = null out,
    @inserted   bigint = null out,
    @updated    bigint = null out,
    @opt        sysname =null,
    @dbg        int=0
as
begin
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname,  @ret int -- standard API: 0=OK -1=HELP, any=error id
select @proc=object_name(@@procid), @ret=0
select @opt=dbo.fn__str_quote(@opt,'|')

-- declarations
declare @flds nvarchar(4000),@drop bit,@code bit
declare @excludes table(ins bit,obj sysname)
declare
    @op_cmp bit,@op_nochk bit,@op_moc bit,
    @op_121 bit,@op_nofmt bit,@op_lkey bit

select
    @op_cmp=charindex('|cmp|',@opt),
    @op_nochk=charindex('|nochk|',@opt),
    @op_moc=charindex('|moc|',@opt),
    @op_121=charindex('|121|',@opt),
    @op_nofmt=charindex('|nofmt|',@opt),
    @op_lkey=charindex('|lkey|',@opt)

-- simple: to,from,[key]
if not @tbl is null and not @flds_tbl is null and not @from is null
and @flds_from is null and @keys is null
    begin
    if @dbg>1 exec sp__printf 'simple syntax'
    select @keys=@from,@from=@flds_tbl,@flds_tbl=null
    end

if @tbl is null and @from is null goto help

if @op_nochk=0
and (dbo.fn__exists(@tbl,null)=0 or dbo.fn__exists(@from,null)=0)
    goto err_notf

-- drop table #fld
create table #fld(
    tid tinyint,        -- 1=fld,2=key,3=upd
    id int identity,
    tbl sysname      null,
    fld sysname,
    [from] sysname   null,
    from_fld sysname null,
    sep nvarchar(4)  null,
    cmm sysname      null,
    t_f              as rtrim(tbl)+rtrim(fld),
    f_f              as rtrim([from])+rtrim(from_fld),
    cmp_flds         as 'or ('+rtrim(tbl)+rtrim(fld)+'!='+
                               rtrim([from])+rtrim(from_fld)+
                        ' or (('+rtrim(tbl)+rtrim(fld)+' is null or '+
                                 rtrim([from])+rtrim(from_fld)+' is null) '+
                        'and not coalesce('+rtrim(tbl)+rtrim(fld)+','+
                                            rtrim([from])+rtrim(from_fld)+
                        ') is null))'
    )

declare @src table (lno int identity primary key,line nvarchar(4000))

declare
    @n int,@m int,@cr nchar(1),@lf nchar(1),@tab nchar(1),
    @sql nvarchar(4000),@id int

select
    @tbl=dbo.fn__sql_unquotename(@tbl),
    @from=dbo.fn__sql_unquotename(@from),
    @cr=cr,@lf=lf,@tab=tab,
    @no_ins=replace(@no_ins,'|',','),
    @no_upd=replace(@no_upd,'|',','),
    @code=0
from dbo.fn__sym()

insert @excludes(ins,obj) select 1,token from dbo.fn__str_table(@no_ins,',')
insert @excludes(ins,obj) select 0,token from dbo.fn__str_table(@no_upd,',')

/*
exec sp__merge
    'tbl',
    'c1,    c2, c3,
     c4,c5',
    'from',
    'c1,c2,
     c3,c4',
    'c1,c2, c3 ,c4',@dbg=1
*/

-- adjust programming format
select @n=4
while @n>0
    begin
    if @dbg>1 exec sp__printf 'adjusting flds of param %d',@n

    if @n=4 select @flds=@flds_tbl
    if @n=3 select @flds=@flds_from
    if @n=2 select @flds=@keys
    if @n=1 select @flds=@flds_cmp

    select @flds=replace(@flds,@tab,' ')
    select @flds=replace(@flds,@cr,'')
    select @flds=replace(@flds,@lf,'')
    while charindex('  ',@flds)>0 select @flds=replace(@flds,'  ',' ')
    while charindex(', ',@flds)>0 select @flds=replace(@flds,', ',',')
    while charindex(' ,',@flds)>0 select @flds=replace(@flds,' ,',',')

    if @n=4 select @flds_tbl=@flds
    if @n=3 select @flds_from=@flds
    if @n=2 select @keys=@flds
    if @n=1 select @flds_cmp=@flds

    select @n=@n-1
    end -- while
/* ================================ body ================================== */

if @keys is null or @dbg>1
    begin
    exec sp__printf '--tbl=%s\n--fld=%s\n--from=%s\n--ffld=%s\n--key=%s',
                    @tbl,@flds_tbl,@from,@flds_from,@keys
    if @keys is null
        select
            @code=1,
            @keys=@flds_tbl,
            @from=@tbl,
            @flds_tbl=null
    end -- code mode

if @keys='*' select @keys=dbo.fn__flds_of(@tbl,',',null)
if @flds_tbl is null
    select @flds_tbl=dbo.fn__flds_of(@tbl,',','%id%')
if @flds_from is null
    select @flds_from =dbo.fn__flds_of(@from,',','%id%')

select
    @n=dbo.fn__str_count(@flds_tbl,','),
    @m=dbo.fn__str_count(@flds_from,',')
if @n!=@m and @op_moc=0 goto err_nmsf

declare @fsrc tinyint,@fdst tinyint,@fkey tinyint,@fcmp tinyint
select @fsrc=1,@fkey=2,@fcmp=3

-- to fields
insert into #fld(tid,fld)
select @fsrc,token
from dbo.fn__str_table(@flds_tbl,',')
where not token in (select obj from @excludes)

-- from fields one to one
if @op_121=1
    update fld set from_fld=ff.token
    from #fld fld
    join dbo.fn__str_table(@flds_from,',') ff
    on ff.pos=fld.id and @fsrc=fld.tid
else
    begin
    select @n=count(*) from #fld
    update fld set from_fld=ff.token
    from #fld fld
    join dbo.fn__str_table(@flds_from,',') ff
    on ff.token=fld.fld and @fsrc=fld.tid
    if @@rowcount!=@n and @op_moc=0 goto err_nmsf
    end

-- remove not matched fields
delete from #fld where from_fld is null
update #fld set sep=case
                    when id=(select max(id) from #fld)
                    then '' else ','
                    end
where 1=#fld.tid

-- keys
select @n=dbo.fn__str_count(@keys,',')
insert into #fld(tid,fld,from_fld,sep)
select
    @fkey,dbo.fn__str_at(token,'=',1),isnull(dbo.fn__str_at(token,'=',2),token),
    case when pos=1 then 'on ' else 'and ' end
from dbo.fn__str_table(@keys,',')
join #fld fld on dbo.fn__str_at(token,'=',1)=fld.fld and @fsrc=fld.tid
order by pos
if @@rowcount!=@n goto err_nmkf

if @dbg>1 exec sp__select_astext '
    select
        case tid
        when 1 then ''S''
        when 2 then ''K''
        when 3 then ''C''
        when 4 then ''D''
        end
        as [T],*
    from #fld
    where tid=2 order by id
'

-- extra update fields to compare
select @n=dbo.fn__str_count(@flds_cmp,',')
insert into #fld(tid,fld,from_fld)
select @fcmp,fld.fld,from_fld
from #fld fld
join dbo.fn__str_table(@flds_cmp,',')
on fld.fld=token and @fsrc=fld.tid
if @@rowcount!=@n goto err_nmuf

-- add table info and format fields
update #fld set
    tbl='tbl.',
    fld=quotename(fld),
    [from]= case when left(from_fld,1) like '[0-9"(]'
            then '' else 'tmp.'
            end,
    from_fld= case when left(from_fld,1) like '[0-9"(]'
              then from_fld else quotename(from_fld)
              end

-- format
if @op_nofmt=0
    begin
    select @n=max(len(tbl+fld)),@m=max(len([from]+from_fld)) from #fld
    update #fld set
        fld=left(fld+replicate(' ',@n-len(tbl)),@n-len(tbl)),
        from_fld=left(from_fld+replicate(' ',@m-len([from])),@m-len([from])),
        cmm=dbo.fn__comment(quotename(@tbl)+'.'+quotename(fld))
    end

if @dbg>1 exec sp__select_astext '
    select
        case tid
        when 1 then ''S''
        when 2 then ''K''
        when 3 then ''C''
        when 4 then ''D''
        end
        as [T],*
    from #fld
    order by id
'


if @op_cmp=1
    begin
    insert @src select    'select'
    insert @src select    top 1
                        '    case when '+t_f+' is null '
                from    #fld
                where    tid=@fsrc
                order    by id

    insert @src select    '    then ''+'' '
    if @flds_cmp is null
        insert @src select    '    else '''''
    else
        begin
        insert @src select    '    else case when 1!=1'
        insert @src select    '         '+cmp_flds
                    from    #fld
                    where    tid=@fcmp
                    order    by id
        insert @src select    '         then ''<'' else '''''
        insert @src select    '         end'
        end -- flds_cmp
    insert @src select    '    end as [*],'
    insert @src select    '    '+t_f+','+f_f+' [<<]'+sep
                from    #fld
                where    tid=@fsrc
                order    by id
    insert @src select    'from '+quotename(@from)+' tmp '
    insert @src select    'left join '+quotename(@tbl)+' tbl '
    insert @src select    '    '+sep+'('+t_f+'='+f_f+
                          case when @op_lkey=1
                          then ' or ('+t_f+' is null and '+f_f+' is null)'
                          else ''
                          end+')'
                from    #fld
                where    tid=2
    insert @src select 'where 1=1'
    if not @where is null insert @src select 'and '+@where
    end     -- cmp
else
    begin   -- ins/upd
    -- generate update and insert script
    insert @src select 'declare @n bigint, @error int'
    -- title
    if not dbo.fn__comment(@tbl) is null
        insert @src select '-- '+@tbl+': '+dbo.fn__comment(@tbl)

    -- append/update
    if 0=(  select count(*)
            from #fld f
            left join #fld k on k.tid=@fkey and k.fld=f.fld
            where f.tid=@fsrc and k.id is null)
        begin
        if @dbg>1 exec sp__printf '-- append mode'
        end
    else
        begin
        insert @src select ''
        insert @src select 'update tbl set'
        insert @src select '    '+f.tbl+f.fld+'='+
                           f.f_f+f.sep+
                           isnull(' -- '+f.cmm,'')
                    from #fld f
                    left join #fld k on k.tid=@fkey and k.fld=f.fld
                    where f.tid=@fsrc
                    -- and k.id is null 130211\s.zaglio
                    order by f.id
        insert @src select 'from '+quotename(@tbl)+' tbl '
        insert @src select 'join '+quotename(@from)+' tmp '
        insert @src select '    '+sep+'('+t_f+'='+f_f+
                           case when @op_lkey=1
                           then ' or ('+t_f+' is null and '+f_f+' is null)'
                           else ''
                           end+')'
                    from #fld
                    where tid=2

        if not @flds_cmp is null
            begin
            insert @src select    'where '+
                                isnull('('+@where+') and ','')+
                                '(1!=1'
            select top 1 @id=id from #fld where tid=3 order by id
            insert @src select    '      '+cmp_flds
            from    #fld
            where    tid=@fcmp
            order    by id
            insert @src select    '      )'
            end

        insert @src select ''
        insert @src select 'select @error=@@error,@n=@@rowcount'
        if @code=0
            insert @src select 'update #returns set error=@error,updated=@n'
        insert @src select 'if @error!=0 goto end_ins_upd'
        insert @src select ''
        end -- update

    -- insert
    insert @src select 'insert into '+quotename(@tbl)+'('
    insert @src select '    '+fld+sep
                from #fld
                where tid=@fsrc
                order by id
    insert @src select '    )'
    insert @src select 'select'
    insert @src select '    '+f_f+sep
                from #fld
                where tid=@fsrc
                order by id
    insert @src select 'from '+quotename(@from)+' tmp '
    insert @src select 'left join '+quotename(@tbl)+' tbl '
    insert @src select '    '+sep+'('+t_f+'='+f_f+
                       case when @op_lkey=1
                       then ' or ('+t_f+' is null and '+f_f+' is null)'
                       else ''
                       end+')'
                from #fld
                where tid=@fkey
    insert @src select 'where 1=1'
    if @op_lkey=0
        insert @src select top 1        -- only one key fld is necessary
                        '    and '+t_f+' is null'
                    from #fld
                    where tid=@fkey
                    order by id
    else
        -- when the "primary key" is "logic" ...
        insert @src select              -- ... all fields are necessary
                        '    and '+t_f+' is null'
                    from #fld
                    where tid=@fkey
                    order by id

    insert @src select ''
    insert @src select 'select @error=@@error,@n=@@rowcount'
    if @code=0
        insert @src select 'update #returns set error=@error,inserted=@n'

    insert @src select 'end_ins_upd:'
    insert @src select '-- if @error!=0 rollback'

    end -- !cmp

if @code=0
    create table #src(lno int identity, line nvarchar(4000))

if @dbg>0
    begin
    select @n=max(lno) from #src
    select @n=isnull(@n,0)
    insert #src(line) select line from @src order by lno
    exec sp__print_table '#src'
    delete from #src where lno>@n
    if @op_cmp=0
        exec sp__printframe '### above code is not executed ###'
    end

if @code=0 and (@dbg=0 or @op_cmp!=0)
    begin
    create table #returns(error int,updated bigint,inserted bigint)
    insert #returns select 0,0,0
    insert #src(line) select line from @src order by lno
    exec @ret=sp__script_compile
    if @ret!=0 exec sp__print_table '#src'
    select @error=error,@inserted=inserted,@updated=updated
    from #returns
    drop table #returns
    end

if @code=1
    begin
    if object_id('tempdb..#src') is null
        select line from @src order by lno
    else
        insert #src(line) select line from @src order by lno
    end

drop table #fld
if @code=0 drop table #src

goto ret

/* ================================ errors ================================ */

err_nmuf:   exec @ret=sp__err 'compare fields for update do not match with fields of tables',@proc
            goto ret
err_nmkf:   exec @ret=sp__err 'key fields do not match with fields of tables',@proc
            goto ret
err_nmsf:   exec @ret=sp__err 'selected fields do not match in both tables (see options 121,moc)',@proc
            goto ret
err_notf:   exec @ret=sp__err 'source or dest table not found (see options nochk)',@proc
            goto ret
err_whre:    exec @ret=sp__err '@where param is not compatible with ...',@proc
            goto ret
/* ================================ help ================================== */
help:
exec sp__usage @proc,'
Scope
    generate and run code for update and insert of records

Parameters
    Code generation syntax
        @tbl        as @tbl
        @flds_tbl   as @keys
        (NB: show generated code to cut and paste into I/O proc
        this is the better practice do not use directly sp__merge
        for I/O because there are many differences between two
        systems except for sync between two well normalized dbs)

    Simple syntax:
        @tbl        as @tbl
        @flds_tbl   as @from
        @from       as @keys

    Complete syntax:
        @tbl        to/destination table
        @flds_tbl   destination fields
        @from       from/source table
        @flds_from  source fields
        @keys       fields of keys for join (* for all of @tbl)
        @flds_cmp   fields for unic key for effective changes for update
        @where      condition applied to @tbl (uses tbl alias)
        @no_ins     exclude this fields (separated by comma) from insert list
                    see code option
        @no_upd     exclude this fields (separated by comma) from update list
                    see code option
        @error      return value of @error happened after insert or update
        @inserted   return number of rows inserted
        @updated    return number of rows update
        @opt        see below
        @dbg        if 1 show the generated code without execute it
                    ### this is useful to use sp__merge as code generatore ###
                    if 2 show debug info about inside tables

Options
    121     match 1st field of 1st table with 1st field of 2nd table and so on
    moc     match only common fields, that exist in both tables
    nochk   do not check existance of tables
    nofmt   dot not format
    lkey    set keys as logic and add compare of nulls
    cmp     show result of a compare select tbl.c1,tmp.c1 [<-]
    dbg     (todo) esecute ins/upd row by row with a cursor

Notes
    The append mode happen when the key is all fields. So only the insert
    statement is executed.

Examples

    -- operative table
    create table tst_base(id int, k1 sysname null, c datetime,act sysname)
    insert tst_base
    select row id,dbo.fn__format(row,"[eng]",default) k1,getdate(),"base"
    from fn__range(1,5,1) -- the last two line is unchanged

    -- temporary working table
    select id,k1,c,"delta" as act into #delta from tst_base
    delete from tst_base where id=1         -- this will added
    update #delta   set c=c+1  where id=2   -- this will updated
    update tst_base set c=null where id=3   -- this test update of nulls
    update tst_base set c=null where id=4   -- this test not update of nulls
    update #delta   set c=null where id=4   -- this test not update of nulls

    -- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< direction
    -- test results using only keys
    exec sp__merge  "tst_base","#delta","id,k1",@opt="cmp",@dbg=1

    -- test results using keys and other fields
    exec sp__merge  "tst_base","#delta","id,k1",@flds_cmp="c",@opt="cmp",@dbg=1

    -- test code with extra flds comp
    exec sp__merge  @tbl="tst_base",
                    @from="#delta",
                    @keys="id,k1",
                    @flds_cmp="c,act"
                    ,@dbg=1

    -- append test mode
    exec sp__merge  "tst_base","#delta","*",@opt="cmp",@dbg=1

    -- code generation test
    exec sp__merge  "tst_base","id,k1",@flds_cmp="c"

    -- run it effectivelly (no dbg, no cmp) with where
    exec sp__merge  @tbl="tst_base",
                    @from="#delta",
                    @keys="id,k1",
                    @flds_cmp="c",
                    @where="tbl.id!=2"

    -- only 1st line is added and 3rd modified
    select * from tst_base

    drop table #delta
    drop table tst_base
'

select @ret=-1

/* ================================ exit ================================== */
ret:
return @ret

end -- proc sp__merge