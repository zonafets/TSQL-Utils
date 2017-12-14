/*  leave this
    l:see LICENSE file
    g:utility,util_tkns
    v:130509\s.zaglio: a small bug on last word
    v:130505\s.zaglio: added min option
    v:120403\s.zaglio: remake of csv parse using (faster) code
    v:120402\s.zaglio: refine of csv option using (slow) regexp
    v:120329\s.zaglio: added more columns and csv option
    v:111114\s.zaglio: split a line into words by @sep
    t:
        select * from fn__str_words(' first name   last name   age  ',' ',default)
        select * from fn__str_words(' first name   last name   age  ','  ',default)
        select * from fn__str_words('   first name     last name   age  ','  ',default)
        select * from fn__str_words('   first name     last name   age  ','  ','min')
    t:
        select * from fn__str_words('a,b,c,"d""",e,"",".,.",f',',',default)
        select * from fn__str_words('a,b,c,"d""",e,"",".,.,.",f,",",g',',','csv')
*/
CREATE function [dbo].[fn__str_words](
    @line nvarchar(4000),
    @sep nvarchar(32),
    @opt sysname)
returns @tbl table(
    c00 nvarchar(4000) null,
    c01 nvarchar(4000) null,
    c02 nvarchar(4000) null,
    c03 nvarchar(4000) null,
    c04 nvarchar(4000) null,
    c05 nvarchar(4000) null,
    c06 nvarchar(4000) null,
    c07 nvarchar(4000) null,
    c08 nvarchar(4000) null,
    c09 nvarchar(4000) null,
    c10 nvarchar(4000) null,
    c11 nvarchar(4000) null,
    c12 nvarchar(4000) null,
    c13 nvarchar(4000) null,
    c14 nvarchar(4000) null,
    c15 nvarchar(4000) null,
    c16 nvarchar(4000) null,
    c17 nvarchar(4000) null,
    c18 nvarchar(4000) null,
    c19 nvarchar(4000) null,
    c20 nvarchar(4000) null,
    c21 nvarchar(4000) null,
    c22 nvarchar(4000) null,
    c23 nvarchar(4000) null,
    c24 nvarchar(4000) null,
    c25 nvarchar(4000) null,
    c26 nvarchar(4000) null,
    c27 nvarchar(4000) null,
    c28 nvarchar(4000) null,
    c29 nvarchar(4000) null,
    c30 nvarchar(4000) null,
    c31 nvarchar(4000) null
    )
as
begin
/*
    declare @n int select @n=32
    -- generate table cols
    select '    c'+row+' nvarchar(4000) null,'
    from (
        select right('00'+cast(row as varchar),2) row
        from fn__range(0,@n-1,1)
        ) a

    -- generate vars
    select '    @c'+row+' nvarchar(4000),'
    from (
        select right('00'+cast(row as varchar),2) row
        from fn__range(0,@n-1,1)
        ) a

    -- generate if
    select '    '+
        'if @pos='+row+' begin '+
        'select @c'+right('00'+row,2)+'=@v continue end'
    from (
        select right('00'+cast(row as varchar),2) row
        from fn__range(0,@n-1,1)
        ) a

    -- generate col of select
    select '    @c'+row+','
    from (
        select right('00'+cast(row as varchar),2) row
        from fn__range(0,@n-1,1)
        ) a

    -- generate col of select for rxp
    select '    select @c'+row+'=token from @rr where id='+row
    from (
        select right('00'+cast(row as varchar),2) row
        from fn__range(0,@n-1,1)
        ) a

*/

declare
    @c00 nvarchar(4000),
    @c01 nvarchar(4000),
    @c02 nvarchar(4000),
    @c03 nvarchar(4000),
    @c04 nvarchar(4000),
    @c05 nvarchar(4000),
    @c06 nvarchar(4000),
    @c07 nvarchar(4000),
    @c08 nvarchar(4000),
    @c09 nvarchar(4000),
    @c10 nvarchar(4000),
    @c11 nvarchar(4000),
    @c12 nvarchar(4000),
    @c13 nvarchar(4000),
    @c14 nvarchar(4000),
    @c15 nvarchar(4000),
    @c16 nvarchar(4000),
    @c17 nvarchar(4000),
    @c18 nvarchar(4000),
    @c19 nvarchar(4000),
    @c20 nvarchar(4000),
    @c21 nvarchar(4000),
    @c22 nvarchar(4000),
    @c23 nvarchar(4000),
    @c24 nvarchar(4000),
    @c25 nvarchar(4000),
    @c26 nvarchar(4000),
    @c27 nvarchar(4000),
    @c28 nvarchar(4000),
    @c29 nvarchar(4000),
    @c30 nvarchar(4000),
    @c31 nvarchar(4000)

declare
    @st nvarchar(4000),
    @i int,@j int,@pos int,@l int,
    @step int,@v nvarchar(4000),
    @tmp nvarchar(4000),            -- temporary @v for csv use
    @csv int,                       -- enabled csv management
    @wd nchar(1),                   -- csv word delimiter
    @minimize bit,                  -- reduce multi-sep to one
    @dbg bit,                       -- enable returns of dbg info
    @dsep nvarchar(64),
    @end_declare bit

