<?php
// GET wyłącznie odczytuje pliki. Token pozostaje w istniejącym env.sh.
header('Content-Type: text/plain; charset=utf-8');
$content = @file_get_contents(__DIR__ . '/env.sh');
$token = null;
if ($content !== false && preg_match('/^TOKEN=[\'\"]?([^\'\"\r\n]+)[\'\"]?/m', $content, $m)) $token = trim($m[1]);
$headers = function_exists('getallheaders') ? getallheaders() : [];
$auth = $headers['Authorization'] ?? $headers['authorization'] ?? ($_SERVER['HTTP_AUTHORIZATION'] ?? '');
if (!$token || !preg_match('/^Bearer\s+(.+)$/', $auth, $m) || !hash_equals($token, $m[1])) { http_response_code(401); exit("Unauthorized\n"); }
function script_path($name) {
 if (!preg_match('/^[A-Za-z0-9_.-]+\.sh$/D', $name) || $name === 'env.sh') return false;
 $path = __DIR__ . '/' . $name;
 return is_file($path) && !is_link($path) ? $path : false;
}
if (!empty($_GET['list'])) {
 foreach (glob(__DIR__ . '/*.sh') as $f) {
  $name = basename($f); if (!script_path($name)) continue;
  echo $name . '|' . hash_file('sha256', $f) . '|' . filesize($f) . '|' . filemtime($f) . "\n";
 }
 exit;
}
if (isset($_GET['file'])) {
 $path = script_path($_GET['file']); if (!$path) { http_response_code(404); exit("Not found\n"); }
 header('Content-Type: application/octet-stream'); header('Content-Length: ' . filesize($path)); readfile($path); exit;
}
echo "OK\n";
