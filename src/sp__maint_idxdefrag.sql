/*  leave this
    l:see LICENSE file
    g:utility
    k:index,maintenance,rebuild,fragmentation
    v:110923\s.zaglio: refined
    r:091018.1000\s.zaglio:  defrag current db indexes
    t:sp__maint_idxdefrag run
*/
CREATE proc sp__maint_idxdefrag
    @opt sysname=null
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0,@opt=dbo.fn__str_quote(isnull(@opt,''),'|')

-- declare variables
set nocount on
declare @tablename varchar (128)
declare @execstr   varchar (255)
declare @objectid  int
declare @indexid   int
declare @frag      decimal
declare @maxfrag   decimal
declare @run       bit

select @run=charindex('|run|',@opt)
if @run=0 exec sp__printf '-- use @opt=''run'' to execute it isntead of show'

-- decide on the maximum fragmentation to allow
select @maxfrag = 8

-- declare cursor
declare tables cursor for
   select '['+table_schema+'].['+table_name+']' as table_name
   from information_schema.tables
   where table_type = 'base table' and table_name not like 't%'

-- create the table
create table #fraglist (
   objectname char (255),
   objectid int null,
   indexname char (255),
   indexid int null,
   lvl int null,
   countpages int null,
   countrows int null,
   minrecsize int null,
   maxrecsize int null,
   avgrecsize int null,
   forreccount int null,
   extents int null,
   extentswitches int null,
   avgfreebytes int null,
   avgpagedensity int null,
   scandensity decimal,
   bestcount int null,
   actualcount int null,
   logicalfrag decimal,
   extentfrag decimal null)

-- open the cursor
open tables

-- loop through all the tables in the database
fetch next
   from tables
   into @tablename

while @@fetch_status = 0
begin
-- do the showcontig of all indexes of the table
   exec sp__printf 'get info of %s',@tablename
   insert into #fraglist
   exec ('dbcc showcontig (''' + @tablename + ''')
      with fast, tableresults, all_indexes, no_infomsgs')
   fetch next
      from tables
      into @tablename
end

-- close and deallocate the cursor
close tables
deallocate tables

if @run=0
    begin
    select  case when logicalfrag >= @maxfrag
            then '*' else '' end [!],objectname,indexname,logicalfrag,countrows
    from #fraglist
    where indexproperty (objectid, indexname, 'indexdepth') > 0
    order by [!] desc,logicalfrag desc
    select @ret=-1
    end
else
    begin
    -- declare cursor for list of indexes to be defragged
    declare indexes cursor for
       select objectname, objectid, indexid, logicalfrag
       from #fraglist
       where logicalfrag >= @maxfrag
          and indexproperty (objectid, indexname, 'indexdepth') > 0

    -- open the cursor
    open indexes

    -- loop through the indexes
    fetch next
       from indexes
       into @tablename, @objectid, @indexid, @frag

    while @@fetch_status = 0
    begin
       print 'executing dbcc indexdefrag (0, ' + rtrim(@tablename) + ',
          ' + rtrim(@indexid) + ') - fragmentation currently '
           + rtrim(convert(varchar(15),@frag)) + '%'
       select @execstr = 'dbcc indexdefrag (0, ' + rtrim(@objectid) + ',
           ' + rtrim(@indexid) + ')'
       exec (@execstr)

       fetch next
          from indexes
          into @tablename, @objectid, @indexid, @frag
    end

    -- close and deallocate the cursor
    close indexes
    deallocate indexes
    end

-- delete the temporary table
drop table #fraglist
return @ret
end -- sp__maint_idxdefrag