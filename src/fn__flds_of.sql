/*  leave this
    l:see LICENSE file
    g:utility
    v:130730\s.zaglio: adapted to mssql2k5 and replaced prev ordby with @tcol pkey
    v:130529\l.mazzanti: trovato un caso in cui si perdeva l'orderby del colorder
    v:121011\s.zaglio: added like on exclusions instead of =
    v:120413,100710\s.zaglio: add.%id% to exclude identity;order by number for table functions
    v:100228\s.zaglio: a remake more simple & faster (as fn__flds_convert)
    v:090915\S.Zaglio: added #temp table management
    v:081224,081121\S.Zaglio: manage quoted name;now @excludes need same @seps
    v:081110,081012\S.Zaglio: expanded @seps to nvarchar(32);expanded @seps to nvarchar(8)
    v:081009\S.Zaglio: added quoting for fields with spaces inside
    v:080721\S.Zaglio: return list of flields separated by comma with optional exlusions of flds separated by |
    t:sp__flds_of_test
*/
CREATE function [dbo].[fn__flds_of](
    @tbl sysname,
    @seps nvarchar(32)=',',
    @excludes sysname=''
    )
returns nvarchar(4000)
as
begin

declare
    @cols nvarchar(4000),@db sysname,@obj sysname,@i int,
    @sql nvarchar(4000),@oid int,@tmp bit,@ex_ident bit,
    @nexcludes int

declare @ex table([name] sysname primary key)
declare @tcols table([name] sysname, colorder int primary key)

if @seps is null select @seps=','
-- print parsename('[db..obj]',1)
-- print parsename('db..[obj]',1)

select
    @db=parsename(@tbl,3),
    @obj=parsename(@tbl,1),
    @tmp=case when left(@obj,1)='#' then 1 else 0 end,
    @ex_ident=charindex('%id%',@excludes)

if (not @db is null and @db!=db_name()) return null

if @tmp=1 select @tbl='tempdb..'+@obj
select @oid=object_id(@tbl)
if @oid is null return null

/*  this fn is so slower that is better
    delete excludes to the end instead of while */

if not @excludes is null
    begin
    insert @ex select token
    from dbo.fn__str_table(@excludes,@seps)
    where token!='%id%'
    select @nexcludes=@@rowcount
    end

-- collect cols
if @ex_ident=1
    begin
    if @tmp=1
        insert @tcols
        select c.name, c.column_id
        -- select *
        from tempdb.sys.columns c
        where c.[object_id]=@oid
        and c.is_identity=0
        order by column_id
    else
        insert @tcols
        select c.name, c.column_id
        from sys.columns c
        where c.[object_id]=@oid
        and is_identity=0
        order by column_id
    end
else    -- with identity
    begin
    if @tmp=1
        insert @tcols
        select c.name, c.column_id
        from tempdb.sys.columns c
        where c.[object_id]=@oid
        order by c.column_id
    else
        insert @tcols
        select c.name, c.column_id
        from sys.columns c
        where c.[object_id]=@oid
        order by column_id
    end

if @nexcludes>0
    delete a from @tcols a join @ex b on a.[name] like b.[name]

select @cols=coalesce(@cols+@seps,'')+c.name from @tcols c

return @cols
end -- fn__flds_of