if @line is null or @sep is null return

-- options
if not @opt is null
    begin
    select @opt='|'+@opt+'|'
    -- comma separated values
    select @csv=charindex('|csv',@opt)
    select @minimize=charindex('|min|',@opt)
    select @dbg=charindex('|dbg|',@opt)
    if @csv>0 select @wd='"',@csv=1
    end
else
    select @minimize=0,@csv=0

--initialize
select @st = ''
select @step = len('.'+@sep+'.')-2
if @sep = '' and @step=0 select @sep = ' ',@step=1

/*
if @minimize=1
    begin
    select @dsep=@sep+@sep
    while charindex(@dsep,@line)>0 select @line=replace(@line,@dsep,@sep)
    -- return
    end
*/

-- if right(@line,@step)!=@sep select @line = @line + @sep
select @j=1,@pos=-1
select @i = charindex(@sep, @line),@l=len(@line+'.')

if @dbg=1
    insert @tbl(c00,c01,c02,c03,c04,c05,c06)
    select '@line','@i','@j','@step','@sep','@v','@l'


while (@j<@l)
    begin

    select @v=substring(@line, @j, @i - @j)

    if @dbg=1
        insert @tbl(c00,c01,c02,c03,c04,c05,c06)
        select @line, @i,@j,@step,@sep,@v,@l

    -- skip multi-separators
    if @minimize=1
        while @i<@l and substring(@line,@i+@step,@step)=@sep
            select @i=@i+@step

    select @j=@i+@step

    /*
        select * from fn__str_words(
            '   first name     last name   age  4','  ',
           --1234567890123456789012345678901234567890
           --  0          1   1         2 3   3
            'min|dbg'
        )
        select * from fn__str_words(
            '   first name     last name   age  4','  ',
            'dbg'
        )
    */

    select @i = charindex(@sep, @line,@j)
    if @i=0 select @i=@l

    if @csv=0
        select @pos=@pos+1
    else
        begin

        if @v=@wd
            begin
            if @tmp is null
                select @tmp=@wd+@sep,@v=null
            else
                select @v=@tmp+@wd,@tmp=null
            end

        if not @v is null
            begin
            if left(@v,1)=@wd and right(@v,1)=@wd
                select @pos=@pos+1,@v=replace(substring(@v,2,len(@v)-2),@wd+@wd,@wd)
            else
                begin
                if left(@v,1)!=@wd and @tmp is null
                    select @pos=@pos+1
                else
                    begin
                    if right(@v,1)=@wd
                        select
                            @v=replace(
                                    substring(@tmp+@v,2,len(@tmp)+len(@v)-2),
                                    @wd+@wd,@wd
                                    ),
                            @pos=@pos+1,
                            @tmp=null
                    else
                        select @tmp=isnull(@tmp,'')+@v+@sep,@v=null
                    end
                end -- half value
            end -- if @v
        end -- csv

    if not @v is null
        begin
        if @pos=00 begin select @c00=@v continue end
        if @pos=01 begin select @c01=@v continue end
        if @pos=02 begin select @c02=@v continue end
        if @pos=03 begin select @c03=@v continue end
        if @pos=04 begin select @c04=@v continue end
        if @pos=05 begin select @c05=@v continue end
        if @pos=06 begin select @c06=@v continue end
        if @pos=07 begin select @c07=@v continue end
        if @pos=08 begin select @c08=@v continue end
        if @pos=09 begin select @c09=@v continue end
        if @pos=10 begin select @c10=@v continue end
        if @pos=11 begin select @c11=@v continue end
        if @pos=12 begin select @c12=@v continue end
        if @pos=13 begin select @c13=@v continue end
        if @pos=14 begin select @c14=@v continue end
        if @pos=15 begin select @c15=@v continue end
        if @pos=16 begin select @c16=@v continue end
        if @pos=17 begin select @c17=@v continue end
        if @pos=18 begin select @c18=@v continue end
        if @pos=19 begin select @c19=@v continue end
        if @pos=20 begin select @c20=@v continue end
        if @pos=21 begin select @c21=@v continue end
        if @pos=22 begin select @c22=@v continue end
        if @pos=23 begin select @c23=@v continue end
        if @pos=24 begin select @c24=@v continue end
        if @pos=25 begin select @c25=@v continue end
        if @pos=26 begin select @c26=@v continue end
        if @pos=27 begin select @c27=@v continue end
        if @pos=28 begin select @c28=@v continue end
        if @pos=29 begin select @c29=@v continue end
        if @pos=30 begin select @c30=@v continue end
        if @pos=31 begin select @c31=@v continue end
        end

    end -- word loop

insert @tbl
select
    @c00,
    @c01,
    @c02,
    @c03,
    @c04,
    @c05,
    @c06,
    @c07,
    @c08,
    @c09,
    @c10,
    @c11,
    @c12,
    @c13,
    @c14,
    @c15,
    @c16,
    @c17,
    @c18,
    @c19,
    @c20,
    @c21,
    @c22,
    @c23,
    @c24,
    @c25,
    @c26,
    @c27,
    @c28,
    @c29,
    @c30,
    @c31
return
end -- fn__str_words