/*  leave this
    l:see LICENSE file
    g:utility
    v:090910\s.zaglio: added output of all script of cur db to svn
    r:090302\S.Zaglio: interface bewteen mssql and svn
*/
CREATE proc [dbo].[sp__svn] @obj sysname,@svr sysname,@uid sysname,@pwd sysname
as
begin
/*
xp_cmdshell 'svn  help list'
xp_cmdshell 'svn ls svn://lupin/SOURCES/ -r HEAD'
-- sp__find 'svn://lupin/SOURCES'  -- list content recursivelly
-- sp__find 'svn://lupin/SOURCES/\*.vb' -- set and do a download (populate system table fnd)
-- sp__find -- list active downloads
xp_cmdshell 'svn ls svn://lupin/SOURCES/SINTESI/trunk -r HEAD -R -v' --username stefano --password prova'
xp_cmdshell 'svn ls svn://lupin/SOURCES/SINTESI/trunk -r HEAD -R --xml' --username stefano --password prova'

  71106 davide                set 16 09:46 PDA/Build/
  68797 giovanni              mag 19  2011 PDA/Build/Argos/
  68594 giovanni         1631 mag 06  2011 PDA/Build/Argos/config.xml

  Con --verbose i seguenti campi verranno mostrati per ogni elemento:
    Numero di revisione dell'ultimo commit
    Autore dell'ultimo commit
    Se bloccato, la lettera 'O'. (Usa 'svn info URL' per i dettali)
    Dimensioni (in byte)
    Data e ora dell'ultimo commit

 sp__script 'sp__script',@out='src__sp_script.sql',@dbg=1    -- out to %temp%\...sql
 sp__run_cmd 'c:\programmi\svn\bin\svn.exe help',@dbg=1 -- ???
 sp__run_cmd 'c:\programmi\svn\bin\svn.exe help update',@dbg=1 -- ???

 sp__run_cmd 'dir /a "c:\Documents and Settings\all users\desktop" /s'

 -- brutal remove
 sp__run_cmd 'rmdir /q /s "c:\Documents and Settings\all users\desktop\ramses"'

 -- checkout
xp_cmdshell 'svn checkout svn://lupin/SOURCES/SINTESI/ "%temp%\sp__find" -r HEAD --depth infinity '--username stefano --password prova'
xp_cmdshell 'svn help checkout'
xp_cmdshell 'dir /s %temp%\sp__find'
xp_cmdshell 'rmdir /q /s %temp%\sp__find'

 -- cleanup
 sp__run_cmd 'c:\programmi\svn\bin\svn.exe cleanup "c:\Documents and Settings\all users\desktop\ramses\sviluppo\db"'

 -- test existance
 sp__run_cmd 'c:\programmi\svn\bin\svn.exe ls svn://gamon/PROJECTS/RAMSES/Sviluppo/DB/readme.txt',@dbg=1 -- ???
 sp__run_cmd 'c:\programmi\svn\bin\svn.exe ls svn://gamon/PROJECTS/RAMSES/Sviluppo/DB/this_dont_exist.txt',@dbg=1 -- ???

 -- add new that already exists
 sp__run_cmd 'c:\programmi\svn\bin\svn.exe add "c:\Documents and Settings\all users\desktop\ramses\sviluppo\db\readme.txt"',@dbg=1 -- ???
 sp__run_cmd 'c:\programmi\svn\bin\svn.exe add "c:\Documents and Settings\all users\desktop\ramses\sviluppo\db\i_dont_exist.txt"',@dbg=1 -- ???

 -- try add new
 sp__run_cmd 'echo test from sp__svn>"c:\Documents and Settings\all users\desktop\ramses\sviluppo\db\test.txt"'
 sp__run_cmd 'c:\programmi\svn\bin\svn.exe add "c:\Documents and Settings\all users\desktop\ramses\sviluppo\db\test.txt"',@dbg=1 -- ???
 sp__run_cmd 'c:\programmi\svn\bin\svn.exe commit "c:\Documents and Settings\all users\desktop\ramses\sviluppo\db" -m "one commit test"'
 sp__run_cmd 'echo test change from sp__svn>>"c:\Documents and Settings\all users\desktop\ramses\sviluppo\db\test.txt"'
 -- do again add and commit

 sp__run_cmd 'c:\programmi\svn\bin\svn.exe update "c:\Documents and Settings\all users\desktop\ramses\sviluppo\db"'

 -- to see the user
 sp__run_cmd 'set'
*/
print 'to do'
goto ret
ret:
end