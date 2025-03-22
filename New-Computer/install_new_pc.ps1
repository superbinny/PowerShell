# 以下用于自动化在新机器上安装一些基本软件：
# 设置PowerShell脚本执行策略为Remotesigned
Set-ExecutionPolicy RemoteSigned -Force
# 设置执行策略为允许运行脚本
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force


# 安装Chocolatey包管理器
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))



# 创建桌面快捷方式
$TargetFile = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
$ShortcutFile = "C:\Users\Public\Desktop\Google Chrome.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()
 
# 设置Visual Studio Code快捷方式到桌面
$vscodeDesktopLink = "C:\Users\Public\Desktop\Visual Studio Code.lnk"
$codeExePath = (Get-Command code).Path
$WScriptShell.CreateShortcut($vscodeDesktopLink).TargetPath = $codeExePath
 
# 清理系统和注册表
# 注意：这一步骤可能会根据系统和安全策略有所不同，需要谨慎操作
# 可以添加清理系统垃圾文件、注册表清理等命令


# 函数：下载并安装软件
function InstallSoftware {
    param (
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Url
    )

    $outputPath = "$env:TEMP\$Name-installer.exe"
    Write-Output "正在下载 $Name ..."
    Invoke-WebRequest -Uri $Url -OutFile $outputPath
    Write-Output "正在安装 $Name ..."
    Start-Process -FilePath $outputPath -ArgumentList '/S' -Wait -NoNewWindow
    Write-Output "$Name 已安装。"
    Remove-Item -Path $outputPath -Force
}

# 更新 Windows
function UpdateWindows {
    Write-Output "正在检查并安装 Windows 更新 ..."
    Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -Install -AcceptAll -AutoReboot
}


# 配置网络设置（例如：设置静态 IP）
# 这部分需要根据具体需求进行定制
# Write-Output "正在配置网络设置 ..."
# New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.1.100 -PrefixLength 24 -DefaultGateway 192.168.1.1
# Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 8.8.8.8,8.8.4.4

# 设置系列环境变量
# 重新排列环境变量的路径
function ResortPath()
{
    param (
        [Parameter(Mandatory=$true)][string]$User
    )
    # 得到所有的路径
    # 使用 "User|Machine" 获取用户/系统级别的环境变量
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", $User)
 
    $paths = $currentPath -split ';'
    # 去重
    $uniquePaths = $paths | Select-Object -Unique
    # 根据需要对去重后的路径进行重新排列。例如，按照字母顺序排序：
    $sortedPaths = $uniquePaths | Sort-Object
    # 将重新排列和去重后的路径重新组合成新的环境变量值，并更新环境变量。这里以更新 PATH 为例：
    $newPathValue = $sortedPaths -join ';'
    echo $newPathValue
}

# 加入路径到环境变量中
function AppendPathToEnvironment()
{
    param (
        [Parameter(Mandatory=$true)][string]$pathadd,
        [Parameter(Mandatory=$true)][string]$User
    )
    $sortpath = ResortPath $User
    # 检查路径是否已存在
    if ($sortpath -notlike "*$pathadd*") {
        # 如果路径不存在，则添加到 PATH
        $newPath = $sortpath + ";$pathadd"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, $User)
    } else {
        Write-Host "The path $pathadd already exists in PATH."
    }
}

# 将多个路径添加到环境变量的 Path 中
function AppendMutiPathToEnvironment()
{
    param (
        [Parameter(Mandatory=$true)][string[]]$appendPathVariable,
        [Parameter(Mandatory=$true)][string]$User
    )
     # 设置环境变量
    foreach ($env in $appendPathVariable) {
        AppendPathToEnvironment($env.Value, $User)
    }
}

function SetEnvironmentVariables()
{
    param (
        [Parameter(Mandatory=$true)][string[]]$environmentVariable,
        [Parameter(Mandatory=$true)][string]$User
    )
     # 设置环境变量
    foreach ($env in $environmentVariable) {
        if (-not (Test-Path "Env:$env.Name")) {
            # 使用 "User|Machine" 设置用户/系统级别的环境变量
            [System.Environment]::SetEnvironmentVariable($env.Name, $env.Value, $User)
        }
    }
}

function InstallSSH()
{
    # 为SSH服务器安装OpenSSH Server
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    # 为SSH客户端安装OpenSSH 客户端
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
    # 启动SSH服务
    Start-Service sshd
    
    # 停止SSH服务
    Stop-Service sshd
    # 允许SSH通信
    New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}

