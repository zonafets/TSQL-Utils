/*  leave this
    l:see LICENSE file
    g:obj,utility
    v:120403\s.zaglio: added to group utility
    v:120125\s.zaglio: return null when unk
    v:110323\s.zaglio: convert mnemonic flags to numeric
    t:select dbo.fn__flags('ABCD'),dbo.fn__flags('E')
    t:
        select
            dbo.fn__flags('P'),dbo.fn__hex(dbo.fn__flags('P')),
            dbo.fn__flags('OP'),dbo.fn__hex(dbo.fn__flags('OP')),
            dbo.fn__flags('AP'),dbo.fn__hex(dbo.fn__flags('AP'))
    t:select dbo.fn__flags('q') -- error
    t:declare @s smallint select @s=32768 select 0xffff-@s
*/
CREATE function fn__flags(@flags nvarchar(16))
returns smallint
as
begin
declare @ret smallint,@i int,@l int
if isnumeric(@flags)=1 return convert(smallint,@flags)
select @ret=0,@i=1,@l=len(@flags)
while (@i<=@l)
    begin
    select @ret=
        case substring(@flags,@i,1)
        when 'a' then @ret|1        -- 1
        when 'b' then @ret|2        -- 2
        when 'c' then @ret|4        -- 3
        when 'd' then @ret|8        -- 4
        when 'e' then @ret|16
        when 'f' then @ret|32
        when 'g' then @ret|64
        when 'h' then @ret|128      -- 8
        when 'i' then @ret|256
        when 'j' then @ret|512
        when 'k' then @ret|1024
        when 'l' then @ret|2048
        when 'm' then @ret|4096
        when 'n' then @ret|8192
        when 'o' then @ret|16384
        when 'p' then ~@ret        -- 16
        else null
        end
    select @i=@i+1
    end
return @ret
end -- fn__flags