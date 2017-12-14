/*  leave this
    l:see LICENSE file
    g:utility
    v:121007\s.zaglio: a remake (see inside code comments)
    v:081130\S.Zaglio: Levenshtein algo. Originally from http://www.marcopipino.it/sql/levenshtein.php
    t:
        print dbo.fn__str_distance('stefano','stefania',default) -- 1.5
        print dbo.fn__str_distance('stefano','giovanni',default) -- 7.5
        print dbo.fn__str_distance('dal-7134ab1','dal=7134ab1',default)     -- 1
        print dbo.fn__str_distance('dal-7134ab1','dal7134ab1',default)      -- 1.5
        print dbo.fn__str_distance('dal-7134ab1','dal7134ab11',default)     -- 2
        print dbo.fn__str_distance('C.SO UMBERTO I','PIAZZA UMBERTO I',10)  -- 6
        print dbo.fn__str_distance('C.SO UMBERTO I','PIAZZA UMBERTO I',40)  -- 5
*/
CREATE function dbo.fn__str_distance(
    @s1 nvarchar(255),
    @s2 nvarchar(255),
    @maxoffset int      -- default is 5
)
returns float
as
begin
/* this is the choose after some test between 5 fn over 9900 streets:
1. the original from http://www.marcopipino.it/sql/levenshtein.php
   4m 45s 476ms
2. LEVENSHTEIN(@s,@t)
   41s 893ms
3. edit_distance_within
   8s 70ms
4. Sift3distance2
   956ms
5. udfDamerauLevenshteinLim
   10s 166ms
Maybe the 5 can be better but I have no time for a deep test
The Sift3distance2 is more accurate in some cases:
    VIA DEI FRENTANI    VIA DEI VESTINI     7,5 vs 4 in all other fn
and less accurate in some other cases:
    C.SO UMBERTO I        PIAZZA UMBERTO I    15 vs 6 at offset 35
*/

declare @s1len int,@s2len int

select @s1len=len(isnull(@s1,'')),@s2len=len(isnull(@s2,''))

if @s1len=0 return @s2len
else
if @s2len=0 return @s1len

if isnull(@maxoffset,0)=0 set @maxoffset=5

declare
    @currpos int,@matchcnt int,@wrkpos int,
    @s1offset int,@s1char varchar,@s1pos int,@s1dist int,
    @s2offset int,@s2char varchar,@s2pos int,@s2dist int

select @s1offset=0,@s2offset=0,@matchcnt=0,@currpos=0

while(@currpos+@s1offset<@s1len and @currpos+@s2offset<@s2len)
begin
    set @wrkpos=@currpos+1

    if(substring(@s1,@wrkpos+@s1offset,1)=substring(@s2,@wrkpos+@s2offset,1))
        set @matchcnt=@matchcnt+1
    else
    begin
        set @s1offset=0
        set @s2offset=0
        select @s1char=substring(@s1,@wrkpos,1),
               @s2char=substring(@s2,@wrkpos,1)
        select @s1pos=charindex(@s2char,@s1,@wrkpos)-1,
               @s2pos=charindex(@s1char,@s2,@wrkpos)-1
        select @s1dist=@s1pos-@currpos,@s2dist=@s2pos-@currpos
        if(@s1pos>0 and (@s1dist<=@s2dist or @s2pos<1) and @s1dist<@maxoffset)
            set @s1offset=(@s1pos-@wrkpos)+1
        else
        if(@s2pos>0 and (@s2dist<@s1dist or @s1pos<1) and @s2dist<@maxoffset)
            set @s2offset=(@s2pos-@wrkpos)+1
    end

    set @currpos=@currpos+1
end

return (@s1len+@s2len)/2.0-@matchcnt
end -- fn__str_distance