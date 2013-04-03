<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:str="http://xsltproc.org/xslt/string"
    extension-element-prefixes="str"
>

<xsl:output
    media-type="text/html" method="xml" encoding="utf-8"
    omit-xml-declaration="yes"
    indent="no"
/>

<xsl:template match="/">
    <root>
        <ltrim><xsl:value-of select="str:ltrim(' &#10;&#13;&#9;  123   ')" /></ltrim>
        <ltrim><xsl:value-of select="str:ltrim('123   ')" /></ltrim>
        <ltrim><xsl:value-of select="str:ltrim('')" /></ltrim>
        <rtrim><xsl:value-of select="str:rtrim('   123 &#10;&#13;&#9;  ')" /></rtrim>
        <rtrim><xsl:value-of select="str:rtrim('   123')" /></rtrim>
        <rtrim><xsl:value-of select="str:rtrim('')" /></rtrim>
        <trim><xsl:value-of select="str:trim(' &#10;&#13;&#9;  123 &#10;&#13;&#9;  ')" /></trim>
        <trim><xsl:value-of select="str:trim('123')" /></trim>
        <trim><xsl:value-of select="str:trim('')" /></trim>
    </root>
</xsl:template>

</xsl:stylesheet>
