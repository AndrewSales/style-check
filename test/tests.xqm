(:~ Unit tests for the style checking module. :)

module namespace sct = "http://www.andrewsales.com/style-check-tests";

import module namespace sc = "http://www.andrewsales.com/style-check" at "../lib/style-check.xqm";

(:static test cases:)
declare variable $sct:goodDOCX := resolve-uri("proper.docx", static-base-uri());
declare variable $sct:badDOCX := resolve-uri("bad.docx", static-base-uri());
declare variable $sct:filenameWithSpaces := resolve-uri('filename%20with%20spaces.docx');

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
  let $manifest := sc:build-manifest($sct:goodDOCX)
  
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
  let $manifest := sc:build-manifest($sct:goodDOCX) => sc:simplify-styles()
  
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

declare %unit:test function sct:validator-jar()
{
  unit:assert-equals(
    proc:execute(
      'java',
     ('-jar', resolve-uri("../etc/validator.jar")=>substring-after('file:///'))
   )/code,
   <code>0</code>	(:ran successfully:)
  )
};

declare %unit:test function sct:validate-no-errors()
{
  let $result := sc:validate(<files><file>{resolve-uri('no-errors/document.xml')}</file></files>, map{})/output
  
  return
  unit:assert-equals(parse-xml($result)/errors/*,())
};

declare %unit:test function sct:validate-errors()
{
  let $result := sc:validate(<files><file dest='{resolve-uri("style-error/document.xml")}'></file></files>, map{})/output
  => parse-xml()
  return
  unit:assert-equals($result/errors/error => count(), 2)
};

declare %unit:test function sct:validate-multiple()
{
  let $result := sc:validate(
    <files>
    <file dest='{resolve-uri("style-error/document.xml")}'></file>
    <file dest='{resolve-uri("no-errors/document.xml")}'></file>
    </files>, 
    map{})/output
    =>parse-xml-fragment()
    
  return
  unit:assert-equals($result/errors => count(), 2)
};

declare %unit:test function sct:check()
{
  let $result := sc:check(resolve-uri("style-error.docx"), map{})/output
  => parse-xml()
  
  return
  unit:assert-equals($result/errors/error => count(), 2)
};

declare %unit:test function sct:run-validator()
{
  let $result := proc:execute(
    'java',
    (
      '-jar', resolve-uri('../etc/validator.jar')=>substring-after('file:///')
    )
  )
  
  return unit:assert(
    $result/error[../code = '0']
  )
};

declare %unit:test function sct:style-dtd-present()
{
  unit:assert(file:exists(resolve-uri('../dtd/style-schema.dtd', static-base-uri())))
};

declare %unit:test function sct:filename-with-spaces()
{
  let $result := sc:check($sct:filenameWithSpaces, map{})/output
  => parse-xml()
  return
  unit:assert($result/*/self::errors)	(:we got an error report:)
};