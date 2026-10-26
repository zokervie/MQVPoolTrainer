$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 "$PSScriptRoot/assemble_full_source.py" @args
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    & python "$PSScriptRoot/assemble_full_source.py" @args
} else {
    Write-Error "Chưa có Python 3 trong PATH. Cài Python rồi chạy lại."
}
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
