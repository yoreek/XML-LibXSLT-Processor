<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:key name="ID" match="/root/item" use="@id" />
<xsl:key name="ID2" match="/root/item" use="." />

<xsl:param name="id" />
<xsl:param name="use_key" select="0" />

<xsl:variable name="DOC" select="document('search.xml')" />

<xsl:template match="/">
    <root>
        <xsl:for-each select="$DOC">
            <xsl:choose>
                <xsl:when test="$use_key = 1">
                    Search using key:   <xsl:value-of select="key('ID', $id)[1]" />
                </xsl:when>
                <xsl:otherwise>
                    Search without key: <xsl:value-of select="/root/item[@id = $id][1]" />
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </root>
</xsl:template>

</xsl:stylesheet>
