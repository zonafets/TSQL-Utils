/*  leave this
    l:see LICENSE file
    g:utility,util_tkns
    v:131010\s.zaglio: a try of optimization
    v:111114\s.zaglio: simplyfied and added to grp util_tkns
    v:100919\s.zaglio: added management of sep ' '
    v:091018\s.zaglio: replaced datalengh with len for problem with unicode
    v:090805\S.Zaglio: now on @pos=0 return null
    v:081212\S.Zaglio: now support @sep=' '
    v:081204\S.Zaglio: removed bug limits 128 chars
    v:081130\S.Zaglio: replaced fn_str_at and optimized
    v:081110\S.Zaglio: expanded @seps to nvarchar(32)
    v:080909\S.Zaglio: added outbounds tests and -n as from right and return of varchar4000 nad null case
    v:080717\S.Zaglio: normalize position for fn_str_at
    t:
        -- due wide use of this, a good test is needed
        declare @tbl table(id int, s sysname,sep sysname,p int,v sql_Variant,r sql_variant)

        insert @tbl(id,s,sep,p,r) select  10,'a','|',4,null
        insert @tbl(id,s,sep,p,r) select  20,'a|b','|',-1,null
        insert @tbl(id,s,sep,p,r) select  22,'a|b','|',-2,null
        insert @tbl(id,s,sep,p,r) select  24,'a|b','|',-3,null
        insert @tbl(id,s,sep,p,r) select  30,'','|',1,''
        insert @tbl(id,s,sep,p,r) select  40,'a|b|c','|',1,'a'
        insert @tbl(id,s,sep,p,r) select  50,'|b|c','|',1,''
        insert @tbl(id,s,sep,p,r) select  60,'a|b|c','|',2,'b'
        insert @tbl(id,s,sep,p,r) select  70,'a|b|c','|',3,'c'
        insert @tbl(id,s,sep,p,r) select  93,'a|b|c','|',0,null
        insert @tbl(id,s,sep,p,r) select  96,'a b c','',3,'c'
        insert @tbl(id,s,sep,p,r) select 100,'abc de fg','',1,'abc'
        insert @tbl(id,s,sep,p,r) select 110,'abc de fg','',2,'de'
        insert @tbl(id,s,sep,p,r) select 120,'abc de fg','',3,'fg'
        insert @tbl(id,s,sep,p,r) select 130,'abc de fg','',4,null
        insert @tbl(id,s,sep,p,r) select 140,'abc   de fg   ','  ',2,' de fg'
        insert @tbl(id,s,sep,p,r) select 140,'abc   de fg   ','',3,''
        insert @tbl(id,s,sep,p,r) select 150,'   abc  de  fg   ','',3,''
        insert @tbl(id,s,sep,p,r) select 160,'   abc  de  fg   ','abc',4,null

        update @tbl set v=dbo.fn__str_at(s,sep,p)

        select *,case when v=r or v is null and r is null then 'ok' else 'ko' end rr
        from @tbl
*/
CREATE function [dbo].[fn__str_at](
    @data nvarchar(4000),
    @sep nvarchar(32),
    @pos int
    )
returns nvarchar(4000)
as
begin
declare @st nvarchar(4000)
declare @i int,@j int
declare @step int

if @data is null or @sep is null return null

--initialize
select @st = ''
select @step = len('.'+@sep+'.')-2
if @sep = '' and @step=0 select @sep = ' ',@step=1

select @data = @data + @sep , @j=1
select @i = charindex(@sep, @data)

/*
    this do not optimize nothing:
    - if @pos=1 return left(@data,@i-1) (same time)
    - use of fn__str_split or fn__str_parse that uses with (5-8 time slower)
*/

while (@i <> 0)
    begin
    select @pos=@pos-1
    if @pos=0 return substring(@data, @j, @i - @j)
    set @j=@i+@step
    set @i = charindex(@sep, @data,@j)
    end

return null
end -- fn__str_at