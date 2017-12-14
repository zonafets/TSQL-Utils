﻿/*  leave this
    l:see LICENSE file
    g:utility
    v:130901\s.zaglio: correct a bug near unicode>32768
    v:130202\s.zaglio: embedded lookup table, 5 times faster
    d:130202\s.zaglio: fn__crc32_tbl
    v:110315\s.zaglio: @string to ntext
    v:090930\s.zaglio: a bug on the name of tbl
    v:090614\s.zaglio: calculate crc32 of a unicode & non unicode string
    t:
        select
            st,res,dbo.fn__crc32(st) crc,
            case when dbo.fn__crc32(st)=res then 'ok' else 'ko' end st
        from (
            select 'jhon' st,2071226836 res union
            select N'Джон',877079858 union
            select 'j',2137352139 union
            select N'Д',1746534835 union
            select N'�',-842440062
        ) data
    t:
        -- mega test
        declare @v nvarchar(max),@i int
        select @i=10000,@v='start\n'
        while (@i>0) select @v=@v+'01234567890\n',@i=@i-1
        select @v=@v+'end'
        print datalength(@v)        -- 260020
        declare @d datetime select @d=getdate()
        print dbo.fn__crc32(@v)     -- 531861221
        exec sp__elapsed @d,''      -- 440ms
*/
CREATE function [dbo].[fn__crc32](
    @string nvarchar(max)
    )
returns int
as
begin
declare @crc int
declare @u int      -- to containt an unsigned smallint
declare @c tinyint
declare @t tinyint
declare @a int
declare @i int
declare @lookup varbinary(2048)
select @lookup = 0x\
0000000077073096ee0e612c990951ba076dc419706af48fe963a5359e6495a30edb8832\
79dcb8a4e0d5e91e97d2d98809b64c2b7eb17cbde7b82d0790bf1d911db710646ab020f2\
f3b9714884be41de1adad47d6ddde4ebf4d4b55183d385c7136c9856646ba8c0fd62f97a\
8a65c9ec14015c4f63066cd9fa0f3d638d080df53b6e20c84c69105ed56041e4a2677172\
3c03e4d14b04d447d20d85fda50ab56b35b5a8fa42b2986cdbbbc9d6acbcf94032d86ce3\
45df5c75dcd60dcfabd13d5926d930ac51de003ac8d75180bfd0611621b4f4b556b3c423\
cfba9599b8bda50f2802b89e5f058808c60cd9b2b10be9242f6f7c8758684c11c1611dab\
b6662d3d76dc419001db710698d220bcefd5102a71b1858906b6b51f9fbfe4a5e8b8d433\
7807c9a20f00f9349609a88ee10e98187f6a0dbb086d3d2d91646c97e6635c016b6b51f4\
1c6c6162856530d8f262004e6c0695ed1b01a57b8208f4c1f50fc45765b0d9c612b7e950\
8bbeb8eafcb9887c62dd1ddf15da2d498cd37cf3fbd44c654db261583ab551cea3bc0074\
d4bb30e24adfa5413dd895d7a4d1c46dd3d6f4fb4369e96a346ed9fcad678846da60b8d0\
44042d7333031de5aa0a4c5fdd0d7cc95005713c270241aabe0b1010c90c20865768b525\
206f85b3b966d409ce61e49f5edef90e29d9c998b0d09822c7d7a8b459b33d172eb40d81\
b7bd5c3bc0ba6cadedb883209abfb3b603b6e20c74b1d29aead547399dd277af04db2615\
73dc1683e3630b1294643b840d6d6a3e7a6a5aa8e40ecf0b9309ff9d0a00ae277d079eb1\
f00f93448708a3d21e01f2686906c2fef762575d806567cb196c36716e6b06e7fed41b76\
89d32be010da7a5a67dd4accf9b9df6f8ebeeff917b7be4360b08ed5d6d6a3e8a1d1937e\
38d8c2c44fdff252d1bb67f1a6bc57673fb506dd48b2364bd80d2bdaaf0a1b4c36034af6\
41047a60df60efc3a867df55316e8eef4669be79cb61b38cbc66831a256fd2a05268e236\
cc0c7795bb0b4703220216b95505262fc5ba3bbeb2bd0b282bb45a925cb36a04c2d7ffa7\
b5d0cf312cd99e8b5bdeae1d9b64c2b0ec63f226756aa39c026d930a9c0906a9eb0e363f\
720767850500571395bf4a82e2b87a147bb12bae0cb61b3892d28e9be5d5be0d7cdcefb7\
0bdbdf2186d3d2d4f1d4e24268ddb3f81fda836e81be16cdf6b9265b6fb077e118b74777\
88085ae6ff0f6a7066063bca11010b5c8f659efff862ae69616bffd3166ccf45a00ae278\
d70dd2ee4e0483543903b3c2a7672661d06016f74969474d3e6e77dbaed16a4ad9d65adc\
40df0b6637d83bf0a9bcae53debb9ec547b2cf7f30b5ffe9bdbdf21ccabac28a53b39330\
24b4a3a6bad03605cdd7069354de572923d967bfb3667a2ec4614ab85d681b022a6f2b94\
b40bbe37c30c8ea15a05df1b2d02ef8d

select @a=0
select @crc = 0xFFFFFFFF
select @i=1
declare @l int
select @l=datalength(@string)/2

while (@i<=@l)
    begin
    -- select unicode(N'�')/256
    select @u=unicode(substring(@string,@i,1))

    select @c=@u % 256
    select @t=(@crc & 0xff) ^ @c
    select @a=(@crc & 0x7FFFFFFF)/256
    if (@crc & 0x80000000)<>0 select @a=@a | 0x800000
    select @crc=@a ^ substring(@lookup,@t*4+1,4)

    select @c=@u / 256
    if @c!=0 begin -- this keep compatibility with old nvarchar crc32 and also the whole performances
        select @t=(@crc & 0xff) ^ @c
        select @a=(@crc & 0x7FFFFFFF)/256
        if (@crc & 0x80000000)<>0 select @a=@a | 0x800000
        select @crc=@a ^ substring(@lookup,@t*4+1,4)
        end -- zero char
    select @i=@i+1
    end
select @crc= @crc ^ 0xFFFFFFFF
return @crc
end -- [fn__crc32]