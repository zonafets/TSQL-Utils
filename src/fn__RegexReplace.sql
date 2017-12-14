/*  leave this
    l:see LICENSE file
    g:utility
    v:131009\s.zaglio:restyle
    v:080101\www.simple-talk.com
    t:
        --remove repeated words in text
        SELECT  dbo.fn__RegexReplace('\b(\w+)(?:\s+\1\b)+', '$1',
                                 'Sometimes I cant help help help stuttering',1, 1)

        --find a #comment and add a TSQL --
        SELECT  dbo.fn__RegexReplace('#.*','--$&','
        # this is a comment
        first,second,third,fourth',1,1)

        --replace a url with an HTML anchor
        SELECT  dbo.fn__RegexReplace(
                '\b(https?|ftp|file)://([-A-Z0-9+&@#/%?=~_|!:,.;]*[-A-Z0-9+&@#/%=~_|])',
                '<a href="$2">$2</a>',
                 'There is  this amazing site at http://www.simple-talk.com',1,1)

        --strip all HTML elements out of a string
        SELECT  dbo.fn__RegexReplace('<(?:[^>''"]*|([''"]).*?\1)*>',
           '','<a href="http://www.simple-talk.com">Simle Talk is wonderful</a><!--This is a comment --> we all love it',1,1)

        --import delimited ntext into a database, converting it into insert statements
        SELECT  dbo.fn__RegexReplace(
         '([^\|\r\n]+)[|\r\n]+([^\|\r\n]+)[|\r\n]+([^\|\r\n]+)[|\r\n]+([^\|\r\n]+)[|\r\n]+',
         'Insert into MyTable (Firstcol,SecondCol, ThirdCol, Fourthcol)
        select $1,$2,$3,$4
        ','1|white gloves|2435|24565
        2|Sports Shoes|285678|0987
        3|Stumps|2845|987
        4|bat|29862|4875',1,1)
*/
CREATE FUNCTION dbo.fn__RegexReplace
    (
      @pattern nvarchar(255),
      @replacement nvarchar(255),
      @Subject nvarchar(4000),
      @global BIT = 1,
     @Multiline bit =1
    )
returns nvarchar(4000)

/*the regexreplace function takes three string parameters. the pattern
(the regular expression) the replacement expression, and the subject
string to do the manipulation to.

the replacement expression is one that can cause difficulties. you can
specify an empty string '' as the @replacement text. this will cause the
replace method to return the subject string with all regex matches
deleted from it (see "strip all html elements out of a string" below).
to re-insert the regex match as part of the replacement, include $& in
the replacement text. (see "find a #comment and add a tsql --" below)
if the regexp contains capturing parentheses, you can use backreferences
in the replacement text. $1 in the replacement ntext inserts the ntext
matched by the first capturing group, $2 the second, etc. up to $9.
(e.g. see import delimited ntext into a database below) to include a
literal dollar sign in the replacements, put two consecutive dollar
signs in the string you pass to the replace method.*/
as
begin
declare @objregexexp int,
    @objerrorobject int,
    @strerrormessage nvarchar(255),
    @substituted nvarchar(4000),
    @hr int,
    @replace bit

select  @strerrormessage = 'creating a regex object'
exec @hr= sp_oacreate 'vbscript.regexp', @objregexexp out
if @hr = 0
    select  @strerrormessage = 'setting the regex pattern',
            @objerrorobject = @objregexexp
if @hr = 0
    exec @hr= sp_oasetproperty @objregexexp, 'pattern', @pattern
if @hr = 0 /*
              by default, the regular expression is case sensitive.
              set the ignorecase property to true to make it case insensitive.
           */
    select  @strerrormessage = 'specifying the type of match'
if @hr = 0
    exec @hr= sp_oasetproperty @objregexexp, 'ignorecase', 1
if @hr = 0
    exec @hr= sp_oasetproperty @objregexexp, 'multiline', @multiline
if @hr = 0
    exec @hr= sp_oasetproperty @objregexexp, 'global', @global
if @hr = 0
    select  @strerrormessage = 'doing a replacement'
if @hr = 0
    exec @hr= sp_oamethod @objregexexp, 'replace', @substituted out,
        @subject, @replacement
/*if the regexp.global property is false (the default), replace will return
the @subject string with the first regex match (if any) substituted with
the replacement text. if regexp.global is true, the @subject string will
be returned with all matches replaced.*/
if @hr <> 0
    begin
        declare @source nvarchar(255),
            @description nvarchar(255),
            @helpfile nvarchar(255),
            @helpid int

        execute sp_oageterrorinfo @objerrorobject, @source output,
            @description output, @helpfile output, @helpid output
        select  @strerrormessage = 'error whilst '
                + coalesce(@strerrormessage, 'doing something') + ', '
                + coalesce(@description, '')
        return @strerrormessage
    end
exec sp_oadestroy @objregexexp
return @substituted
end -- fn__RegexReplace