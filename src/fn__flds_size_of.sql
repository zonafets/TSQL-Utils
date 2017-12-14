/*  leave this
    l:see LICENSE file
    g:utility
    v:090916\S.Zaglio: a better managemnt of temp tables
    v:090202\S.Zaglio: return a series of field's sizes of table
    t: print dbo.fn__flds_size_of('sysobjects','|',null) --> name and id and xtype ...
*/
CREATE function [dbo].[fn__flds_size_of](@tbl sysname, @seps nvarchar(32)=',',@excludes sysname='')
returns nvarchar(4000)
as
begin
set @tbl=dbo.fn__sql_unquotename(@tbl)
if @excludes<>'' set @excludes=@excludes+@seps -- coz error into fn_str_at

declare @flds nvarchar(4000) set @flds=''

declare @tmp bit
if left(@tbl,1)='#' set @tbl='tempdb..'+@tbl
if charindex('.#',@tbl)>0 set @tmp=1 else set @tmp=0

if @tmp=0
    declare flds cursor local for
        select convert(nvarchar(10),t.length) as length from syscolumns c
        inner join systypes t on c.xusertype=t.xusertype
        where c.[id]=object_id(@tbl) order by colorder
else
    declare flds cursor local for
        select convert(nvarchar(10),t.length) as length from tempdb..syscolumns c
        inner join tempdb..systypes t on c.xusertype=t.xusertype
        where c.[id]=object_id(@tbl) order by colorder

declare @fld sysname
declare @i int
declare @n int set @n=dbo.fn__str_count(@excludes,default)
declare @no bit

open flds
while (1=1) begin
    fetch next from flds into @fld
    if @@error != 0 or @@fetch_status != 0 BREAK

    set @no=0
    if @excludes<>'' begin
        set @i=1
        while (@i<=@n) begin
            if dbo.fn__at(@fld,@excludes,@seps)<>0 begin set @no=1 break end
            set @i=@i+1
        end -- while
    end -- if @excludes
    if @no=0 begin
        if charindex(' ',@fld)>0 set @fld=quotename(@fld)
        if @flds<>'' set @flds=@flds+@seps
        set @flds=@flds+@fld
    end -- @no
end -- while cursor

close flds
deallocate flds
return @flds
end -- function