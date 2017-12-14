/*  leave this
    l:see LICENSE file
    g:utility,io
    v:130510\s.zaglio: added 0<n
    v:130329\s.zaglio: added $<, comments to disambiguate (search 130329)
    v:120523\s.zaglio: a bug near use of goto, when format is a date but @val a string
    v:120406\s.zaglio: added @ tag for string format
    v:110805\s.zaglio: added more symbols to ^ format
    v:110804\s.zaglio: added management of bad float convertion for 0<
    v:110706\s.zaglio: added [eng] format
    v:110705\s.zaglio: a bug near 0<
    v:110620\s.zaglio: expanded left pad format
    v:110601\s.zaglio: added ^ fmt
    v:110527\s.zaglio: added chk of type of @val and name normalization
    v:110516\s.zaglio: used by importing proc
    t:sp__format
                                                                   #
    ###########################################################   ##
    ## -- PLEASE --                                          ##  #######
    ## see/update "sp__format" and read comment's' of 130329 ## ########
    ##                                                       ##  #######
    ###########################################################   ##
                                                                   #
*/
CREATE function fn__format(
    @val sql_variant,
    @fmt nvarchar(128),
    @len int
    )
returns nvarchar(4000)
as
begin

declare
    @ret nvarchar(4000),@svp varchar(32),@i int,
    @tmp nvarchar(4000),@l int,@c nvarchar(2),
    @lc int,@lret int,@p int

select @svp=convert(varchar(32),sql_variant_property(@val,'basetype'))

if @svp='datetime'          goto date_format
if left(@fmt,1)='@'         goto string_format
if left(@fmt,2)='0<'        goto string_0left_padding
if @fmt='$<'                goto money_0left_padding
if substring(@fmt,2,1)='<'  goto specific_pad
if @fmt='[eng]'             goto verbalize
if @fmt='^'                 goto replace_accents
if @fmt in (
    'AN',   -- alfanumeric:replace symbols with _ (only 0-9a-Z)
    'ANs'   -- 120315\alfanumeric:replace symbols with one _ (only 0-9a-Z)
    )                       goto alphanumeric
if @len is null
    select @ret=convert(nvarchar(4000),@val)
else
    select @ret=left(convert(nvarchar(4000),@val),@len)
goto ret

-- ============================================================== date_format ==

date_format:
if @fmt='YYYY'                          -- 110722\s.zaglio
    begin
    select @ret=convert(datetime,@val,8)
    select @ret=cast(year(convert(datetime,@val,8)) as nvarchar(4))
    goto ret
    end -- yyyy
if @fmt='HHMM'
    begin
    select @ret=convert(nvarchar(32),@val,8)
    select @ret=substring(@ret,1,2)+substring(@ret,4,2)
    goto ret
    end -- hhmm
if @fmt='YYYYMMDDHHMMSS'
    begin
    select @ret=convert(nvarchar(32),@val,8)
    select @ret=convert(nvarchar(32),@val,112)
               +substring(@ret,1,2)+substring(@ret,4,2)
               +substring(@ret,7,2)
    goto ret
    end -- YYYYMMDDHHMMSS
if @fmt='YYMMDD_HHMM'                   -- 111115\s.zaglio
    begin
    select @ret=convert(nvarchar(32),@val,8)
    select @ret=convert(nvarchar(32),@val,12)
               +'_'
               +substring(@ret,1,2)+substring(@ret,4,2)
    goto ret
    end -- YYMMDDHHMM
if @fmt='YYYYMMDD_HHMMSS'               -- 110615\s.zaglio
    begin
    select @ret=convert(nvarchar(32),@val,8)
    select @ret=convert(nvarchar(32),@val,112)
               +'_'
               +substring(@ret,1,2)+substring(@ret,4,2)
               +substring(@ret,7,2)
    goto ret
    end -- YYYYMMDDHHMMSS
if @fmt='YYYYMMDD_HHMM'
    begin
    select @ret=convert(nvarchar(32),@val,8)
    select @ret=convert(nvarchar(32),@val,112)
               +'_'
               +substring(@ret,1,2)+substring(@ret,4,2)
    goto ret
    end -- YYYYMMDD_HHMM
