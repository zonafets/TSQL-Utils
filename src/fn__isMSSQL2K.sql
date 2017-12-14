/*  leave this
    l:see LICENSE file
    g:utility
    v:110629\s.zaglio: optimized
    v:100919\s.zaglio: more compatible mssql2k
    v:100204\s.zaglio: return 1 if this is mssql 2000
    t:select @@version,dbo.fn__isMSSQL2K(),substring(@@version,23,4)
    t:
        declare @d datetime,@i int,@r nvarchar(4)
        select @i=10000
        exec sp__elapsed @d out,'init'
        while @i>0 select @r=substring(@@version,8,4),@i=@i-1  -- faster
        exec sp__elapsed @d out,'after @@ver'
        select @i=10000
        while @i>0 select @r=substring(cast(serverproperty('productversion') as sysname),1,1),@i=@i-1
        exec sp__elapsed @d out,'after prop'
*/
CREATE function fn__isMSSQL2K()
returns bit
as
begin
if substring(@@version,23,4) in ('2000','000 ') return 1
-- Microsoft SQL Server  2000 - 8.00.2039 ...
/*  'Microsoft SQL Server 2000',
    'Microsoft SQL Server  200'
    )
    return 1
*/
return 0
end -- fn__isMSSQL2K()