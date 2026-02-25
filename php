<?php
session_start();

// --- CONFIGURATION ---
$keycloak_url = "https://<your-keycloak-domain>/realms/<your-realm>";
$client_id = "<your-client-id>";
$redirect_uri = "http://localhost:8000/callback.php";
// ---------------------

if (isset($_GET['error'])) {
    die("Auth Error: " . htmlspecialchars($_GET['error_description']));
}

if (!isset($_GET['code']) || !isset($_SESSION['code_verifier'])) {
    die("Missing authorization code or PKCE verifier. Did you start at login.php?");
}

$code = $_GET['code'];
$verifier = $_SESSION['code_verifier'];
$token_endpoint = $keycloak_url . "/protocol/openid-connect/token";

$post_data = http_build_query([
    'grant_type' => 'authorization_code',
    'client_id' => $client_id,
    'redirect_uri' => $redirect_uri,
    'code' => $code,
    'code_verifier' => $verifier
]);

$ch = curl_init($token_endpoint);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $post_data);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
// Bypass SSL verification for local Windows testing
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($http_code !== 200) {
    die("Token Exchange Failed. HTTP $http_code. Response: $response");
}

$token_data = json_decode($response, true);
unset($_SESSION['code_verifier']); // Clean up

// --- DECODE THE TOKENS ---
$access_token_claims = decode_jwt($token_data['access_token'] ?? '');
$id_token_claims = decode_jwt($token_data['id_token'] ?? '');

?>
<!DOCTYPE html>
<html>
<head>
    <title>PHP OAuth Success</title>
    <style>
        body { font-family: sans-serif; margin: 40px; background: #f9f9f9; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        pre { background: #222; color: #0f0; padding: 15px; border-radius: 5px; overflow-x: auto; }
        h3 { border-bottom: 2px solid #eee; padding-bottom: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1 style="color: green;">✅ Success! Identity Confirmed</h1>
        <p>Welcome, <strong><?php echo htmlspecialchars($id_token_claims['preferred_username'] ?? 'User'); ?></strong>!</p>
        
        <h3>1. ID Token Claims (User Profile)</h3>
        <p><em>This is the OIDC token that tells the app who logged in.</em></p>
        <pre><?php echo json_encode($id_token_claims, JSON_PRETTY_PRINT); ?></pre>

        <h3>2. Access Token Claims (API Permissions)</h3>
        <p><em>This is the token the PHP app would send to your backend API in the Authorization header.</em></p>
        <pre><?php echo json_encode($access_token_claims, JSON_PRETTY_PRINT); ?></pre>
    </div>
</body>
</html>

<?php
// --- HELPER FUNCTION ---
function decode_jwt($jwt) {
    if (empty($jwt)) return ['error' => 'No token provided'];
    
    $parts = explode('.', $jwt);
    if (count($parts) !== 3) return ['error' => 'Invalid JWT format'];
    
    $payload = $parts[1];
    
    // JWTs use Base64Url encoding. PHP's base64_decode expects standard Base64.
    // We must replace the URL-safe characters back to standard Base64 characters.
    $payload = str_replace(['-', '_'], ['+', '/'], $payload);
    
    // Pad the string with '=' to make its length a multiple of 4
    $rem = strlen($payload) % 4;
    if ($rem) {
        $payload .= str_repeat('=', 4 - $rem);
    }
    
    return json_decode(base64_decode($payload), true);
}
?>
