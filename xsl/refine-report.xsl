<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:wordml='http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    xmlns:asdp='http://www.andrewsales.com'
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
    
    <xsl:template match="errors[@systemId]">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <!-- hack the path to the DOCX XML as unzipped -->
            <xsl:variable name="path" select="replace(@systemId, '/out/', '/word/')"/>
            <xsl:apply-templates select="error">
                <xsl:with-param name="doc" select="doc($path)" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="error[@location]">
        <xsl:param name="doc" tunnel="yes" as="document-node(element(wordml:document))"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:call-template name="refine-error-message"/>
            <xsl:variable name="text"><xsl:evaluate context-item="$doc" xpath="@location"/></xsl:variable>
            <xsl:text>: </xsl:text>
            <text style="{if($text/wordml:p) then 'para' else 'char'}"><xsl:value-of select="$text"/></text>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="refine-error-message">
        <xsl:choose>
            <xsl:when test="matches(., $unrecognized-style)">
                <xsl:analyze-string select="." regex="{$unrecognized-style}">
                    <xsl:matching-substring>
                        <xsl:variable name="stylename" select="regex-group(1)"/>
                        <xsl:text>unrecognized </xsl:text>
                        <xsl:value-of select="asdp:style-type-from-name($stylename)"/>
                        <xsl:text> style: </xsl:text>
                        <xsl:value-of select="asdp:element-to-stylename($stylename)"/>
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
            <xsl:when test="starts-with($stylename, 'Para.')">paragraph style '<xsl:value-of select="asdp:element-to-stylename($stylename)"/>' should only contain one of these character styles: <xsl:value-of select="string-join(asdp:content-model-to-styles(regex-group(2)), ', ')"/></xsl:when>
            <xsl:when test="starts-with($stylename, 'Text.')">character style '<xsl:value-of select="asdp:element-to-stylename($stylename)"/>' should only contain one of these character styles: <xsl:value-of select="string-join(asdp:content-model-to-styles(regex-group(2)), ', ')"/></xsl:when>
            <xsl:when test="starts-with($stylename, 'Document')">the document should only contain these paragraph styles: <xsl:value-of select="string-join(asdp:content-model-to-styles(regex-group(2)), ', ')"/></xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <xsl:function name="asdp:element-to-stylename" as="xs:string">
        <xsl:param name="elem" as="xs:string"/>
        <xsl:value-of select="replace($elem, $stylename-prefix, '')"/>
    </xsl:function>
    
    <xsl:function name="asdp:content-model-to-styles" as="xs:string+">
        <xsl:param name="model" as="xs:string"/>
        <xsl:analyze-string select="$model" regex="{$element-names}">
            <xsl:matching-substring><xsl:value-of select="asdp:element-to-stylename(.)"/></xsl:matching-substring>
        </xsl:analyze-string>
    </xsl:function>
    
    <xsl:function name="asdp:style-type-from-name" as="xs:string">
        <xsl:param name="stylename"/>
        <xsl:choose>
            <xsl:when test="starts-with($stylename, 'Para.')">paragraph</xsl:when>
            <xsl:when test="starts-with($stylename, 'Text.')">character</xsl:when>
            <xsl:when test="starts-with($stylename, 'Document')">document</xsl:when>
            <xsl:otherwise><xsl:value-of select="$stylename"/></xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>