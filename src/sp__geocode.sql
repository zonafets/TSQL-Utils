/*  leave this
    l:see LICENSE file
    g:utility
    k:gps,coords,street
    v:120124\s.zaglio: ask google for coords
    c:origin http://www.sqlservercentral.com/articles/geocode/70061/
*/
CREATE proc sp__geocode
    @opt sysname = null,
    @dbg int = null
as
begin

-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
if object_id('tempdb..#addr') is null goto help

-- ============================================================== declaration ==

declare
    @address varchar(80) ,
    @city    varchar(40) ,
    @state   varchar(40) ,

    @country varchar(40) ,
    @postalcode varchar(20),

    @county varchar(40) ,

    @gpslatitude numeric(9,6) ,
    @gpslongitude numeric(9,6),
    @mapurl varchar(1024)

declare
    @url varchar(max),
    @response varchar(8000),
    @xml xml,
    @obj int ,
    @hr int ,
    @httpstatus int ,
    @error varchar(max),
    @tmp nvarchar(4000)

-- =========================================================== initialization ==

-- ======================================================== second params chk ==
-- ===================================================================== body ==

-- ##########################
-- ##
-- ## be carefull with upcase letters on xml path
-- ##
-- ########################################################

exec @hr = sp_oacreate 'MSXML2.ServerXMLHttp', @obj out
if @hr!=0 goto err_ole

declare cs cursor local for
    select
        gpslatitude,
        gpslongitude,
        city,
        [state] ,
        postalcode ,
        [address],
        country ,
        county,
        mapurl ,
        error
    from #addr
    where 1=1
open cs
while 1=1
    begin
    fetch next from cs into
        @gpslatitude,
        @gpslongitude,
        @city,
        @state,
        @postalcode,
        @address,
        @country,
        @county,
        @mapurl,
        @error

    if @@fetch_status!=0 break

    exec sp__printf 'addr:%s, state:%s',@address,@state

    select @url =
        'http://maps.google.com/maps/api/geocode/xml?sensor=false&address=' +
        case when @address is not null then @address else '' end +
        case when @city is not null then ', ' + @city else '' end +
        case when @state is not null then ', ' + @state else '' end +
        case when @postalcode is not null then ', ' + @postalcode else '' end +
        case when @country is not null then ', ' + @country else '' end
    select @url = replace(@url, ' ', '+')
    if @dbg=1
        begin
        select @tmp=cast(@url as nvarchar(4000))
        exec sp__printf 'get url:%s',@tmp
        end

    exec @hr = sp_oamethod @obj, 'open', null, 'GET', @url, false
    if @hr!=0 goto err

    exec @hr = sp_oamethod @obj, 'setRequestHeader', null,
                                 'content-type',
                                 'application/x-www-form-urlencoded'
    if @hr!=0 goto err

    exec @hr = sp_oamethod @obj, 'send', null, ''
    if @hr!=0 goto err

    select @httpstatus=null,@response=null,@xml=null
    exec @hr = sp_oagetproperty @obj, 'status', @httpstatus out
    if @hr!=0 goto err
    -- exec @hr = sp_oagetproperty @obj, 'responseXML.xml', @response out
    exec @hr = sp_oagetproperty @obj, 'responseText', @response out

    err:
    if (@error is not null) or (@httpstatus <> 200) or (@hr!=0)
        begin
        exec sp_oageterrorinfo @obj, @error out, @tmp out
        if @httpstatus <> 200 and @hr=0
            select
                @error = 'error in spgeocode: ' +
                isnull(@error, 'http result is: ' +
                cast(@httpstatus as varchar(10)))
        else
            select @error=cast(@hr as sysname)+':'+isnull(@error,'?')+' - '+isnull(@tmp,'?')
        goto skip
        end

    select @xml = cast(@response as xml)

    if @dbg>1
        begin
        select @tmp=cast(@xml as nvarchar(4000))
        exec sp__printf 'xml:%s',@tmp
        end

    select
        @gpslatitude = @xml.value('(/GeocodeResponse/result/geometry/location/lat) [1]', 'numeric(9,6)'),
        @gpslongitude = @xml.value('(/GeocodeResponse/result/geometry/location/lng) [1]', 'numeric(9,6)'),
        @city = @xml.value('(/GeocodeResponse/result/address_component[type="locality"]/long_name) [1]', 'varchar(40)'),
        @state = @xml.value('(/GeocodeResponse/result/address_component[type="administrative_area_level_1"]/short_name) [1]', 'varchar(40)'),
        @postalcode = @XML.value('(/GeocodeResponse/result/address_component[type="postal_code"]/long_name) [1]', 'varchar(20)') ,
        @country = @XML.value('(/GeocodeResponse/result/address_component[type="country"]/short_name) [1]', 'varchar(40)') ,
        @county = @XML.value('(/GeocodeResponse/result/address_component[type="administrative_area_level_2"]/short_name) [1]', 'varchar(40)') ,
        @address =
            ISNULL(@XML.value('(/GeocodeResponse/result/address_component[type="street_number"]/long_name) [1]', 'varchar(40)'), '???') + ' ' +
            ISNULL(@XML.value('(/GeocodeResponse/result/address_component[type="route"]/long_name) [1]', 'varchar(40)'), '???'),
        @mapurl = 'http://maps.google.com/maps?f=q&hl=en&q=' + cast(@gpslatitude as varchar(20)) + '+' + cast(@gpslongitude as varchar(20))

    skip:
    update #addr set
        gpslatitude     =@gpslatitude,
        gpslongitude    =@gpslongitude,
        city            =@city,
        [state]         =@state,
        postalcode      =@postalcode,
        [address]       =@address,
        country         =@country,
        county          =@county,
        mapurl          =@mapurl,
        error           =@error
    where current of cs

    end -- while of cursor
close cs
deallocate cs

exec @hr = sp_oadestroy @obj

goto ret

-- =================================================================== errors ==
err_ole:    exec @ret=sp__err 'object creation error',@proc goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    fill a table with corrected addresses and coords from google maps

Parameters
    #addr   is the table with addresses. Must be specified at least
            address,city and state

            create table #addr(
                [address]   varchar(80) null,
                city        varchar(40) null,
                [state]     varchar(40) null,
                country     varchar(40) null,
                postalcode  varchar(20) null,
                county      varchar(40) null,
                gpslatitude numeric(9,6) null,
                gpslongitude numeric(9,6) null,
                mapurl      varchar(1024) null,
                error       varchar(max) null
            )

Examples
    insert #addr(address,city,state)
    select "1234 N. Main Street","Sant Ana","CA" union
    select "219 E Washington Ave","Sant Ana","CA" union
    select "219 E Washington Ave",null,"CA"     -- this cause an error
                                                -- but the url would work
    exec sp__geocode
    select * from #addr
'

-- ===================================================================== exit ==
ret:
return @ret
end -- sp__geocode