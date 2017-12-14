/*  leave this
    l:see LICENSE file
    g:utility
    k:test,conflict,difference,upgrade
    v:140204\s.zaglio:better error management
    v:140116.1100\s.zaglio:added better compare output, help and use of context info
    v:140108.1518\s.zaglio:set of default @tcc to 10 and added ovr option
    v:131216.1500\s.zaglio:added STRICT option and correct a bug near compare
    v:131215\s.zaglio:refactor and added relaxed check of ver without .hhmm
    v:131210.1000\s.zaglio:compare for @tcc common comments and overwrite dst
    v:131103\s.zaglio:a bug when pair conflict\common (conflict===update)
    v:131018.1210\s.zaglio:added SD option and removed initial blnk lines
    v:130908.0100\s.zaglio:converted to update utility
    r:121006\s.zaglio:replacing script header template
    t:sp__script_update_test @dbg=2
*/
CREATE proc sp__script_update
    @src nvarchar(max) = null,
    @db  sysname = null,
    @tcc int = null,
    @opt sysname = null,
    @dbg int=0
as
begin try
set nocount on

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    @err_msg nvarchar(2000),@err_sev int-- used before raise

-- ======================================================== params set/adjust ==
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=nullif(@opt,''),
    @opt=case when @opt is null then '||' else dbo.fn__str_quote(@opt,'|') end

-- ============================================================== declaration ==
declare
    -- object and its type
    @obj sysname,@t_type nvarchar(4),
    @sch sysname,@params sysname,           -- used by sp_executesql
    -- new object info
    @pcmd int,                              -- create/alter position
    @cmd sysname,                           -- create/alter
    @otype sysname,                         -- proc/func/...
    @t_obj_id int,                          -- target object id
    -- local vars
    @tag char,
    @s_obj sysname,                         -- sub object commodity
    @ver sysname,                           -- version commodity
    @sql nvarchar(max),                     -- sql commodity
    @dst nvarchar(max),                     -- destination/target src
    @drop nvarchar(4000),
    @crlf nvarchar(2),
    @sp__update_log sysname,
    @sp__update_log_id int,
    @threshold_last_cmt tinyint,            -- see below
    @cmts_min_distance tinyint,             -- see below
    @n int,@m int,
    -- options
    @test bit,@sd bit,@strict bit,@ovr bit,
    -- status
    @sts char,
    @st_common tinyint,
    @st_conflict tinyint,
    @st_update tinyint,                       -- target(correct) update
    @st_left_update tinyint,                  -- new il order
    @st_err tinyint,
    @st_unk tinyint,

    @end_declare bit

declare @nfo table (
    tag varchar(4),row smallint,
    val1 sysname,val2 sysname,val3 sysname
    )

declare @cmprs table(
    row int,
    b_ver numeric(10,4),
    m_ver numeric(10,4),
    diff float,
    t_row smallint,n_row smallint,
    t_ver numeric(10,4) null,n_ver numeric(10,4) null,
    t_aut sysname null,n_aut sysname null,
    t_cmt nvarchar(512) null,n_cmt nvarchar(512) null,
    sts tinyint null
    )

-- target or current object info
declare @dst_nfo table(
    row smallint not null,
    ver numeric(10,4) null,
    aut nvarchar(4000) null,
    cmt nvarchar(4000) null,
    hhmm bit not null,
    tick smallint,                  -- sub sequence when doubled version
    lrow smallint
    )

-- source or new object info
declare @src_nfo table(
    row smallint not null,
    ver numeric(10,4) null,
    aut nvarchar(4000) null,
    cmt nvarchar(4000) null,
    hhmm bit not null,
    tick smallint,                  -- sub sequence when doubled version
    diff float,                     -- distance between dst.val3 and src.val3
    lrow smallint
    )

-- =========================================================== initialization ==

