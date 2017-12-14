/*  leave this
    l:see LICENSE file
    g:utility
    v:100919\s.zaglio: quote numeric fields names
    v:100405\s.zaglio: re???added reserved keywords
    v:091128\s.zaglio: added use of fn__token_sql
    v:090916\S.Zaglio: added some keywords
    v:090627\S.Zaglio: added keywords as,where
    v:090304\S.Zaglio: add bounds [ & ] if have space or chars or is a keyword
    t:print dbo.fn__flds_quotename('test,te/st,test test,test_test,group,set,[already_quoted]',',')
*/
CREATE  function [dbo].[fn__flds_quotename](
    @flds nvarchar(4000),
    @seps nvarchar(32)=','
)
returns nvarchar(4000)
as
begin
declare @r nvarchar(4000),@name sysname,@i int,@n int
declare @t table (token sysname)
insert @t select token from dbo.fn__str_table(@flds,@seps)
update @t set token=quotename(token)
where left(token,1)!='['
and (patindex('%[^0-9A-Za-z,_]%', token)>0
     or dbo.fn__token_sql(token)=1
     or isnumeric(token)=1
    )
select @r=coalesce(@r+@seps,'')+token from @t
/*
set @r='' set @i=1 set @n=dbo.fn__str_count(@flds,@seps)
while (@i<=@n)
    begin
    set @name=dbo.fn__str_at(@flds,@seps,@i)
    if left(@name,1)<>'[' and right(@name,1)<>']'
        begin
        if charindex(' ',@name)>0 or dbo.fn__token_sql(@name)=1
            set @name=quotename(@name)
        end
    if @i>1 set @r=@r+@seps
    set @r=@r+@name
    set @i=@i+1
    end -- while
*/
return @r
end -- fn__flds_quotename