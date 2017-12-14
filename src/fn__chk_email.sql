/*  leave this
    l:see LICENSE file
    g:utility
    v:121004.1424\s.zaglio: accept empty email when uses @seps
    v:121004\s.zaglio: changed fn__chk_str to fn__str_chk and used multi @seps
    v:110720\s.zaglio: added null/empty test
    v:110408\s.zaglio: return wrong emails instead of a boolean
    v:110219\s.zaglio: check if @email is correct and return wrongs
    t:print dbo.fn__chk_email('me.you@me@you',default)  -- ko
    t:print dbo.fn__chk_email('me.you@m-e',default)     -- null
    t:print dbo.fn__chk_email('me@#me',default)         -- ko
    t:print dbo.fn__chk_email('me@me;you@you',';')      -- null
    t:print dbo.fn__chk_email('me@me;you@U#U',';')      -- ko
    t:print dbo.fn__chk_email('me.youm-e',default)      -- ko
    t:print dbo.fn__chk_email('me@you.com',default)     -- ok
    t:print dbo.fn__chk_email('ok@ok.ok;me.youm-e;ok@ok.ok',';')      -- ko
    t:print dbo.fn__chk_email('ok1@ok.ok;ok2@ok.ok;',';,')      -- ok
    t:print dbo.fn__chk_email('ok1@ok.ok;;',';,')      -- ok
    t:sp__find 'fn__chk_email'
*/
CREATE function fn__chk_email(@email nvarchar(4000),@seps nvarchar(32))
returns nvarchar(4000)
as
begin
declare
    @chars nvarchar(32),@token nvarchar(1024),@wrong nvarchar(1024),
    @i int
select @chars='-a-z0-9_.@' -- !#$%&'*+-/=?^_`{|}~

-- empty or null email is an error (forgotten?)
if isnull(@email,'')='' return ''

if @seps is null
    begin
    if dbo.fn__str_count(@email,'@')!=2
    or dbo.fn__str_chk(@email,@chars)=0 -- not exists
        return @email
    end -- single mail

select @i=1
while 1=1
    begin
    select @token=dbo.fn__str_parse(@email,@seps,@i)
    -- select dbo.fn__str_parse('ok1@ok.ok;ok2@ok.ok;',';,',1)
    if @token is null break
    if @token!=''
    and (dbo.fn__str_count(@token,'@')!=2
         or dbo.fn__str_chk(@token,@chars)!=1
        )
        select @wrong=isnull(@wrong+left(@seps,1),'')+@token
    select @i=@i+1
    end -- while of cursor

return @wrong
end -- fn__chk_email