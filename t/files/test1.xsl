<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output
    media-type="text/html" method="xml" encoding="utf-8"
    omit-xml-declaration="yes"
    indent="no"
/>

<xsl:param name="param1" />

<xsl:template match="/">
    <root>
        <param1><xsl:value-of select="$param1" /></param1>
        <tag1><xsl:value-of select="/root/tag1" /></tag1>
    </root>
</xsl:template>

</xsl:stylesheet>
