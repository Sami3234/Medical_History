param(
  [ValidateSet('debug', 'release')]
  [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $projectRoot 'admin_panel\.env.local'

if (-not (Test-Path -LiteralPath $envPath)) {
  throw 'Missing admin_panel/.env.local with Supabase configuration.'
}

$values = @{}
Get-Content -LiteralPath $envPath | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
    $values[$matches[1].Trim()] = $matches[2].Trim().Trim('"').Trim("'")
  }
}

$supabaseUrl = $values['NEXT_PUBLIC_SUPABASE_URL']
$supabaseAnonKey = $values['NEXT_PUBLIC_SUPABASE_ANON_KEY']
$tempShareUrl = $values['TEMP_SHARE_API_URL']
if ([string]::IsNullOrWhiteSpace($tempShareUrl)) {
  $tempShareUrl = 'https://medical-history-temporary-share.kk34samikhan.workers.dev'
}

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or
    [string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
  throw 'Supabase URL or publishable anon key is missing from admin_panel/.env.local.'
}

Push-Location $projectRoot
try {
  flutter build apk `
    --$Mode `
    --target-platform android-arm64 `
    "--dart-define=SUPABASE_URL=$supabaseUrl" `
    "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey" `
    "--dart-define=TEMP_SHARE_API_URL=$tempShareUrl"
} finally {
  Pop-Location
}