if @fmt='HHMMSS'                        -- 120109\s.zaglio
    begin
    select @ret=convert(nvarchar(32),@val,8)
    select @ret=substring(@ret,1,2)+substring(@ret,4,2)
               +substring(@ret,7,2)
    goto ret
    end -- HHMMSS

if @fmt='DD/MM/YYYY HH:MM:SS'           -- 120821\s.zaglio
    begin
    select @ret=convert(nvarchar(32),@val,103)
               +' '
               +convert(nvarchar(32),@val,108)
    goto ret
    end -- DD/MM/YYYY HH:MM:SS

/* 130329\s.zaglio:
    fn__format covert format not already coveder by TSQL CONVERT;
    CONVERT formats have been left out (sono stati lasciati fuori)
    because call of fn__format is extremely slower that CONVERT
    and REPLACE+CONVERT.
    I left this to not break code.
*/

if @fmt='DDMMYYYY'                      -- 121112\A.Sirna
    begin
    select @ret=replace(convert(nvarchar(32),@val,103),'/','')
    goto ret
    end -- DDMMYYYY

if @fmt='YYYYMMDD'                      -- 121112\A.Sirna
    begin
    select @ret=convert(nvarchar(32),@val,112)
    goto ret
    end -- YYYYMMDD

goto ret

-- ====================================================== string left padding ==
string_0left_padding:
/* 130329\s.zaglio:
    bigint was choosen instead of money because money has a fixed 2 digit and
    uses the 'decimal separator' of the local lang.
    A 0 left padded string is necessary to manage a variable number of digits,
    without use the variable and ambigous decimal separator;
    of course an according between sender and receiver or writer and reader must
    pre-exists
*/
-- select dbo.fn__format(123.435,'0<2',10)
-- select round(123.435,2)

if len(@fmt)>2
    begin
    select @i=cast(substring(@fmt,3,4) as int)
    select @ret=convert(nvarchar(4000),
                        round(cast(@val as float),@i)*power(10,@i)
                       )
    end
else
    select @ret=convert(nvarchar(4000),cast(@val as bigint))
select @ret=replicate('0',@len-len(@ret))+@ret
goto ret

money_0left_padding:
select @ret=convert(nvarchar(4000),cast(@val as money))
select @ret=replicate('0',@len-len(@ret))+@ret
goto ret

-- =================================================== specific char left pad ==
specific_pad:
-- ##########################
-- ##
-- ## be careful with len(' ')=0 while datalength(' ')=1
-- ##
-- ########################################################

-- select dbo.fn__format('fn__format','=< ',80)
-- todo: expand formats to: 0<.0, 0<.00, 0<.000 and so on
-- todo: expand formats to: 0<,0, 0<,00, 0<,000 and so on
-- todo: expand formats to: 0<00, 0<000, to multiply x XXX and remove decimal sign
select @ret=convert(nvarchar(4000),@val),
       @c=substring(@fmt,3,1),
       @lc=datalength(@c),@lret=len(@ret)

if @lc=0
    select @ret=replicate(
                    substring(@fmt,1,1),
                    @len-@lret
                    )+@ret
else
    select @ret=replicate(
                    substring(@fmt,1,1),
                    @len-(@lret+
                        case when @c=' '
                             then 1
                             else @lc
                        end)
                    )+@c+@ret
goto ret

-- =================================================== normalize anphanumeric ==

alphanumeric:
select @ret=convert(nvarchar(4000),@val)
select @l=len(@ret)
while @l>0
    if not substring(@ret,@l,1) like '[a-zA-Z0-9]'
        select @ret=stuff(@ret,@l,1,'_'),@l=@l-1
    else
        select @l=@l-1
if @fmt='ANs'
    begin
    while charindex('__',@ret)>0 select @ret=replace(@ret,'__','_')
    select @i=1,@l=len(@ret)
    while substring(@ret,@i,1)='_' select @i=@i+1
    while substring(@ret,@l,1)='_' select @l=@l-1
    select @ret=substring(@ret,@i,@l-@i+1)
    end
goto ret

-- ========================================================= replaces accents ==

