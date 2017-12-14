/*  leave this
    g:utility
    v:110721.1646\s.zaglio: alternative use of sp__write_ntext_to_lines
    t:
        declare @obj sysname,@le bit
        select @le=1,@obj=
            'SP_SAP_EXPORT_PRODUCTIONS_test_bug'
            -- 'sp__write_ntext_to_lines'
        select *,charindex(char(13),line) pcr,charindex(char(10),line) plf
        from fn__ntext_to_lines(
                (select top 1 [text]
                    from syscomments
                    where id=object_id(@obj)
                    )
                ,@le  -- @leave_le
            )
        order by lno
*/
CREATE function fn__ntext_to_lines(@blob ntext,@leave_le bit)
returns @t table(lno int identity primary key,line nvarchar(4000))
as
begin

declare
    @drop bit,
    @i int,@j int,@l int,@n int,@p int,
    @ncrlf nvarchar(2),@cr nchar(1),@lf nchar(1),
    @lcrlf int,@dbg bit

select @dbg=0

declare @lines table (pos int primary key,leng int)

select @ncrlf=crlf,@cr=cr,@lf=lf,@leave_le=isnull(@leave_le,0)
from fn__sym()

-- identify row separator
select
    @i=charindex(@cr,@blob),
    @j=charindex(@lf,@blob),
    @n=datalength(@blob)/2
/*
if @dbg=1
    insert @t(line)
    select '@i='+cast(@i as sysname) union
    select '@j='+cast(@j as sysname) union
    select '@n='+cast(@n as sysname)
*/

if @i is null return
if @i=0 and @j=0 and @n<4000
    begin
    insert @t(line) select substring(@blob,1,4000)
    return
    end

if @i>0 and @j=0 select @ncrlf=@cr
if @i=0 and @j>0 select @ncrlf=@lf
if @i=@j+1 select @ncrlf=@lf+@cr
select @lcrlf=len(@ncrlf)
/*
if @dbg=1
    insert @t(line)
    select '@lcrlf='+cast(@lcrlf as sysname) union
    select '@cr='+cast(unicode(@cr) as sysname) union
    select '@lf='+cast(unicode(@lf) as sysname) union
    select '@ncrlf='+cast(unicode(substring(@ncrlf,1,1)) as sysname)+'|'+
                     cast(isnull(unicode(substring(@ncrlf,2,1)),'0') as sysname)
*/
select top 1 @i=1,@p=1,@j=1

while 1=1
    begin
    select top 1 @i=charindex(@ncrlf,substring(@blob,@j,4000))

    if @i=0
        begin
        -- last pieces that do not end with crlf
        -- if @dbg=1 exec sp__printf 'j:%d, i:%d, @n:%d',@j,@i,@n
        if @n>@j/*+@lcrlf*/-1 insert @lines select @j,@n-@j+1
        break
        end
    -- if @dbg=1 exec sp__printf 'j:%d, i:%d',@j,@i
    if @leave_le=1 select @l=@i+@lcrlf-1 else select @l=@i-1
    insert @lines select @j,@l
    /*
    if @dbg=1
        begin
        insert @t(line)
        select left('i:'+cast(@i as sysname)+
                    ';j:'+cast(@j as sysname)+
                    ';l:'+cast(@l as sysname)+
                    ';                    ',20)+
               replace(replace(substring(@blob,@j,4000),@lf,'|'),@cr,'+')
        insert @t(line) select space(@i+20-1)+'^'
        end
    */
    select @j=@j+@i+@lcrlf-1
    end -- while

/*
insert @t(line)
select 'pos:'+cast(pos as sysname)+'; leng:'+cast(leng as sysname)
from @lines
return
*/
insert @t(line)
select substring(@blob,pos,leng) line
from @lines

return
end -- fn__ntext_to_lines