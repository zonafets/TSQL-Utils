/*  leave this
    l:see LICENSE file
    g:utility
    v:090815\s.zaglio: find a word in a sentence
    t:print dbo.fn__words_replace(
        ' declare @v nvarchar(12) nchar @v=convert(nvarchar,@varchar)',
        default,
        'varchar|char',
        'nvarchar|nchar',
        default,
        default)
*/
CREATE function [dbo].[fn__words_replace](
    @sentence nvarchar(4000),
    @sep nvarchar(32)='|',
    @words sysname,
    @replaces sysname,
    @lt sysname=null,
    @rt sysname=null
    )
returns nvarchar(4000)
as
begin
declare
    @i int,@l int,@j int,@n int,
    @word sysname,@replace sysname
if @sentence is null return null
select @j=1,@n=dbo.fn__str_count(@words,@sep)
while @j<=@n
    begin
    select @word=dbo.fn__str_at(@words,@sep,@j)
    select @replace=dbo.fn__str_at(@replaces,@sep,@j)
    select @j=@j+1,@l=len(@word),@i=dbo.fn__word_find(@sentence,@word,@lt,@rt)
    while (@i>0)
        begin
        select @sentence=substring(@sentence,1,@i-1)+@replace+substring(@sentence,@i+@l,4000)
        select @i=dbo.fn__word_find(@sentence,@word,@lt,@rt)
        end -- while
    end -- while words
return @sentence
end -- function fn__word_find