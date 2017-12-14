/*  leave this
    l:see LICENSE file
    g:utility
    v:091018\s.zaglio: test for bcp form of sp__copy
*/
CREATE proc sp__copy_test_bcp @dbg bit=0
as
begin
set nocount on
declare @r int
if dbo.fn__exists('bcp_test',null)=1 drop table bcp_test
declare @t sysname select @t='a11_um'
-- sp__dir 'a11_um'
-- select * from a11_um
exec('select top 0 * into bcp_test from '+@t)
-- bcp do not manage difference between table and file without format
-- exec('alter table bcp_test add ok bit')
if @dbg=1 exec('select * from '+@t)
exec @r=sp__copy @t,'bcp_test.txt',@dbg=1
if @r!=0 goto err
exec @r=sp__run_cmd 'type %temp%\bcp_test.txt'
if @r!=0 goto err
exec @r=sp__copy 'bcp_test.txt','bcp_testone',@dbg=1
if @r!=-16 goto err
exec @r=sp__copy 'bcp_test.txt','bcp_test',@dbg=1
if @r!=0 goto err

select * from bcp_test
drop table bcp_test
goto ret
err:
exec sp__printf 'sp__copy_test_bpc:bcp test error'
ret:
end -- proc