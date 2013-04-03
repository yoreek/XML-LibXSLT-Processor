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
        <join_one_arg><xsl:value-of select="str:join('str1', ',')" /></join_one_arg>
        <join_two_args><xsl:value-of select="str:join('str1', 'str2', ',')" /></join_two_args>
        <join_node_set><xsl:value-of select="str:join(/root/string, ',')" /></join_node_set>
        <join_mix><xsl:value-of select="str:join('str1', /root/string, 'str6', ',')" /></join_mix>
    </root>
</xsl:template>

</xsl:stylesheet>
