/*  Leave this unchanged doe MS compatibility
    l:see LICENSE file
    g:utility,script
    v:131126\s.zaglio: added recache option
    v:131027\s.zaglio: added cache for slow computers
    v:130730.1230,130729,130726,130725,130724,130723,130722,130719\s.zaglio: restructuring
    r:130703;130701\s.zaglio: removed prefix; removed old unused code;moving code sp__script
    r:130613\s.zaglio: deprecated html out and moved index to ...
    r:130610\s.zaglio: integration with fn__script_group_select
    v:130417;130127\s.zaglio: added author filter and script of obj|obj|...;added %latests_objs%
    v:121229;121218\s.zaglio: replaced %now% with %dt% and added %db%;around problem of "\"
    v:121108\s.zaglio: searching bug of \{space} (found into sp__script)
    v:121004.1614\s.zaglio: exclude _old objs and used sp__deprecated
    v:120924;120921\s.zaglio: around error management;added prefix opt
    v:120920\s.zaglio: exec setup also at end and used try-catch
    v:120907.1500\s.zaglio: deprecated tag X and used postfix _%grp%_setup
    r:120907\s.zaglio: added chk if sp__script_store,grp,%_setup are in R
    v:120827\s.zaglio: added app_name test and forced convert to db 90
    v:120823.1000;120731\s.zaglio: added nochk option and better tests;test of #script_results
    v:120727\s.zaglio: added errors check and script repeat
    v:120725.1557;120724\s.zaglio: spring test and done;messaging and new tag X
    v:120516.1841\s.zaglio: adapted to new fn__script_sysobjs & fn__script_sign
    v:120510;120201\s.zaglio: a bug near deprecated "null" names;fn__sym before others
    v:111230;111229\s.zaglio: adapted to new sp__script_template;adapting to new sp__script_template
    r:111228;111223\s.zaglio: added support for multi &grp;adapting to new sp__script_template
    v:111205;111111\s.zaglio: added script of direct objects;excluded deprecated from group
    v:111007;110916\s.zaglio: added sortable func to index.html;adapted to new fn__buildin
    v:110824;110704\s.zaglio: adapted to new sp__script_template;specified log_ddl upgrade version
    v:110701.1848;110630;110629\s.zaglio: added upgrade of log_ddl;re-profiling;used fn__sysobjects
    v:110628\s.zaglio: added deprecated management and script of trigger db
    v:110623;110621\s.zaglio: better comment position;a small bug near drop and more info
    v:110620;110615\s.zaglio: done 3rd review with versioning;readded out to file/s and html
    r:110614;110603\s.zaglio: added versioning;added integration with history
    v:110509;110406\s.zaglio: added print obj in regen...;adapted to new sp__script & C.
    v:100919.1005\s.zaglio: a bug near html creations
    v:100919.1001\s.zaglio: script ordered by name desc
    v:100919\s.zaglio: added note about script of fkeys
    v:100905;100724\s.zaglio: added origin db check;a bug near html generation
    v:100718100612\s.zaglio: added check of origin db;added more examples
    v:100523;100501\s.zaglio: renamed option hidx to index;added last chg column on html table
    v:100418.2200\s.zaglio: use of fn__script_info and added hidx
    v:100411\s.zaglio: added * to collect tables&views
    v:100405;100403\s.zaglio: done & tested;adapted to 3rd remake of sp__script
    v:100328;091126\s.zaglio: adapted to new version of sp__Script;added list of groups in help
    v:091018\s.zaglio: remake of old sp__script_group to separate from use of table
    t:sp__script_group 'UTILITY@s.zaglio',@dbg=2,@exclude='fn__word%'
    t:sp__script_group 'utility',@out='%temp%\%grp%_%t',@dbg=2  -- single file out
    t:sp__script_group 'utility',@out='%temp%\%obj%_%t',@dbg=2  -- multi file out
    t:sp__script_group 'fn__str_table|fn__str_at'
    t:sp_script_utility @out='%temp%\%grp%.sql',@dbg=1
*/
CREATE proc [dbo].[sp__script_group]
    @grp        nvarchar(4000) = null,
    @out        nvarchar(max)  = null out,
    @exclude    nvarchar(4000) = null,
    @include    nvarchar(4000) = null,
    @opt        sysname = null,
    @dbg        int     = 0
as
begin try
set nocount on

declare
    @proc sysname,@ret int,
    @e_msg nvarchar(4000),@e_p1 sysname,@e_p2 sysname,
    @t datetime,@i int,@aut sysname -- derived parameter

