/*  leave this
    l:see LICENSE file
    g:utility
    d:130521\s.zaglio:sp__select
    v:130517.1700\s.zaglio: a bug near print into @out and h and noh opts
    v:130424\s.zaglio: again adapted to be multi collate
    v:130422\s.zaglio: removed use of fn__str_print
    v:121025\s.zaglio: better identification of last "from"
    v:121024\s.zaglio: adapted to be multi collate
    v:120830.1518\s.zaglio: a bug near hdr when out ot #tbl or select
    v:120809\s.zaglio: use of fn__sql_normalize
    v:120801\s.zaglio: bug new into ... porder by
    v:120724\s.zaglio: added auto enclose of union into ()
    v:120723.1700\s.zaglio: added footer in html out if @header=2
    v:120723\s.zaglio: chk of unions and a bug generating html file
    v:120720.1531\s.zaglio: converted order by 1,2,... into names
    v:120720.1243\s.zaglio: corrected new and old order by problem
    r:120719\s.zaglio: added html and done test (wrong order)
    r:120718\s.zaglio: a remake for mssql2k5> (20% faster)
    v:120717\s.zaglio: test for -- presence
    v:120307\s.zaglio: better error management
    v:120116\s.zaglio: added #src,#out,p4 options
    v:111130\s.zaglio: when @out=#html or .htm?, now send a real table
    v:110831\s.zaglio: return error if write to file fail
    v:110308\s.zaglio: more help
    v:110219\s.zaglio: added out as select and @sep as varchar32
    v:110112\s.zaglio: added right trim
    v:101201\s.zaglio: added row2,3,4 for very big tables
    v:100911\s.zaglio: added type distinctions between datetime, reals, etc in convert
    v:100718\s.zaglio: added @p1,@p2...
    v:100612\s.zaglio: more debug info
    v:100522\s.zaglio: a bug when @header=0 and added 1 or 2 headers option
    v:100404\s.zaglio: adj. help and added <br>
    v:100328\s.zaglio: removed doubled from run in exec(...)
    v:100228\s.zaglio: added @sep,quoted names and order by
    v:100115\s.zaglio: adjusted header padding and managed 0 rows table
    v:100107\s.zaglio: @out=null -> normal select
    v:100105\s.zaglio: normalized sql
    v:091229\s.zaglio: added help and @header
    v:091227\s.zaglio: show results of tbl/qry as text table with col'autosize
    t:
        exec sp__select_astext '
            select top 10 id,name [name/test],crdate,cast(0x1221 as image) im
            from sysobjects order by [name/test] desc
            '
            ,@dbg=1
            ,@opt='html'
            ,@out='%temp%\sp__select_astext_test.htm'
        exec master..xp_cmdshell 'type %temp%\sp__select_astext_test.htm'
        exec master..xp_cmdshell 'del %temp%\sp__select_astext_test.htm'
    t:
        create table #src(lno int identity,line nvarchar(4000))
        truncate table #src
        exec sp__select_astext '
            select name,id [code],xtype,crdate
            from sysobjects
            order by code
            '
            ,@dbg=2
            ,@out='#src',@opt='html'
        select * from #src
        exec sp__email
            @to='stefano.zaglio@seltris.it',
            @body='#src',
            @from='sp__select_astext_test@seltris.it'
        drop table #src
        drop table #t
    t:
        select top 10 * into #t from sysobjects order by crdate desc
        select * from #t
        exec sp__select_astext 'select * from #t'
        exec sp__select_astext 'select * from #t order by id',@dbg=1
        exec sp__select_astext 'select * from #t order by 2 desc,uid, 1',@dbg=2
        drop table #t
    t:
        exec sp__select_astext '
            select name,id [code],xtype,crdate
            from sysobjects
            order by code
            ',@out='select'
*/
CREATE proc [dbo].[sp__select_astext]
    @what   nvarchar(max)=null,        -- table/view/select
    @out    sysname=null,
    @header tinyint=null,
    @sep    nvarchar(32)=null,
    @p1     sql_variant=null,
    @p2     sql_variant=null,
    @p3     sql_variant=null,
    @p4     sql_variant=null,
    @opt    sysname=null,
    @dbg    int=0
