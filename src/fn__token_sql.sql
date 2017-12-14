/*  leave this
    l:see LICENSE file
    g:utility
    v:111128\s.zaglio: added key
    v:101230\s.zaglio: added option
    v:091128\s.zaglio: commonly used by fn__flds_quotename and sp__token
*/
CREATE function fn__token_sql(@name sysname)
returns bit
as
begin
if @name is null return null
if @name in ('delete','id','select','insert','update','name','group','backup','default',
             'set','table','view','as','where','from','to','go','by','having','create',
             'nocount','on','begin','end','if','else','exec','declare','return',
             'bit','nvarchar','varchar','int','bigint','char','nchar','sysname','datetime',
             'top','proc','function','goto','drop','not','is','null','option','key'
            )
    return 1
return 0
end -- fn__token_sql