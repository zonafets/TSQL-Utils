/*  leave this
    l:see LICENSE file
    g:utility
    d:130830\s.zaglio: fn__taxcode
    v:130830\s.zaglio: renamed into fn__taxcode_it
    v:101209\d.averoldi: corrected some bug
    v:101208\s.zaglio: calculate italian TAX code (only for check, not really legal)
    c:from http://microsoft-it.confusenet.com/showthread.php?t=16620
    t:select dbo.fn__taxcode('Stefano', 'Zaglio', 1, '19720201', 'X000') --> ZGLSFN72B01X000R
    t:select dbo.fn__taxcode('Davide', 'Averoldi', 1, '', 'X000') -->    --> VRLDVD00A01X000W
*/
create function fn__taxcode_it(
    @first_name varchar(255),
    @last_name varchar(255),
    @male bit,                  -- 1=male 0=female
    @birth_day datetime,        -- yyyymmdd
    @region_code char(4))       -- http://it.wikipedia.org/wiki/Codice_catastale
returns varchar(16) as begin

declare @tax varchar(16)
set @tax=''

/* -- TEST --
declare @d datetime
set @d=getdate()
select dbo.fn__GetCf('paolo', 'Bigongiari', 1, @d, 'c124')
*/


/*
Cognome (3 lettere)
Vengono prese le consonanti del cognome (o dei cognomi, se ve ne è più
di uno) nel loro ordine: solo se sono insufficienti, si prelevano anche
le vocali, sempre nel loro ordine: comunque, le vocali vengono riportate
dopo le consonanti. Nel caso in cui un cognome abbia meno di tre
lettere, la parte di codice viene completata aggiungendo la lettera X
(es.: Fo -> FOX). Per le donne, viene preso in considerazione il solo
cognome da nubile.
*/
set @last_name=replace(@last_name, ' ', '')
set @last_name=replace(@last_name, '''', '')
if @last_name like '%[^a-z]%' return null
if @last_name='' return null;

declare @T table(L char(1) not null, R varchar(255) not null, N int
primary key, N2 int not null, Vocale as case when L in('a', 'e', 'i',
'o', 'u') then 1 else 0 end )
insert into @T
select L = left(@last_name,1), R = stuff(@last_name, 1, 1, ''), N=1, 0
while (select max(N) from @T) < len(@last_name)
begin
insert into @T
select top 1 L = left(R,1), R = stuff(R, 1, 1, ''), N=N+1, 0
from @T
order by N desc
if @@rowcount=0 break
end;

select top 3 @tax = @tax + L
from @T x
order by Vocale, N

set @tax = left(@tax + 'xx', 3);

/*
Nome (3 lettere)
Vengono prese le consonanti del nome (o dei nomi, se ve ne è più di
uno) in questo modo: se il nome contiene quattro o più consonanti, si
scelgono la prima, la terza e la quarta, altrimenti le prime tre in
ordine. Solo se il nome non ha consonanti a sufficienza, si prendono
anche le vocali: comunque, le vocali vengono riportate dopo le
consonanti. Nel caso in cui il nome abbia meno di tre lettere, la parte
di codice viene completata aggiungendo la lettera X. Un caso estremo si
incontra in alcuni soggetti provenienti dall'India nel passaporto dei
quali è riportata una sola parola al posto del cognome e del nome. Si
userà allora quella parola per generare le prime tre lettere del codice
e, non esistendo il nome, la seconda terzina di lettere del codice sarà
XXX.
*/

set @first_name=replace(@first_name, ' ', '')
set @first_name=replace(@first_name, '''', '')
if @first_name like '%[^a-z]%' return null;
delete @T;
if @first_name>''
begin
insert into @T
select L = left(@first_name,1), R = stuff(@first_name, 1, 1, ''), N=1, 0
while (select max(N) from @T) < len(@first_name)
begin
insert into @T
select top 1 L = left(R,1), R = stuff(R, 1, 1, ''), N=N+1, 0
from @T
order by N desc
if @@rowcount=0 break
end;
end

declare @Cs int
select @Cs=count(*) from @T where Vocale=0

update @T
set N2=case t.Vocale when 0 then t.N-K else t.N-K + @Cs end
from @T t
inner join(
select t1.N, K=sum(isnull(t2.Vocale,0))
from @T t1
left outer join @T t2
on t2.N<t1.N
group by t1.N
) x
on x.N=t.N



select top 3 @tax = @tax + L
from @T
where @Cs<=3 or N2!=2
order by N2, N

set @tax = left(@tax + 'xxx', 6)

/*
Data di nascita e sesso (5 caratteri alfanumerici)
Anno di nascita (2 cifre): si prendono le ultime due cifre dell'anno di
nascita;
Mese di nascita (1 lettera): ad ogni mese dell'anno viene associata una
lettera in base a questa tabella:
Lettera Mese Lettera Mese Lettera Mese
A gennaio E maggio P settembre
B febbraio H giugno R ottobre
C marzo L luglio S novembre
D aprile M agosto T dicembre
Giorno di nascita e sesso (2 cifre): si prendono le due cifre del
giorno di nascita (se è compreso tra 1 e 9 si pone uno zero come prima
cifra); per i soggetti di sesso femminile a tale cifra va sommato il
numero 40.
*/

set @tax = @tax + right(convert(varchar,year(@birth_day)),2) +
case month(@birth_day) when 1 then 'A' when 2 then 'B' when 3 then
'C' when 4 then 'D' when 5 then 'E' when 6 then 'H' when 7 then 'L' when
8 then 'M' when 9 then 'P' when 10 then 'R' when 11 then 'S' when 12
then 'T' end +
right('0' + convert(varchar, day(@birth_day) + case @male when 1
then 0 else 40 end),2)

/*
Comune di nascita (4 caratteri alfanumerici)
Per questa parte di codice viene utilizzato il codice catastale del
comune di nascita, ossia una codifica predisposta dalla Direzione
Generale del Catasto, composta da una lettera e 3 cifre numeriche. Per i
nati al di fuori del territorio italiano si considera lo Stato estero di
nascita; in tal caso la sigla inizia con la lettera Z, seguita dal
numero identificativo della nazione.
*/

if @region_code is null return null
if @region_code not like '[a-z][0-9][0-9][0-9]' return null
set @tax = @tax + @region_code;

/*
Codice di controllo (1 lettera)
A partire dai 15 caratteri alfanumerici ricavati in precedenza, si
determina il codice di controllo in base ad un particolare algoritmo,
che opera in questo modo: si mettono da una parte i caratteri
alfanumerici che si trovano in posizione dispari (il 1º, il 3º ecc.) e
da un'altra quelli che si trovano in posizione pari (il 2º, il 4º ecc.).
Fatto questo, i caratteri vengono convertiti in valori numerici
rispettando le seguenti tabelle:
<CUT>
*/

delete @T;
insert into @T
select L = left(@tax,1), R = stuff(@tax, 1, 1, ''), N=1, 0
while (select max(N) from @T) < len(@tax)
begin
insert into @T
select top 1 L = left(R,1), R = stuff(R, 1, 1, ''), N=N+1, 0
from @T
order by N desc
if @@rowcount=0 break
end;

select @tax = @tax + char(97+k)
from (
select k=sum(case N%2 when 1 then
case L when '0' then 1 when '9' then 21 when 'I' then 19 when
'R' then 8
when '1' then 0 when 'A' then 1 when 'J' then 21 when 'S'
then 12
when '2' then 5 when 'B' then 0 when 'K' then 2 when 'T'
then 14
when '3' then 7 when 'C' then 5 when 'L' then 4 when 'U'
then 16
when '4' then 9 when 'D' then 7 when 'M' then 18 when 'V'
then 10
when '5' then 13 when 'E' then 9 when 'N' then 20 when 'W'
then 22
when '6' then 15 when 'F' then 13 when 'O' then 11 when 'X'
then 25
when '7' then 17 when 'G' then 15 when 'P' then 3 when 'Y'
then 24
when '8' then 19 when 'H' then 17 when 'Q' then 6 when 'Z'
then 23 end
else
case L when '0' then 0 when '9' then 9 when 'I' then 8 when
'R' then 17
when '1' then 1 when 'A' then 0 when 'J' then 9 when 'S' then 18
when '2' then 2 when 'B' then 1 when 'K' then 10 when 'T'
then 19
when '3' then 3 when 'C' then 2 when 'L' then 11 when 'U'
then 20
when '4' then 4 when 'D' then 3 when 'M' then 12 when 'V'
then 21
when '5' then 5 when 'E' then 4 when 'N' then 13 when 'W'
then 22
when '6' then 6 when 'F' then 5 when 'O' then 14 when 'X'
then 23
when '7' then 7 when 'G' then 6 when 'P' then 15 when 'Y'
then 24
when '8' then 8 when 'H' then 7 when 'Q' then 16 when 'Z'
then 25 end
end)%26
from @T x
)s

return upper(@tax)
end -- fn__taxcode