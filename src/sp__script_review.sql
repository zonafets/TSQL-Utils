/*  leave this
    v:091018\s.zaglio: help programmer to change code dinamically&sistematically
    g:utility
*/
CREATE proc [dbo].[sp__script_review]
    @old_code sysname=null,
    @new_code sysname=null,
    @objs sysname='%'
as
begin

-- replace old g: tag
-- sp__script_review '%g:sp__group%''utility'',''%''','%g:utility'
-- add g:tag
-- sp__script_review '%*/','%g:utility{crlf}*/',@objs='%[_][_]%'

-- sp__script_review '%exec%sp__elapsed%''-- SP_SYNC_TABLES:%''',
--                   '%exec%sp__elapsed%''-- %s:%''',@proc
-- sp__script_review '%exec%sp__printf%''-- SP_SYNC_TABLES:%''',
--                   '%exec%sp__printf%''-- %s:%''',@proc

print 'programming aid procedure: to do see content'
end--proc