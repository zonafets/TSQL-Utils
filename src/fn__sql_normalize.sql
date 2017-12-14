/*  leave this
    l:see LICENSE file
    g:utility
    k:normalize, simplify
    v:120913\s.zaglio: a bug in exp semplification
    v:120903\s.zaglio: added exp option
    v:120820\s.zaglio: used () around top %
    v:120809\s.zaglio: remove extra from code and put on single line
    d:120809\s.zaglio: fn__sql_simplify
    t:print dbo.fn__sql_normalize('  test  '+char(13)+'  ',default)
    t:print dbo.fn__sql_normalize('  test  -- comment'+char(13)+'  ',default)
    t:print dbo.fn__sql_normalize('  dt   desc','ord')
    t:select dbo.fn__sql_normalize(' 20%','top')
    t:select dbo.fn__sql_normalize(' 20','top')
    t:
        select dbo.fn__sql_normalize(' t1.f1="a",
                                       t2.f2=t3.f3 ',
                                     'exp')
    t:
        select dbo.fn__sql_normalize(' t1.f1="a" and
                                       t2.f2=t3.f3 ',
                                     'exp')
*/
CREATE function fn__sql_normalize (
    @sql nvarchar(max),
    @opt sysname
)
returns nvarchar(max)
as
begin
declare
    @crlf   nvarchar(2),
    @cr     nvarchar(1),
    @lf     nvarchar(1),
    @tab    nvarchar(1),
    @sel    bit,                        -- sel option specified
    @ord    bit,                        -- ord option
    @top    bit,
    @exp    bit

if @sql is null return null
if charindex('--',@sql)>0 return null

select
    @cr=cr,@lf=lf,@tab=tab,@crlf=crlf,
    @opt=case
         when not @opt is null
         then dbo.fn__str_quote(isnull(@opt,''),'|')
         else null
         end
from dbo.fn__sym()

while charindex(@cr,@sql)>0 select @sql=replace(@sql,@cr,' ')
while charindex(@lf,@sql)>0 select @sql=replace(@sql,@lf,' ')
while charindex(@tab,@sql)>0 select @sql=replace(@sql,@tab,'')
while charindex('  ',@sql)>0 select @sql=replace(@sql,'  ',' ')
select @sql=ltrim(rtrim(@sql))

if @sql='' return null

if not @opt is null
    begin
    select
        @sel=charindex('|sel|',@opt),
        @ord=charindex('|ord|',@opt),
        @top=charindex('|top|',@opt),
        @exp=charindex('|exp|',@opt)

    if @sel=1   -- expand table name to select
        begin
        if left(@sql,7)!='select '
            select @sql='select top 100 percent * from '+dbo.fn__str_quote(@sql,'[]')
        end

    if @ord=1   -- expand to oby expression
        begin
        if left(@sql,9)!='order by '
            select @sql='order by '+@sql
        end

    if @top=1   -- convert n or n% to top ...
        begin
        if (right(@sql,1)='%'  and isnumeric(left(@sql,len(@sql)-1))=0)
        or (right(@sql,1)!='%' and isnumeric(@sql)=0)
            select @sql='#wrong number or percent'
        else
            begin
            if right(@sql,1)='%'
                select @sql='top ('+cast(left(@sql,len(@sql)-1) as sysname)
                           +') percent'
            else
                select @sql='top ('+cast(left(@sql,len(@sql)) as sysname)+')'
            end
        end -- top

    if @exp=1   -- expression for join: replace " with '' and strip spaces
        begin
        select @sql=replace(@sql,'"','''')
        -- todo: for {sym}{spc} and {spc}{sym}
        end
    end -- options

return @sql
end -- fn__sql_normalize