replace_accents:
-- select dbo.fn__format('a.é.É.t.è.ù.õ.Ö.Ì.ï.ŝ.s','^',default)
/*  declare @c nvarchar(2),@val sql_variant,@tmp
    sysname,@ret sysname,@l int,@i int select @val='é.É.t.è.ù.õ.Ö.Ì.ï'
*/
declare
    @cc varbinary(8), @acc varbinary(256),@accd varbinary(256),
    @rep nvarchar(128),@repd nvarchar(128),@w int
/*  ÂÃÄÀÁÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿĀāĒřŠŝş
    öèéòìàù ĀāĒóôåæ ÀÁÆËÏÍÌ çćĉřŠŝş'
    ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖÙÚÛÜÝßàáâãäåæçèéêëìíîïðñòóôõöùúûüýþÿĀāĂăĄąĆćĈĉĊċČč
    ĎďĐđĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħĨĩĪīĬĭĮįİıĲĳĴĵĶķĸĹĺĻļĽľĿŀŁłŃńŅņŇňŉŊŋŌōŎŏŐőŒœ
    ŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŦŧŨũŪūŬŭŮůŰűŲųŴŵŶŷŸŹźŻżŽžſƏƒƠơƯưǍǎǏǐǑǒǓǔǕǖǗǘǙǚǛǜǺǻǼǽǾǿØ
*/
select
    @w=len(cast(N' ' as varbinary(8))),
    @tmp=convert(nvarchar(4000),@val),
    @ret='',@i=1,@l=len(@tmp),

    /*  method:
        Research done by position:
             4 to the position of @ acc (Ç) is the rep of @ 4 (C)
    */
    -- @acc contains accented characters to be replaced by individual
    --                    1         2         3         4         5
    --          012345678901234567890123456789012345678901234567890
    @acc=cast(N'ÂÃÅÇÊËÎÐÑÔÕØÛÝÞßâãåçêëîðñôõøûýþĀāĒřŠŝş°¦ª' as varbinary(256)),
    @rep=     N'AAACEEIDNOOOUYBBaaaceeionooouybAaErSss.|a',

    -- @accd contains accented characters to be replaced by double
    --                     1         2         3
    --           0123456789012345678901234567890
    @accd=cast(N'ÄÀÁÆÈÉÌÍÏÒÓÖÙÚÜàáäæèéìíïòóöùúü' as varbinary(256)),
    --                                      1                         2                          3
    --           0 1  2  3 4  5  6  7  8 9  0  1 2  3  4 5  6  7 8 9  0  1  2  3 4  5  6 7  8  9 0
    @repd=     N'AEA''A''AEE''E''I''I''IIO''O''OEU''U''UEa''a''aeaee''e''i''i''iio''o''oeu''u''ue'

if (@tmp like '%['+cast(@acc as nvarchar(128))+cast(@accd as nvarchar(128))+']%' )

    while @i<=@l
        begin
        select
            @c=substring(@tmp,@i,1),
            @cc=cast(@c as varbinary(4)),
            @i=@i+1
        -- exec sp__printf 'cc=%s',@cc
        select @p=charindex(@cc,@acc)
        if @p=0
            begin
            select @p=charindex(@cc,@accd)
            if @p>0 select @c=substring(@repd,@p,2)
            end
        else
            select @c=substring(@rep,@p/@w+1,1)
        select @ret=@ret+@c
        -- exec sp__printf 'c=%s; p=%d',@c,@p
        end -- while
else
    select @ret=@tmp
-- print @ret
goto ret

-- ================================================================ verbalize ==
verbalize:
/*  originally from:
    http://www.novicksoftware.com/udfofweek/Vol2/T-SQL-UDF-Vol-2-Num-9-udf_Num_ToWords.htm
*/
declare @inputnumber varchar(38)
declare @numberstable table (number char(2), word varchar(10))
declare @length int
declare @counter int
declare @loops int
declare @position int
declare @chunk char(3) -- for chunks of 3 numbers
declare @tensones char(2)
declare @hundreds char(1)
declare @tens char(1)
declare @ones char(1)
declare @number numeric (38, 0) -- input number with as many as 18 digits

select @number=convert(numeric(38,0),@val)
if @number = 0 return 'zero'

-- initialize the variables
select @inputnumber = convert(varchar(38), @number)
     , @ret = ''
     , @counter = 1
