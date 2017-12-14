/*  leave this
    l:see LICENSE file
    g:utility
    k:insert
    v:111229\s.zaglio: adapted to new sp__script_template
    r:111228\s.zaglio: adapting to new sp__script_template
    r:111227\s.zaglio: adapting to new sp__script_template
    r:111223\s.zaglio: adapting to new sp__script_template
    v:111103\s.zaglio: added bincols option and db check
    v:111031\s.zaglio: added N before '
    v:110824\s.zaglio: adapted to new sp__script_template
    v:110707\s.zaglio: a small bug near ident
    v:110706.1221\s.zaglio: a bug near truncate and added restore
    v:110705\s.zaglio: added @opt
    v:110518\s.zaglio: injected strings with '
    v:100919\s.zaglio: added insert from #tmp (useful to find error string or bin truncated)
    v:100601\s.zaglio: added @top and @where
    v:100514\s.zaglio: print script to insert data
    t:
        create table test_script_data(id int identity, a sysname, d datetime default(getdate()))
        insert test_script_data(a) select 'one'
        insert test_script_data(a) select 'two'
        exec sp__script_data 'test_script_data'
        exec sp__script_data 'test_script_data',@where='a="two"'
        exec sp__script_data 'test_script_data',@top=1,@dbg=1
        select * into #t from test_script_data
        exec sp__script_data '#t'   -- TODO
        drop table test_script_data
        drop table #t
*/
CREATE proc sp__script_data
    @tbl sysname=null,
    @where sysname=null,
    @top sysname=null,
    @opt sysname=null,
    @dbg bit=null
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0,@dbg=isnull(@dbg,0),
       @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

if @tbl is null goto help

if left(@tbl,1)!='#' and object_id(@tbl) is null goto err_noo
if left(@tbl,1)='#' and object_id('tempdb..'+@tbl) is null goto err_noo

select @tbl=dbo.fn__sql_unquotename(@tbl)

