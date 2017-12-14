/*  leave this
    l:see LICENSE file
    g:utility
    k:move,back,history,historicize
    v:130802.1800\s.zaglio: adapted to new sp__script_template
    v:121122\s.zaglio: log n moved instead of @top
    v:121107\s.zaglio: added nolock near count(*)
    v:121003\s.zaglio: used sp__flds_list to follow synonyms
    v:121002\s.zaglio: follow the synonyms of tables using sp__script_pkey
    v:120921\s.zaglio: better skip when single table
    v:120920\s.zaglio: abount log times of @top instead of @n
    v:120919\s.zaglio: due runtime errors, some correction to aliases
    v:120918\s.zaglio: done a compilable version without errors
    r:120917\s.zaglio: adopting sp_select_asform
    r:120913\s.zaglio: modifing template and correct sp__script_template
    r:120912\s.zaglio: modifing template
    d:120910\s.zaglio: sp__script_copy
    r:120910\s.zaglio: removed tag opt. and converting in multi tab.
    r:120903\s.zaglio: changing to multi table
    v:120828\s.zaglio: added tag option
    v:120827\s.zaglio: added log of times
    v:120820\s.zaglio: added @ms... vars
    v:120810\s.zaglio: done
    r:120809\s.zaglio: script copy or move data
    t:sp__script_move_test @dbg=1
*/
CREATE proc sp__script_move
    @tbls nvarchar(4000) = null,    -- sa|sb|sc
    @dsts nvarchar(4000) = null,    -- da|db|dc
    @joins nvarchar(max) = null,    -- sa.id=sb.rid|sb.id=sc.rid
    @where nvarchar(4000) = null,   -- dt>...
    @order sysname = null,
    @top sysname = null,
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp
declare
    @proc sysname, @err int, @ret int, -- @ret: 0=OK -1=HELP, any=error id
    @e_msg sysname, @e_p1 sysname

select
    @dbg=0,
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

-- ========================================================= param formal chk ==

select
    -- @tbl=   dbo.fn__sql_normalize(@tbl,default),
    -- @dst=   dbo.fn__sql_normalize(@dst,default),
    @where= dbo.fn__sql_normalize(@where,default),
    @order= dbo.fn__sql_normalize(@order,'ord'),
    @top=   dbo.fn__sql_normalize(@top,'top'),
    @joins= case when ltrim(rtrim(@joins))='|'
                 then ''
                 else isnull(@joins,'')
            end

if left(@top,1)='#' goto err_top

if dbo.fn__str_count(@tbls,'|')!=dbo.fn__str_count(@tbls,'|') goto err_dp1
if @joins!=''
and dbo.fn__str_count(@tbls,'|')!=dbo.fn__str_count(@joins,'|') goto err_dp2

-- ============================================================== declaration ==
declare
    @i int,@j int,
    @tbl sysname,@dst sysname,
    @dst_db sysname,
    @dst_tbl sysname,
    @pkey nvarchar(4000),               -- list of pk fields
    @on_pkeys nvarchar(4000),           -- list of tbl.pkf1=tmp.pkf1 and ...
    @excludes sysname,
    @notrg bit, @copy bit, @back bit,   -- options
    @idx bit,                           -- options
    @flds nvarchar(4000),               -- fields
    @tbl_flds nvarchar(4000),           -- fields with tbl. prefix
    @lbl sysname,                       -- local label for goto
    @keys sysname,                      -- #tmp table name for keys of @tbl
    @src bit,                           -- 1=return results into #src, 0=print
    @ntop sysname,                      -- value of @top
    @log sysname,                       -- name of log table
    @join_on nvarchar(1024),            -- on condition
    @alias sysname,@join sysname,
    @tmp sysname,
    @mix sysname,                       -- inner sp
    @id int,
    @end_declare bit

create table #tpl(
    lno int identity primary key,
    line nvarchar(4000)
    ,procid int default(@@procid)
    )
create table #tpl_sec(
    lno int identity,
    section sysname,
    line nvarchar(4000)
    ,procid int default(@@procid)
    )
create table #tpl_cpl(tpl binary(20),section sysname,y1 int,y2 int)

if exists(select top 1 null from #tpl) goto err_tpl

create table #vars (id nvarchar(16),value sql_variant)

if object_id('tempdb..#src') is null
    begin
    create table #src(lno int identity primary key,line nvarchar(4000))
    select @src=0
    end
else
    select @src=1

create table #joins(
    id int identity,
    src sysname,
    alias sysname,
    dst sysname,
    [join] nvarchar(4000) null,
    join_on nvarchar(4000),
    [pkey] nvarchar(1024) null,
    keys nvarchar(1024) null,
    [on_pkeys] sysname null,
    [main] sysname null,
    [main_alias] sysname null,
    dst_flds nvarchar(4000) null,
    tbl_flds nvarchar(4000) null,
    lbl sysname null -- normalized rtbl for skip_
    )

-- =========================================================== initialization ==

