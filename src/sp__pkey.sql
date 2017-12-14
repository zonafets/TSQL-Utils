/*  leave this
    l:see LICENSE file
    g:utility
    v:100523\s.zaglio: a bug near counts and added excludes
    v:100321\s.zaglio: return pkey's fields or finds possibles
    t:sp__pkey 'MATMAS_MARAM',@dbg=1
    t:
        sp__pkey 'MATMAS04_MARA_MTXH_MTXL'
        select * from MATMAS04_MARA_MTXH_MTXL
        sios_select '*','MTXH'
*/
CREATE proc sp__pkey
    @tbl sysname=null,
    @pk nvarchar(512)=null,
    @excludes sysname=null,
    @dbg bit=0
as
begin
declare @proc sysname,@ret int
select @proc='sp__pkey',@ret=0
if @tbl is null goto help

declare
    @flds nvarchar(4000),@i int,@n int,@nr bigint,@r bigint,
    @sql nvarchar(4000),@fld sysname,@pks int

select @flds=dbo.fn__flds_of(@tbl,',',@excludes)
if @dbg=1 exec sp__printf '%s',@flds
select @i=1,@n=dbo.fn__str_count(@flds,',')

exec sp__count @tbl,@nr out
select @pks=0

while (@i<=@n)
    begin
    select @fld=dbo.fn__str_at(@flds,',',@i)
    select @sql='select @r=count(*) from (select distinct ['+@fld+'] from ['+@tbl+']) a'
    if @dbg=1 select @sql=@sql+' print @r'
    select @r=null
    if @dbg=1 exec sp__printf @sql
    exec sp_executesql @sql,N'@r bigint out',@r=@r out
    if @r=@nr
        begin
        if @pk is null select @pk=@fld
        exec sp__printf '%s possible pk:%s',@tbl,@fld
        select @pks=@pks+1
        end
    select @i=@i+1
    end

-- TODO:if @pks=0 ... search for combination
goto ret

help:
exec sp__usage @proc

ret:
return @ret
end -- sp__pkey