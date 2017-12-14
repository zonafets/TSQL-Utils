/*  leave this
    l:see LICENSE file
    g:utility
    v:090430\s.zaglio
*/
CREATE function fn__t9_cmp(@t9_src int, @len tinyint, @t9_key int)
returns bit
as
begin
if convert(int,left(convert(varchar(12),@t9_key),@len))=@t9_src return 1
return 0
end