/*  leave this for other app
    l:see LICENSE file
    g:obj,utility
    v:130217\s.zaglio: generic enumerators
*/
CREATE view enums
as
select
    -- fn__str_between
  null as [btw.close_left],     -- search @from and then the next @to
     1 as [btw.close_right],    -- search @to and then the previous @from

    -- end
     -1 as [last]