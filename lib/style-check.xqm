(:~ 
 : Module of BaseX XQuery functions to provide style-checking functionality
 : for Microsoft Word documents.
 : 
 : Tested under BaseX 9.5
 : The target Word XML format is that in the namespace:
 : 	http://schemas.openxmlformats.org/wordprocessingml/2006/main
 :
 : The main entry point is sc:check(), which takes one or more paths to *.docx
 : documents. Each of these is unzipped, simplified to consist of elements
 : describing paragraph and inline styles, then validated against the style
 : DTD - see path given in $sc:STYLE_SCHEMA.
 :
 : APPROACH
 : ~~~~~~~~
 : 1. does path exist?
 : 2. is it a DOCX?
 : 3. is it a valid zip?
 : 4. unzip it
 : 5. is it a valid DOCX (does it contain word/document.xml)?
 : 6. transform it to simplified styles
 : 7. validate the result with custom validator
 : 8. return the resulting report
 :
 : TODO: use $sc:UNZIP_DIR
 :)

module namespace sc = "http://www.andrewsales.com/style-check";

declare variable $sc:UNZIP_DIR external := '.';
declare variable $sc:DOCX_CONTENT as element(archive:entry)+ := 
  <archive:entry>word/document.xml</archive:entry>;	(:expected zip entries:)
declare variable $sc:STYLE_SCHEMA as xs:anyURI external := 
  resolve-uri('../dtd/style-schema.dtd');

(:~ 
 : Process one or more word-processing documents.
 : Currently only DOCX format is supported.
 : @param docs the absolute URI(s) of the document(s) to process
 : @return manifest of file paths for further processing
 :)
declare function sc:check($docs as xs:string+)
as element(files)
{
  sc:build-manifest($docs) => sc:simplify-styles()
};

(:~ Build the manifest for the Word XML files extracted. 
 : @param docs the absolute URI(s) of the document(s) to process
 : @return 
 :)
declare function sc:build-manifest($docs as xs:string+)
as element(files)
{
  <files>{
    $docs !
    (
      sc:ensure-file(.) => sc:ensure-format() => sc:unzip(),
      sc:ensure-contents(.)
    )
  }</files>
};

(:~ Batch-transform the manifest of files passed in.
 : @param manifest the manifest of files
 :)
declare function sc:simplify-styles($manifest as element(files))
as element(files)
{
  xslt:transform(
    $manifest, 
    resolve-uri('../xsl/batch-transform.xsl'),	(:TODO: compile this to SEF too?:)
    map{'dtd-loc':$sc:STYLE_SCHEMA}
  )/files
};

declare function sc:ensure-file($path as xs:string)
as xs:string?
{
  if(file:exists($path))
  then $path
  else error(xs:QName('sc:file-not-found'), 'cannot find file: '|| $path)
};

declare function sc:ensure-format($path as xs:string)
as xs:string?
{
  if(ends-with($path, '.docx'))
  then $path
  else error(xs:QName('sc:invalid-format'), 'invalid format for file: '|| $path)
};

(:~ 
 : Extract the contents of an archive representing a single word-processing
 : document.
 : In this implementation, only the document word/document.xml will be extracted,
 : to a directory named after the archive filename (minus extension).
 : @param zip the word-processing document
 :)
declare function sc:unzip($zip as xs:string)
as empty-sequence()
{
  try{
    archive:extract-to(
      sc:unzip-path($zip), 
      file:read-binary($zip), 
      $sc:DOCX_CONTENT
    )    
  }
  catch * {
    error(xs:QName('sc:docx-zip'), 'error unzipping '|| $zip || ' :' || 
      $err:description)
  }
};

(:~ 
 : Check that all expected content is present in the DOCX archive.
 : @param docx the absolute path to the DOCX archive
 : @return the absolute path(s) to the unzipped content
 :)
declare function sc:ensure-contents($docx as xs:string)
as element(file)+
{
  for $x in $sc:DOCX_CONTENT
  let $unzip-path := sc:unzip-path($docx)
  let $path := resolve-uri($x, $unzip-path)
  return
    if(file:exists($path))
    then <file xml:base='file:/{$unzip-path}' src='{$x}'/>
    else error(xs:QName('sc:docx-no-content'), 'no content found: '|| $path ||
  '; expected: ' || $x)
};

(:~ 
 : Return the directory path where the DOCX contents are to be extracted.
 : @param docx absolute path to the DOCX file
 : @return path to the extraction directory
 :)
declare function sc:unzip-path($docx as xs:string)
as xs:string
{
  file:resolve-path(substring-before($docx, '.docx'), file:parent($docx))
  => replace('\\', '/')
};