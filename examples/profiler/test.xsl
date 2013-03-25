<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output
    media-type="text/html" method="xml" encoding="utf-8"
    omit-xml-declaration="yes"
    doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
    doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
    indent="yes"
/>

<xsl:template match="/">
    <html>
        <head><xsl:call-template name="head" /></head>
        <body><xsl:call-template name="body" /></body>
    </html>
</xsl:template>

<xsl:template name="head">
    <meta http-equiv="Content-Type"  content="text/html; charset=utf-8" />
    <title>Test</title>
</xsl:template>

<xsl:template name="body">
    <h3>Test</h3>

    <ul>
        <xsl:for-each select="/root/item">
            <li><xsl:value-of select="." /></li>
        </xsl:for-each>
    </ul>
</xsl:template>

</xsl:stylesheet>
