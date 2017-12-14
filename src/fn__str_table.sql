/*  leave this
    l:%licence%
    g:utility
    v:130415\s.zaglio: 4000->max
    v:120906\s.zaglio: replaced version with "with" because limited to 100 recursions
    v:111114\s.zaglio: added to grp util_tkns and commented inside a 20% faster method mssql2k5>
    v:101201\s.zaglio: added pkey index on pos
    v:100916\s.zaglio: added cross apply example
    v:100314\s.zaglio: managed null @data
    v:090812\s.zaglio: a bug with double sep
    v:081130\s.zaglio: verticalizee a splitted variable
    t:select * from dbo.fn__str_table('a|b|c','|')
    t:select * from dbo.fn__str_table('a\n\nc','\n') <-- is correct have only one line empty
    t:select * from dbo.fn__str_table(null,';')
    t:select * from dbo.fn__str_table('a b c d','')
    t:
        select l,s.* from (
            select '1|a|aa' as l union
            select '2|b|bb' as l union
            select '3|c|cc' as l union
            select '4|d|dd' as l
        ) as data
        cross apply dbo.fn__str_table(data.l,'|') s
*/
create function [dbo].[fn__str_table](
  @data nvarchar (max),
  @sep nvarchar (32)='|'
  )
returns
    @t table (pos int identity(1,1) primary key, token nvarchar(4000))
begin
declare @st nvarchar(max)
declare @pos int,@opos int
declare @step int

if @data is null or @sep is null return

--initialize
select @st = ''
select @step = len('.'+@sep+'.')-2
if @sep = '' and @step=0 select @sep = ' ',@step=1

select @data = @data + @sep , @opos=1
select @pos = charindex(@sep, @data)

while (@pos <> 0)
    begin
    set @st = substring(@data, @opos, @pos - @opos)
    insert into @t (token) values (@st)
    set @opos=@pos+@step
    set @pos = charindex(@sep, @data,@opos)
    end

return
end -- fn__str_table