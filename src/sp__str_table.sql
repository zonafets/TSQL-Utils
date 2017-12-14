/*  leave this
    l:see LICENSE file
    g:utility
    v:100508\s.zaglio: adde hwhere parameters with @p1,@p2,...
    v:100113\s.zaglio: added test comment
    v:091027\s.zaglio: name that start with #,@ are not closed into % and managed (n)text flds
    v:091018\s.zaglio: verticalize a row of a table into a #vars for str_replace
    t:
        create table #vars (id nvarchar(16),value sql_variant)
        create table #local(id int,name sysname)
        insert #local select 1,'one'
        insert #local select 2,'two'
        exec sp__str_table '#vars','#local','id=%d',@p1=2-- ,@dbg=1
        declare @sql sysname select @sql='id:%id%; name:%name%'
        exec sp__str_replace @sql out,@tbl=1
        print @sql
        drop table #local drop table #vars
*/
CREATE proc [dbo].[sp__str_table]
    @vtbl sysname=null,
    @htbl sysname=null,
    @hwhere sysname=null,
    @excludes sysname=null,
    @p1 sql_variant=null,
    @p2 sql_variant=null,
    @p3 sql_variant=null,
    @p4 sql_variant=null,
    @dbg bit=0
as
begin
set nocount on
declare
    @flds nvarchar(4000),@types nvarchar(4000),
    @declares nvarchar(4000),@select nvarchar(4000),
    @inserts nvarchar(4000),@crlf nchar(2),@sql nvarchar(4000),
    @i int,@n int,@fld sysname,@type sysname,@sfld sysname

if @vtbl is null or @htbl is null goto help

select
    @crlf=char(13)+char(10),
    @flds =dbo.fn__flds_of(@htbl,'|',null),
    @types=dbo.fn__flds_type_of(@htbl,'|',null),
    @select='',@declares='',@inserts='',
    @i=1,@n=dbo.fn__str_count(@flds,'|')

while (@i<=@n)
    begin
    select @fld =dbo.fn__str_at(@flds ,'|',@i)
    select @sfld=quotename(@fld)
    select @type=dbo.fn__str_at(@types,'|',@i)
    if @type in ('text','ntext') select @sfld='convert(nvarchar(4000),'+@sfld+') '
    if @type in ('text','ntext') select @type='nvarchar(4000)'
    if dbo.fn__at(@fld,@excludes,'|')=0
        begin
        select @declares=@declares+'@'+@fld+' '+@type+case when @i<@n then ',' else '' end+@crlf
        select @select=@select+'@'+@fld+'='+@sfld+case when @i<@n then ',' else '' end
        select @inserts=@inserts+'insert '+@vtbl+' select '''
            +case when left(@fld,1) in ('#','@') then @fld else '%'+@fld+'%' end
            +''',@'+@fld+@crlf
        end
    select @i=@i+1
    end

select @sql='truncate table '+@vtbl+@crlf
           +'declare'+@crlf+@declares
           +'select top 1 '+@select+' from '+@htbl+@crlf
           +coalesce('where '
            +dbo.fn__printf(@hwhere,@p1,@p2,@p3,@p4,null,null,null,null,null,null)
            ,'')
           +@crlf
           +@inserts
if @dbg=1 exec sp__printf @sql
exec(@sql)
goto ret
help:
select @sql='Verticalize a row of a table into a table to pass to sp__str_replace
Sample:
        create table #vars(id nvarchar(16), value sql_variant)
        create table #objs(id int,name sysname,age int,b bit, e nvarchar(10), t ntext)
        insert #objs select 1,''first'',10,1,''v10'',''text1''
        insert #objs select 2,''second'',20,2,''v20'',''text2''
        exec sp__str_table ''#vars'',''#objs'',''id=%d'',@p1=1
        select * from #vars
        drop table #vars
        drop table #objs'
exec sp__usage 'sp__str_table',@sql
ret:
end -- proc