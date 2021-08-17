<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:fn='http://www.w3.org/2005/xpath-functions'
    xmlns:map='http://www.w3.org/2005/xpath-functions/map'
    xmlns:err='http://www.w3.org/2005/xqt-errors'
    xmlns:saxon-config='http://saxon.sf.net/ns/configuration'
    exclude-result-prefixes="xs math"
    version="3.0">
    
    <!-- the result of fn:transform() is a map, so this output method
    serializes the result without further handling -->
    <xsl:output method="adaptive" indent="no"
        doctype-system="style-schema.dtd"/>
    
    <xsl:template match="/files/file">
        <xsl:message expand-text="true">processing {.}</xsl:message>
        <xsl:result-document href="{replace(., '/word/', '/out/')}">
            <xsl:sequence select="fn:transform(
                map{
                'stylesheet-location': 'styles2elems.xsl',
                'source-node':doc(.)
                }
                )?output"/>
        </xsl:result-document>
    </xsl:template>
    
</xsl:stylesheet>