as
begin
set nocount on
declare
    @proc   sysname,
    @ret    int,
    @err    int,
    @id     int,
    @i      int,                        -- index
    @crlf   nvarchar(2),
    @cr     nvarchar(1),
    @lf     nvarchar(1),
    @tab    nvarchar(1),
    @tmp    sysname,                    -- name of ##tmp tables
    @html   bit,                        -- mark out as html
    @csep   nvarchar(255),              -- output column separator
    @chead  nvarchar(255),              -- column head separator
    @cfoot  nvarchar(255),              -- column footer sep.
    @sql    nvarchar(max),              -- dinamyc sql
    @oby    nvarchar(4000),             -- keep orderby clause
    @row    nvarchar(max),              -- final row select format
    @hth    nvarchar(4000),             -- html table header
    @hdr    nvarchar(4000),             -- header tmp string
    @hstyle nvarchar(4000),             -- html table header style
    @q      char(1),                    -- quote char '
    @dq     char(2),                    -- double quote char ''
    @declare_end bit

declare @src table(lno int identity primary key,line nvarchar(4000))

select
    @proc=object_name(@@procid),@crlf=crlf,@ret=0,
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|'),
    @cr=cr,@lf=lf,@tab=tab,@crlf=crlf
from dbo.fn__sym()

if @what is null goto help

if charindex('--',@what)>0 goto err_lce

-- normalize sql
select @what=dbo.fn__sql_normalize(@what,'sel')

-- replace parameters
if right(@what,1)='=' select @what=@what+convert(sysname,@p1,126),@p1=null
if not @p1 is null select @what=replace(@what,'{1}',convert(sysname,@p1,126))
if not @p2 is null select @what=replace(@what,'{2}',convert(sysname,@p2,126))
if not @p3 is null select @what=replace(@what,'{3}',convert(sysname,@p3,126))
if not @p4 is null select @what=replace(@what,'{4}',convert(sysname,@p4,126))
-- 120718\s.zaglio: aligned to sp__usage
if not @p1 is null select @what=replace(@what,'%p1%',convert(sysname,@p1,126))
if not @p2 is null select @what=replace(@what,'%p2%',convert(sysname,@p2,126))
if not @p3 is null select @what=replace(@what,'%p3%',convert(sysname,@p3,126))
if not @p4 is null select @what=replace(@what,'%p4%',convert(sysname,@p4,126))

if @dbg>0 exec sp__printsql @what

create table #html (lno int identity,line nvarchar(4000))   -- for html output
create table #cols (
    col sysname,                                            -- name
    typ sysname,                                            -- type
    pos smallint identity primary key,                      -- colord
    spos as cast(pos as varchar(5)),                        -- pos as string
    width smallint,                                         -- max col width
    swidth as cast(width as varchar(5)),                    -- width as string
    cst nvarchar(512),                                      -- cast code
    csep bit                                                -- if column separator
    )

