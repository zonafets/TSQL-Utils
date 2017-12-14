/*  leave this
    l:see LICENSE file
    g:utility
    k:process,status
    v:120905\s.zaglio: called by sp__lock and sp__lock_ex
*/
create proc sp__lock_help @opt sysname=null
as
begin
set nocount on
print '
--- See also ---
sp__lock_ex     show grouped and detailed info
sp__perf        show most heavy running processes

--- Legend ---
Campi visualizzati:
    blocking    SPID del processo che viene bloccato da quello di riga
    n_locks     conto totale dei lock ad opera dello SPID di riga

Process status:
    dormant = SQL Server is resetting the session.
    running = The session is running one or more batches. When Multiple Active Result Sets (MARS) is enabled, a session can run multiple batches. For more information, see Using Multiple Active Result Sets (MARS).
    background = The session is running a background task, such as deadlock detection.
    rollback = The session has a transaction rollback in process.
    pending = The session is waiting for a worker thread to become available.
    runnable = The task in the session is in the runnable queue of a scheduler while waiting to get a time quantum.
    spinloop = The task in the session is waiting for a spinlock to become free.
    suspended = The session is waiting for an event, such as I/O, to complete.

Tipo di blocco:
    RID = Blocco su una sola riga di una tabella identificata da un identificatore di riga (RID).
    KEY = Blocco all''interno di un indice che protegge un intervallo di chiavi in transazioni serializzabili.
    PAG = Blocco su una pagina di dati o di indice.
    EXT = Blocco su un extent, un''unità di 8 pagine contigue.
    TAB = Blocco su un''intera tabella, inclusi tutti i dati e gli indici.
    DB = Blocco su un database.
    FIL = Blocco su un file di database.
    APP = Blocco su una risorsa specifica di un''applicazione.
    MD = Blocco su metadati o informazioni del catalogo.
    HBT = Blocco su un heap o un indice b-tree.
          Queste informazioni non sono complete in SQL Server 2005.
    AU = Blocco su un''unità di allocazione.
         Queste informazioni non sono complete in SQL Server 2005.

Modalità di blocco richiesta. I possibili valori sono i seguenti:
    NULL = Non è concesso l''accesso alla risorsa. Funge da segnaposto.
    Sch-S = Stabilità dello schema. Garantisce che nessun elemento dello schema,
            ad esempio una tabella o un indice, venga eliminato mentre
            in una sessione viene mantenuto attivo un blocco di stabilità
            dello schema sull''elemento dello schema.
    Sch-M = Modifica dello schema. Deve essere impostato in tutte le sessioni
            in cui si desidera modificare lo schema della risorsa specificata.
            Assicura che nessun''altra sessione faccia riferimento all''oggetto
            specificato.
    S = Condiviso. La sessione attiva dispone dell''accesso condiviso alla risorsa.
    U = Aggiornamento. Indica un blocco di aggiornamento acquisito su risorse
        che potrebbero venire aggiornate. Viene utilizzato per evitare una
        forma comune di deadlock che si verifica quando in più sessioni
        vengono bloccate risorse che potrebbero venire aggiornate
        in un momento successivo.
    X = Esclusivo. La sessione dispone dell''accesso esclusivo alla risorsa.
    IS = Preventivo condiviso. Indica l''intenzione di impostare blocchi
         condivisi (S) su alcune risorse subordinate nella gerarchia dei blocchi.
    IU = Preventivo aggiornamento. Indica l''intenzione di impostare
         blocchi di aggiornamento (U) su alcune risorse subordinate
         nella gerarchia dei blocchi.
    IX = Preventivo esclusivo. Indica l''intenzione di impostare
         blocchi esclusivi (X) su alcune risorse subordinate
     nella gerarchia dei blocchi.
    SIU = Condiviso preventivo aggiornamento. Indica l''accesso condiviso
          a una risorsa con l''intenzione di acquisire blocchi di
          aggiornamento su risorse subordinate nella gerarchia dei blocchi.
    SIX = Condiviso preventivo esclusivo. Indica l''accesso condiviso
          a una risorsa con l''intenzione di acquisire blocchi esclusivi
          su risorse subordinate nella gerarchia dei blocchi.
    UIX = Aggiornamento preventivo esclusivo.
          Indica un blocco di aggiornamento attivato su una risorsa
          con l''intenzione di acquisire blocchi esclusivi su risorse
          subordinate nella gerarchia dei blocchi.
    BU = Aggiornamento di massa. Utilizzato dalle operazioni di massa.
    RangeS_S = Blocco condiviso intervalli di chiavi e risorsa.
               Indica una scansione di intervallo serializzabile.
    RangeS_U = Blocco condiviso intervalli di chiavi e aggiornamento risorsa.
               Indica una scansione di aggiornamento serializzabile.
    RangeI_N = Blocco inserimento intervalli di chiavi e risorsa Null.
               Utilizzato per verificare gli intervalli prima di inserire
               una nuova chiave in un indice.
    RangeI_S = Blocco conversione intervalli di chiavi.
               Creato da una sovrapposizione dei blocchi RangeI_N e S.
    RangeI_U = Blocco conversione intervallo di chiavi creato da
               una sovrapposizione di blocchi RangeI_N e U.
    RangeI_X = Blocco conversione intervallo di chiavi creato da
               una sovrapposizione di blocchi RangeI_N e X.
    RangeX_S = Blocco conversione intervallo di chiavi creato da
               una sovrapposizione di blocchi RangeI_N e RangeS_S.
    RangeX_U = Blocco conversione intervallo di chiavi creato da
               una sovrapposizione di blocchi RangeI_N e RangeS_U.
    RangeX_X = Blocco esclusivo intervalli di chiavi e risorsa.
               Si tratta di un blocco di conversione utilizzato
               quando viene aggiornata una chiave in un intervallo.

Stato della richiesta di blocco:
    CNVRT: è in corso la conversione del blocco da un''altra modalità,
           ma la conversione è bloccata da un altro processo
           che mantiene attivo un blocco con una modalità in conflitto.
    GRANT: il blocco è stato ottenuto.
    WAIT: il blocco è bloccato da un altro processo che mantiene attivo un blocco con una modalità in conflitto.
'
end -- sp__lock_help