select @length   = len(@inputnumber)
     , @position = len(@inputnumber) - 2
     , @loops    = len(@inputnumber)/3

-- make sure there is an extra loop added for the remaining numbers
if len(@inputnumber) % 3 <> 0 set @loops = @loops + 1

-- insert data for the numbers and words
insert into @numberstable   select '00', ''
    union all select '01', 'one'      union all select '02', 'two'
    union all select '03', 'three'    union all select '04', 'four'
    union all select '05', 'five'     union all select '06', 'six'
    union all select '07', 'seven'    union all select '08', 'eight'
    union all select '09', 'nine'     union all select '10', 'ten'
    union all select '11', 'eleven'   union all select '12', 'twelve'
    union all select '13', 'thirteen' union all select '14', 'fourteen'
    union all select '15', 'fifteen'  union all select '16', 'sixteen'
    union all select '17', 'seventeen' union all select '18', 'eighteen'
    union all select '19', 'nineteen' union all select '20', 'twenty'
    union all select '30', 'thirty'   union all select '40', 'forty'
    union all select '50', 'fifty'    union all select '60', 'sixty'
    union all select '70', 'seventy'  union all select '80', 'eighty'
    union all select '90', 'ninety'

while @counter <= @loops begin

    -- get chunks of 3 numbers at a time, padded with leading zeros
    set @chunk = right('000' + substring(@inputnumber, @position, 3), 3)

    if @chunk <> '000' begin
        select @tensones = substring(@chunk, 2, 2)
             , @hundreds = substring(@chunk, 1, 1)
             , @tens = substring(@chunk, 2, 1)
             , @ones = substring(@chunk, 3, 1)

        -- if twenty or less, use the word directly from @numberstable
        if convert(int, @tensones) <= 20 or @ones='0' begin
            set @ret = (select word
                                      from @numberstable
                                      where @tensones = number)
                   + case @counter when 1 then '' -- no name
                       when 2 then ' thousand ' when 3 then ' million '
                       when 4 then ' billion '  when 5 then ' trillion '
                       when 6 then ' quadrillion ' when 7 then ' quintillion '
                       when 8 then ' sextillion '  when 9 then ' septillion '
                       when 10 then ' octillion '  when 11 then ' nonillion '
                       when 12 then ' decillion '  when 13 then ' undecillion '
                       else '' end
                               + @ret
            end
         else begin -- break down the ones and the tens separately

             set @ret = ' '
                            + (select word
                                    from @numberstable
                                    where @tens + '0' = number)
                             + '-'
                             + (select word
                                    from @numberstable
                                    where '0'+ @ones = number)
                   + case @counter when 1 then '' -- no name
                       when 2 then ' thousand ' when 3 then ' million '
                       when 4 then ' billion '  when 5 then ' trillion '
                       when 6 then ' quadrillion ' when 7 then ' quintillion '
                       when 8 then ' sextillion '  when 9 then ' septillion '
                       when 10 then ' octillion '  when 11 then ' nonillion '
                       when 12 then ' decillion '   when 13 then ' undecillion '
                       else '' end
                            + @ret
        end

        -- now get the hundreds
        if @hundreds <> '0' begin
            set @ret  = (select word
                                      from @numberstable
                                      where '0' + @hundreds = number)
                                + ' hundred '
                                + @ret
        end
    end

    select @counter = @counter + 1
         , @position = @position - 3

end

-- remove any double spaces
set @ret = ltrim(rtrim(replace(@ret, '  ', ' ')))
set @ret = upper(left(@ret, 1)) + substring(@ret, 2, 4000)
goto ret

-- ============================================================ string format ==

string_format:
declare @nc nchar,@mtpl nvarchar(64)
select
    @i=2,@l=len(@fmt),
    @mtpl='1234567890abcdefghijklmnopqrsxyvwz',
    @ret='',@tmp=cast(@val as nvarchar(4000))

while (@i<=@l)
    select
        @nc=substring(@fmt,@i,1),
        @p=charindex(@nc,@mtpl),
        @ret=@ret+case @p when 0 then @nc else substring(@tmp,@p,1) end,
        @i=@i+1

goto ret

-- if not managed type
select @ret=left(convert(nvarchar(4000),@val),@len)

ret:
return @ret
end -- fn__format