/*  leave this
    l:see LICENSE file
    g:utility
    d:130202\s.zaglio: fn__crc16_tbl
    v:130901\s.zaglio: correction for unicode>32768
    v:130202\s.zaglio: embedded lookup table, 5 times faster
    v:090614\S.Zaglio: used by fn_crc16
    t:
        print dbo.fn__crc16('')         -- 0
        print dbo.fn__crc16('a')        -- 22398
        print dbo.fn__crc16('b')        -- 22078
        print dbo.fn__crc16('aa')       -- -30633
        print dbo.fn__crc16('ab')       -- -30441
        print dbo.fn__crc16('ba')       -- 30805
        print dbo.fn__crc16(N'ウィ')    -- -30571
*/
CREATE function [dbo].[fn__crc16](
    @string nvarchar(4000)
)
returns smallint
as
begin
declare @lookup binary(512)
select @lookup = 0x\
0000C0C1C1810140C30103C00280C241C60106C00780C7410500C5C1C4810440CC010CC00D80\
CD410F00CFC1CE810E400A00CAC1CB810B40C90109C00880C841D80118C01980D9411B00DBC1\
DA811A401E00DEC1DF811F40DD011DC01C80DC411400D4C1D5811540D70117C01680D641D201\
12C01380D3411100D1C1D0811040F00130C03180F1413300F3C1F28132403600F6C1F7813740\
F50135C03480F4413C00FCC1FD813D40FF013FC03E80FE41FA013AC03B80FB413900F9C1F881\
38402800E8C1E9812940EB012BC02A80EA41EE012EC02F80EF412D00EDC1EC812C40E40124C0\
2580E5412700E7C1E68126402200E2C1E3812340E10121C02080E041A00160C06180A1416300\
A3C1A28162406600A6C1A7816740A50165C06480A4416C00ACC1AD816D40AF016FC06E80AE41\
AA016AC06B80AB416900A9C1A88168407800B8C1B9817940BB017BC07A80BA41BE017EC07F80\
BF417D00BDC1BC817C40B40174C07580B5417700B7C1B68176407200B2C1B3817340B10171C0\
7080B041500090C191815140930153C052809241960156C057809741550095C1948154409C01\
5CC05D809D415F009FC19E815E405A009AC19B815B40990159C058809841880148C049808941\
4B008BC18A814A404E008EC18F814F408D014DC04C808C41440084C185814540870147C04680\
8641820142C043808341410081C180814040

declare @crc smallint
declare @c tinyint
declare @t tinyint
declare @a smallint
declare @i smallint
declare @u int
set @a=0
set @crc = 0xFFFF
set @i=1
declare @l int
set @l=len(@string)

while (@i<=@l) begin
    set @u=unicode(substring(@string,@i,1))

    set @c=@u % 256
    set @t=(@crc^@c)&0xff
    set @a=@crc/256
    set @crc=@a ^ substring(@lookup,@t*2+1,2)

    set @c=@u / 256
    if @c!=0 begin -- this keep compatibility with old nvarchar crc32
                   -- and also the whole performances
        set @t=(@crc^@c)&0xff
        set @a=@crc/256
        set @crc=@a ^ substring(@lookup,@t*2+1,2)
        end

    set @i=@i+1
end
set @crc= ~@crc
return @crc
end -- fn__crc16