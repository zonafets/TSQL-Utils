/*  leave this
    l:see LICENSE file
    g:utility
    v:151108\s.zaglio:added collate database_default
    v:130728.1000\s.zaglio:use sp__script_template_compile
    v:130724\s.zaglio:doubled performance
    v:130713,130709\s.zaglio:added (duty) #tpl_cpl;better help and sp__Script_template_test
    v:130707,130519\s.zaglio:moved init of #tpl here;better info on missing tpl lines
    v:130430,130301\s.zaglio:a bug when #tpl is empty;a bug near insert #tpl_sec
    v:121229\s.zaglio:added %dt% and %uid% in unix notation
    v:120918\s.zaglio:removed exclusion tag from sub substitution and nomixed
    v:120914\s.zaglio:opt mix is now default and #tpl mix with itself's secs
    v:120913\s.zaglio:split of #tpl_sec.line with crlf and a small bug
    v:120912,120725.1212\s.zaglio:better help;added @spring
    v:120627,120126\s.zaglio:a bug near mix (ex temp_db.#tpl_sec);#tpl_sec optional
    v:111230.1509\s.zaglio:probable stable version
    r:111228,111227\s.zaglio:debugging
    r:111223,111222\s.zaglio:auto tokens;new concept that reduce caller code
    v:111221,111220\s.zaglio:done tab management;about @tab as in&out
    v:111216\s.zaglio:@to searched after @from
    v:111115\s.zaglio:added "out" opt and removed exlusion of middle section
    v:111102\s.zaglio:added option
    v:110824\s.zaglio:better errors and src now is #tpl and #src become output
    v:110823,110822\s.zaglio:done;added @from,@to,@tab and removed @splitter
    v:110707,110706\s.zaglio:@bug near #var;added @excludes
    v:110701.1825,110601\s.zaglio:a bug near replace of ";added tokens
    v:110630\s.zaglio:help define templates and generate code
    t:sp__script_template_test
*/
CREATE proc sp__script_template
    @section  nvarchar(max) = null,
    @as       nvarchar(256) = null,
    @opt      nvarchar(256) = null,
    @tab      int           = null out,
    @tokens   nvarchar(4000)= null,
    @v1       sql_variant   = null,
    @v2       sql_variant   = null,
    @v3       sql_variant   = null,
    @v4       sql_variant   = null,
    @excludes nvarchar(4000)= null,
    @dbg      int           = null
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
if @dbg=2 create table #tpl (lno int identity,line nvarchar(4000))

-- ========================================================= param formal chk ==
declare
    @nomix bit,@isection sysname,@crlf nvarchar(2),@lcrlf int,@itab int,
    @tpl_oid int,@tpl_cpl_oid int

select
    @nomix=charindex('|nomix|',@opt),
    @crlf=crlf,
    @lcrlf=len(@crlf),
    @itab=isnull(@tab,0),
    @tab=isnull(@tab,0),
    @tpl_oid=object_id('tempdb..#tpl'),
    @tpl_cpl_oid=object_id('tempdb..#tpl_cpl')
from fn__sym()


if @tpl_oid is null
-- or (object_id('tempdb..#tpl_sec') is null and @nomix=0)
    goto help

select @isection=left(@section,128)
-- ============================================================== declaration ==
declare
    @tpl binary(20),                    -- hash of template
    @sep nvarchar(32),
    @i int,@n int,@dtype int,@null nvarchar,
    @x1 int,@y1 int,@x2 int,@y2 int,@line nvarchar(4000),
    @replace_double_quotes bit,@print bit,@out_out bit,
    @scissors nvarchar(32),
    @tkn nvarchar(32),          -- token
    @oline nvarchar(4000),      -- original line
    @bos sysname,               -- begin of section
    @lo_lno int,@hi_lno int,    -- low and high line number
    @noimacro bit,
    @td nvarchar(4),            -- tokens delimiter
    @d datetime,
    @exclusion sysname,         -- pattern for fine comment line
    @tmp nvarchar(4000),
    @spring varchar(10),        -- space extensor to justify text
    @start varchar(16),         -- pattern of section start
    @end_deflare bit

declare @tkns table (
    id int identity(1,1) primary key,
    -- lno int,
    -- x1 int,
    -- x2 int,
    tkn nvarchar(4000),
    [val] nvarchar(4000)
    )

declare @exclusions table (
    lno int,
    pos int,    -- left position to exclude tag
    exclude bit -- 1=is included into exclude tokens
    )

declare @out table(lno int identity primary key,line nvarchar(4000))

-- =========================================================== initialization ==

