/*  leave this
    l:see LICENSE file
    g:utility
    v:090210\S.Zaglio: optimized
    v:080811\S.Zaglio: managed nulls
    v:080101\S.Zaglio: update on change of fn__at
    v:080730\S.Zaglio: mix words of two groups separated by pipe withour repeatitions
    t:print dbo.fn__str_mix('a|b|c','a|c|d','|') -->'a|b|c|d'
    t:print dbo.fn__str_mix('d|b|c|a','a|c|b','|') -->'d|b|c|a'
    t:print dbo.fn__str_mix('','a|c|d','|') -->'a|b|d'
    t:print dbo.fn__str_mix('a|b|c','','|') -->'a|b|c'
    c:very slow. Must be optimized
*/
CREATE  function fn__str_mix(@grp1 nvarchar(4000), @grp2 nvarchar(4000),@sep nvarchar(32)='|')
returns nvarchar(4000)
as
begin
declare @r nvarchar(4000) set @r=''
declare @t table(pos int identity(1,1), token nvarchar(4000))
if @grp1!='' and @grp2!=''
    insert into @t select token from dbo.fn__str_table(@grp2,@sep)
    union select token from dbo.fn__str_table(@grp1,@sep)
else
    begin
    if @grp1='' return @grp2 else return @grp1
    end
declare @n int,@i int
select @n=count(*) from @t
set @i=2
select @r=token from @t where pos=1
while (@i<=@n) begin select @r=@r+@sep+token from @t where pos=@i set @i=@i+1 end
return @r
/*
declare @n int
declare @m int
declare @i int
declare @token sysname
if @grp1 is null return @grp2
if @grp2 is null return @grp1

set @n=dbo.fn__str_count(@grp2,@sep)
set @m=dbo.fn__str_count(@grp2,@sep)
set @i=1
if @n>@m
    while (@i<=@n) begin
        set @token=dbo.fn__str_at(@grp1,@sep,@i)
        if dbo.fn__at(@token,@grp2,@sep)=0 begin
            if @grp2<>'' set @grp2=@grp2+@sep
            set @grp2=@grp2+@token
        end -- if
        set @i=@i+1
    end -- while
else
    while (@i<=@m) begin
        set @token=dbo.fn__str_at(@grp2,@sep,@i)
        if dbo.fn__at(@token,@grp1,@sep)=0 begin
            if @grp1<>'' set @grp1=@grp1+@sep
            set @grp1=@grp1+@token
        end -- if
        set @i=@i+1
    end -- while

if @n>@m return @grp2
return @grp1
*/
end -- function