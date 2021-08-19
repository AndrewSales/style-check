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
declare variable $sc:OPT_DEBUG := 'debug';
declare variable $sc:HALT_ON_INVALID := 'halt-on-invalid';

(:~ 
 : Process one or more word-processing documents.
 : Currently only DOCX format is supported.
 : Options are: 
 : 	debug (Boolean): whether to emit debugging messages via trace()
 : 	halt-on-invalid (Boolean): whether to halt processing on the first invalid 
 : document returned by sc:validate()
 : @param docs the absolute URI(s) of the document(s) to process
 : @param options map of options
 : @return manifest of file paths for further processing
 :)
declare function sc:check(
  $docs as xs:string+,
  $options as map(*)
)
{
  let $_ := sc:debug('check(): ' || string-join($docs, ' '), $options)
  let $manifest := sc:build-manifest($docs)
  let $_ := sc:debug('manifest=' || $manifest, $options)
  return sc:simplify-styles($manifest) => sc:validate($options)
};

(:~ 
 : Process one or more word-processing documents.
 : Currently only DOCX format is supported.
 : If the option '--halt-on-invalid' is passed, processing halts on the first
 : invalid file.
 : @param manifest of files to be validated
 : @param options map of options
 : @return one error report per file validated
 :)
declare function sc:validate(
  $manifest as element(files),
  $options as map(*)
)
as element(result)
{
  let $_ := sc:debug('validate paths='||
    string-join($manifest/file/@dest, ' '), $options)
  return
  proc:execute(
    'java',
    (
      '-jar', resolve-uri('../etc/validator.jar')=>substring-after('file:///'),
      $manifest/file/@dest ! data(),
      if($options ? ($sc:HALT_ON_INVALID)) then '--'||$sc:HALT_ON_INVALID else ()
    )
  )
};

(:~ Build the manifest for the Word XML files extracted. 
 : @param docs the absolute URI(s) of the document(s) to process
 : @return the manifest
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

(:~ Ensure the file to be processed exists.
 : @param path the file path
 :)
declare function sc:ensure-file($path as xs:string)
as xs:string?
{
  if(file:exists($path))
  then $path
  else error(xs:QName('sc:file-not-found'), 'cannot find file: '|| $path)
};

(:~ Ensure the file to be processed is in the correct format, by examining its
 : extension.
 : @param path the file path
 :)
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
 : This implementation uses the file name, minus extension.
 : @param docx absolute path to the DOCX file
 : @return path to the extraction directory
 :)
declare function sc:unzip-path($docx as xs:string)
as xs:string
{
  file:resolve-path(substring-before($docx, '.docx'), file:parent($docx))
  => replace('\\', '/')
};

(:~ Emit debugging messages to the console.
 : @param msg the contents of the message to display
 : @param options map of options (if 'debug' is set to true(), messages are 
 : emitted)
 :)
declare %private function sc:debug($msg as item()*, $options as map(*))
{
  if($options?($sc:OPT_DEBUG))
  then trace('[DEBUG]:' || $msg)
  else ()
};