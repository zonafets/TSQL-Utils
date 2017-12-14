/*  leave this
    l:%licence%
    g:utility,script
    v:121010.1700\s.zaglio: added sql92,nopkx options and sql92 output
    v:121005\s.zaglio: done previous
    v:121004\s.zaglio: a bug near order of idx with includes
    v:120919.1300\s.zaglio: a bug near idx with single fld and some includes
    v:120731.1300\s.zaglio: ix->pk
    v:120727\s.zaglio: adding #src_def
    v:120305\s.zaglio: used fn__script_idx
    v:111028\s.zaglio: moved scripting of triggers in sp__script
    v:110624\s.zaglio: bug near pkey name and blank lines
    v:110510\s.zaglio: near help
    v:110324\s.zaglio: added n/varxxxx(max) and include
    v:100919\s.zaglio: added advice about fkeys
    v:100905\s.zaglio: added go before trigger
    v:100509\s.zaglio: added more noidx,notrg,noidn options
    v:100404\s.zaglio: a bug near "non custer..." & collate in fn__sql_def.. & quote & idx sep
    r:100328\s.zaglio: called alone or from sp__script 3.0
    t:
        create table test(id int identity(10,10),
                          i int, r real,
                          f float constraint test_chk check (f<10.4),
                          s sysname,v varchar(12), nv nvarchar(12),
                          c char(10) default 'c10', nc nchar(10),
                          nn bit not null default 0,
                          num numeric(18,1), dec decimal(18,1),
                          dt datetime constraint test_dt_def default (getdate()),
                          cf as 2*1)

        create  index [ix_test] on [test]([f], [s] desc ) on [primary]
        create  index [ix_test1] on [test]([f] desc ) on [primary]
        create  unique  index [ix_test_uk] on [test]([s]) on [primary]
        go
        create trigger tr_test_del on test for delete as print 'test'
        go
        create trigger tr_test_ins on test for insert as print 'test'
        go
        exec sp__script_table 'test'
        drop table test
    t:sp__script_table 'cfg',@opt='sql92',@dbg=2
    t:sp__script_table 'log_ddl',@opt='sql92',@dbg=2
*/
CREATE proc [dbo].[sp__script_table]
    @obj sysname=null,
    @opt sysname=null,
    @dbg int=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0
if @obj is null goto help

declare
    @id int,
    @db sysname,@sch sysname,@sch_id int,
    @obj_ex sysname,@obj_in sysname,@q nvarchar(2),
    @sql nvarchar(4000),@indent sysname,
    @blank nvarchar(1),@pos int,
    @i int,@n int,@idx sysname,@pk bit,@uq bit,@cl bit,
    @def bit, @src_pos int,@src_id int,
    @src_seed int,@src_incr int,
    @sql92 bit,@sqlite bit,@nofg bit,@nodbo bit,
    @noclt bit,@noidx bit,@noidn bit,@nocmt bit,@nopkx bit,
    @end_declare bit

declare @src table(lno int identity primary key,line nvarchar(4000))

select
    @indent='    ',
    @opt=dbo.fn__str_quote(coalesce(@opt,''),'||'),
    @sqlite=charindex('|sqlite|',@opt),
    @sql92=charindex('|sql92|',@opt),
    @nofg=charindex('|nofg|',@opt),
    @nodbo=charindex('|nodbo|',@opt),
    @noclt=charindex('|noclt|',@opt),
    @noidx=charindex('|noidx|',@opt),
    @noidn=charindex('|noidn|',@opt),
    @nocmt=charindex('|nocmt|',@opt),
    @nopkx=charindex('|nopkx|',@opt),
    @q=case when charindex('|quote|',@opt)>0 then '[]' else '[]' end,
    @def=isnull(object_id('tempdb..#src_def'),0),
    @src_id=isnull(object_id('tempdb..#src'),0),
    @src_seed=ident_seed('#src'),
    @src_incr=ident_incr('#src'),
    @blank=''

if @src_id!=0
    select
        @src_pos=isnull(max(lno),@src_seed)
    from #src

select
    @db =parsename(@obj,3),
    @sch=parsename(@obj,2),
    @obj=parsename(@obj,1)

if @db is null select @db=db_name()
select @sch=[name],@sch_id=id from dbo.fn__schema_of(@obj)
select @obj_ex=quotename(@db)+'.'+coalesce(quotename(@sch),'')+'.'+quotename(@obj)
select @id=object_id(@obj_ex)
if @id is null goto err_nof

/*
sections:
    1. usefull select to collect info into common and confortable tables
    2. apply options correction  (not performant but simple)
    3. create scripts from tables
*/

-- ========================================================================= --

