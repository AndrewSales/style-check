(:~ Unit tests for the style checking module. :)

module namespace sct = "http://www.andrewsales.com/style-check-tests";

import module namespace sc = "http://www.andrewsales.com/style-check" at "../lib/style-check.xqm";

(:static test cases:)
declare variable $sct:goodDOCX := resolve-uri("proper.docx", static-base-uri());
declare variable $sct:badDOCX := resolve-uri("bad.docx", static-base-uri());
declare variable $sct:filenameWithSpaces := resolve-uri('filename%20with%20spaces.docx');
declare variable $sct:malformedXML := resolve-uri('malformed.xml');

declare 
%unit:before-module 
%unit:after-module 
function sct:cleanup()
{
  for $dir in ('proper', 'style-error', 'no-errors', 'stylename-with-spaces',
  'filename%20with%20spaces')
  let $path := resolve-uri($dir)
  return
  if(file:exists($path))
  then
  file:delete($path, true())
  else ()
};

declare %unit:test function sct:ensure-file-pass()
{
  sc:ensure-file($sct:goodDOCX)
};

(:file not found:)
declare %unit:test('expected', 'sc:file-not-found') function sct:ensure-file-fail()
{
  sc:ensure-file('not-my.docx')
};

declare %unit:test function sct:ensure-format-pass()
{
  unit:assert-equals(
    sc:ensure-format('my.docx'),
    'my.docx'
  )
};

(:not a .docx file:)
declare %unit:test("expected", 'sc:invalid-format') function sct:ensure-format-fail()
{
  sc:ensure-format('my.doc')
};

declare %unit:test function sct:unzip-pass()
{
  sc:unzip($sct:goodDOCX)
};

(:bad zip:)
declare %unit:test('expected', 'sc:docx-zip') function sct:unzip-fail()
{
 sc:unzip($sct:badDOCX)
};

declare %unit:test function sct:ensure-contents-pass()
{
  sc:ensure-contents($sct:goodDOCX)
};

declare %unit:test function sct:ensure-contents-src()
{
  let $file := sc:ensure-contents($sct:goodDOCX)
  
  return
  unit:assert-equals(
     data($file/@src),
     'word/document.xml'
  )
};

(:expected contents not in zip:)
declare %unit:test('expected', 'sc:docx-no-content') function sct:ensure-contents-fail()
{
  sc:ensure-contents($sct:badDOCX)
};

(:~ manifest created before the simplify transform should contain @src paths to 
the input and @xml:base :)
declare %unit:test function sct:build-manifest()
{
  let $manifest := sc:build-manifest($sct:goodDOCX, map{})
  
  return
  (unit:assert(
    $manifest/file/@xml:base => ends-with('/test/proper/')
  ),
  unit:assert(
    $manifest/file/@src eq "word/document.xml"
  ))  
};

(:~ manifest returned after the successful transform should now also contain
@dest paths to the output
N.B. we have to do some fixups on the URIs to make this portable :)
declare %unit:test function sct:simplify-styles()
{
  let $manifest := sc:build-manifest($sct:goodDOCX, map{}) => sc:simplify-styles()
  
  return
  (
    unit:assert-equals(
      $manifest/file/@dest/data(), 
      resolve-uri('proper/out/document.xml') => replace('///', '/')
    ),
    unit:assert-equals(
      $manifest/file/@src/data(), "word/document.xml"
    ),
    unit:assert-equals(
      $manifest/file/@xml:base/data(),
      resolve-uri('proper/') => replace('///', '/')
    )
  )
};

declare %unit:test function sct:validator-jar-exists()
{
  unit:assert(
    file:exists(resolve-uri("../etc/validator.jar"))
  )
};

declare %unit:before('validate-no-errors') function sct:before-validate-no-errors()
{
  sc:build-manifest((resolve-uri('no-errors.docx')), map{}) => sc:simplify-styles()
};

