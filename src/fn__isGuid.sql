/*  leave this
    l:see LICENSE file
    g:utility
    v:090807\S.Zaglio: added remove of ',",{,}
    v:090604\S.Zaglio: test a guid
    c:originally from: http://jesschadwick.blogspot.com/2007/11/safe-handling-of-uniqueidentifier-in.html
    t: print dbo.fn__isguid(convert(sysname,newid()))
    t: print dbo.fn__isguid(replace(convert(sysname,newid()),'-','_'))
    t: print convert(uniqueidentifier,convert(sysname,newid()))
*/
CREATE function [dbo].[fn__isGuid](@input nvarchar(48))
returns bit
as
begin
declare @isvalidguid bit; set @isvalidguid = 0;
select @input=replace(@input, '-', '')
select @input=replace(@input, '''', '')
select @input=replace(@input, '"', '')
select @input=replace(@input, '{', '')
select @input=replace(@input, '}', '')
set @input = upper(ltrim(rtrim(@input)));
if(@input is not null and len(@input) = 32)
    begin
    declare @indexchar nchar(1)
    declare @index int;  set @index = 1;
    while (@index <= 32)
        begin
        set @indexchar = substring(@input, @index, 1);
        if (isnumeric(@indexchar) = 1 or @indexchar in ('a', 'b', 'c', 'd', 'e', 'f'))
            set @index = @index + 1;
        else
            break;
        end
    if(@index = 33)   set @isvalidguid = 1;
    end
return @isvalidguid;
end -- function