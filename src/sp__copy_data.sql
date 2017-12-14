/*  leave this
    g:utility
    v:100517\s.zaglio: changed @objs to #objs
    r:100513\s.zaglio: copy data from specular table of different databases
    todo:integrate into sp__copy)
    todo:now dtbls=stbls
*/
CREATE proc sp__copy_data
    @src sysname=null,
    @dst sysname=null,
    @truncate bit=0,
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc='sp_copy_data',@ret=0
if @src is null and @dst is null goto help

declare
    @sdb sysname,@ssch sysname,@stbl sysname,
    @ddb sysname,@dsch sysname,@dtbl sysname,
    @dflds nvarchar(4000), @sflds nvarchar(4000),
    @sql nvarchar(4000),@i int,@n int,
    @like sysname,
    @end_declare bit

create table #objs (id int identity,src sysname,dst sysname)

select @sdb=db,@ssch=sch,@stbl=obj from dbo.fn__parsename(@src,1,default)
select @ddb=db,@dsch=sch,@dtbl=obj from dbo.fn__parsename(@dst,1,default)

if charindex('.',@src)>0 and @sdb=@ddb goto err_pat

if charindex('*',@src)=0 insert #objs select @src,@dst
else
    begin
    -- select @sdb,@ssch,@stbl,@ddb,@dsch,@dtbl
    select @like=replace(dbo.fn__sql_unquotename(@stbl),'*','%')
    select @sql='
        use %sdb%
        insert #objs
        select "%sdb%"+"."+"%ssch%"+"."+[name],"%ddb%"+"."+"%dsch%"+"."+[name]
        from sysobjects
        where [name] like "%like%"
        and xtype="u"
    '
    exec sp__str_replace @sql out,
        '"|%sdb%|%ssch%|%ddb%|%dsch%|%like%',
        '''',@sdb,@ssch,@ddb,@dsch,@like
    if @dbg=1 exec sp__printf '%s',@sql
    exec(@sql)
    end -- collect objs

create table #vars (id nvarchar(16),value sql_variant)
select @i=min(id),@n=max(id) from #objs

while (@i<=@n)
    begin
    select @src=src,@dst=dst from #objs where id=@i

    select @sdb=db,@ssch=sch,@stbl=obj from dbo.fn__parsename(@src,1,default)
    select @ddb=db,@dsch=sch,@dtbl=obj from dbo.fn__parsename(@dst,1,default)

    select @sflds=dbo.fn__flds_quotename(dbo.fn__flds_of(@stbl,',',null),',')
    select @dflds=dbo.fn__flds_quotename(@sflds,',')

    truncate table #vars
    insert #vars values('"',        '''')
    insert #vars values('%sdb%',    @sdb)
    insert #vars values('%ssch%',   @ssch)
    insert #vars values('%stbl%',   @stbl)
    insert #vars values('%ddb%',    @ddb)
    insert #vars values('%dsch%',   @dsch)
    insert #vars values('%dtbl%',   @dtbl)
    insert #vars values('%sflds%',  @sflds)
    insert #vars values('%dflds%',  @dflds)
    if @truncate=1 insert #vars values('%truncate%', 'truncate table '+@dsch+'.'+@dtbl)
    else insert #vars values('%truncate%','')

    select @sql='
    use %ddb%
    if objectproperty(object_id("%dsch%.%dtbl%"),"tablehasidentity")=1
        set identity_insert %dtbl% on
    %truncate%
    declare @rows bigint
    insert into %dsch%.%dtbl%(%dflds%)
    select %sflds%
    from %sdb%.%ssch%.%stbl%
    select @rows=@@rowcount
    exec sp__printf "-- %dtbl%:%d inserted",@rows
    if objectproperty(object_id("%dsch%.%dtbl%"),"tablehasidentity")=1
        set identity_insert %dtbl% off
    '
    exec sp__str_replace @sql out,@tbl=1

    if @dbg=1 exec sp__printf '%s',@sql
    else exec(@sql)
    if @@error!=0 exec sp__printf '%s',@sql

    select @i=@i+1
    end -- while

drop table #vars

goto ret

err_pat:    exec @ret=sp__err 'I see a ''.'' but source and dest db are same; maybe forgot schema?',@proc goto ret

help:
exec sp__usage 'sp__copy_data','
Parameters
    @src        source path with database.schema.tables (accept wildcard * on object)
    @dst        destination path with database (names are sames)
    @truncate   truncate dest table
    @dbg        show script but not execute

Examples
    sp__copy_data ''source_db.dbo.obj'',''dest_db'',@dbg=1,@truncate=1
    sp__copy_data ''source_db.dbo.obj*'',''dest_db'',@truncate=1,@dbg=1
    sp__copy_data ''source_db..obj*'',''dest_db'',@truncate=1,@dbg=1
'

select @ret=-1

ret:
return @ret
end -- sp__copy_data