/*  leave this
    l:see LICENSE file
    g: script,utility
    v:110326\s.zaglio: added parameters clear
    v:110305\s.zaglio: done first version
    r:100127\s.zaglio: create a vb function to call a sp
    t:sp__util_sp2dotnet 'sp__util_sp2dotnet',@opt='class'
*/
CREATE proc [dbo].[sp__util_sp2dotnet]
    @obj sysname=null,
    @base sysname=null out,
    @lng sysname=null,
    @opt sysname=null,
    @dbg int=null
as
begin
set nocount on
declare @proc sysname,@ret int,@err int
select @proc=object_name(@@procid),@ret=0,@dbg=isnull(@dbg,0)
select @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
if @obj is null and object_id('tempdb..#objs') is null goto help

select
    @lng=isnull(@lng,'vbnet'),
    @base=isnull(@base,'db')

if not @lng in ('vbnet') goto help

-- ============================================================= declarations ==
declare
    @xtype nvarchar(2),@tab1 sysname,@tab2 sysname,@tab3 sysname,@id int

if object_id('tempdb..#objs') is null
    create table #objs(obj sysname,xtype nvarchar(2) null)

create table #src(lno int,line nvarchar(4000))
create table #cols(
    id int identity,
    col sysname, xtype sysname,
    ln sysname,prec sysname,scale sysname,
    nullable bit,isout bit,
    vbtype sysname null
    )

-- =========================================================== initialization ==
select
    @tab1='    ',@tab2=@tab1+@tab1,@tab3=@tab2+@tab1

if not @obj is null
    insert #objs(obj,xtype)
    select [name],xtype from sysobjects
    where [name] like @obj

-- ===================================================================== body ==
-- add header
if charindex('|class|',@opt)>0
    begin
    insert into #src(line) select ''' v:'+convert(sysname,getdate(),12)+'.'
                                         +left(replace(convert(sysname,getdate(),8),':',''),4)
                                         +'\sp__util_sp2dotnet: generated automatically'
    insert into #src(line) select 'Imports System'
    insert into #src(line) select 'Imports System.Data'
    insert into #src(line) select ''
    insert into #src(line) select 'Public Class '+@base+'_objs'
    insert into #src(line) select @tab1+'Inherits '+@base
    insert into #src(line) select ''' inherited by '+@base+'_io'
    insert into #src(line) select ''
    insert into #src(line) select @tab1+'Public Sub New(Optional ByVal cs As String = "")'
    insert into #src(line) select @tab2+'MyBase.New(cs)'
    insert into #src(line) select @tab1+'End Sub'
    insert into #src(line) select ''
    end -- class

-- add stored
declare cs cursor local for
    select obj,xtype,object_id(obj)
    from #objs
    where 1=1
