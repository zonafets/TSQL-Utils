/*  leave this
    l:see LICENSE file
    g:utility
    k:street, place, civic, split, correc, normalize
    v:121118\s.zaglio: working
    v:121007\s.zaglio: split and normalize an address
    t:
        select *
        from tst_street_tbl t
        cross apply fn__place(t.addr,default) p
        cross apply fn__place(t.addr,0) d      -- debug version
        where 1=1
        -- and t.addr='STR. COMUNALE MARANDA 9'
        and t.addr like '%riposo%'
        and p.typ_id is null
*/
CREATE function fn__place(@address sysname,@lng tinyint)
returns @t table (
    typ nvarchar(32), typ_id tinyint,
    name nvarchar(128),
    num nvarchar(64)
    -- ,co nvarchar(64)
    )
as
begin
-- declare @addr sysname
declare
    @p_name int,@p_num int,@l int,@p_co int,@p_via int,
    @typ nvarchar(32), @name nvarchar(128), @num nvarchar(64),
    @co nvarchar(64), @typ_id int,@i int,@addr sysname,@j int,
    @c nchar,@pc nchar, @co_id int

-- replace not good symbols: ltrim, rtrim
select @i=1,@l=len(@address),@addr='',@j=0,@pc=' ',@p_via=0
while @i<=@l
    begin
    select @c=substring(@address,@i,1),@i=@i+1
    -- skip initial spaces
    if (@c=N' ' and @j=0) continue
    if @c in ('-',':') select @c='.'
    else if @c in ('(',')',',') select @c=' '
    -- insert @t(typ,typ_id,name,num) select @pc+'|'+@c+'|',@i,@addr,@j
    if @pc!=' ' select @addr=@addr+@pc,@j=@j+1
    if @c=' ' and not @pc in ('.',' ') select @addr=@addr+@c,@j=@j+1
    select @pc=@c
    end
if @c!=' ' select @addr=@addr+@c
-- insert @t(typ,typ_id,name,num) select @pc+'|'+@c+'|',@i,@addr,@j return

select @addr=replace(replace(@addr,'Rif..',''),'Rif.','')

-- special cases of address inversion
select top 1 @p_via=charindex(cod,@addr) ,@typ_id=id
-- select *
from fn__place_type()
where charindex(cod,@addr)>0
select top 1 @p_co=charindex(cod,@addr),@co_id=id
-- select *,charindex(cod,'PRESSO CLINICA SAN RAFFAELE') p_co
from fn__place_at()
where charindex(cod,@addr)>0
select @p_co=isnull(@p_co,0)
if @p_co=1 and @p_via>1
    select @addr=substring(@addr,@p_via,128)+' '
                +left(@addr,@p_via-1)

select @l=len(@addr)
if @l<3 goto store

select @p_name=charindex(' ',@addr)
if @p_via=0 and @p_name>0 select @typ=left(@addr,@p_name),@p_name=1

select @p_num=patindex('%KM%[0-9]%',@addr)

if @p_num=0 select @p_num=patindex('%N.[0-9]%',@addr)

if @p_num=0 select @p_num=patindex('%N°[0-9]%',@addr)

if @p_num=0
    begin
    select @p_num=patindex('%[0-9] %',reverse(@addr))
    if @p_num>0 select @p_num=@l-@p_num+1
    end

-- if @p_name=0 select @p_name=1

-- select * from arc04_addresses cross apply fn__street(pla)

if not @lng is null
    begin
    insert @t(typ,typ_id,name,num)
    select @p_via,@p_co,@p_name,@p_num
    return
    end

-- if @p_name=0 select @p_name=1
-- if @p_co=0  select @p_co =@l+1
if @p_name>0
    begin
    if @typ is null
        select @typ=ltrim(left(@addr,@p_name-1)),@p_name=@p_name+1 -- skip space
    if @p_num=0 and @p_co=0
        select @name=ltrim(rtrim(substring(@addr,@p_name,abs(@l+1-@p_name))))
    else
        begin
        if @p_num=0 and @p_co>0
            select
                @num=ltrim(rtrim(replace(substring(@addr,@p_co,@l+1-@p_co),',',''))),
                @name=ltrim(rtrim(substring(@addr,@p_name,abs(@p_co-@p_name))))
        else
            select
                @num=ltrim(rtrim(replace(substring(@addr,@p_num,@l+1-@p_num),',',''))),
                @name=ltrim(rtrim(substring(@addr,@p_name,abs(@p_num-@p_name))))
        end
    end
else
    select @name=@addr

select @name=replace(@name,',','')
-- if right(@name,2) in ('n.',' n','n°') select @name=left(@name,len(@name)-2)

store:
-- exec sp__printf 'pn:%d n:%s',@p_num,@name

if @name is null
    insert @t select null,@typ_id,@addr,null--,@co
else
    insert @t select @typ,@typ_id,@name,@num--,@co

return
end -- fn__place