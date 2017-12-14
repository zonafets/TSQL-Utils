/*  leave this
    l:%licence%
    g:utility
    v:120823\s.zaglio: convert datetime to unix format
    t:select fn__unix_timestamp(getdate())
*/
CREATE function fn__unix_timestamp (
    @dt datetime
)
returns integer
as
begin
    declare @ret int
    select @ret = datediff(s,{d '1970-01-01'}, @dt)
    return @ret
end -- fn__unix_timestamp