# 设置休眠状态
function SetPowerManagement()
{
    # 设置笔记本的休眠为盖上盖子不休眠
    powercfg -setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
    powercfg -setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
    powercfg -setactive SCHEME_CURRENT
    # https://www.cnblogs.com/suv789/p/18033972 (powershell 电源管理命令)
    # powershell安装PowerManagement
    # 安装 NuGet 提供程序
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name PowerManagement
    # 禁用系统的休眠模式
    powercfg /hibernate off
    # 以上模块无法用，所以用这个 https://devblogs.microsoft.com/scripting/get-windows-power-plan-settings-on-your-computer-by-using-powershell/
    $guid=(Get-WmiObject -Class win32_powerplan -Namespace root\cimv2\power -Filter "IsActive=true").InstanceID.tostring()
    $start_index=$guid.IndexOf("{")
    $end_index=$guid.IndexOf("}")
    $length=$end_index-$start_index-1
    $power_guid=$guid.Substring($start_index+1,$length)
    echo $power_guid
    1bef50e5-557d-4b3b-9b29-cdde74fcfd30

    Get-WmiObject -Class win32_powerplan -Namespace root\cimv2\power -Filter "IsActive=true"
}

# 修改用户名
# 参考：https://blog.csdn.net/zhangfuping123456789/article/details/141964663
# 原作是修改：HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Profilelist
# 但是在 Windows11 上，位置为：HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList


function ClearTempDirs()
{
    # 清理和最终配置
    Write-Output "清理临时文件 ..."
    Remove-Item -Path "$env:TEMP*.*" -Force -Recurse
    Write-Output "脚本执行完毕。请重启计算机以确保所有更改生效。"
}

function install_zsh()
{
    Remove-Item $env:POSH_PATH -Force -Recurse
    Uninstall-Module oh-my-posh -AllVersions
    winget install JanDeDobbeleer.OhMyPosh -s winget
    # 升级 OhMyPosh
    winget upgrade JanDeDobbeleer.OhMyPosh -s winget
    Install-Module posh-git -Scope CurrentUser -Force
}

# 安装服务器管理器
# https://techcommunity.microsoft.com/discussions/windows11/how-to-install-or-uninstall-rsat-in-windows-11/3273590
# How to Install or Uninstall RSAT in Windows 11
Get-WindowsCapability -Name RSAT* -Online | Select-Object -Property DisplayName, Name, State
<# 
DisplayName                                     Name                                                          State
-----------                                     ----                                                          -----
RSAT: Active Directory 域服务和轻型目录服务工具 Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0             NotPresent
RSAT: PowerShell module for Azure Stack HCI     Rsat.AzureStack.HCI.Management.Tools~~~~0.0.1.0          NotPresent
RSAT: BitLocker 驱动器加密管理实用程序          Rsat.BitLocker.Recovery.Tools~~~~0.0.1.0                 NotPresent
RSAT: Active Directory 证书服务工具             Rsat.CertificateServices.Tools~~~~0.0.1.0                NotPresent
RSAT: DHCP 服务器工具                           Rsat.DHCP.Tools~~~~0.0.1.0                               NotPresent
RSAT: DNS 服务器工具                            Rsat.Dns.Tools~~~~0.0.1.0                                NotPresent
RSAT: 故障转移群集工具                          Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0         NotPresent
RSAT: 文件服务工具                              Rsat.FileServices.Tools~~~~0.0.1.0                       NotPresent
RSAT: 组策略管理工具                            Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0             NotPresent
RSAT: IP 地址管理(IPAM)客户端                   Rsat.IPAM.Client.Tools~~~~0.0.1.0                        NotPresent
RSAT: 数据中心桥接 LLDP 工具                    Rsat.LLDP.Tools~~~~0.0.1.0                               NotPresent
RSAT: 网络控制器管理工具                        Rsat.NetworkController.Tools~~~~0.0.1.0                  NotPresent
RSAT: 网络负载平衡工具                          Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0               NotPresent
RSAT: 远程访问管理工具                          Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0            NotPresent
RSAT: 远程桌面服务工具                          Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0             NotPresent
RSAT: 服务器管理器                              Rsat.ServerManager.Tools~~~~0.0.1.0                      NotPresent
RSAT: 存储迁移服务管理工具                      Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0 NotPresent
RSAT: Windows PowerShell 的存储副本模块         Rsat.StorageReplica.Tools~~~~0.0.1.0                     NotPresent
RSAT: Windows PowerShell 系统见解模块           Rsat.SystemInsights.Management.Tools~~~~0.0.1.0          NotPresent
RSAT: 批量激活工具                              Rsat.VolumeActivation.Tools~~~~0.0.1.0                   NotPresent
RSAT: Windows Server Update Services 工具       Rsat.WSUS.Tools~~~~0.0.1.0                               NotPresent
#>
Add-WindowsCapability -Online -Name Rsat.ServerManager.Tools

UpdateWindows

# 使用Chocolatey安装常用软件包
choco install -y googlechrome firefox calibre ffmpeg 7zip.install vlc kate git.install foxitreader vscode thunderbird

# 安装qt6：
choco install -y qt6-base-dev cmake qtcreator

