<?xml version="1.0" encoding="UTF-8"?>
<!--
    Stylesheet to validate against Schematron.
    Batch-transform the files passed in, as an XML manifest with the format:
    
    <result>
        <errors systemId='...' haltOnInvalid='{true|false}'>...</errors>
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
        <xsl:copy>
            <xsl:choose>
                <xsl:when test="errors[@systemId]/@haltOnInvalid = 'true'">
                    <xsl:iterate select="errors[@systemId]">
                        <xsl:variable name="sch-output" as="element(errors)">
                            <xsl:apply-templates select=".">
                                <xsl:with-param name="schematron-validation" select="true()"/>
                            </xsl:apply-templates>
                        </xsl:variable>
                        <xsl:sequence select="$sch-output"/>                        
                        <xsl:choose>
                            <xsl:when test="$sch-output/schematron/*">
                                <xsl:message>BREAKING</xsl:message>
                                <xsl:apply-templates select="following-sibling::errors[@systemId]">
                                    <xsl:with-param name="schematron-validation" select="false()"/>
                                </xsl:apply-templates>
                                <xsl:break/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:next-iteration/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:iterate>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates>
                        <xsl:with-param name="schematron-validation" select="true()"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:apply-templates select="output | code"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="/result/output | /result/code" mode="#all">
        <xsl:copy-of select="."/>
    </xsl:template>
    
    <xsl:template match="/result/errors[@systemId]">
        <xsl:param name="schematron-validation" as="xs:boolean" />
        <xsl:message expand-text="true">validate {@systemId} with Schematron={$schematron-validation}</xsl:message>
        <xsl:copy>
            <xsl:copy-of select="@*, node()"/>
           <xsl:if test="$schematron-validation"> <!-- TODO: compile to SEF? -->
            <xsl:variable name="svrl" select="fn:transform(
                map{
                'stylesheet-location': '../sch/style-schema.xsl',
                'source-node':doc(@systemId)
                }
                )?output"/>
            <schematron><xsl:apply-templates select="$svrl"/></schematron></xsl:if>
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