/*  leave this
    l:see LICENSE file
    g:utility
    v:110210\s.zaglio: added more params
    v:101103\s.zaglio: more explicit sample
    v:080817\S.Zaglio: check if all parameters are nulls (use in params check)
    t:
        declare @r int
        exec @r=sp__chknulls 'a|b|c',1,null,'a',@dbg=1
        print @r    -->0
        exec @r=sp__chknulls null,null,null,null,@dbg=1
        print @r    -->1
*/
CREATE proc [dbo].[sp__chknulls]
    @p0 sql_variant=null,
    @p1 sql_variant=null,
    @p2 sql_variant=null,
    @p3 sql_variant=null,
    @p4 sql_variant=null,
    @p5 sql_variant=null,
    @p6 sql_variant=null,
    @p7 sql_variant=null,
    @p8 sql_variant=null,
    @p9 sql_variant=null,
    @dbg bit=0
as
begin
declare @r int
if  @p0 is null and
    @p1 is null and @p2 is null and @p3 is null and
    @p4 is null and @p5 is null and @p6 is null and
    @p7 is null and @p8 is null and @p9 is null
    begin
    set @r=1
    if @dbg=1 print 'all nulls'
    end
else set @r=0
return @r
end -- [sp__chknulls]