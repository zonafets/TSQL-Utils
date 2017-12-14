/*  leave this
    l:see LICENSE file
    g:utility
    r:091018\s.zaglio: loop into values, replacing in the template and execute or print it
*/
CREATE proc [dbo].[sp__loop]
    @tpl nvarchar(4000)=null,
    @x nvarchar(4000)=null,
    @y nvarchar(4000)=null,
    @z nvarchar(4000)=null,
    @parallel bit=1,
    @simul bit=0
as
begin
print 'todo: see inside'
/*
exec sp__loop '
-- test inner temp tables
create proc sp_temp_test<x>
as
begin
create table #test(<y>)
select id,right(name,13) from tempdb..sysobjects where id=object_id(''tempdb..#test'')
exec sp_temp_test<z> -- <onlast:remove>
drop table #test
end
g o
drop proc sp_temp_test<x> --<onlast:addall>
'
@x='1,2,3',
@y='id1 int|id1 real,p2c2 money,p2c3 text|id1 nvarchar(10),c2 int',
@z='2,3,4',
@parallel=1,
@simul=1
*/
-- must return:
/*
create proc sp_temp_test2
as
begin
create table #test(id1 real,p2c2 money,p2c3 ntext)
select id,right(name,13) from tempdb..sysobjects where id=object_id('tempdb..#test')
exec sp_temp_test3
drop table #test
end
g o
create proc sp_temp_test3
as
begin
create table #test(id1 nvarchar(10),c2 int)
select id,right(name,13) from tempdb..sysobjects where id=object_id('tempdb..#test')
drop table #test
end
g o
drop proc sp_temp_test1
drop proc sp_temp_test2
drop proc sp_temp_test3
*/
end -- proc