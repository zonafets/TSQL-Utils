/*  leave this
    l:see LICENSE file
    g:utility
    v:100328\s.zaglio: adapted to fn__comment_types
    v:100204\s.zaglio: return comment of obj
*/
CREATE function [dbo].[fn__comment](@path sysname)
returns nvarchar(4000)
as
begin
declare
    @schema sysname,@prop sysname,
    @obj sysname,@obj_type sysname,
    @col sysname,@col_type sysname,
    @comment nvarchar(4000),@id int,
    @xtype nvarchar(2),@sch_type sysname

select @prop=prop,@schema=sch,@sch_type=sch_type,
       @obj_type=obj_type,@obj=obj,
       @col_type=sub_type,@col=sub
from dbo.fn__comment_types(@path)

select @comment=convert(nvarchar(4000),value)
from fn_listextendedproperty (
    @prop,
    @sch_type, @schema,
    @obj_type, @obj,
    @col_type, @col);

return @comment
end -- function