/*  leave this
    l:see LICENSE file
    g:utility
    k:html,parse,get,table
    v:120905\s.zaglio: quiet out, use dbg to show info
    v:120824.1400\s.zaglio: get a table but not all
    r:120823\s.zaglio: add temp SP for web operations
    t:sp__web_tool @opt='install'
*/
CREATE proc sp__web_tool
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp
declare
    @proc sysname, @err int, @ret int -- @ret: 0=OK -1=HELP, any=error id
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
if @opt='||' goto help

-- ============================================================== declaration ==
-- declare -- insert before here --  @end_declare bit
-- =========================================================== initialization ==
-- select -- insert before here --  @end_declare=1
-- ======================================================== second params chk ==
-- ===================================================================== body ==

-- ##########################
-- ##
-- ## BEGIN OF RUETER'S CODE
-- ##
-- ########################################################

/*
SQLDOM HTML parser and DOM tools for MSSQL.
https://sourceforge.net/projects/sqldom/

Parses HTML from a string or from a URL into a DOM (document object model)
implemented with SQL tables.  Provides routines to manipulate the DOM data
and to render the DOM data back to HTML.

You may safely run this entire script:  it does not make any changes to any
SQL user databases.  It only creates some local temporary tables and temporary
stored procedures, and prints out a string with some instructions.

Requires Microsoft SQL 2005 or later.

Copyright (C) 2012 David B. Rueter (drueter@assyst.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

HISTORY

Version .924 4/24/2012
  Fixed attribute handling to support attributes without values (such as <
  option selected>My Option</option>)  Thanks to JMelin for reporting.

Version .923 4/3/2012
  Fixed additional bug in #spgetDOM pertaining to getting by selector.

Version .922 3/20/2012
  Fixed bug in #spgetDOM pertaining to getting by selector.  Thanks to Brian Hurtt
  for reporting and providing correction.

Version .921 3/5/2012
  Added #sputilConvertJSONToXML to convert JSON data to XML

Version .920 2/23/2012
  Refactor #spgetDOMHTML to fix bugs, streamline

Version .919 2/21/2012
  Corrected problem with rendering HTML comments

Version .918  2/20/2012
  Removed dependencies on 3 UDF string helper functions
  Performance increase (approx. 23%)
  Clean up some comments

Version .917  2/19/2012
  Initial public version

*/

SET NOCOUNT ON

IF OBJECT_ID('tempdb..#spactTrimWhitespace') IS NOT NULL BEGIN
  DROP PROCEDURE #spactTrimWhitespace
END

IF OBJECT_ID('tempdb..#spgetLenNTW') IS NOT NULL BEGIN
  DROP PROCEDURE #spgetLenNTW
END

if charindex('|keep|',@opt)=0
    begin

    IF OBJECT_ID('tempdb..#tblDOMDocs') IS NOT NULL BEGIN
      DROP TABLE #tblDOMDocs
    END

    IF OBJECT_ID('tempdb..#tblDOM') IS NOT NULL BEGIN
      DROP TABLE #tblDOM
    END

    IF OBJECT_ID('tempdb..#tblDOMAttribs') IS NOT NULL BEGIN
      DROP TABLE #tblDOMAttribs
    END

    IF OBJECT_ID('tempdb..#tblDOMStyles') IS NOT NULL BEGIN
      DROP TABLE #tblDOMStyles
    END
    end -- keep option

IF OBJECT_ID('tempdb..#spactDOMOpen') IS NOT NULL BEGIN
  DROP PROCEDURE #spactDOMOpen
END

IF OBJECT_ID('tempdb..#spgetDOM') IS NOT NULL BEGIN
  DROP PROCEDURE #spgetDOM
END

IF OBJECT_ID('tempdb..#spgetDOMHTML') IS NOT NULL BEGIN
  DROP PROCEDURE #spgetDOMHTML
END

IF OBJECT_ID('tempdb..#spactDOMLoad') IS NOT NULL BEGIN
  DROP PROCEDURE #spactDOMLoad
END

IF OBJECT_ID('tempdb..#spinsDOMNode') IS NOT NULL BEGIN
  DROP PROCEDURE #spinsDOMNode
END

IF OBJECT_ID('tempdb..#spactDOMClear') IS NOT NULL BEGIN
  DROP PROCEDURE #spactDOMClear
END

IF OBJECT_ID('tempdb..#spupdDOMAttribs') IS NOT NULL BEGIN
  DROP PROCEDURE #spupdDOMAttribs
END

IF OBJECT_ID('tempdb..#spupdDOMStyles') IS NOT NULL BEGIN
  DROP PROCEDURE #spupdDOMStyles
END

IF OBJECT_ID('tempdb..#sputilGetHTTP') IS NOT NULL BEGIN
  DROP PROCEDURE #sputilGetHTTP
END

IF OBJECT_ID('tempdb..#sputilConvertJSONToXML') IS NOT NULL BEGIN
  DROP PROCEDURE #sputilConvertJSONToXML
END

