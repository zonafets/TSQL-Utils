/*  leave this
    l:see LICENSE file
    g:utility
    v:121226\s.zaglio: remake
    c:http://www.sqlperformance.com/2012/07/t-sql-queries/split-strings
    v:121004\s.zaglio: remake using patindex and removed a bug
    v:120517\s.zaglio: removed from core group
    v:110630\s.zaglio: added to core group
    v:100418\s.zaglio: a bug near out of indx
    v:100221\S.Zaglio: return piece of string separated by one of char in @sym
    t:
        print isnull(dbo.fn__str_parse('drive:\dir\subdir\file.ext','\.',0),'?') -- ?
        print dbo.fn__str_parse('drive:\dir\subdir\file.ext','\.',1) -- drive:
        print dbo.fn__str_parse('drive:\dir\subdir\file.ext','\.',2) -- dir
        print dbo.fn__str_parse('drive:\dir\subdir\file.ext','\.',3) -- subdir
        print dbo.fn__str_parse('drive:\dir\subdir\file.ext','\.',4) -- file
        print dbo.fn__str_parse('drive:\dir\subdir\file.ext','\.',5) -- ext
        print isnull(dbo.fn__str_parse('drive:\dir\subdir\file.ext','\.',6),'?') -- ?
        select dbo.fn__str_parse('a;b;',';,',1),dbo.fn__str_parse('a;b;',';,',2) -- a,b
        select dbo.fn__str_parse('a;b;',';,',3),dbo.fn__str_parse('a;b;',';,',4) -- '',null
*/
CREATE function [dbo].[fn__str_parse](
    @tokens nvarchar(4000),
    @sym nvarchar(32),
    @pos int
    )
returns nvarchar(4000)
as
begin
declare @token nvarchar(4000)
;with
    e1(n)        as (select 1 union all select 1 union all select 1 union all select 1
                     union all select 1 union all select 1 union all select 1
                     union all select 1 union all select 1 union all select 1),
    e2(n)        as (select 1 from e1 a, e1 b),
    e4(n)        as (select 1 from e2 a, e2 b),
    e42(n)       as (select 1 from e4 a, e2 b),
    ctetally(n)  as (select 0 union all select top (datalength(isnull(@tokens,1)))
                     row_number() over (order by (select null)) from e42),
    ctestart(n1) as (select t.n+1 from ctetally t
                     where (substring(@tokens,t.n,1) like '['+@sym+']' or t.n = 0)),
limits(n1,n2) as (
    select
        s.n1,
        isnull((select top 1 n1 from ctestart e where e.n1>s.n1 order by 1),len(@tokens)+2) n2
    from ctestart s
    ),
tokens(pos,token) as (
    select
        pos=row_number() over (order by (select null)),
        token=substring(@tokens,n1,n2-n1-1)
    from limits
    )
select @token=token
from tokens
where pos=@pos
return @token
end -- [fn__str_parse]