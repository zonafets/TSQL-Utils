/*  leave this
    l:see LICENSE file
    g:utility
    v:100509\s.zaglio: define structure for txt i/o
    todo: convert csvio into a tree structure
    t:
        sp__dir 'f:\sapshare'
        truncate table csvio
        sp__csvio
*/
CREATE proc [dbo].[sp__csvio]
    @tbl nvarchar(64)=null,
    @fld nvarchar(32)=null,
    @offset int=null,
    @len int=null,
    @info nvarchar(1024)=null,
    @rid sysname=0,
    @out sysname=null,
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc='sp__csvio',@ret=0

if @tbl is null and @fld is null goto help

-- declaration
declare
    @tid tinyint,@rows int,@sql nvarchar(4000),
    @upd bigint,@ins bigint,@del bigint

-- init and addjust
if object_id('csvio') is null
    begin
    select @sql='
    create table csvio(
        tid tinyint,
        id int identity primary key nonclustered,
        rid int not null,                   -- doc parent if this is a sub-segment
        des nvarchar(64) null,              -- tbl
        cod nvarchar(32) null,              -- fld
        flags int null,                     -- (not used)
        idx int not null,                   -- offset
        n   int not null,                   -- len
        at  datetime default (getdate()),   -- update, version
        dat nvarchar(1024) null             -- description
        )
    create clustered index csvio_tid on csvio (tid)'
    if @dbg=1 exec sp__printf '%s',@sql else exec(@sql)
    end -- create

select
    @tid=1,
    @out=dbo.fn__sql_unquotename(@out),
    @info=replace(@info,'''','''''')

create table #vars (id nvarchar(16),value sql_variant)
insert #vars values('"',        '''')
insert #vars values('%tid%',    @tid)
insert #vars values('%rid%',    @rid)
insert #vars values('%tbl%',    @tbl)
insert #vars values('%fld%',    @fld)
insert #vars values('%offset%', @offset)
insert #vars values('%len%',    @len)
insert #vars values('%info%',   @info)
insert #vars values('%out%',    @out)

-- create out table
if not @tbl is null and @fld is null and @offset is null and @len is null and @info is null
and not @out is null
    begin
    select @sql=null
    select @sql=coalesce(@sql+',','')+quotename(cod)+' nvarchar('+convert(sysname,[n])+')'
    from csvio
    where tid=@tid and rid=@rid
    and [des]=@tbl
    order by idx
    select @sql='
    if not object_id("%out%") is null drop table [%out%]
    create table ['+@out+']('+@sql+')'
    end


-- list tbl fields
if not @tbl is null and @fld is null and @offset is null and @len is null and @info is null
and @out is null
    select @sql='
        select des as tbl, cod as fld, idx as offset,n as [len], at as [updt],dat as info
        from csvio
        where tid=%tid% and rid=%rid%
        and des like "%tbl%%"
        order by des,idx
    '


-- deletes


-- delete table
if not @tbl is null and @fld='*' and @offset is null
and @len is null and @info is null
    select @sql='
    update csvio set tid=0 where tid=%tid% and rid=%rid% and des like "%tbl%%"
    select @del=@@rowcount
    '

-- delete fields
if not @tbl is null and not @fld is null and @offset is null
and @len is null and @info is null
    select @sql='
    update csvio set tid=0 where tid=%tid% and rid=%rid% and des="%tbl%" and cod like "%fld%%"
    select @del=@@rowcount
    '

-- add/upd tbl/fld
if not @tbl is null and not @fld is null and not @offset is null
and not @len is null
    select @sql='
        update csvio set idx=%offset%, n=%len%, dat="%info%"
        where tid=%tid% and rid=%rid% and des="%tbl%" and cod="%fld%"
        select @upd=@@rowcount
        if @upd=0
            begin
            insert csvio(tid,rid,des,cod,idx,n,dat)
            select %tid%,%rid%,"%tbl%","%fld%",%offset%,%len%,"%info%"
            select @ins=@@rowcount
            end
        '


if not @sql is null
    begin
    exec sp__str_replace @sql out,@tbl=1
    if @dbg=1 exec sp__printf '%s',@sql
    else
        begin
        select @ins=0,@upd=0,@del=0
        exec sp_executesql @sql,
            N'@ins bigint out,@upd bigint out,@del bigint out',
            @ins=@ins out,@upd=@upd out,@del=@del out
        if @out is null exec sp__printf '-- %d rows inserted, %d updated,%d freed',@ins,@upd,@del
        else exec sp__printf '-- table dropped and recreated'
        end
    end


goto ret

help:
exec sp__usage @proc,'
Examples
    sp__csvio                                    -->this help
    sp__csvio @tbl                               -->list tbl fields
    sp__csvio @tbl,@fld,@offset,@len,@info       -- add or update
    sp__csvio @tbl,@fld                          -- delete
    sp__csvio @tbl,''*''                         -- delete table

    sp__csvio_in @path,@table,@definition

'

ret:
return @ret
end -- sp__csvio