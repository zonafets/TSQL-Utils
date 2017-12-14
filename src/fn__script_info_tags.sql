/*  leave this
    l:see LICENSE file
    g:utility,script
    todo:manage multiline tags;manage /**/ into ''
    v:140119.1000\s.zaglio:again syntax near tags of 0 lenght
    v:140113.1002\s.zaglio\z.aglio: better syntax parses
    v:131103\s.zaglio:converted @row into @lvl and row into row of code
    v:131129\s.zaglio:added maxrecurtion to 1st with
    v:131126\s.zaglio:added management of r3;r2;r1 and c3;c2;c1
    v:130907\s.zaglio:added tag #
    v:130602\s.zaglio:added management of r3,r2,r1 in comments
    v:130528\s.zaglio:better end comments finding and used maxrecursion
    v:130523\s.zaglio:a bug where more spaces after create
    v:130522\s.zaglio:resolved bug near lf and changed results to nvarchar
    v:130511;121206\s.zaglio:a remake using with;added monoline tag S (scope) and J (job)
    v:120724,120517\s.zaglio:added tag x;removed from core group
    v:120510,111229\s.zaglio:a bug when comments greather than 4k;a small bug
    v:111222\s.zaglio:limited to /* ... */ with backward compatibility
    v:110630\s.zaglio:added to core grp
    v:110628,110624\s.zaglio:added deprecated;vesioned
    r:110614\s.zaglio:used only fn__str_parse;called from fn__script_info,sp__trace
    t:sp__script_info_tags_test @dbg=1
    t:select object_name(obj_id) name,* from fn__script_info(null,default,default)
    t:select object_name(obj_id) name,* from fn__script_info(null,'g',default)
    t:select * from dbo.fn__script_info('fn__script_info_tags','rv#',0)
    t:select * from dbo.fn__script_info('fn__script_info_tags','rv#',default)
    t:select object_name(obj_id) obj,* from fn__script_info(null,'d',default) -- deprecard
    t:sp__Script_store @opt=dis
-- c:old style
*/
CREATE function fn__script_info_tags(
    @buf nvarchar(max)=null,                -- top comment of sp,fn,v,etc.
    @grps sysname=null,
    @lvl tinyint=null                       -- row 0 is top of group,cmd pos
    )
returns @tag table (
    tag nvarchar(8),                        -- l,g,v,d,s,todo,#
    row smallint,                           -- row of code
    val1 nvarchar(4000),                    -- date(rvd),grp(g),cmd,cmt(c)
    val2 nvarchar(4000) null,               -- user,2nd grp,object type
    val3 nvarchar(4000) null,               -- comment,3rd grp,object
    status smallint null                    -- status of syntax of comments
)
as
begin

-- ============================================================= declarations ==

declare @lines table (
    pos int primary key,
    tag nvarchar(8),
    line nvarchar(4000),
    pslash smallint null,
    pcolon smallint null,
    pcom1 smallint null,
    pcom2 smallint null,
    pcom3 smallint null,
    ln smallint
    )

declare
    @line nvarchar(4000),
    @cr nchar(1),@lf nchar(1),@crlf nchar(2),
    @tab nchar(1),@i int,@j int,@k int,@st sysname,
    @pcmd int, @cmd sysname, @otype sysname, @oname sysname,
    @kind sysname,@tck varchar(16),@c nchar,@dbgt xml;

select
    @grps=isnull(@grps,'lkbvrjgbsctodo#'),  -- sp__Style
    @cr=cr,@lf=lf,@crlf=crlf,@tab=tab
from fn__sym()

-- ===================================================================== body ==

-- if @dbg=1 insert @tag(row,tag,val1,val2,val3) select 62,'dbg',null,null,null

/*  extract create/alter [type] and object name
    proc
    func
    view
    tabl
    syno
    trig
*/

