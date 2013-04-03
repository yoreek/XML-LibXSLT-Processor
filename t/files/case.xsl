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
        <xsl:if test="function-available('str:lc')">
            <lc><xsl:value-of select="str:lc('AbCd')" /></lc>
            <uc><xsl:value-of select="str:uc('aBcD')" /></uc>
        </xsl:if>
    </root>
</xsl:template>

</xsl:stylesheet>
