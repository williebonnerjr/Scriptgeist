Get-ChildItem -Recurse -Path \\Modules\*.ps1 | ForEach-Object { . \.FullName }