select @proc=object_name(@@procid),@ret=0,
       @opt=dbo.fn__str_quote(coalesce(@opt,''),'|'),
       @t=getdate()

-- ================================================================ param chk ==

if @grp is null goto help

-- ============================================================= declarations ==

declare
    @n int,@obj sysname,@sql nvarchar(max),@isql nvarchar(4000),
    @src nvarchar(max),
    @type nvarchar(2),@tmp sysname,@var_id int,@src_id int,
    @db sysname,@xt nvarchar(2),
    @go sysname,@ver sysname,
    @dothtm nvarchar(32),@crlf nvarchar(2),
    @grp_sep nvarchar(4),@obj_sep nvarchar(4),
    @grp_util sysname,@db_util sysname,
    @tgs varchar(4),                    -- tags of objs to consider,
    @tag nvarchar(8),
    @tpl sysname,                       -- name of template
    @ver_grp numeric(10,4),             -- max version of utilities
    @latests_objs nvarchar(4000),       -- max ver:obj,obj,obj,...
    @grp_setup sysname,                 -- like for name of group setup object
    @drop nvarchar(512),
    @opt_script sysname,
    @tmp_script_group_cache_id int,
    @key varbinary(16),
    -- options
    @bin bit,@recache bit,
    @end_declare bit

if charindex('|',@grp)>0 goto script_objs

declare @objs table(
    obj_id int null,
    obj sysname,
    xt nvarchar(2) null,
    tag nvarchar(16) default('v'),
    aut sysname null,           -- info.val2
    ver nvarchar(16) null,      -- info.val1
    [des] sysname null,         -- info.val3
    grp1 sysname null default(''),
    grp2 sysname null default(''),
    grp3 sysname null default(''),
    core bit default(0),        -- basic obj used to define others
    [drop] nvarchar(512) null,
    ord int,
    match bit
    )

-- =========================================================== check in cache ==

-- drop table tmp_script_group_cache
if object_id('tmp_script_group_cache') is null
    create table tmp_script_group_cache(
        dt datetime not null,
        id int identity not null,
        [key] varbinary(16) not null,
        latests_objs nvarchar(320) not null,   -- print 450-128=322
        [out] nvarchar(max) not null,
        constraint pk_tmp_script_group primary key (id)
        )

select @key=hashbytes('md5',@grp+'|'+isnull(@include,'')
                                +'|'+isnull(@exclude,'')+
                                +@opt)

select @tmp_script_group_cache_id=isnull(object_id('tmp_script_group_cache'),0)

if @tmp_script_group_cache_id!=0
    -- purge data older than one year (not necessary but more safest)
    delete from tmp_script_group_cache where dt<getdate()-365

-- =========================================== exclude objs managed elsewhere ==

select @i=charindex('@',@grp)
if @i>0 select @aut=substring(@grp,@i+1,128),@grp=left(@grp,@i-1)

insert into @objs(
    obj_id,obj,xt,tag,aut,ver,[des],grp1,grp2,grp3,core,[drop],ord,match
    )
select
    obj_id,obj,xt,tag,aut,ver,[des],grp1,grp2,grp3,core,[drop],ord,match
from fn__script_group_select(@grp,@exclude,@include,default,default)

if @@rowcount=0 raiserror('no objects for this group',16,1)

-- check for bad headers
select @exclude=null
select @exclude=isnull(@exclude+',','')+obj
from (select distinct obj from @objs where isnumeric(ver)=0) a
if isnull(@exclude,'')!=''
    raiserror('this objects has bad version: %s',16,1,@exclude)

-- update version for non versioned objects
update @objs set ver=dbo.fn__script_buildin(getdate(),1,'','')
where ver is null -- teorically tables

if @dbg>0 exec sp__elapsed @t out,'after obj list'

if @dbg>1 select * from @objs order by core desc,tag,ord,obj

if @dbg=0
and exists(
    select top 1 null
    from @objs nfo
    where cast(tag as nchar)='R'
    and (
        object_name(obj_id) in (@proc,'sp__script_store','sp__script')
        or object_name(obj_id) like '%'+@grp+'_setup'
        )
    )
    begin
    select @e_msg='"sp__script_group" or "sp__script_store" '
                         +'or "sp__script" '
                         +'or "group setup object" are in R state'
    raiserror(@e_msg,16,1)
    end

-- ============================================================== #temp table ==
select
    @var_id=isnull(object_id('tempdb..#vars'),0),
    @src_id=isnull(object_id('tempdb..#src'),0)