-- =================================================================== tables ==
select identity(int,1,1) as row_id,0 as lrow_id,*
into #table
from fn__script_tbl(@id)
order by name
update #table set lrow_id=(select max(row_id) from #table)
-- ================================================================== columns ==
select identity(int,1,1) as row_id,0 as lrow_id,*
into #columns
from fn__script_col(@id)
order by tablename,tableowner,columnid
update #columns set lrow_id=(select max(row_id) from #columns)
-- ================================================================== indexes ==
-- declare @id int select @id=object_id('???')
select identity(int,1,1) as row_id,0 as lrow_id,*
into #indexes   -- drop table #indexes
from fn__script_idx(@id)
order by index_id,index_column_id

-- differences last row id on each group of included and not included flds
update idxs set lrow_id=lid
from #indexes idxs
join (
    select indexname,is_included_column,max(row_id) lid
    from #indexes
    --where is_included_column=1
    group by indexname,is_included_column
    ) ix
on idxs.indexname=ix.indexname
and idxs.is_included_column=ix.is_included_column

-- select row_id,lrow_id,indexname,columnname,is_included_column,* from #indexes

-- ========================================================================= --
-- compose source
-- remove undesired options
if @sqlite=1
    begin
    select @sql92=1
    update #columns set typename='integer'
    where typename in ('int','bigint','tinyint')
    update #columns set typename='blob'
    where typename in ('uniqueidentifier')
    -- update #columns set typename='text'
    -- where typename typename in ('text','ntext')
    end
if @sql92=1 select @nofg=1,@nodbo=1,@noclt=1,@nopkx=1
if @nofg=1
    begin
    update #table set [owner]=null
    update #indexes set parentowner=null
    end
if @nodbo=1
    begin
    update #table set [filegroup]=null
    update #indexes set [filegroup]=null
    end
if @noclt=1 update #columns set collation=null
if @noidx=1 truncate table #indexes
if @noidn=1 update #columns set [identity]=null

