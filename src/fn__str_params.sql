/*  leave this
    l:see LICENSE file
    g:utility
    v:130909\s.zaglio: optimized using with
    v:111114\s.zaglio: optimized and added to grp util_tkns
    v:100718\s.zaglio: same as fn__str_table but reduce tokens
    t:
        select * from dbo.fn__str_params('a,b  ,c,
                                         d,  e  ,  f',',',default)
*/
CREATE function [dbo].[fn__str_params](
    @data nvarchar (4000),
    @sep nvarchar (32)='|',
    @reserved bit=null
    )
returns table
as
return
-- declare @data sysname,@sep sysname
-- select @data=' a b c ',@sep=' ';
with pieces(pos, start, [stop]) as (
  select 1, 1, charindex(@sep, @data)
  union all
  select
    pos + 1,
    [stop] + (datalength(@sep)/2),
    charindex(@sep, @data, [stop] + (datalength(@sep)/2))
  from pieces
  where [stop] > 0
)
select pos,
    token=ltrim(rtrim(replace(replace(replace(
            substring(@data, start,
                      case when [stop] > 0 then [stop]-start else 4000 end
                     ),
            cr,''),lf,''),tab,'')))
from pieces,fn__sym()
-- fn__str_table_fast