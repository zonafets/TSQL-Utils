/*  leave this
    l:see LICENSE file
    g:utility
    v:120724\s.zaglio: modified to complete left or right quote
    v:111205\s.zaglio: specialized injection only for single&double quote
    v:090529\S.Zaglio: revision
    v:080505\S.Zaglio: close string into quotes if not just done and inject
    t: select dbo.fn__str_quote('test',''''),dbo.fn__str_quote('test''1','''')
    t: select dbo.fn__str_quote('''test''',''''),dbo.fn__str_quote('''test''''1','''')
    t: select dbo.fn__str_quote('test','<>')    --> <test>
    t: select dbo.fn__str_quote(null,'<>') --> null
    t: select dbo.fn__str_quote('test|','|'),dbo.fn__str_quote('|test','|')
*/
CREATE function [dbo].[fn__str_quote](
    @str nvarchar(4000),
    @quotes nvarchar(4)    -- single ', double " or couple ()
)
returns nvarchar(4000)
as
begin
if @str is null return null
declare @qo nvarchar(2),@qoe bit    -- Quote Open Exists
declare @qc nvarchar(2),@qce bit    -- Quote Close Exists
if len(@quotes)=1 select @qo=@quotes,@qc=@qo
if len(@quotes)=2 select @qo=left(@quotes,1),@qc=right(@quotes,1)
if left(@str,1) =@qo select @qoe=1 else select @qoe=0
if right(@str,1)=@qc select @qce=1 else select @qce=0
if @qo=@qc and @qo in ('''','"')
    select @str=replace(@str,@qo,@qo+@qo) -- inject

if @qoe=0 select @str=@qo+@str
if @qce=0 select @str=@str+@qc

return @str
end -- [fn__str_quote]