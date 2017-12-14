/*  leave this
    l:see LICENSE file
    g:utility
    v:090815\s.zaglio: find a word in a sentence
    t:print dbo.fn__word_find('convert(nvarchar,@test)','varchar',default,default) -->9
    t:print dbo.fn__word_find('declare @test nvarchar(10)','varchar',default,default) -->15
    t:print dbo.fn__word_find('varchar  10','varchar',default,default) ->1
    t:print dbo.fn__word_find('set nvarchar  10','varchar',default,default) ->0
*/
CREATE function [dbo].[fn__word_find](
    @sentence nvarchar(4000),
    @word sysname,
    @lt sysname=null,
    @rt sysname=null
    )
returns int
as
begin
declare @i int,@c nchar
declare @key sysname
declare @points sysname
if @sentence is null return null
select @points=' ([,])'
if @lt is null select @lt=@points+char(9)
if @rt is null select @rt=@points+char(13)
select @key='%'+replace(replace(@word,'_','[_]'),'%','[%]')+'%'
/*  tests:
    print patindex('%word%','wordcap') -->1
    print patindex('%_word%','wordcap') -->0
    print patindex('%_word%','inwordcap') -->2
    print patindex('%word%','demoword') -->5
    if substring('hello',6,1)='' print 'empty space'  -->empty space
    if substring('hello',-1,1)='' print 'empty space'  -->empty space
*/
select @i=patindex(@key,@sentence)
if @i=0 return 0
select @c=substring(@sentence,@i+len(@word),1)
if @c!='' and charindex(@c,@rt)=0 return 0
select @c=substring(@sentence,@i-1,1)
if @c!='' and charindex(@c,@lt)=0 return 0
return @i
end -- function fn__word_find