/*  leave this
    l:see LICENSE file
    g:utility
    v:100612\s.zaglio: revision
    r:100404\s.zaglio: returns tsql name splitted
    t:select * from fn__parsename('svr.db..obj',0,0)
    t:select * from fn__parsename('[db]..obj',0,0)
    t:select * from fn__parsename('*obj*',0,1)
    t:select * from fn__parsename('*obj*',1,1)
*/
CREATE function [dbo].[fn__parsename](@obj sysname,@quoted bit=0,@defaults bit=0)
returns @t table(svr sysname null,db sysname null,sch sysname null,obj sysname null)
--begin
as
begin
if @obj is null return
declare @svr sysname,@db sysname,@sch sysname,@tbl sysname
select
    @svr=parsename(@obj,4),
    @db=parsename(@obj,3),
    @sch=parsename(@obj,2),
    @tbl=parsename(@obj,1)

if @defaults=1
    select
        @svr=coalesce(@svr,dbo.fn__servername(Null)),
        @db=coalesce(@db,db_name()),
        @sch=coalesce(@sch,'dbo')

if @quoted=1
    select
        @svr=quotename(@svr),
        @db=quotename(@db),
        @sch=quotename(@sch),
        @tbl=quotename(@tbl)

insert @t select @svr,@db,@sch,@tbl
return
end -- fn__parsename