import module namespace sc = "http://www.andrewsales.com/style-check" at "../lib/style-check.xqm";

let $dir := 'C:\projects\CMS\ALS_91\'
let $paths := 
  for $path in file:list($dir)
  let $path := file:resolve-path($path, $dir)
  where file:is-file($path)
  return $path
return sc:check($paths, map{'debug':true(), 'halt-on-invalid':true()})/output
 => parse-xml-fragment()