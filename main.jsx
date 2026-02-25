import React from "react";
import ReactDOM from "react-dom/client";
import { AuthProvider } from "react-oidc-context";
import App from "./App";

const oidcConfig = {
  authority: "https://<your-keycloak-domain>/realms/<your-realm>",
  client_id: "<your-client-id>",
  redirect_uri: "http://localhost:5173/callback",
  response_type: "code",
  scope: "openid profile email",
  
  // 🚀 THE MAGIC FLAG: This tells the library to use PAR for Phase A
  usePushedAuthorizationRequests: true,

  // Cleans up the messy ?code=... from the URL after login
  onSigninCallback: () => {
    window.history.replaceState({}, document.title, window.location.pathname);
  },
};

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <AuthProvider {...oidcConfig}>
      <App />
    </AuthProvider>
  </React.StrictMode>
);
