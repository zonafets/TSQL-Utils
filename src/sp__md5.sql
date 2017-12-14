/*  leave this
    l:see LICENSE file
    g:utility
    v:110429\s.zaglio: specified for #src
    v:080808\S.Zaglio: calculate hash md5 of multiple strings
*/
CREATE proc sp__md5
    @hash binary(16) =null out,
    @skip int=null
as
begin
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0

if object_id('tempdb..#src') is null goto help

declare
    @buffer varbinary(64), @counter int,@line nvarchar(4000),
    @a bigint, @b bigint, @c bigint, @d bigint,@len int

select
    @skip=isnull(@skip,0),
    @a = 0x67452301, @b = 0xefcdab89, @c = 0x98badcfe, @d = 0x10325476

declare cs cursor local for
    select isnull(line,'')
    from #src
    order by lno
open cs
while 1=1
    begin
    fetch next from cs into @line
    if @@fetch_status!=0 break
    if @skip>0
        begin
        select @skip=@skip-1
        continue
        end

    select @counter=1,@hash=0,@len=datalength(@line)

    -- exec sp__printf '@l=%d, @h=%d, @line=%s',@len,@hash,@line

    while @counter<=@len or @len=0
        begin

        select @buffer=substring(cast( @line as varbinary(8000) ),@counter,55)
        select @counter=@counter+55


        select @buffer = @buffer
                     + 0x80 +  cast( replicate( 0x00, 64 - 8 - 1 - datalength( @buffer )  ) as varbinary(64) )
                     + cast( (datalength( @buffer )*8 & 0xFF) as binary(1) )
                     + cast( (datalength( @buffer )*8 & 0xFF00)/256 as binary(1) )
                     + 0x0

        select @a = dbo.fn__md5_r(0, @a, @b, @c, @d, cast( reverse( substring( @buffer, 00 + 1, 4 ) ) as binary(4) ), 128,    0xd76aa478 )
        select @d = dbo.fn__md5_r(0, @d, @a, @b, @c, cast( reverse( substring( @buffer, 04 + 1, 4 ) ) as binary(4) ), 4096,   0xe8c7b756 )
        select @c = dbo.fn__md5_r(0, @c, @d, @a, @b, cast( reverse( substring( @buffer, 08 + 1, 4 ) ) as binary(4) ), 131072, 0x242070db )
        select @b = dbo.fn__md5_r(0, @b, @c, @d, @a, cast( reverse( substring( @buffer, 12 + 1, 4 ) ) as binary(4) ), 4194304,0xc1bdceee )

        select @a = dbo.fn__md5_r(0, @a, @b, @c, @d, cast( reverse( substring( @buffer, 16 + 1, 4 ) ) as binary(4) ), 128,    0xf57c0faf )
        select @d = dbo.fn__md5_r(0, @d, @a, @b, @c, cast( reverse( substring( @buffer, 20 + 1, 4 ) ) as binary(4) ), 4096,   0x4787c62a )
        select @c = dbo.fn__md5_r(0, @c, @d, @a, @b, cast( reverse( substring( @buffer, 24 + 1, 4 ) ) as binary(4) ), 131072, 0xa8304613 )
        select @b = dbo.fn__md5_r(0, @b, @c, @d, @a, cast( reverse( substring( @buffer, 28 + 1, 4 ) ) as binary(4) ), 4194304,0xfd469501 )

        select @a = dbo.fn__md5_r(0, @a, @b, @c, @d, cast( reverse( substring( @buffer, 32 + 1, 4 ) ) as binary(4) ), 128,    0x698098d8 )
        select @d = dbo.fn__md5_r(0, @d, @a, @b, @c, cast( reverse( substring( @buffer, 36 + 1, 4 ) ) as binary(4) ), 4096,   0x8b44f7af )
        select @c = dbo.fn__md5_r(0, @c, @d, @a, @b, cast( reverse( substring( @buffer, 40 + 1, 4 ) ) as binary(4) ), 131072, 0xffff5bb1 )
        select @b = dbo.fn__md5_r(0, @b, @c, @d, @a, cast( reverse( substring( @buffer, 44 + 1, 4 ) ) as binary(4) ), 4194304,0x895cd7be )

        select @a = dbo.fn__md5_r(0, @a, @b, @c, @d, cast( reverse( substring( @buffer, 48 + 1, 4 ) ) as binary(4) ), 128,    0x6b901122 )
        select @d = dbo.fn__md5_r(0, @d, @a, @b, @c, cast( reverse( substring( @buffer, 52 + 1, 4 ) ) as binary(4) ), 4096,   0xfd987193 )
        select @c = dbo.fn__md5_r(0, @c, @d, @a, @b, cast( reverse( substring( @buffer, 56 + 1, 4 ) ) as binary(4) ), 131072, 0xa679438e )
        select @b = dbo.fn__md5_r(0, @b, @c, @d, @a, cast( reverse( substring( @buffer, 60 + 1, 4 ) ) as binary(4) ), 4194304,0x49b40821 )

        select @a = dbo.fn__md5_r(1, @a, @b, @c, @d, cast( reverse( substring( @buffer, 04 + 1, 4 ) ) as binary(4) ), 32,     0xf61e2562 )
        select @d = dbo.fn__md5_r(1, @d, @a, @b, @c, cast( reverse( substring( @buffer, 24 + 1, 4 ) ) as binary(4) ), 512,    0xc040b340 )
        select @c = dbo.fn__md5_r(1, @c, @d, @a, @b, cast( reverse( substring( @buffer, 44 + 1, 4 ) ) as binary(4) ), 16384,  0x265e5a51 )
        select @b = dbo.fn__md5_r(1, @b, @c, @d, @a, cast( reverse( substring( @buffer, 00 + 1, 4 ) ) as binary(4) ), 1048576,0xe9b6c7aa )

        select @a = dbo.fn__md5_r(1, @a, @b, @c, @d, cast( reverse( substring( @buffer, 20 + 1, 4 ) ) as binary(4) ), 32,     0xd62f105d )
        select @d = dbo.fn__md5_r(1, @d, @a, @b, @c, cast( reverse( substring( @buffer, 40 + 1, 4 ) ) as binary(4) ), 512,    0x2441453  )
        select @c = dbo.fn__md5_r(1, @c, @d, @a, @b, cast( reverse( substring( @buffer, 60 + 1, 4 ) ) as binary(4) ), 16384,  0xd8a1e681 )
        select @b = dbo.fn__md5_r(1, @b, @c, @d, @a, cast( reverse( substring( @buffer, 16 + 1, 4 ) ) as binary(4) ), 1048576,0xe7d3fbc8 )

        select @a = dbo.fn__md5_r(1, @a, @b, @c, @d, cast( reverse( substring( @buffer, 36 + 1, 4 ) ) as binary(4) ), 32,     0x21e1cde6 )
        select @d = dbo.fn__md5_r(1, @d, @a, @b, @c, cast( reverse( substring( @buffer, 56 + 1, 4 ) ) as binary(4) ), 512,    0xc33707d6 )
        select @c = dbo.fn__md5_r(1, @c, @d, @a, @b, cast( reverse( substring( @buffer, 12 + 1, 4 ) ) as binary(4) ), 16384,  0xf4d50d87 )
        select @b = dbo.fn__md5_r(1, @b, @c, @d, @a, cast( reverse( substring( @buffer, 32 + 1, 4 ) ) as binary(4) ), 1048576,0x455a14ed )

        select @a = dbo.fn__md5_r(1, @a, @b, @c, @d, cast( reverse( substring( @buffer, 52 + 1, 4 ) ) as binary(4) ), 32,     0xa9e3e905 )
        select @d = dbo.fn__md5_r(1, @d, @a, @b, @c, cast( reverse( substring( @buffer, 08 + 1, 4 ) ) as binary(4) ), 512,    0xfcefa3f8 )
        select @c = dbo.fn__md5_r(1, @c, @d, @a, @b, cast( reverse( substring( @buffer, 28 + 1, 4 ) ) as binary(4) ), 16384,  0x676f02d9 )
        select @b = dbo.fn__md5_r(1, @b, @c, @d, @a, cast( reverse( substring( @buffer, 48 + 1, 4 ) ) as binary(4) ), 1048576,0x8d2a4c8a )


        select @a = dbo.fn__md5_r(2, @a, @b, @c, @d, cast( reverse( substring( @buffer, 20 + 1, 4 ) ) as binary(4) ), 16,     0xfffa3942 )
        select @d = dbo.fn__md5_r(2, @d, @a, @b, @c, cast( reverse( substring( @buffer, 32 + 1, 4 ) ) as binary(4) ), 2048,   0x8771f681 )
        select @c = dbo.fn__md5_r(2, @c, @d, @a, @b, cast( reverse( substring( @buffer, 44 + 1, 4 ) ) as binary(4) ), 65536,  0x6d9d6122 )
        select @b = dbo.fn__md5_r(2, @b, @c, @d, @a, cast( reverse( substring( @buffer, 56 + 1, 4 ) ) as binary(4) ), 8388608,0xfde5380c )

        select @a = dbo.fn__md5_r(2, @a, @b, @c, @d, cast( reverse( substring( @buffer, 04 + 1, 4 ) ) as binary(4) ), 16,     0xa4beea44 )
        select @d = dbo.fn__md5_r(2, @d, @a, @b, @c, cast( reverse( substring( @buffer, 16 + 1, 4 ) ) as binary(4) ), 2048,   0x4bdecfa9 )
        select @c = dbo.fn__md5_r(2, @c, @d, @a, @b, cast( reverse( substring( @buffer, 28 + 1, 4 ) ) as binary(4) ), 65536,  0xf6bb4b60 )
        select @b = dbo.fn__md5_r(2, @b, @c, @d, @a, cast( reverse( substring( @buffer, 40 + 1, 4 ) ) as binary(4) ), 8388608,0xbebfbc70 )

        select @a = dbo.fn__md5_r(2, @a, @b, @c, @d, cast( reverse( substring( @buffer, 52 + 1, 4 ) ) as binary(4) ), 16,     0x289b7ec6 )
        select @d = dbo.fn__md5_r(2, @d, @a, @b, @c, cast( reverse( substring( @buffer, 00 + 1, 4 ) ) as binary(4) ), 2048,   0xeaa127fa )
        select @c = dbo.fn__md5_r(2, @c, @d, @a, @b, cast( reverse( substring( @buffer, 12 + 1, 4 ) ) as binary(4) ), 65536,  0xd4ef3085 )
        select @b = dbo.fn__md5_r(2, @b, @c, @d, @a, cast( reverse( substring( @buffer, 24 + 1, 4 ) ) as binary(4) ), 8388608,0x04881d05 )

        select @a = dbo.fn__md5_r(2, @a, @b, @c, @d, cast( reverse( substring( @buffer, 36 + 1, 4 ) ) as binary(4) ), 16,     0xd9d4d039 )
        select @d = dbo.fn__md5_r(2, @d, @a, @b, @c, cast( reverse( substring( @buffer, 48 + 1, 4 ) ) as binary(4) ), 2048,   0xe6db99e5 )
        select @c = dbo.fn__md5_r(2, @c, @d, @a, @b, cast( reverse( substring( @buffer, 60 + 1, 4 ) ) as binary(4) ), 65536,  0x1fa27cf8 )
        select @b = dbo.fn__md5_r(2, @b, @c, @d, @a, cast( reverse( substring( @buffer, 08 + 1, 4 ) ) as binary(4) ), 8388608,0xc4ac5665 )


        select @a = dbo.fn__md5_r(3, @a, @b, @c, @d, cast( reverse( substring( @buffer, 00 + 1, 4 ) ) as binary(4) ), 64,     0xf4292244 )
        select @d = dbo.fn__md5_r(3, @d, @a, @b, @c, cast( reverse( substring( @buffer, 28 + 1, 4 ) ) as binary(4) ), 1024,   0x432aff97 )
        select @c = dbo.fn__md5_r(3, @c, @d, @a, @b, cast( reverse( substring( @buffer, 56 + 1, 4 ) ) as binary(4) ), 32768,  0xab9423a7 )
        select @b = dbo.fn__md5_r(3, @b, @c, @d, @a, cast( reverse( substring( @buffer, 20 + 1, 4 ) ) as binary(4) ), 2097152,0xfc93a039 )

        select @a = dbo.fn__md5_r(3, @a, @b, @c, @d, cast( reverse( substring( @buffer, 48 + 1, 4 ) ) as binary(4) ), 64,     0x655b59c3 )
        select @d = dbo.fn__md5_r(3, @d, @a, @b, @c, cast( reverse( substring( @buffer, 12 + 1, 4 ) ) as binary(4) ), 1024,   0x8f0ccc92 )
        select @c = dbo.fn__md5_r(3, @c, @d, @a, @b, cast( reverse( substring( @buffer, 40 + 1, 4 ) ) as binary(4) ), 32768,  0xffeff47d )
        select @b = dbo.fn__md5_r(3, @b, @c, @d, @a, cast( reverse( substring( @buffer, 04 + 1, 4 ) ) as binary(4) ), 2097152,0x85845dd1 )

        select @a = dbo.fn__md5_r(3, @a, @b, @c, @d, cast( reverse( substring( @buffer, 32 + 1, 4 ) ) as binary(4) ), 64,     0x6fa87e4f )
        select @d = dbo.fn__md5_r(3, @d, @a, @b, @c, cast( reverse( substring( @buffer, 60 + 1, 4 ) ) as binary(4) ), 1024,   0xfe2ce6e0 )
        select @c = dbo.fn__md5_r(3, @c, @d, @a, @b, cast( reverse( substring( @buffer, 24 + 1, 4 ) ) as binary(4) ), 32768,  0xa3014314 )
        select @b = dbo.fn__md5_r(3, @b, @c, @d, @a, cast( reverse( substring( @buffer, 52 + 1, 4 ) ) as binary(4) ), 2097152,0x4e0811a1 )

        select @a = dbo.fn__md5_r(3, @a, @b, @c, @d, cast( reverse( substring( @buffer, 16 + 1, 4 ) ) as binary(4) ), 64,     0xf7537e82 )
        select @d = dbo.fn__md5_r(3, @d, @a, @b, @c, cast( reverse( substring( @buffer, 44 + 1, 4 ) ) as binary(4) ), 1024,   0xbd3af235 )
        select @c = dbo.fn__md5_r(3, @c, @d, @a, @b, cast( reverse( substring( @buffer, 08 + 1, 4 ) ) as binary(4) ), 32768,  0x2ad7d2bb )
        select @b = dbo.fn__md5_r(3, @b, @c, @d, @a, cast( reverse( substring( @buffer, 36 + 1, 4 ) ) as binary(4) ), 2097152,0xeb86d391 )

        -- exec sp__printf '@c=%d, a=%d, b=%d, c=%d, d=%d',@counter,@a,@b,@c,@d
        if @len=0 break

        end -- while counter

    end -- while 1=1

    close cs
    deallocate cs

    select @hash = cast( reverse( cast( ( @a + 0x67452301 ) as binary(4) ) )
                  + reverse( cast( ( @b + 0xefcdab89 ) as binary(4) ) )
                  + reverse( cast( ( @c + 0x98badcfe ) as binary(4) ) )
                  + reverse( cast( ( @d + 0x10325476 ) as binary(4) ) )
                  as binary(16) )


goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    calculate hash for table #src
    (for single strings, use fn__md5)

Parameters
    @skip   skin @skip (header)lines before init to calculate

Examples
    declare @hash binary(16)
    create table #src(lno int identity,line nvarchar(4000))
    insert #src(line) select ''Test line 1''
    insert #src(line) select ''Test line 2''
    insert #src(line) select ''''
    insert #src(line) select null
    exec sp__md5 @hash out      print @hash -- 0xC9AA7200A10304DD76F4C5B75F79C41C
    exec sp__md5 @hash out,1    print @hash -- 0x4F67A2ECFC0E84DB22585F13AAC9F8E6
    exec sp__md5 @hash out,2    print @hash -- 0xD4588FC69881818B29010299103452BF
    exec sp__md5 @hash out,3    print @hash -- 0xD41D8CD98F00B204E9800998ECF8427E
    drop table #src
'
ret:
return @ret
end -- sp__md5