-- search correct create/alter proc/func/...
-- skip initial comments /*...*/ and /*../*..*/..*/
select @kind='[pfvts][ruiay][onebi][cwlog]'
select @k=patindex('%create %'+@kind+'%',@buf)
if @k=0 select @k=patindex('%alter %'+@kind+'%',@buf)
select @i=charindex('/*',@buf),@j=charindex('*/',@buf,@i+2)
if @i>0 and @k>@i
    begin
    while @i<@j
        begin
        select @i=charindex('/*',@buf,@i+2)
        if @i=0 or (@i>@j and @i>@k) break
        if @i<@j select @j=charindex('*/',@buf,@j+2)
        end
    select @j=@j+2
    if @k>@j select @j=@k
    end
else
    select @j=@k
-- @j contain the last closed comment or 0
-- must be skipped blank lines and -- comment
-- strip headers and search for create/alter proc/func/view/trigger/synonym
select @line=substring(@buf,@j,256)
select @pcmd=patindex('%create %'+@kind+'%',@line)
if @pcmd=0 select @pcmd=patindex('%alter %'+@kind+'%',@line)
if @pcmd!=0
    begin
    -- extract declaration line and move all into single line
    select @line=replace(substring(@line,@pcmd,200),@tab,' ')
    select @pcmd=@pcmd+@j+2 -- absolute position
    select @line=replace(replace(replace(@line,@crlf,@cr),@lf,@cr),@cr,' ')
    -- reduce spaces
    while (charindex('  ',@line)>0) select @line=replace(@line,'  ',' ')
    while (charindex('. ',@line)>0) select @line=replace(@line,'. ','.')
    while (charindex(' .',@line)>0) select @line=replace(@line,' .','.')
    while (charindex('[ ',@line)>0) select @line=replace(@line,'[ ','[')
    while (charindex(' ]',@line)>0) select @line=replace(@line,' ]',']')
    end

-- parse alter/create instruction
;with splits(pos, start, [stop])
as (
  select 1, 1, charindex(' ', @line)
  union all
  select
    pos + 1,
    [stop] + 1,
    charindex(' ', @line, [stop] + 1)
  from splits
  where [stop] > 0
)
,tokens as (
    select pos,
      ltrim(
        substring(
            @line,
            start,
            case when [stop] > 0 then [stop]-start else 256 end
            )
       ) as token
    from splits
)
select
    @cmd=case when pos=1 then token else @cmd end,
    @otype=case when pos=2 then token else @otype end,
    @oname=case when pos=3 then token else @oname end
from tokens
where pos<4
option (maxrecursion 1000)

select @i=charindex('(',@oname)
if @i>0 select @oname=left(@oname,@i-1)
select @oname=isnull(quotename(parsename(@oname,2))+'.','')
             +quotename(parsename(@oname,1))

-- reduce to header to not occur into max occurence of 1000
select @buf=substring(@buf,1,@pcmd)

-- correct unix \n to uncorrect \n windows style and tab to space
select @buf=replace(replace(replace(@buf,@crlf,@cr),@lf,@cr),@tab,' ')

/* debug session
-- select * from dbo.fn__script_info('fn__script_info_tags',default,0)
insert @tag(row,tag,val1,val2,val3)
select 75,'dbg',@buf,null,null
*/

-- split top comment into lines
;with splits(pos, start, [stop])
as (
  select 1, cast(1 as int), charindex(@cr, @buf)
  union all
  select
    pos + 1,
    cast([stop] + (datalength(@cr)/2) as int),
    charindex(@cr, @buf, [stop] + (datalength(@cr)/2))
  from splits
  where [stop] > 0
)
,lines as (
    select pos,
      ltrim(
        substring(
            @buf,
            start,
            case when [stop] > 0 then [stop]-start else 4000 end
            )
       ) as line
    from splits
)
/*
    unfortunatelly a more sub withs cannot be used for unknown problemi with
    substring or left or charindex due some inner optimization of the engine
*/
,tags as (
    select pos,
           case
           when charindex(':',line)>0
           then left(line,charindex(':',line)-1)
           else ''
           end as tag,
           case
           when charindex(':',line)>0
           then ltrim(rtrim(substring(line,charindex(':',line)+1,4000)))
           else ltrim(rtrim(line))
           end as line
    from lines
    )
