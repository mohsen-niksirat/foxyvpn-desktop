<?php
// API relay for the VPN client, as one PHP file (PHP 7.3 or later, with
// the curl extension, on any host that serves HTTPS).
//
// When Mozilla's sign-in, Guardian, or server list cannot be reached from
// your network, the client can send those requests (never the VPN traffic)
// through this relay: upload the file, then set its URL in Settings >
// Advanced > "Relay for Mozilla's services", for example
// https://example.com/relay.php?key=SECRET
//
// The client asks for relay.php?url=<target>; the relay sends the same
// method, headers, and body to the target and answers with its response.
// Only the hosts below are relayed, so the relay is not an open proxy for
// others.

// A secret only your client knows; the relay URL then ends in ?key=SECRET.
// Leave empty for no key (anyone who finds the URL could use your relay,
// for these hosts only).
$KEY = '';

$ALLOWED = [
    'mozilla.org', 'mozilla.com', 'firefox.com', // accounts, Guardian, server list
    'github.com', 'githubusercontent.com', 'jsdelivr.net', // geo files, flags
];

// Headers that describe this hop, not the request or the response.
$HOP = ['host', 'connection', 'keep-alive', 'content-length', 'transfer-encoding', 'accept-encoding',
    'x-forwarded-for', 'x-forwarded-proto', 'x-forwarded-host', 'x-real-ip', 'upgrade', 'te', 'trailer'];

function fail($status, $why)
{
    http_response_code($status);
    header('X-Relay-Error: ' . $why);
    header('Content-Type: text/plain');
    echo $why;
    exit;
}

function ends_with($text, $suffix)
{
    return substr($text, -strlen($suffix)) === $suffix;
}

if ($KEY !== '' && !hash_equals($KEY, (string)($_GET['key'] ?? ''))) {
    fail(403, 'wrong key');
}
$target = (string)($_GET['url'] ?? '');
$parts = parse_url($target);
if (!$parts || ($parts['scheme'] ?? '') !== 'https' || empty($parts['host'])) {
    fail(400, 'url must be an https URL');
}
$host = strtolower($parts['host']);
$allowed = false;
foreach ($ALLOWED as $domain) {
    if ($host === $domain || ends_with($host, '.' . $domain)) {
        $allowed = true;
    }
}
if (!$allowed) {
    fail(403, 'host not allowed: ' . $host);
}

$headers = [];
foreach (getallheaders() as $name => $value) {
    $lower = strtolower($name);
    if (in_array($lower, $HOP, true) || strpos($lower, 'cf-') === 0) {
        continue;
    }
    $headers[] = $name . ': ' . $value;
}

$method = $_SERVER['REQUEST_METHOD'];
$ch = curl_init($target);
curl_setopt_array($ch, [
    CURLOPT_CUSTOMREQUEST => $method,
    CURLOPT_HTTPHEADER => $headers,
    // Redirects go back to the client, which follows them through the relay.
    CURLOPT_FOLLOWLOCATION => false,
    CURLOPT_CONNECTTIMEOUT => 20,
    CURLOPT_TIMEOUT => 600,
    // The response's status and headers, as they arrive (a 100 Continue
    // comes first sometimes).
    CURLOPT_HEADERFUNCTION => function ($ch, $line) use ($HOP) {
        $trimmed = trim($line);
        if (preg_match('#^HTTP/\S+\s+(\d{3})#', $trimmed, $m)) {
            http_response_code((int)$m[1]);
        } elseif ($trimmed !== '' && strpos($trimmed, ':') !== false) {
            $name = strtolower(trim(strstr($trimmed, ':', true)));
            if (!in_array($name, $HOP, true)) {
                header($trimmed, false);
            }
        }
        return strlen($line);
    },
    // The body is passed on as it arrives, so large files need no memory.
    CURLOPT_WRITEFUNCTION => function ($ch, $data) {
        echo $data;
        flush();
        return strlen($data);
    },
]);
if ($method !== 'GET' && $method !== 'HEAD') {
    curl_setopt($ch, CURLOPT_POSTFIELDS, file_get_contents('php://input'));
}
if ($method === 'HEAD') {
    curl_setopt($ch, CURLOPT_NOBODY, true);
}
if (curl_exec($ch) === false && !headers_sent()) {
    fail(502, 'the target did not answer: ' . curl_error($ch));
}
curl_close($ch);
