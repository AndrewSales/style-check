import module namespace sc = "http://www.andrewsales.com/style-check" at "../lib/style-check.xqm";

let $dir := 'c:\users\user\downloads\als\'
for $path in file:list($dir)
(: return sc:check($path) :)
return sc:check(file:resolve-path($path, $dir))