/*  leave this
    l:see LICENSE file
    g:utility
    v:090707.1055\s.zaglio: revision
    v:090630.1055\s.zaglio: utility per chiamare velocemente le FN_...
    t:sp__fn 'address'
*/
CREATE proc [dbo].[sp__fn] @name sysname=null,
    @v1 sql_variant=null,@v2 sql_variant=null,@v3 sql_variant=null
as
begin
set nocount on
declare @sql nvarchar(4000),@ename sysname,@msg nvarchar(4000)
declare @p table (id int identity, param sysname)
declare @i int,@n int,@params nvarchar(4000),@param sysname
if @name is null goto help
-- select xtype from sysobjects group by xtype
select @ename=name from sysobjects where name like @name and xtype in ('TF','IF','FN')
if @ename is null select @ename=name from sysobjects where name like '%'+@name+'%' and xtype in ('TF','IF','FN')
if @ename is null goto err_name

exec sp__usage @ename
insert into @p(param) select name from syscolumns where id=object_id(@ename) and left(name,1)='@' order by colid
select @params='',@i=min(id),@n=max(id) from @p
while (@i<=@n) select  @params=@params+'null'+case when @i<@n then ',' else '' end,@i=@i+1
set @sql='select * from '+@ename+'('+@params+')'
select lower(@sql) as cmd_line
exec(@sql)
goto ret

err_name:   select @msg='function name not found'   goto ret

help:
exec sp__printf 'specificare nome o contenuto funzione'
exec sp__printf 'nb:procedura da ultimare'
ret:
if not @msg is null exec sp__printf @msg
end -- proc