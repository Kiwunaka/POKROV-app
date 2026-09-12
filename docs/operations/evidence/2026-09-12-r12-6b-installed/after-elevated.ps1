$ErrorActionPreference='Stop'
& C:/Users/Public/R126b20260912/canary-state.ps1 after | Out-File -LiteralPath C:/Users/Public/R126b20260912/state-after-capture.json -Encoding utf8
& C:/Users/Public/R126b20260912/scan-sinks.ps1 | Out-File -LiteralPath C:/Users/Public/R126b20260912/scan-after.json -Encoding utf8