open cs
while 1=1
    begin
    fetch next from cs into @obj,@xtype,@id
    if @@fetch_status!=0 break

    if @xtype!='P'
        begin
        exec sp__printf '%s excluded because not managed type(%s)',@obj,@xtype
        continue
        end

    truncate table #cols
    insert #cols(col,xtype,ln,prec,scale,nullable,isout,vbtype)
    -- declare @id int select @id=object_id('swl_rfc')
    select
        -- select * from systypes
        c.[name],case when t.xusertype=256 then 'nvarchar' else t.[name] end ,

        case -- select * from systypes
        when c.xusertype in (175,239,231,167,256) --char,nchar,nvc,vc
        then c.prec
        else c.length
        end as [length],

        case -- select * from systypes
        when c.xusertype in (175,239,231,167,256) --char,nchar,nvc,vc
        then 0
        else c.prec
        end as prec,

        isnull(convert(sysname,c.scale),'nothing') as scale,
        c.isnullable,c.isoutparam,
        case -- select * from systypes
        when c.xusertype in (175,239,231,167,256) --char,nchar,nvc,vc
        then 'string' -- +'('+convert(sysname,prec)+')'
        when c.xusertype in (62,106,108) then 'double' -- float,decimal,numeric
        when c.xusertype in (59) then 'single' -- real
        when c.xusertype in (61,58) then 'date' -- *datetime
        when c.xusertype in (56) then 'int32' -- int
        when c.xusertype in (52) then 'int16' -- smallint
        when c.xusertype in (48) then 'byte' -- tinyint
        when c.xusertype in (60) then 'currency' -- money
        when c.xusertype in (35,99) then 'string' -- text,ntext
        when c.xusertype in (104) then 'boolean' -- bit
        when c.xusertype in (98) then 'object' -- sql_variant
        else 'object ''unk type'
        end as vbtype
    from syscolumns c
    join systypes t on c.xusertype=t.xusertype
    where c.id=@id
    order by colid

    insert into #src(line) select @tab1+'public function ['+@obj+']( _'

    insert into #src(line)
    -- select * from systypes
    -- select * from syscolumns c where id=object_id('')
    select @tab3+
        case when nullable =1 then 'optional ' else '' end+
        case isout when 1 then 'byref ' else 'byval ' end+
        substring(col,2,4000)+' as '+
        vbtype+
        case when nullable=1 then '=nothing' else '' end+
        ', _'
    from #cols
    order by id

    insert into #src(line) select @tab3+'optional byref raiserrorIfRetNotIs as integer=0, _'
    insert into #src(line) select @tab3+'optional byval tst_params as boolean=false _'
    insert into #src(line) select @tab2+') as dataset'
    insert into #src(line) select ''
    insert into #src(line) select @tab1+'Dim ex As Exception = Nothing'
    insert into #src(line) select @tab1+'Dim retval as integer,da as SqlClient.SqlDataAdapter=nothing'
    insert into #src(line) select @tab1+'Dim ds as system.Data.DataSet=nothing'
    insert into #src(line) select @tab1+'Dim p As system.Data.SqlClient.SqlParameter'
    insert into #src(line) select ''
    insert into #src(line) select @tab1+'p=New system.Data.SqlClient.SqlParameter("retvalue", SqlDbType.Int)'
    insert into #src(line) select @tab1+'p.Direction = ParameterDirection.ReturnValue'
    insert into #src(line) select @tab1+'cmd.Parameters.Clear()'
    insert into #src(line) select @tab1+'cmd.parameters.add(p)'

    insert into #src(line)
    select top 100 percent
        'cmd.parameters.add(New system.Data.SqlClient.SqlParameter('+
        '"'+col+'",SqlDbType.'+xtype+','+
        ln+','+
        case
            when isout=1 then 'ParameterDirection.InputOutput'
            else 'ParameterDirection.Input'
        end+','+
        case when nullable=1 then 'true,' else 'false,' end+
        prec+','+
        scale+','+
        'nothing,DataRowVersion.Current,'+
        substring(col,2,4000)
        +'))'
        as line
    from #cols
    order by id

    insert into #src(line) select @tab1+'cmd.CommandType = System.Data.CommandType.StoredProcedure'
    insert into #src(line) select @tab1+'cmd.CommandText="'+@obj+'"'
    insert into #src(line) select @tab1+'debug(cmd)'
    -- .Parameters("au_id").Value = "172-32-1176"
    insert into #src(line) select @tab1+'da = New SqlClient.SqlDataAdapter(cmd)'
    insert into #src(line) select @tab1+'ds = New system.Data.DataSet'
    insert into #src(line) select @tab1+'timer.Start()'
    insert into #src(line) select @tab1+'try'
    insert into #src(line) select @tab1+'da.Fill(ds)'
    insert into #src(line) select @tab1+'catch local_ex As Exception'
    insert into #src(line) select @tab3+'ex=local_ex'
    insert into #src(line) select @tab1+'end try'
    insert into #src(line) select @tab1+'cmd.CommandType = System.Data.CommandType.Text'
    insert into #src(line) select @tab1+'timer.Stop()'
    insert into #src(line) select @tab1+'da.Dispose()'
    insert into #src(line) select @tab1+'da = Nothing'
    insert into #src(line) select @tab3+'if not ex is nothing then throw ex'

    insert into #src(line) select @tab1+'retval=nz(CType(cmd.Parameters("retvalue").Value, Integer),0)'
    insert into #src(line) select @tab1+'if retval<>raiserrorIfRetNotIs then'
    insert into #src(line) select @tab3+'throw new exception("error(" & retval & ") in ""' + @obj + '""")'
    insert into #src(line) select @tab1+'else'
    insert into #src(line) select @tab3+'raiserrorIfRetNotIs = retval'
    insert into #src(line) select @tab1+'end if '

    -- output values
    insert into #src(line)
    select top 100 percent
        @tab1+substring(col,2,4000)+'=CType(cmd.Parameters("'+col+'").Value, '+vbtype+')'
        as line
    from #cols
    where isout=1
    order by id

    insert into #src(line) select @tab1+'return ds'
    insert into #src(line) select @tab1+'end function '' '+@obj
    end -- while of cursor
close cs
deallocate cs

if charindex('|class|',@opt)>0
    begin
    insert into #src(line) select ''
    insert into #src(line) select 'End Class '' '+@base+'_objs'
    end -- class

select line from #src order by lno
drop table #src
drop table #cols

goto ret
-- =================================================================== errors ==

-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    generate the dotnet code necessary to use the objects of db

Parameters
    @obj    object name, can use wild %
            can pass directly #objs as
                create table #objs(obj sysname,xtype nvarchar(2) null)
    @base   is the base class used with "class" option; by default is "db"
    @lng    specify .net language of output
            possible languages are:
            null    (default)
            vbnet   (default)
    @opt    options
            class       enclose functions into class db_io inherited from db
            svn         TODO:out to svn (see sp__svn)
'

ret:
return @ret
end -- [sp__util_sp2dotnet]