if @db is null select @db=db_name()
select
    @tcc=isnull(@tcc,10),           -- this values is from experience and must
                                    -- be modified only if very sure
    @threshold_last_cmt = 3,        -- same above consideration
    @cmts_min_distance  = 4,        -- same of above
    @crlf=crlf,
    @test=charindex('|test|',@opt),
    @sd=charindex('|sd|',@opt),
    @strict=charindex('|strict|',@opt),
    @ovr=charindex('|ovr|',@opt)|dbo.fn__context_info(@proc+':ovr'),
    @st_unk=0,
    @st_common=1,
    @st_update=2,
    @st_conflict=3,
    @st_left_update=4,
    @st_err=5
from fn__sym()

-- ======================================================== second params chk ==

if nullif(@src,'') is null goto help

-- =============================================================== #tbls init ==

select @sp__update_log_id=isnull(object_id('tempdb..#sp_update_log'),0)
if @sp__update_log_id=0 -- if not defined outside
    begin
    exec('create proc #sp__update_log
                        @obj sysname,
                        @st char,
                        @msg nvarchar(2000) = null
          as
          declare @sev int
          select @sev=10
          if not object_id(''tempdb..#update_log'') is null
            insert #update_log(obj,msg,sts)
            select @obj,@msg,@st
          -- Updated,New,Same,Older,Conflict,Error
          select @msg=case @st when ''E'' then @msg
                               when ''U'' then ''updated-re-created''
                               when ''N'' then ''new-created''
                               when ''S'' then ''same-not replaced''
                               when ''O'' then ''older-not replaced''
                               when ''C'' then ''conflict''+
                                               isnull('':''+@msg,'''')
                               end
          if @st=''C'' select @sev=11
          if @st=''E'' select @sev=16
          select @msg=@obj+'':''+@msg
          raiserror(@msg,@sev,1)
         ')
    end

select @sp__update_log='#sp__update_log'

-- ===================================================================== body ==
/* get object name
    proc
    func
    view
    tabl
    syno
*/

if @dbg>0 exec sp__printf '-- %s: debugging level:%d',@proc,@dbg

-- ================================================= get info from new script ==

-- remove initial blank lines
while left(@src,1) like '[%'+@crlf+'%]' select @src=stuff(@src,1,1,'')

insert @nfo
select tag,row,val1,val2,val3
from fn__script_info_tags(@src,'ad#',default)

if @dbg>1 select 'new' [?],* from @nfo

select @obj=parsename(val3,1),@pcmd=row,@cmd=val1,@otype=val2
from @nfo where tag='#'

if @cmd!='create' raiserror('command "%s" not managed',16,1,@cmd)
if not @otype in ('proc','procedure','func','function','view','trigger')
    begin
    select @err_msg='object type "'+@otype+'" not managed'
    exec @sp__update_log @obj,'E',@err_msg
    end

-- ============================================== get info from target object ==
-- target object cannot be locked, so do not use (nolock)
select @dst='
use [%db%]
select @id=o.object_id, @type=o.[type],@code=m.definition,@sch=sch
from (
    select object_id,name,type,object_schema_name(object_id) sch
    from sys.objects
    where name="%obj%"
    union
    select object_id,name,type,object_schema_name(object_id) sch
    from sys.triggers
    where name="%obj%"
    ) o
join sys.all_sql_modules m on o.object_id=m.object_id
'

exec sp__str_replace @dst out,'"|%db%|%obj%','''',@db,@obj

select @params=N'@id int out,@type nvarchar(4) out,@code nvarchar(max) out,'
              +N'@sch sysname out'

exec sp_executesql
        @dst,
        @params,
        @id=@t_obj_id out,@type=@t_type out,@code=@dst out,@sch=@sch out

if @t_obj_id is null
    begin
    select @sts='N' -- new
    goto do_action
    end

-- ================================================================== compare ==

if @ovr=1
    begin
    exec sp__printf '-- OVERRIDE option enabled'
    select @sts='U'
    goto do_action
    end

begin try

    insert into @dst_nfo(ver,aut,cmt,row,hhmm,tick,lrow)
    select
        cast(ver as numeric(10,4)),aut,cmt,
        row,hhmm,
        row_number() over (partition by ver,aut order by ver,row desc)-1 as tick,
        row_number() over (order by row)-1 as lrow
    from (
        -- convert aaaammgg.hhmm to aammgg.hhmm
        select case
               when val1<999999
               then val1
               else val1-cast(val1/1000000 as int)*1000000
               end as ver,val2 as aut,val3 as cmt,row,hhmm
        from (
            select
                cast(val1 as numeric(12,4)) as val1,val2,val3,
                row,charindex('.',val1) as hhmm
            from fn__script_info_tags(@dst,'rv',default)
            where isnumeric(val1)=1 -- skip non coerent comments
            ) nfo
        ) nfo
    order by row
    select @m=@@rowcount

    insert into @src_nfo(ver,aut,cmt,row,hhmm,tick,lrow)
    select
        cast(ver as numeric(10,4)),aut,cmt,
        row,hhmm,
        row_number() over (partition by ver,aut order by ver,row desc)-1 as tick,
        row_number() over (order by row)-1 as lrow
    from (
        -- convert aaammgg.hhmm to aammgg.hhmm
        select case
               when val1<999999
               then val1
               else val1-cast(val1/1000000 as int)*1000000
               end as ver,val2 as aut,val3 as cmt,row,hhmm
        from (
            select
                cast(val1 as numeric(12,4)) as val1,val2,val3,
                row,charindex('.',val1) as hhmm
            from fn__script_info_tags(@src,'rv',default)
            where isnumeric(val1)=1 -- skip non coerent comments
            ) nfo
        ) nfo
    order by row
    select @n=@@rowcount

    if @n=0 exec @sp__update_log @obj,'E','cannot identify source properties'
    if @m<2 -- if destination has not comments
        begin
        select @sts='U'
        goto do_action
        end

    -- some automatic adjustements to prevent user's fortuity
    if @strict=0
        begin
        -- correct dates with .0000 binding to comment
        update @src_nfo set ver=ver+tick/10000.0 where hhmm=0
        update @dst_nfo set ver=ver+tick/10000.0 where hhmm=0

        -- adjust similar comments
        update src set diff=dbo.fn__str_distance(src.cmt,dst.cmt,default)
        from @src_nfo src
        join @dst_nfo dst on src.ver=dst.ver and src.aut=dst.aut

        if @dbg>2
            begin
            select '@src_info' tbl,* from @src_nfo order by row
            select '@dst_info' tbl,* from @dst_nfo order by row
            end

        end -- relaxed or strict=0

    ;with
        compare as
        (
        select isnull(t_ver,n_ver) m_ver,*
        from (
            select
                t.row as t_row,
                n.row as n_row,
                t.ver as t_ver,
                t.aut as t_aut,
                t.cmt as t_cmt,
                n.ver as n_ver,
                n.aut as n_aut,
                n.cmt as n_cmt,
                case when
                    n.lrow=0 and t.lrow=0               -- only last row
                    and n.ver-t.ver between 0 and 1     -- same date
                    and n.aut=t.aut                     -- same author
                    and dbo.fn__str_distance(n.cmt,t.cmt,default)
                        <
                        len(n.cmt)/@cmts_min_distance
                then 0
                else
                    dbo.fn__str_distance(n.cmt,t.cmt,default)
                end as diff
            from @dst_nfo as t                      -- target/current version
            full join @src_nfo as n                 -- source/new version
            on t.ver=n.ver and t.aut=n.aut          -- aligned by datetime and author
            or (-- or is a last ...
                n.lrow=0 and t.lrow=0
                -- ... daily change ...
                and n.ver-t.ver between 0 and 1
                -- ... by same user ...
                and n.aut=t.aut
                -- ... with a small change
                and dbo.fn__str_distance(n.cmt,t.cmt,default)
                    <
                    len(n.cmt)/@cmts_min_distance
                )
            ) a
        ),

        -- find 1st common base ver
        base_ver(b_ver) as
        (
        -- select the older
        select top 1 b_ver
        from (
            -- take last 4 common comments
            select top (@tcc) t_ver as b_ver
            from compare
            where t_ver=n_ver
            order by m_ver desc
            ) commons
        order by b_Ver
        )

    insert into @cmprs(
        row,b_ver,m_ver,diff,t_row,n_row,t_ver,n_ver,t_aut,n_aut,t_cmt,n_cmt,sts
        )
    select
        row_number() over(order by m_ver desc),
        (select top 1 b_ver from base_ver) as b_ver,
        m_ver,diff,t_row,n_row,t_ver,n_ver,t_aut,n_aut,t_cmt,n_cmt,
        case
        -- do not change order of whens
        when (not n_cmt is null and t_cmt is null)
          or (diff=0 and t_cmt!=n_cmt) then @st_update
        when (n_cmt is null and not t_cmt is null) then @st_left_update
        when (diff<=@cmts_min_distance) then @st_common
        when (diff>@cmts_min_distance) then @st_conflict
        else @st_err
        end sts
    from compare
    where m_ver>=(select top 1 b_ver from base_ver)
    order by m_ver desc -- merged version

end try
begin catch
    -- possible fn__script_info_tags error
    if @dbg>1 exec sp__printsql @dst
    select @err_msg=left(error_procedure(),len(@sp__update_log))
    if @err_msg!=@sp__update_log
        select @err_msg='SP inside error at line '+cast(error_line() as sysname)
                       +' maybe near fn__script_info_tags; check header with @dbg=2'
    else
        select @err_msg=error_message()
    select @err_sev=error_severity()
    raiserror(@err_msg,@err_sev,1)
end catch


-- complete unknown situations
update @cmprs set sts=@st_unk where sts is null

-- =================================================================== checks ==

if @dbg>1
    begin
    select
        @db as db,'@cmprs' tbl,*,
        case sts
        when @st_common then 'common'
        when @st_update then 'update'
        when @st_conflict then 'conflict'
        when @st_err then 'algorithm missing error'
        when @st_unk then 'algorithm unknown error'
        when @st_left_update then 'left_update'
        end as [status]
    from @cmprs
    end

if exists(select top 1 null from @cmprs where sts in (@st_err,@st_unk))
    exec @sp__update_log @obj,'E','algorithm'

-- if no common base comment
if not exists(select top 1 null from @cmprs where sts=@st_common)
and (select count(*) from @dst_nfo)>0   -- 131210\s.zaglio
    exec @sp__update_log @obj,'E','too much different releases'
-- overwrite targets that do not has comments (without header)

select @sts=''

declare @mark_a int,@mark_b int
select @mark_a=null,@mark_b=null
select top 1
    @mark_a=case
            when a.sts=@st_conflict
            then a.n_row
            else b.n_row
            end
from @cmprs a
left join @cmprs b
on b.row=a.row+1
where 1=0
   -- (a.sts=@st_common and isnull(b.sts,@st_common)=@st_update)
   or (a.sts=@st_common and isnull(b.sts,@st_common)=@st_left_update)
   or (a.sts=@st_update and isnull(b.sts,@st_common)=@st_left_update)
   or (a.sts=@st_conflict)
order by a.row
if @@rowcount>0 select @sts='C',@mark_b=@mark_a

-- if same or small comment difference
if @sts=''
and not exists(select top 1 null from @cmprs where sts!=@st_common)
    begin
    if exists(select top 1 null
              from @cmprs
              where t_cmt!=n_cmt)
        select @sts='U'
    else
        select @sts='S'
    end

-- if newer
if @sts=''
and exists (
    select top 1 null
    from @cmprs c
    where c.row=1 and c.sts=@st_update and t_cmt is null
    )
    select @sts='U'

-- if newer (for last,quick,small modification)
if @sts=''
and not exists (
    select top 1 null
    from @cmprs c
    -- where c.row=1 and c.sts=@st_update and not t_cmt is null and n_ver>=t_ver
    where not c.sts in (@st_update,@st_common)
    )
    select @sts='U'

-- older
if @sts='' select @sts='O'

-- if @sts='' raiserror('inside error, unmanaged condition',16,1)

-- ============================================ show result status of compare ==
do_action:

if @dbg>1 select @sts as '------------------- result_action -------------------'

-- check for aliases and deprecates
declare cs cursor local for
    select tag,val1 as ver,val3 as obj
    from @nfo
    where @sts!='C'    -- <<<<<<<<<<<<< NB >>>>>>>>>>>
      and tag in ('a','d')
    order by val1
open cs
while 1=1
    begin
    fetch next from cs into @tag,@ver,@s_obj
    if @@fetch_status!=0 break
    select @sql='use '+quotename(@db)+@crlf
    if @tag='D' select @sql=@sql+'exec sp__deprecate '''+@s_obj+''','+@ver
    if @tag='A' select @sql=@sql+'exec sp__aliases '''+@s_obj+''',@of='''+@obj+''''
    begin try
        if @test=0 exec(@sql)
    end try
    begin catch
        select @err_msg=error_message()
        exec @sp__update_log @obj,'E',@err_msg
    end catch
    end -- cursor cs
close cs
deallocate cs

if @sts in ('O','S')    -- older,same
    begin
    exec @sp__update_log @obj,@sts
    goto dispose
    end

if @sts='C'             -- conflict
    begin
    if @sd=1
        if @test=1                      -- show difference of lines
            select
                'diff' tbl,isnull(a.lno,b.lno) lno,@db as db,@obj as obj,
                isnull(b.line,'') as [current(A)],
                isnull(a.line,'') as [new(B)]
            from fn__ntext_to_lines(@src,0) a
            full outer join fn__ntext_to_lines(@dst,0) b
            on a.line=b.line and abs(a.lno-b.lno)<10
            order by isnull(a.lno,b.lno)
        else                            -- show the two sequence of lines
            begin
            select @sql='
            select
                isnull(b.line,'''') as ['+@db+'.'+@obj+'],
                isnull(a.line,'''') as [new code],
                case
                when a.lno between @mark_a and @mark_b then ''<<''
                else ''''
                end [??]
            from fn__ntext_to_lines(@src,0) a
            full outer join fn__ntext_to_lines(@dst,0) b
            on a.lno=b.lno
            order by isnull(a.lno,b.lno)'
            exec sp_executesql
                    @sql,
                    N'@src nvarchar(max),@dst nvarchar(max),@mark_a int,@mark_b int',
                    @src=@src,@dst=@dst,@mark_a=@mark_a,@mark_b=@mark_b
            end
        -- sd option

    exec @sp__update_log @obj,@sts -- raiserror 11
    end -- conflict

-- ================================================================ do update ==

if @sts!='N'
    select
        @drop=if_exists+@crlf+'    '+drop_script
    from fn__script_drop(@obj,@t_type,@sch,default,'relaxed')

-- remove initial crlf
while left(@src,len(@crlf))=@crlf select @src=stuff(@src,1,len(@crlf),'')

select @src='use '+quotename(@db)+@crlf
           +'begin try'+@crlf
           +'begin tran sp__script_update'+@crlf
           +isnull(@drop+@crlf,'')
           +'exec('''+replace(@src,'''','''''')+''')'+@crlf
           +'commit tran sp__script_update'+@crlf
           +'end try'+@crlf
           +'begin catch'+@crlf
           +'rollback tran sp__script_update'+@crlf
           +'declare @m nvarchar(2000),@s int'+@crlf
           +'select @m=error_message(),@s=error_severity()'+@crlf
           +'raiserror(@m,@s,1)'+@crlf
           +'end catch'

begin try
    -- todo: encose in trans and manage nested
    if @dbg>0 exec sp__printsql @src
    if @test=0 exec(@src)
-- ================================================================ run SETUP ==
    if @obj like '%[_]setup'
        begin
        if @dbg>0 exec sp__printf '-- will be executed as setup'
        else
            begin
            if @test=0 exec ('exec '+@obj+',@opt=''run''')
            end
        end
    exec @sp__update_log @obj,@sts
end try
begin catch
    select @err_msg=error_message(),@err_sev=error_severity()
    exec @sp__update_log @obj,'E',@err_msg
end catch

-- ================================================================== dispose ==

dispose:
if @sp__update_log_id=0 drop proc #sp__update_log -- if it come from outside

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    analyze the script and update of relative object in the specified db

Notes
    - be careful with grouped comments (left the lasts as single)
    - actually drop and re-create the object because too difficult understand
      when sub-type deeply change (example TF to IF)
    - for a complete list of test cases see sp__script_update_test
    - tag D is performed (sp__deprecate @db.@obj,@ver,@aut )
    - if the name of object end with "_setup", the sp will be executed with
      @opt=run (be sure that the sp of setup must run more times)
    - commonly this util will be used by your deploy engine as:
        - create deploy log
        - create #update log
        - call sp for each new object
        - save #update log into deploy log
        - eventually repeat script 3 times (for dependencies)
        - send email with report or other
    - version and comments are used to check effective code progression
        - the possible conditions are:
            - regular (right) upgrade (only new comments on right side)
            - nothing to do (only common comments)
            - conflict (one or more comments on the left)
            - upgrade of merge or minor update (last comment changed on the right)
            - older (less comments in the new script)

        id current                    new                           status
        -- -----------------------  ---------------------------        ----------
        01 yymmd3\auth0:comment3    yymmd3.hhmm\auth0:comment3.x    merged or reviewd
        02       (not present)      yymmd2\auth1:comment2           new line
        03 yymmd1\auth2:comment1       (not present)                conflict or newer
        04 yymmd0\authX:commentXXX  yymmd0\auth3:commentYYY         conflict
        05 yymmd0\auth3:comment0    yymmd0\auth3:comment0           last common

        - lasts 10 comments are taken from each side and compared
        - if "current" has more comments than "new", means that current is newer
        - if 1st comment change a bit in the comment and/or in the time, is a small
          revision

Todo
    - if the new script present a "a"(sp__alias @db.obj,@obj),"j" tag, "t" tag


Parameters
    [param]     [desc]
    #update_log (optional) store update status
                create table #update_log(
                    id int identity,
                    dt datetime default(getdate()) not null,
                    who sysname default system_user+''@''+
                                        isnull(host_name(),''???''),
                    obj sysname,
                    sts char,       -- Updated,New,Same,Older,Conflict,Error
                    msg nvarchar(2000)
                    )
                anyway a raiserror 11 is given
    @src        source script with "new" version
    @db         target db (default is local),
    @tcc        top common comments to check from history (default:%p1%)
                useful when a bug fix is integrated with same comment in
                a future version where another user had previusly added
                a new feature (see example in notes)
    @opt        options
                test    do not update, test only the possibility (no conflicts)
                sd      show a two column table with two codes, to simplify
                        cut and paste into Kdiff or similar when in conflict
                strict  do not replace missed .hhmm
                ovr     force override (update or create)
                        the local OVR is overridden bye a global OVR, enabled with:
                            sp__context_info ''sp__script_update:ovr''
    @dbg        1=base info
                2=compare table
                3=middle and campare table

Examples
    sp__script_update_test 1,@dbg=1
',@p1=@tcc

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end try

-- =================================================================== errors ==
begin catch
-- if @@trancount > 0 rollback -- for nested trans see style "procwnt"
if @sp__update_log_id=0 and not object_id('tempdb..#sp__update_log') is null
    drop proc #sp__update_log

-- exec @ret=sp__err @cod=@proc,@opt='ex'
declare @e_msg nvarchar(4000),@e_sev int

-- this come always from #sp
select @e_msg=error_message(),@e_sev=error_severity()
raiserror(@e_msg,@e_sev,1)
return @ret
end catch   -- proc sp__script_update