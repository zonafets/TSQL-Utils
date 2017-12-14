/*  leave this
    l:see LICENSE file
    g:utility
    v:080923\S.Zaglio: used to get complete error description of @@error
    t:begin declare @s nvarchar(2000) exec('truncate table_test') exec sp__outputbuffer @s out print @s end
*/
CREATE   PROC sp__outputbuffer
    @errMessage     nvarchar(1000) out
AS
set nocount on
BEGIN
    DECLARE @dbccrow        nchar(77)
           ,@sql            nvarchar(2000)
           ,@hex            nchar(2)
           ,@byte           int
           ,@pos            int
           ,@numMsg         int
           ,@gather         int
           ,@count          int
           ,@byteNum        int
           ,@msgLen         int
           ,@errMsgLen      int
           ,@nchar          int
           ,@errNumber      bigint
           ,@errState       int
           ,@errLevel       int

           ,@errInstance    nvarchar(256)
           ,@errProcedure   nvarchar(256)
           ,@errLine        int

/*
A buffer sample

00000000   04 01 00 c8 00 37 01 00 aa 30 00 50 c3 00 00 01   ...È.7..ª0.PÃ...
00000010   10 07 00 54 00 45 00 53 00 54 00 20 00 30 00 31   ...T.E.S.T. .0.1
00000020   00 0a 45 00 4e 00 54 00 45 00 52 00 50 00 52 00   ..E.N.T.E.R.P.R.
00000030   49 00 53 00 45 00 00 01 00 00 00 fd 03 00 f6 00   I.S.E......ý..ö.
00000040   00 00 00 00 00 00 00 00 aa 30 00 50 c3 00 00 02   ........ª0.PÃ...
00000050   11 07 00 54 00 45 00 53 00 54 00 20 00 30 00 32   ...T.E.S.T. .0.2
00000060   00 0a 45 00 4e 00 54 00 45 00 52 00 50 00 52 00   ..E.N.T.E.R.P.R.
00000070   49 00 53 00 45 00 00 02 00 00 00 fd 03 00 f6 00   I.S.E......ý..ö.
00000080   00 00 00 00 00 00 00 00 aa 30 00 50 c3 00 00 03   ........ª0.PÃ...
00000090   12 07 00 54 00 45 00 53 00 54 00 20 00 30 00 33   ...T.E.S.T. .0.3
000000a0   00 0a 45 00 4e 00 54 00 45 00 52 00 50 00 52 00   ..E.N.T.E.R.P.R.
000000b0   49 00 53 00 45 00 00 03 00 00 00 fd 02 00 f6 00   I.S.E......ý..ö.
000000c0   00 00 00 00 00 00 00 00 30 00 20 00 36 00 64 00   ........0. .6.d.

We need to scan the buffer for the byte marker 0xAA that starts an error message.

The problem with this approach is that if the buffer contains any user data it might
have the marker byte and thus provoking a false response.

*/

    -- Catch the output buffer.
    CREATE TABLE #DBCCOUT (col1 nchar(77))
    INSERT INTO #DBCCOUT
         EXEC ('DBCC OUTPUTBUFFER(@@spid)')

    CREATE TABLE #errors
    (
         errNumber    bigint
        ,errState     int
        ,errLevel     int
        ,errMessage   nvarchar(1000)
        ,errInstance  nvarchar(256)
        ,errProcedure nvarchar(256)
        ,errLine      int
    )

    -- Step through the buffer lines.
    DECLARE error_cursor CURSOR STATIC FORWARD_ONLY FOR
        SELECT col1
        FROM   #DBCCOUT
        ORDER  BY col1

    -- Init variable, and open cursor.
    OPEN error_cursor
    FETCH NEXT FROM error_cursor INTO @dbccrow

    -- Count the number of error messages
    SET @numMsg = 0

    SET @pos    = 12
    SET @gather = 0

    -- Now assemble rest of string.
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
Start:
        IF (@pos > 57)
        BEGIN
            SET @pos = 12
            GOTO NextRow
        END

        -- Get a byte from th stream
        SET @hex = Substring(@dbccrow, @pos, 2)

        -- Convert hexstring to int
        SELECT @sql = 'SELECT @int = convert(int, 0x00' + @hex + ')'
        EXEC sp_executesql @sql, N'@int int OUTPUT', @byte output
        -- move to the next byte
        SET @pos = @pos + 3

        IF (@gather = 0)
        BEGIN
            /*
             * Searching for the 0xAA marker
             */
            IF (@byte != 170)
                GOTO Start

            SET @gather = 1
            SET @count  = 0
            SET @msgLen = 0
            GOTO Start
        END

        IF (@gather = 1)
        BEGIN
            /*
             * Get the Message Length
             */
            SET @count  = @count + 1
            SET @msgLen = (@msgLen * 256) + @byte

            IF (@count = 2)
            BEGIN
                SET @count     = 0
                SET @byteNum   = 0
                SET @errNumber = 0
                SET @gather    = 2
            END

            GOTO Start
        END

        /*
         * Count the number of bytes of the message
         */
        IF (@gather > 1)
            SET @byteNum = @byteNum + 1

        IF (@gather = 2)
        BEGIN
            /*
             * Get the error message
             */
            SET @errNumber = IsNull(@errNumber, 0) + (@byte * power(256, @count))
            SET @count     = @count + 1
            IF (@count = 4)
            BEGIN
                SET @count  = 0
                SET @gather = 3
            END

            GOTO Start
        END

        IF (@gather = 3)
        BEGIN
            /*
             * Get the Error State
             */
            SET @gather   = 4
            SET @errState = @byte

            GOTO Start
        END

        IF (@gather = 4)
        BEGIN
            /*
             * Get the Error Level
             */
            SET @gather   = 5
            SET @errLevel = @byte

            GOTO Start
        END

        IF (@gather = 5)
        BEGIN
            /*
             * Get the error message length
             */
            SET @errMsgLen = IsNull(@errMsgLen, 0) + (@byte * Power(256, @count))
            SET @count     = @count + 1
            IF (@count = 2)
            BEGIN
                SET @nchar  = 0
                SET @count  = 0
                SET @gather = 6
            END

            GOTO Start
        END

        IF (@gather = 6)
        BEGIN
            IF (@errMsgLen > 0)
            BEGIN
                /*
                 * Get the error message text
                 */
                SET @nchar = IsNull(@nchar, 0) + (@byte * Power(256, @count))
                SET @count = @count + 1
                IF (@count = 2)
                BEGIN
                    SET @count = 0
                    SET @errMessage = IsNull(@errMessage, '') + nchar(@nchar)
                    SET @nchar = 0
                END

                IF (Len(@errMessage) = @errMsgLen)
                    SET @gather = 7

                GOTO Start
            END
            ELSE
                SET @gather = 7
        END

        IF (@gather = 7)
        BEGIN
            /*
             * Get the instance size
             */
            SELECT @gather    = 8
                  ,@errMsgLen = @byte
                  ,@nchar     = 0

            Goto Start
        END

        IF (@gather = 8)
        BEGIN
            IF (@errMsgLen > 0)
            BEGIN
                /*
                 * Get the instance name
                 */
                SET @nchar = IsNull(@nchar, 0) + (@byte * Power(256, @count))
                SET @count = @count + 1
                IF (@count = 2)
                BEGIN
                    SET @count = 0
                    SET @errInstance = IsNull(@errInstance, '') + nchar(@nchar)
                    SET @nchar = 0
                END

                IF (Len(@errInstance) = @errMsgLen)
                    SET @gather = 9

                GOTO Start
            END
            ELSE
                SET @gather = 9
        END

        IF (@gather = 9)
        BEGIN
            /*
             * Get the procedure size
             */
            SELECT @gather    = 10
                  ,@errMsgLen = @byte
                  ,@nchar     = 0

            Goto Start
        END

        IF (@gather = 10)
        BEGIN
            IF (@errMsgLen > 0)
            BEGIN
                /*
                 * Get the procedure name
                 */
                SET @nchar = IsNull(@nchar, 0) + (@byte * Power(256, @count))
                SET @count = @count + 1
                IF (@count = 2)
                BEGIN
                    SET @count = 0
                    SET @errProcedure = IsNull(@errProcedure, '') + nchar(@nchar)
                    SET @nchar = 0
                END

                IF (Len(@errProcedure) = @errMsgLen)
                    SET @gather = 11

                GOTO Start
            END
            ELSE
                SET @gather = 11
        END

        IF (@gather = 11)
        BEGIN
            /*
             * Get the error message length
             */
            SET @errLine = IsNull(@errLine, 0) + (@byte * Power(256, @count))
            SET @count   = @count + 1
            IF (@count = 2)
            BEGIN
                SET @nchar  = 0
                SET @count  = 0
                SET @gather = 0
                SET @nchar  = 0

                INSERT #errors VALUES (@errNumber, @errState, @errLevel, @errMessage, @errInstance, @errProcedure, @errLine)
            END

            GOTO Start
        END

NextRow:
        FETCH NEXT FROM error_cursor INTO @dbccrow
    END

    CLOSE error_cursor
    DEALLOCATE error_cursor

    SELECT top 1 @errMessage=errMessage FROM #errors
END