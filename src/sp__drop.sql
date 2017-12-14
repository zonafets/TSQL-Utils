/*  leave this
    l:see LICENSE file
    g:utility
    v:120802\s.zaglio: added drop of tbl.col
    v:110331\s.zaglio: removed use of fn__locked
    v:101112\s.zaglio: a bug near deleting tables in tempdb that's not #temp tables
    v:100919\s.zaglio: added order by name desc to manage 1/2 problems with fkeys
    v:100718\s.zaglio: a total remake of old, to delete files,temps,any obj without errors
    t:
        declare @sql nvarchar(4000)
        select @sql='
            create table drop_test1(a int)
            create table drop_test2(a int)
            create table drop_test3(a int)
            create table #drop_test4(a int)
            '

        exec(@sql)  exec sp__printf 'multiple test'
        exec sp__drop 'drop_test1|drop_test2|drop_test3|#drop_test4'
        exec sp__dir 'drop_test*'

        exec(@sql)  exec sp__printf 'wild test'
        exec sp__drop 'drop_test*',@dbg=1
        exec sp__dir 'drop_test*'
        exec sp__drop '#drop_test4|drop_test*',@simul=0
        exec sp__dir 'drop_test*'
        exec sp__drop '#drop_test4',@dbg=1
        select * from #drop_test4
*/
CREATE proc [dbo].[sp__drop]
    @names  nvarchar(4000)=null,
    @xtype  nvarchar(2)=null,
    @simul  bit=null,
    @opt    sysname=null,
    @dbg    int=null
as
begin
set nocount on
declare @proc sysname,@ret int
select
    @proc=object_name(@@procid),@ret=0,@dbg=isnull(@dbg,0),
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

if @names is null goto help
if @names='*' goto err_no

declare
    @i int,@n int,
    @obj nvarchar(512),@db sysname,@xt nvarchar(4),
    @sql nvarchar(4000),@sch sysname,
    @col sysname

-- select * from tempdb..sysobjects where name like '%objs%' and xtype='u'
-- drop table #sp__drop_objs
create table #sp__drop_objs(
    id int identity,
    db sysname null,sch sysname null,
    obj nvarchar(512),
    col sysname null,
    xt nvarchar(4) null
    )


-- =================================== fill temp table with names

-- declare @names nvarchar(4000) select @names='#t|[#tt]|here|[test]|[db].dbo.[test]|c:\test.txt|sintesi_vi00*|#sp__drop_objs'
-- declare @names nvarchar(4000) select @names='drop_test3'
if charindex('|',@names)>0
    insert #sp__drop_objs(obj) select token from dbo.fn__str_params(@names,'|',default)
else
    insert #sp__drop_objs(obj) select @names


-- =================================== update with db info & normalize name
update #sp__drop_objs set
    db= case
        when left(obj,1)='#' or left(obj,2)='[#'
        then 'tempdb'
        when left(obj,1)!='[' and (obj like '%[\:/]%')
        then '' -- a file
        else isnull(parsename(obj,3),db_name())
        end,
    obj=case
        when left(obj,1)='#' or left(obj,2)='[#'
        then parsename(obj,1)
        when left(obj,1)!='[' and (obj like '%[\:/]%')  -- file
        then obj
        else case
             when charindex('*',obj)>0                  -- multiobj
             then replace(replace(parsename(obj,1),'_','[_]'),'*','%')
             else
                case -- tbl.col
                when not object_id(parsename(obj,2),N'U') is null
                then obj
                else parsename(obj,1)
                end
             end
        end

