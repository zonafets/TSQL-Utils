/*  leave this
    l:see LICENSE file
    g:utility
    v:130808\s.zaglio: faster but for mssql2k5 or greater
    v:100501\s.zaglio: converted into @table
    v:090614\s.zaglio: return a numerator
    t:select row from fn__range(20,60,1)
    t:select * from fn__range(-20,-10,1)
    t:select row from fn__range(500,50000,1000)
    t:select * from fn__range(500,5000000,1000)
*/
CREATE function [dbo].[fn__range](@from int, @to int,@step int)
returns table
as
return
with a as (select 1 as n union all select 1) -- 2
     ,b as (select 1 as n from a ,a a1)       -- 4
     ,c as (select 1 as n from b ,b b1)       -- 16
     ,d as (select 1 as n from c ,c c1)       -- 256
     ,e as (select 1 as n from d ,d d1)       -- 65,536
     ,f as (select 1 as n from e ,e e1)       -- 4,294,967,296=17+trillion chrs
     ,factored as (select row_number() over (order by n) rn from f)
select (rn-1)*@step+@from as row
from factored
where rn<=(@to/@step-@from/@step+1)
and ((rn-1)*@step+@from)<=@to
-- fn__range