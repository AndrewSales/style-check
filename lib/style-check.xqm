(:~ 
 : <p>Module of BaseX XQuery functions to provide style-checking functionality
 : for Microsoft Word documents.</p>
 : 
 : <p>Tested under BaseX 9.5.</p>
 : The target Word XML format is that in the namespace:
 : 	<code>http://schemas.openxmlformats.org/wordprocessingml/2006/main</code>.
 :
 : <p>The main entry point is sc:check(), which takes one or more paths to *.docx
 : documents. Each of these is unzipped, simplified to consist of elements
 : describing paragraph and inline styles, then validated against the style
 : DTD - see path given in $sc:STYLE_SCHEMA.</p>
 :
 : <h2>APPROACH</h2>
 : <ol><li>does path exist?</li>
 : <li>is it a DOCX?</li>
 : <li>is it a valid zip?</li>
 : <li>unzip it</li>
 : <li>is it a valid DOCX (does it contain <code>word/document.xml</code>)?</li>
 : <li>transform it to simplified styles</li>
 : <li>validate the result with custom validator</li>
 : <li>return the resulting report</li>
 : </ol>
 :
 : <p>TODO: use <code>$sc:UNZIP_DIR</code></p>
 :)

module namespace sc = "http://www.andrewsales.com/style-check";

(:~ where the contents of the DOCX will be extracted to (not currently used) :)
declare variable $sc:UNZIP_DIR external := '.';
(:~ the zip entries to be extracted from DOCX :)
declare variable $sc:DOCX_CONTENT as element(archive:entry)+ := 
  <archive:entry>word/document.xml</archive:entry>;	(:expected zip entries:)
(:~ location of the style schema applied during validation :)
declare variable $sc:STYLE_SCHEMA as xs:anyURI external := 
  resolve-uri('../dtd/style-schema.dtd');
(:~ Schematron validation flag :)  
declare variable $sc:OPT_SCHEMATRON_VALIDATION as xs:string := 'schematron';
(:~ debugging flag :)  
declare variable $sc:OPT_DEBUG as xs:string := 'debug';
(:~ profiling flag :)  
declare variable $sc:OPT_PROFILE as xs:string := 'profile';
(:~ string of the halt-on-invalid validation option :)
declare variable $sc:OPT_HALT_ON_INVALID as xs:string := 'halt-on-invalid';

(:~ 
 : Process one or more word-processing documents.
 : Currently only DOCX format is supported.
 : Options are: 
 : <ul><li>debug (Boolean): whether to emit debugging messages via trace()</li>
 : <li>halt-on-invalid (Boolean): whether to halt processing on the first invalid 
 : document returned by <code>sc:validate()</code></li></ul>
 :
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
  let $start := prof:current-ms()
  let $manifest := sc:build-manifest($docs, $options)
  let $_ := sc:profile('manifest built, '||count($manifest/file)||' files', 
    $start, $options)
  let $_ := sc:debug('manifest=' || $manifest, $options)
  let $start := prof:current-ms()
  let $simplified := sc:simplify-styles($manifest)
  let $_ := sc:profile('styles simplified', $start, $options)
  let $start := prof:current-ms()
  return 
  (
    sc:validate($simplified, $options), 
    sc:profile('validated', $start, $options)
  )
};

(:~ 
 : Process one or more word-processing documents.
 : Currently only DOCX format is supported.
 : If the option <code>halt-on-invalid</code> is set to <code>true()</code>, 
 : processing halts on the first invalid file.
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
  let $result :=
  proc:execute(
    'java',
    (
      '-jar', resolve-uri('../etc/validator.jar')=>substring-after('file:///'),
      $manifest/file/@dest ! data(),
      if($options ? ($sc:OPT_HALT_ON_INVALID)) 
      then '--'||$sc:OPT_HALT_ON_INVALID else ()
    )
  )
  return
  if($result/code eq '-1')	(:indicates abnormal termination:)
  then $result
  else 
  if($options ? ($sc:OPT_SCHEMATRON_VALIDATION))
  then sc:refine-report($result) => sc:validate-schematron()
  else sc:refine-report($result)
};

declare function sc:validate-schematron($report as element(result))
as element(result)
{
  xslt:transform(
    $report,
    resolve-uri('../xsl/schematron-validation.xsl')
  )/result
};

(:~ 
 : Amend the error messages contained in the report passed in to direct users to
 : the region of affected text in the document, and couch the message in
 : style-centric (rather than XML) terms.
 : Note this is not attempted if the return code was <code>-1</code>, since this
 : indicates abnormal termination, usually resulting from an I/O or 
 : well-formedness error.
 : @param result the report resulting from sc:validate()
 : @return report containing refined error messages
 :)
declare function sc:refine-report($result as element(result)) 
as element(result)
{
  xslt:transform(
    <result>{parse-xml-fragment($result/output)}{$result/(error|code)}</result>,
    resolve-uri('../xsl/refine-report.xsl')
  )/*
};

(:~ Build the manifest for the Word XML files extracted. 
 : @param docs the absolute URI(s) of the document(s) to process
 : @return the manifest, each document in the batch represented by <code>&lt;file src='...'/></code>
 :)
declare function sc:build-manifest($docs as xs:string+, $options as map(*))
as element(files)
{
  <files>{
    $docs !
    (
      let $files := sc:ensure-file(.) => sc:ensure-format() 
      let $start := prof:current-ms()
      return 
      (
        sc:unzip($files),
        sc:profile('unzipped '||., $start, $options),
        sc:ensure-contents(.)
      )
    )
  }</files>
};

(:~ Batch-transform the manifest of files passed in.
 : @param manifest the manifest of files
 : @return the manifest, each document in the batch represented by 
 : <code>&lt;file src='...' dest='...'/></code>
 :)
declare function sc:simplify-styles($manifest as element(files))
as element(files)
{
  xslt:transform(
    $manifest, 
    resolve-uri('../xsl/batch-transform.xsl'),	(:negligible gain if compiled to SEF:)
    map{'dtd-loc':$sc:STYLE_SCHEMA}
  )/files
};

declare function sc:profile(
  $msg as xs:string, 
  $start as xs:integer, 
  $options as map(*)
)
{
  if($options?($sc:OPT_PROFILE))
  then
  trace('[profile]:' || $msg || ' ' || prof:current-ms() - $start || 'ms')
  else()
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
 : In this implementation, only the document <code>word/document.xml</code> will be extracted,
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
  (:cope with spaces in filenames: escape them for resolution purposes, but
  retain them for checking the actual file path exists:)
  let $uri := resolve-uri($x, $unzip-path => replace(' ', '%20'))
  let $path := replace($uri, '%20', ' ')
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