if @sql92=1
    begin
    if exists(select top 1 null from #columns c where c.iscomputed=1)
        goto err_cpt
    if exists(
        select top 1 null
        from #indexes
        where is_included_column=1
        )
        exec sp__printf '-- included columns are not considered'
    end -- sql92 limits
-- sp__script 'continent',@opt='sql92'
-- ============================================================= script table ==

-- head
insert @src select top 1
    'create table '+coalesce(dbo.fn__str_quote(t.[owner],@q)+'.','')
                   +dbo.fn__str_quote(t.[name],@q)
                   +' ('
-- select t.*,i.[primary] as haspk
from #table t

-- =========================================================== script columns ==

insert @src
select top 100 percent              -- exec sp__script_table 'test',@opt='nofg|noclt'
    @indent+dbo.fn__sql_def_col(    -- sp__usage 'fn__sql_def_col'
        c.tablename,null,
        dbo.fn__str_quote(c.columnname,@q),null,c.typename,
        c.[length],c.[precision],c.scale,
        c.allownulls,c.dridefaultname,c.dridefaultcode,c.[identity],
        c.iscomputed,c.computedtext,null/*chkname*/,
        null/*chkcode*/,c.collation,null,null)
    +case when row_id!=lrow_id then ',' else '' end
    as line
-- select c.*,i.[primary] as haspk
from #columns c -- select * from #columns

order by columnid

-- pk inside table
if @nopkx=1
    begin
    select @pos=@src_pos+max(lno)*@src_incr from @src
    select distinct
        @idx=indexname,@pk=[primary],@uq=[unique],@cl=[clustered]
    from #indexes
    where [primary]=1
    if @def=1
        insert #src_def(xtype,cod,idx,flags)
        select 'PK',@idx,@pos,
               @uq*flags.e+@cl*flags.f
        from flags

    insert @src
    select top 1
        @indent+',constraint '+dbo.fn__str_quote(indexname,@q)+' primary key '
        +case when @sql92=0 then
              case [clustered] when 1 then 'clustered '
                                      else 'nonclustered ' end
         else ''
         end
        +'('
    from #indexes
    where indexname=@idx

    -- index columns
    insert @src
    select
        @indent+@indent
        +dbo.fn__str_quote(columnname,@q)+case descending when 1 then ' DESC ' else ' ' end
        +case when row_id!=lrow_id then ',' else '' end
    from #indexes
    where indexname=@idx and is_included_column=0
    order by row_id

    insert @src
    select top 1
        @indent+')'+coalesce(' on '+dbo.fn__str_quote([filegroup],@q),'')
    from #indexes where indexname=@idx

    end -- pk inside table

-- foot
insert @src
select ')'+coalesce(' on '+dbo.fn__str_quote([filegroup],@q),'')
from #table

-- ============================================================= script index ==

-- add indexes
declare @idxs table (id int identity,indexname sysname,pk bit,uq bit,cl bit)
insert @idxs
select distinct
    indexname,[primary],[unique],[clustered]
from #indexes
order by [primary] desc,[indexname]

select @i=min(id),@n=max(id) from @idxs
while (@i<=@n)
    begin

    select @idx=indexname,@pk=pk,@uq=uq,@cl=cl
    from @idxs
    where id=@i

    if @pk=1 and @nopkx=1 goto iterate

    -- blank line
    insert @src select @blank

    select @pos=@src_pos+max(lno)*@src_incr from @src

    if @def=1
        insert #src_def(xtype,cod,idx,flags)
        select case @pk when 1 then 'PK' else 'IX' end ,@idx,@pos,
               @uq*flags.e+@cl*flags.f
        from flags

    -- CREATE [UNIQUE] NONCLUSTERED INDEX [ix_test] ON [dbo].[test] ([f] ASC,[s] DESC) ON [PRIMARY]
    -- ALTER TABLE [dbo].[test] ADD PRIMARY KEY CLUSTERED ([id] ASC) ON [PRIMARY]

    -- head
    if @pk=1
        insert @src
        select top 1
            'alter table '+coalesce(dbo.fn__str_quote(parentowner,@q)+'.','')
                          +dbo.fn__str_quote(parentname,@q)
            +' add constraint '+dbo.fn__str_quote(indexname,@q)+' primary key '
            +case when @sql92=0 then
                  case [clustered] when 1 then 'clustered '
                                          else 'nonclustered ' end
             else ''
             end
            +'('
        from #indexes
        where indexname=@idx
        order by row_id
    else
        insert @src
        select  top 1
            'create '
            +case [unique] when 1 then 'unique ' else '' end
            +case when @sql92=0 then
                  case [clustered] when 1 then 'clustered '
                                          else 'nonclustered ' end
                  else ''
                  end
            +'index '
            +dbo.fn__str_quote(indexname,@q)
            +' on '
            +coalesce(dbo.fn__str_quote(parentowner,@q)+'.','')
            +dbo.fn__str_quote(parentname,@q)
            +'('
        from #indexes
        where indexname=@idx
        order by row_id

    -- body
    -- select * from #indexes order by indexname
    -- exec sp__script_table 'test'

    -- index columns
    insert @src
    select
        dbo.fn__str_quote(columnname,@q)+case descending when 1 then ' DESC ' else ' ' end
        +case when row_id!=lrow_id then ',' else '' end
    from #indexes
    where indexname=@idx and is_included_column=0
    order by row_id
    -- order by columnname  -- wrong

    -- foot

    -- includes
    if @sql92=0
    and exists(
        select top 1 null
        from #indexes
        where indexname=@idx and is_included_column=1
        )
        begin
        insert @src select ') include ('
        insert @src
        select
            dbo.fn__str_quote(columnname,@q)+case descending when 1 then ' DESC ' else ' ' end
            +case when row_id!=lrow_id then ',' else '' end
        from #indexes
        where indexname=@idx and is_included_column=1
        order by row_id
        end -- includes

    insert @src
    select top 1
        ')'+coalesce(' on '+dbo.fn__str_quote([filegroup],@q),'')
    from #indexes where indexname=@idx

    iterate:
    select @i=@i+1
    end -- loop indx

if @nocmt=0
    begin
    if @def=1
        begin
        select @pos=@src_pos+max(lno)*@src_incr from @src
        insert #src_def(xtype,cod,idx,flags)
        select '--',@obj,@pos,0
        end

    insert @src select @blank
    insert @src select '/******************************************************************'
    insert @src select ' *** remember that fkeys are script aside with sp__script_fkeys ***'
    insert @src select ' ******************************************************************/'
    end -- nocmt

-- output
if @src_id!=0
    insert #src(line)
    select line
    from @src
    order by lno
else
    select line from @src order by lno

goto ret

-- =================================================================== errors ==

err_nof:
exec @ret=sp__err 'object %s not found',
                  @proc,@p1=@obj_ex
goto ret

err_cpt:
exec @ret=sp__err 'sql92 not support computed columns',
                  @proc,@p1=@obj_ex
goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Options for tables to script:
    default all dependencies (keys,constraint,indexs,triggers,etc.)
    nofg    no filegroup
    noclt   no collate
    noidx   no indexes
    notrg   no triggers
    noidn   no identity
    nocmt   no comment
    nodbo   no owner
    nopkx   script pk into table and not out as an index
    sql92   no owner,filegroup,collate,comment
'
select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end -- sp__script_table