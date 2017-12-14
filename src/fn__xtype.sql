/*  leave this
    l:see LICENSE file
    g:utility
    v:110312\s.zaglio:list sysobjects types
    t:select * from fn__xtype()
    t:
        select *
        from (
            select distinct xtype from sysobjects
            ) t
        left join fn__xtype() f
        on t.xtype=f.xtype
    t:select * from sysobjects where xtype in ('it','sq')
*/
CREATE function fn__xtype()
returns @xtype table ([xtype] nvarchar(2),[name] sysname,sqlver int null)
as
begin
insert @xtype
        select 'C', 'vincolo CHECK',null
union   select 'D', 'valore predefinito o vincolo DEFAULT',null
union   select 'F', 'vincolo FOREIGN KEY',null
union   select 'L', 'log',null
union   select 'FN','funzione scalare',null
union   select 'IF','funzione inline valutata a livello di tabella',null
union   select 'P', 'stored procedure',null
union   select 'PK','vincolo PRIMARY KEY (tipo K)',null
union   select 'RF','stored procedure del filtro di replica',null
union   select 'S', 'tabella di sistema',null
union   select 'TF','funzione di tabella',null
union   select 'TR','trigger',null
union   select 'U', 'tabella utente',null
union   select 'UQ','vincolo UNIQUE (tipo K)',null
union   select 'V', 'vista',null
union   select 'X', 'stored procedure estesa',null
union   select 'SN','sininimo',2005
union   select 'AF','funzione di aggregazione (CLR)',2005
union   select 'PC','stored procedure assembly (CLR)',2005
union   select 'FS','funzione scalare assembly (CLR)',2005
union   select 'FT','funzione valutata a livello di tabella assembly (CLR)',2005
union   select 'R', 'regola (tipo obsoleto, autonoma)',2005
union   select 'SQ','coda di servizio',2005
union   select 'TA','trigger DML assembly (CLR)',2005
union   select 'TR','trigger DML SQL',2005
union   select 'UQ','vincolo UNIQUE',2005
union   select 'IT','tabella interna',2005

return
end -- fn__xtype