/*  leave this
    l:see LICENSE file
    g:utility
    v:080430\S.Zaglio: @action=1->left part of string from @from
    t: print dbo.fn__subst(default,'CREATE_SYNC_STRUCTURE:[gamon.seldom.it].ramsesbg',':',default)
*/
CREATE    function fn__subst(@action tinyint=1,@str nvarchar(4000),@from nvarchar(8),@dummy nvarchar(4000)=null)
returns nvarchar(4000)
as
begin
return substring(@str,isnull(charindex(@from,@str)+len(@from),len(@str)),len(@str))
end