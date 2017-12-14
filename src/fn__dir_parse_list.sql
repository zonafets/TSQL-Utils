/*  leave this
    l:see LICENSE file
    g:utility
    k:dir,list,command,parse,name,date,size,directory
    v:140110\s.zaglio: bug near eng dt (solved but maybe not completelly)
    v:131016.1030\s.zaglio: support and simplify sp__dir
    t:sp__dir '%temp%\*.*',@dbg=2
*/
CREATE function fn__dir_parse_list(@line nvarchar(4000),@opt sysname)
returns @t table(
    sdt sysname,
    sfsize sysname null,
    name nvarchar(446)
)
as
begin
declare @max_file_name_size int select @max_file_name_size=446
if @opt='I'
    --         10        20        30        40        50        60        70        80
    -- 123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.
    -- 14/09/2010  15.34         1.106.500 FILENAME
    -- 25/01/2010  12.27    <DIR>          ADFS
    -- select convert(datetime,'09/01/14 03:30:00PM')
insert @t(sdt,sfsize,name)
    select
        substring(@line,7,4)+'-'+substring(@line,4,2)+'-'+substring(@line,1,2)
                        +'T'
                        +substring(@line,13,2)+':'+substring(@line,16,2)+':00.000'
        as sat,
        ltrim(rtrim(replace(replace(substring(@line,20,16),'.',''),',','')))
        as sfsize,
        substring(@line,37,@max_file_name_size) [key]

else if @opt='E'

    --         10        20        30        40        50        60        70        80
    -- 123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.
    -- 10/06/2011  04:39 PM    <DIR>          1040
    -- 12/31/2013  02:00 AM               137 tmp_3A2D662D_C46C_425F_8EBA_91635D98C83B
    -- set language english
    -- set language italian
    -- Hijri: dd/mm/yyyy hh:mi:ss:mmmAM: this return a bad year
    -- select convert(sysname,convert(datetime,'04:43:00PM'),8)
    -- xp_cmdshell 'dir %temp%\*.*'
    -- select convert(datetime,'12/24/13 04:43:00PM')
    insert @t(sdt,sfsize,name)
    select
        /* substring(@line,4,2)+'/'+substring(@line,1,2)+'/'+substring(@line,9,2)
        +' '
        +convert(sysname,
                 convert(datetime,
                         substring(@line,13,2)+':'+
                         substring(@line,16,2)+':00'+
                         substring(@line,19,2)
                         )
                )
        */
        substring(@line,1,20)   -- 140110\s.zaglio
        as sdt, -- gg/mm/aa hh:mi:ss:mmmAM
        ltrim(rtrim(replace(replace(substring(@line,21,18),'.',''),',',''))) sfsize,
        substring(@line,40,@max_file_name_size) [key]

return
end -- fn__dir_parse_list