<?xml version="1.0" encoding="UTF-8"?>
<!--
    Stylesheet to validate against Schematron.
    Batch-transform the files passed in, as an XML manifest with the format:
    
    <result>
        <errors systemId='...'>...</errors>
    </result>
    
    Return an amended version of the SVRL (failed assertions and successful 
    reports renamed to their @role, defaulting to <error>), as shown:
    
    <result>
        <errors systemId='...'>
            [any DTD errors here]
            <schematron>
                <error location='...' test='...'>...</error>
                [etc]
            </schematron>
        </errors>        
    </result>    
    
    -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:fn='http://www.w3.org/2005/xpath-functions'
    xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
    exclude-result-prefixes="#all"
    version="3.0">
        
    <xsl:template match="/result">
        <xsl:copy><xsl:apply-templates/></xsl:copy>
    </xsl:template>
    
    <xsl:template match="/result/output | /result/code">
        <xsl:copy-of select="."/>
    </xsl:template>
    
    <xsl:template match="/result/errors[@systemId]">
        <xsl:message expand-text="true">validating {@systemId} with Schematron</xsl:message>
        <xsl:copy>
            <xsl:copy-of select="@*, node()"/>
            <!-- TODO: compile to SEF? -->
            <xsl:variable name="svrl" select="fn:transform(
                map{
                'stylesheet-location': '../sch/style-schema.xsl',
                'source-node':doc(@systemId)
                }
                )?output"/>
            <schematron><xsl:apply-templates select="$svrl"/></schematron>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="svrl:failed-assert | svrl:successful-report">
        <xsl:element name="{if(@role) then @role else 'error'}">
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="svrl:text">
        <xsl:apply-templates/>
    </xsl:template>
    
</xsl:stylesheet>