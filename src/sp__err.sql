/*  leave this
    l:see LICENSE file
    g:utility
    v:131018\s.zaglio: better help
    v:130927\s.zaglio: better output when called by exception
    v:130722.1000\s.zaglio: a small bug when under try catch
    v:130606\s.zaglio: a small bug when noerr opt
    v:121209\s.zaglio: changed exception msg format again(**)
    v:121206\s.zaglio: back to version 121002 because more correct call stack
    v:121121\s.zaglio: better help
    v:121118\s.zaglio: changed exception msg format and removed @lang,@tr
    v:121002\s.zaglio: a bug when called for exception
    v:120810\s.zaglio: warn option
    v:120809\s.zaglio: engine exception return
    v:120802\s.zaglio: better help
    v:120731\s.zaglio: added db name on print of @cod
    v:120223\s.zaglio: suppressed log of error
    v:111108\s.zaglio: added @opt and moved @src and and @trap
    v:110526\s.zaglio: refined #ex
    v:110523\s.zaglio: removed #err, added @src
    v:110329\s.zaglio: added print of exception error
    v:100706\s.zaglio: more help
    v:100228\s.zaglio: more help
    r:100223\s.zaglio: added params
    r:100222\s.zaglio: a review
    r:100127\s.zaglio: added more help and direct error raise and raise 20
    v:100117\s.zaglio: manage errors
    todo: test it remotelly
    t:sp__err 'immediate error %s','sp__this',@trap=1
    t:sp__err 'immediate error %s','sp__this',@p1='test'    -- error(1794031170)
    t:sp__err_old
    t:sp__err_test
*/
CREATE proc [dbo].[sp__err]
    @msg    nvarchar(4000)=null out,
    @cod    sysname=null,
    @p1     sql_variant=null,
    @p2     sql_variant=null,
    @p3     sql_variant=null,
    @p4     sql_variant=null,
    @opt    sysname=null
as
begin
set nocount on
declare @proc sysname,@ret int
select
    @proc=object_name(@@procid),
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

declare
    @crlf nchar(2),@err bit,
    @type smallint,@level int,@n int,
    @trap bit,@src bit,@noerr bit,@ex bit,@warn bit,
    @e_msg nvarchar(4000),
    @db sysname

select
    @db=db_name(),
    @trap=charindex('|trap|',@opt),
    @src=charindex('|src|',@opt),
    @noerr=charindex('|noerr|',@opt),
    @ex=charindex('|ex|',@opt)
       |case @msg when '#ex' then 1 else 0 end,
    @warn=charindex('|warn|',@opt),
    @crlf=crlf,
    @e_msg='error(%d) "%s" in [%s:%s]',
    @ret=dbo.fn__crc32(@msg)
from dbo.fn__sym()

select
    @msg=dbo.fn__printf(@msg,@p1,@p2,@p3,@p4,null,null,null,null,null,null)

if @noerr=1 goto ret
if @trap=1 select @level=20 else select @level=16

if (@msg is null and @cod is null and @opt='||') goto help

-- select @msg=isnull(@msg,'')

if @ex=1   -- used in a try catch from mssql2k5
    begin
    -- for compatibiliy with ms2k
    declare @err_message nvarchar(4000);
    declare @err_procedure nvarchar(4000);
    declare @err_severity int;
    declare @err_state int;
    declare @err_number int;
    declare @err_line nvarchar(8);

    select
        @ret=dbo.fn__crc32('exception'),
        @err_message = isnull(@msg,     -- when redefined by developer
                              isnull(error_message(),'-- msg not specified --')
                             ),
        @err_severity = case @warn when 1 then 10 else error_severity() end,
        @err_state = error_state(),
        @err_number = error_number(),
        @err_line = error_line(),
        @err_procedure = @db+'.'+isnull(error_procedure(),@cod)
                                     -- not correct when managed

    -- dynamics
    -- sp__err/raiserror -> exception -> exception
    -- error(nnn)        -> calledby  -> calledby

    if @err_message like 'error(%)%[[]%]%'
        select @e_msg=@err_message
    else
        select @e_msg=dbo.fn__printf(
                @e_msg,@ret,@err_message,@err_procedure,@err_line,
                null,null,null,null,null,null)
    if @cod!='' and @cod!=error_procedure()
        select @e_msg=@e_msg
                     +@crlf
                     +'called by ['+@db+'.'+@cod+':?]'

    select @e_msg=replace(@e_msg,'%','%%')
    raiserror(@e_msg,@err_severity,@err_state) with nowait
    goto ret
    end -- print of exception error

-- sp__usage 'fn__printf'
if not @cod is null select @cod=@db+'.'+@cod

-- raiserror('test %s',10,1)
if @src=1 insert #src(line)
    select dbo.fn__printf(@e_msg,
                          @ret,@msg,@cod,null,
                          null,null,null,null,null,null)


select @msg=isnull(@msg,''),@cod=isnull(@cod,'')
raiserror(@e_msg,@level,1,@ret,@msg,@cod,'?') with nowait

goto ret

help:
exec sp__usage @proc,'
Scope
    Introduce a common error management.

Notes
    raiserror <20 do not break SP execution in VS
    raiserror >10 break execution of SP if execute from step of job

Parameters:
    return  return the crc32 calculated on @msg (without replaces)
            and is the number reporter into ()
            (**) unfortunatelly with try/catch and the use or raiserror,
            we lost msg format so "2143915629" is the crc32 of "exception";
            when old style error management and new exception are mixed,
            the error report can contain stack calls ("called by [...]")
    @msg    the message with macros %s, %d or ''#ex''
    @proc   name of caller
    @p1..4  replaces %s, %d into @msg
    @opt    options
            trap    0(default) or 1, break the connection (raiserror >=20)
            src     if 1, store the message into #src before raise
                    #src(lno int identity,line nvarchar(4000))
            ex      print exception info, used into catch in mssql2k5 i.e.
                        begin catch
                            if error_number()!=1205 /*deadlock*/ exec sp__err @opt="ex"
                        end catch
                    message can be overridden:
                        exec sp__err "my msg",@proc,@opt="ex"
            noerr   calc on return code but do not raise error
            warn    replace severity with 10 to show only the error

Examples:

    exec @ret = sp__err ''test''

    produce

        Messagge 50000, level 16, state 1, procedure sp__err, row 122
        error(-662733300) "test" in [:?]

    the ? means unknown line number

    exec sp__err ''test %s'',''sp__this'',@p1=''personal''

        Messagge 50000, level 16, state 1, procedure sp__err, row 122
        error(-1628459270) "test personal" in [db.sp__this:line]"

    when caused by an exception, a message can be followed by:

        called by [proc:?]
        called by [proc:?]
        ...
'
select @ret=-1

ret:
return @ret
end -- sp__err