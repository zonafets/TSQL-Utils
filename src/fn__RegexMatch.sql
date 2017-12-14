/*  leave this
    l:see LICENSE file
    g:utility
    v:131009\s.zaglio:restyle
    v:080101\www.simple-talk.com
    c:probably the best tutorial on the web for regular expressions is on www.regular-expressions.info
    c:but it is also worth reading implementing real-world data input validation using regular expressions by francis norton
    c:for an introduction to regular expressions:
    c:http://www.simple-talk.com/dotnet/.net-framework/implementing-real-world-data-input-validation-using-regular-expressions/
    t:
        -- now, with this routine, we can do some complex input validation
        --is there a repeating word
        select dbo.fn__regexmatch('\b(\w+)\s+\1\b','this has has been repeated')--1
        select dbo.fn__regexmatch('\b(\w+)\s+\1\b','this has not been repeated')--0

        --find a word near another word (in this case 'for' and 'last' 1 or 2 words apart)
        select dbo.fn_regexmatch('\bfor(?:\w+\w+){1,2}?\w+last\b',
                   'you have failed me for the last time, admiral')--1
        select dbo.fn__regexmatch('\bfor(?:\w+\w+){1,2}?\w+last\b',
                   'you have failed me for what could be the last time, admiral')--0

        --is this likely to be a valid credit card
        select dbo.fn__regexmatch('^(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|6011[0-9]{12}|3(?:0
        [0-5]|[68][0-9])[0-9]{11}|3[47][0-9]{13}|(?:2131|1800)\d{11})$','4953129482924435')

        --is this a valid zip code
        select dbo.fn__regexmatch('^[0-9]{5,5}([- ]?[0-9]{4,4})?$','02115-4653')

        --is this a valid postcode
        select dbo.fn__regexmatch('^([gg][ii][rr] 0[aa]{2})|((([a-za-z][0-9]{1,2})|(([a-za-z][a-ha
        -hj-yj-y][0-9]{1,2})|(([a-za-z][0-9][a-za-z])|([a-za-z][a-ha-hj-yj-y][0-9]?[a-za-z])))
        ) {0,1}[0-9][a-za-z]{2})$','rg35 2aq')

        --is this a valid european date
        select dbo.fn__regexmatch('^((((31\/(0?[13578]|1[02]))|((29|30)\/(0?[1,3-9]|1[0-2])))\/(1[
        6-9]|[2-9]\d)?\d{2})|(29\/0?2\/(((1[6-9]|[2-9]\d)?(0[48]|[2468][048]|[13579][26])|((16
        |[2468][048]|[3579][26])00))))|(0?[1-9]|1\d|2[0-8])\/((0?[1-9])|(1[0-2]))\/((1[6-9]|[2
        -9]\d)?\d{2})) (20|21|22|23|[0-1]?\d):[0-5]?\d:[0-5]?\d$','12/12/2007 20:15:27')

        --is this a valid currency value (dollar)
        select dbo.fn__regexmatch('^\$(\d{1,3}(\,\d{3})*|(\d+))(\.\d{2})?$','$34,000.00')

        --is this a valid currency value (sterling)
        select dbo.fn__regexmatch('^\&pound;(\d{1,3}(\,\d{3})*|(\d+))(\.\d{2})?$',
        '&pound;34,000.00')

        --a valid email address?
        select dbo.fn__regexmatch('^(([a-za-z0-9!#\$%\^&\*\{\}''`\+=-_\|/\?]+(\.[a-za-z0-9!#\$%\^&
        \*\{\}''`\+=-_\|/\?]+)*){1,64}@(([a-za-z0-9]+[a-za-z0-9-_]*){1,63}\.)*(([a-za-z0-9]+[a
        -za-z0-9-_]*){3,63}\.)+([a-za-z0-9]{2,4}\.?)+){1,255}$','phil.factor@simple-talk.com')
*/
CREATE function dbo.fn__regexmatch
    (
      @pattern nvarchar(2000),
      @matchstring nvarchar(max)--varchar(8000) got sql server 2000
    )
returns int
/* the regexmatch returns true or false, indicating if the regular expression
matches (part of) the string. (it returns null if there is an error).
when using this for validating user input, you'll normally want to check
if the entire string matches the regular expression. to do so, put a caret
at the start of the regex, and a dollar at the end, to anchor the regex at
the start and end of the subject string.
*/
-- with this function, the passing back of errors is rudimentary.
-- if an ole error occurs, then a null is passed back.
as
begin
declare @objregexexp int,
    @objerrorobject int,
    @strerrormessage nvarchar(255),
    @hr int,
    @match bit

select  @strerrormessage = 'creating a regex object'
exec @hr= sp_oacreate 'vbscript.regexp', @objregexexp out
if @hr = 0
    exec @hr= sp_oasetproperty @objregexexp, 'pattern', @pattern
    --specifying a case-insensitive match
if @hr = 0
    exec @hr= sp_oasetproperty @objregexexp, 'ignorecase', 1
    --doing a test'
if @hr = 0
    exec @hr= sp_oamethod @objregexexp, 'test', @match out, @matchstring
if @hr <> 0
    begin
        return null
    end
exec sp_oadestroy @objregexexp
return @match
end -- fn__regexmatch