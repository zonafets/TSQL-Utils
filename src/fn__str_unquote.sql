/*  leave this
    l:%licence%
    g:utility
    v:120914\s.zaglio: a small bug if len(@str)=1
    v:100112\S.Zaglio: unquote with specification
    t:print dbo.fn__str_unquote('[test]','[]')
*/
CREATE function [dbo].[fn__str_unquote](
    @str nvarchar(4000),
    @quotes nvarchar(4)    -- single ', double " or couple ()
)
returns nvarchar(4000)
as
begin
if @str is null return null
declare @qo nvarchar(2)
declare @qc nvarchar(2)
declare @l int,@lr int,@ll int
if len(@str)<2 return @str
select @l=len(@quotes)
if @l=1 begin set @qo=@quotes set @qc=@qo end
if @l=2 begin set @qo=left(@quotes,1) set @qc=right(@quotes,1) end
select @lr=len(@qo),@ll=len(@qc),@l=len(@str)
if left(@str,1)=@qo and right(@str,1)=@qc begin
    select @str=substring(@str,@lr+1,@l-@lr-@ll)
    select @str=replace(@str,@qo+@qo,@qo) -- un-inject
    end
return @str
end -- [fn__str_unquote]