create table #tpl (lno int identity,line nvarchar(4000))
create table #tpl_sec(lno int identity,section sysname,line nvarchar(4000))
create table #tpl_cpl(tpl binary(20),section sysname,y1 int,y2 int)
create index #ix_tpl_cpl on #tpl_cpl(tpl,section)
if @var_id=0 create table #vars (id nvarchar(16),value nvarchar(4000))
if @src_id=0 create table #src (lno int identity,line nvarchar(4000))

-- todo: test run, checking if is in R state by other user

-- inside dbg
/*
exec('
create proc #chk as
if exists(select null from #src where right(line,2)=''\ '')
    exec sp__printf ''bug!!!''
')
*/

-- ===============================================================  templates ==
-- NB: chk of version of utility is limitating if outside
--     better use fn__Script_sign inside sp.

/*
    templates dependencies
    - %scr_header%
        - %disable_tracer%
        - %tmp_deprecated%
        - for each core object
            - %obj_core_chk%
            - %skip_obj%
        - for each other objects
            - %obj_ver_chk% -- from sp__script
            - %skip_obj%
        - %enable_tracer%
    - %scr_footer%
*/

exec sp__script_templates 'group'
if @dbg>0 exec sp__elapsed @t out,'after templates init'

-- ===================================================================== init ==

exec sp__get_temp_dir @tmp out

select
    -- @out=nullif(@out,''),    because used to return the entire script
    @grp_setup=(select top 1 name
                from sys.objects
                where type='P' and name like '%'+@grp+'_setup'
               ),
    @grp_util='utility',
    @db_util='utility',
    @tgs='rv',
    @grp_sep=',',
    @obj_sep='|',
    @crlf=crlf,
    @db=db_name(),
    @go='go',
    @dothtm='.htm',
    @bin=charindex('|bin|',@opt),
    @recache=charindex('|recache|',@opt),
    @out=replace(
            replace(
                replace(@out,'%temp%',@tmp),
                '%grp%',replace(@grp,',','_')
                ),
            '%t',dbo.fn__format(getdate(),'YYYYMMDD_HHMMSS',default)
            )
        +case when @out='' or @out like '%.sql' then '' else '.sql' end
from fn__sym()

-- check that every R,V tag has a correct numeric version
select @latests_objs=null
-- list of bad versions
select @latests_objs=isnull(@latests_objs+@crlf+obj+':'+ver,
                            obj+':'+ver
                            )
from @objs
where tag in ('r','v')
and not (ver like '[0-9][0-9][0-9][0-9][0-9][0-9]' -- yymmdd or --yymmdd.hhmm
         or ver like '[0-9][0-9][0-9][0-9][0-9][0-9].[0-9][0-9][0-9][0-9]')

if not @latests_objs is null
    begin
    exec sp__printf '%s',@latests_objs
    raiserror('above list of objects has bad version',16,1)
    end

-- this is necessary due a bug or an optimization in the engine
declare @vers table(obj sysname,ver numeric(10,4))
insert @vers(obj,ver)
select obj,cast(ver as numeric(10,4)) -- this in the where causes error
from @objs
where tag in ('r','v')

-- calculate max group version
select @ver_grp=max(cast(ver as numeric(10,4))) from @vers

-- sp__script_group 'utility'
-- list of latests objects
select @latests_objs=isnull(@latests_objs+','+obj,
                            replace(cast(@ver_grp as sysname),
                                    '.0000',
                                    ''
                                   )+':'+obj
                            )
from @vers
where ver=@ver_grp

-- ================================================ check if already in cache ==

if @tmp_script_group_cache_id!=0 and @recache=0
    begin
    select @src=null
    select top 1 @src=[out]
    from tmp_script_group_cache
    where [key]=@key and latests_objs=@latests_objs

    if not @src is null
        begin
        -- resplit into #src
        insert #src(line) select line from fn__ntext_to_lines(@src,0)
        if @out='' select @out=@src
        if @dbg>0 exec sp__printf '-- get script from cache'
        goto out_to_cached
        end -- test cache
    end -- if cache enabled

-- =============================================================== init macro ==

insert #vars
select '%svr%',@@servername union
select '%grp%',@grp union
select '%grp_setup%',@grp_setup union
select '%db_util%',@db_util union
select '%latests_objs%',@latests_objs union
 -- markers
select '%obj%',null union
select '%ver%',null union
select '%aut%',null union
select '%drop%',null

-- ======================================================== select all object ==

-- check invalid deprecated tags
if exists(
    select top 1 null
    from @objs nfo
    where nfo.tag='d'
    and isnumeric(convert(sysname,grp1))=0
    )
    exec sp__printf '-- W A R N I N G : some invalid deprecated tags'

-- =================================================================== header ==

if @grp!=@db_util
    select @exclude='utility'
