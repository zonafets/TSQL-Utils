/*  leave this
    v:090606\S.Zaglio: return object definition (int,varchar,etc. if column; V,C,U,etc. if not)
    g:utility
    t:print dbo.fn__object_type('sysobjects')
    t:print dbo.fn__object_type('sysobjects.name')
    t:print dbo.fn__object_type('test.txt')
*/
CREATE function [dbo].[fn__object_type](@name sysname)
returns sysname
as
begin
declare @obj  sysname
declare @col  sysname
declare @type sysname

select @obj=dbo.fn__str_at(@name,'.',1),
       @col=dbo.fn__str_at(@name,'.',2)

if @col is null select top 1 @type=xtype from sysobjects where id=object_id(@name)
else select top 1 @type=t.name from syscolumns c inner join systypes t on c.xusertype=t.xusertype where c.id=object_id(@obj) and c.name=@col

return @type
end -- function