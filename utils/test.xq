import module namespace sc = "http://www.andrewsales.com/style-check" at "../lib/style-check.xqm";

let $dir := 'c:\users\user\downloads\als\'
for $path in file:list($dir)
let $path := file:resolve-path($path, $dir)
where file:is-file($path)
return sc:check($path)