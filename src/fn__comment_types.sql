/*  leave this
    l:see LICENSE file
    g:utility
    v:100612\s.zaglio: managed unknown objs (retur nothing)
    v:100328\s.zaglio: support for fn__comment,sp__comment
    todo: using MS original methos is slow. Need to be rewritten
    t:
        select * from dbo.fn__comment_types('sp__comment')
        select * from dbo.fn__comment_types('sp__comment.@path')
        select * from dbo.fn__comment_types('fn__comment.@path')
*/
CREATE function [dbo].[fn__comment_types] (
    @path sysname=null
    )
returns @t table (
    prop sysname,
    sch sysname,sch_type sysname,
    obj sysname,obj_type sysname,
    sub sysname null,sub_type sysname null,
    xtype nvarchar(2),id int
    )
as
begin

declare
    @sch sysname,@sch_type sysname,
    @obj sysname,@obj_type sysname,
    @sub sysname,@sub_type sysname,
    @id int,@prop sysname,@xtype nvarchar(2)

if @path is null return

/*
Table 1. Extended property hierarchy for SQL Server 2000.
------------------------------------------------------------------------
Level 0                 Level 1                 Level 2
User                    Table                   Column, index, constraint, trigger
User                    View                    Column, INSTEAD OF trigger
User                    Schema-bound view       Column, index, INSTEAD OF trigger
User                    Procedure               Parameter
User                    Rule                    (none)
User                    Default                 (none)
User                    Function                Column, parameter, constraint
User                    Schema-bound function   Column, parameter, constraint
User-defined datatype   (none)                  (none)
*/

select @prop=N'MS_Description',
       @sch_type='Schema'  -- maybe in mssql2k must use 'user'

if charindex('.',@path)=0
    select
        @obj=parsename(@path,1)
else
    select
        @sch=parsename(@path,3),
        @obj=parsename(@path,2),
        @sub=parsename(@path,1)

if @sch is null select @sch=[name] from dbo.fn__schema_of(@obj)

select @id=object_id(@sch+'.'+@obj)
if @id is null return

select @xtype=xtype from sysobjects where id=@id

if @xtype in ('V') select  @obj_type='View',     @sub_type='Column'
if @xtype in ('U') select  @obj_type='Table',    @sub_type='Column'
if @xtype in ('P','TR') select  @obj_type='Procedure',@sub_type='Parameter'
if @xtype in ('FN','IF','TF','IT') select  @obj_type='Function',@sub_type='Parameter'
-- select distinct xtype from sysobjects

if charindex('.',@path)=0 select @sub_type=null

insert @t select @prop,
                 @sch,@sch_type,@obj,@obj_type,
                 @sub,@sub_type,@xtype,@id
return
end -- fn__comment_types