if exists(select null from #sp__drop_objs where obj in ('*','sp__drop')) goto err_no


-- =================================== update with schema and type info from each db

-- declare @i int,@n int,@obj nvarchar(512),@db sysname,@sql nvarchar(4000),@dbg bit,@simul bit set @dbg=1
select @i=min(id),@n=max(id) from #sp__drop_objs
while (@i<=@n)
    begin
    select @db=db,@obj=obj from #sp__drop_objs where id=@i

    if charindex('.',@obj)>0
        begin
        select @col=parsename(@obj,1),@obj=parsename(@obj,2)
        select @sql ='alter table '+quotename(@obj)+' drop constraint '
        select @sql = @sql + (select sys_obj.name as constraint_name
        from sysobjects sys_obj
        join syscomments sys_com on sys_obj.id = sys_com.id
        join sysobjects sys_objx on sys_obj.parent_obj = sys_objx.id
        join sysconstraints sys_con on sys_obj.id = sys_con.constid
        join syscolumns sys_col on sys_objx.id = sys_col.id
        and sys_con.colid = sys_col.colid
        where
        sys_obj.uid = user_id() and sys_obj.xtype = 'd'
        and sys_objx.name=@obj and sys_col.name=@col)
        if @dbg=0 exec(@sql) else exec sp__printsql @sql

        if exists(
            select null
            from syscolumns
            where id=object_id(@obj) and name=@col
            )
            begin
            select @sql ='alter table '+quotename(@obj)
                        +' drop column '+quotename(@col)
            if @dbg=0 exec(@sql) else exec sp__printsql @sql
            end

        select @i=@i+1
        continue
        end -- drop tbl.col

    if @db!='' -- not a file
    and exists(select null from master..sysdatabases where [name]=@db)
        begin

        if charindex('%',@obj)>0
            begin
            select  @simul=coalesce(@simul,1),
                    @sql='insert #sp__drop_objs(db,sch,obj,xt)
                          select ''%db%'',u.[name],o.[name],o.xtype
                          from [%db%]..sysobjects o with (nolock)
                          join [%db%]..sysusers u with (nolock)
                          on o.uid=u.uid
                          where ''S'' not in (o.xtype,o.[type])
                          and o.name like ''%obj%''
                          order by o.name desc
                          '
            end
        else
            begin
            if left(@obj,1)='#'
                select  @sql='
                              update objs set xt=o.xtype,sch=''''
                              from #sp__drop_objs objs
                              join [%db%]..sysobjects o with (nolock)
                              on o.id=object_id(''%db%..%obj%'')
                              where objs.id=%id%
                             '
            else
                select  @sql='
                              update objs set xt=o.xtype,sch=isnull(u.[name],'''')
                              from #sp__drop_objs objs
                              join [%db%]..sysobjects o with (nolock)
                              on o.name=''%obj%'' and ''S'' not in (o.xtype,o.[type])
                              join [%db%]..sysusers u with (nolock) on o.uid=u.uid
                              where objs.id=%id%
                             '
            end

        exec sp__str_replace @sql out,'%db%|%obj%|%id%',@db,@obj,@i
        if @dbg=1 exec sp__printf '%s',@sql
        exec(@sql)
        end -- db obj

    select @i=@i+1
    end -- expand

if @dbg=1 exec sp__select_astext 'select * from #sp__drop_objs order by obj'

if @simul=1 exec sp__printf '-- use @simul=0 when delete multiple objects'


-- =================================== delete

-- declare @i int,@n int,@obj nvarchar(512),@db sysname,@sql nvarchar(4000),@xt sysname
--    declare @dbg bit,@sch sysname,@simul
--    select @dbg=1
select @i=min(id),@n=max(id) from #sp__drop_objs
while (@i<=@n)
    begin
    select @db=db,@sch=sch,@obj=obj,@xt=xt
    from #sp__drop_objs where id=@i
    if @db='' -- is a file
        begin
        select @obj=dbo.fn__str_quote(@obj,'"')
        set @sql='del /q '+@obj
        if @dbg=1 exec sp__printf @sql
        if @dbg=1 exec master..xp_cmdshell @sql else exec master..xp_cmdshell @sql,no_output
        end
    else
        begin
        if @db!='' and not @xt is null
            begin
            -- exec sp__printf 'db=%s, sch=%s, obj=%s',@db,@sch,@obj
            select @sql=
                case when @db!=db_name() and left(@obj,1)!='#' then 'use '+quotename(@db)+';' else '' end+
                'drop '+case
                when @xt='TR'   then 'trigger '
                when @xt='SN'   then 'synonym '
                when @xt='U'    then 'table '
                when @xt='P'    then 'proc '
                when @xt='V'    then 'view '
                when @xt in ('PK','UQ','F')     then 'index '
                when @xt in ('FN','IF','TF')    then 'function '
                else null
                end
                +
                case when @db='tempdb'
                then quotename(@obj)
                else quotename(@sch)+'.'+quotename(@obj)
                end

            if @dbg=1 or @simul=1 exec sp__printf '%s',@sql
            else exec(@sql)

            end -- db obj

        if @sch is null and @xt is null and charindex('%',@obj)=0 and @dbg=1
            exec sp__printf 'obj "%s" not found',@obj
        end -- file/db obj

    select @i=@i+1
    end --- while

drop table [#sp__drop_objs]

goto ret

err_no:     exec @ret=sp__err 'cannot delete all objects or sp__drop itself',@proc  goto ret

help:

exec sp__usage @proc,'
Scope
    delete objects of any type

Parameters
    @names  can be a single object (with db), a file
            can use * wild chars for group of objs
            can use | to delete multiple objs (obj|obj|file|etc)
            can be a table.column tha has constraints to delete
    @xtypes not used
    @simul  when * is used, this must be specified eual to 1 do act
    @opt    options
'
select @ret=-1

ret:
return @ret
end -- sp__drop