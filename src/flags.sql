/*  leave this for other app
    l:see LICENSE file
    g:obj,utility
    v:131006\s.zaglio: updated
    v:120517\s.zaglio: global flags
*/
CREATE view [flags]
as
select
    1 as A,
    2 as B,
    4 as C,
    8 as D,
   16 as E,
   32 as F,
   64 as G,
  128 as H,
  256 as I,
  512 as J,
 1024 as K,
 2048 as L,
 4096 as M,
 8192 as N,
16384 as O,
32768 as P,

 512 as srv , -- concerning the server
1024 as db  , -- concerning the database
2048 as ddl , -- concerning Data Definition Language
 512 as ver , -- 1=version/0=release flag
 512 as RA  , -- replaces accented
  48 as type, -- segment type
   0 as SEG , -- generic
  32 as #FLT, -- filter
  16 as #GRP, -- group
  48 as #COM, -- comment
 512 as RPT , -- repeat
1024 as HDR , -- header
2048 as DTL , -- detail
4096 as FTR , -- footer
8192 as SCR                             , -- scramble

-- iof
  32 as [iof.wrong],
  64 as [iof.processed],

-- fn__script_sysobjs and ex fn__script_events
  16 as [sys],      -- system
  32 as [tmp],      -- temporary
  64 as [exclude],  -- eXclude

-- sp__dir, sp__ftp and files
  32 as [files.directory],
  64 as [files.download],
 128 as [files.upload],
 256 as [files.delete],
 512 as [files.ok],
1024 as [files.err],

  -1 as [flags.last]