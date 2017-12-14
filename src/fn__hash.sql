/*  leave this
    l:see LICENSE file
    g:utility
    k:hash,md5,sha1,hashbytes,limits,8000,chars,len
    v:130707\s.zaglio: bypasses the limit of 8000 bytes of MS hashbytes
    c:originally from fn_hashbytesMAX of Brandon Galderisi
    t:
        select dbo.fn__hash(cast('test' as varbinary(max)),'md5')
        -- 0x8706F8479081122D32400F2E681D26C4
        select dbo.fn__hash(cast(N'test' as varbinary(max)),'md5')
        -- 0x2BC0BA5B64772F46C3876E043FBF6775
    t:select dbo.fn__script_sign('fn__hash',default)
*/
CREATE function dbo.fn__hash(
    @data varbinary(max),
    @algo varchar(10)
    )
returns varbinary(8000)
as
begin
declare
    @concat varchar(max),@hash varbinary(8000)

;with a as (select 1 as n union all select 1) -- 2
     ,b as (select 1 as n from a ,a a1)       -- 4
     ,c as (select 1 as n from b ,b b1)       -- 16
     ,d as (select 1 as n from c ,c c1)       -- 256
     ,e as (select 1 as n from d ,d d1)       -- 65,536
     ,f as (select 1 as n from e ,e e1)       -- 4,294,967,296=17+trillion chrs
     ,factored as (select row_number() over (order by n) rn from f)
     ,factors as (select rn,(rn*4000)+1 factor from factored)

select @concat = cast((
select right(sys.fn_varbintohexstr
             (
             hashbytes(@algo, substring(@data, factor - 4000, 4000))
             )
          , 40) + ''
from factors
where rn <= ceiling(datalength(@data)/(4000.0))
for xml path('')
) as nvarchar(max))

if len(@concat)>8000
    select @hash=dbo.fn__hash(cast(@concat as varbinary(max)),@algo)
else
    select @hash=hashbytes(@algo,@concat)

return @hash
end -- fn__hash