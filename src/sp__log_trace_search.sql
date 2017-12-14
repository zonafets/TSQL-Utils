/*  leave this
    l:see LICENSE file
    g:utility
    v:130225\s.zaglio: adapted to new sp__udage
    v:110314\s.zaglio: renamed from deprecated sp__trace_search (see sp__log)
    v:090322\S.Zaglio: search into formatted log_trace
*/
CREATE proc [dbo].[sp__log_trace_search]
    @proc sysname=null,
    @days int=1,
    @id smallint=null,
    @like sysname=null
as
begin
set nocount on
declare @sql nvarchar(4000)

if @proc is null and (@id is null)
    begin
    select @sql ='select top 100 percent dbo.fn__str_at(txt, ''|'', 2) as prc '
                +'from dbo.log_trace l with (readpast) '
                +'where substring(txt,24,1)=''|'' group by dbo.fn__str_at(txt, ''|'', 2)'
    exec(@sql)
    exec sp__usage 'sp_log_trace',@extra='\n    @proc can be % or a procedure\n    @like is used in like %@like%'
    goto ret
    end

select top 100 percent id, ref_id + id-1 as rel_id, spid,
convert(datetime,substring(txt,1,23)) date,
dbo.fn__str_at(txt, '|', 2) as prc,
replace(dbo.fn__str_at(txt, '|', 3),char(13)+char(10),' ') as txt
from dbo.log_trace l with (readpast)
where
    substring(txt,24,1)='|'
and
    (@days is null or convert(datetime,substring(txt,1,23))>getdate()-@days)
and
    dbo.fn__str_at(txt, '|', 2) like '%'+isnull(@proc,'')+'%'
and
    (@id is null or [id]=@id)
and
    (@like is null or txt like '%'+@like+'%')
order by id desc
ret:
end -- proc