/*  leave this
    l:see LICENSE file
    g:utility
    v:110627\s.zaglio:convert hex to int
    t:print dbo.fn__hex2int('0x80000005') -- -2147483643
    t:print dbo.fn__hex2int('0x8000005')  -- 134217733
*/
CREATE function fn__hex2int(@v varchar(16))
returns int
as
begin
if left(@v,2)!='0x' return null
else select @v=upper(substring(@v,3,8))
-- declare @v varchar(10) select @v='80000005'
declare @vc as varchar(4),@i int,@cl char,@ch char
select @vc='',@i=len(@v)
if @i%2=1 select @v='0'+@v,@i=@i+1
-- exec sp__printf '@i=%d @v=%s',@i,@v
while (@i>0)
    begin
    select
        @ch=substring(@v,@i-1,1),@cl=substring(@v,@i,1),
        @vc=char(
                case
                when @cl between '0' and '9' then ascii(@cl)-48
                when @cl between 'A' and 'F' then ascii(@cl)-55
                end
                +
                case
                when @ch between '0' and '9' then (ascii(@ch)-48)*16
                when @ch between 'A' and 'F' then (ascii(@ch)-55)*16
                end
            )+@vc,
        @i=@i-2
    -- exec sp__printf '@cl=%s @ch=%s @i=%d @vc=%s',@cl,@ch,@i,@vc
    end
return cast(cast(@vc as binary(4)) as int)
end -- fn__hex2int