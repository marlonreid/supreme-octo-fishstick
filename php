<?php
session_start();

// --- 1. CONFIGURATION ---
$keycloak_url  = "https://<your-keycloak-domain>/realms/<your-realm>";
$client_id     = "<your-client-id>";
$client_secret = "<your-client-secret>"; // <-- NEW: Required for token exchange too
$redirect_uri  = "http://localhost:8000/callback.php";
// ------------------------

// 2. Verify we have the required data
if (isset($_GET['error'])) {
    die("Auth Error from Keycloak: " . htmlspecialchars($_GET['error_description']));
}

if (!isset($_GET['code']) || !isset($_SESSION['code_verifier'])) {
    die("Missing authorization code or PKCE verifier. Did you start at login.php?");
}

$code = $_GET['code'];
$verifier = $_SESSION['code_verifier'];

// 3. The Token Request (Server-to-Server Exchange)
$token_endpoint = $keycloak_url . "/protocol/openid-connect/token";

$post_data = http_build_query([
    'grant_type'    => 'authorization_code',
    'client_id'     => $client_id,
    'client_secret' => $client_secret, // Authenticates the Client again
    'redirect_uri'  => $redirect_uri,
    'code'          => $code,
    'code_verifier' => $verifier
]);

$ch = curl_init($token_endpoint);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $post_data);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
// NOTE: Set to false ONLY for local Windows testing
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($http_code !== 200) {
    die("Token Exchange Failed. HTTP $http_code. Response: $response");
}

$token_data = json_decode($response, true);
unset($_SESSION['code_verifier']); // Security cleanup

// 4. Decode the Tokens to show the claims
$access_token_claims = decode_jwt($token_data['access_token'] ?? '');
$id_token_claims = decode_jwt($token_data['id_token'] ?? '');

?>
<!DOCTYPE html>
<html>
<head>
    <title>PHP OAuth Success (Confidential)</title>
    <style>
        body { font-family: sans-serif; margin: 40px; background: #f9f9f9; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        pre { background: #222; color: #0f0; padding: 15px; border-radius: 5px; overflow-x: auto; }
        h3 { border-bottom: 2px solid #eee; padding-bottom: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1 style="color: green;">✅ Confidential Login Successful</h1>
        <p>Logged in as: <strong><?php echo htmlspecialchars($id_token_claims['preferred_username'] ?? 'Unknown User'); ?></strong></p>
        
        <h3>ID Token Claims (Who is the user?)</h3>
        <pre><?php echo json_encode($id_token_claims, JSON_PRETTY_PRINT); ?></pre>

        <h3>Access Token Claims (What can they do?)</h3>
        <pre><?php echo json_encode($access_token_claims, JSON_PRETTY_PRINT); ?></pre>
    </div>
</body>
</html>

<?php
// --- HELPER FUNCTION: Read JWT without verifying signature ---
// Remind them: In production, they should verify the JWT signature using Keycloak's public keys!
function decode_jwt($jwt) {
    if (empty($jwt)) return ['error' => 'No token'];
    
    $parts = explode('.', $jwt);
    if (count($parts) !== 3) return ['error' => 'Invalid JWT format'];
    
    $payload = str_replace(['-', '_'], ['+', '/'], $parts[1]);
    
    $rem = strlen($payload) % 4;
    if ($rem) {
        $payload .= str_repeat('=', 4 - $rem);
    }
    
    return json_decode(base64_decode($payload), true);
}
?>
