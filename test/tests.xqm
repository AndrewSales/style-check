(:~ Unit tests for the style checking module. :)

module namespace sct = "http://www.andrewsales.com/style-check-tests";

import module namespace sc = "http://www.andrewsales.com/style-check" at "../lib/style-check.xqm";

(:static test cases:)
declare variable $sct:goodDOCX := resolve-uri("proper.docx", static-base-uri());
declare variable $sct:badDOCX := resolve-uri("bad.docx", static-base-uri());

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
@dest paths to the output :)
declare %unit:test function sct:simplify-styles()
{
  let $manifest := sc:build-manifest($sct:goodDOCX) => sc:simplify-styles()
  
  return
  (
    unit:assert(
      $manifest/file/@dest => ends-with('/test/proper/out/document.xml')
    ),
    unit:assert(
      $manifest/file/@src eq "word/document.xml"
    ),
    unit:assert(
      $manifest/file/@xml:base => ends-with('/test/proper/')
    )
  )
};