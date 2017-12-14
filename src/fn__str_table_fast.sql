/*  leave this
    l:%licence%
    g:utility
    a:130909\s.zaglio: fn__str_split
    v:130909\s.zaglio: unified fn__str_split and fn__str_table_fast
    v:120909\s.zaglio: faster version of fn__str_table for few lines
    t:select * from dbo.fn__str_split('a|b|c','|')
    t:select * from dbo.fn__str_split('a\n\nc','\n') <-- is correct have only one line empty
    t:select * from dbo.fn__str_split(null,';')
    t:select * from dbo.fn__str_split('a;b;c',null) -- a;b;c
    t:select * from dbo.fn__str_split('one two tree four  test','')
    t:select * from dbo.fn__str_split('one, two, tree,',',')
    t:
        select l,s.* from (
            select '1|a|aa' as l union
            select '2|b|bb' as l union
            select '3|c|cc' as l union
            select '4|d|dd' as l
        ) as data
        cross apply dbo.fn__str_table_fast(data.l,'|') s
    t:select * from fn__Str_table('a b c','')
    t:select * from fn__Str_table_fast('a b c','')
*/
CREATE function [dbo].[fn__str_table_fast](
  @data nvarchar (4000),
  @sep nvarchar (32)='|'
  )
returns table
as
return
-- declare @data sysname,@sep sysname
-- select @data=' a b c ',@sep=' ';
with pieces(pos, start, [stop]) as (
  select
    1, 1,
    charindex(case @sep when '' then ' ' else @sep end, @data)
  union all
  select
    pos + 1, [stop] + (datalength(sep)/2),
    charindex(sep, @data, [stop] + (datalength(sep)/2))
  from pieces,
       (select case @sep when '' then ' ' else @sep end sep) sep
  where [stop] > 0
)
select pos,
  substring(@data, start,
            case when [stop] > 0 then [stop]-start else 4000 end
            ) as token
  -- ,len(sep) ns
from pieces
-- fn__str_table_fast