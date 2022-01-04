<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:bmy='http://www.bloomsbury.com'
    exclude-result-prefixes="#all"
    version="3.0">
    
    <xsl:variable name="unrecognized-style" select="'Element type &quot;([^&quot;]+)&quot; must be declared.'"/>
    <xsl:variable name="unexpected-style" select="'The content of element type &quot;([^&quot;]+)&quot; must match &quot;([^&quot;]+)&quot;.'"/>
    <xsl:variable name="stylename-prefix" select="'^(Para|Text)\.'"/>
    <xsl:variable name="element-names" select="'[^|(),?*+]+'"/>
    
    <xsl:template match="*">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="error[@location]">
        <xsl:copy>
            <!-- TODO: handle @location to retrieve region of affected text -->
            <xsl:call-template name="refine-error-message"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="refine-error-message">
        <xsl:choose>
            <xsl:when test="matches(., $unrecognized-style)">
                <xsl:analyze-string select="." regex="{$unrecognized-style}">
                    <xsl:matching-substring>
                        <xsl:variable name="stylename" select="regex-group(1)"/>
                        <xsl:text>unrecognized </xsl:text>
                        <xsl:value-of select="bmy:style-type-from-name($stylename)"/>
                        <xsl:text> style: </xsl:text>
                        <xsl:value-of select="bmy:element-to-stylename($stylename)"/>
                    </xsl:matching-substring>
                </xsl:analyze-string>
            </xsl:when>
            <xsl:when test="matches(., $unexpected-style)">
                <xsl:analyze-string select="." regex="{$unexpected-style}">
                    <xsl:matching-substring>
                        <xsl:call-template name="unexpected-style">
                            <xsl:with-param name="stylename" select="regex-group(1)"/>
                        </xsl:call-template>
                    </xsl:matching-substring>
                </xsl:analyze-string>
            </xsl:when>
            <xsl:otherwise><xsl:sequence select="."/></xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="unexpected-style">
        <xsl:param name="stylename"/>
        <xsl:choose>
            <xsl:when test="starts-with($stylename, 'Para.')">paragraph style '<xsl:value-of select="bmy:element-to-stylename($stylename)"/>' should only contain one of these character styles: <xsl:value-of select="string-join(bmy:content-model-to-styles(regex-group(2)), ', ')"/></xsl:when>
            <xsl:when test="starts-with($stylename, 'Text.')">character style '<xsl:value-of select="bmy:element-to-stylename($stylename)"/>' should only contain one of these character styles: <xsl:value-of select="string-join(bmy:content-model-to-styles(regex-group(2)), ', ')"/></xsl:when>
            <xsl:when test="starts-with($stylename, 'Document')">the document should only contain these paragraph styles: <xsl:value-of select="string-join(bmy:content-model-to-styles(regex-group(2)), ', ')"/></xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <xsl:function name="bmy:element-to-stylename" as="xs:string">
        <xsl:param name="elem" as="xs:string"/>
        <xsl:value-of select="replace($elem, $stylename-prefix, '')"/>
    </xsl:function>
    
    <xsl:function name="bmy:content-model-to-styles" as="xs:string+">
        <xsl:param name="model" as="xs:string"/>
        <xsl:analyze-string select="$model" regex="{$element-names}">
            <xsl:matching-substring><xsl:value-of select="bmy:element-to-stylename(.)"/></xsl:matching-substring>
        </xsl:analyze-string>
    </xsl:function>
    
    <xsl:function name="bmy:style-type-from-name" as="xs:string">
        <xsl:param name="stylename"/>
        <xsl:choose>
            <xsl:when test="starts-with($stylename, 'Para.')">paragraph</xsl:when>
            <xsl:when test="starts-with($stylename, 'Text.')">character</xsl:when>
            <xsl:when test="starts-with($stylename, 'Document')">document</xsl:when>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>