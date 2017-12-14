/*  leave this
    l:see LICENSE file
    g:utility
    v:130902,130830\s.zaglio: a bug when len(@what)>1;optimized from 2x to 4x
    v:111223\s.zaglio: upgraded to int indexes
    v:111111\s.zaglio: managed search of ' ' backwards
    v:091217\s.zaglio: a bug on right 1st char
    v:091015\s.zaglio: as charindex but can search from end to begin
    t:print dbo.fn__charindex('\','c:\test\test2',0) -- null
    t:print dbo.fn__charindex('\','c:\test\test2',-1) -- 8
    t:print dbo.fn__charindex('\','c:\test\test2',-9) -- 3
    t:print dbo.fn__charindex('\',null,-1) -- null
    t:print charindex('\',null) -- null
    t:print dbo.fn__charindex(']','end]',-1) -- 4
    t:print dbo.fn__charindex(' ','left rght',-1) -- 5
    t:print dbo.fn__charindex('\','nothing do find',-1) -- 0
    t:print dbo.fn__charindex(' from ','select * from #objs ',-1) -- 9
*/
CREATE function fn__charindex(
    @what nvarchar(4000),
    @where nvarchar(4000),
    @from int
    )
returns int
as
begin
declare @i int,@n int,@m int
if @from>=0 return null -- prevent use of this instead of charindex
select @from=-@from,@n=len('.'+@where+'.')-2,@m=len('.'+@what+'.')-2
select @i=charindex(reverse(@what),reverse(@where),@from)
if @i>0 return @n-@i+1-@m+1
return 0
end -- end fn__charindex