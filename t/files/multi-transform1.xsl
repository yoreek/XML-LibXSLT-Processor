<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output
    media-type="text/html" method="xml" encoding="utf-8"
    omit-xml-declaration="yes"
    indent="no"
/>

<xsl:param name="pass" />

<xsl:template match="/">
    <root>
        <pass1><xsl:value-of select="$pass" /></pass1>
    </root>
</xsl:template>

</xsl:stylesheet>
