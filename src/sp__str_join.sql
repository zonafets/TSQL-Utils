/*  leave this
    l:see LICENSE file
    g:utility
    v:081114\S.Zaglio: join strings with a @separator. PArameters must not null
    t:
        begin
        declare @s nvarchar(4000)
        exec sp__str_join @s out,'|','1','a','2','b',@test=1
        exec sp__str_join @s out,'|','c','1','2','b',@test=1 -- test auto resets
        exec sp__str_join @s out,'|',@s,'d','3','4','e',@test=1 -- test keep
        end
*/
CREATE  proc sp__str_join
    @sentence nvarchar(4000) out,
    @sep nvarchar(32),
    @v1 sql_variant,
    @v2 sql_Variant=null,
    @v3 sql_Variant=null,
    @v4 sql_Variant=null,
    @v5 sql_Variant=null,
    @v6 sql_Variant=null,
    @v7 sql_Variant=null,
    @v8 sql_Variant=null,
    @v9 sql_Variant=null,
    @v10 sql_Variant=null,
    @v11 sql_Variant=null,
    @v12 sql_Variant=null,
    @v13 sql_Variant=null,
    @v14 sql_Variant=null,
    @v15 sql_Variant=null,
    @v16 sql_Variant=null,
    @test bit=0
as
begin
declare @n int, @i int
declare @v sql_variant
set @i=1 set @n=16
while (@i<=@n) begin
    if @i=1 set @v=@v1
    if @i=2 set @v=@v2
    if @i=3 set @v=@v3
    if @i=4 set @v=@v4
    if @i=5 set @v=@v5
    if @i=6 set @v=@v6
    if @i=7 set @v=@v7
    if @i=8 set @v=@v8
    if @i=9 set @v=@v9
    if @i=10 set @v=@v10
    if @i=11 set @v=@v11
    if @i=12 set @v=@v12
    if @i=13 set @v=@v13
    if @i=14 set @v=@v14
    if @i=15 set @v=@v15
    if @i=16 set @v=@v16
    if @v is null break
    if @i=1 set @sentence=''
    if @sentence<>'' set @sentence=@sentence+@sep
    set @sentence=@sentence+convert(nvarchar(4000),@v)
    set @i=@i+1
end -- while
if @test=1 print @sentence
end -- fn__str_replace