# 安装软件
# 定义要安装的软件
$softwareToInstall = @(
    @{ Name = 'Google Chrome'; Url = 'https://dl.google.com/dl/edge/dl/latest/msedgeredist.exe' },
    @{ Name = 'Notepad++'; Url = 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.1.9/npp.8.1.9.Installer.exe' }
    # 添加更多软件及其下载链接
)

foreach ($software in $softwareToInstall) {
    InstallSoftware -Name $software.Name -Url $software.Url
}

# 配置系统设置（例如：禁用 OneDrive）
Write-Output "正在禁用 OneDrive ..."
if ((Get-WmiObject -Class Win32_Processor).NumberOfCores -gt 1) {
    $oneDriveProcess = Get-Process | Where-Object { $_.ProcessName -eq "OneDrive" }
    if ($oneDriveProcess) {
        Stop-Process -Id $oneDriveProcess.Id -Force
    }
    New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -Value "" -Force
}

# 参考：https://hahndorf.eu/blog/WindowsFeatureViaCmd.html（Different ways for installing Windows features on the command line）
install_zsh


$OneDrivePath = $env:OneDrive
$environmentVariable = @(
    @{ Name = 'CRACK_TOOLS'; Value = 'D:\Crack' },
    @{ Name = 'LATEX_DOC_PATH'; Value = '$OneDrivePath\Program\latex\DOC' }
    @{ Name = 'OUTPUT_PATH'; Value = 'D:\Develop' }
    @{ Name = 'NODE_PATH'; Value = 'D:\Linux\node' }
    # 来自 https://github.com/superbinny/BinnyWorkGit
    @{ Name = 'PYTHONPATH'; Value = 'D:\Source\BinnyWorkGit\PythonTools' }
    # 添加更多环境变量
)

$appendPathVariable = @(
    @{ Name = 'VcPkg'; Value = 'D:\Linux\vcpkg' },
    @{ Name = 'AdobePhotoshop'; Value = 'C:\Program Files\Adobe\Adobe Photoshop 2024' }
    @{ Name = 'Node.js.Global'; Value = '%NODE_PATH%\node_global' }
    # 重新安装 texlive 以后
    @{ Name = 'TexLive'; Value = 'D:\Linux\texlive\2024\bin\windows' }
    @{ Name = 'anaconda3Scripts'; Value = 'D:\Linux\anaconda3\Scripts' }
    @{ Name = 'anaconda3Bin'; Value = 'D:\Linux\anaconda3\condabin' }
   # 添加更多环境变量
)

SetEnvironmentVariables $environmentVariable "User"
AppendMutiPathToEnvironment $appendPathVariable "User"

# choco常用软件安装
#python解释器
choco install -y python3
#jdk8
choco install -y jdk8
#或 jdk11
choco install -y jdk11
#Windows终端
choco install -y cmder
#Windows管理员提权工具
choco install -y gsudo 
#命令行下载工具
choco install -y curl wget axel
#开源下载工具
choco install -y motrix
#笔记工具
choco install -y typora
#ssh工具
choco install -y openssh ssh-copy-id rsync
#网络工具
choco install -y telnet netcat
#内网穿透
choco install -y zerotier-one
#命令行目录查看工具
choco install -y which
#多媒体
choco install -y potplayer
# 安装7zip压缩工具
choco install -y 7zip
# 安装增强剪切板
choco install -y ditto

#ntop资源查看器和grep便于管道符过滤命令行结果
choco install -y ntop.portable grep

#pandoc文档格式转换工具
choco install -y pandoc

# 移动测试工具类
choco install -y adb
# 安装apktool,会自动安装依赖包jre.
choco install -y apkool

# 开发常用
choco install -y copyq
choco install -y launchy
choco install -y golang

# choco install -y clink # Not maintained anymore, use the below one
choco install -y clink-maintained
choco install -y vscode
choco install -y motrix
choco install -y git
choco install -y TortoiseGit
choco install -y qdir
choco install -y winscp

# nodejs在choco安装貌似不会安装缺省编译环境，可能还是单独下载包安装更好。另外，如果要安装多个nodejs版本，还是使用nvm安装比较好

choco install -y nodejs

# 程序比较大，下载比较慢
choco install -y tabby

# 偶尔失败
choco install -y LinkShellExtension
choco install -y GoogleChrome

#下面的不成功
choco install -y nutstore

# nodejs网上下载的安装包会安装Python，所以可能anaconda不一定需要，另外商用环境使用anaconda3需要收费
choco install -y anaconda3

# 如果没有使用anaconda3时，安装cookiecutter
pip install cookiecutter

# 运维常用
choco install -y grype
choco install -y pod-desktop

# 开发可选
choco install -y pyenv-win

# choco清理工具
# 安装清理工具
choco install -y choco-cleaner
#执行清理
choco-cleaner