else
    select @exclude='other'

-- expand proc into section
exec sp__script_template '%script_catch_definition%',
                         '%script_catch_implementation%'
update #tpl_sec set line=replace(line,'''','''''')

exec sp__script_template '%scr_header%',@excludes=@exclude

-- ============================================================= uninst trace ==
if @grp in (@grp_util) exec sp__script_template '%disable_tracer%'

if @dbg>0 exec sp__elapsed @t out,'after header scripting'

-- =================================================== loop into core objects ==
select @opt_script='upgrade|nodecl|nohdr|nofot'
if not @out is null select @opt_script=@opt_script+'|tofile'

if @grp in (@grp_util)
    begin

    exec sp__printframe 'core objects has different version check',@out='#src'

    declare cs_core cursor local fast_forward for
        select grp.obj,grp.xt,grp.tag,grp.[drop]
        from @objs grp
        where grp.core=1
        and grp.tag in ('r','v')
        order by grp.ord,grp.obj

    open cs_core
    while 1=1
        begin
        fetch next from cs_core into @obj,@xt,@tag,@drop
        if @@fetch_status!=0 break

        select @ver=dbo.fn__script_sign(@obj,1)
        update #vars set
            value=case id
                  when '%obj%' then @obj
                  when '%ver%' then @ver
                  when '%drop%' then @drop
                  end
        where id in ('%obj%','%ver%','%drop%')

        insert into #src(line)  select '' union
                                select '-- '+dbo.fn__format(@obj,'=< ',77)

        if @obj!='fn__script_sign'
            exec sp__script_template '%obj_core_chk%'
        else
            begin
            insert #src(line)
            select 'raiserror(''drop&create "fn__script_sign"'',10,1)'
            insert #src(line)
            select token
            from dbo.fn__str_table_fast(@drop,@crlf)
            end

        if @dbg=1 exec sp__printf 'scripting:%s, ver:%s',@obj,@ver

        -- ##########################
        -- ##
        -- ## dump CORE obj into #src
        -- ##
        -- ########################################################
        exec sp__script @obj,@opt=@opt_script

        if @obj!='fn__script_sign'
            exec sp__script_template '%skip_obj%',@excludes='setup'

        end -- while
        close cs_core
        deallocate cs_core

    end -- script 1st core objects for utility

if @dbg>0 exec sp__elapsed @t out,'after core scripting'

-- =============================================================== deprecated ==

exec sp__printframe 'remove deprecated',@out='#src'