,epured as (
    select pos,ltrim(replace(tag,'--','')) as tag/*old line style */,line
    from tags
    )
insert @lines(pos,tag,line,pslash,pcolon,pcom1,pcom2,pcom3,ln)
select
    pos,left(tag,8),line,
    nullif(isnull(
        nullif(isnull(
            nullif(charindex('\',line),0),
            charindex('/',line)),0),
        case -- case v:yyyymmaa:{space}comment
        when charindex(' ',line)<charindex(':',line)
        then charindex(' ',line)
        end),0),
    nullif(charindex(':',line),0),
    nullif(charindex(',',line),0),
    nullif(charindex(',',line,nullif(charindex(',',line),0)+1),0),
    nullif(charindex(',',line,nullif(charindex(',',line,
        nullif(charindex(',',line),0)+1),0)+1),0),
    len(line)
from epured
where left(line,2)!='/*' and right(line,2)!='*/'
and (charindex(tag,@grps)>0 or @grps is null)
option (maxrecursion 1000)

-- code for debug
select @dbgt = (select * from @lines for xml auto)

/* debug session
-- select * from dbo.fn__script_info('fn__script_info_tags',default,default)
insert @tag(row,tag,val1,val2,val3) select 158,'dbg',pos,tag,line from @lines
return
*/

-- extract group components
;with tags as (
    select
        tag,
        row_number() over(partition by tag order by pos)-1 as lvl,
        ltrim(rtrim(substring(line,1,isnull(pcom1-1,ln)))) as val1,
        ltrim(rtrim(substring(line,pcom1+1,isnull(pcom2-1,ln)-pcom1))) as val2,
        ltrim(rtrim(substring(line,pcom2+1,isnull(pcom3-1,ln)-pcom2))) as val3,
        pos
    from @lines
    where tag in ('g','s') and ln>0
)
insert @tag(tag,row,val1,val2,val3)
select tag,pos,val1,val2,val3
from tags
where @lvl is null or @lvl=lvl
option (maxrecursion 1000)

-- extract revisions components
;with tags as (
    select
        tag,
        row_number()
        over(
            -- row 0 of a revision is the 1st r or v
            partition by case tag when 'r' then 'v' else tag end
            order by pos
            )-1
        as lvl,
        pos as row,
        ltrim(rtrim(substring(line,1,isnull(pslash-1,isnull(pcolon-1,ln)))))
        as val1,
        ltrim(rtrim(substring(line,pslash+1,isnull(pcolon-1,ln)-pslash)))
        as val2,
        ltrim(rtrim(substring(line,pcolon+1,ln-pcolon)))
        as val3
    from @lines
    where tag in ('v','r','d','x','o') and ln>0
)
insert @tag(tag,row,val1,val2,val3)
select tag,row,val1,val2,val3
from tags
where @lvl is null or @lvl=lvl
option (maxrecursion 1000)

-- select * from fn__script_info('fn__script_info_tags','rv',default)

-- reduce r3,r2,r1 or r3;r2;r1 into r3; reduce c3;c2;c1 into c3
update @tag set
    val1=left(val1,isnull(nullif(charindex(',',val1),0),charindex(';',val1))-1),
    val3=left(val3,isnull(nullif(charindex(';',val3),0),len(val3)+1)-1)
where tag in ('r','v')
and (charindex(',',val1)>0 -- ??and charindex(',',val1,charindex(',',val1))>0??
     or charindex(';',val1)>0)

-- extract single tag component
;with tags as (
    select tag,
           row_number() over(partition by tag order by pos)-1 as lvl,
           line as val1,
           pos
    from @lines
    where tag in ('l','c','t','k','todo')
)
insert @tag(tag,row,val1)
select tag,pos,val1
from tags
where @lvl is null or @lvl=lvl
option (maxrecursion 1000)

if charindex('#',@grps)>0
    begin
    -- if isnull(@pcmd,0)=0 select @i='create/alter not found'
    insert @tag(tag,row,val1,val2,val3)
    select '#',@pcmd,@cmd,@otype,@oname
    end

-- apply convert into datetime and adjustments
return
end -- fn__script_info_tags