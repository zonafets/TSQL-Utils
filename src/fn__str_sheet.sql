/*  leave this
    l:see LICENSE file
    g:utility,util_tkns
    v:131006\s.zaglio: optimized sep reduction
    v:130423\s.zaglio: a bug when @sep are spaces
    v:130201\s.zaglio: added str option
    v:121118\s.zaglio: preparing for group option
    v:120305\s.zaglio: now trim is default and addeded regular
    v:111114\s.zaglio: split a text into table by @sep
    t:
        select *
        from fn__str_sheet('
            first name   last name   11/12/2011   232.43
                first name 1   last name 2    11/12/2011   33.2
            ',
            '  ',
            default,default
        )
    t:
        select *
        from fn__str_sheet('
            id  cod     des
            1   a       desc one
            2   b       desc two
            ',
            '  ',
            default,'regular'
        )
    t:
        select *
        from fn__str_sheet('
            id
            1
            2
            ',
            ' ',
            default,'regular'
        )
    */
CREATE function [dbo].[fn__str_sheet](
    @text nvarchar(max),
    @sep nvarchar(32),
    @sep_row nvarchar(4),
    @opt sysname)
returns @tbl table(
    id int identity,
    c00 sql_variant null,
    c01 sql_variant null,
    c02 sql_variant null,
    c03 sql_variant null,
    c04 sql_variant null,
    c05 sql_variant null,
    c06 sql_variant null,
    c07 sql_variant null,
    c08 sql_variant null,
    c09 sql_variant null,
    c10 sql_variant null
    )
as
begin
declare
    @c00 sql_variant,@c01 sql_variant,@c02 sql_variant,@c03 sql_variant,
    @c04 sql_variant,@c05 sql_variant,@c06 sql_variant,@c07 sql_variant,
    @c08 sql_variant,@c09 sql_variant,@c10 sql_variant,
    @c00o sql_variant,@c01o sql_variant,@c02o sql_variant,@c03o sql_variant,
    @c04o sql_variant,@c05o sql_variant,@c06o sql_variant,@c07o sql_variant,
    @c08o sql_variant,@c09o sql_variant
declare
    @p00 int,@p01 int,@p02 int,@p03 int,
    @p04 int,@p05 int,@p06 int,@p07 int,
    @p08 int,@p09 int,@p10 int
declare
    @st nvarchar(4000),@line nvarchar(4000),
    @i int,@j int,@pos int,@l int,
    @step int,@v sql_variant,
    @rpt char(1),           -- 1st char of separator that can repeat
    @lrpt int,              -- len of repeater (for future expansions)
    @dsc char(2),           -- double separator code
    @dsci char(2)           -- double separator code inverted

declare
    @notrim bit,            -- remove white space before and inside
    @regular bit,           -- columns are regularly columned
    @group bit,             -- group data when prev. cols as equals
    @str bit                -- do not convert numbers anda dates

if @text is null or @sep is null return

if @sep_row is null select @sep_row=crlf from fn__sym()

--initialize
select
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|'),
    @notrim=charindex('|notrim|',@opt),
    @regular=charindex('|regular|',@opt),
    @group=charindex('|regular|',@opt),
    @str=charindex('|str|',@opt)

if @notrim=0 select @dsc=char(17)+char(18),@dsci=char(18)+char(17)

select
    @p00=0,
    @st = '',
    @rpt=left(@sep,1),
    @lrpt=1,
    @step = len('.'+@sep+'.')-2
if @sep = '' and @step=0 select @sep = ' ',@step=1

select @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

declare cs cursor local for
    select
        case @notrim when 1 then token else ltrim(rtrim(token)) end
    from fn__str_table(@text,@sep_row)
    where ltrim(rtrim(token))!=''
    order by pos
