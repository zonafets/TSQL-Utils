/*  leave this
    l:see LICENSE file
    g:utility,web,test
    v:121019\s.zaglio: done test 4 and xml extraction
    r:121018\s.zaglio: testing smart soap call
    r:121017\s.zaglio: adapted sp__web_ws to null prev bugs
    r:121016\s.zaglio: bug near N' and crlf
    r:121015\s.zaglio: test sp__web_ws
    t:sp__web_test 'all',@dbg=1
*/
CREATE proc sp__web_test
    @tst sysname = null,
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    -- error vars
    @e_msg nvarchar(4000),              -- message error
    @e_opt nvarchar(4000),              -- error option
    @e_p1  sql_variant,
    @e_p2  sql_variant,
    @e_p3  sql_variant,
    @e_p4  sql_variant

select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
declare
    -- generic common
    -- @i int,@n int,                      -- index, counter
    -- @sql nvarchar(max),                 -- dynamic sql
    -- options
    -- @opt1 bit,@opt2 bit,
    @crlf nvarchar(2),
    @response nvarchar(max),
    @status nvarchar(4000),
    @url nvarchar(1024),
    @sa  nvarchar(1024),
    @xml xml,
    @end_declare bit

-- =========================================================== initialization ==
select
    -- @opt1=charindex('|opt|',@opt),
    @crlf=crlf,
    @tst=isnull(@tst,''),
    @end_declare=1
from fn__sym()

-- ======================================================== second params chk ==
if @tst='' goto help
if @tst='all' select @tst='0'
if isnumeric(@tst)=0 goto err_tst
if @tst<0 or @tst>4 goto err_tst

-- ===================================================================== body ==
-- sp__web_test run,@dbg=1
if @tst in (0,1)
    begin
    exec sp__prints 'simple url get'
    select @url='http://www.webservicex.com/stockquote.asmx/GetQuote?symbol=MSFT'
    exec @ret=sp__web @url,@rsp=@response out,@sts=@status out,@dbg=@dbg
    if @ret in (0,-176288843) exec sp__printsql @response
    else exec sp__printf 'ret=%d, status=%s',@ret,@status
    end

-- sp__web_test 2,@dbg=1
if @tst in (0,2)
    begin
    exec sp__prints 'not exists test'
    select @url='http://www.thisdonotexist.exw/i.html'
    exec @ret=sp__web @url,@dbg=@dbg
    if @ret in (0,-176288843) exec sp__printsql @response
    else exec sp__printf 'ret=%d, status=%s',@ret,@status

    exec sp__prints 'bad method'
    select @url='http://www.webservicex.com/stockquote.asmx/GetQuote?symbol=MSFT'
    exec @ret=sp__web @url,'got',@dbg=@dbg
    if @ret in (0,-176288843) exec sp__printsql @response
    else exec sp__printf 'ret=%d, status=%s',@ret,@status
    end

-- sp__web_test 3,@dbg=1
if @tst in (0,3)
    begin
    exec sp__prints 'web service test with timeouts and xml parse'
    select @url='http://www.webservicex.net/globalweather.asmx'
    exec @ret=sp__web @url,
        @rsp=@response out,
        @sa='http://www.webserviceX.NET/GetWeather',
        @rcq='
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <soap:Body>
            <GetWeather xmlns="http://www.webserviceX.NET">
              <CityName>brescia</CityName>
              <CountryName>italy</CountryName>
            </GetWeather>
          </soap:Body>
        </soap:Envelope>'
        ,@opt='to:1000,1000,1000,1000'
        ,@sts=@status out,@dbg=@dbg --,@opt='nodecode'
    if @ret in (0,-176288843) exec sp__printsql @response
    else exec sp__printf 'ret=%d, status=%s',@ret,@status

    -- extract xml data
    select @xml = cast(@response as xml)
    select
        t.c.value('Location[1]', 'nvarchar(20)') as 'Location',
        t.c.value('Time[1]',     'nvarchar(10)') as 'Time',
        t.c.value('Wind[1]',     'nvarchar(50)') as 'Wind',
        t.c.value('Visibility[1]', 'nvarchar(200)') as 'Visibility',
        -- alternative direct method
        @xml.value('(//CurrentWeather/SkyConditions)[1]', 'nvarchar(20)') SkyCond,
        @xml.value('(//CurrentWeather/temperature)[1]', 'nvarchar(20)') Temp,   -- case sensitive
        @xml.value('(//CurrentWeather/DewPoint)[1]', 'nvarchar(20)') DewPoint,
        @xml.value('(//CurrentWeather/RelativeHumidity)[1]', 'nvarchar(20)') Humidity,
        @xml.value('(//CurrentWeather/Pressure)[1]', 'nvarchar(20)') Pressure,
        @xml.value('(//CurrentWeather/Status)[1]', 'nvarchar(20)') Status
    from @xml.nodes('//CurrentWeather') t(c)
    end -- test 3

-- sp__web_test 4,@dbg=1
if @tst in (0,4)
    begin
    exec sp__prints 'smart SOAP call'
    create table #rcqprms(
        id int identity, rid int default(0),
        var nvarchar(500),
        val nvarchar(max)
        )

    insert #rcqprms(var,val) select 'CityName','brescia'
    insert #rcqprms(var,val) select 'CountryName','italy'

    select @url='http://www.webserviceX.NET/globalweather.asmx',
           @sa ='GetWeather'
    exec @ret=sp__web @uri=@url,
                      @sa=@sa,@sts=@status out,@rsp=@response out
                      ,@dbg=@dbg
    if @ret in (0,-176288843) exec sp__printsql @response
    else exec sp__printf 'ret=%d, status=%s',@ret,@status

    drop table #rcqprms
    end -- soap smart call

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- =================================================================== errors ==
err:        exec @ret=sp__err @e_msg,@proc,@p1=@e_p1,@p2=@e_p2,@p3=@e_p3,
                              @p4=@e_p4,@opt=@e_opt                     goto ret

err_tst:    select @e_msg='wrong @tst value'                            goto err
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    test the sp__web_ws:
    1. simple test (get a url)
    2. wrong test (bad url)
    3. wrong method (got instead of get)

Parameters
    @tst    id of specific test
            1   test simple get
            2   test wrong params
            3   test SOAP call
            4   test SOAP smart call
            ALL all above
    @opt    options (not used)
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__web_test