-- init constants/vars
select
    @q     ='''',
    @dq    ='''''',
    @html  =case
            when charindex('|html|',@opt)>0 then 1
            when right(@out,4)='.htm' then 1
            when right(@out,5)='.html' then 1
            else 0
            end,
    @header=isnull(@header,
            case
            when charindex('|h|',@opt)>0 then 1
            when charindex('|noh|',@opt)>0 then 0
            else 2
            end),
    @csep  =case @html
            when 1 then '</td><td>'
            else isnull(replace(@sep,@q,@dq),' ')
            end,
    @chead =case @html when 1 then '<tr><td>' else '' end,
    @cfoot =case @html when 1 then '</td></tr>' else '' end,
    @hth   ='<table width="100%" '+
            'border="1" width="100%" cellspacing="0" cellpadding="2" '+
            'style="border-collapse: collapse;'+
            'font-size:10pt;font-family:arial'+
            '">',
    @hstyle='background-color:darkgray;color:white;text-align:center;'+
            'font-size:120%;font-size:120%;font-weight:bold;font-style:italic'

-- hive off sql pieces of code
select @i = charindex(' order by ',@what)
if @i>0
    select @oby=substring(@what,@i+10,4000),@what=left(@what,@i)
else
    select @oby=''

select @i = charindex(' union ',@what)
if @i>0
    begin
    if charindex('(',@what)>@i
    or charindex(')',@what,@i)=0
        select @what='select * from ('+@what+') a'
    end

select @i = dbo.fn__charindex(' from ',@what,-1) -- @i is used below near INTO
if @i=0 goto err_from

if charindex('|#src|',@opt)>0 select @out='#src'
if charindex('|#out|',@opt)>0 select @out='#out'
if charindex('|p4|',  @opt)>0 select @out=convert(nvarchar(512),@p4)

-- create tmp table 1
select
    @tmp='##tmp'+replace(convert(sysname,newid()),'-',''),
    @sql=left(@what,@i)+' into '+@tmp
        +substring(@what,@i,len(@what))
        +case @oby when '' then '' else ' order by '+@oby end
exec(@sql)
select @err=@@error,@id=@@identity

if @err!=0
    begin
    exec sp__printf @sql
    goto err_sql
    end
if @dbg>0 exec sp__printsql @sql

-- get flds info
insert #cols(col,typ,csep,width)
select c.name,t.name,1,len(c.name)
from tempdb..syscolumns c
join tempdb..systypes t
on c.xusertype=t.xusertype
where c.id=object_id('tempdb..'+@tmp)
and t.name!='image'
update #cols set csep=0 where pos=@@identity

-- due the final select a+b+c.. the order by n fail because n can be only 1
-- we split order by fields and replace it with names
if @oby!=''
    begin
    declare @obyf table(
        pos int,
        fld nvarchar(4000),
        nfld nvarchar(4000),
        ord sysname,
        sep char(1)
        )
    insert @obyf(
        pos,
        fld,
        ord,
        sep
        )
    select
        pos,
        dbo.fn__str_at(ltrim(rtrim(token)),' ',1),
        isnull(dbo.fn__str_at(ltrim(rtrim(token)),' ',2),''),
        ','
    from dbo.fn__str_table(@oby,',')
    order by pos
    update @obyf set sep='' where pos=(select max(pos) from @obyf)

    if @dbg>0 exec sp__printf '@oby:%s',@oby

    update tbl set
        nfld=(select a.col
              from #cols a
              where a.spos=tbl.fld collate database_default)
    from @obyf tbl
    where isnumeric(tbl.fld)=1

    -- recompound clause
    select @oby=''
    select @oby=@oby+isnull(nfld,fld)+' '+ord+sep from @obyf order by pos
    select @oby=' order by '+@oby

    if @dbg>1 select '@obyf' tbl,* from @obyf
    if @dbg>0 exec sp__printf '@oby:%s',@oby

    end -- order by

-- set casting (note: can be optimized more)
update #cols set cst=
    'isnull('+case
    when typ in ('text','ntext')
    then 'substring('+quotename(col)+',1,4000)'
    when typ like '%char'
    then quotename(col)
    when typ like '%date%' or typ like '%time%'
    then 'convert(nvarchar(4000),'+quotename(col)+',126)'
    else 'cast('+quotename(col)+' as nvarchar(4000))'
    end+','''')'

-- calculate max width of each column
select @sql=null
select @sql=isnull(@sql+',','declare ')+'@c'+spos+' smallint'
from #cols
select @sql=@sql++@crlf+'select '
select @sql=@sql+' @c'+spos+'=max(len('+cst+'))'
                +case csep when 1 then ',' else '' end
from #cols
select @sql=@sql+'from '+@tmp+@crlf
select @sql=@sql+'update #cols set width='
                +'case '+
                +'when @c'+spos+'>width then @c'+spos+' '
                +'else width end '    -- if width of header is greater
                +'where pos='+spos+@crlf
from #cols

if @dbg>0 exec sp__printsql @sql
exec(@sql)
select @err=@@error

if @err!=0
    begin
    exec sp__printf @sql
    goto err_sql
    end


if @dbg>1 select '#col' tbl,* from #cols

-- prepare header table for txt out
if @html=0
    begin
    select @hdr=''
    select @hdr=@hdr+left(col+replicate(' ',width),width)
               +case csep when 1 then @csep else '' end
    from #cols
    order by pos
    select @hdr=rtrim(@hdr)             -- optimization
    end -- txt headers

-- =================================================================== output ==

