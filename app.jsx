import React from "react";
import { useAuth } from "react-oidc-context";

function App() {
  const auth = useAuth();
  
  // Detect if we are currently landing on the callback route
  const isCallbackRoute = window.location.pathname === "/callback";

  // 1. Loading State (During redirect or token exchange)
  if (auth.isLoading || auth.activeNavigator === "signinRedirect" || isCallbackRoute) {
    return (
      <div style={{ marginTop: "100px", textAlign: "center", fontFamily: "sans-serif" }}>
        <h2>🔄 Processing Secure Login...</h2>
        <p>Exchanging code for tokens...</p>
      </div>
    );
  }

  // 2. Error State (Misconfigured Keycloak, CORS, etc.)
  if (auth.error) {
    return (
      <div style={{ marginTop: "50px", textAlign: "center", color: "red", fontFamily: "sans-serif" }}>
        <h2>❌ Authentication Error</h2>
        <p>{auth.error.message}</p>
        <p><em>Tip: Check your Keycloak CORS (Web Origins) and Valid Redirect URIs!</em></p>
        <button onClick={() => window.location.replace("/")}>Try Again</button>
      </div>
    );
  }

  // 3. Authenticated State (Success)
  if (auth.isAuthenticated) {
    return (
      <div style={{ padding: "40px", fontFamily: "sans-serif", maxWidth: "800px", margin: "0 auto" }}>
        <h1 style={{ color: "green" }}>✅ PAR + PKCE Successful</h1>
        <p>Welcome, <strong>{auth.user?.profile?.preferred_username || "User"}</strong>!</p>
        
        <button
          onClick={() => auth.removeUser()}
          style={{ padding: "10px 20px", background: "#ff4444", color: "white", border: "none", borderRadius: "5px", cursor: "pointer" }}
        >
          Log Out (Clear Local State)
        </button>

        <h3 style={{ marginTop: "30px" }}>Your Decoded ID Token Payload:</h3>
        <pre style={{ background: "#222", color: "#0f0", padding: "20px", borderRadius: "8px", overflowX: "auto" }}>
          {JSON.stringify(auth.user?.profile, null, 2)}
        </pre>
      </div>
    );
  }

  // 4. Unauthenticated State (Start Screen)
  return (
    <div style={{ textAlign: "center", marginTop: "100px", fontFamily: "sans-serif" }}>
      <h1>OAuth 2.0 Security Test</h1>
      <p>Using: <strong>Authorization Code Flow + PKCE + PAR</strong></p>
      
      <button
        onClick={() => auth.signinRedirect()}
        style={{ padding: "15px 30px", fontSize: "18px", background: "#007bff", color: "white", border: "none", borderRadius: "5px", cursor: "pointer", marginTop: "20px" }}
      >
        Start Secure Login
      </button>
    </div>
  );
}

export default App;
