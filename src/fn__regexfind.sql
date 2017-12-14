/*  leave this
    l:see LICENSE file
    g:utility
    v:131009\s.zaglio:restyle
    v:080101\www.simple-talk.com
    t:
        begin
        --showing the context where two words 'for' and 'last' are found in proximity
        DECLARE @sample nvarchar(2000)
        SELECT @Sample='You have failed me for the last time, Admiral.
        We have not long to wait for your last gasp'
        SELECT '...'+SUBSTRING(@Sample,Firstindex-8,length+16)+'...'
            FROM dbo.fn__RegexFind ('\bfor(?:\W+\w+){0,3}?\W+last\b',
                   @sample,1,1)

        --finding repeated words, showing the repetition and the repeated word
        SELECT [repetition]=value, [word]=SubmatchValue FROM dbo.fn__RegexFind ('\b(\w+)\s+\1\b',
        'this this is is a repeated word word word',1,1)

        --Split lines based on a regular expression
        SELECT value FROM dbo.fn__regexfind('[^\r\n]*(?:[\r\n]*)',
        '
        This is the second line
        This is the third
        and the fourth',1,1) WHERE length>0

        --break up all words in a string into separate table rows
        SELECT value FROM dbo.fn__RegexFind ('\b[\w]+\b',
        'Hickory dickory dock,the mouse ran up the clock',1,1)

        --split ntext into keywords and values
        SELECT Match_ID,
        [keyword]=MAX (CASE WHEN submatch_ID=1 THEN  submatchValue ELSE '' END),
        [value]=MAX (CASE WHEN submatch_ID=2 THEN  submatchValue ELSE '' END)
          FROM dbo.fn__RegexFind ('(\w+)\s*=\s*(.*)\s*',
        'firstname=Phil
        Lastname=Factor
        Salary=$200,000
        age=unknown to us
        Post=DBA',1,1) GROUP BY Match_ID

        SELECT * FROM dbo.fn__RegexFind ('([^\|\r\n]+[\|\r\n]+)',
        '1|white gloves|2435|24565
        2|Sports Shoes|285678|0987
        3|Stumps|2845|987
        4|bat|29862|4875',1,1)

        --get valid dates and convert to SQL Server format
        SELECT DISTINCT CONVERT(DATETIME,value,103)
        FROM dbo.fn__RegexFind ('\b(0?[1-9]|[12][0-9]|3[01])[- /.](0?[1-9]|1[012])[- /.](19|20?[0-9]{2})\b','
        12/2/2006 12:30 <> 13/2/2007
        13:30
        32/3/2007
        2-4-2007
        25.8.2007
        1/1/2005
        34/2/2104
        2/5/2006',1,1)

        end
*/
CREATE function fn__regexfind(
    @pattern nvarchar(255),
    @matchstring nvarchar(max),
    @global bit = 1,
    @multiline bit =1)
returns
    @result table
        (
        match_id int,
          firstindex int ,
          length int ,
          value nvarchar(2000),
          submatch_id int,
          submatchvalue nvarchar(2000),
         error nvarchar(255)
        )


as -- columns returned by the function
/* this is the most powerful function for doing complex finding and replacing of text.
as it passes back detailed records of the hits, including the location and the backreferences,
it allows for complex manipulations.

this is written as a table function. the regex routine actually passes back a collection for each 'hit'.
in the relational world, you'd normally represent this in two tables, so we've returned a left outer join
of the two logical tables so as to pass back all the information.
this seems to cater for all the uses we can think of. we also append an error column, which should be blank!
*/
begin
declare @objregexexp int,
    @objerrorobject int,
    @objmatch int,
    @objsubmatches int,
    @strerrormessage nvarchar(255),
   @error nvarchar(255),
    @substituted nvarchar(4000),
    @hr int,
    @matchcount int,
    @submatchcount int,
    @ii int,
    @jj int,
    @firstindex int,
    @length int,
    @value nvarchar(2000),
    @submatchvalue nvarchar(2000),
    @objsubmatchvalue int,
    @command nvarchar(4000),
    @match_id int

declare @match table
    (
      match_id int identity(1, 1)
                   not null,
      firstindex int not null,
      length int not null,
      value nvarchar(2000)
    )
declare @submatch table
    (
      submatch_id int identity(1, 1),
      match_id int not null,
      submatchno int not null,
      submatchvalue nvarchar(2000)
    )

select  @strerrormessage = 'creating a regex object',@error=''
exec @hr= sp_oacreate 'vbscript.regexp', @objregexexp out
if @hr = 0
    select  @strerrormessage = 'setting the regex pattern',
            @objerrorobject = @objregexexp
