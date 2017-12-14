/*  leave this
    l:see LICENSE file
    g:utility
    v:090811\s.zaglio: parse next tokens to extract a table path
    t:
        declare @path sysname,@s sysname,@i int

        select @s='create proc svr.db.[schema].tbl (@param1 int)',@i=13
        exec sp__parse_name @s,@path out,@i out
        exec sp__printf 'path=%s, next:%d',@path,@i

        select @s='create proc db.[schema].tbl (@param1 int)',@i=13
        exec sp__parse_name @s,@path out,@i out
        exec sp__printf 'path=%s, next:%d',@path,@i

        select @s='create proc [schema].tbl (@param1 int)',@i=13
        exec sp__parse_name @s,@path out,@i out
        exec sp__printf 'path=%s, next:%d',@path,@i

        select @s='create proc tbl (@param1 int)',@i=13
        exec sp__parse_name @s,@path out,@i out
        exec sp__printf 'path=%s, next:%d',@path,@i
*/
create proc [dbo].[sp__token_name]
    @line nvarchar(4000)=null out,  -- source code
    @path sysname       =null out,  -- output or found and normalized [server].[db].[schema].[name]
    @start int          =null out,  -- set/return next position after name
    @at int             =null out,
    @dbg  bit=0
as
begin
set nocount on
declare
    @token sysname,@tl sysname,@i int,@len int,
    @svr sysname,@db sysname,@schema sysname,@name sysname

select @path=null,@token=null,@tl='.',@i=@start,@len=len(@line)
exec sp__token @line,@path out,@i out,@at out
while @i<=@len and @tl='.'
    begin
    select @token=null
    exec sp__token @line,@token out,@i out,@tl=@tl out
    if @tl='.' select @path=@path+@tl+@token,@start=@i
    end --
select
    @svr=   coalesce(dbo.fn__sql_quotename(parsename(@path,4))+'.',''),
    @db=    coalesce(dbo.fn__sql_quotename(parsename(@path,3))+'.',''),
    @schema=coalesce(dbo.fn__sql_quotename(parsename(@path,2))+'.',''),
    @name=  coalesce(dbo.fn__sql_quotename(parsename(@path,1)),''),
    @path=@svr+@db+@schema+@name
end -- proc