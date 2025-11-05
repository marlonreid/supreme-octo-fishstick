$organization = "https://dev.azure.com/your-org"
$projectB = "ProjectB"
$pipelineBId = 123
$pat = "$(SYSTEM_ACCESSTOKEN)"

# Trigger pipeline B
$body = @{
    templateParameters = @{
        param1 = "value1"
    }
} | ConvertTo-Json -Depth 10

$headers = @{
    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
    "Content-Type" = "application/json"
}

$response = Invoke-RestMethod -Uri "$organization/$projectB/_apis/pipelines/$pipelineBId/runs?api-version=7.1-preview.1" -Method Post -Body $body -Headers $headers
$runId = $response.id

Write-Host "Triggered Pipeline B run $runId"

# Poll until completion
do {
    Start-Sleep -Seconds 10
    $status = Invoke-RestMethod -Uri "$organization/$projectB/_apis/pipelines/$pipelineBId/runs/$runId?api-version=7.1-preview.1" -Headers $headers
} while ($status.state -ne "completed")

Write-Host "Pipeline B completed with result: $($status.result)"

# Stream logs for each step
$logsUrl = "$organization/$projectB/_apis/build/builds/$($status.id)/logs?api-version=7.1"
$logs = Invoke-RestMethod -Uri $logsUrl -Headers $headers
foreach ($log in $logs.value) {
    $logContent = Invoke-RestMethod -Uri "$organization/$projectB/_apis/build/builds/$($status.id)/logs/$($log.id)?api-version=7.1" -Headers $headers
    Write-Host $logContent
}

# Fail Pipeline A if B failed
if ($status.result -ne "succeeded") {
    Write-Error "Pipeline B failed! Propagating failure to Pipeline A."
}
