/*    leave this
    l:see LICENSE file
    g:utility
    v:100501\s.zaglio: added @extra (for each columns) to calc nulls
    v:100228\s.zaglio: a correction on description (in bytes)
    v:091018\s.zaglio: return row size (in bytes) of fields of a table
    t:
        print dbo.fn__flds_row_size('sysobjects',',','name,id,xtype',default)
        select * from syscolumns where id=object_id('sysobjects') order by colid
    t:
        create table #test(a varchar(4),b nvarchar(4), c bit, d int) -- 4+8+?+4=16+?
        print dbo.fn__flds_row_size('#test',',','a,b,c,d',default)
        print dbo.fn__flds_row_size('#test',',','a,b,c,d',1)
        drop table #test
    t:sp__find 'fn__flds_row_size'
*/
CREATE function [dbo].[fn__flds_row_size](@tbl sysname,@sep nvarchar(32),@flds nvarchar(4000),@extra real=0)
returns int
as
begin
declare @r int
if @sep is null select @sep=','
select @flds=@sep+@flds+@sep
if left(@tbl,1)='#'
    begin
    select @tbl='tempdb..'+@tbl
    select @r=sum(length)+@extra*count(*) from tempdb..syscolumns
    where id=object_id(@tbl) and charindex(@sep+[name]+@sep,@flds)>0
    end
else
    select @r=sum(length)+@extra*count(*) from syscolumns
    where id=object_id(@tbl) and charindex(@sep+[name]+@sep,@flds)>0
return @r
end -- func