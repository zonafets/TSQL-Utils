/*  leave this
    l:see LICENSE file
    g:utility
    k:web
    v:120823.1000\s.zaglio: short comment
    c:from http://www.simple-talk.com
    c:/sql/t-sql-programming/getting-html-data-workbench/
    t:select * from fn__html_tag()
*/
CREATE function fn__html_tag()
returns table
as
return
SELECT [tag]='!DOCTYPE', [meaning]='Defines the document type',
     [type]='Basic Tag',[HasclosingTag]=0
UNION SELECT '!|[CDATA|[', 'delimits a javascript area in XHTML','Basic Tag',0
--note we have used the ESCAPE char | before the '[' character
--as otherwise it would foul up the LIKE comparison
UNION SELECT '?xml', 'flags an XML document','Basic Tag',0
UNION SELECT 'html', 'Defines a html document','Basic Tag',1
UNION SELECT 'body', 'Defines the body element','Basic Tag',1
UNION SELECT 'h1', 'Defines header 1 ','Basic Tag',1
UNION SELECT 'h2', 'Defines header 2 ','Basic Tag',1
UNION SELECT 'h3', 'Defines header 3 ','Basic Tag',1
UNION SELECT 'h4', 'Defines header 4 ','Basic Tag',1
UNION SELECT 'h5', 'Definess header 5 ','Basic Tag',1
UNION SELECT 'h6', 'Defines header 6 ','Basic Tag',1
UNION SELECT 'p', 'Defines a paragraph','Basic Tag',1
UNION SELECT 'br', 'Inserts a single line break','Basic Tag',0
UNION SELECT 'hr', 'Defines a horizontal rule','Basic Tag',0
UNION SELECT '!--', 'Defines a comment','Basic Tag',0
UNION SELECT 'b', 'Defines bold text','Char Format',1
UNION SELECT 'font', 'Defines the font face, size, and color of text',
                                                   'Char Format',1
UNION SELECT 'i', 'Defines italic text','Char Format',1
UNION SELECT 'em', 'Defines emphasized text ','Char Format',1
UNION SELECT 'big', 'Defines big text','Char Format',1
UNION SELECT 'strong', 'Defines strong text','Char Format',1
UNION SELECT 'small', 'Defines small text','Char Format',1
UNION SELECT 'sup', 'Defines superscripted text','Char Format',1
UNION SELECT 'sub', 'Defines subscripted text','Char Format',1
UNION SELECT 'bdo', 'Defines the direction of text display',
                                                   'Char Format',1
UNION SELECT 'u', 'Defines underlined text','Char Format',1
UNION SELECT 'pre', 'Defines preformatted text','Output',1
UNION SELECT 'code', 'Defines computer code text','Output',1
UNION SELECT 'tt', 'Defines teletype text','Output',1
UNION SELECT 'kbd', 'Defines keyboard text','Output',1
UNION SELECT 'dfn', 'Defines a definition term','Output',1
UNION SELECT 'var', 'Defines a variable','Output',1
UNION SELECT 'samp', 'Defines sample computer code','Output',1
UNION SELECT 'xmp', 'Deprecated. Use <pre> instead','Output',1
UNION SELECT 'acronym', 'Defines an acronym','Blocks',1
UNION SELECT 'abbr', 'Defines an abbreviation','Blocks',1
UNION SELECT 'address', 'Defines an address element','Blocks',1
UNION SELECT 'blockquote', 'Defines an long quotation','Blocks',1
UNION SELECT 'center', 'Defines centered text','Blocks',1
UNION SELECT 'q', 'Defines a short quotation','Blocks',1
UNION SELECT 'cite', 'Defines a citation','Blocks',1
UNION SELECT 'ins', 'Defines inserted text','Blocks',1
UNION SELECT 'del', 'Defines deleted text','Blocks',1
UNION SELECT 's', 'Defines strikethrough text','Blocks',1
UNION SELECT 'strike', 'Defines strikethrough text','Blocks',1
UNION SELECT 'a', 'Defines an anchor','Links',1
UNION SELECT 'link', 'Defines a resource reference','Links',0
UNION SELECT 'frame', 'Defines a sub window (a frame)','Frames',1
UNION SELECT 'frameset', 'Defines a set of frames','Frames',1
UNION SELECT 'noframes', 'Defines a noframe section','Frames',1
UNION SELECT 'iframe', 'Defines an inline sub window (frame)','Frames',1
UNION SELECT 'form', 'Defines a form ','Input',1
UNION SELECT 'input', 'Defines an input field','Input',0
UNION SELECT 'textarea', 'Defines a text area','Input',1
UNION SELECT 'button', 'Defines a push button','Input',1
UNION SELECT 'select', 'Defines a selectable list','Input',1
UNION SELECT 'optgroup', 'Defines an option group','Input',1
UNION SELECT 'option', 'Defines an item in a list box','Input',1
UNION SELECT 'label', 'Defines a label for a form control','Input',1
UNION SELECT 'fieldset', 'Defines a fieldset','Input',1
UNION SELECT 'legend', 'Defines a title in a fieldset','Input',1
UNION SELECT 'isindex', 'Deprecated. Use <input> instead','Input',1
UNION SELECT 'ul', 'Defines an unordered list','Lists',1
UNION SELECT 'ol', 'Defines an ordered list','Lists',1
UNION SELECT 'li', 'Defines a list item','Lists',1
UNION SELECT 'dir', 'Defines a directory list','Lists',1
UNION SELECT 'dl', 'Defines a definition list','Lists',1
UNION SELECT 'dt', 'Defines a definition term','Lists',1
UNION SELECT 'dd', 'Defines a definition description','Lists',1
UNION SELECT 'menu', 'Defines a menu list','Lists',1
UNION SELECT 'img', 'Defines an image','Images',0
UNION SELECT 'map', 'Defines an image map ','Images',1
UNION SELECT 'area', 'Defines an area inside an image map','Images',0
UNION SELECT 'table', 'Defines a table','Tables',1
UNION SELECT 'caption', 'Defines a table caption','Tables',1
UNION SELECT 'th', 'Defines a table header','Tables',1
UNION SELECT 'tr', 'Defines a table row','Tables',1
UNION SELECT 'td', 'Defines a table cell','Tables',1
UNION SELECT 'thead', 'Defines a table header','Tables',1
UNION SELECT 'tbody', 'Defines a table body','Tables',1
UNION SELECT 'tfoot', 'Defines a table footer','Tables',1
UNION SELECT 'col', 'Defines attributes for table columns ','Tables',0
UNION SELECT 'colgroup', 'Defines groups of table columns','Tables',1
UNION SELECT 'style', 'Defines a style definition','Styles',1
UNION SELECT 'div', 'Defines a section in a document','Styles',1
UNION SELECT 'span', 'Defines a section in a document','Styles',1
UNION SELECT 'head', 'Defines information about the document','Meta Info',1
UNION SELECT 'title', 'Defines the document title','Meta Info',1
UNION SELECT 'meta', 'Defines meta information','Meta Info',0
UNION SELECT 'base', 'Defines base URL for all links in a page','Meta Info',0
UNION SELECT 'basefont', 'Defines a base font','Meta Info',0
UNION SELECT 'script', 'Defines a script','Programming',1
UNION SELECT 'noscript', 'Defines a noscript section','Programming',1
UNION SELECT 'applet', 'Defines an applet','Programming',1
UNION SELECT 'object', 'Defines an embedded object','Programming',1
UNION SELECT 'param', 'Defines a parameter for an object','Programming',0
-- fn__web_tag