select
    @as=isnull(@as,''), -- @isection),
    @d=getdate(),
    @sep ='|',
    @td='%',
    @dtype=126,
    @null='',
    @replace_double_quotes=charindex('|replace"|',@opt),
    @out_out=charindex('|out|',@opt),
    @print=charindex('|print|',@opt),
    @noimacro=charindex('|noimacro|',@opt),
    @scissors='-%8<%-',
    @tkn='%[%]%[a-z0-9_]%[%]%',
    @exclusion='%--[|]%[|]',
    @start='[%<]%[>%]:',
    @spring='/*@*/'

-- 120918\s.zaglio: nomixed automatically if...
if @as!='' select @nomix=1

-- ================================================= split and store sections ==
if @section like '%['+@crlf+']%'
    begin
    select @tpl=hashbytes('md5',left(@section,4000))

    -- if already compiled
    if exists(select top 1 null from #tpl_cpl where tpl=@tpl) goto ret

    select @hi_lno=isnull(max(lno)+1,0) from #tpl

    insert #tpl(line)
    select line -- sp__Script_template
    from dbo.fn__ntext_to_lines(@section,0)

    exec sp__script_template_compile @tpl,@start,@scissors

    goto ret
    end -- compile teplate

-- backward compatiblity
if @tpl_cpl_oid is null
    begin
    create table #tpl_cpl(tpl binary(20),section sysname,y1 int,y2 int)
    -- print hashbytes('md5','compiled')
    select @tpl=0xCB5185196AD3147D58C13C22B2A32292
    exec sp__script_template_compile @tpl,@start,@scissors
    end

select @bos=@isection+':',@lo_lno=min(lno),@hi_lno=max(lno) from #tpl

if @dbg=1
    select '#tpl_cpl' tbl,section,y1,y2,line
    from #tpl_cpl join #tpl t on t.lno between y1 and y2
    order by lno

if not exists(select top 1 null from #tpl) goto err_tpl

-- check for sections with null lines
if not object_id('tempdb..#tpl_sec') is null
    if exists(
        select top 1 null
        from #tpl_sec
        where line is null
        and (@isection is null or section=@isection)
        )
        begin
        if @isection is null
            select top 3 @isection=isnull(@isection+',','')+section
            from #tpl_sec
            where line is null
        goto err_sec
        end

-- collect line number to exclude
insert @exclusions(lno,pos,exclude)
select
    lno,
    case
    when patindex(@exclusion,rtrim(t.line))>2
    then len(rtrim(substring(t.line,1,patindex(@exclusion,rtrim(t.line))-1)))
    else len(t.line)
    end as pos,
    case
    when patindex(@exclusion,rtrim(t.line))>2
     and dbo.fn__str_between(
         substring(t.line,patindex(@exclusion,rtrim(t.line))+2,128)
         ,'|','|'
         ,default
         )
         in (
             select token
             from dbo.fn__str_table(@excludes,@sep)
             where token!=''
            )
    then 1
    else 0
    end as exclude
from #tpl t

-- select * from #tpl t join @exclusions e on t.lno=e.lno

if @isection is null
    -- after last scissor
    select top 1 @y1=lno+1
    from #tpl
    where line like @scissors
    and lno!=@hi_lno -- skip last scissor on last line
    order by lno desc
else
    -- begin of section
    select top 1 @y1=lno+1
    from #tpl
    where ltrim(rtrim(line)) = @bos  -- 120913\s.zaglio: removed like
    order by lno

if @y1 is null and not @isection is null goto err_snf

select @y1=isnull(@y1,@lo_lno)

-- end of section (scissors or eof or [ssep]%[ssep]
if not @isection is null
    select top 1 @y2=lno-1
    from #tpl
    where 1=1
    and lno>=@y1
    and line like @scissors
    order by lno

-- last section end is last line
if @y2 is null select @y2=@hi_lno

-- ======================================================== second params chk ==

-- ===================================================================== body ==

-- extract section lines and mix with info from #tpl_sec or print missing data

-- ##################################
-- ##
-- ## mix
-- ## if #tpl_sec contain the section use it, otherwise
-- ## replace with original section from #tpl or give error or unk. section
-- ##
-- #############################################################################
if object_id('tempdb..#tpl_sec') is null
    insert @out(line)
    select
        left(t.line,excl.pos)
        as line
    from #tpl t
    left join @exclusions excl on t.lno=excl.lno
    where 1=1
    and t.lno between @y1 and @y2
    and not t.line collate database_default like @scissors
    and excl.exclude=0
    order by t.lno
else
    insert @out(line)
    select
        case
        when s.section is null
        then case
             when tts.section is null
             then left(t.line,excl_t.pos)
             else left(replace(left(t.line,excl_t.pos) collate database_default,
                               tts.section collate database_default,
                               tt.line collate database_default),
                       excl_tt.pos)
             end
        else replace(left(t.line,excl_t.pos) collate database_default,
                     s.section collate database_default,
                     s.line collate database_default)
        end
        as line
    from #tpl t
    left join @exclusions excl_t on t.lno=excl_t.lno
    left join (
        select s.lno*1000+pos lno,s.section,token as line
        from #tpl_sec s
        cross apply dbo.fn__str_table_fast(s.line,@crlf)
        -- where charindex(s.section,t.line)>0 not possible
        ) s
        -- #tpl_sec s
        on charindex(s.section,t.line)>0
    left join #tpl_cpl tts
        on charindex(tts.section,t.line)>0
    left join #tpl tt
        on tt.lno between tts.y1 and tts.y2
    left join @exclusions excl_tt on tt.lno=excl_tt.lno
    where 1=1
    and t.lno between @y1 and @y2
    and not t.line like @scissors collate database_default
    and isnull(excl_t.exclude,0)=0
    and isnull(excl_tt.exclude,0)=0
    order by t.lno,s.lno

if @@rowcount=0 goto err_mix

insert @tkns(tkn,val)
select
    token,
    convert(nvarchar(4000),
            case pos
            when 1 then @v1
            when 2 then @v2
            when 3 then @v3
            when 4 then @v4
            end
            )
from fn__str_table(@tokens,@sep)

if not object_id('tempdb..#vars') is null
    insert @tkns(tkn,val)
    select
        v.id,
        case
        when sql_variant_property(v.[value],'BaseType')='datetime'
        then convert(nvarchar(48),v.[value],@dtype)
        else convert(nvarchar(4000),coalesce(v.[value],@null))
        end
    from #vars v
    left join @tkns t on v.[id]=t.tkn collate database_default
    where t.tkn is null

-- add local macro
if @noimacro=0
    insert  @tkns(tkn,val)
        select m.id,m.value
        from (
            select '%db%' id,db_name() value union
            select '%now%',convert(nvarchar(48),getdate(),126) union
            select '%dt%',substring(convert(nvarchar(48),getdate(),126),3,14) union
            select '%uid%',system_user+'@'+host_name()
            ) m
        left join @tkns t on m.id=t.tkn
        where t.tkn is null

-- introduce here the reading of last indent, if @tab=0
if @tab=0
    select top 1 @tab=patindex('%[^ ]%',line)-1 -- is a len
    from @out
    order by lno desc

if @dbg=1
    begin
    select @section as [@section],@as as [@as],
           @x1 as [@x1],@y1 as [@y1],@x2 as [@x2],@y2 as [@y2],
           @tab as [@tab],@itab as [@itab]
    select 'tpl' tpl,* from #tpl
    select '@out' [out],@isection as sec,* from @out order by lno
    select '@tkns' tkns,* from @tkns

    select '#tpl_sec' sec,* from #tpl_sec
    select '@ex' ex,* from @exclusions
    end -- dbg

declare cs cursor local forward_only for
    select lno,/*space(@itab)+*/line
    from @out
    order by lno

/*  TODO:   convert tokens in inside sections and/or allow
            that tokens with CRLF will be correctly expandend
            to allow a correct compare between composed #src
            and its compiled version
*/
-- replace tokens & "
open cs
while 1=1
    begin
    fetch next from cs into @i,@line
    if @@fetch_status!=0 break

    if @line is null goto err_nll

    select @oline=@line

    select
        @line=replace(@line,tkn,convert(nvarchar(4000),val))
    from @tkns t
    where charindex(t.tkn,@line)>0

    -- count "
    if @replace_double_quotes=1
        begin
        select @n=0,@i=charindex('"',@line,1)
        while @i>0
            select @n=@n+1,@i=charindex('"',@line,@i+1)
        if @n>0 and @n%2=0 select @line=replace(@line,'"','''')
        end

    if @line is null goto err_nlr

    if charindex(@spring,@line)>0
    and (80-len(@line)+len(@spring))<=80
        select @line=replace(
                        @line,
                        @spring,
                        replicate(' ',80-len(@line)+len(@spring))
                        )

    if @print=1
        begin
        select @tmp=replace(@line,'%','%%')
        raiserror(@tmp,10,1) with nowait
        end
    else
        update @out set line=@line where current of cs
    end -- while of cursor
close cs
deallocate cs

if not @isection is null
and @nomix=1
    insert #tpl_sec(section,line)
    select @as,line
    from @out
    order by lno
else
    begin
    if @print=0 -- already printed above
        begin
        if object_id('tempdb..#src') is null or @out_out=1
            begin
            if object_id('tempdb..#out') is null
                select line from @out order by lno
            else
                insert #out(line) select line from @out order by lno
            end -- out to #out
        else
            insert #src(line) select line from @out order by lno
        end -- out to #src
    end -- out

goto ret

-- =================================================================== errors ==
err_mix:    exec @ret=sp__err   'fusion (y1:%d,y2:%d)',
                                @proc,@p1=@y1,@p2=@y2
            goto ret
err_tpl:    exec @ret=sp__err   'empty #tpl',
                                @proc,@p1=@isection
            goto ret
err_cpl:    exec @ret=sp__err   'undeclared #tpl_cpl',
                                @proc
            goto ret
err_snf:    exec @ret=sp__err   'section "%s" not found in #tpl',
                                @proc,@p1=@isection
            goto ret
err_nlr:    exec @ret=sp__err   'null line result in (%s)',
                                @proc,@p1=@oline
            goto ret
err_nll:    exec @ret=sp__err   'null input line (sec:%s)',
                                @proc,@p1=@isection
            goto ret
err_sec:    exec @ret=sp__err   'null line in #tpl_sec for (sec:%s)',
                                @proc,@p1=@isection
            goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    help programmer to generate code from template;
    generally script a section of #tpl in #tpl_sec and
    finally MIX the specified or last section into console or #src if present.

Todo
    - check for duplicates on init

Notes
    since version 130713, #tpl and #tpl_cpl are duty and inner section of #tpl
    are not auto expanded (sorry) so you need to pre-expand into #tpl_sec
    create table #tpl(lno int identity primary key,line nvarchar(4000))
    create table #tpl_sec(lno int identity,section sysname,line nvarchar(4000))
    create table #tpl_cpl(tpl binary(20),section sysname,y1 int,y2 int)

Parameters
    #tpl        the source template
    #tpl_cpl    is the compiled version of #tpl and allows inner calls as for example
                between sp__script_group and sp__script
    #tpl_sec    (optional)the template section replacers
                if omitted, output directly to #src or #out
    #src        (optional) where store the compiled result
    #out        (optional) where store the compiled result if #src is not given
    @section    - templates to init #tpl
                - script @section of #tpl into #tpl_sec with @section as name
                (@section identify lines between %section%: and next --8<--8<-- scissor)
                @tokens are replaced with @v1,@v2,...
                If null, insert into #src the last section (tipical MAIN at end of code),
                mixing content from #tpl_sec and replacing words as %tpl_sec.section%
                with tpl_sec.line (multiple lines are allowed).
    @as         alternative @section name to use when section is scripted into #tpl_sec
                (this do not do any mix into #src/#out)
    @opt        options, see below
    @tokens     (optional) tokens, separated by | to replace with @v1..4
                if omitted, collects couples of %...% (see also #vars)
    @v1..4      values for tokens
    @tab        out the number of spaces before the splitter
                or the left spaces of last row of section;
                if valued, shift the section
    @excludes   tokens (sep. by |) of lines to exclude (line that end with "--|token|"
    #vars       (optional) macro replace (see sp__str_replace) (@tokens overwrite #vars)
                (macro %db%,%uid%,%dt%,%now% are pre-defined)
                create table #vars (id nvarchar(16),value sql_variant)
    @dbg        2 inner create #tpl to test insert

Notes
    1. if not all sections are covered by #tpl_sec, a list of sections is printed
    2. if all sections are covered, the sp merge #tpl and sec into #src or #out or print
    3. the indent of ##section## is applied to lines of #tpl_sec
    4. There are predefined macros:
        %db%    current db
        %now%   current datetime in current format (126)
    5. scissors are skipped (any line like "-%8<%-")
       -- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
    6. /*@*/    justify to right at col 80, the rest of text

Options
    replace"    replace " with double ''
    noimacro    disable autodefinition of inner macros (%db%,%now%,...)
    print       print lines instead insert into #src or #out or #tpl_sec
    out         force output to #out instead of #src

Examples

    -- given this template...

    exec sp__script_template ''
    -- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
    %header%:
        %detail%
    -- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
    %details%:
    line 1
    line 2
    -- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
    ''

    -- ... or call the sp @as to out to #tpl_sec to be remixed

    exec sp__script_template ''%details%'',''%detail%''
    exec sp__script_template ''%header%''

    see sp__script_template_test, sp__script_group, sp__script_data

'

if not object_id('tempdb..#tpl') is null
and object_id('tempdb..#tpl_sec') is null
    begin
    exec sp__select_astext '
        select line as sections from #tpl where rtrim(line) like ''%:''
        '
    end

select @ret=-1

-- ===================================================================== exit ==
ret:
if @dbg>2 exec sp__elapsed @d,@proc
return @ret

end -- proc sp__script_template