insert into #src(line)
select 'exec sp__deprecate '''+[des]+''','+ver
from @objs
where tag in ('d')
order by case xt when 'TD' then 0 else 1 end,
         ord,obj

if @dbg>0 exec sp__elapsed @t out,'after deprecated scripting'

-- ================================================== loop into objects group ==

exec sp__printframe 'group objects',@out='#src'

select @opt_Script='upgrade|nodecl|nofot'
if not @out is null select @opt_script=@opt_script+'|tofile'

declare cs cursor local fast_forward for
    select grp.obj,grp.xt,grp.tag,grp.ver,grp.aut,grp.[drop]
    from @objs grp
    where tag in ('r','v')
    and grp.core=0
    order by grp.ord,grp.obj

open cs
while 1=1
    begin
    fetch next from cs into @obj,@xt,@tag,@ver,@aut,@drop
    if @@fetch_status!=0 break

    update #vars set
        value=case id
              when '%obj%' then @obj
              when '%ver%' then @ver
              when '%aut%' then @aut
              when '%drop%' then @drop
              end
    where id in ('%obj%','%ver%','%aut%','%drop%')

    insert into #src(line) select '-- '+dbo.fn__format(@obj,'=< ',77)

    if @dbg>0 exec sp__printf 'scripting:%s, ver:%s, aut:%s',@obj,@ver,@aut
    -- ##########################
    -- ##
    -- ## dump group obj into #src
    -- ##
    -- ########################################################
    exec sp__script @obj,@opt=@opt_Script
    -- exec #chk

    if @xt='u' exec sp__script_fkeys @obj

    -- grp obj footer
    select @tmp=case when @obj=@grp_setup then null else 'setup' end
    exec sp__script_template '%skip_obj%',@excludes=@tmp

    end -- while object
close cs
deallocate cs

if @dbg>0 exec sp__elapsed @t out,'after obj scripting'

-- ============================================================= uninst trace ==
if @grp in (@grp_util) exec sp__script_template '%enable_tracer%'

-- =================================================================== footer ==

if @grp_setup is null select @exclude=isnull(@exclude,'')+'setup'
exec sp__script_template '%scr_footer%',
                         @tokens='%grp_setup%',@v1=@grp_setup,
                         @excludes=@exclude

if @dbg>0 exec sp__elapsed @t out,'after footer scripting'

-- ======================================================= out to single file ==

out_to:

if @bin=1 exec sp__script_compress

select @src=
 stuff(
    (select @crlf + line
    from #src
    order by lno
    for xml path(''), type
    ).value('(./text())[1]','nvarchar(max)')
  , 1, len(@crlf), '')

-- if cache enabled
if @tmp_script_group_cache_id!=0
    begin
    update tmp_script_group_cache set [out]=@src
    where [key]=@key
    if @@rowcount=0
        insert tmp_script_group_cache(dt,[key],latests_objs,[out])
        select getdate(),@key,@latests_objs,@src
    end

out_to_cached:

if @src_id=0
    begin
    if @out is null
        exec sp__print_table '#src'
    else
        begin
        if @dbg>0 exec sp__printf 'out to %s',@out
        if @dbg=2
            begin
            exec sp__print_table '#src'
            end
        else
            exec sp__file_write_stream @out
        if @dbg>0 exec sp__elapsed @t out,'after out to file'
        end
    end -- out

-- out to variable
if @out='' select @out=@src

dispose:
if @src_id=0 drop table #src
if @var_id=0 drop table #vars

goto ret

-- ==================================================== script direct objects ==

script_objs:
-- t:sp__script_group 'fn_str_at|fn__str_at|sp__chknulls'
-- t:sp__script_group 'fn__str_at|sp__chknulls'
declare cs cursor local for
    select token
    from dbo.fn__str_table(@grp,'|')
open cs
while 1=1
    begin
    fetch next from cs into @obj
    if @@fetch_status!=0 break

    exec @ret=sp__script @obj,@opt='upgrade'
    if @ret!=0 goto ret

    end -- cursor cs
close cs
deallocate cs

goto out_to

-- =================================================================== errors ==
err:        exec @ret=sp__err @e_msg,@proc                              goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    script a group of objects by category
    see below for more info

Parameters
    #src    (optional) fill the caller table
    #vars   (optional) used to fill some specials macro (as %license%)
    @grp    single group to script can postfix with @AUTHOR
            to filter only objects where author of last version is AUTHOR;
            * the group is identified by tag G:
            * tag G support multiple groups separated by comma (",")
            * if contain a %, select names instead of group
            * if contain *, select also tables (with idxs,fkeys,trs)
            * SYS group, script S objects from fn__script_sysobjs
            * obj1|obj2|... direct script only obj1,obj2,...
              calling sp__script with opt upgrade

    @out    * if passed an empty string, return the script
            * can be a path where out a single file
              (extension is .sql)
              %grp% will be replaced with group name and create a unique file
              %t will be replaced with YYMMDD_HHMMSS
              %temp% will be replaced with windows user temp directory

    @opt    options
            bin         return results as compressed binary string
            recache     ignore cached version and re-script then re-cache

    @dbg    1 list selected objects and exit
            2 print and do not out to files

    @exclude is a "like" expression for post exclusion of objects
    @include is a "like" expression for pre inclusion of objects

Notes
    * an object that end with group name and "_setup", is considered the setup
      store procedure of the group, scripted 1st and executed immediatelly
    * if sp__script_store and sp__script_group are in R tag, cannot script
    * if object "%_%groupname%_setup" is in R, scripting is aborted

Examples
    -- normal use
    exec sp__script_group ''utility''

    -- replace macros
    create table #vars (id nvarchar(16),value nvarchar(4000))
    insert #vars select ''%license%'',''test replacements''
    exec sp__script_group ''script''
    drop table #vars

##########################
##
## SCRIPT GROUP STEPS
## ==================
##
## if script to console or into single file:
##   drop deprecated objects
##   check version
##     drop object
##     re-create
##
## is script "utility" group:
##   if exists uninstall db trigger
##   eventually re-create scripting core objects
##   drop deprecated objects
##   check version
##     drop object
##     re-create
##   if exists install db trigger and upgrade if necessary
##
########################################################

'
select val1 as grp
from fn__script_info(null,'g',0)
where not val1 is null
union
select val2
from fn__script_info(null,'g',0)
where not val2 is null
union
select val3
from fn__script_info(null,'g',0)
where not val3 is null
order by 1

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end try

-- =================================================================== errors ==
begin catch
-- if @@trancount > 0 rollback -- for nested trans see style "procwnt"

exec @ret=sp__err @cod=@proc,@opt='ex'
return @ret
end catch   -- proc sp__script_group