if charindex('|uninstall|',@opt)>0 goto ret
if charindex('|install|',@opt)>0
begin
/*
**************************************************************************************
PROCEDURE #spactTrimWhitespace
Simple helper function to do a left-trim  or right-trim of whitespace (spaces, tabs,
carriage returns and linefeeds, and tabs).
I would really prefer this to be a function, but we are not allowed to create
temporary functions, and I do not want SQLDOM to require permanent database objects.
**************************************************************************************
*/
exec('
CREATE PROCEDURE #spactTrimWhitespace
@S varchar(MAX) OUTPUT,
@DoLeft bit = 0,
@DoRight bit = 1
AS BEGIN
  DECLARE @P int

  IF @DoRight = 1 BEGIN
    --Right trim
    SET @P = LEN(@S + ''x'') - 1
    WHILE @P >= 1 BEGIN
      IF ISNULL(SUBSTRING(@S, @P, 1), '' '') IN ('' '', CHAR(9), CHAR(10), CHAR(13)) BEGIN
        SET @P = @P - 1
      END
      ELSE BEGIN
        BREAK
      END
    END

    SET @S= LEFT(@S, @P)
  END

  IF @DoLeft = 1 BEGIN
    --Left trim
    SET @P = 1
    WHILE @P <= LEN(@S + ''x'') - 1 BEGIN
      IF SUBSTRING(@S, @P, 1) IN  ('' '', CHAR(9), CHAR(10), CHAR(13)) BEGIN
        SET @P = @P + 1
      END
      ELSE BEGIN
        BREAK
      END
    END

    SET @S = RIGHT(@S, LEN(@S + ''x'') - 1 - @P + 1)
  END

END
')

/*
**************************************************************************************
PROCEDURE #spgetLenNTW (no trailing whitespace)
Simple helper function to determine the length of a string after trimming all
trailing whitespace (spaces, tabs, carriage returns and linefeeds, and tabs).
I would really prefer this to be a function, but we are not allowed to create
temporary functions, and I do not want SQLDOM to require permanent database objects.
**************************************************************************************
*/
exec('
CREATE PROCEDURE #spgetLenNTW
@S varchar(MAX),
@Len int OUTPUT
AS
BEGIN
  SET @Len = LEN(@S + ''x'') - 1

  DECLARE @Done bit
  SET @Done = 0

  WHILE @Done = 0 BEGIN
    IF (@Len > 0) AND (SUBSTRING(@S, @Len, 1) IN (CHAR(9), CHAR(10), CHAR(13), '' '')) BEGIN
      SET @Len = @Len - 1
    END
    ELSE BEGIN
      SET @Done = 1
    END
  END

END
')

/*
**************************************************************************************
PROCEDURE #spactDOMOpen
Procedure #spactDOMOpen verifies session and @DocID
**************************************************************************************
*/
exec('
CREATE PROCEDURE #spactDOMOpen
@DocID int OUTPUT,
@CreateNew bit = 0
AS
BEGIN
  --Note:  if @DocID is provided, we trust it.  We don''t validate that it exists
  --or that it belongs to this session.

  IF (@CreateNew = 1) BEGIN
    IF @DocID IS NOT NULL BEGIN
      RAISERROR(''Error in #spactDOMOpen:  Cannot specify @DocID if @CreateNew=1'', 16, 1)
    END

    INSERT INTO #tblDOMDocs (DateCreated)
    VALUES (GETDATE())

    SET @DocID = SCOPE_IDENTITY()
  END
  ELSE BEGIN
    IF @DocID IS NOT NULL BEGIN
      IF NOT EXISTS (SELECT DocID FROM #tblDomDocs WHERE DocID = @DocID) BEGIN
        RAISERROR(''Error in #spactDOMOpen: Invalid @DocID specified.'', 16, 1)
      END
    END
    ELSE BEGIN
      --Open a new DOM Document

      DECLARE @DocCount int
      IF @DocID IS NULL BEGIN
        SELECT
          @DocCount = COUNT(doc.DocID),
          @DocID = MIN(doc.DocID)
        FROM
          #tblDOMDocs doc

        IF @DocCount > 1 BEGIN
          RAISERROR(''Error in #spactDOMOpen:  @DocID was not specified, and there are multiple documents present in this session.'', 16, 1)
        END
        ELSE IF @DocID IS NULL BEGIN
          INSERT INTO #tblDOMDocs (DateCreated)
          VALUES (GETDATE())

          SET @DocID = SCOPE_IDENTITY()
        END
      END
    END
  END
END
')

/*
**************************************************************************************
PROCEDURE #spactDOMClear
Procedure #spactDOMClear clears all data in the DOM
**************************************************************************************
*/
exec('
CREATE PROCEDURE #spactDOMClear
@DocID int = NULL OUTPUT
AS BEGIN

  DELETE FROM #tblDOMAttribs WHERE DEID IN (SELECT DEID FROM #tblDOM WHERE @DocID IS NULL OR DocID = @DocID)
  DELETE FROM #tblDOMStyles WHERE DEID IN (SELECT DEID FROM #tblDOM WHERE @DocID IS NULL OR DocID = @DocID)
  DELETE FROM #tblDOM WHERE @DocID IS NULL OR DocID = @DocID

END
')

/*
**************************************************************************************
PROCEUDRE #spupdDOMAttribs
Procedure #spupdDOMAttribs is to set Attributes of existing elements in the DOM
**************************************************************************************
*/
exec('
CREATE PROCEDURE #spupdDOMAttribs
@DocID int = NULL OUTPUT,
@DEID int = NULL,
@ID varchar(512) = NULL,
@Name varchar(512) = NULL,
@Value varchar(MAX) = NULL,
@Attribs varchar(MAX) = NULL,
@Selector varchar(MAX) = NULL
AS
BEGIN
  SET @Value = NULLIF(RTRIM(@Value), '''')

  IF @DocID IS NULL EXEC #spactDOMOpen @DocID = @DocID OUTPUT

  DECLARE @tvTargetList TABLE (
    DEID int PRIMARY KEY
  )

  IF @ID IS NOT NULL BEGIN
    SELECT @DEID = dom.DEID
    FROM
      #tblDOM dom
    WHERE
      dom.DocID = @DocID AND
      dom.ID = @ID
  END
  ELSE IF @Selector IS NOT NULL BEGIN
    INSERT INTO @tvTargetList (DEID)
    EXEC #spgetDOM @DocID = @DocID OUTPUT, @Selector = @Selector, @ReturnDEIDsOnly = 1
    SELECT TOP 1 @DEID = DEID FROM @tvTargetList
  END

  WHILE @DEID IS NOT NULL BEGIN

    IF ISNULL(RTRIM(@Attribs), '''') = '''' BEGIN
      DECLARE @TargetID int
      SELECT @TargetID = atr.DomAttribID
      FROM #tblDOMAttribs atr
      WHERE
         atr.DEID = @DEID AND
         atr.Name = @Name


      IF @TargetID IS NOT NULL BEGIN
        IF @Value IS NULL BEGIN
          DELETE FROM #tblDOMAttribs WHERE DOMAttribID = @TargetID
        END
        ELSE BEGIN
          UPDATE #tblDOMAttribs SET Value = @Value WHERE DOMAttribID = @TargetID
        END
      END
      ELSE BEGIN
        INSERT INTO #tblDOMAttribs (
          DEID,
          Name,
          Value)
        VALUES (
          @DEID,
          @Name,
          @Value
        )
      END

      --Assign special attributes
      UPDATE dom
      SET
        ID = ISNULL(at_id.Value, dom.ID),
        Name = ISNULL(at_name.Value, dom.Name),
        Class = ISNULL(at_class.Value, dom.Class)
      FROM
        #tblDOM dom
        LEFT JOIN #tblDOMAttribs at_id ON dom.DEID = at_id.DEID AND at_id.Name = ''id''
        LEFT JOIN #tblDOMAttribs at_name ON dom.DEID = at_name.DEID AND at_name.Name = ''name''
        LEFT JOIN #tblDOMAttribs at_class ON dom.DEID = at_class.DEID AND at_class.Name = ''class''
      WHERE
        dom.DocID = @DocID AND
        dom.DEID = @DEID


      DELETE FROM #tblDOMAttribs
      WHERE
        DEID = @DEID AND
        Name in (''id'', ''name'', ''class'')
    END
    ELSE BEGIN
      IF RTRIM(ISNULL(@Attribs, '''')) <> '''' BEGIN
        --Parse out attributes
        DECLARE @i int
        DECLARE @c char
        DECLARE @State varchar(40)
        DECLARE @InQuote bit
        DECLARE @NameStr varchar(MAX)
        DECLARE @ValueStr varchar(MAX)
        DECLARE @StartQuote char

        DECLARE @DoAttrib bit

        SET @InQuote = 0

        SET @StartQuote = NULL
        SET @State = ''AttribName''
        SET @i = 1

        SET @NameStr = ''''
        SET @ValueStr = ''''

        WHILE @i <= LEN(@Attribs) BEGIN
          SET @c = SUBSTRING(@Attribs, @i, 1)

          IF (@State = ''AttribValue'') BEGIN
            IF (@c IN (''"'', '''''''')) BEGIN
              IF (@InQuote = 0) AND ((@StartQuote IS NULL) OR (@c = @StartQuote)) BEGIN
                SET @InQuote = 1
                IF @StartQuote IS NULL BEGIN
                  SET @StartQuote = @c
                END
              END
              ELSE IF (@InQuote = 1) AND (@c = @StartQuote) BEGIN
                SET @InQuote = 0
                IF (@i >= 2) AND (SUBSTRING(@Attribs, @i -1 , 1) = @c) BEGIN
                  SET @ValueStr = @ValueStr + @C
                END
              END
              ELSE IF @c <> @StartQuote BEGIN
                SET @ValueStr = @ValueStr + @c
              END
            END
            ELSE BEGIN
              SET @ValueStr = @ValueStr + @c
            END

            IF ((@c = '' '') AND @InQuote = 0) OR (@i = LEN(@Attribs)) BEGIN
              SET @DoAttrib = 1
              SET @State = ''AttribName''
            END
          END

          ELSE BEGIN
            IF @State = ''AttribName'' BEGIN
              IF @c = ''='' BEGIN
                SET @State = ''AttribValue''
              END
              ELSE IF (@c = '' '') BEGIN
                SET @DoAttrib = 1
              END
              ELSE IF @i = LEN(@Attribs) BEGIN
                SET @NameStr = @NameStr + @c
                SET @DoAttrib = 1
              END
              ELSE BEGIN
                IF @c <> '' '' BEGIN
                  SET @NameStr = @NameStr + @c
                END
              END
            END
          END

          IF @DoAttrib = 1 BEGIN
            SET @DoAttrib = 0
            EXEC #spupdDOMAttribs
              @DocID = @DocID OUTPUT,
              @DEID = @DEID,
              @Name = @NameStr,
              @Value = @ValueStr

            SET @NameStr = ''''
            SET @ValueStr = ''''
          END

          SET @i = @i + 1
        END

      END
    END

    DELETE FROM @tvTargetList WHERE DEID = @DEID

    SET @DEID = NULL

    IF EXISTS(SELECT DEID FROM @tvTargetList) BEGIN
      SELECT TOP 1 @DEID = DEID FROM @tvTargetList
    END
  END
END
')

/*
**************************************************************************************
PROCEDURE #spinsDOMNode
Procedure #spinsDOMNode is to ADD elements to the DOM
**************************************************************************************
*/
exec('
CREATE PROCEDURE #spinsDOMNode
@DocID int = NULL OUTPUT,
@Tag varchar(MAX),
@ID varchar(512) = NULL,
@Name varchar(512) = NULL,
@Class varchar(512) = NULL,
@Text varchar(MAX) = NULL,
@Attribs varchar(MAX) = NULL,
@OpenTagStartPos int = NULL,
@CloseTagEndPos int = NULL,
@ParentID varchar(512) = NULL,
@ParentDEID int = NULL,
@DEID int = NULL OUTPUT
AS
BEGIN

  /*
    Adds the specified node to the #tblDOM. If @Tag is specified, but @Text is not specified,
    a single normal node is added. If @Text is specified, then TWO nodes are added: one for
    the specified @Tag, and then a child text node.  (Text nodes have only the TextData and
    the ParentDEID:  they do not have tags or other attributes.)

    If @Tag is null, then only a text node is added.  It is added as a child of the parent that
    was specified.

    HTML comments are a special case.  For these the tag will be !-- and the comment node itself
    will store the comment body in TextData.  TextData will contain the start and end tags
    for the comment (such as <!-- Hello World -->).  There will not be a child text node.

    If @ParentID is specified, #tblDOM is searched for an existing node that has the
    specified HTML ID.  If found, the corresponding ParentDEID will be used as the parent
    for the new node.  Alternately, @ParentDEID may be spedified directly.  If both
    @ParentID and @ParentDEID are null, then the node will be added with a null parent--
    which indicates that it is a top level (or root level) node.

  */
  IF @DocID IS NULL EXEC #spactDOMOpen @DocID = @DocID OUTPUT

  IF @ParentID IS NOT NULL BEGIN
    SELECT @ParentDEID = dom.DEID
    FROM
      #tblDOM dom
    WHERE
      dom.DocID = @DocID AND
      dom.ID = @ParentID
  END

  SET @DEID = NULL

  IF (@Tag IS NOT NULL) BEGIN
    INSERT INTO #tblDOM (
      DocID,
      Tag,
      ID,
      Name,
      Class,
      TextData,
      OpenTagStartPos,
      CloseTagEndPos,
      ParentDEID)
    VALUES (
      @DocID,
      LOWER(@Tag),
      @ID,
      @Name,
      @Class,
      CASE WHEN (@Tag = ''!--'') THEN @Text ELSE NULL END,
      @OpenTagStartPos,
      @CloseTagEndPos,
      @ParentDEID)

    SET @DEID = SCOPE_IDENTITY()
    SET @ParentDEID = @DEID

    --Store attributes
    IF ISNULL(RTRIM(@Attribs), '''') <> '''' BEGIN
      EXEC #spupdDOMAttribs
        @DocID = @DocID OUTPUT,
        @DEID = @DEID,
        @Attribs = @Attribs
    END

  END

  IF (ISNULL(@Tag, '''') <> ''!--'') AND (@Text IS NOT NULL) BEGIN
    INSERT INTO #tblDOM (
      DocID,
      Tag,
      ID,
      Name,
      Class,
      TextData,
      ParentDEID)
    SELECT
      @DocID,
      NULL AS Tag,
      NULL AS ID,
      NULL AS Name,
      NULL AS Class,
      @Text,
      @ParentDEID
  END


END
')

/*
**************************************************************************************
PROCEDURE #spupdDOMStyles
Procedure #spupdDOMStyles is to set Styles of existing elements in the DOM
**************************************************************************************
*/
exec('
CREATE PROCEDURE #spupdDOMStyles
@DocID int = NULL,
@DEID int = NULL,
@ID varchar(512) = NULL,
@Name varchar(512),
@Value varchar(MAX)
AS
BEGIN
  IF @DocID IS NULL EXEC #spactDOMOpen @DocID = @DocID OUTPUT

  IF @ID IS NOT NULL BEGIN
    SELECT
      @DEID = dom.DEID
    FROM
      #tblDOM dom
    WHERE
      dom.DocID = @DocID AND
      dom.ID = @ID
  END
  ELSE BEGIN
    SELECT
      @DEID = dom.DEID
    FROM
      #tblDOM dom
    WHERE
      dom.DocID = @DocID AND
      dom.DEID = @DEID
  END

  DECLARE @TargetID int
  SELECT @TargetID = DOMStyleID FROM #tblDOMStyles WHERE DEID = @DEID AND Name = @Name

  IF @TargetID IS NOT NULL BEGIN
    IF @Value IS NULL BEGIN
      DELETE FROM #tblDOMStyles WHERE DOMStyleID = @TargetID
    END
    ELSE BEGIN
      UPDATE #tblDOMStyles SET Value = @Value
      WHERE
        DOMStyleID = @TargetID
    END
  END
  ELSE BEGIN
    INSERT INTO #tblDOMStyles (
      DEID,
      Name,
      Value)
    VALUES (
      @DEID,
      @Name,
      @Value
    )
  END
END
')

/*
*******************************************************************4*******************
PROCEDURE #spgetDOM
Procedure #spgetDOM is to retrive the internal DOM information as a resultset.
Provides JQuery-like functionality to select nodes from the DOM based on the
specified selector.  The selector can indicate #classes, .id''s or tags.
If @Selector = NULL, the entire DOM will be returned.
**************************************************************************************
*/
exec('
CREATE PROCEDURE #spgetDOM
@DocID int = NULL OUTPUT,
@Selector varchar(900) = NULL,
@ReturnDEIDsOnly bit = 0
AS
BEGIN
  IF @DocID IS NULL EXEC #spactDOMOpen @DocID = @DocID OUTPUT

  IF @Selector IS NULL BEGIN
    --CTE Start -----------------------
    ;WITH DOMTree (
      DEID,
      DocID,
      Tag,
      ID,
      Name,
      Class,
      TextData,
      OpenTagStartPos,
      CloseTagEndPos,
      ParentDEID,
      HUID,
      SortHUID,
      DOMLevel
    )
    AS
    (
    SELECT
      dom.DEID,
      dom.DocID,
      dom.Tag,
      dom.ID,
      dom.Name,
      dom.Class,
      dom.TextData,
      dom.OpenTagStartPos,
      dom.CloseTagEndPos,
      dom.ParentDEID,
      CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)) AS HUID,
      CAST(RIGHT(''000000'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)), 6) AS varchar(900)) AS SortHUID,
      1 AS DOMLevel
    FROM
      #tblDOM dom
    WHERE
      dom.ParentDEID IS NULL

    UNION ALL

    SELECT
      dom.DEID,
      dom.DocID,
      dom.Tag,
      dom.ID,
      dom.Name,
      dom.Class,
      dom.TextData,
      dom.OpenTagStartPos,
      dom.CloseTagEndPos,
      dom.ParentDEID,
      CAST(domch.HUID + ''.'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)) AS varchar(900)) AS HUID,
      CAST(domch.SortHUID + ''.'' + RIGHT(''000000'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)), 6) AS varchar(900)) AS SortHUID,
      domch.DOMLevel + 1
    FROM
      DOMTree domch
      JOIN #tblDOM dom ON
        domch.DEID = dom.ParentDEID
    )
    --CTE End -----------------------

    SELECT *
    FROM
      DOMTree dom
    WHERE
      dom.DocID = @DocID
    ORDER BY
      dom.SortHUID

  END
  ELSE BEGIN

    SET @Selector = RTRIM(@Selector) + '' ''

    DECLARE @c char
    DECLARE @i int

    DECLARE @Mode varchar(40)
    DECLARE @SelWhere varchar(MAX)
    DECLARE @SelTerm varchar(MAX)


    --default selector is Tag
    SET @Mode = ''tag''

    SET @i = 1
    WHILE @i <= LEN(@Selector) BEGIN

      SET @c = SUBSTRING(@Selector, @i, 1)

      IF @c IN (''.'', ''#'', '' '') BEGIN
        IF @c = ''.'' BEGIN
          SET @Mode = ''id''
        END
        ELSE IF @c = ''#'' BEGIN
          SET @Mode = ''class''
        END
        ELSE IF @C = '' '' BEGIN
          --apply selector
          SET @SelWhere = ISNULL(@SelWhere + '' AND '', '''') + @SelTerm
        END
        SET @SelTerm = NULL
      END
      ELSE BEGIN
        SET @SelTerm = ISNULL(@SelTerm, '''') + @c
      END

      SET @i = @i + 1
    END

    IF @ReturnDEIDsOnly = 1 BEGIN
      IF @Mode = ''class'' BEGIN
        SELECT DEID
        FROM
          #tblDOM dom
        WHERE
          dom.DocID = @DocID AND
          dom.Class = @SelTerm
      END
      ELSE IF @Mode = ''id'' BEGIN
        SELECT DEID
        FROM
          #tblDOM dom
        WHERE
          dom.DocID = @DocID AND
          dom.ID = @SelTerm
      END
      ELSE IF @Mode = ''tag'' BEGIN
        SELECT DEID
        FROM
          #tblDOM dom
        WHERE
          dom.DocID = @DocID AND
          dom.Tag = @SelTerm
      END
    END
    ELSE BEGIN
      IF @Mode = ''class'' BEGIN
        --CTE Start -----------------------
        ;WITH DOMTree (
          DEID,
          DocID,
          Tag,
          ID,
          Name,
          Class,
          TextData,
          OpenTagStartPos,
          CloseTagEndPos,
          ParentDEID,
          HUID,
          SortHUID,
          DOMLevel
        )
        AS
        (
        SELECT
          dom.DEID,
          dom.DocID,
          dom.Tag,
          dom.ID,
          dom.Name,
          dom.Class,
          dom.TextData,
          dom.OpenTagStartPos,
          dom.CloseTagEndPos,
          dom.ParentDEID,
          CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)) AS HUID,
          CAST(RIGHT(''000000'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)), 6) AS varchar(900)) AS SortHUID,
          1 AS DOMLevel
        FROM
          #tblDOM dom
        WHERE
          dom.ParentDEID IS NULL

        UNION ALL

        SELECT
          dom.DEID,
          dom.DocID,
          dom.Tag,
          dom.ID,
          dom.Name,
          dom.Class,
          dom.TextData,
          dom.OpenTagStartPos,
          dom.CloseTagEndPos,
          dom.ParentDEID,
          CAST(domch.HUID + ''.'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)) AS varchar(900)) AS HUID,
          CAST(domch.SortHUID + ''.'' + RIGHT(''000000'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)), 6) AS varchar(900)) AS SortHUID,
          domch.DOMLevel + 1
        FROM
          DOMTree domch
          JOIN #tblDOM dom ON
            domch.DEID = dom.ParentDEID
        )
        --CTE End -----------------------

        SELECT
          dt.DEID,
          dt.DocID,
          dt.Tag,
          dt.ID,
          dt.Name,
          dt.Class,
          dt.TextData,
          dt.OpenTagStartPos,
          dt.CloseTagEndPos,
          dt.ParentDEID,
          dt.HUID,
          dt.SortHUID,
          dt.DOMLevel,
          ROW_NUMBER() OVER (ORDER BY dt.SortHUID) AS Sequence
        FROM
          DomTree dt
          JOIN #tblDOMDocs doc ON
            dt.DocID = doc.DocID
        WHERE
          dt.DocID = @DocID AND
          dt.Class = @SelTerm
        ORDER BY
          dt.sortHUID
      END
      ELSE IF @Mode = ''id'' BEGIN
        --CTE Start -----------------------
        ;WITH DOMTree (
          DEID,
          DocID,
          Tag,
          ID,
          Name,
          Class,
          TextData,
          OpenTagStartPos,
          CloseTagEndPos,
          ParentDEID,
          HUID,
          SortHUID,
          DOMLevel
        )
        AS
        (
        SELECT
          dom.DEID,
          dom.DocID,
          dom.Tag,
          dom.ID,
          dom.Name,
          dom.Class,
          dom.TextData,
          dom.OpenTagStartPos,
          dom.CloseTagEndPos,
          dom.ParentDEID,
          CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)) AS HUID,
          CAST(RIGHT(''000000'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)), 6) AS varchar(900)) AS SortHUID,
          1 AS DOMLevel
        FROM
          #tblDOM dom
        WHERE
          dom.ParentDEID IS NULL

        UNION ALL

        SELECT
          dom.DEID,
          dom.DocID,
          dom.Tag,
          dom.ID,
          dom.Name,
          dom.Class,
          dom.TextData,
          dom.OpenTagStartPos,
          dom.CloseTagEndPos,
          dom.ParentDEID,
          CAST(domch.HUID + ''.'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)) AS varchar(900)) AS HUID,
          CAST(domch.SortHUID + ''.'' + RIGHT(''000000'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)), 6) AS varchar(900)) AS SortHUID,
          domch.DOMLevel + 1
        FROM
          DOMTree domch
          JOIN #tblDOM dom ON
            domch.DEID = dom.ParentDEID
        )
        --CTE End -----------------------
        SELECT
          dt.DEID,
          dt.DocID,
          dt.Tag,
          dt.ID,
          dt.Name,
          dt.Class,
          dt.TextData,
          dt.OpenTagStartPos,
          dt.CloseTagEndPos,
          dt.ParentDEID,
          dt.HUID,
          dt.SortHUID,
          dt.DOMLevel,
          ROW_NUMBER() OVER (ORDER BY dt.SortHUID) AS Sequence
        FROM
          DomTree dt
          JOIN #tblDOMDocs doc ON
            dt.DocID = doc.DocID
        WHERE
          dt.DocID = @DocID AND
          dt.ID = @SelTerm
        ORDER BY
          dt.sortHUID
      END
      ELSE IF @Mode = ''tag'' BEGIN
        --CTE Start -----------------------
        ;WITH DOMTree (
          DEID,
          DocID,
          Tag,
          ID,
          Name,
          Class,
          TextData,
          OpenTagStartPos,
          CloseTagEndPos,
          ParentDEID,
          HUID,
          SortHUID,
          DOMLevel
        )
        AS
        (
        SELECT
          dom.DEID,
          dom.DocID,
          dom.Tag,
          dom.ID,
          dom.Name,
          dom.Class,
          dom.TextData,
          dom.OpenTagStartPos,
          dom.CloseTagEndPos,
          dom.ParentDEID,
          CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)) AS HUID,
          CAST(RIGHT(''000000'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)), 6) AS varchar(900)) AS SortHUID,
          1 AS DOMLevel
        FROM
          #tblDOM dom
        WHERE
          dom.ParentDEID IS NULL

        UNION ALL

        SELECT
          dom.DEID,
          dom.DocID,
          dom.Tag,
          dom.ID,
          dom.Name,
          dom.Class,
          dom.TextData,
          dom.OpenTagStartPos,
          dom.CloseTagEndPos,
          dom.ParentDEID,
          CAST(domch.HUID + ''.'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)) AS varchar(900)) AS HUID,
          CAST(domch.SortHUID + ''.'' + RIGHT(''000000'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)), 6) AS varchar(900)) AS SortHUID,
          domch.DOMLevel + 1
        FROM
          DOMTree domch
          JOIN #tblDOM dom ON
            domch.DEID = dom.ParentDEID
        )
        --CTE End -----------------------
        SELECT
          dt.DEID,
          dt.DocID,
          dt.Tag,
          dt.ID,
          dt.Name,
          dt.Class,
          dt.TextData,
          dt.OpenTagStartPos,
          dt.CloseTagEndPos,
          dt.ParentDEID,
          dt.HUID,
          dt.SortHUID,
          dt.DOMLevel,
          ROW_NUMBER() OVER (ORDER BY dt.SortHUID) AS Sequence
        FROM
          DomTree dt
          JOIN #tblDOMDocs doc ON
            dt.DocID = doc.DocID
          WHERE
            dt.DocID = @DocID AND
            dt.Tag = @SelTerm
          ORDER BY
            dt.sortHUID
      END
    END
  END

END
')

/*
**************************************************************************************
PROCEDURE #spgetDOMHTML
Procedure #spgetDOMHTML is to render an HTML string based on the internal data in
the DOM
**************************************************************************************
*/
exec('
CREATE PROCEDURE #spgetDOMHTML
@DocID int = NULL OUTPUT,
@ForceDocType varchar(MAX) = NULL,
@PrettyWhitespace bit = 0,
@HTML varchar(MAX) = NULL OUTPUT,
@PrintHTML bit = 1
AS
BEGIN
  DECLARE @Debug bit
  SET @Debug = 0

  IF @DocID IS NULL EXEC #spactDOMOpen @DocID = @DocID OUTPUT

  --temp table to hold local copy of DOM output by #DOM
  CREATE TABLE #Render(
    DEID int PRIMARY KEY,
    DocID int,
    Tag varchar(MAX),
    ID varchar(512),
    Name varchar(512),
    Class varchar(512),
    TextData varchar(MAX),
    OpenTagStartPos int,
    CloseTagEndPos int,
    ParentDEID int,
    HUID varchar(900),
    SortHUID varchar(900),
    DOMLevel int,
    Sequence int,
    HasChild bit
  )

  CREATE INDEX ixtmpRender_SortHUID ON #Render (SortHUID)
  CREATE INDEX ixtmpRender_Sequence ON #Render (Sequence)

  --local table to hold stack of tags
  DECLARE @tvTagStack TABLE (
    StackID int identity PRIMARY KEY, --facilitates deletes
    DEID int,
    CloseTag varchar(900)
  );

  DECLARE @CRLF varchar(5)
  SET @CRLF = CHAR(13) + CHAR(10)

  INSERT INTO #Render (
    DEID,
    DocID,
    Tag,
    ID,
    Name,
    Class,
    TextData,
    OpenTagStartPos,
    CloseTagEndPos,
    ParentDEID,
    HUID,
    SortHUID,
    DOMLevel
  )
  EXEC #spgetDOM @DocID = @DocID OUTPUT

  UPDATE r
  SET
    Sequence = r_seq.Sequence
  FROM
    #Render r
    JOIN (
      SELECT
        r.DEID,
        ROW_NUMBER() OVER (ORDER BY r.SortHUID) AS Sequence
      FROM
        #Render r
      ) r_seq ON
    r.DEID = r_seq.DEID

  UPDATE r
  SET
    HasChild = CASE WHEN r2.DOMLevel > r.DOMLevel THEN 1 ELSE 0 END
  FROM
    #Render r
    JOIN #Render r2 ON
      r.Sequence + 1 = r2.Sequence


  DECLARE curDOM CURSOR LOCAL STATIC FOR
  SELECT
    r.DEID,
    r.Tag,
    r.ID,
    r.Name,
    r.Class,
    r.TextData,
    r.ParentDEID,
    r.HUID,
    r.DOMLevel,
    r.HasChild
  FROM
    #Render r
  ORDER BY
    r.Sequence

  DECLARE @DEID int
  DECLARE @Tag varchar(MAX)
  DECLARE @ID varchar(512)
  DECLARE @Name varchar(512)
  DECLARE @Class varchar(512)
  DECLARE @TextData varchar(MAX)
  DECLARE @ParentDEID int
  DECLARE @HUID varchar(900)
  DECLARE @DOMLevel int
  DECLARE @HasChild bit


  DECLARE @RenderedHTML varchar(MAX)

  DECLARE @DonePop bit
  DECLARE @AllowPush bit

  DECLARE @StackID int
  DECLARE @StackDEID int
  DECLARE @StackTag varchar(MAX)

  DECLARE @EmitTag varchar(MAX)

  DECLARE @ThisStyle varchar(MAX)

  DECLARE @ThisAttribID int
  DECLARE @LastAttribID int
  DECLARE @ThisAttribName varchar(MAX)
  DECLARE @ThisAttribValue varchar(MAX)

  DECLARE @CurParentDEID int
  DECLARE @CurParentTag varchar(MAX)

  OPEN curDOM
  FETCH curDOM INTO
    @DEID,
    @Tag,
    @ID,
    @Name,
    @Class,
    @TextData,
    @ParentDEID,
    @HUID,
    @DOMLevel,
    @HasChild

  SET @RenderedHTML = NULL
  SET @CurParentDEID = NULL
  SET @CurParentTag = NULL
  SET @DonePop = NULL

  WHILE @@FETCH_STATUS = 0 BEGIN
    --Walk through each node of the DOM to render HTML
    SET @ThisStyle = NULL
    SET @ThisAttribID = NULL
    SET @LastAttribID = NULL

    SET @EmitTag = NULL
    SET @AllowPush = NULL

    SET @StackID = NULL
    SET @StackDEID = NULL
    SET @StackTag = NULL

    IF @DonePop IS NULL BEGIN
      --first pass through
      SET @CurParentDEID = @ParentDEID
      SET @CurParentTag = ''</'' + @Tag + ''>''
      SET @DonePop = 1
    END

    IF @Debug = 1 PRINT ''Starting node @Tag = '' + ISNULL(@Tag, ''NULL'') +
      '' @DEID = '' + ISNULL(CAST(@DEID AS varchar(100)), ''NULL'') +
      '' @ParentDEID = '' + ISNULL(CAST(@ParentDEID AS varchar(100)), ''NULL'') +
      '' @CurParentDEID = '' + ISNULL(CAST(@CurParentDEID AS varchar(100)), ''NULL'')

    --#1:  See if there is anything we need to pop.  Close tags, set CurParent as needed.
    IF ISNULL(@ParentDEID, 0) <> ISNULL(@CurParentDEID, 0) --AND
   --   (@Tag IS NOT NULL) AND (@Tag NOT LIKE ''!%'')
    BEGIN

      IF @Debug = 1 IF @Debug = 1 PRINT ''TRACE: Need to pop''

      --need to pop
      SET @DonePop = 0
      WHILE @DonePop = 0 BEGIN

        SET @StackID = NULL
        SET @StackDEID = NULL
        SET @StackTag = NULL

        SELECT TOP 1
          @StackID = StackID,
          @StackDEID = DEID,
          @StackTag = CloseTag
        FROM
          @tvTagStack
        ORDER BY
          StackID DESC

        SET @DonePop = 1

        IF @Debug = 1 IF @Debug = 1 PRINT ''TRACE: Popped from @CurParentDEID = '' +
          ISNULL(CAST(@CurParentDEID AS varchar(100)), ''NULL'') + '' to '' +
          ISNULL(CAST(@StackDEID AS varchar(100)), ''NULL'')

        IF @CurParentTag IS NOT NULL BEGIN
          SET @RenderedHTML = ISNULL(@RenderedHTML + CASE WHEN @PrettyWhitespace = 1 THEN @CRLF ELSE '''' END, '''') + @CurParentTag
        END

        SET @CurParentDEID = @StackDEID
        SET @CurParentTag = @StackTag

        --Note:  CurParent is left open.  May be re-pushed

        IF @StackID IS NULL BEGIN
          SET @DonePop = 1
        END
        ELSE BEGIN
          DELETE FROM @tvTagStack WHERE StackID = @StackID

          IF ISNULL(@ParentDEID, 0) <> ISNULL(@CurParentDEID, 0) BEGIN
            SET @DonePop = 0
            --render close tag
--            SET @RenderedHTML = ISNULL(@RenderedHTML + CASE WHEN @PrettyWhitespace = 1 THEN @CRLF ELSE '''' END, '''') + @StackTag
          END

        END

      END --WHILE @DonePop = 0
    END  --IF CurParent change needed


    IF ISNULL(@ParentDEID, 0) <> ISNULL(@CurParentDEID, 0) BEGIN
      PRINT ''Error in DOM:  could not pop back to where @ParentDEID = @CurParentDEID '' +
      ''(@ParentDEID = '' + ISNULL(CAST(@ParentDEID AS varchar(100)), ''NULL'') +
      '' @CurParentDEID = '' + ISNULL(CAST(@CurParentDEID AS varchar(100)), ''NULL'') + '')''
    END


    --#2: Render tag
    IF @Tag = ''!--'' BEGIN
      --HTML Comment
      SET @RenderedHTML = ISNULL(@RenderedHTML + CASE WHEN @PrettyWhitespace = 1 THEN @CRLF ELSE '''' END, '''') + ISNULL(@TextData, '''')
      SET @AllowPush = 0
    END
    ELSE IF @Tag LIKE ''!%'' BEGIN
      --declaration
      SET @RenderedHTML = ISNULL(@RenderedHTML + CASE WHEN @PrettyWhitespace = 1 THEN @CRLF ELSE '''' END, '''') + ISNULL(''<'' + @TextData + ''>'', '''')
      SET @AllowPush = 0
    END
    ELSE IF @Tag IS NULL BEGIN
      --text node
      SET @RenderedHTML = ISNULL(@RenderedHTML + CASE WHEN @PrettyWhitespace = 1 THEN @CRLF ELSE '''' END, '''') + ISNULL(@TextData, '''')
      SET @AllowPush = 0
    END
    ELSE BEGIN
      --normal node
      SET @AllowPush = 1

      SET @EmitTag = ''<'' + @Tag +
        ISNULL('' id="'' + @ID + ''"'', '''') +
        ISNULL('' name="'' + @Name + ''"'', '''') +
        ISNULL('' class="'' + @Class + ''"'', '''')

      IF EXISTS (SELECT DOMStyleID FROM #tblDOMStyles WHERE DEID = @DEID) BEGIN
        SET @ThisAttribID = -1
        WHILE @ThisAttribID IS NOT NULL BEGIN
          SET @ThisAttribID = NULL
          SELECT TOP 1
            @ThisAttribID = da.DOMStyleID,
            @ThisAttribName = da.Name,
            @ThisAttribValue = da.Value
          FROM
            #DOMStyles da
          WHERE
            da.DEID = @DEID AND
            da.DOMStyleID > ISNULL(@LastAttribID, 0)
          ORDER BY
            da.DOMStyleID

          IF @ThisAttribID IS NOT NULL BEGIN
            SET @ThisStyle = ISNULL(@ThisStyle, '''') + ISNULL(@ThisAttribName + '': '' + @ThisAttribValue + '';'', '''')
          END

          SET @LastAttribID = @ThisAttribID
        END
      END

      --save list of styles in style attribute
      EXEC #spupdDOMAttribs @DocID = @DocID OUTPUT, @DEID = @DEID, @Name = ''style'', @Value = @ThisStyle

      IF EXISTS (SELECT DOMAttribID FROM #tblDOMAttribs WHERE DEID = @DEID) BEGIN
        SET @ThisAttribID = -1
        WHILE @ThisAttribID IS NOT NULL BEGIN
          SET @ThisAttribID = NULL
          SELECT TOP 1
            @ThisAttribID = da.DOMAttribID,
            @ThisAttribName = da.Name,
            @ThisAttribValue = da.Value
          FROM
            #tblDOMAttribs da
          WHERE
            da.DEID = @DEID AND
            da.DOMAttribID > ISNULL(@LastAttribID, 0)
          ORDER BY
            da.DOMAttribID

          IF @ThisAttribID IS NOT NULL BEGIN
            SET @EmitTag = @EmitTag + ISNULL('' '' + @ThisAttribName + ''="'' + @ThisAttribValue + ''"'', '''')
          END

          SET @LastAttribID = @ThisAttribID
        END
      END

      SET @RenderedHTML = ISNULL(@RenderedHTML + CASE WHEN @PrettyWhitespace = 1 THEN @CRLF ELSE '''' END, '''') + @EmitTag +
        CASE WHEN @HasChild = 0 THEN ''/'' ELSE '''' END + ''>''
    END


    --#3: Set CurParentDEID = new node, if applicable
    IF (@AllowPush = 1) AND (@HasChild = 1) BEGIN
      --push and move CurParent to newly-inserted node

      IF @CurParentDEID IS NOT NULL BEGIN
        INSERT INTO @tvTagStack (
          DEID,
          CloseTag
        )
        VALUES (
          @CurParentDEID,
          @CurParentTag
        )
      END

      IF @Debug = 1 IF @Debug = 1 PRINT ''TRACE: Push @CurParentDEID = '' + ISNULL(CAST(@CurParentDEID AS varchar(100)), ''NULL'') +
       '' New @CurParentDEID = '' +  ISNULL(CAST(@DEID AS varchar(100)), ''NULL'')

      SET @CurParentDEID = @DEID
      SET @CurParentTag =  ''</'' + @Tag + ''>''

    END


    FETCH curDOM INTO
      @DEID,
      @Tag,
      @ID,
      @Name,
      @Class,
      @TextData,
      @ParentDEID,
      @HUID,
      @DOMLevel,
      @HasChild
  END
  CLOSE curDOM

  IF @CurParentTag IS NOT NULL BEGIN
    SET @RenderedHTML = ISNULL(@RenderedHTML + CASE WHEN @PrettyWhitespace = 1 THEN @CRLF ELSE '''' END, '''') + @CurParentTag
  END

  WHILE EXISTS(SELECT StackID FROM @tvTagStack) BEGIN

    SELECT TOP 1
      @StackID = StackID,
      @StackDEID = DEID,
      @StackTag = CloseTag
    FROM
      @tvTagStack
    ORDER BY
      StackID DESC

    DELETE FROM @tvTagStack WHERE StackID = @StackID

    SET @RenderedHTML = ISNULL(@RenderedHTML + CASE WHEN @PrettyWhitespace = 1 THEN @CRLF ELSE '''' END, '''') + ISNULL(@StackTag, '''')
  END

  SET @HTML = @RenderedHTML

  DROP TABLE #Render

  IF @PrintHTML = 1 BEGIN
    PRINT @HTML
  END
END
')

/*
**************************************************************************************
PROCEDURE #spactDOMLoad
Procedure #spactDOMLoad parses the provided @HTML and loads into DOM.

If @ID or @DEID is specified, modifes existing DOM starting with the specified node.

If @Selector is specified, the #Load operation will be performed for each node
that matches the specified selection.

If @ReplaceOuter = 1 the specified node itself will also be replaced (i.e. OUTER HTML),
otherwise only the children of the specified node will be replaced (i.e. INNER
HTML)

If neither @ID or @DEID is specified, clears entire DOM and loads from @HTML.

@Attribs may specify a string of Attributes that will be appended to every node
affected by #spactDOMLoad.

IF @Class is specifed,
**************************************************************************************
*/
exec('
CREATE PROCEDURE #spactDOMLoad
@DocID int = NULL,
@HTML varchar(MAX),
@ID varchar(512) = NULL,
@DEID int = NULL,
@ReplaceOuter bit = 0,
@CreateNew bit = 0,

@Selector varchar(MAX) = NULL,
@IncludeAllWhitespace bit = 0,
@Tolerate bit = 0
AS
BEGIN
  EXEC #spactDOMOpen @CreateNew = @CreateNew, @DocID = @DocID OUTPUT


  --local table to hold stack of tags
  DECLARE @tvTagStack TABLE (
    TagStackID int identity PRIMARY KEY ,
    Tag varchar(512),
    DEID int,
    ParentDEID int
  );

  DECLARE @tvTargetList TABLE (
    DEID int PRIMARY KEY
  )


  DECLARE @TargetDEID int

  IF @ID IS NOT NULL BEGIN
    SELECT
      @DEID = dom.DEID
    FROM
      #tblDOM dom
    WHERE
      dom.DocID = @DocID AND
      dom.ID = @ID
  END
  ELSE IF @Selector IS NOT NULL BEGIN
    INSERT INTO @tvTargetList (DEID)
    EXEC #spgetDOM @DocID = @DocID OUTPUT, @Selector = @Selector, @ReturnDEIDsOnly = 1
    SELECT TOP 1 @DEID = DEID FROM @tvTargetList
  END


  DECLARE @i int
  DECLARE @c char

  DECLARE @IsSingleton bit
  DECLARE @InComment bit
  DECLARE @InQuote bit
  DECLARE @StartQuote char

  DECLARE @ParentDEID int
  DECLARE @LastDEID int

  DECLARE @TopStackID int
  DECLARE @StackTag varchar(8000)
  DECLARE @PopDone bit

  DECLARE @State varchar(40)
  DECLARE @OpenTagName varchar(512)
  DECLARE @CloseTagName varchar(512)

  DECLARE @Text varchar(MAX)
  DECLARE @AttribStr varchar(MAX)
  DECLARE @CommentStr varchar(MAX)

  DECLARE @TextChunk varchar(8000)
  DECLARE @AttribChunk varchar(8000)

  DECLARE @StartPos int
  DECLARE @EndPos int
  DECLARE @CommentStartPos int
  DECLARE @TextLen int
  DECLARE @TextChunkLen int

  DECLARE @DoOpenTag bit
  DECLARE @DoCloseTag bit
  DECLARE @ImmediateClose bit


  IF (@DEID IS NULL) AND (@Selector IS NULL) BEGIN
    EXEC #spactDOMClear @DocID = @DocID OUTPUT
    SET @DEID = -1
  END

  WHILE @DEID IS NOT NULL BEGIN
    SET @Text = ''''
    SET @CommentStr = ''''
    SET @LastDEID = NULL
    SET @ParentDEID = NULL
    SET @OpenTagName = NULL
    SET @CloseTagName = NULL

    SET @ImmediateClose = 0
    SET @IsSingleton = 0
    SET @InComment = 0
    SET @InQuote = 0
    SET @StartQuote = NULL

    SET @StartPos = NULL
    SET @EndPos = NULL
    SET @CommentStartPos = NULL

    SET @TextChunk = ''''
    SET @AttribChunk = ''''

    SET @Text = ''''
    SET @AttribStr = ''''
    SET @CommentStr = ''''

    SELECT
      @ParentDEID = CASE WHEN @ReplaceOuter = 1 THEN dom.ParentDEID ELSE dom.DEID END
    FROM
      #tblDOM dom
    WHERE
      dom.DocID = @DocID AND
      dom.DEID = @DEID

    --Note:  we are replacing all child nodes.  We might be replacing
    --the target node too--if @ReplaceOuter = 1

    IF @HTML IS NOT NULL BEGIN
      DELETE FROM #tblDOM
      WHERE
        (((@ReplaceOuter = 1 ) AND (DEID = @DEID)) OR
         ((ParentDEID = @DEID) AND (LEFT(@HTML, 1) = ''<'')))

      SET @i = 1

      SET @OpenTagName = ''''
      SET @CloseTagName = ''''

      SET @State = ''Text''

      WHILE @i <= LEN(@HTML) BEGIN
        SET @c = SUBSTRING(@HTML, @i, 1)

        --IF @State = ''Comment'' BEGIN
        IF @InComment = 1 BEGIN
          --special case:  locked in processing text until -->
          SET @CommentStr = @CommentStr + @c

          IF PATINDEX(''%-->%'', @CommentStr) > 0 BEGIN
            --reached the end of the comment
            EXEC #spinsDOMNode
              @DocID = @DocID OUTPUT,
              @Tag = ''!--'',
              @Text = @CommentStr,
              @OpenTagStartPos = @CommentStartPos,
              @CloseTagEndPos = @i,
              @ParentDEID = @ParentDEID

            SET @CommentStr = ''''
            SET @CommentStartPos = 0

            SET @State = ''Text''
            SET @InComment = 0
            --SET @i = @i + 1
          END
        END
        ELSE BEGIN
          IF (@i = LEN(@HTML)) AND
             ((@IncludeAllWhitespace = 1) OR
              (@C NOT IN (CHAR(9), CHAR(10), CHAR(13), '' ''))) BEGIN

            --at the last character of our @HTML
            IF @IncludeAllWhitespace = 1 BEGIN
              SET @TextLen = LEN(@Text + ''x'') - 1
              SET @TextChunkLen = LEN(@TextChunk + ''x'') - 1
            END
            ELSE BEGIN
              EXEC #spgetLenNTW @s = @Text, @Len = @TextLen OUTPUT
              EXEC #spgetLenNTW @s = @TextChunk, @Len = @TextChunkLen OUTPUT
            END

            IF (@TextLen > 0) OR (@TextChunkLen > 0) BEGIN
              --special case of text-only @HTML (no tags)
              SET @TextChunk = @TextChunk + @c
              IF @TextChunk <> '''' BEGIN
                SET @Text = @Text + @TextChunk
                SET @TextChunk = ''''
              END

              EXEC #spinsDOMNode
                @DocID = @DocID OUTPUT,
                @Tag = NULL,
                @Text = @Text,
                @ParentDEID = @ParentDEID,
                @DEID = @LastDEID OUTPUT

              SET @Text = ''''
            END
          END

          --special occurrences of / Note that these could have been coded to
          --be handled below in each respective State, but seemed more clear to
          --keep together here.
          ELSE IF (@c = ''/'') AND (@State = ''StartTag'') BEGIN
            SET @State = ''CloseTagName''
          END
          ELSE IF (@c = ''/'') AND (@State = ''OpenTagName'') BEGIN
            --Immediate close of tag.  Actual close will happen on >
            SET @ImmediateClose = 1
          END
          ELSE IF (@c = ''/'') AND (@State = ''CloseTagName'') BEGIN
            --NOOP:  we want to drop the /
            SET @c = @c
          END
          ELSE IF (@c = ''/'') AND (@State = ''Attributes'') AND (@InQuote = 0) BEGIN
            IF @Tolerate = 1 BEGIN
              IF SUBSTRING(@HTML, @i + 1, 1) <> ''>'' BEGIN
                --False alarm:  HTML is missing quotes around attribute values.
                --This is not really an indication of the end of the tag.

                SET @AttribChunk = @AttribChunk + @c
                IF LEN(@AttribChunk) = 8000 BEGIN
                  SET @AttribStr = @AttribStr + @AttribChunk
                  SET @AttribChunk = ''''
                END
              END
              ELSE BEGIN
                SET @State = ''OpenTagName''
                SET @ImmediateClose = 1
              END
            END
            ELSE BEGIN
              SET @State = ''OpenTagName''
              SET @ImmediateClose = 1
            END

          END


          ELSE IF (@c = ''<'') BEGIN
            SET @StartPos = @i

            IF @TextChunk <> '''' BEGIN
             SET @Text = @Text + @TextChunk
              SET @TextChunk = ''''
            END

            IF @Text  <> '''' BEGIN
              --reached the end of the text node
              EXEC #spgetLenNTW @s = @Text, @Len = @TextLen OUTPUT

              IF ((@IncludeAllWhitespace = 1) OR (@TextLen > 0)) BEGIN
                EXEC #spinsDOMNode
                  @DocID = @DocID OUTPUT,
                  @Tag = NULL,
                  @Text = @Text,
                  @ParentDEID = @ParentDEID,
                  @DEID = @LastDEID OUTPUT

                SET @Text = ''''
              END
            END

            --See if we are starting a comment
            IF SUBSTRING(@HTML, @i, LEN(''<!--'')) = ''<!--'' BEGIN
              --SET @State = ''Comment''
              SET @InComment = 1
              SET @CommentStr = @c
              SET @CommentStartPos = @i
            END
            ELSE BEGIN
              --otherwise we are just starting a new tag
              SET @State = ''StartTag''
            END
          END

          ELSE IF (@c = ''>'') BEGIN
            IF @State = ''CloseTagName'' BEGIN
              SET @EndPos = @i
              SET @IsSingleton = CASE WHEN
                (@CloseTagName IN (''area'', ''br'', ''col'', ''command'', ''embed'', ''hr'', ''img'', ''input'', ''link'', ''meta'', ''param'', ''source'')) OR
                (@CloseTagName LIKE ''!%'') THEN 1 ELSE 0 END

              IF @IsSingleton = 0 BEGIN
                --Not a singleton HTML tag for which we ignore the close tag if present
                SET @DoCloseTag = 1
              END
            END
            ELSE IF @State IN (''OpenTagName'', ''Attributes'') BEGIN
              SET @IsSingleton = CASE WHEN
               (@OpenTagName IN (''area'', ''br'', ''col'', ''command'', ''embed'', ''hr'', ''img'', ''input'', ''link'', ''meta'', ''param'', ''source'')) OR
               (@OpenTagName LIKE ''!%'') THEN 1 ELSE 0 END

              IF @IsSingleton = 1 BEGIN
                --Singleton HTML tag that does not need to be closed
                SET @ImmediateClose = 1
              END
              SET @DoOpenTag = 1
            END
          END

          ELSE IF @State = ''StartTag'' BEGIN
            --not a / because that case was handled above
            SET @State = ''OpenTagName''
            SET @OpenTagName = @c
          END
          ELSE IF @State = ''OpenTagName'' BEGIN
            IF @c = '' '' BEGIN
              SET @State = ''Attributes''
            END
            ELSE BEGIN
              --Not a / because that case was handled above
              SET @OpenTagName = @OpenTagName + @c
            END
          END
          ELSE IF @State = ''CloseTagName'' BEGIN
            SET @CloseTagName = @CloseTagName + @c
          END
          ELSE IF @State = ''Attributes'' BEGIN
            --not a / because that case was handled above
            IF (@c IN (''"'', '''''''')) BEGIN
              IF (@InQuote = 0) AND ((@StartQuote IS NULL) OR (@c = @StartQuote)) BEGIN
                SET @InQuote = 1
                IF @StartQuote IS NULL BEGIN
                  SET @StartQuote = @c
                END
              END
              ELSE IF (@InQuote = 1) AND (@c = @StartQuote) BEGIN
                SET @InQuote = 0
              END
            END

            SET @AttribChunk = @AttribChunk + @c
            IF LEN(@AttribChunk) = 8000 BEGIN
              SET @AttribStr = @AttribStr + @AttribChunk
              SET @AttribChunk = ''''
            END

          END

          ELSE IF @State IN (''Text'') BEGIN


            SET @TextChunk = @TextChunk + @c



            IF LEN(@TextChunk) = 8000 BEGIN
             SET @Text = @Text + @TextChunk
              SET @TextChunk = ''''
            END

          END
          ELSE BEGIN
            RAISERROR(''Error in #Load:  Unexpected state parsing HTML'', 16, 1)
          END

          --Processing for completed OpenTag
          IF @DoOpenTag = 1 BEGIN

            SET @DoOpenTag = 0

            IF @AttribChunk <> '''' BEGIN
              SET @AttribStr = @AttribStr + @AttribChunk
              SET @AttribChunk = ''''
            END

            IF @ImmediateClose = 1 BEGIN
              SET @EndPos = @i --should be called on the >
            END

            IF @OpenTagName = ''script'' BEGIN
              --A special case:  we know that there must be an end tag for the script
              --(required in all cases), and we know we don''t want to inspect the contents
              --of the script block.  So we can copy the whole block at once here and
              --save some looping and concatenating.

              --SET @Text = RIGHT(@HTML, LEN(@HTML) - @i)
              --SET @Text = SUBSTRING(@Text, 1, PATINDEX(''%</script>%'', @Text) - 1)
              --SET @Text = SUBSTRING(RIGHT(@HTML, LEN(@HTML) - @i), 1, PATINDEX(''%</script>%'', RIGHT(@HTML, LEN(@HTML) - @i)) - 1)
              SET @EndPos = PATINDEX(''%</script>%'', RIGHT(@HTML, LEN(@HTML) - @i)) - 1
              SET @Text = SUBSTRING(RIGHT(@HTML, LEN(@HTML) - @i), 1, @EndPos)

              SET @i = @i + LEN(@Text) + LEN(''</script>'')
              SET @EndPos = @i

              EXEC #spinsDOMNode
                @DocID = @DocID OUTPUT,
                @Tag = @OpenTagName,
                @Attribs = @AttribStr,
                @Text = @Text,
                @OpenTagStartPos = @StartPos,
                @CloseTagEndPos = @EndPos,
                @ParentDEID = @ParentDEID,
                @DEID = @LastDEID OUTPUT

                SET @Text = ''''
            END
            ELSE BEGIN
              EXEC #spinsDOMNode
                @DocID = @DocID OUTPUT,
                @Tag = @OpenTagName,
                @Attribs = @AttribStr,
                @Text = NULL, --@Text,
                @OpenTagStartPos = @StartPos,
                @CloseTagEndPos = @EndPos,
                @ParentDEID = @ParentDEID,
                @DEID = @LastDEID OUTPUT
              END

            IF @ImmediateClose = 1 BEGIN
              SET @ImmediateClose = 0
              --Note:  do not change @ParentDEID
            END
            ELSE BEGIN
              IF @IsSingleton = 0 BEGIN
                --Note:  Comments, declarations and singleton tags should never be a parent,
                --and so they don''t get pushed onto the stack.

                --Push tag
                INSERT INTO @tvTagStack (Tag, DEID, ParentDEID)
                VALUES (@OpenTagName, @LastDEID, @ParentDEID)

                SET @ParentDEID = @LastDEID
              END
            END


            SET @State = ''Text''

            SET @OpenTagName = ''''
            SET @AttribStr = ''''
            SET @AttribChunk = ''''
            SET @Text = ''''
            SET @TextChunk = ''''

          END


          --Processing for completed CloseTag
          IF @DoCloseTag = 1 BEGIN
            SET @DoCloseTag = 0

            --Pop tag
            IF @IsSingleton = 0 BEGIN
              --not a singleton tag

              SET @StackTag = ''''
              SET @PopDone = 0

              SELECT TOP 1 @TopStackID = TagStackID FROM @tvTagStack ORDER BY TagStackID DESC

              WHILE (@TopStackID IS NOT NULL) AND
                    (@StackTag <> @CloseTagName) AND
                    (@PopDone = 0) BEGIN

                /*
                Note:  The idea is that we pushed nodes onto a stack.  We have reached the closing tag for a
                node, and so now we want to pop off all nodes that were pushed until we pop off the corresponding
                opening tag.

                There could be a problem is with non-XHTML:  In XMHTML, tags such as <td> and <li> must be
                closed--as they should be--because they can contain child text nodes.  However, the HTML spec
                allows for <td> and <li> to be pseudo-singletons...meaning that they may not have a closing tag.

                Consequently, the current behavior is that since there is no closing tag (i.e. </td>) on the stack,
                we will keep poping until we come to the top of the stack.  Thus the next tag after the </td>--which
                will likely be a <td> in this case--will be inserted as a root-level node with no parent.

                This behavior is not bad:  it is fairly fault-tollerant.  The nodes will still be processed, and the
                sequence of the nodes will still be presevered.

                Nonetheless, a future enhancement might be to somehow limit the popping to stop at the "inferred"
                parent.  For example, we know that the parent of a <td> should be a <tr>.  So perhaps stopping popping
                when we reach the <tr> is possible through some yet-to-be-defined means.
                */

                SET @TopStackID = NULL
                SET @StackTag = NULL

                SELECT TOP 1
                  @TopStackID = ts.TagStackID,
                  @StackTag = ts.Tag,
                  @LastDEID = ts.DEID,
                  @ParentDEID = ts.ParentDEID
                FROM
                  @tvTagStack ts
                ORDER BY
                  ts.TagStackID DESC

                DELETE FROM @tvTagStack WHERE TagStackID = @TopStackID

              END
            END

            UPDATE #tblDOM
            SET CloseTagEndPos = @EndPos
            WHERE
              DEID = @LastDEID

            SET @CloseTagName = ''''

            SET @State = ''Text''
            SET @Text = ''''

          END

        END

        SET @i = @i + 1
      END
    END

    DELETE FROM @tvTargetList WHERE DEID = @DEID

    SET @DEID = NULL

    IF EXISTS(SELECT DEID FROM @tvTargetList) BEGIN
      SELECT TOP 1 @DEID = DEID FROM @tvTargetList
    END
  END

END
')

exec('
CREATE PROCEDURE #sputilGetHTTP
@URL varchar(MAX),
  --URL to retrieve data from
@HTTPMethod varchar(40) = ''GET'',
  --can be either GET or POST
@ContentType varchar(80)= ''text/http'',
@DataToSend nvarchar(4000) = NULL,

@HTTPStatus int = NULL OUTPUT,
  --HTTP Status Code (200=OK, 404=Not Found, etc.)
@ResponseText nvarchar(MAX) = NULL OUTPUT,
  --Full text returned by remote HTTP server (if @SuppressResponseText = 0)

@StartTag varchar(100) = NULL, --''<div class="entry-content">'',
  --Token to mark start of block to return in @ParsedText.  NULL means return nothing.
@EndTag varchar(100) =  NULL, --''</div><!-- .entry-content -->'',
@IncludeStartTag bit = 1,
@IncludeEndTag bit = 1,

  --Token to mark end of block to return in @ParsedText.  NULL means return to end.
@ParsedText nvarchar(MAX) = NULL OUTPUT,
  --Substring of @ResponseText delimeted by @StartTag and @EndTag

@ErrorMsg varchar(MAX) = NULL OUTPUT,
  --NULL unless an error message was encountered
@LastResultCode int = NULL OUTPUT,
  --0 unless an error code was returned by MSXML2.ServerXMLHttp

@SuppressResponseText bit = 0,
  --If 0, actual content is not returned from remote server (just status code)
@SuppressResultset bit = 1
  --If 0, result set is is not returned (just parameters)
AS
BEGIN
  --Retrieves data via HTTP

  --http://msdn.microsoft.com/en-us/library/aa238861(v=sql.80).aspx

  SET NOCOUNT ON

  DECLARE @Debug bit
  SET @Debug = 0

  DECLARE @CRLF char(5)
  SET @CRLF = CHAR(13) + CHAR(10)

  DECLARE @XML xml
  DECLARE @Obj int

  DECLARE @PerformedInit bit
  SET @PerformedInit = 0

  DECLARE @ErrSource varchar(512)
  DECLARE @ErrMsg varchar(512)

  DECLARE @tvResponse TABLE (Response nvarchar(MAX))

  BEGIN TRY
    IF @Debug = 1 PRINT ''About to call sp_OACreate for MSXML2.ServerXMLHttp''

    EXEC @LastResultCode = sp_OACreate ''MSXML2.ServerXMLHttp'', @Obj OUT
    IF @LastResultCode <> 0 BEGIN
      EXEC sp_OAGetErrorInfo @obj, @ErrSource OUTPUT, @ErrMsg OUTPUT
      PRINT @ErrSource
      PRINT @ErrMsg
    END
    ELSE BEGIN
      SET @PerformedInit = 1
    END

    IF @LastResultCode = 0 BEGIN
      IF @HTTPMethod = ''GET'' BEGIN

       IF @Debug = 1 PRINT ''About to call sp_OAMethod for open (GET)''
        EXEC @LastResultCode = sp_OAMethod @Obj, ''open'', NULL, ''GET'', @URL, false
        IF @LastResultCode <> 0 BEGIN
          EXEC sp_OAGetErrorInfo @obj, @ErrSource OUTPUT, @ErrMsg OUTPUT
          PRINT @ErrSource
          PRINT @ErrMsg
        END

      END
      ELSE BEGIN
       IF @Debug = 1 PRINT ''About to call sp_OAMethod for open (POST)''
        EXEC @LastResultCode = sp_OAMethod @Obj, ''open'', NULL, ''POST'', @URL, false
        IF @LastResultCode <> 0 BEGIN
          EXEC sp_OAGetErrorInfo @obj, @ErrSource OUTPUT, @ErrMsg OUTPUT
          PRINT @ErrSource
          PRINT @ErrMsg
        END

        IF @Debug = 1 PRINT ''About to call sp_OAMethod for setRequestHeader''
        IF @LastResultCode = 0 EXEC @LastResultCode = sp_OAMethod @Obj, ''setRequestHeader'', NULL, ''Content-Type'', @ContentType
        IF @LastResultCode <> 0 BEGIN
          EXEC sp_OAGetErrorInfo @obj, @ErrSource OUTPUT, @ErrMsg OUTPUT
          PRINT @ErrSource
          PRINT @ErrMsg
        END

      END
    END

    IF @Debug = 1 PRINT ''About to call sp_OAMethod for send''
    IF @LastResultCode = 0 EXEC @LastResultCode = sp_OAMethod @Obj, ''send'', NULL, @DataToSend
    IF @LastResultCode <> 0 BEGIN
      EXEC sp_OAGetErrorInfo @obj, @ErrSource OUTPUT, @ErrMsg OUTPUT
      PRINT @ErrSource
      PRINT @ErrMsg
    END

    IF @LastResultCode = 0 EXEC @LastResultCode = sp_OAGetProperty @Obj, ''status'', @HTTPStatus OUT
    IF @LastResultCode <> 0 BEGIN
      EXEC sp_OAGetErrorInfo @obj, @ErrSource OUTPUT, @ErrMsg OUTPUT
      PRINT @ErrSource
      PRINT @ErrMsg
    END

    IF (@LastResultCode = 0) AND (ISNULL(@SuppressResponseText, 0) = 0) BEGIN
      INSERT INTO @tvResponse (Response)
      EXEC @LastResultCode = sp_OAGetProperty @Obj, ''responseText'' --, @Response OUT
        --Note:  sp_OAGetProperty (or any extended stored procedure parameter) does not support
        --varchar(MAX), however returning as a resultset will return long results.
    END
  END TRY
  BEGIN CATCH
   SET @ErrorMsg = ERROR_MESSAGE() +
     ISNULL(@CRLF + @ErrMsg, '''')
  END CATCH

  BEGIN TRY
    DECLARE @DestroyResultCode int
    EXEC @DestroyResultCode = sp_OADestroy @Obj
  END TRY
  BEGIN CATCH
    SET @ErrorMsg = ISNULL(@ErrorMsg + @CRLF, '''') + ERROR_MESSAGE() +
     ''on call to sp_OADestroy.''
  END CATCH

  SELECT @ResponseText = Response FROM @tvResponse

  IF (@LastResultCode = 0) AND (@StartTag IS NOT NULL) BEGIN
    DECLARE @P1 int
    DECLARE @P2 int

    SET @P1 = PATINDEX(''%'' + @StartTag +''%'', @ResponseText)
    IF @IncludeEndTag = 0 SET @P1 = @P1 + LEN(@EndTag + ''x'') - 1

    IF @EndTag IS NULL BEGIN
      SET @P2 = LEN(@ResponseText + ''x'') - 1
    END
    ELSE BEGIN
      SET @P2 = PATINDEX(''%'' + @EndTag + ''%'', @ResponseText) - 1
      IF @IncludeEndTag = 1 SET @P2 = @P2 + LEN(@EndTag + ''x'') - 1
    END

    --SET @ParsedText = REPLACE(tempdb.dbo.RTRIMWhitespace(tempdb.dbo.LTRIMWhitespace(SUBSTRING(@ResponseText, @P1, @P2 - @P1 + 1))), CHAR(9), '''')

    SET @ParsedText = SUBSTRING(@ResponseText, @P1, @P2 - @P1 + 1)
    EXEC #spactTrimWhitespace @S = @ParsedText OUTPUT, @DoLeft = 1, @DoRight = 1, @TrimTabs = 1
  END


  IF ISNULL(@SuppressResultset, 0) = 0 BEGIN
    SELECT
      @URL AS URL,
      @ResponseText AS ResponseText,
      @ParsedText AS ParsedText,
      @HTTPStatus AS HTTPStatus,
      @LastResultCode AS LastResultCode,
      @ErrorMsg AS ErrorMsg
  END

  IF ((ISNULL(@LastResultCode, -1) <> 0) OR
      (ISNULL(@DestroyResultCode, -1) <> 0) OR
      (@ErrorMsg IS NOT NULL)) BEGIN
    SET @ErrorMsg = ''Error in #sputlGetHTTP: '' + @CRLF +
      ISNULL(NULLIF(RTRIM(@ErrMsg), '''') + @CRLF, '''') +
--      ISNULL(NULLIF(RTRIM(@ErrSource), '''') + @CRLF, '''') +
      ISNULL(NULLIF(RTRIM(@ErrorMsg), '''') + @CRLF, '''') +
      CASE WHEN @PerformedInit = 0 THEN
      @CRLF +
      ''Remember that this stored procedure uses OLE.  To work properly you may need to configure '' +
      ''your database to allow OLE, as follows: '' + @CRLF +
      ''  EXEC sp_configure ''''show advanced options'''', 1;'' + @CRLF +
      ''  RECONFIGURE;'' + @CRLF +
      ''  EXEC sp_configure ''''Ole Automation Procedures'''', 1;'' + @CRLF +
      ''  RECONFIGURE;'' + @CRLF +
      ''Also, your SQL user must have execute rights to the following stored procedures in master:'' + @CRLF +
      ''  sp_OACreate'' + @CRLF +
      ''  sp_OAGetProperty'' + @CRLF +
      ''  sp_OASetProperty'' + @CRLF +
      ''  sp_OAMethod'' + @CRLF +
      ''  sp_OAGetErrorInfo'' + @CRLF +
      ''  sp_OADestroy'' + @CRLF +
      ''You can grant rights for each of these as follows:'' + @CRLF +
      ''  USE master'' + @CRLF +
      ''  GRANT EXEC ON sp_OACreate TO myuser'' + @CRLF +
      ''  GRANT EXEC etc. ...''
      ELSE '''' END

      RAISERROR(@ErrorMsg, 16, 1)
  END

END
')
--------------------
exec('
CREATE PROCEDURE #sputilConvertJSONToXML
@JSON nvarchar(MAX),
@XML xml OUTPUT
AS
BEGIN
  DECLARE @tvStack TABLE (
    StackID int IDENTITY PRIMARY KEY,
    Tag varchar(8000),
    IsArrayElem bit
  )

  DECLARE @I int
  DECLARE @C char
  DECLARE @LastChar char

  DECLARE @Buf varchar(8000)
  DECLARE @XMLStr varchar(MAX)
  DECLARE @Tag varchar(8000)

  DECLARE @StackID int

  DECLARE @InQuote bit
  DECLARE @EndedQuote bit
  DECLARE @IsArrayElem bit

  SET @I = 1
  SET @InQuote = 0

  SET @XMLStr = ''''
  SET @Buf = ''''

  WHILE @I < LEN(@JSON + ''x'') - 1 BEGIN
    IF @C NOT IN (CHAR(9), CHAR(10), CHAR(13), '' '') SET @LastChar = @C

    SET @C = SUBSTRING(@JSON, @I, 1)

    IF @C = ''"'' BEGIN
      --Found Quote
      IF @EndedQuote = 1 BEGIN
        --Just exited a quote:  special case for embedded ""
        SET @Buf = @Buf + @C
        SET @InQuote = 1
        SET @EndedQuote = 0
      END
      ELSE IF @InQuote = 1 BEGIN
        --We were already in a quote, so we must be exiting
        SET @InQuote = 0
        SET @EndedQuote = 1
      END
      ELSE BEGIN
        SET @InQuote = 1
      END
    END
    ELSE BEGIN
      --not a quote character

      SET @EndedQuote = 0
      IF (@InQuote = 1) BEGIN
        --just append character
        IF @C NOT IN (CHAR(9), CHAR(10), CHAR(13)) BEGIN
          SET @Buf = @Buf +
            CASE @C
              WHEN ''<'' THEN ''&lt;''
              WHEN ''>'' THEN ''&gt;''
              WHEN ''&'' THEN ''&amp;''
              ELSE @C
            END
        END
      END
      ELSE BEGIN
        --inspect character to determine state

        IF @C = '':'' BEGIN
          --@Buf contains VarName
          SET @XMLStr = @XMLStr + ''<'' + @Buf + ''>''

          INSERT INTO @tvStack (Tag) VALUES (@Buf)

          SET @Buf = ''''
        END
        ELSE IF @C = '','' BEGIN
          --@Buf contains VarValue
          IF @Buf <> '''' BEGIN
            SET @XMLStr = @XMLStr + @Buf
            SET @Buf = ''''

            --pop tag from stack and write closing tag to XML
            SET @Tag = ''''
            SELECT TOP 1 @Tag = Tag, @StackID = StackID FROM @tvStack ORDER BY StackID DESC
            DELETE FROM @tvStack WHERE StackID = @StackID

            IF @Tag <> '''' BEGIN
              SET @XMLStr = @XMLStr + ''</'' + @Tag + ''>''
            END
          END

          --We are on a comma.  If the top element is an array element, peek and write
          --a close tag and a re-open tag to XML
          SET @IsArrayElem = 0
          SELECT TOP 1 @IsArrayElem = IsArrayElem, @Tag = Tag FROM @tvStack ORDER BY StackID DESC
          IF @LastChar = ''}'' AND @IsArrayElem = 1 BEGIN
            SET @XMLStr = @XMLStr + ''</'' + @Tag +''>'' + ''<'' + @Tag + ''>''
          END

        END
        ELSE IF @C = ''['' BEGIN
          --Start of array.

          --peek at stack and add first array element tag
          SET @Tag = ''''
          SELECT TOP 1 @Tag = Tag, @StackID = StackID FROM @tvStack ORDER BY StackID DESC

          IF @Tag <> '''' BEGIN
            SET @Tag = @Tag + ''_''

            --push array element tag to stack and write closing tag to XML
            INSERT INTO @tvStack (Tag, IsArrayElem) VALUES (@Tag, 1)
            SET @XMLStr = @XMLStr + ''<'' + @Tag + ''>''
          END
        END
        ELSE IF @C = ''}'' BEGIN
          --at end of object

          --pop tag from stack and write closing tag to XML
          SELECT TOP 1 @Tag = Tag, @StackID = StackID FROM @tvStack ORDER BY StackID DESC
          DELETE FROM @tvStack WHERE StackID = @StackID

          IF @Tag <> '''' BEGIN
            SET @XMLStr = @XMLStr + @Buf + ''</'' + @Tag + ''>''
          END
          SET @Buf = ''''
        END
        ELSE IF @C = '']'' BEGIN
          SELECT TOP 1 @Tag = Tag, @StackID = StackID FROM @tvStack ORDER BY StackID DESC
          DELETE FROM @tvStack WHERE StackID = @StackID

          IF @Tag <> '''' BEGIN
            SET @XMLStr = @XMLStr + @Buf + ''</'' + @Tag + ''>''
          END
          SET @Buf = ''''
        END
        ELSE BEGIN
          IF @C NOT IN (CHAR(9), CHAR(10), CHAR(13), ''{'') BEGIN
            SET @Buf = @Buf +
              CASE @C
                WHEN ''<'' THEN ''&lt;''
                WHEN ''>'' THEN ''&gt;''
                WHEN ''&'' THEN ''&amp;''
                WHEN '' '' THEN ''''
                ELSE @C
              END
          END
        END

      END
    END

    SET @I = @I + 1
  END

  --pop any remaining tags from stack
  WHILE EXISTS(SELECT StackID FROM @tvStack) BEGIN
    SET @Tag = ''''
    SELECT TOP 1 @Tag = Tag, @StackID = StackID FROM @tvStack ORDER BY StackID DESC
    DELETE FROM @tvStack WHERE StackID = @StackID
    IF @Tag <> '''' BEGIN
      SET @XMLStr = @XMLStr + ''</'' + @Tag + ''>''
    END
  END

  SET @XML = NULLIF(RTRIM(@XMLStr), '''')
END
')

-- ##########################
-- ##
-- ## END OF RUETER'S CODE
-- ##
-- ########################################################

-- ##########################
-- ##
-- ## BEGIN OF NEW UTILS
-- ##
-- ########################################################

if not object_id('tempdb..#sputilGetTable ') is null
    drop proc #sputilGetTable

exec('
CREATE PROCEDURE #sputilGetTable
    @name sysname = null,
    @DocID int = null,
    @opt sysname = null,
    @dbg int = null
as
begin
set nocount on
declare @proc sysname,@ret int

select
    @proc=''#sputilGetTable'',
    @dbg=isnull(@dbg,0),@docid=isnull(@docid,1)

if @name is null goto help

;WITH DOMTree (
  DEID,
  DocID,
  Tag,
  ID,
  Name,
  Class,
  TextData,
  OpenTagStartPos,
  CloseTagEndPos,
  ParentDEID,
  HUID,
  SortHUID,
  DOMLevel
)
AS
(
SELECT
  dom.DEID,
  dom.DocID,
  dom.Tag,
  dom.ID,
  dom.Name,
  dom.Class,
  dom.TextData,
  dom.OpenTagStartPos,
  dom.CloseTagEndPos,
  dom.ParentDEID,
  CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)) AS HUID,
  CAST(RIGHT(''000000'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)), 6) AS varchar(900)) AS SortHUID,
  1 AS DOMLevel
FROM
  #tblDOM dom
WHERE
  -- dom.ParentDEID IS NULL
  dom.DEID=(select DEID from  #tblDOM where tag=''table'' and isnull(id,'''')=@name)

UNION ALL

SELECT
  dom.DEID,
  dom.DocID,
  dom.Tag,
  dom.ID,
  dom.Name,
  dom.Class,
  dom.TextData,
  dom.OpenTagStartPos,
  dom.CloseTagEndPos,
  dom.ParentDEID,
  CAST(domch.HUID + ''.'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)) AS varchar(900)) AS HUID,
  CAST(domch.SortHUID + ''.'' + RIGHT(''000000'' + CAST(ROW_NUMBER() OVER (ORDER BY dom.DEID) AS varchar(900)), 6) AS varchar(900)) AS SortHUID,
  domch.DOMLevel + 1
FROM
  DOMTree domch
  JOIN #tblDOM dom ON
    domch.DEID = dom.ParentDEID
)
--CTE End -----------------------

SELECT *
INTO #xtable
FROM
  DOMTree dom
WHERE
  dom.DocID = @DocID
ORDER BY
  dom.SortHUID

if @dbg=2 select * from #xtable

-- extract table
declare @sql nvarchar(max),@crlf varchar(2)
select @crlf=crlf from fn__sym()

select top 100
    @sql=isnull(@sql+'','','''')+ -- ''[''+textdata+''] nvarchar(4000)''+@crlf
    ''(select top 1 TextData from #xtable ''+
    '' where huid like t.huid+''''.''+
    cast((row_number() over (order by huid)) as varchar(5))+
    ''.%'''' and tag is null''+
    '') [''+TextData+'']''+@crlf
-- select huid,textdata
from #xtable
where huid like (
    select top 1 huid
    from #xtable
    where tag in(''tr'')
    order by sorthuid
    )+''.%''
and tag is null
order by sorthuid

-- select @sql=''create table [''+@name+''](''+@crlf+@sql+'')''+@crlf
select @sql=''select''+@crlf+@sql +''from (
    select huid
    from #xtable t
    where t.tag=''''tr'''' and huid!=''''1.1.1''''
    ) t
''

if @dbg=1 exec sp__printsql @sql
exec(@sql)


goto ret

help:
exec sp__usage @proc,''
Scope
    return content table of html table @name

Notes
    Use #spgetDOM @selector="table" to list tables

Parameters
    @name   name of table
    @DocID  default 1
''
ret:
return 0
end
')

if @err!=0 or @dbg>0
    begin
    exec sp__printf '-- web tools installed'
    exec sp__select_astext '
    select left(name,charindex(''_'',name)-1) web_proc
    from tempdb..sysobjects where name like ''#sp%''
    ',@header=1
    end

end -- install option

goto ret

-- =================================================================== errors ==
/*
err_sample1:
exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param
goto ret
*/
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    enable a set of #sp to download data from web and explore DOM.

Notes
    this SP encapsulate code of David Rueter, taken from
        http://sourceforge.net/projects/sqldom/files/
    Follow this steps
    1.  open SQLDOM_core_XXX.sql
    2.  replace all single quote with two single quotes
    3.  move examples after last GO below
    4.  put CREATE of #DOM tables into IF not OBJECT_ID(''...
        and copy tables definitions here
    6.  replaces GO with EXEC(...)
    7.  done

    Tables

        CREATE TABLE #tblDOMDocs(
        DocID int identity PRIMARY KEY,
        DateCreated datetime,
        DocName varchar(128)
        )

        /*
        **************************************************************************************
        TABLE  #tblDOM
        Table #tblDOM  is for internal representation of the DOM data
        **************************************************************************************
        */
        CREATE TABLE #tblDOM (
          DEID int identity PRIMARY KEY,
          DocID int,
          Tag varchar(MAX),
          ID varchar(512),
          Name varchar(512),
          Class varchar(512),
          TextData varchar(MAX),
          OpenTagStartPos int,
          CloseTagEndPos int,
          ParentDEID int
        )

        CREATE INDEX ixDOMTable_ParentDEID ON #tblDOM (ParentDEID) INCLUDE (DEID, DocID)
        CREATE INDEX ixDOMTable_DEID ON #tblDOM (DEID, DocID)

        --NOTE: SQL 2008 introduced filtered indexes, which makes it easy to enforce
        --unqique-but-nullable. If on SQL 2008 or greater AND you wish to enforce uniqueness
        --of ID and Name attributes, uncomment the following two lines
        --  CREATE UNIQUE INDEX tmpixDOMTable_ID ON #tblDOM (ID) INCLUDE (DEID) WHERE ID IS NOT NULL
        --  CREATE UNIQUE INDEX tmpixDOMTable_Name ON #tblDOM (Name) INCLUDE (DEID) WHERE Name IS NOT NULL

        /*
        Note:
        TextData will contain the data for the first text node (if any) under the tag.
        Subsequent text nodes (if any) will be in their own #tblDOM row, with a null TAG
        and referencing the original DEID in the ParentDEID column.
        */


        /*
        **************************************************************************************
        TABLE #DOMAttribs
        Table #tblDOMAttribs is for internal representation of the DOM data--specifically,
        for attributes of DOM elements
        **************************************************************************************
        */
        CREATE TABLE #tblDOMAttribs(
        DOMAttribID int identity PRIMARY KEY,
        DEID int,
        Name varchar(512),
        Value varchar(MAX)
        )

        CREATE UNIQUE INDEX uqDOMAttribs_DEID ON #tblDOMAttribs (DEID, Name)
        CREATE INDEX ixDOMAttribs_DEID ON #tblDOMAttribs (DEID) INCLUDE (Name, Value)

        /*
        **************************************************************************************
        TABLE #tblDOMStyles
        Table #tblDOMAttribs is for internal representation of the DOM data--specifically,
        for attributes of DOM elements
        **************************************************************************************
        */
        CREATE TABLE #tblDOMStyles(
        DOMStyleID int identity PRIMARY KEY,
        DEID int,
        Name varchar(512),
        Value varchar(MAX)
        )

        CREATE UNIQUE INDEX ixDOMStyles_ID ON #tblDOMStyles (DEID, Name)
        CREATE INDEX ixDOMStyles_DEID ON #tblDOMStyles (DEID) INCLUDE (Name, Value)

Parameters
    @opt    options
            install     add web procedures
            uninstall   drop web procedures
            keep        preserve tables otherwise install will drop #dom...
    @dbg    1 show installed #sp

See
    sp__html_table

Examples
    Things to try:

    --Example 1:  Simple parse of string
    EXEC #spactDOMLoad @HTML = ''<html><body>Hello World.<br /><div><p>SQLDOM <b>ROCKS!</b></p></div></body></html>''
    EXEC #spgetDOM

    --Example 2:  Render HTML from DOM (that we parsed in Example 1 above)
    EXEC #spgetDOMHTML @PrettyWhitespace=1, @PrintHTML = 1

    --Example 3:  Parse and re-render from a URL
    DECLARE @HTML varchar(MAX)

    EXEC #sputilGetHTTP
      @URL = ''http://www.google.com'',
      @ResponseText = @HTML OUTPUT,
      @SuppressResultset = 1

    EXEC #spactDOMLoad @HTML=@HTML
    EXEC #spgetDOM
    EXEC #spgetDOMHTML @PrettyWhitespace=1, @PrintHTML = 1

    --Example 4:  Parse from a string, modify the DOM, render resulting HTML

    EXEC #spactDOMLoad @HTML = ''<html><body>Hello World.<br /><div id="myContent">Future content goes here</div></body></html>''

    EXEC #spactDOMLoad @HTML = ''<div>Here is some neat stuff about <b>SQLDOM</b></div>'', @Selector = ''.myContent''

    EXEC #spgetDOM
    EXEC #spgetDOMHTML @PrettyWhitespace=1, @PrintHTML = 1
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__web_tool