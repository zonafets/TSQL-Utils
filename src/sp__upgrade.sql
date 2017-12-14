/*  leave this
    l:see LICENSE file
    g:utility
    k:compare, deploy, upload, download,
    d:130902\s.zaglio:sp__checkout
    d:130902\s.zaglio:sp__script_deploy
    r:130922,130906,130905\s.zaglio:adapting to sp__file_get
    v:130830\s.zaglio:done remake
    r:130829\s.zaglio:rename and remake from sp__checkout
    v:130204\s.zaglio:working near comparation
    r:130201\s.zaglio:help to identify diff of versions
    t:sp__upgrade @opt='list'
*/
CREATE proc sp__upgrade
    @uri nvarchar(max) = null,
    @opt sysname = null,
    @dbg int = 0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
declare
    @i int,@j int,@n int,
    @run bit,@noquote bit,
    @crlf varchar(2),@cr char(1),@lf char(1),
    @data varbinary(max),@cdata nvarchar(max),                 -- character data
    @grp sysname,@temp nvarchar(1024),
    @todo varchar(16),@obj sysname,
    @q char,@qq char(2)

-- =========================================================== initialization ==
exec sp__get_temp_dir @temp out
select
    @crlf=crlf,@cr=cr,@lf=lf,
    @q='"',@qq='""',
    @uri=replace(ltrim(rtrim(isnull(@uri,''))),'%temp%',@temp),
    @run=charindex('|run|',@opt)
from fn__sym()

-- ======================================================== second params chk ==
if @uri='' goto help
if @uri like '%,%,%,%,%' select @cdata=@uri,@uri=null
if not @uri like 'http%.asmx?op=%'
if not @uri like '%[\/]index.txt'
    raiserror('@uri must end with "index.txt" file name',16,1)

-- =============================================================== #tbls init ==

select top  0 * into #objs_list
from fn__script_group_select(default,default,default,'top0',default)

-- temp table for index file
select top 0 obj,tag,ver,aut,des,lcl
into #group_file_list
from #objs_list

-- drop table #src
create table #src(lno int identity primary key,line nvarchar(4000))

-- ===================================================================== body ==

/*
    1. download list (or parse @uri as list)
    2. get the group if exists
    3. get current list
    4. compare ...
*/

-- ============================================================ download list ==

-- sp__upgrade 'sp__upgrade,v,130831,s.zaglio,"rename and remake","done remake"'
-- sp__upgrade 'sp__upgrade,v,130831,s.zaglio,"rename and remake","last chglog"'

if @cdata is null
    begin
    exec sp__file_get @uri out,@data out
    select @cdata=cast(@data as nvarchar(max))
    end

-- fill table and get group name .. if given
insert #group_file_list(obj,tag,ver,aut,des,lcl)
select c00,c01,c02,c03,c04,c05
from fn__ntext_to_lines(@cdata,0)
cross apply fn__str_words(line,',','csv')

select @grp=obj from #group_file_list where tag=''

-- ===================================================== fill with local list ==
insert into #objs_list
select *
from fn__script_group_select(@grp,default,default,'lcl',default)

-- ======================================================= compare into #todo ==

-- t:sp__upgrade '%temp%\utility\index.txt'

select
    todo=
    case when ol.obj is null then 'add'
         when isnull(ol.lcl,'')!=isnull(gl.lcl,'') then 'conflict'
         when isnull(ol.lcl,'')=isnull(gl.lcl,'')
         then case
              when ol.ver>gl.ver then 'newest'
              when ol.ver<gl.ver then 'update'
              else 'nothing'
              end
    end,
    obj=
    isnull(ol.obj,gl.obj),
    l_tag=ol.tag,
    r_tag=gl.tag,
    l_ver=ol.ver,
    r_ver=gl.ver,
    l_aut=ol.aut,
    r_aut=gl.aut,
    l_des=ol.des,
    r_des=gl.des,
    l_lcl=ol.lcl
into #todo
from #group_file_list gl
full join #objs_list ol
on gl.obj=ol.obj
where gl.tag in ('r','v') and ol.tag in ('r','v')

insert into #todo
select 'drop',obj,'',gl.tag,'',gl.ver,'',gl.aut,'',gl.des,gl.lcl
from #group_file_list gl
where gl.tag='d'

-- ================================================== show results or upgrade ==
if @run=0
    begin
    insert #src
    select 'todo,obj,l_tag,r_tag,l_ver,r_ver,l_aut,r_aut,l_des,r_des,l_lcl'
    insert #src
    select
        @q+todo+@q+','+
        @q+obj+@q+','+
        @q+l_tag+@q+','+
        @q+r_tag+@q+','+
        @q+l_ver+@q+','+
        @q+r_ver+@q+','+
        @q+l_aut+@q+','+
        @q+r_aut+@q+','+
        @q+replace(l_des,@q,@qq)+@q+','+
        @q+replace(r_des,@q,@qq)+@q+','+
        @q+replace(l_lcl,@q,@qq)+@q
    from #todo
    order by todo desc,obj
    select * from #src
    end
else
    begin
    declare cs cursor local for
        select todo,obj
        from #todo
        where 1=1
    open cs
    while 1=1
        begin
        fetch next from cs into @todo,@obj
        if @@fetch_status!=0 break

        if @todo='drop'
            begin
            exec sp__deprecate @obj
            exec sp__printf '-- %s dropped',@obj
            end

        if @todo in ('newest','conflict')
            exec sp__printf '-- %s send not implemented',@obj

        if @todo='update'
            begin
            print 'todo download and run'
            end
        end -- cursor cs
    close cs
    deallocate cs
    end -- run

goto ret

-- =================================================================== errors ==
-- err_sample1: exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    download list from a url or a file or a constant and compare versions
    with local objects; if RUN options specified, execute the upgrade.

Notes
    - conflicts:
        case    svr obj ver aut pver paut   (p stay for previouse)
        1       s1  o1  t1  A   t0   A
        2       s2  o1  t1  A   t0   A
        3       s3  o1  t1  B   t0   A
        4       s1  o2  t1  A   t0   A
        5       s2  o2  t2  B   t0   A

        case 1 and 2: must not happen because is undecidable
        case 2 and 3: same version but different user -> conflict
        case 4 and 5: if the happen together, there is no way to solve
                      if 4 happen before 5, 5 see a difference

      the new object with conflict is stored into LOG_DDL and difference
      can be explored using SP__SCRIPT_DIFF.

Parameters
    @uri    is the source of list (see sp__script_group_tofile); can be:
            - url of "index.txt" (index.txt must be included)
            - path of "index.txt" (index.txt must be included)
            - the source of the list (for manual comparision)
    @opt    options
            run     execute the upgrade instead of list the differencies
            newest  add to the output the source of newest objects

Examples
    -- load list from file and compare with local
    exec sp__upgrade "%temp%\utility\index.txt"
    -- compare current "sp__upgrade" version with the specified
    exec sp__upgrade ''sp__upgrade,v,130829,s.zaglio,"rename and remake"''
    --
'

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
end catch   -- proc sp__upgrade