if @hr = 0
    exec @hr= sp_oasetproperty @objregexexp, 'pattern', @pattern
if @hr = 0
    select  @strerrormessage = 'specifying a case-insensitive match'
if @hr = 0
    exec @hr= sp_oasetproperty @objregexexp, 'ignorecase', 1
if @hr = 0
    exec @hr= sp_oasetproperty @objregexexp, 'multiline', @multiline
if @hr = 0
    exec @hr= sp_oasetproperty @objregexexp, 'global', @global
if @hr = 0
    select  @strerrormessage = 'doing a match'
if @hr = 0
    exec @hr= sp_oamethod @objregexexp, 'execute', @objmatch out,
        @matchstring
if @hr = 0
    select  @strerrormessage = 'getting the number of matches'
if @hr = 0
    exec @hr= sp_oagetproperty @objmatch, 'count', @matchcount out
select  @ii = 0
while @hr = 0
    and @ii < @matchcount
    begin
    /*the match object has four read-only properties.
    the firstindex property indicates the number of characters in the string to the left of the match.
    the length property of the match object indicates the number of characters in the match.
    the value property returns the ntext that was matched.*/
        select  @strerrormessage = 'getting the firstindex property',
                @command = 'item(' + cast(@ii as nvarchar) + ').firstindex'
        if @hr = 0
            exec @hr= sp_oagetproperty @objmatch, @command,
                @firstindex out
        if @hr = 0
            select  @strerrormessage = 'getting the length property',
                    @command = 'item(' + cast(@ii as nvarchar) + ').length'
        if @hr = 0
            exec @hr= sp_oagetproperty @objmatch, @command, @length out
        if @hr = 0
            select  @strerrormessage = 'getting the value property',
                    @command = 'item(' + cast(@ii as nvarchar) + ').value'
        if @hr = 0
            exec @hr= sp_oagetproperty @objmatch, @command, @value out
        insert  into @match
                (
                  firstindex,
                  [length],
                  [value]
                )
                select  @firstindex + 1,
                        @length,
                        @value
        select  @match_id = @@identity
        /* the submatches property of the match object is a collection of
        strings. It will only hold values if your regular expression has
        capturing groups. The collection will hold one string for each
        capturing group. The count property (returned as submatchcount)
        indicates the number of string in the collection.
        The item property takes an index parameter, and returns the ntext
        matched by the capturing group.
        */
        if @hr = 0
            select  @strerrormessage = 'getting the submatches collection',
                    @command = 'item(' + cast(@ii as nvarchar)
                    + ').submatches'
        if @hr = 0
            exec @hr= sp_oagetproperty @objmatch, @command,
                @objsubmatches out
        if @hr = 0
            select  @strerrormessage = 'getting the number of submatches'
        if @hr = 0
            exec @hr= sp_oagetproperty @objsubmatches, 'count',
                @submatchcount out
        select  @jj = 0
        while @hr = 0
            and @jj < @submatchcount
            begin
                if @hr = 0
                    select  @strerrormessage = 'getting the submatch value property',
                            @command = 'item(' + cast(@jj as nvarchar)
                            + ')' ,@submatchvalue=null
                if @hr = 0
                    exec @hr= sp_oagetproperty @objsubmatches, @command,
                        @submatchvalue out
                insert  into @submatch
                        (
                          match_id,
                          submatchno,
                          submatchvalue
                        )
                        select  @match_id,
                                @jj+1,
                                @submatchvalue
                select  @jj = @jj + 1
            end
        select  @ii = @ii + 1
    end
if @hr <> 0
    begin
        declare @source nvarchar(255),
            @description nvarchar(255),
            @helpfile nvarchar(255),
            @helpid int

        execute sp_oageterrorinfo @objerrorobject, @source output,
            @description output, @helpfile output, @helpid output
        select  @error = 'error whilst '
                + coalesce(@strerrormessage, 'doing something') + ', '
                + coalesce(@description, '')
    end
exec sp_oadestroy @objregexexp
 exec sp_oadestroy        @objmatch
 exec sp_oadestroy        @objsubmatches

insert into @result
      (match_id,
      firstindex,
      [length],
      [value],
      submatch_id,
      submatchvalue,
     error)


select  m.[match_id],
       [firstindex],
       [length],
       [value],[submatchno],
       [submatchvalue],@error
from    @match m
left outer join   @submatch s
on m.match_id=s.match_id
if @@rowcount=0 and len(@error)>0
insert into @result(error) select @error
return
end -- fn__regexfind