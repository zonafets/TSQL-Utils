/*  leave this
    l:see LICENSE file
    g:utility
    k:ftp,list,command,parse,name,date,size,directory,dir,x
    v:130603\s.zaglio: added microsoft and winscp style
    v:130531\s.zaglio: parse line of ls/dir command
    t:
        set language english -- for jan, ...
        select convert(datetime,[timestamp],100) dt,*
        from (
            select '-- test' as line
            union select
                '-rw-r--r--   1 1003     1004       1834147 Apr 20 14:13:06 2012 file'
            union select
                '05-29-12  03:46PM                  652 file'
            union select
                '03-26-07  03:16AM       <DIR>          directory'
            union select
                '-rw-r--r-- 1 ftp ftp           3613 Jan 03  2012 file'
            union select
                '-rw-r--r--    1 23208    3600        22588 Jan 11 1:43 file'
            union select
                -- probable IBM
                -- Volume Unit     Date  Ext Used Recfm Lrecl BlkSz Dsorg Dsname
                'APCSPL 3380D  07/16/97  1    1  FB      80  8800  PS  ETC.RPC'
            ) a
        cross apply fn__ftp_parse_list(1,line,default)
*/
CREATE function fn__ftp_parse_list(@lno int,@line nvarchar(4000),@opt sysname)
returns @t table(
    lno int null,
    dir char(1) null,
    [permissions] char(9) null,
    filecode sysname null,
    [owner] sysname null,
    [group] sysname null,
    size int null,
    [timestamp] sysname null,   -- returned as type 100
    name sysname
)
as
begin
/*
^
(?<dir>[\-ld])
(?<permission>([\-r][\-w][\-xs]){3})
\s+
(?<filecode>\d+)
\s+
(?<owner>\w+)
\s+
(?<group>\w+)
\s+
(?<size>\d+)
\s+
(?<timestamp>
 ((?<month>\w{3})\s+(?<day>\d{2})\s+(?<hour>\d{1,2}):(?<minute>\d{2}))
 |
 ((?<month>\w{3})\s+(?<day>\d{2})\s+(?<year>\d{4}))
)
\s+
(?<name>.+)
$
*/
declare
    @s1 int,@s2 int,@s3 int,@s4 int,@s5 int,
    @dts sysname,@tmp sysname,
    @dir char(1),@group sysname,@owner sysname,@size sysname,@name sysname,
    @permissions char(9),@filecode char(1), @done bit

-- strip spaces and mark words positions
select @done=0,@line=ltrim(@line)
while charindex('  ',@line)>0 select @line=replace(@line,'  ',' ')

select
    @s1=charindex(' ',@line)+1,     @s2=charindex(' ',@line,@s1)+1,
    @s3=charindex(' ',@line,@s2)+1, @s4=charindex(' ',@line,@s3)+1,
    @s4=charindex(' ',@line,@s3)+1, @s5=charindex(' ',@line,@s4)+1

-- if unix style
if @line like '[-dl][-r][-w][-xs][-r][-w][-xs][-r][-w][-xs] %[0-9]% % [0-9]% %'
    begin

    -- set language english
    -- select convert(datetime,'Jan 11 2012 13:43',100)
    -- select convert(datetime,'Jan 11 2012 13:43:01',100)
    -- select convert(datetime,'Jan 11 2012 1:43PM',100)
    -- select @@language
    -- set language italian

    select
        @dir=left(@line,1),
        @permissions=substring(@line,2,9),
        @filecode=substring(@line,@s1,@s2-@s1),
        @owner=substring(@line,@s2,@s3-@s2),
        @group=substring(@line,@s3,@s4-@s3),
        @size=substring(@line,@s4,@s5-@s4)

    select @tmp=substring(@line,@s5,128)
    select
        @s1=charindex(' ',@tmp)+1,      -- dd
        @s2=charindex(' ',@tmp,@s1)+1,  -- yy
        @s3=charindex(' ',@tmp,@s2)+1,  -- file or hh:mm or year
        @s4=charindex(' ',@tmp,@s3)+1

    -- unify date to "mmm dd yyyy hh:mm[am|pm]"

    -- winscp format "mmm dd hh:mm:ss yyyy "
    if @tmp like '[a-z][a-z][a-z]%:%:%'
        begin
        select @dts=left(@tmp,@s2-1)
                   +substring(@tmp,@s3,@s4-@s3)
                   +substring(@tmp,@s2,@s3-@s2),
               @name=substring(@tmp,@s4,128),
               @done=1
        end

    -- month day hour:minute
    if @done=0 and @tmp like '[a-z][a-z][a-z]%:%'
        begin
        select @dts=left(@tmp,@s2-1)
                   +cast(year(getdate()) as char(4))+' '
                   +substring(@tmp,@s2,@s3-@s2),
               @name=substring(@tmp,@s3,128),
               @done=1
        end

    if @done=0
        select @dts=left(@tmp,@s3-1),
               @name=substring(@tmp,@s3,128),
               @done=1

    end -- unit style

-- if microsoft style
if @done=0 and @line like '[0-9][0-9][-/][0-9][0-9][-/][0-9][0-9] %'
    begin

    select
        @dts=convert(
                sysname,
                convert(datetime,substring(@line,1,8),10)
                +convert(datetime,substring(@line,@s1,7),0),
                100),
        @tmp=substring(@line,@s2,@s3-@s2)
    if isnumeric(@tmp)=1
        select
            @dir='-',   -- l is linked file
            @size=convert(int,@tmp),
            @name=substring(@line,@s3,128)
    if @tmp='<DIR>'
        select
            @dir='d',
            @size=0,
            @name=substring(@line,@s3,128)
    select @done=1
    end -- microsoft style

if @done=1
    insert @t(
        lno,dir,[permissions],filecode,[owner],[group],size,[timestamp],name
        )
    select
        @lno,
        dir=@dir,
        [permissions]=@permissions,
        filecode=@filecode,
        [owner]=@owner,
        [group]=@group,
        [size]=cast(@size as int),
        [timestamp]=@dts,
        name=@name

return
end -- fn__ftp_list_parse