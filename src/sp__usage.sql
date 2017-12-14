/*  leave this
    l:see LICENSE file
    g:utility
    v:120824\s.zaglio: added usage of #sp
    v:120112\s.zaglio: now print @obj version near usage of ...
    v:110706\s.zaglio: added odd/event test for presence of "
    v:110628\s.zaglio: a bug near info on fn
    v:110513\s.zaglio: a small bug
    v:110510\s.zaglio: replace " with ' on line starting with sp_
    v:110507\s.zaglio: replace " with ' if inside sql code
    v:110422\s.zaglio: expanded @extra to blob
    v:110406\s.zaglio: added @p1...,@opt, removed old @test params
    v:110312\s.zaglio: added autoreverse if remote call
    v:100919.1000\s.zaglio: more compatible mssql2k
    v:100919\s.zaglio: out of extra without replacement of macro
    v:100723\s.zaglio: @force=0 in print of @extra (for sp__style)
    v:100707\s.zaglio: show info about reversed
    v:100501\s.zaglio: added @reverse
    v:100404\s.zaglio: added #vars replacements
    v:100228\s.zaglio: added db name support
    v:090222\s.zaglio: addded out&null info
    v:090805\S.Zaglio: removed @force=0 on printf
    v:090729\S.Zaglio: revision
    v:090623\S.Zaglio: revision
    v:090616\S.Zaglio: added @extra
    v:090610\S.Zaglio: added @print
    v:090608\S.Zaglio: added -- to use as template for sp call
    v:090520\S.Zaglio: added more info to params
    v:081117\S.Zaglio: made indipendent from sp__dir
    v:081021\S.Zaglio: print a fast & simple expanation of parameters of sp (future expansion)
    t:sp__usage 'fn__comments'
*/
CREATE PROCEDURE [dbo].[sp__usage]
    @obj   sysname=null,
    @extra ntext=null,  -- extra help until will be integrated in a help system
    @p1    sql_variant=null,
    @p2    sql_variant=null,
    @p3    sql_variant=null,
    @p4    sql_variant=null,
    @opt   sysname=null
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0,
       @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

if @obj is null goto help

create table #src (lno int identity,line nvarchar(4000))
-- insert #src(line) select 'test'
create table #blob(id int identity,blob ntext)
create table #cols(id int identity,name sysname,colorder int)

declare
    @n int,@db sysname,@reverse bit,@id bigint,@sql nvarchar(4000),
    @sel bit,@xt nvarchar(2),@ver nvarchar(32)

select
    @reverse=dbo.fn__isremote(@@spid),
    @sel=charindex('|sel|',@opt)

if left(@obj,1)='#'
    begin
    select @id=object_id('tempdb..'+@obj)
    select @xt=xtype from tempdb..sysobjects with (nolock) where id=@id
    insert #cols select name,colorder
    from tempdb..syscolumns c with (nolock)
    where left(c.name,1)='@'
    end
else
    begin
    select @id=object_id(@obj)
    select @xt=xtype from sysobjects with (nolock) where id=@id
    insert #cols
    select name,colorder from syscolumns c with (nolock)
    where left(c.name,1)='@'
    end


if @id is null goto err_obj

if (@xt) in ('FN','TF','IF')
    begin
    -- select * from syscolumns where id=object_id('fn__comment')
    -- select * from syscolumns where id=object_id('fn__comments')
    select @sql=null
    select @sql=isnull(@sql+',','')+'/*'+c.[name]+'*/default'
    from #cols
    order by c.colorder
    if @xt='IF'
        select @sql='select dbo.'+@obj+'('+@sql+')'
    select @sql='select * from ['+@obj+']('+@sql+')'
    if @sel=1 select @sql else print @sql
    if @extra is null goto ret
    end --

select @ver=' ('+tag+':'+convert(sysname,val1)+') '
from dbo.fn__script_info(@obj,'rv',0)
select @ver=isnull(@ver,'')

insert #src(line)
select 'usage of ' + @obj+@ver+
                     case @reverse
                     when 1
                     then '(list is reversed for remote servers)'
                     else ''
                     end

-- print parsename('db..obj',3)
-- print isnull(parsename('obj',3),'??')
select @db=parsename(@obj,3)
if @db is null select @db=db_name()
-- print parsename('obj',1)
select @obj=parsename(@obj,1)

exec('
use ['+@db+']
declare @n int,@obj sysname select @obj='''+@obj+'''
select @n=max(len(name)) from syscolumns with (nolock) where id=object_id(@obj)
insert into #src(line)
select
    ''    ''+left(c.[name]+space(@n),@n) +
    '' ''+case
        when t.name in (''nvarchar'',''nchar'') then t.name+''(''+convert(sysname,c.length/2)+'')''
        when t.name in (''char'',''varchar'') then t.name+''(''+convert(sysname,c.length)+'')''
        else t.name end+
    -- case when c.isnullable=1 then ''=null'' else '''' end+   because all def params are nullable
    '' ''+case when c.isoutparam=1 then ''out'' else '''' end+
    '','' as line
from syscolumns c with (nolock)
inner join systypes t with (nolock)  on c.xusertype=t.xusertype
where id=object_id(@obj) and left(c.name,1)=''@'' order by colid
')

insert #blob(blob) select @extra
exec sp__write_ntext_to_lines @crlf=0
drop table #blob

if not object_id('tempdb..#vars') is null
    exec sp__str_replace '#src','#vars'

update #src set line=replace(line,'%proc%',@obj)
if not @p1 is null update #src set line=replace(line,'%p1%',convert(nvarchar(4000),@p1,126))
if not @p2 is null update #src set line=replace(line,'%p2%',convert(nvarchar(4000),@p2,126))
if not @p3 is null update #src set line=replace(line,'%p3%',convert(nvarchar(4000),@p3,126))
if not @p4 is null update #src set line=replace(line,'%p4%',convert(nvarchar(4000),@p4,126))

-- replace " with ' if even occurrences and in particular cases
update #src set line=replace(line,'"','''')
where 1=1
and (charindex('"',line)>0 and dbo.fn__str_count(line,'"')%2=1)
and (
    charindex(' ',ltrim(line))>0
    and (   left(ltrim(line),charindex(' ',ltrim(line))-1) in
                ('select','insert','exec','if','else','update','declare','set')
        or left(ltrim(line),3)='sp_'
        )
    or left(ltrim(line),1)='@'
    )
if @sel=1
    select line from #src order by lno
else -- print
    exec sp__print_table '#src',@reverse=@reverse

drop table #src
goto ret

-- =================================================================== errors ==
err_obj:    exec @ret=sp__err 'object not found' goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope of %proc% Version 1.04.110406
    print info and help about an object

Notes
    * if the object is a function, add a line of code with its call
    * if called remotelly, print help in reverse order (MS remote print problem)
    * if declare #vars, inside tokens are replaced (see sp__str_replace)
    * *********************************************
    * ** this help is a template for all others  **
    * *********************************************
    * future strategy is to use this sp to populate wiki table
    * in the lines that start with "exec","select",etc or "sp_"
      is considered sql code and " will be replaced with ''

Parameters
    @obj    name of object
    @extra  info/help text
            if @extra contain macros, this will be replaced
            macro   mean
            %proc%  replaced with @obj
            %p1%    replaced with @p1
            %p...%  replaced with @p...
    @opt    options
            sel     return help as select instead of print

Examples

    exec sp__usage ''sp__usage'',''
    Scope of %obj%
        this is an examples with replace %p1%
        '',
        @p1=''p1_test''
'
select @ret=-1

ret:
return @ret
end -- sp__usage