(:there's an empty error report:)
declare %unit:test function sct:validate-no-errors()
{
  let $result := sc:validate(
    <files><file dest='{resolve-uri('no-errors/out/document.xml')}'/></files>, 
    map{}
  )
  
  return  
  (
    unit:assert($result/errors),
    unit:assert-equals($result/errors/*, ())
  )
};

declare %unit:test function sct:validate-no-paths()
{
  let $result := sc:validate(
    <files><file></file></files>, 
    map{}
  )
  
  return
  (unit:assert($result/error[.='[FATAL]:no paths supplied for validation
']),
  unit:assert($result/code[.='-1']))
};

declare %unit:test function sct:validate-errors()
{
  let $result := sc:check(resolve-uri("style-error.docx"), map{})
  return
  unit:assert-equals($result/errors/error => count(), 3)
};

declare %unit:test function sct:validate-multiple()
{
  let $result := sc:check(
    (resolve-uri("style-error.docx"),
    resolve-uri("no-errors.docx")),
    map{}
  )    
  return
  unit:assert-equals($result/errors => count(), 2)	(:two error reports in o/p:)
};

declare %unit:test function sct:check()
{
  let $result := sc:check(resolve-uri("style-error.docx"), map{})
  return
  unit:assert-equals($result/errors/error => count(), 3)
};

(:the validator exits with error code -1 on fatal errors:)
declare %unit:test function sct:validate-io-error()
{
  unit:assert-equals(
    sc:validate(
      <files><file dest='non-existent.xml'/></files>,
      map{}
    )/code,
    <code>-1</code>
  )
};

declare %unit:test function sct:validate-empty-path()
{
  unit:assert-equals(
    sc:validate(
      <files><file dest=''/></files>,
      map{}
    )/code,
    <code>-1</code>
  )
};

declare %unit:test function sct:validate-malformed-error()
{
  unit:assert-equals(
    sc:validate(
      <files><file dest='{$sct:malformedXML}'/></files>,
      map{}
    )/code,
    <code>-1</code>
  )
};

declare %unit:test function sct:run-validator()
{
  let $result := proc:execute(
    'java',
    (
      '-jar', resolve-uri('../etc/validator.jar')=>substring-after('file:///')
    )
  )
  
  return 
  (unit:assert-equals(
    $result/error, <error>[FATAL]:no paths supplied for validation
</error>
  ),
  unit:assert-equals(
    $result/code, <code>-1</code>
  ))
};

declare %unit:test function sct:style-dtd-present()
{
  unit:assert(file:exists(resolve-uri('../dtd/style-schema.dtd', static-base-uri())))
};

declare %unit:test function sct:filename-with-spaces()
{
  let $result := sc:check($sct:filenameWithSpaces, map{})
  return
  (
    unit:assert-equals($result/code, <code>0</code>),	(:process succeeded:)
    unit:assert(ends-with($result/errors/@systemId, 'filename with spaces/out/document.xml'))	(:filepath reported correctly:)
  )
};

declare %unit:test function sct:stylename-with-spaces()
{
  let $result := sc:check(resolve-uri('stylename-with-spaces.docx'), map{})
  return
  (
    unit:assert(
      starts-with($result/errors/error[1], 'unrecognized paragraph style: Mystylenamehasspaces: ')
    ),
    unit:assert(
      $result/errors/error[1]/text[.='foo']
    )
  )
  
};

declare %unit:test function sct:report-refined()
{
  let $result := sc:check(resolve-uri('style-error.docx'), map{})
  return
  (
    unit:assert-equals(count($result/errors/error), 3),
    unit:assert(
      starts-with($result/errors/error[1], 'unrecognized character style: BookTitle: ')
    ),
    unit:assert(
      $result/errors/error[2]/text[.='Bad style here']
    )
  )
  
};

(:Schematron validation correctly inserts errors into the report passed in:)
declare %unit:test function sct:schematron-report()
{
  let $manifest := <result>
  <errors systemId="../test/style-error/out/document.xml" haltOnInvalid="false">
    <error location="/Q{{http://schemas.openxmlformats.org/wordprocessingml/2006/main}}document[1]/Q{{http://schemas.openxmlformats.org/wordprocessingml/2006/main}}body[1]/Q{{http://schemas.openxmlformats.org/wordprocessingml/2006/main}}p[1]">unrecognized paragraph style: Normal: <text style="para">Foo</text>
    </error>
    <error location="/Q{{http://schemas.openxmlformats.org/wordprocessingml/2006/main}}document[1]/Q{{http://schemas.openxmlformats.org/wordprocessingml/2006/main}}body[1]/Q{{http://schemas.openxmlformats.org/wordprocessingml/2006/main}}p[2]">unrecognized paragraph style: Normal: <text style="para">Bad style here</text>
    </error>
    <error location="/Q{{http://schemas.openxmlformats.org/wordprocessingml/2006/main}}document[1]/Q{{http://schemas.openxmlformats.org/wordprocessingml/2006/main}}body[1]/Q{{http://schemas.openxmlformats.org/wordprocessingml/2006/main}}p[2]/Q{{http://schemas.openxmlformats.org/wordprocessingml/2006/main}}r[1]">unrecognized character style: BookTitle: <text style="char">Bad style here</text>
    </error>
  </errors>
<error>[info]:Validation completed in 225 ms
</error>
  <code>0</code>
</result>

  return 
  unit:assert-equals(sc:validate-schematron($manifest)/errors/schematron/error
  => count(), 4)
};

(:halt on invalid respected - SCH errors only reported for first file in batch:)
declare %unit:test function sct:schematron-halt-on-invalid()
{
  let $result := sc:check(
    (resolve-uri("no-errors.docx"), resolve-uri("style-error.docx")),
    map{'halt-on-invalid':true(), 'schematron':true()}
  )
  return
  (
    unit:assert-equals(count($result/errors/schematron), 1),
    unit:assert($result/errors[1]/schematron/error)
  )
};