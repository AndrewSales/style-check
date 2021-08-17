<?xml version="1.0" encoding="UTF-8"?>
<!--
    Batch-transform the files passed in, as an XML manifest with the format:
    
    <files>
        <file xml:base='/path/to/dir/' src='word/document.xml'/>
    </files>
    
    On successful transformation of the entire batch (recovery options remain 
    as defaulted), return the manifest with file/@dest inserted, showing the 
    URI of the output:
    
        <file xml:base='/path/to/dir/' src='word/document.xml' 
            dest='/path/to/dir/out/document.xml'/>
    -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:fn='http://www.w3.org/2005/xpath-functions'
    exclude-result-prefixes="#all"
    version="3.0">
    
    <!-- sys id of DTD -->
    <xsl:param name="dtd-loc" required="true"/>
    
    <xsl:template match="/files">
        <xsl:copy><xsl:apply-templates/></xsl:copy>
    </xsl:template>
    
    <xsl:template match="/files/file">
        <xsl:variable name="source" select="resolve-uri(@src, @xml:base)"/>
        <xsl:variable name="output" select="replace($source, '/word/', '/out/')"/>
        <xsl:message expand-text="true">transforming {$source} to {$output}</xsl:message>
        <xsl:result-document href="{$output}" doctype-system="{$dtd-loc}" indent="no">
            <xsl:sequence select="fn:transform(
                map{
                'stylesheet-location': 'word2styles/styles2elems.sef',
                'source-node':doc($source)
                }
                )?output"/>
        </xsl:result-document>
        <file dest='{$output}'><xsl:copy-of select="@*"/></file>
    </xsl:template>
    
</xsl:stylesheet>