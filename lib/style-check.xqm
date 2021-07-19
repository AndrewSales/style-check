module namespace sc = "http://www.andrewsales.com/style-check";

declare variable $sc:unzip-dir external := '.';
declare variable $sc:DOCX_CONTENT as element(archive:entry)+ := 
  <archive:entry>word/document.xml</archive:entry>;	(:expected zip entries:)

(:~ 
 : Process one or more word-processing documents.
 : Currently only DOCX format is supported.
 : @param docs the absolute URI(s) of the document(s) to process
 :)
declare function sc:check($docs as xs:string+)
{
  (:
  1. does path exist?
  2. is it a DOCX?
  3. is it a valid zip?
  4. unzip it
  4a. is it a valid DOCX (does it contain word/document.xml)?
  5. transform it to simplified styles
  6. validate the result with custom validator
  7. return the resulting report
  :)
  
  for $doc in $docs
  return 
  (sc:ensure-file($doc) => sc:ensure-format() => sc:unzip(), 
  sc:ensure-contents($doc))
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
      file:read-binary($zip), $sc:DOCX_CONTENT
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
as xs:string+
{
  for $x in $sc:DOCX_CONTENT
  let $path := sc:unzip-path($docx) || '/' || $x
  return
    if(file:exists($path))
    then $path
    else error(xs:QName('sc:docx-no-content'), 'no content found: '|| $path ||
  '; expected: ' || $x)
};

(:~ 
 : Return the directory path where the DOCX contents are to be extracted.
 : @param docx absolute path to the DOCX file
 : @return path to the extraction directory
 :)
declare function sc:unzip-path($docx as xs:string)
{
  file:resolve-path(substring-before($docx, '.docx'), file:parent($docx))
};