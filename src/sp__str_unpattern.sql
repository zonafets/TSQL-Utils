/*  leave this
    l:see LICENSE file
    g:utility
    v:120528\s.zaglio:wrapper for fn__str_unpattern
*/
CREATE proc sp__str_unpattern
    @blob ntext     =null,
    @filter sysname =null,
    @opt sysname   =null,
    @dbg int        =0
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
if @blob is null goto help

select * from fn__str_unpattern(@blob,@filter,@opt)

goto ret

-- =================================================================== errors ==
-- err_sample1: exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    wrapper for fn__str_unpattern, extract not repetitive words

Parameters
    @blob       the big text
    @filter     value for option
    @opt        options
                like    keep only lines the like @filter
                unlike  exclude lines that not like @filter

Examples
    sp__str_unpattern ''
        Messaggio 50000, livello 16, stato 1, procedura sp__err, riga 101
        error(-811561914) "local object "FN_GET_2OF5_CHECKDIGIT" is different" in "sp__script_alias"
        Messaggio 50000, livello 16, stato 1, procedura sp__err, riga 102
        error(-811561914) "local object "FN_GET_3OF9_CHECKDIGIT" is different" in "sp__script_alias"
        Messaggio 50000, livello 16, stato 1, procedura sp__err, riga 103
        error(-811561914) "local object "FN_GET_ID_ENTITY_FROM_CD_ERP_SHIPMENT" is different" in "sp__script_alias"
        Messaggio 50000, livello 16, stato 1, procedura sp__err, riga 103
        error(-811561914) "local object "SP_MANAGE_MAIL_QUEUE" is different" in "sp__script_alias"
        Messaggio 50000, livello 16, stato 1, procedura sp__err, riga 103
        error(-811561914) "local object "SP_REFRESH_VIEWS" is different" in "sp__script_alias"
        '',''[0-9]%'',''unlike'' -- excludes 101 and 102
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__str_unpattern