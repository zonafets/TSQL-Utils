/*  leave this
    l:see LICENSE file
    g:utility
    v:110527\S.Zaglio: a remake (the older will be a str generator)
    v:091018\s.zaglio: added scramble for numbers or chars only and a bug on len
    v:081218\S.Zaglio: scramble data
    c:remake of previous fun with same name
    t:
        select  dbo.fn__str_scramble('stefano zaglio',
                                     rand(checksum(newid()))
                                    ) as [stefano zaglio],
                dbo.fn__str_scramble('stefano zaglio',
                                     rand(checksum(newid()))
                                    ) as [stefano zaglio],
                dbo.fn__str_scramble('zaglio stefano',
                                     rand(checksum(newid()))
                                    ) as [zaglio stefano],
                dbo.fn__str_scramble('zaglio stefania',
                                     rand(checksum(newid()))
                                    ) as [zaglio stefania]
*/
CREATE function fn__str_scramble(@data nvarchar(4000),@rand real)
returns nvarchar(4000)
as
begin
-- declare @data sysname select @data='stefano zaglio'
declare
    @len int,
    @i int,  -- index
    @p int,  -- random position,
    @n int,
    @c nvarchar(1),
    @s int
-- declare @len int select @len=10 -- declare @len int

declare @rnd table(id int identity,r int)
/*
    select top 32
        'union all select '+convert(sysname,(RAND(CHECKSUM(NEWID()))))+'*@len+1'
    from sysobjects

    SELECT CAST(CAST(newid() AS binary(1)) AS int)/256.0

    select RAND(CHECKSUM(NEWID()))

    DECLARE @maxRandomValue TINYINT, @minRandomValue TINYINT
    select @maxRandomValue = 100,  @minRandomValue = 0
    SELECT CAST(((@maxRandomValue + 1) - @minRandomValue)
        * RAND(CHECKSUM(NEWID())) + @minRandomValue AS TINYINT) AS 'randomNumber'
*/
select @len=len(@data),@i=1,@n=32,@s=20*@rand

insert @rnd(r)
-- declare @len int select @len=10
          select 0.648147*@len+1
union all select 0.49276*@len+1
union all select 0.760752*@len+1
union all select 0.92745*@len+1
union all select 0.550134*@len+1
union all select 0.327785*@len+1
union all select 0.223983*@len+1
union all select 0.602884*@len+1
union all select 0.611201*@len+1
union all select 0.920175*@len+1
union all select 0.626131*@len+1
union all select 0.666639*@len+1
union all select 0.490854*@len+1
union all select 0.714348*@len+1
union all select 0.931448*@len+1
union all select 0.202067*@len+1
union all select 0.136386*@len+1
union all select 0.400647*@len+1
union all select 0.33078*@len+1
union all select 0.169345*@len+1
union all select 0.227007*@len+1
union all select 0.293043*@len+1
union all select 0.916565*@len+1
union all select 0.816953*@len+1
union all select 0.923834*@len+1
union all select 0.873596*@len+1
union all select 0.379763*@len+1
union all select 0.857231*@len+1
union all select 0.468347*@len+1
union all select 0.351739*@len+1
union all select 0.445449*@len+1
union all select 0.860574*@len+1
-- select * from @rnd

while (@i<=@len)
    begin
    select
        @c=substring(@data,@i,1),
        @p=isnull((select r from @rnd where id=(@i+@s)%@n),1),
        @data=stuff(@data,@i,1,substring(@data,@p,1)),
        @data=stuff(@data,@p,1,@c),
        @i=@i+1
    -- select @c c,@p p,@data data,@i i,@n n
    end
return substring('abcdefghijklmnopqrstuvwxyz',@s,1)+@data
end -- fn__str_scramble