open cs
while 1=1
    begin
    fetch next from cs into @line
    if @@fetch_status!=0 break

    -- ============================================================== regular ==
    if @regular=1
        begin
        if charindex(@sep,@line)=0
            select @p00=1,@p01=len(@line)+1
        if @p00=0
            begin
            select @pos=0,@j=1,@l=len(@line)+1,@i=charindex(@sep,@line)
            if @i=0
                select @p00=1,@p01=@l
            else
                while @i!=0
                    begin
                    -- search next col

                    select @i=@i+@step,@pos=@pos+1
                    -- skip multiple separators like spaces
                    while @i<@l and substring(@line,@i,@lrpt)=@rpt select @i=@i+@lrpt
                    -- insert @tbl(c00,c01,c02,c03,c04)
                    -- select @j,@i,@pos,@regular,datalength(@sep)
                    if @pos=1  select @p00=@j,@p01=4000
                    if @pos=2  select @p01=@j,@p02=4000
                    if @pos=3  select @p02=@j,@p03=4000
                    if @pos=4  select @p03=@j,@p04=4000
                    if @pos=5  select @p04=@j,@p05=4000
                    if @pos=6  select @p05=@j,@p06=4000
                    if @pos=7  select @p06=@j,@p07=4000
                    if @pos=8  select @p07=@j,@p08=4000
                    if @pos=9  select @p08=@j,@p09=4000
                    if @pos=10 select @p09=@j,@p10=4000
                    select @j=@i,@i=charindex(@sep,@line,@j)
                    if @i=0 and @j<@l select @i=@l
                    end
                -- wend
            end -- header line

        select
            @c00=substring(@line,@p00,@p01-@p00),@c01=substring(@line,@p01,@p02-@p01),
            @c02=substring(@line,@p02,@p03-@p02),@c03=substring(@line,@p03,@p04-@p03),
            @c04=substring(@line,@p04,@p05-@p04),@c05=substring(@line,@p05,@p06-@p05),
            @c06=substring(@line,@p06,@p07-@p06),@c07=substring(@line,@p07,@p08-@p07),
            @c08=substring(@line,@p08,@p09-@p08),@c09=substring(@line,@p09,@p10-@p09),
            @c10=@c10

        end -- regular
    else
        begin
        if @notrim=0
            begin
            /*
            select @st=@sep+@sep
            while charindex(@st,@line)>0
                select @line=replace(@line,@st,@sep)
            */
            select @line=replace(
                            replace(
                                replace(@line,@sep,@dsc),@dsci,''
                                ),@dsc,@sep
                            )
            end

        select @j=1,@pos=0,@line=@line,@l=len(@line)+1
        select @i = charindex(@sep, @line)
        if @i=0 select @i=@l
        select @c00=null,@c01=null,@c02=null,@c03=null,@c04=null,
               @c05=null,@c06=null,@c07=null,@c08=null,@c09=null

        while (@i <> 0)
            begin
            select @st=substring(@line, @j, @i - @j)
            if @notrim=0 select @st=ltrim(rtrim(@st))

            /*  this return an error
            select @v=
                case
                -- when isdate(@st)=1              then convert(datetime,@st)
                when dbo.fn__isnumeric(@st)=1   then convert(int,@st)
                else @st
                end
            */
            -- insert @tbl(c00,c01,c02,c03) select @pos,@i,@j,@st

            select @pos=@pos+1,
                   @j=@i+@step,
                   @i=charindex(@sep, @line,@j)
            if @i=0 and @j<@l select @i=@l

            if @str=1
                select @v=@st
            else
                begin
                if dbo.fn__isnumeric(@st)=1
                    select @v=convert(float,@st)
                else
                    select @v=@st
                end
            if @pos= 1 begin select @c00=@v continue end
            if @pos= 2 begin select @c01=@v continue end
            if @pos= 3 begin select @c02=@v continue end
            if @pos= 4 begin select @c03=@v continue end
            if @pos= 5 begin select @c04=@v continue end
            if @pos= 6 begin select @c05=@v continue end
            if @pos= 7 begin select @c06=@v continue end
            if @pos= 8 begin select @c07=@v continue end
            if @pos= 9 begin select @c08=@v continue end
            if @pos=10 begin select @c09=@v continue end

            end -- while cols

        end -- not regular

        -- store
        insert  @tbl select @c00,@c01,@c02,@c03,@c04,@c05,@c06,@c07,@c08,@c09,@c10
        select  @c00=@c00o,@c01=@c01o,@c02=@c02o,@c03=@c03o,@c04=@c04o,
                @c05=@c05o,@c06=@c06o,@c07=@c07o,@c08=@c08o,@c09=@c09o,@c10=@c10

    end -- while of cursor
close cs
deallocate cs

return
end -- fn__str_sheet