using Microsoft.AspNetCore.HttpOverrides;

var app = builder.Build();

app.Logger.LogInformation("=== BEFORE UseForwardedHeaders ===");
app.Use(async (ctx, next) =>
{
    app.Logger.LogInformation("BEFORE: Request.Scheme={scheme}, Request.Host={host}, HostHeader={hostHeader}, X-Forwarded-Proto={xfp}, X-Forwarded-Host={xfh}, Forwarded={fwd}",
        ctx.Request.Scheme,
        ctx.Request.Host,
        ctx.Request.Headers["Host"].ToString(),
        ctx.Request.Headers["X-Forwarded-Proto"].ToString(),
        ctx.Request.Headers["X-Forwarded-Host"].ToString(),
        ctx.Request.Headers["Forwarded"].ToString());
    await next();
});

// configure forwarded headers (include host and forwarded if necessary)
var forwardedOptions = new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost
};
forwardedOptions.KnownNetworks.Clear();
forwardedOptions.KnownProxies.Clear();

app.UseForwardedHeaders(forwardedOptions);

app.Logger.LogInformation("=== AFTER UseForwardedHeaders ===");
app.Use(async (ctx, next) =>
{
    app.Logger.LogInformation("AFTER: Request.Scheme={scheme}, Request.Host={host}, HostHeader={hostHeader}, X-Forwarded-Proto={xfp}, X-Forwarded-Host={xfh}, Forwarded={fwd}",
        ctx.Request.Scheme,
        ctx.Request.Host,
        ctx.Request.Headers["Host"].ToString(),
        ctx.Request.Headers["X-Forwarded-Proto"].ToString(),
        ctx.Request.Headers["X-Forwarded-Host"].ToString(),
        ctx.Request.Headers["Forwarded"].ToString());
    await next();
});
