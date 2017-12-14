/*  leave this
    l:see LICENSE file
    g:utility
    v:000000\s.zaglio:used by sp_displaypkgerrors,execute_dts,run_dts
*/
CREATE  PROC sp__displayoaerrorinfo
    @object as int,
    @hr as int=0
AS

DECLARE @output nvarchar(255)
DECLARE @source nvarchar(255)
DECLARE @description nvarchar(255)

PRINT 'OLE Automation Error Information'

EXEC @hr = sp_OAGetErrorInfo @object, @source OUT, @description OUT
IF @hr = 0
    BEGIN
        SELECT @output = ' Source: ' + @source
        PRINT @output
        SELECT @output = ' Description: ' + @description
        PRINT @output
    END
ELSE
    BEGIN
        PRINT ' sp_OAGetErrorInfo failed.'
        RETURN
    END