-- compound final select row
select @row=''
if @html=1
    select  @row = @row
            +cst
            +case csep when 1 then '+'''+@csep+'''+' else '' end
    from #cols
    order by pos
else
    select  @row = @row
            +case swidth
             when '0' then ''
             else 'cast('+cst+' as nchar('+swidth+'))'
             end
            +case csep when 1 then '+'''+@csep+'''+' else '' end
    from #cols
    order by pos

-- add row header and footer
select @row=@q+@chead+'''+'+@row+'+'''+@cfoot+@q

if @dbg>0 exec sp__printsql @row

-- output middle table if dbg
if @dbg>1 exec('select '+@row+' from '+@tmp+@oby)

if @dbg>0 exec sp__printf '-- print'

if @html=0
    begin
    if @out is null
        begin
        if @header in (1,2) print @hdr
        select @sql='
        declare @line nvarchar(4000)
        declare c cursor local for
        select rtrim('+@row+') collate database_default as line
        from '+@tmp+@oby+'
        open c
        while (1=1)
            begin
            fetch next from c into @line
            if @@fetch_status!=0 break
            -- print dbo.fn__str_print(@line)
            print @line
            end
        close c
        deallocate c
        '
        if @dbg>0 exec sp__printf @sql
        exec(@sql)
        select @err=@@error
        if @err!=0
            begin
            exec sp__printf @sql
            goto err_sql
            end

        if @header=2 print @hdr
        end -- print
    else
        begin
        if @out='select'
            begin
            if @header in (1,2) insert @src select @hdr
            insert @src exec('select rtrim('+@row+') line from '+@tmp+@oby)
            if @header in (1,2) insert @src select @hdr
            select line from @src order by lno
            end
        else -- insert to table
            begin
            select @sql=''
            if @header in (1,2)
                select @sql='insert into '+@out+'(line) '
                           +'values('''+replace(@hdr,'''','''''')+''')'
                           +@crlf
            select @sql = @sql
                        + ';insert into '+@out+'(line) '
                        + 'select rtrim('+@row+') as line '
                        + 'from '+@tmp+@oby
            if @header in (1,2)
                select @sql=@crlf+@sql+
                           +';insert into '+@out+'(line) '+
                           +'values('''+replace(@hdr,'''','''''')+''')'
            exec(@sql)
            select @err=@@error

            if @err!=0
                begin
                exec sp__printsql @sql
                goto err_sql
                end

            end
        end -- @out
    end -- no html
else
    begin  -- is html
    insert #html select @hth

    -- insert header
    select @hdr=''
    select @hdr=@hdr+'<th>'+col+'</th>' from #cols order by pos
    select @hdr='<thead style="'+@hstyle+'"><tr>'+@hdr+'</tr></thead>'
    insert #html select @hdr

    select @sql ='insert into #html(line) '
                +'select '+@row+' as line '
                +'from '+@tmp+@oby
    exec(@sql)
    select @err=@@error,@id=@@identity
    if @header=2
        update #html set line=replace(line,'<tr>','<tr style="'+@hstyle+'">')
        where lno=@id

    if @err!=0
        begin
        exec sp__printf @sql
        goto err_sql
        end

    insert #html select '</table>'
    if @out is null
        begin
        if @dbg>0 exec sp__printf '-- out to:text as html'
        exec sp__print_table '#html'
        end
    else
        begin
        if @out='select'
            begin
            if @dbg>0 exec sp__printf '-- out to:select as html'
            exec('select line from #html order by lno')
            end
        else
            begin
            if left(@out,1)='#'
                begin
                if @dbg>0 exec sp__printf '-- out to:#table as html'
                select @sql ='insert into '+@out+'(line) '
                            +'select line '
                            +'from #html '
                            +'order by lno'
                exec(@sql)
                select @err=@@error

                if @err!=0
                    begin
                    exec sp__printf @sql
                    goto err_sql
                    end

                end
            else
                begin
                if @dbg>0 exec sp__printf '-- out to:file as html'
                exec @ret=sp__file_write @out,@table='#html'
                -- the below add chars at top of text that are not
                -- correctly readed
                -- exec @ret=sp__file_write_stream @out,@opt='html'
                end
            end
        end
    end -- out

if @err!=0 goto err

dispose:
drop table #html
exec('drop table '+@tmp)

goto ret

-- =================================================================== errors ==
err:        goto ret
err_len:    exec @ret=sp__err 'null len',@proc goto ret
err_ofm:    exec @ret=sp__err 'out of memory string',@proc goto ret
err_lce:    exec @ret=sp__err 'line comment -- illegal',@proc goto ret
err_from:   exec @ret=sp__err 'cluase FROM absent',@proc goto ret
err_sql:    exec @ret=sp__err 'bad sql code',@proc goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'

Parameters:
    @what   can be a table or a query (use top clause)
    @out    can be a #table or .htm/.html file
            if "select", return as select
    @p1...  replace "%p1%","%p2%",... in @what befor execute
            (retro-compatible with {1},{2}...)
    @header default is 2 and
            * when txt out:
            0 do not print
            1 print header as name of columns
            2 print footer as name of columns
            * when htm out:
            0 do not add headers
            1 add highlighted header as name of columns
            2 highlight last row
    @opt    options
            html    return a <table>...</table> structure
                    * can be combined with @out
                    * implicit if @out end with .htm...
            #src    set out to this table
            #out    set out to this table
            p4      (experimental)set @out to @p4
            h       show only top header
            noh     do not show any header
    @dbg    1 print inside code
            2 show mid table content

Notes
    * order by is applied on result query so in:
        select fld1 as [a] from tbl order by fld1
      must become:
        select fld1 as myname from tbl order by myname
    * FROM clause must be present
'
select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end -- sp__select_astext