select
    @mix='#mix',
    @back =charindex('|back|',@opt),
    @notrg=charindex('|notrg|',@opt),
    @copy =charindex('|copy|',@opt),
    @idx  =charindex('|idx|',@opt),
    @log  =isnull(dbo.fn__str_between(@opt,'log:','|',default),
                  'tmp_script_copy_log'
                 ),
    @excludes='',
    @excludes=@excludes+case @copy  when 1  then '|move' else '' end,
    @excludes=@excludes+case @notrg when 1  then '|trgs' else '' end,
    @excludes=@excludes+case @dbg   when 0  then '|dbg'  else '' end,
    @excludes=@excludes+case @idx   when 0  then '|idxs' else '' end,
    @ntop=dbo.fn__Str_between(@top,'(',')',default),
    @top=replace(@top,@ntop,'@top')

-- load local template
exec sp__Script_templates 'move'

-- insert before here --  @end_declare=1
-- ======================================================== second params chk ==

insert into #joins(alias,src,dst,join_on)
select
    alias=case charindex(':',src.token)
          when 0 then src.token
          else left(src.token,charindex(':',src.token)-1)
          end,
    src=case charindex(':',src.token)
        when 0 then src.token
        else substring(src.token,charindex(':',src.token)+1,128)
        end,
    dst.token,
    isnull(replace(replace(jj.token,'|',' and '),'"',''''),'')
from dbo.fn__str_split(@tbls,'|') src
left join dbo.fn__str_split(@dsts,'|') dst on src.pos=dst.pos
left join dbo.fn__str_split(@joins,'|') jj on jj.pos=dst.pos

update #joins set lbl=dbo.fn__format(alias,'AN',default)

-- extract table from join_on
declare cs cursor local for
    select id,src,alias,join_on from #joins order by id
open cs
while 1=1
    begin
    fetch next from cs into @id,@tbl,@alias,@join_on
    if @@fetch_status!=0 break

    -- 121002\s.zaglio: will follow synonyms
    exec sp__script_pkey @pkey out,@tbl,@sep=',',@opt='flds'
    if @pkey is null goto err_pk
    exec sp__flds_list @flds out,@tbl,','
    -- exec sp__printf 'tbl:%s pkey:%s flds:%s',@tbl,@pkey,@flds

    select
        @keys='#keys_'+lower(dbo.fn__format(@tbl,'ANs',default)),
        @pkey=dbo.fn__flds_quotename(@pkey,','),
        @on_pkeys=replace(dbo.fn__str_exp(@alias+'.%%=tmp.%%',@pkey,','),
                          ',',' and '
                         ),
        @tbl_flds=dbo.fn__str_exp(@alias+'.%%',@flds,','),
        @join=','

    -- extra tables/aliases from joins
    if @joins=''
        select @join=@tbl,@join_on=@keys
    else
        begin
        select @i=charindex('.',@join_on)
        while @i>0
            begin
            select @j=@i-1
            while @j>0 and not substring(@join_on,@j,1) like '[[ =,]' select @j=@j-1
            select @alias=substring(@join_on,@j+1,@i-@j-1)
            select @tmp=src from #joins where @alias in (alias,src)
            if charindex(','+@tmp+',',@join)=0 and @tmp!=@tbl
                select @join=@join+@tmp+','
            select @i=charindex('.',@join_on,@i+1)
            end
        if @join = ','
            select @join=@tbl
        else
            select @join=substring(@join,2,len(@join)-2)
        end

    update #joins set
        [join]=@join,
        join_on=@join_on,
        pkey=@pkey,
        [keys]=@keys,
        on_pkeys=@on_pkeys,
        -- template tokens do not support crlf
        -- dst_flds=dbo.fn__str_flow(@flds,',',default),
        -- tbl_flds=dbo.fn__str_flow(@tbl_flds,',',default),
        dst_flds=@flds,
        tbl_flds=@tbl_flds,
        main=src, main_alias=alias
    where id=@id

    end -- cursor cs
close cs
deallocate cs

-- select @proc sp,* from #joins

if exists(
    select null
    from #joins
    where object_id(src) is null or object_id(dst) is null
    )
    goto err_tbl

if @joins!=''
and exists(
    select null
    from #joins
    where isnull(join_on,'')=''
    and id!=1
    )
    goto err_jn

if @tbls is null or @dsts is null or @where is null -- and @opt='||'
    goto help

-- if joins are specified the 1st table is the main table
if @joins!=''
    begin
    update #joins set [join]=keys,[join_on]=on_pkeys where id=1
    update j set
        j.keys=jj.keys,
        j.on_pkeys=jj.on_pkeys,
        j.main=jj.src,
        j.main_alias=jj.alias
    from #joins j
    join #joins jj on j.[join]=jj.src
    -- where j.id!=1
    end

-- select @proc sp,* from #joins


-- ===================================================================== body ==
-- common info
insert #vars select '%top%',@top
insert #vars select '%ntop%',@ntop
insert #vars select '%where%',@where
insert #vars select '%orderby%',@order
insert #vars select '%log%',@log
exec sp__select_asform '#joins','id=1',@opt='#vars'

if not object_id('tempdb..'+@mix) is null drop proc #mix

exec('create proc '+@mix+' @section sysname,@excludes sysname=null,@dbg int=0
      as
      select @excludes='''+@excludes+'''+isnull(''|''+@excludes,'''')
      exec sp__script_template
        @section,
        @opt=''replace"'',
        @excludes=@excludes
        ,@dbg=@dbg
    ')

-- manually expand %log_times% for problem with backward compatibility
exec sp__script_template '%log_times_section%','%log_times%'
exec sp__script_template '%log_commit_section%','%log_commit%'

exec @mix '%header%',@dbg=@dbg
if @joins!='' exec @mix '%begin%',@dbg=@dbg

-- select @proc sp,* from #joins

declare cs cursor local for
    select
        id,src,dst,alias,join_on,[join],pkey,keys,on_pkeys
    from #joins
    -- from last because main table is used in join with details
    order by id desc
open cs
while 1=1
    begin
    fetch next from cs into
        @id,@tbl,@dst,@alias,@join_on,@join,
        @pkey,@keys,@on_pkeys
    if @@fetch_status!=0 break

    select @where='id='+cast(@id as sysname)
    exec sp__select_asform '#joins',@where,@opt='#vars'

    if @joins=''
        exec @mix '%body_single_table%',@dbg=@dbg
    else
        begin
        select @excludes=case @id when 1 then 'main' else null end
        exec @mix '%body_group%',@excludes,@dbg=@dbg
        end
    end -- cursor cs
close cs
deallocate cs

if @joins!='' exec @mix '%end%',@dbg=@dbg
exec @mix '%footer%',@dbg=@dbg
-- if @back=1 exec @mix '%back%'
exec @mix '%catch%',@dbg=@dbg

drop proc #mix

if @src=0 exec sp__print_table '#src'

goto ret

-- =================================================================== errors ==
err:        exec @ret=sp__err @e_msg,@proc,@p1=@e_p1                    goto ret
err_top:    select @e_msg=@top                                          goto err
err_pk:     select @e_msg='table %s without primary key',@e_p1=@tbl     goto err
err_tbl:    select @e_msg='source table not found'                      goto err
err_jn:     select @e_msg='some join are not specified'                 goto err
err_tpl:    select @e_msg='a tpl already exists from parent proc'       goto err
err_dp1:    select @e_msg='@dsts count is different from @tbls'         goto err
err_dp2:    select @e_msg='@joins count is differente from @tbls'       goto err
goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    create a script to copy rows from tables to their copy;
    can move related data if @where contain joins conditions.
    can be used to historicize data

Parameters
    (*)         duty parameters
    #src        if present, store result here
    @tbls       (*)source tables names separated by "|";
                aliases must prefixed with ":" (ex: "A1:ARCHIVE1")
    @dsts       (*)destination table (must in the same order of sources)
    @joins      when more than one table is involved, can/must be joined
                using these expressions, separated by "|"
    @where      (*)condition that split tables into data to move and
                data to keep back from history
    @order      optional order by condition
    @top        optional top rows (n) or percent (n%)
    @opt        options
                run     run the script immediatelly
                sel     return results as select
                copy    copy only, do not delete original rows
                notrg   do not disable triggers
                back    reverses @where and  move back data
                        from destination to original table
                idx     include disable and then rebuild of indexes
                nfo     print count of moved rows and store times into log table:
                        create table %log%(
                            dt datetime,
                            tbl sysname,
                            n int,
                            ms_key int,
                            ms_alt int,
                            ms_ins int,
                            ms_del int,
                            ms_commit int
                            )
                log:tbl store log info into table tbl instead of
                        default tmp_script_copy_log

Notes
    A check of number of lines moved, to prevent move of all data, will be done.

See
    sp__script_align

Examples
    -- move single table
    sp__script_move @tbls = "tbl",
                    @dsts = "history..tbl",
                    @where = "not dt<getdate()-30",
                    @order = "dt",
                    @top = 4000,
                    @opt = "back|move|nfo"
                    ,@dbg=1

    -- move multiple table
    sp__script_move @tbls = "T1:tbl1|T2:tbl2|T3:tbl3",
                    @dsts = "H1|H2|H3",             -- this are synonyms
                    @joins= "|T2.rid=T1.id|T3.rid=T2.id",
                    @where = "not dt<getdate()-30",
                    @order = "dt",
                    @top = 4000,
                    @opt = "back|move|nfo"
                    ,@dbg=1
    /*  results is
        T1.pkeys -> #k
        move T1 from T1+#k
        move T2 from T1+#k+T2
        move T3 from T1+#k+T2+T3                    -- note this
    */

    sp__script_move @tbls = "T1:tbl1|T2:tbl2|T3:tbl3",
                    @dsts = "H1|H2|H3",           -- this are synonyms
                    @joins= "T1.id=T2.rid|T1.id=T3.rid",
                    @where = "not dt<getdate()-30",
                    @order = "dt",
                    @top = 4000,
                    @opt = "back|move|nfo"
                    ,@dbg=1
    /*  results is
        T1.pkeys -> #k
        move T1 from T1+#k
        move T2 from T1+#k+T2
        move T3 from T1+#k+T3                       -- note this
    */
'

select @ret=-1
-- ===================================================================== exit ==
ret:
return @ret

end -- sp__script_copy