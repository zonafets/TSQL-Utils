/*  leave this
    l:see LICENSE file
    g:utility
    v:130725,130724\s.zaglio: a bug in particolar condition from sp__elapsed
    v:130614\s.zaglio: added %x and varchar max
    v:110429\s.zaglio: added special case for *binary
    v:100918\s.zaglio: again better print on small float and real
    v:100914\s.zaglio: better precision on datetime,real, etc.
    v:081021\S.Zaglio: corrected bad replace in case @p? contains %s
    v:080925\S.Zaglio: replace xp_printf because truncate strings to +/-1000 chars
    v:080515\S.Zaglio: as sp__printf but only for functions debug, don't print
    t:sp__printf_test @opt='run',@dbg=1
    t:print dbo.fn__printf('test (%s)','%drop%',null,null,null,null,null,null,null,null,null)
*/
CREATE function fn__printf(
    @format nvarchar(max),
    @p1 sql_variant=null,
    @p2 sql_variant=null,
    @p3 sql_variant=null,
    @p4 sql_variant=null,
    @p5 sql_variant=null,
    @p6 sql_variant=null,
    @p7 sql_variant=null,
    @p8 sql_variant=null,
    @p9 sql_variant=null,
    @p0 sql_variant=null)
returns nvarchar(max)
as
begin
declare
    @p sql_variant,@s nvarchar(4000),
    @crlf nvarchar(2),@tab nvarchar(2),
    @i int,@n int,@type char,@ln int

select @crlf=crlf,@tab=tab,@n=1 from fn__sym()
select
    @p1=isnull(@p1,'(null)'),   @p2=isnull(@p2,'(null)'),
    @p3=isnull(@p3,'(null)'),   @p4=isnull(@p4,'(null)'),
    @p5=isnull(@p5,'(null)'),   @p6=isnull(@p6,'(null)'),
    @p7=isnull(@p7,'(null)'),   @p8=isnull(@p8,'(null)'),
    @p9=isnull(@p9,'(null)'),   @p0=isnull(@p0,'(null)')

select @format=replace(@format,'%d','%s')
select @format=replace(@format,'\n',@crlf)
select @format=replace(@format,'\t',@tab)

select @i=charindex('%',@format),@ln=len(@format)
while (@i>0)
    begin
    select @type=substring(@format,@i+1,1)
    if @type in ('s','x','d')
        begin
        select @p=(case @n
            when 1 then @p1 when 2 then @p2 when 3 then @p3 when 4 then @p4 when 5 then @p5
            when 6 then @p6 when 7 then @p7 when 8 then @p8 when 9 then @p9 when 10 then @p0 end)
        if @type!='x' and sql_variant_property(@p,'BaseType') in ('datetime','smalldatetime')
            select @s=convert(nvarchar(4000),@p,126)
        else
            if @type!='x' and sql_variant_property(@p,'BaseType') in ('real','float')
                begin
                select @s=convert(nvarchar(4000),@p,0)
                if charindex('e-',@s)>0 select @s=convert(nvarchar(4000),@p,1)
                if charindex('e-',@s)>0 select @s=convert(nvarchar(4000),@p,2)
                end
            else
            if sql_variant_property(@p,'BaseType') in ('binary','varbinary')
            or @type='x'
                select @s=sys.fn_varbintohexstr(convert(varbinary(8000),@p))
        else
            select @s=convert(nvarchar(4000),@p)

        select @format=left(@format,@i-1)+@s+substring(@format,@i+2,@ln)
        select @i=@i+len(@s)
        select @n=@n+1
        end
    else
        if @type='%'
            select @format=left(@format,@i)+substring(@format,@i+2,@ln),
                   @i=@i+1
        else
            select @i=@i+1

        select @i=charindex('%',@format,@i)
    end -- while
-- the xp_sprintf truncate to less than 4000 chars
-- exec master..xp_sprintf @format out,@format,@p1,@p2,@p3,@p4,@p5,@p6,@p7,@p8,@p9,@p0
return @format
end -- fn__printf