if not @where is null and (dbo.fn__occurrence(@where,'"') % 2)=0
    select @where=replace(@where,'"','''')

declare
    @flds nvarchar(4000),
    @oflds nvarchar(4000),@merge bit,@restore bit,@scramble bit,
    @dst sysname,@n int, @src sysname,
    @excludes sysname,@noinc bit,
    @identity sysname                -- main section

declare @bincols table ([name] sysname)

if charindex('|bincols:',@opt)>0
    begin
    insert @bincols([name])
    select token
    from dbo.fn__str_table(dbo.fn__str_between(@opt,'|bincols:','|',default),'|')
    end -- bincols

create table #tpl(lno int identity primary key,line nvarchar(4000))
create table #tpl_sec(lno int identity,section sysname,line nvarchar(4000))

-- first define the template
insert #tpl(line)
select line
from dbo.fn__ntext_to_lines('
%safety%:
if db_name()=''%db%''
    begin
    raiserror(''for safety reasons I can not run on the same database'',10,1) with nowait
    goto safe_skip
    end

-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%before%:
%safety%

select top 0 * into [%dst%] from [%src%]    -- |merge|

alter table [%dst%] disable trigger all

set identity_insert [%dst%] on              -- |ident|

truncate table [%dst%]                      -- |where|
-- truncate table [%dst%]

-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%after%:

exec sp__merge  "%src%",                    -- |merge|
                @from="%dst%",              -- |merge|
                @keys="???",                -- |merge|
                @flds_cmp="%flds%"          -- |merge|

set identity_insert [%dst%] off             -- |ident|

alter table [%dst%] enable trigger all

',0)

select @identity=[name]
from syscolumns
where id=object_id(@tbl)
and columnproperty(id,[name],'IsIdentity')=1

select
    @merge=charindex('|merge|',@opt),
    @restore=charindex('|restore|',@opt),
    @scramble=charindex('|scramble|',@opt),
    @noinc=charindex('|noinc|',@opt),
    @flds=dbo.fn__flds_of(@tbl,'|',case when @noinc=1 then @identity else null end),
    @oflds=replace(dbo.fn__flds_quotename(@flds,'|'),'|',','),
    @dst=case when @merge=1 then '#' else '' end + @tbl,
    @src=@tbl,
    @excludes=''

create table #out (lno int identity(10,10),line nvarchar(4000))
create table #src (lno int identity,line nvarchar(4000))

if @identity is null and @noinc=0 select @excludes=@excludes+'|ident'
if @merge=0 select @excludes=@excludes+'|merge'

-- <fields>
insert #tpl_sec
select
    '%fields%',
    case
    when @scramble=1 and (t.[name] like '%char' or t.name in ('sysname'))
    then 'dbo.fn__str_scramble('+dbo.fn__str_quote(c.[name],'[]')+
         ',rand(checksum(newid()))) as ['+c.[name]+']'
    else dbo.fn__str_quote(c.[name],'[]')
    end
    +
    case
    when colorder=(select max(colorder) from syscolumns where id=object_id(@tbl))
    then ''
    else ','
    end
from syscolumns c
join systypes t
on c.xusertype=t.xusertype
where id=object_id(@tbl)
order by colorder

-- create the script to script the select of data and store into #out

insert #src(line) select 'insert #out(line) '
insert #src(line) select 'select '+coalesce('top '+@top+' ','')+' ' -- ' ''N'''
-- insert #src(line) select '''insert ['+@dst+']('+@oflds+') '

-- sp__Script_data 'sios_dict',@opt='restore'
-- sp__Script_data 'sios_dict',@opt='bincols:cod'

insert #src(line)
select
    '+'+
    case
    -- if binary column
    when exists(select null from @bincols where [name]=c.[name])
    then
        'coalesce(dbo.fn__hex(convert(varbinary(8000),'+dbo.fn__str_quote(c.[name],'[]')+')),''null'')'
    -- if numeric field
    when t.[name] like '%int' or t.name in ('real','float','decimal','numeric')
    then
        'coalesce(convert(nvarchar(4000),'+
        dbo.fn__str_quote(c.[name],'[]')+
        ',126),''null'')'
    else
        replace(
            'coalesce("N"""+replace(convert(nvarchar(4000),'
            +
            case
            when @scramble=1 and (t.[name] like '%char' or t.name in ('sysname'))
            then 'dbo.fn__str_scramble('+dbo.fn__str_quote(c.[name],'[]')+
              ',rand(checksum(newid())))'
            else dbo.fn__str_quote(c.[name],'[]')
            end
            +
            ',126),"""","""""")+"""","null")',
            '"',''''
        )
    end+
    case
    when colid= (select max(colid)
                 from syscolumns
                 where id=object_id(@tbl)
                )
    then ''
    else '+'','''
    end
from syscolumns c
join systypes t on c.xusertype=t.xusertype
where c.id=object_id(@tbl)
and (
    -- exclude identity if opt "noinc"
    @identity is null
    or @noinc=0
    or (@noinc=1 and @identity!=c.[name])
    )
order by c.colorder
insert #src(line) select ' as line '
insert #src(line) select 'from '+quotename(@tbl)

if not @where is null insert #src(line) select 'where '+@where

if @dbg=1 exec sp__print_table '#src'
exec sp__script_compile

if (select count(*) from #out)=0 goto err_nrec

-- now #out(line) contain cvs of selected lines

update #out set line='union select '+line

-- break inserts into small blocks because is faster

select @n=count(*)/64+1 from #out

set identity_insert #out on

-- insert 'inserts'
insert #out(lno,line)
select (r.row-1)*640+1,'insert into ['+@dst+']'
from dbo.fn__range(1,@n,1) r

-- insert 'insert' fields
insert #out(lno,line)
select (r.row-1)*640+5,'    ('+@oflds+')'
from dbo.fn__range(1,@n,1) r

set identity_insert #out off

update #out set line='      select '+substring(line,14,4000)
from #out o
join dbo.fn__range(1,@n,1) r
on o.lno=(r.row-1)*640+10


-- begin to out the script
exec sp__script_template '%safety%'

if not @where is null
or not @top is null
    select @excludes=@excludes+'|where'

exec sp__script_template '%before%',
                         @tokens='%dst%|%flds%|%src%',
                         @v1=@dst,@v2=@oflds,@v3=@src,
                         @opt='print',
                         @excludes=@excludes
                         --,@dbg=1

exec sp__print_table '#out'

-- mix
exec sp__script_template '%after%',
                         @tokens='%dst%|%flds%|%src%',
                         @v1=@dst,@v2=@oflds,@v3=@src,
                         @opt='print',
                         @excludes=@excludes
                         -- ,@dbg=1

exec sp__printf '\nsafe_skip:'

drop table #src
drop table #out
drop table #tpl
drop table #tpl_sec
goto ret

-- =================================================================== errors ==
err_noo:    exec @ret=sp__err 'no table found',@proc    goto ret
err_nrec:   exec @ret=sp__err 'no records found',@proc    goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    generate inserts for @tbl
    if dest table has identity generate adeguate code

Parameters
    @tbl        name of table where select/insert data
    @where      optional filter for rows
    @top        optional top (@top) rows
    @opt        options

Options
    merge       step into a middle #tbl for mixing operations
                The ukey is defined manually
    scramble    apply scramble function to *chars fields
    noinc       skip autoincrement column
    bincols:x|y convert columns x and y and ... into binary (0x545...)
                This is necessary in some cases where a nvarchar
                filed is used as binary container, because a special
                character block the copy&paste to&from clipboard

'
select @ret=-1

ret:
return @ret
end -- sp__script_data