Import-LocalizedData LocalizedData -filename PSGet.Resource.psd1

#########################################################################################
#
# Copyright (c) Microsoft Corporation. All rights reserved.
#
# PowerShellGet Module
#
#########################################################################################

Microsoft.PowerShell.Core\Set-StrictMode -Version Latest

#region script variables

$script:IsInbox = $PSHOME.EndsWith('\WindowsPowerShell\v1.0', [System.StringComparison]::OrdinalIgnoreCase)
$script:IsWindows = (-not (Get-Variable -Name IsWindows -ErrorAction Ignore)) -or $IsWindows
$script:IsLinux = (Get-Variable -Name IsLinux -ErrorAction Ignore) -and $IsLinux
$script:IsMacOS = (Get-Variable -Name IsMacOS -ErrorAction Ignore) -and $IsMacOS
$script:IsCoreCLR = $PSVersionTable.ContainsKey('PSEdition') -and $PSVersionTable.PSEdition -eq 'Core'
$script:IsNanoServer = & {
    if (!$script:IsWindows) {
        return $false
    }

    $serverLevelsPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Server\ServerLevels\'
    if (Test-Path -Path $serverLevelsPath) {
        $NanoItem = Get-ItemProperty -Name NanoServer -Path $serverLevelsPath -ErrorAction Ignore
        if ($NanoItem -and ($NanoItem.NanoServer -eq 1)) {
            return $true
        }
    }
    return $false
}

if ($script:IsInbox) {
    $script:ProgramFilesPSPath = Microsoft.PowerShell.Management\Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell"
}
elseif ($script:IsCoreCLR) {
    if ($script:IsWindows) {
        $script:ProgramFilesPSPath = Microsoft.PowerShell.Management\Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell'
    }
    else {
        $script:ProgramFilesPSPath = Microsoft.PowerShell.Management\Split-Path -Path ([System.Management.Automation.Platform]::SelectProductNameForDirectory('SHARED_MODULES')) -Parent
    }
}

try {
    $script:MyDocumentsFolderPath = [Environment]::GetFolderPath("MyDocuments")
}
catch {
    $script:MyDocumentsFolderPath = $null
}

if ($script:IsInbox) {
    $script:MyDocumentsPSPath = if ($script:MyDocumentsFolderPath) {
        Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsFolderPath -ChildPath "WindowsPowerShell"
    }
    else {
        Microsoft.PowerShell.Management\Join-Path -Path $env:USERPROFILE -ChildPath "Documents\WindowsPowerShell"
    }
}
elseif ($script:IsCoreCLR) {
    if ($script:IsWindows) {
        $script:MyDocumentsPSPath = if ($script:MyDocumentsFolderPath) {
            Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsFolderPath -ChildPath 'PowerShell'
        }
        else {
            Microsoft.PowerShell.Management\Join-Path -Path $HOME -ChildPath "Documents\PowerShell"
        }
    }
    else {
        $script:MyDocumentsPSPath = Microsoft.PowerShell.Management\Split-Path -Path ([System.Management.Automation.Platform]::SelectProductNameForDirectory('USER_MODULES')) -Parent
    }
}

$script:ProgramFilesModulesPath = Microsoft.PowerShell.Management\Join-Path -Path $script:ProgramFilesPSPath -ChildPath 'Modules'
$script:MyDocumentsModulesPath = Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsPSPath -ChildPath 'Modules'

$script:ProgramFilesScriptsPath = Microsoft.PowerShell.Management\Join-Path -Path $script:ProgramFilesPSPath -ChildPath 'Scripts'
$script:MyDocumentsScriptsPath = Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsPSPath -ChildPath 'Scripts'

$script:PSGetPath = [pscustomobject]@{
    AllUsersModules    = $script:ProgramFilesModulesPath
    AllUsersScripts    = $script:ProgramFilesScriptsPath
    CurrentUserModules = $script:MyDocumentsModulesPath
    CurrentUserScripts = $script:MyDocumentsScriptsPath
    PSTypeName         = 'Microsoft.PowerShell.Commands.PSGetPath'
}

$script:TempPath = [System.IO.Path]::GetTempPath()
$script:PSGetItemInfoFileName = "PSGetModuleInfo.xml"

if ($script:IsWindows) {
    $script:PSGetProgramDataPath = Microsoft.PowerShell.Management\Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
    $script:PSGetAppLocalPath = Microsoft.PowerShell.Management\Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
}
else {
    $script:PSGetProgramDataPath = Microsoft.PowerShell.Management\Join-Path -Path ([System.Management.Automation.Platform]::SelectProductNameForDirectory('CONFIG')) -ChildPath 'PowerShellGet'
    $script:PSGetAppLocalPath = Microsoft.PowerShell.Management\Join-Path -Path ([System.Management.Automation.Platform]::SelectProductNameForDirectory('CACHE')) -ChildPath 'PowerShellGet'
}

$script:PSGetModuleSourcesFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:PSGetAppLocalPath -ChildPath "PSRepositories.xml"
$script:PSGetModuleSources = $null
$script:PSGetInstalledModules = $null
$script:PSGetSettingsFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:PSGetAppLocalPath -ChildPath "PowerShellGetSettings.xml"
$script:PSGetSettings = $null

$script:MyDocumentsInstalledScriptInfosPath = Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsScriptsPath -ChildPath 'InstalledScriptInfos'
$script:ProgramFilesInstalledScriptInfosPath = Microsoft.PowerShell.Management\Join-Path -Path $script:ProgramFilesScriptsPath -ChildPath 'InstalledScriptInfos'

$script:IsRunningAsElevated = $true
$script:IsRunningAsElevatedTested = $false

$script:InstalledScriptInfoFileName = 'InstalledScriptInfo.xml'
$script:PSGetInstalledScripts = $null

# Public PSGallery module source name and location
$Script:PSGalleryModuleSource = "PSGallery"
$Script:PSGallerySourceUri = 'https://www.powershellgallery.com/api/v2'
$Script:PSGalleryPublishUri = 'https://www.powershellgallery.com/api/v2/package/'
$Script:PSGalleryScriptSourceUri = 'https://www.powershellgallery.com/api/v2/items/psscript'

# PSGallery V3 Source
$Script:PSGalleryV3SourceUri = 'https://www.powershellgallery.com/api/v3'

$Script:ResponseUri = "ResponseUri"
$Script:StatusCode = "StatusCode"
$Script:Exception = "Exception"

$script:PSModuleProviderName = 'PowerShellGet'
$script:PackageManagementProviderParam = "PackageManagementProvider"
$script:PublishLocation = "PublishLocation"
$script:ScriptSourceLocation = 'ScriptSourceLocation'
$script:ScriptPublishLocation = 'ScriptPublishLocation'
$script:Proxy = 'Proxy'
$script:ProxyCredential = 'ProxyCredential'
$script:Credential = 'Credential'
$script:VSTSAuthenticatedFeedsDocUrl = 'https://go.microsoft.com/fwlink/?LinkID=698608'
$script:Prerelease = "Prerelease"

$script:NuGetProviderName = "NuGet"
$script:NuGetProviderVersion = [Version]'2.8.5.201'

$script:SupportsPSModulesFeatureName = "supports-powershell-modules"
$script:FastPackRefHashtable = @{ }
$script:NuGetBinaryProgramDataPath = if ($script:IsWindows) { "$env:ProgramFiles\PackageManagement\ProviderAssemblies" }
$script:NuGetBinaryLocalAppDataPath = if ($script:IsWindows) { "$env:LOCALAPPDATA\PackageManagement\ProviderAssemblies" }
# go fwlink for 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'
$script:NuGetClientSourceURL = 'https://aka.ms/psget-nugetexe'
$script:NuGetExeMinRequiredVersion = [Version]'4.1.0'
$script:NuGetExeName = 'NuGet.exe'
$script:NuGetExePath = $null
$script:NuGetExeVersion = $null
$script:NuGetProvider = $null
$script:DotnetCommandName = 'dotnet'
$script:MinimumDotnetCommandVersion = [Version]'2.0.0'
$script:DotnetInstallUrl = 'https://aka.ms/dotnet-install-script'
$script:DotnetCommandPath = $null
# PowerShellGetFormatVersion will be incremented when we change the .nupkg format structure.
# PowerShellGetFormatVersion is in the form of Major.Minor.
# Minor is incremented for the backward compatible format change.
# Major is incremented for the breaking change.
$script:PSGetRequireLicenseAcceptanceFormatVersion = [Version]'2.0'
$script:CurrentPSGetFormatVersion = $script:PSGetRequireLicenseAcceptanceFormatVersion
$script:PSGetFormatVersion = "PowerShellGetFormatVersion"
$script:SupportedPSGetFormatVersionMajors = @("1", "2")
$script:ModuleReferences = 'Module References'
$script:AllVersions = "AllVersions"
$script:AllowPrereleaseVersions = "AllowPrereleaseVersions"
$script:Filter = "Filter"
$script:IncludeValidSet = @('DscResource', 'Cmdlet', 'Function', 'Workflow', 'RoleCapability')
$script:DscResource = "PSDscResource"
$script:Command = "PSCommand"
$script:Cmdlet = "PSCmdlet"
$script:Function = "PSFunction"
$script:Workflow = "PSWorkflow"
$script:RoleCapability = 'PSRoleCapability'
$script:Includes = "PSIncludes"
$script:Tag = "Tag"
$script:NotSpecified = '_NotSpecified_'
$script:PSGetModuleName = 'PowerShellGet'
$script:FindByCanonicalId = 'FindByCanonicalId'
$script:InstalledLocation = 'InstalledLocation'
$script:PSArtifactType = 'Type'
$script:PSArtifactTypeModule = 'Module'
$script:PSArtifactTypeScript = 'Script'
$script:All = 'All'

$script:Name = 'Name'
$script:Version = 'Version'
$script:Guid = 'Guid'
$script:Path = 'Path'
$script:ScriptBase = 'ScriptBase'
$script:Description = 'Description'
$script:Author = 'Author'
$script:CompanyName = 'CompanyName'
$script:Copyright = 'Copyright'
$script:Tags = 'Tags'
$script:LicenseUri = 'LicenseUri'
$script:ProjectUri = 'ProjectUri'
$script:IconUri = 'IconUri'
$script:RequiredModules = 'RequiredModules'
$script:ExternalModuleDependencies = 'ExternalModuleDependencies'
$script:ReleaseNotes = 'ReleaseNotes'
$script:RequiredScripts = 'RequiredScripts'
$script:ExternalScriptDependencies = 'ExternalScriptDependencies'
$script:DefinedCommands = 'DefinedCommands'
$script:DefinedFunctions = 'DefinedFunctions'
$script:DefinedWorkflows = 'DefinedWorkflows'
$script:TextInfo = (Get-Culture).TextInfo
$script:PrivateData = 'PrivateData'

$script:PSScriptInfoProperties = @($script:Name
    $script:Version,
    $script:Guid,
    $script:Path,
    $script:ScriptBase,
    $script:Description,
    $script:Author,
    $script:CompanyName,
    $script:Copyright,
    $script:Tags,
    $script:ReleaseNotes,
    $script:RequiredModules,
    $script:ExternalModuleDependencies,
    $script:RequiredScripts,
    $script:ExternalScriptDependencies,
    $script:LicenseUri,
    $script:ProjectUri,
    $script:IconUri,
    $script:DefinedCommands,
    $script:DefinedFunctions,
    $script:DefinedWorkflows,
    $script:PrivateData
)

$script:SystemEnvironmentKey = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'
$script:UserEnvironmentKey = 'HKCU:\Environment'
$script:SystemEnvironmentVariableMaximumLength = 1024
$script:UserEnvironmentVariableMaximumLength = 255
$script:EnvironmentVariableTarget = @{ Process = 0; User = 1; Machine = 2 }

# Wildcard pattern matching configuration.
$script:wildcardOptions = [System.Management.Automation.WildcardOptions]::CultureInvariant -bor `
    [System.Management.Automation.WildcardOptions]::IgnoreCase

$script:DynamicOptionTypeMap = @{
    0 = [string]; # String
    1 = [string[]]; # StringArray
    2 = [int]; # Int
    3 = [switch]; # Switch
    4 = [string]; # Folder
    5 = [string]; # File
    6 = [string]; # Path
    7 = [Uri]; # Uri
    8 = [SecureString]; #SecureString
}
#endregion script variables

#region Module message resolvers
$script:PackageManagementMessageResolverScriptBlock = {
    param($i, $Message)
    return (PackageManagementMessageResolver -MsgId $i, -Message $Message)
}

$script:PackageManagementSaveModuleMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = $LocalizedData.InstallModulewhatIfMessage
    $QuerySaveUntrustedPackage = $LocalizedData.QuerySaveUntrustedPackage

    switch ($i) {
        'ActionInstallPackage' { return "Save-Module" }
        'QueryInstallUntrustedPackage' { return $QuerySaveUntrustedPackage }
        'TargetPackage' { return $PackageTarget }
        Default {
            $Message = $Message -creplace "Install", "Download"
            $Message = $Message -creplace "install", "download"
            return (PackageManagementMessageResolver -MsgId $i, -Message $Message)
        }
    }
}

$script:PackageManagementInstallModuleMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = $LocalizedData.InstallModulewhatIfMessage

    switch ($i) {
        'ActionInstallPackage' { return "Install-Module" }
        'TargetPackage' { return $PackageTarget }
        Default {
            return (PackageManagementMessageResolver -MsgId $i, -Message $Message)
        }
    }
}

$script:PackageManagementUnInstallModuleMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = $LocalizedData.InstallModulewhatIfMessage
    switch ($i) {
        'ActionUninstallPackage' { return "Uninstall-Module" }
        'TargetPackageVersion' { return $PackageTarget }
        Default {
            return (PackageManagementMessageResolver -MsgId $i, -Message $Message)
        }
    }
}

$script:PackageManagementUpdateModuleMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = ($LocalizedData.UpdateModulewhatIfMessage -replace "__OLDVERSION__", $($psgetItemInfo.Version))
    switch ($i) {
        'ActionInstallPackage' { return "Update-Module" }
        'TargetPackage' { return $PackageTarget }
        Default {
            return (PackageManagementMessageResolver -MsgId $i, -Message $Message)
        }
    }
}

# Modules allowed to install non-Microsoft signed modules over Microsoft signed modules
$script:WhitelistedModules = @{
    "Pester"     = $true
    "PSReadline" = $true
}

function PackageManagementMessageResolver($MsgID, $Message) {
    $NoMatchFound = $LocalizedData.NoMatchFound
    $SourceNotFound = $LocalizedData.SourceNotFound
    $ModuleIsNotTrusted = $LocalizedData.ModuleIsNotTrusted
    $RepositoryIsNotTrusted = $LocalizedData.RepositoryIsNotTrusted
    $QueryInstallUntrustedPackage = $LocalizedData.QueryInstallUntrustedPackage

    switch ($MsgID) {
        'NoMatchFound' { return $NoMatchFound }
        'SourceNotFound' { return $SourceNotFound }
        'CaptionPackageNotTrusted' { return $ModuleIsNotTrusted }
        'CaptionSourceNotTrusted' { return $RepositoryIsNotTrusted }
        'QueryInstallUntrustedPackage' { return $QueryInstallUntrustedPackage }
        Default {
            if ($Message) {
                $tempMessage = $Message -creplace "PackageSource", "PSRepository"
                $tempMessage = $tempMessage -creplace "packagesource", "psrepository"
                $tempMessage = $tempMessage -creplace "Package", "Module"
                $tempMessage = $tempMessage -creplace "package", "module"
                $tempMessage = $tempMessage -creplace "Sources", "Repositories"
                $tempMessage = $tempMessage -creplace "sources", "repositories"
                $tempMessage = $tempMessage -creplace "Source", "Repository"
                $tempMessage = $tempMessage -creplace "source", "repository"

                return $tempMessage
            }
        }
    }
}

#endregion Module message resolvers

#region Script message resolvers
$script:PackageManagementMessageResolverScriptBlockForScriptCmdlets = {
    param($i, $Message)
    return (PackageManagementMessageResolverForScripts -MsgId $i, -Message $Message)
}

$script:PackageManagementSaveScriptMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = $LocalizedData.InstallScriptwhatIfMessage
    $QuerySaveUntrustedPackage = $LocalizedData.QuerySaveUntrustedScriptPackage

    switch ($i) {
        'ActionInstallPackage' { return "Save-Script" }
        'QueryInstallUntrustedPackage' { return $QuerySaveUntrustedPackage }
        'TargetPackage' { return $PackageTarget }
        Default {
            $Message = $Message -creplace "Install", "Download"
            $Message = $Message -creplace "install", "download"
            return (PackageManagementMessageResolverForScripts -MsgId $i, -Message $Message)
        }
    }
}

$script:PackageManagementInstallScriptMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = $LocalizedData.InstallScriptwhatIfMessage

    switch ($i) {
        'ActionInstallPackage' { return "Install-Script" }
        'TargetPackage' { return $PackageTarget }
        Default {
            return (PackageManagementMessageResolverForScripts -MsgId $i, -Message $Message)
        }
    }
}

$script:PackageManagementUnInstallScriptMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = $LocalizedData.InstallScriptwhatIfMessage
    switch ($i) {
        'ActionUninstallPackage' { return "Uninstall-Script" }
        'TargetPackageVersion' { return $PackageTarget }
        Default {
            return (PackageManagementMessageResolverForScripts -MsgId $i, -Message $Message)
        }
    }
}

$script:PackageManagementUpdateScriptMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = ($LocalizedData.UpdateScriptwhatIfMessage -replace "__OLDVERSION__", $($psgetItemInfo.Version))
    switch ($i) {
        'ActionInstallPackage' { return "Update-Script" }
        'TargetPackage' { return $PackageTarget }
        Default {
            return (PackageManagementMessageResolverForScripts -MsgId $i, -Message $Message)
        }
    }
}

function PackageManagementMessageResolverForScripts($MsgID, $Message) {
    $NoMatchFound = $LocalizedData.NoMatchFoundForScriptName
    $SourceNotFound = $LocalizedData.SourceNotFound
    $ScriptIsNotTrusted = $LocalizedData.ScriptIsNotTrusted
    $RepositoryIsNotTrusted = $LocalizedData.RepositoryIsNotTrusted
    $QueryInstallUntrustedPackage = $LocalizedData.QueryInstallUntrustedScriptPackage

    switch ($MsgID) {
        'NoMatchFound' { return $NoMatchFound }
        'SourceNotFound' { return $SourceNotFound }
        'CaptionPackageNotTrusted' { return $ScriptIsNotTrusted }
        'CaptionSourceNotTrusted' { return $RepositoryIsNotTrusted }
        'QueryInstallUntrustedPackage' { return $QueryInstallUntrustedPackage }
        Default {
            if ($Message) {
                $tempMessage = $Message -creplace "PackageSource", "PSRepository"
                $tempMessage = $tempMessage -creplace "packagesource", "psrepository"
                $tempMessage = $tempMessage -creplace "Package", "Script"
                $tempMessage = $tempMessage -creplace "package", "script"
                $tempMessage = $tempMessage -creplace "Sources", "Repositories"
                $tempMessage = $tempMessage -creplace "sources", "repositories"
                $tempMessage = $tempMessage -creplace "Source", "Repository"
                $tempMessage = $tempMessage -creplace "source", "repository"

                return $tempMessage
            }
        }
    }
}

#endregion Script message resolvers

#region Add .Net type for Telemetry APIs and WebProxy

# Check and add InternalWebProxy type
if ( -not ('Microsoft.PowerShell.Commands.PowerShellGet.InternalWebProxy' -as [Type])) {
    $RequiredAssembliesForInternalWebProxy = @(
        [System.Net.IWebProxy].Assembly.FullName,
        [System.Uri].Assembly.FullName
    )

    $InternalWebProxySource = @'
using System;
using System.Net;

namespace Microsoft.PowerShell.Commands.PowerShellGet
{
    /// <summary>
    /// Used by Ping-Endpoint function to supply webproxy to HttpClient
    /// We cannot use System.Net.WebProxy because this is not available on CoreClr
    /// </summary>
    public class InternalWebProxy : IWebProxy
    {
        Uri _proxyUri;
        ICredentials _credentials;

        public InternalWebProxy(Uri uri, ICredentials credentials)
        {
            Credentials = credentials;
            _proxyUri = uri;
        }

        /// <summary>
        /// Credentials used by WebProxy
        /// </summary>
        public ICredentials Credentials
        {
            get
            {
                return _credentials;
            }
            set
            {
                _credentials = value;
            }
        }

        public Uri GetProxy(Uri destination)
        {
            return _proxyUri;
        }

        public bool IsBypassed(Uri host)
        {
            return false;
        }
    }
}
'@

    try {
        $AddType_prams = @{
            TypeDefinition = $InternalWebProxySource
            Language       = 'CSharp'
            ErrorAction    = 'SilentlyContinue'
        }
        if (-not $script:IsCoreCLR -or $script:IsNanoServer) {
            $AddType_prams['ReferencedAssemblies'] = $RequiredAssembliesForInternalWebProxy
        }
        Add-Type @AddType_prams
    }
    catch {
        Write-Warning -Message "InternalWebProxy: $_"
    }
}

# Check and add Telemetry type
if (('Microsoft.PowerShell.Telemetry.Internal.TelemetryAPI' -as [Type]) -and
    -not ('Microsoft.PowerShell.Commands.PowerShellGet.Telemetry' -as [Type])) {
    $RequiredAssembliesForTelemetry = @(
        [System.Management.Automation.PSCmdlet].Assembly.FullName
    )

    $TelemetrySource = @'
using System;
using System.Management.Automation;

namespace Microsoft.PowerShell.Commands.PowerShellGet
{
    public static class Telemetry
    {
        public static void TraceMessageArtifactsNotFound(string[] artifactsNotFound, string operationName)
        {
            Microsoft.PowerShell.Telemetry.Internal.TelemetryAPI.TraceMessage(operationName, new { ArtifactsNotFound = artifactsNotFound });
        }

        public static void TraceMessageNonPSGalleryRegistration(string sourceLocationType, string sourceLocationHash, string installationPolicy, string packageManagementProvider, string publishLocationHash, string scriptSourceLocationHash, string scriptPublishLocationHash, string operationName)
        {
            Microsoft.PowerShell.Telemetry.Internal.TelemetryAPI.TraceMessage(operationName, new { SourceLocationType = sourceLocationType, SourceLocationHash = sourceLocationHash, InstallationPolicy = installationPolicy, PackageManagementProvider = packageManagementProvider, PublishLocationHash = publishLocationHash, ScriptSourceLocationHash = scriptSourceLocationHash, ScriptPublishLocationHash = scriptPublishLocationHash });
        }
    }
}
'@

    try {
        $AddType_prams = @{
            TypeDefinition = $TelemetrySource
            Language       = 'CSharp'
            ErrorAction    = 'SilentlyContinue'
        }
        $AddType_prams['ReferencedAssemblies'] = $RequiredAssembliesForTelemetry
        Add-Type @AddType_prams
    }
    catch {
        Write-Warning -Message "Telemetry: $_"
    }
}
# Turn ON Telemetry if the infrastructure is present on the machine
$script:TelemetryEnabled = $false
if ('Microsoft.PowerShell.Commands.PowerShellGet.Telemetry' -as [Type]) {
    $telemetryMethods = ([Microsoft.PowerShell.Commands.PowerShellGet.Telemetry] | Get-Member -Static).Name
    if ($telemetryMethods.Contains("TraceMessageArtifactsNotFound") -and $telemetryMethods.Contains("TraceMessageNonPSGalleryRegistration")) {
        $script:TelemetryEnabled = $true
    }
}

# Check and add Win32Helpers type
$script:IsSafeX509ChainHandleAvailable = ($null -ne ('Microsoft.Win32.SafeHandles.SafeX509ChainHandle' -as [Type]))
if ($script:IsWindows -and -not ('Microsoft.PowerShell.Commands.PowerShellGet.Win32Helpers' -as [Type])) {
    $RequiredAssembliesForWin32Helpers = @()
    if ($script:IsSafeX509ChainHandleAvailable) {
        # It is not possible to define a single internal SafeHandle class in PowerShellGet namespace for all the supported versions of .Net Framework including .Net Core.
        # SafeHandleZeroOrMinusOneIsInvalid is not a public class on .Net Core,
        # therefore SafeX509ChainHandle will be used if it is available otherwise InternalSafeX509ChainHandle is defined below.
        #
        # ChainContext is not available on .Net Core, we must have to use SafeX509ChainHandle on .Net Core.
        #
        $SafeX509ChainHandleClassName = 'SafeX509ChainHandle'
        $RequiredAssembliesForWin32Helpers += [Microsoft.Win32.SafeHandles.SafeX509ChainHandle].Assembly.FullName
    }
    else {
        # SafeX509ChainHandle is not available on .Net Framework 4.5 or older versions,
        # therefore InternalSafeX509ChainHandle is defined below.
        #
        $SafeX509ChainHandleClassName = 'InternalSafeX509ChainHandle'
    }

    $Win32HelpersSource = @"
using System;
using System.Net;
using Microsoft.Win32.SafeHandles;
using System.Security.Cryptography;
using System.Runtime.InteropServices;
using System.Runtime.ConstrainedExecution;
using System.Runtime.Versioning;
using System.Security;

namespace Microsoft.PowerShell.Commands.PowerShellGet
{
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct CERT_CHAIN_POLICY_PARA {
        public CERT_CHAIN_POLICY_PARA(int size) {
            cbSize = (uint) size;
            dwFlags = 0;
            pvExtraPolicyPara = IntPtr.Zero;
        }
        public uint   cbSize;
        public uint   dwFlags;
        public IntPtr pvExtraPolicyPara;
    }

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct CERT_CHAIN_POLICY_STATUS {
        public CERT_CHAIN_POLICY_STATUS(int size) {
            cbSize = (uint) size;
            dwError = 0;
            lChainIndex = IntPtr.Zero;
            lElementIndex = IntPtr.Zero;
            pvExtraPolicyStatus = IntPtr.Zero;
        }
        public uint   cbSize;
        public uint   dwError;
        public IntPtr lChainIndex;
        public IntPtr lElementIndex;
        public IntPtr pvExtraPolicyStatus;
    }

    // Internal SafeHandleZeroOrMinusOneIsInvalid class to remove the dependency on .Net Framework 4.6.
    public abstract class InternalSafeHandleZeroOrMinusOneIsInvalid : SafeHandle
    {
        protected InternalSafeHandleZeroOrMinusOneIsInvalid(bool ownsHandle)
            : base(IntPtr.Zero, ownsHandle)
        {
        }

        public override bool IsInvalid
        {
            get
            {
                return handle == IntPtr.Zero || handle == new IntPtr(-1);
            }
        }
    }

    // Internal SafeX509ChainHandle class to remove the dependency on .Net Framework 4.6.
    [SecurityCritical]
    public sealed class InternalSafeX509ChainHandle : InternalSafeHandleZeroOrMinusOneIsInvalid {
        private InternalSafeX509ChainHandle () : base(true) {}

        internal InternalSafeX509ChainHandle (IntPtr handle) : base (true) {
            SetHandle(handle);
        }

        internal static InternalSafeX509ChainHandle InvalidHandle {
            get { return new InternalSafeX509ChainHandle(IntPtr.Zero); }
        }

        [SecurityCritical]
        override protected bool ReleaseHandle()
        {
            CertFreeCertificateChain(handle);
            return true;
        }

        [DllImport("Crypt32.dll", SetLastError=true)]
$(if(-not $script:IsCoreCLR)
{
        '
        [SuppressUnmanagedCodeSecurity,
         ResourceExposure(ResourceScope.None),
         ReliabilityContract(Consistency.WillNotCorruptState, Cer.Success)]
        '
})
        private static extern void CertFreeCertificateChain(IntPtr handle);
    }

    public class Win32Helpers
    {
        [DllImport("Crypt32.dll", CharSet=CharSet.Auto, SetLastError=true)]
        public extern static
        bool CertVerifyCertificateChainPolicy(
            [In]     IntPtr                       pszPolicyOID,
            [In]     $SafeX509ChainHandleClassName  pChainContext,
            [In]     ref CERT_CHAIN_POLICY_PARA   pPolicyPara,
            [In,Out] ref CERT_CHAIN_POLICY_STATUS pPolicyStatus);

        [DllImport("Crypt32.dll", CharSet=CharSet.Auto, SetLastError=true)]
        public static extern
        $SafeX509ChainHandleClassName CertDuplicateCertificateChain(
            [In]     IntPtr pChainContext);

$(if($script:IsSafeX509ChainHandleAvailable)
{
@"
        [DllImport("Crypt32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    $(if(-not $script:IsCoreCLR)
    {
    '
        [ResourceExposure(ResourceScope.None)]
    '
    })
        public static extern
        SafeX509ChainHandle CertDuplicateCertificateChain(
            [In]     SafeX509ChainHandle pChainContext);
"@
})

        public static bool IsMicrosoftCertificate([In] $SafeX509ChainHandleClassName pChainContext)
        {
            //-------------------------------------------------------------------------
            //  CERT_CHAIN_POLICY_MICROSOFT_ROOT
            //
            //  Checks if the last element of the first simple chain contains a
            //  Microsoft root public key. If it doesn't contain a Microsoft root
            //  public key, dwError is set to CERT_E_UNTRUSTEDROOT.
            //
            //  pPolicyPara is optional. However,
            //  MICROSOFT_ROOT_CERT_CHAIN_POLICY_ENABLE_TEST_ROOT_FLAG can be set in
            //  the dwFlags in pPolicyPara to also check for the Microsoft Test Roots.
            //
            //  MICROSOFT_ROOT_CERT_CHAIN_POLICY_CHECK_APPLICATION_ROOT_FLAG can be set
            //  in the dwFlags in pPolicyPara to check for the Microsoft root for
            //  application signing instead of the Microsoft product root. This flag
            //  explicitly checks for the application root only and cannot be combined
            //  with the test root flag.
            //
            //  MICROSOFT_ROOT_CERT_CHAIN_POLICY_DISABLE_FLIGHT_ROOT_FLAG can be set
            //  in the dwFlags in pPolicyPara to always disable the Flight root.
            //
            //  pvExtraPolicyPara and pvExtraPolicyStatus aren't used and must be set
            //  to NULL.
            //--------------------------------------------------------------------------
            const uint MICROSOFT_ROOT_CERT_CHAIN_POLICY_ENABLE_TEST_ROOT_FLAG       = 0x00010000;
            const uint MICROSOFT_ROOT_CERT_CHAIN_POLICY_CHECK_APPLICATION_ROOT_FLAG = 0x00020000;
            //const uint MICROSOFT_ROOT_CERT_CHAIN_POLICY_DISABLE_FLIGHT_ROOT_FLAG    = 0x00040000;

            CERT_CHAIN_POLICY_PARA PolicyPara = new CERT_CHAIN_POLICY_PARA(Marshal.SizeOf(typeof(CERT_CHAIN_POLICY_PARA)));
            CERT_CHAIN_POLICY_STATUS PolicyStatus = new CERT_CHAIN_POLICY_STATUS(Marshal.SizeOf(typeof(CERT_CHAIN_POLICY_STATUS)));
            int CERT_CHAIN_POLICY_MICROSOFT_ROOT = 7;

            PolicyPara.dwFlags = (uint) MICROSOFT_ROOT_CERT_CHAIN_POLICY_ENABLE_TEST_ROOT_FLAG;
            bool isMicrosoftRoot = false;

            if(CertVerifyCertificateChainPolicy(new IntPtr(CERT_CHAIN_POLICY_MICROSOFT_ROOT),
                                                pChainContext,
                                                ref PolicyPara,
                                                ref PolicyStatus))
            {
                isMicrosoftRoot = (PolicyStatus.dwError == 0);
            }

            // Also check for the Microsoft root for application signing if the Microsoft product root verification is unsuccessful.
            if(!isMicrosoftRoot)
            {
                // Some Microsoft modules can be signed with Microsoft Application Root instead of Microsoft Product Root,
                // So we need to use the MICROSOFT_ROOT_CERT_CHAIN_POLICY_CHECK_APPLICATION_ROOT_FLAG for the certificate verification.
                // MICROSOFT_ROOT_CERT_CHAIN_POLICY_CHECK_APPLICATION_ROOT_FLAG can not be used
                // with MICROSOFT_ROOT_CERT_CHAIN_POLICY_ENABLE_TEST_ROOT_FLAG,
                // so additional CertVerifyCertificateChainPolicy call is required to verify the given certificate is in Microsoft Application Root.
                //
                CERT_CHAIN_POLICY_PARA PolicyPara2 = new CERT_CHAIN_POLICY_PARA(Marshal.SizeOf(typeof(CERT_CHAIN_POLICY_PARA)));
                CERT_CHAIN_POLICY_STATUS PolicyStatus2 = new CERT_CHAIN_POLICY_STATUS(Marshal.SizeOf(typeof(CERT_CHAIN_POLICY_STATUS)));
                PolicyPara2.dwFlags = (uint) MICROSOFT_ROOT_CERT_CHAIN_POLICY_CHECK_APPLICATION_ROOT_FLAG;

                if(CertVerifyCertificateChainPolicy(new IntPtr(CERT_CHAIN_POLICY_MICROSOFT_ROOT),
                                                    pChainContext,
                                                    ref PolicyPara2,
                                                    ref PolicyStatus2))
                {
                    isMicrosoftRoot = (PolicyStatus2.dwError == 0);
                }
            }

            return isMicrosoftRoot;
        }
    }
}
"@

    try {
        $AddType_prams = @{
            TypeDefinition = $Win32HelpersSource
            Language       = 'CSharp'
            ErrorAction    = 'SilentlyContinue'
        }
        if ((-not $script:IsCoreCLR -or $script:IsNanoServer) -and $RequiredAssembliesForWin32Helpers) {
            $AddType_prams['ReferencedAssemblies'] = $RequiredAssembliesForWin32Helpers
        }
        Add-Type @AddType_prams
    }
    catch {
        Write-Warning -Message "Win32Helpers: $_"
    }
}

#endregion

#region Private Functions
function Add-ArgumentCompleter()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$cmdlets,
        
        [Parameter(Mandatory=$true)]
        [string]$parameterName
    )

    try
    {
        if(Get-Command -Name Register-ArgumentCompleter -ErrorAction SilentlyContinue)
        {
            Register-ArgumentCompleter -CommandName $cmdlets -ParameterName $parameterName -ScriptBlock {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter) 
                
                Get-PSRepository -Name "$wordTocomplete*"-ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Foreach-Object { 
                    [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Name) 
                } 
           }
        }
    }
    catch 
    {
        # All this functionality is optional, so suppress errors 
        Write-Debug -Message "Error registering argument completer: $_"      
    }
}
function Compare-PrereleaseVersions
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $FirstItemVersion,

        [string]
        $FirstItemPrerelease,

        [ValidateNotNullOrEmpty()]
        [string]
        $SecondItemVersion,

        [string]
        $SecondItemPrerelease
    )

    <#
        This function compares one item to another to determine if it has a greater version (and/or prerelease).
        It returns true if item TWO is GREATER/newer than item ONE, it returns false otherwise.


        First Order:  Compare Versions
        ===========
        *** Version is never NULL.

        Item #1         Comparison      Item #2
        Version         of Values       Version         Notes about item #2
        -------         ----------      -------         -------------------
        Value           >               Value           An older release version
        Value           <               Value         * A newer release version
        Value           ==              Value           Inconclusive, must compare prerelease strings now



        Second Order:  Compare Prereleases
        =============
        *** Prerelease may be NULL, indicates a release version.

        Item #1         Comparison      Item #2
        Prerelease      of Values       Prerelease      Notes about item #2
        ----------      -----------     ----------      -------------------
        NULL                ==          NULL            Exact same release version
        NULL                >           Value           Older (prerelease) version
        Value               <           NULL          * A newer, release version
        Value               ==          Value           Exact same prerelease (and same version)
        Value               >           Value           An older prerelease
        Value               <           Value         * A newer prerelease


        Item #2 is newer/greater than item #1 in the starred (*) combinations.
        Those are the conditions tested for below.
    #>

    [version]$itemOneVersion = $null
    # try parsing version string
    if (-not ( [System.Version]::TryParse($FirstItemVersion.Trim(), [ref]$itemOneVersion) ))
    {
        $message = $LocalizedData.InvalidVersion -f ($FirstItemVersion)
        Write-Error -Message $message -ErrorId "InvalidVersion" -Category InvalidArgument
        return
    }

    [Version]$itemTwoVersion = $null
    # try parsing version string
    if (-not ( [System.Version]::TryParse($SecondItemVersion.Trim(), [ref]$itemTwoVersion) ))
    {
        $message = $LocalizedData.InvalidVersion -f ($SecondItemVersion)
        Write-Error -Message $message -ErrorId "InvalidVersion" -Category InvalidArgument
        return
    }

    return (($itemOneVersion -lt $itemTwoVersion) -or `
            (($itemOneVersion -eq $itemTwoVersion) -and `
             (($FirstItemPrerelease -and -not $SecondItemPrerelease) -or `
              ($FirstItemPrerelease -lt $SecondItemPrerelease))))
}
function Copy-Module
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourcePath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationPath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [PSCustomObject]
        $PSGetItemInfo,

        [Parameter(Mandatory=$false)]        
        [Switch]
        $IsSavePackage
    )

    $ev = $null
    if(-not $IsSavePackage)
    {
        $message = $LocalizedData.AdministratorRightsNeededOrSpecifyCurrentUserScope
        $errorId = 'AdministratorRightsNeededOrSpecifyCurrentUserScope'
    }
    else
    {
        $message = $LocalizedData.UnauthorizedAccessError -f $DestinationPath
        $errorId = 'UnauthorizedAccessError'
    }

    if(Microsoft.PowerShell.Management\Test-Path $DestinationPath)
    {
        Microsoft.PowerShell.Management\Remove-Item -Path $DestinationPath `
                                                    -Recurse `
                                                    -Force `
                                                    -ErrorVariable ev `
                                                    -ErrorAction SilentlyContinue `
                                                    -WarningAction SilentlyContinue `
                                                    -Confirm:$false `
                                                    -WhatIf:$false

        if($ev)
        {
            $script:IsRunningAsElevated = $false
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId $errorId `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $ev
        }
    }


    # Copy the module to destination
    $null = Microsoft.PowerShell.Management\New-Item -Path $DestinationPath `
                                                     -ItemType Directory `
                                                     -Force `
                                                     -ErrorVariable ev `
                                                     -ErrorAction SilentlyContinue `
                                                     -WarningAction SilentlyContinue `
                                                     -Confirm:$false `
                                                     -WhatIf:$false

    if($ev)
    {
        $script:IsRunningAsElevated = $false
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $message `
                   -ErrorId $errorId `
                   -CallerPSCmdlet $PSCmdlet `
                   -ErrorCategory InvalidArgument `
                   -ExceptionObject $ev
    }

    Microsoft.PowerShell.Management\Copy-Item -Path (Microsoft.PowerShell.Management\Join-Path -Path $SourcePath -ChildPath '*') `
                                              -Destination $DestinationPath `
                                              -Force `
                                              -Recurse `
                                              -ErrorVariable ev `
                                              -ErrorAction SilentlyContinue `
                                              -Confirm:$false `
                                              -WhatIf:$false

    if($ev)
    {
        $script:IsRunningAsElevated = $false
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $message `
                   -ErrorId $errorId `
                   -CallerPSCmdlet $PSCmdlet `
                   -ErrorCategory InvalidArgument `
                   -ExceptionObject $ev
    }

    # Remove the *.nupkg file
    $NupkgFilePath = Join-PathUtility -Path $DestinationPath -ChildPath "$($PSGetItemInfo.Name).nupkg" -PathType File
    if(Microsoft.PowerShell.Management\Test-Path -Path $NupkgFilePath -PathType Leaf)
    {
        Microsoft.PowerShell.Management\Remove-Item -Path $NupkgFilePath -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
    }

    # Create PSGetModuleInfo.xml
    $psgetItemInfopath = Microsoft.PowerShell.Management\Join-Path $DestinationPath $script:PSGetItemInfoFileName

    Microsoft.PowerShell.Utility\Out-File -FilePath $psgetItemInfopath -Force -InputObject ([System.Management.Automation.PSSerializer]::Serialize($PSGetItemInfo))

    [System.IO.File]::SetAttributes($psgetItemInfopath, [System.IO.FileAttributes]::Hidden)
}
function Copy-ScriptFile
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourcePath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationPath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [PSCustomObject]
        $PSGetItemInfo,

        [Parameter()]
        [string]
        $Scope
    )

    $ev = $null
    $message = $LocalizedData.AdministratorRightsNeededOrSpecifyCurrentUserScope

    # Copy the script file to destination
    if(-not (Microsoft.PowerShell.Management\Test-Path -Path $DestinationPath))
    {
        $null = Microsoft.PowerShell.Management\New-Item -Path $DestinationPath `
                                                         -ItemType Directory `
                                                         -Force `
                                                         -ErrorVariable ev `
                                                         -ErrorAction SilentlyContinue `
                                                         -WarningAction SilentlyContinue `
                                                         -Confirm:$false `
                                                         -WhatIf:$false

        if($ev)
        {
            $script:IsRunningAsElevated = $false
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId "AdministratorRightsNeededOrSpecifyCurrentUserScope" `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $ev
        }
    }

    Microsoft.PowerShell.Management\Copy-Item -Path $SourcePath `
                                              -Destination $DestinationPath `
                                              -Force `
                                              -Confirm:$false `
                                              -WhatIf:$false `
                                              -ErrorVariable ev `
                                              -ErrorAction SilentlyContinue

    if($ev)
    {
        $script:IsRunningAsElevated = $false
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $message `
                   -ErrorId "AdministratorRightsNeededOrSpecifyCurrentUserScope" `
                   -CallerPSCmdlet $PSCmdlet `
                   -ErrorCategory InvalidArgument `
                   -ExceptionObject $ev
    }

    if($Scope)
    {
        # Create <Name>_InstalledScriptInfo.xml
        $InstalledScriptInfoFileName = "$($PSGetItemInfo.Name)_$script:InstalledScriptInfoFileName"

        if($scope -eq 'AllUsers')
        {
            $scriptInfopath = Microsoft.PowerShell.Management\Join-Path -Path $script:ProgramFilesInstalledScriptInfosPath `
                                                                        -ChildPath $InstalledScriptInfoFileName
        }
        else
        {
            $scriptInfopath = Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsInstalledScriptInfosPath `
                                                                        -ChildPath $InstalledScriptInfoFileName
        }

        Microsoft.PowerShell.Utility\Out-File -FilePath $scriptInfopath `
                                              -Force `
                                              -InputObject ([System.Management.Automation.PSSerializer]::Serialize($PSGetItemInfo))
    }
}
function DeSerialize-PSObject
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true)]
        $Path
    )
    $filecontent = Microsoft.PowerShell.Management\Get-Content -Path $Path
    [System.Management.Automation.PSSerializer]::Deserialize($filecontent)
}
function Get-AuthenticodePublisher
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Signature]
        $AuthenticodeSignature
    )

    if($AuthenticodeSignature.SignerCertificate)
    {
        $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
        $null = $chain.Build($AuthenticodeSignature.SignerCertificate)

        $certStoreLocations = @('cert:\LocalMachine\Root',
                                'cert:\LocalMachine\AuthRoot',
                                'cert:\CurrentUser\Root',
                                'cert:\CurrentUser\AuthRoot')

        foreach($element in $chain.ChainElements.Certificate)
        {
            foreach($certStoreLocation in $certStoreLocations)
            {
                $rootCertificateAuthority = Microsoft.PowerShell.Management\Get-ChildItem -Path $certStoreLocation |
                                                Microsoft.PowerShell.Core\Where-Object { ($_.Subject -eq $element.Subject) -and ($_.thumbprint -eq $element.thumbprint) }
                if($rootCertificateAuthority)
                {
                    # Select-Object writes an error 'System Error' into the error stream.
                    # Using below workaround for getting the first element when there are multiple certificates with the same subject name.
                    if($rootCertificateAuthority.PSTypeNames -contains 'System.Array') {
                        $rootCertificateAuthority = $rootCertificateAuthority[0]
                    }
                    
                    $publisherInfo = @{
                        publisher = $AuthenticodeSignature.SignerCertificate.Subject
                        publisherRootCA = $rootCertificateAuthority.Subject
                    } 

                    Write-Output -InputObject $publisherInfo
                    return
                }
            }
        }
    }
}
function Get-AvailableRoleCapabilityName
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [PSModuleInfo]
        $PSModuleInfo
    )

    $RoleCapabilityNames = @()

    $RoleCapabilitiesDir = Join-PathUtility -Path $PSModuleInfo.ModuleBase -ChildPath 'RoleCapabilities' -PathType Directory
    if(Microsoft.PowerShell.Management\Test-Path -Path $RoleCapabilitiesDir -PathType Container)
    {
        $RoleCapabilityNames = Microsoft.PowerShell.Management\Get-ChildItem -Path $RoleCapabilitiesDir `
                                  -Name -Filter *.psrc |
                                      ForEach-Object {[System.IO.Path]::GetFileNameWithoutExtension($_)}
    }

    return $RoleCapabilityNames
}
function Get-AvailableScriptFilePath
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter()]
        [string]
        $Name
    )

    $scriptInfo = $null
    $scriptFileName = '*.ps1'
    $scriptBasePaths = @($script:ProgramFilesScriptsPath, $script:MyDocumentsScriptsPath)
    $scriptFilePaths = @()
    $wildcardPattern = $null

    if($Name)
    {
        if(Test-WildcardPattern -Name $Name)
        {
            $wildcardPattern = New-Object System.Management.Automation.WildcardPattern $Name,$script:wildcardOptions
        }
        else
        {
            $scriptFileName = "$Name.ps1"
        }

    }

    foreach ($location in $scriptBasePaths)
    {
        $scriptFiles = Get-ChildItem -Path $location `
                                     -Filter $scriptFileName `
                                     -ErrorAction SilentlyContinue `
                                     -WarningAction SilentlyContinue

        if($wildcardPattern)
        {
            $scriptFiles | Microsoft.PowerShell.Core\ForEach-Object {
                                if($wildcardPattern.IsMatch($_.BaseName))
                                {
                                    $scriptFilePaths += $_.FullName
                                }
                           }
        }
        else
        {
            $scriptFiles | Microsoft.PowerShell.Core\ForEach-Object { $scriptFilePaths += $_.FullName }
        }
    }

    return $scriptFilePaths
}
function Get-DynamicParameters
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Location,

        [Parameter(Mandatory=$true)]
        [REF]
        $PackageManagementProvider
    )

    $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
    $dynamicOptions = $null

    $loc = Get-LocationString -LocationUri $Location

    if(-not $loc)
    {
        return $paramDictionary
    }

    # Ping and resolve the specified location
    $loc = Resolve-Location -Location $loc `
                            -LocationParameterName 'Location' `
                            -ErrorAction SilentlyContinue `
                            -WarningAction SilentlyContinue
    if(-not $loc)
    {
        return $paramDictionary
    }

    $providers = PackageManagement\Get-PackageProvider | Where-Object { $_.Features.ContainsKey($script:SupportsPSModulesFeatureName) }

    if ($PackageManagementProvider.Value)
    {
        # Skip the PowerShellGet provider
        if($PackageManagementProvider.Value -ne $script:PSModuleProviderName)
        {
            $SelectedProvider = $providers | Where-Object {$_.ProviderName -eq $PackageManagementProvider.Value}

            if($SelectedProvider)
            {
                $res = Get-PackageSource -Location $loc -Provider $PackageManagementProvider.Value -ErrorAction SilentlyContinue

                if($res)
                {
                    $dynamicOptions = $SelectedProvider.DynamicOptions
                }
            }
        }
    }
    else
    {
        $PackageManagementProvider.Value = Get-PackageManagementProviderName -Location $Location
        if($PackageManagementProvider.Value)
        {
            $provider = $providers | Where-Object {$_.ProviderName -eq $PackageManagementProvider.Value}
            $dynamicOptions = $provider.DynamicOptions
        }
    }

    foreach ($option in $dynamicOptions)
    {
        # Skip the Destination parameter
        if( $option.IsRequired -and
            ($option.Name -eq "Destination") )
        {
            continue
        }

        $paramAttribute = New-Object System.Management.Automation.ParameterAttribute
        $paramAttribute.Mandatory = $option.IsRequired

        $message = $LocalizedData.DynamicParameterHelpMessage -f ($option.Name, $PackageManagementProvider.Value, $loc, $option.Name)
        $paramAttribute.HelpMessage = $message

        $attributeCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute]
        $attributeCollection.Add($paramAttribute)

        $ageParam = New-Object System.Management.Automation.RuntimeDefinedParameter($option.Name,
                                                                                    $script:DynamicOptionTypeMap[$option.Type.value__],
                                                                                    $attributeCollection)
        $paramDictionary.Add($option.Name, $ageParam)
    }

    return $paramDictionary
}
function Get-EntityName
{
    param
    (
        [Parameter(Mandatory=$true)]
        $SoftwareIdentity,

        [Parameter(Mandatory=$true)]
        $Role
    )

    foreach( $entity in $SoftwareIdentity.Entities )
    {
        if( $entity.Role -eq $Role)
        {
            $entity.Name
        }
    }
}
function Get-EnvironmentVariable
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [parameter(Mandatory = $true)]
        [int]
        $Target
    )

    if ($Target -eq $script:EnvironmentVariableTarget.Process)
    {
        return [System.Environment]::GetEnvironmentVariable($Name)
    }
    elseif ($Target -eq $script:EnvironmentVariableTarget.Machine)
    {
        if ($Name -eq "path")
        {
            # if we need the path environment variable, we need it un-expanded, otherwise
            # when writing it back, we would loose all the variables like %systemroot% in it.
            # We use the Win32 API directly using DoNotExpandEnvironmentNames
            # It is unclear whether any code calling this function for %path% needs the expanded version of %path%
            # There are currently no tests for this code
            # Microsoft.PowerShell.Management\Get-ItemProperty is passed through to the PowerShell Registry provider
            # which currently doesn't seem to support anything like: DoNotExpandEnvironmentNames
            $hklmHive = [Microsoft.Win32.Registry]::LocalMachine
            $EnvRegKey = $hklmHive.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment", $FALSE)
            $itemPropertyValue = $EnvRegKey.GetValue($Name, "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            return $itemPropertyValue
        }
        else
        {
            $itemPropertyValue = Microsoft.PowerShell.Management\Get-ItemProperty -Path $script:SystemEnvironmentKey -Name $Name -ErrorAction SilentlyContinue

            if($itemPropertyValue)
            {
                return $itemPropertyValue.$Name
            }
        }
    }
    elseif ($Target -eq $script:EnvironmentVariableTarget.User)
    {
        $itemPropertyValue = Microsoft.PowerShell.Management\Get-ItemProperty -Path $script:UserEnvironmentKey -Name $Name -ErrorAction SilentlyContinue

        if($itemPropertyValue)
        {
            return $itemPropertyValue.$Name
        }
    }
}
function Get-EscapedString
{
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        [Parameter()]
        [string]
        $ElementValue
    )

    return [System.Security.SecurityElement]::Escape($ElementValue)
}
function Get-ExportedDscResources
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [PSModuleInfo]
        $PSModuleInfo
    )

    $dscResources = @()

    if(-not $script:IsCoreCLR -and (Get-Command -Name Get-DscResource -Module PSDesiredStateConfiguration -ErrorAction Ignore))
    {
        $OldPSModulePath = $env:PSModulePath

        try
        {
            $env:PSModulePath = Join-Path -Path $PSHOME -ChildPath "Modules"
            $env:PSModulePath = "$env:PSModulePath;$(Split-Path -Path $PSModuleInfo.ModuleBase -Parent)"

            $dscResources = PSDesiredStateConfiguration\Get-DscResource -ErrorAction SilentlyContinue -WarningAction SilentlyContinue |
                                Microsoft.PowerShell.Core\ForEach-Object {
                                    if($_.Module -and ($_.Module.Name -eq $PSModuleInfo.Name))
                                    {
                                        $_.Name
                                    }
                                }
        }
        finally
        {
            $env:PSModulePath = $OldPSModulePath
        }
    }
    else
    {
        $dscResourcesDir = Join-PathUtility -Path $PSModuleInfo.ModuleBase -ChildPath "DscResources" -PathType Directory
        if(Microsoft.PowerShell.Management\Test-Path $dscResourcesDir)
        {
            $dscResources = Microsoft.PowerShell.Management\Get-ChildItem -Path $dscResourcesDir -Directory -Name
        }
    }

    return $dscResources
}
function Get-ExternalModuleDependencies
{
    Param (
        [Parameter(Mandatory=$true)]
        [PSModuleInfo]
        $PSModuleInfo
    )

    if($PSModuleInfo.PrivateData -and
       ($PSModuleInfo.PrivateData.GetType().ToString() -eq "System.Collections.Hashtable") -and
       $PSModuleInfo.PrivateData["PSData"] -and
       ($PSModuleInfo.PrivateData["PSData"].GetType().ToString() -eq "System.Collections.Hashtable") -and
       $PSModuleInfo.PrivateData.PSData['ExternalModuleDependencies'] -and
       ($PSModuleInfo.PrivateData.PSData['ExternalModuleDependencies'].GetType().ToString() -eq "System.Object[]")
    )
    {
        return $PSModuleInfo.PrivateData.PSData.ExternalModuleDependencies
    }
}
function Get-First
{
    param
    (
        [Parameter(Mandatory=$true)]
        $IEnumerator
    )

    foreach($item in $IEnumerator)
    {
        return $item
    }

    return $null
}
function Get-Hash
# Returns a SHA1 hash of the specified string
{
    [CmdletBinding()]
    Param
    (
        [string]
        $locationString
    )

    if(-not $locationString)
    {
        return ""
    }

    $sha1Object = New-Object System.Security.Cryptography.SHA1Managed
    $stringHash = $sha1Object.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($locationString));
    $stringHashInHex = [System.BitConverter]::ToString($stringHash)

    if ($stringHashInHex)
    {
        # Remove all dashes in the hex string
        return $stringHashInHex.Replace('-', '')
    }

    return ""
}

# Determine scope. We prefer CurrentUser scope even if the older module is installed for AllUsers, unless:
# old module is installed for all users, we are elevated, AND using Windows PowerShell
# This is to mirror newer behavior of Install-Module.
function Get-InstallationScope()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PreviousInstallLocation,

        [Parameter(Mandatory=$true)]
        [string]$CurrentUserPath
    )

    if ( -not $PreviousInstallLocation.ToString().StartsWith($currentUserPath, [System.StringComparison]::OrdinalIgnoreCase) -and
         -not $script:IsCoreCLR -and
         (Test-RunningAsElevated)) {
        $Scope = "AllUsers"
    }
    else {
        $Scope = "CurrentUser"
    }

    Write-Debug "Get-InstallationScope: $PreviousInstallLocation $($script:IsCoreCLR) $(Test-RunningAsElevated) : $Scope"
    return $Scope
}
function Get-InstalledModuleAuthenticodeSignature
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [PSModuleInfo]
        $InstalledModuleInfo,

        [Parameter(Mandatory=$true)]
        [string]
        $InstallLocation
    )

    $ModuleName = $InstalledModuleInfo.Name

    # Priority order for getting the published details of the installed module:
    # 1. Latest version under the $InstallLocation
    # 2. Latest available version in $PSModulePath
    # 3. $InstalledModuleInfo
    $AvailableModules = Microsoft.PowerShell.Core\Get-Module -ListAvailable `
                                                             -Name $ModuleName `
                                                             -ErrorAction SilentlyContinue `
                                                             -WarningAction SilentlyContinue `
                                                             -Verbose:$false |
                            Microsoft.PowerShell.Utility\Sort-Object -Property Version -Descending

    # Remove the version folder on 5.0 to get the actual module base folder without version
    if(Test-ModuleSxSVersionSupport)
    {
        $InstallLocation = Microsoft.PowerShell.Management\Split-Path -Path $InstallLocation
    }

    $SourceModule = $AvailableModules | Microsoft.PowerShell.Core\Where-Object {
                                            $_.ModuleBase.StartsWith($InstallLocation, [System.StringComparison]::OrdinalIgnoreCase)
                                        } | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

    if(-not $SourceModule)
    {
        $SourceModule = $AvailableModules | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore
    }
    else
    {
        $SourceModule = $InstalledModuleInfo
    }

    $SignedFilePath = $SourceModule.Path

    $CatalogFileName = "$ModuleName.cat"
    $CatalogFilePath = Microsoft.PowerShell.Management\Join-Path -Path $SourceModule.ModuleBase -ChildPath $CatalogFileName

    if(Microsoft.PowerShell.Management\Test-Path -Path $CatalogFilePath -PathType Leaf)
    {
        $message = $LocalizedData.CatalogFileFound -f ($CatalogFileName, $ModuleName)
        Write-Debug -Message $message

        $SignedFilePath = $CatalogFilePath
    }
    else
    {
        Write-Debug -Message ($LocalizedData.CatalogFileNotFoundInAvailableModule -f ($CatalogFileName, $ModuleName))
    }

    $message = "Using the previously-installed module '{0}' with version '{1}' under '{2}' for getting the publisher details." -f ($SourceModule.Name, $SourceModule.Version, $SourceModule.ModuleBase)
    Write-Debug -Message $message

    $message = "Using the '{0}' file for getting the authenticode signature." -f ($SignedFilePath)
    Write-Debug -Message $message

    $AuthenticodeSignature = Microsoft.PowerShell.Security\Get-AuthenticodeSignature -FilePath $SignedFilePath
    $ModuleDetails = $null

    if($AuthenticodeSignature)
    {
        $ModuleDetails = @{}
        $ModuleDetails['AuthenticodeSignature'] = $AuthenticodeSignature
        $ModuleDetails['Version'] = $SourceModule.Version
        $ModuleDetails['ModuleBase']=$SourceModule.ModuleBase
        $ModuleDetails['IsMicrosoftCertificate'] = Test-MicrosoftCertificate -AuthenticodeSignature $AuthenticodeSignature
        $PublisherDetails = Get-AuthenticodePublisher -AuthenticodeSignature $AuthenticodeSignature
        $ModuleDetails['Publisher'] = if($PublisherDetails) {$PublisherDetails.Publisher}
        $ModuleDetails['RootCertificateAuthority'] = if($PublisherDetails) {$PublisherDetails.PublisherRootCA}
        
        $message = $LocalizedData.SourceModuleDetailsForPublisherValidation -f ($ModuleName, $SourceModule.Version, $SourceModule.ModuleBase, $ModuleDetails.Publisher, $ModuleDetails.RootCertificateAuthority, $ModuleDetails.IsMicrosoftCertificate)
        Write-Debug $message
    }

    return $ModuleDetails
}
function Get-InstalledModuleDetails
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [string]
        $MinimumVersion,

        [Parameter()]
        [string]
        $MaximumVersion
    )

    Set-InstalledModulesVariable

    # Keys in $script:PSGetInstalledModules are "<ModuleName><ModuleVersion>",
    # first filter the installed modules using "$Name*" wildcard search
    # then apply $Name wildcard search to get the module name which meets the specified name with wildcards.
    #
    $wildcardPattern = New-Object System.Management.Automation.WildcardPattern "$Name*",$script:wildcardOptions
    $nameWildcardPattern = New-Object System.Management.Automation.WildcardPattern $Name,$script:wildcardOptions

    $script:PSGetInstalledModules.GetEnumerator() | Microsoft.PowerShell.Core\ForEach-Object {
                                                        if($wildcardPattern.IsMatch($_.Key))
                                                        {
                                                            $InstalledModuleDetails = $_.Value

                                                            if(-not $Name -or $nameWildcardPattern.IsMatch($InstalledModuleDetails.PSGetItemInfo.Name))
                                                            {

                                                                if (Test-ItemPrereleaseVersionRequirements -Version $InstalledModuleDetails.PSGetItemInfo.Version `
                                                                                                           -RequiredVersion $RequiredVersion `
                                                                                                           -MinimumVersion $MinimumVersion `
                                                                                                           -MaximumVersion $MaximumVersion)
                                                                {
                                                                    $InstalledModuleDetails
                                                                }
                                                            }
                                                        }
                                                    }
}
function Get-InstalledScriptDetails
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [string]
        $MinimumVersion,

        [Parameter()]
        [string]
        $MaximumVersion
    )

    Set-InstalledScriptsVariable

    # Keys in $script:PSGetInstalledScripts are "<ScriptName><ScriptVersion>",
    # first filter the installed scripts using "$Name*" wildcard search
    # then apply $Name wildcard search to get the script name which meets the specified name with wildcards.
    #
    $wildcardPattern = New-Object System.Management.Automation.WildcardPattern "$Name*",$script:wildcardOptions
    $nameWildcardPattern = New-Object System.Management.Automation.WildcardPattern $Name,$script:wildcardOptions

    $script:PSGetInstalledScripts.GetEnumerator() | Microsoft.PowerShell.Core\ForEach-Object {
                                                        if($wildcardPattern.IsMatch($_.Key))
                                                        {
                                                            $InstalledScriptDetails = $_.Value

                                                            if(-not $Name -or $nameWildcardPattern.IsMatch($InstalledScriptDetails.PSGetItemInfo.Name))
                                                            {
                                                                if (Test-ItemPrereleaseVersionRequirements -Version $InstalledScriptDetails.PSGetItemInfo.Version `
                                                                                                           -RequiredVersion $RequiredVersion `
                                                                                                           -MinimumVersion $MinimumVersion `
                                                                                                           -MaximumVersion $MaximumVersion)
                                                                {
                                                                    $InstalledScriptDetails
                                                                }
                                                            }
                                                        }
                                                    }
}
function Get-InstalledScriptFilePath
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter()]
        [string]
        $Name
    )

    $installedScriptFilePaths = @()
    $scriptFilePaths = Get-AvailableScriptFilePath @PSBoundParameters

    foreach ($scriptFilePath in $scriptFilePaths)
    {
        $scriptInfo = Test-ScriptInstalled -Name ([System.IO.Path]::GetFileNameWithoutExtension($scriptFilePath))

        if($scriptInfo)
        {
            $installedScriptInfoFilePath = $null
            $installedScriptInfoFileName = "$($scriptInfo.Name)_$script:InstalledScriptInfoFileName"

            if($scriptInfo.Path.StartsWith($script:ProgramFilesScriptsPath, [System.StringComparison]::OrdinalIgnoreCase))
            {
                $installedScriptInfoFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:ProgramFilesInstalledScriptInfosPath `
                                                                                         -ChildPath $installedScriptInfoFileName
            }
            elseif($scriptInfo.Path.StartsWith($script:MyDocumentsScriptsPath, [System.StringComparison]::OrdinalIgnoreCase))
            {
                $installedScriptInfoFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsInstalledScriptInfosPath `
                                                                                         -ChildPath $installedScriptInfoFileName
            }

            if($installedScriptInfoFilePath -and (Microsoft.PowerShell.Management\Test-Path -Path $installedScriptInfoFilePath -PathType Leaf))
            {
                $installedScriptFilePaths += $scriptInfo.Path
            }
        }
    }

    return $installedScriptFilePaths
}
function Get-LocationString
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter()]
        [Uri]
        $LocationUri
    )

    $LocationString = $null

    if($LocationUri)
    {
        if($LocationUri.Scheme -eq 'file')
        {
            $LocationString = $LocationUri.OriginalString
        }
        elseif($LocationUri.AbsoluteUri)
        {
            $LocationString = $LocationUri.AbsoluteUri
        }
        else
        {
            $LocationString = $LocationUri.ToString()
        }
    }

    return $LocationString
}
function Get-ManifestHashTable
{
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet
    )

    $Lines = $null

    try
    {
        $Lines = Get-Content -Path $Path -Force
    }
    catch
    {
        if($CallerPSCmdlet)
        {
            $CallerPSCmdlet.ThrowTerminatingError($_.Exception.ErrorRecord)
        }
    }

    if(-not $Lines)
    {
        return
    }

    $scriptBlock = [ScriptBlock]::Create( $Lines -join "`n" )

    $allowedVariables = [System.Collections.Generic.List[String]] @('PSEdition', 'PSScriptRoot')
    $allowedCommands = [System.Collections.Generic.List[String]] @()
    $allowEnvironmentVariables = $false

    try
    {
        $scriptBlock.CheckRestrictedLanguage($allowedCommands, $allowedVariables, $allowEnvironmentVariables)
    }
    catch
    {
        if($CallerPSCmdlet)
        {
            $CallerPSCmdlet.ThrowTerminatingError($_.Exception.ErrorRecord)
        }

        return
    }

    return $scriptBlock.InvokeReturnAsIs()
}
function Get-ModuleDependencies
{
    Param (
        [Parameter(Mandatory=$true)]
        [PSModuleInfo]
        $PSModuleInfo,

        [Parameter(Mandatory=$true)]
        [string]
        $Repository,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet,

        [Parameter(Mandatory=$false)]
        [pscredential]
        $Credential
    )

    $DependentModuleDetails = @()

    if($PSModuleInfo.RequiredModules -or $PSModuleInfo.NestedModules)
    {
        # PSModuleInfo.RequiredModules doesn't provide the RequiredVersion info from the ModuleSpecification
        # Reading the contents of module manifest file
        # to get the RequiredVersion details.
        $ModuleManifestHashTable = Get-ManifestHashTable -Path $PSModuleInfo.Path

        if($PSModuleInfo.RequiredModules)
        {
            $ModuleManifestRequiredModules = $null

            if($ModuleManifestHashTable)
            {
                $ModuleManifestRequiredModules = $ModuleManifestHashTable.RequiredModules
            }

            $ValidateAndGetRequiredModuleDetails_Params = @{
                ModuleManifestRequiredModules=$ModuleManifestRequiredModules
                RequiredPSModuleInfos=$PSModuleInfo.RequiredModules
                Repository=$Repository
                DependentModuleInfo=$PSModuleInfo
                CallerPSCmdlet=$CallerPSCmdlet
                Verbose=$VerbosePreference
                Debug=$DebugPreference
            }
            if ($PSBoundParameters.ContainsKey('Credential'))
            {
                $ValidateAndGetRequiredModuleDetails_Params.Add('Credential',$Credential)
            }

            $DependentModuleDetails += ValidateAndGet-RequiredModuleDetails @ValidateAndGetRequiredModuleDetails_Params
        }

        if($PSModuleInfo.NestedModules)
        {
            $ModuleManifestRequiredModules = $null

            if($ModuleManifestHashTable)
            {
                $ModuleManifestRequiredModules = $ModuleManifestHashTable.NestedModules
            }

            # A nested module is be considered as a dependency
            # 1) whose module base is not under the specified module base OR
            # 2) whose module base is under the specified module base and it's path doesn't exists
            #
            $RequiredPSModuleInfos = $PSModuleInfo.NestedModules | Microsoft.PowerShell.Core\Where-Object {
                        -not $_.ModuleBase.StartsWith($PSModuleInfo.ModuleBase, [System.StringComparison]::OrdinalIgnoreCase) -or
                        -not $_.Path -or
                        -not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $_.Path)
                    }

            $ValidateAndGetRequiredModuleDetails_Params = @{
                ModuleManifestRequiredModules=$ModuleManifestRequiredModules
                RequiredPSModuleInfos=$RequiredPSModuleInfos
                Repository=$Repository
                DependentModuleInfo=$PSModuleInfo
                CallerPSCmdlet=$CallerPSCmdlet
                Verbose=$VerbosePreference
                Debug=$DebugPreference
            }
            if ($PSBoundParameters.ContainsKey('Credential'))
            {
                $ValidateAndGetRequiredModuleDetails_Params.Add('Credential',$Credential)
            }
            $DependentModuleDetails += ValidateAndGet-RequiredModuleDetails @ValidateAndGetRequiredModuleDetails_Params
        }
    }

    return $DependentModuleDetails
}
function Get-NormalizedVersionString
{
    <#
    .DESCRIPTION
        Latest versions of nuget.exe and dotnet command generate the .nupkg file name with
        semantic version format for the modules/scripts with two part version.
        For example: package 1.0 --> package.1.0.0.nupkg
    #>
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Version
    )

    [Version]$ParsedVersion = $null
    if ([System.Version]::TryParse($Version, [ref]$ParsedVersion)) {
        $Build = $ParsedVersion.Build
        if ($Build -eq -1) {
            $Build = 0
        }

        return "$($ParsedVersion.Major).$($ParsedVersion.Minor).$Build"
    }

    return $Version
}
function Get-OrderedPSScriptInfoObject
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]
        $PSScriptInfo
    )

    $NewPSScriptInfo = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
                            $script:Name = $PSScriptInfo.$script:Name
                            $script:Version = $PSScriptInfo.$script:Version
                            $script:Guid = $PSScriptInfo.$script:Guid
                            $script:Path = $PSScriptInfo.$script:Path
                            $script:ScriptBase = $PSScriptInfo.$script:ScriptBase
                            $script:Description = $PSScriptInfo.$script:Description
                            $script:Author = $PSScriptInfo.$script:Author
                            $script:CompanyName = $PSScriptInfo.$script:CompanyName
                            $script:Copyright = $PSScriptInfo.$script:Copyright
                            $script:Tags = $PSScriptInfo.$script:Tags
                            $script:ReleaseNotes = $PSScriptInfo.$script:ReleaseNotes
                            $script:RequiredModules = $PSScriptInfo.$script:RequiredModules
                            $script:ExternalModuleDependencies = $PSScriptInfo.$script:ExternalModuleDependencies
                            $script:RequiredScripts = $PSScriptInfo.$script:RequiredScripts
                            $script:ExternalScriptDependencies = $PSScriptInfo.$script:ExternalScriptDependencies
                            $script:LicenseUri = $PSScriptInfo.$script:LicenseUri
                            $script:ProjectUri = $PSScriptInfo.$script:ProjectUri
                            $script:IconUri = $PSScriptInfo.$script:IconUri
                            $script:DefinedCommands = $PSScriptInfo.$script:DefinedCommands
                            $script:DefinedFunctions = $PSScriptInfo.$script:DefinedFunctions
                            $script:DefinedWorkflows = $PSScriptInfo.$script:DefinedWorkflows
							$script:PrivateData = $PSScriptInfo.$script:PrivateData
                        })

    $NewPSScriptInfo.PSTypeNames.Insert(0, "Microsoft.PowerShell.Commands.PSScriptInfo")

    return $NewPSScriptInfo
}
function Get-PackageManagementProviderName
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Location
    )

    $PackageManagementProviderName = $null
    $loc = Get-LocationString -LocationUri $Location

    $providers = PackageManagement\Get-PackageProvider | Where-Object { $_.Features.ContainsKey($script:SupportsPSModulesFeatureName) }

    foreach($provider in $providers)
    {
        # Skip the PowerShellGet provider
        if($provider.ProviderName -eq $script:PSModuleProviderName)
        {
            continue
        }

        $packageSource = Get-PackageSource -Location $loc -Provider $provider.ProviderName  -ErrorAction SilentlyContinue

        if($packageSource)
        {
            $PackageManagementProviderName = $provider.ProviderName
            break
        }
    }

    return $PackageManagementProviderName
}
function Get-ParametersHashtable
{
    param(
        $Proxy,
        $ProxyCredential
    )

    $ParametersHashtable = @{}
    if($Proxy)
    {
        $ParametersHashtable[$script:Proxy] = $Proxy
    }

    if($ProxyCredential)
    {
        $ParametersHashtable[$script:ProxyCredential] = $ProxyCredential
    }

    return $ParametersHashtable
}
function Get-PrivateData
#Utility function to help form the content string for PrivateData
{
    param
    (
        [System.Collections.Hashtable]
        $PrivateData
    )

    if($PrivateData.Keys.Count -eq 0)
    {
        $content = "
    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        # Tags = @()

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = `$false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable"
        return $content
    }


    #Validate each of the property of PSData is of the desired data type
    $Tags= $PrivateData["Tags"] -join "','" | Foreach-Object {"'$_'"}
    $LicenseUri = $PrivateData["LicenseUri"]| Foreach-Object {"'$_'"}
    $ProjectUri = $PrivateData["ProjectUri"] | Foreach-Object {"'$_'"}
    $IconUri = $PrivateData["IconUri"] | Foreach-Object {"'$_'"}
    $ReleaseNotesEscape = $PrivateData["ReleaseNotes"] -Replace "'","''"
    $ReleaseNotes = $ReleaseNotesEscape | Foreach-Object {"'$_'"}
    $Prerelease = $PrivateData[$script:Prerelease] | Foreach-Object {"'$_'"}
    $RequireLicenseAcceptance = $PrivateData["RequireLicenseAcceptance"]
    $ExternalModuleDependencies = $PrivateData["ExternalModuleDependencies"] -join "','" | Foreach-Object {"'$_'"}
    $DefaultProperties = @("Tags","LicenseUri","ProjectUri","IconUri","ReleaseNotes",$script:Prerelease,"ExternalModuleDependencies","RequireLicenseAcceptance")

    $ExtraProperties = @()
    foreach($key in $PrivateData.Keys)
    {
        if($DefaultProperties -notcontains $key)
        {
            $PropertyString = "#"+"$key"+ " of this module"
            $PropertyString += "`r`n    "
            if(($PrivateData[$key]).GetType().IsArray)
            {
                $PropertyString += $key +" = " +" @("
                $PrivateData[$key] | Foreach-Object { $PropertyString += "'" + $_ +"'" + "," }
                if($PrivateData[$key].Length -ge 1)
                {
                    #Remove extra ,
                    $PropertyString = $PropertyString -Replace ".$"
                }
                $PropertyString += ")"
            }
            else
            {
                $PropertyString += $key +" = " + "'"+$PrivateData[$key]+"'"
            }

            $ExtraProperties += ,$PropertyString
        }
    }

    $ExtraPropertiesString = ""
    $firstProperty = $true
    foreach($property in $ExtraProperties)
    {
        if($firstProperty)
        {
            $firstProperty = $false
        }
        else
        {
            $ExtraPropertiesString += "`r`n`r`n    "
        }
        $ExtraPropertiesString += $Property
    }

    $TagsLine ="# Tags = @()"
    if($Tags -ne "''")
    {
        $TagsLine = "Tags = "+$Tags
    }
    $LicenseUriLine = "# LicenseUri = ''"
    if($LicenseUri -ne "''")
    {
        $LicenseUriLine = "LicenseUri = "+$LicenseUri
    }
    $ProjectUriLine = "# ProjectUri = ''"
    if($ProjectUri -ne "''")
    {
        $ProjectUriLine = "ProjectUri = " +$ProjectUri
    }
    $IconUriLine = "# IconUri = ''"
    if($IconUri -ne "''")
    {
        $IconUriLine = "IconUri = " +$IconUri
    }
    $ReleaseNotesLine = "# ReleaseNotes = ''"
    if($ReleaseNotes -ne "''")
    {
        $ReleaseNotesLine = "ReleaseNotes = "+$ReleaseNotes
    }
    $PrereleaseLine = "# Prerelease = ''"
    if ($Prerelease -ne "''")
    {
        $PrereleaseLine = "Prerelease = " +$Prerelease
    }

    $RequireLicenseAcceptanceLine = "# RequireLicenseAcceptance = `$false"
    if($RequireLicenseAcceptance)
    {
        $RequireLicenseAcceptanceLine = "RequireLicenseAcceptance = `$true"
    }

    $ExternalModuleDependenciesLine ="# ExternalModuleDependencies = @()"
    if($ExternalModuleDependencies -ne "''")
    {
        $ExternalModuleDependenciesLine = "ExternalModuleDependencies = @($ExternalModuleDependencies)"
    }

    if(-not $ExtraPropertiesString -eq "")
    {
        $Content = "
    ExtraProperties

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        $TagsLine

        # A URL to the license for this module.
        $LicenseUriLine

        # A URL to the main website for this project.
        $ProjectUriLine

        # A URL to an icon representing this module.
        $IconUriLine

        # ReleaseNotes of this module
        $ReleaseNotesLine

        # Prerelease string of this module
        $PrereleaseLine

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        $RequireLicenseAcceptanceLine

        # External dependent modules of this module
        $ExternalModuleDependenciesLine

    } # End of PSData hashtable

} # End of PrivateData hashtable"

        #Replace the Extra PrivateData in the block
        $Content -replace "ExtraProperties", $ExtraPropertiesString
    }
    else
    {
        $content = "
    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        $TagsLine

        # A URL to the license for this module.
        $LicenseUriLine

        # A URL to the main website for this project.
        $ProjectUriLine

        # A URL to an icon representing this module.
        $IconUriLine

        # ReleaseNotes of this module
        $ReleaseNotesLine

        # Prerelease string of this module
        $PrereleaseLine

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        $RequireLicenseAcceptanceLine

        # External dependent modules of this module
        $ExternalModuleDependenciesLine

    } # End of PSData hashtable

 } # End of PrivateData hashtable"
        return $content
    }
}
function Get-ProviderName
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]
        $PSCustomObject
    )

    $providerName = $script:NuGetProviderName

    if((Get-Member -InputObject $PSCustomObject -Name PackageManagementProvider))
    {
        $providerName = $PSCustomObject.PackageManagementProvider
    }

    return $providerName
}
function Get-PSScriptInfoString
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Version,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Guid]
        $Guid,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Author,

        [Parameter()]
        [String]
        $CompanyName,

        [Parameter()]
        [string]
        $Copyright,

        [Parameter()]
        [String[]]
        $ExternalModuleDependencies,

        [Parameter()]
        [string[]]
        $RequiredScripts,

        [Parameter()]
        [String[]]
        $ExternalScriptDependencies,

        [Parameter()]
        [string[]]
        $Tags,

        [Parameter()]
        [Uri]
        $ProjectUri,

        [Parameter()]
        [Uri]
        $LicenseUri,

        [Parameter()]
        [Uri]
        $IconUri,

        [Parameter()]
        [string[]]
        $ReleaseNotes,

		[Parameter()]
        [string]
        $PrivateData
    )

    Process
    {
        $PSScriptInfoString = @"

<#PSScriptInfo

.VERSION$(if ($Version) {" $Version"})

.GUID$(if ($Guid) {" $Guid"})

.AUTHOR$(if ($Author) {" $Author"})

.COMPANYNAME$(if ($CompanyName) {" $CompanyName"})

.COPYRIGHT$(if ($Copyright) {" $Copyright"})

.TAGS$(if ($Tags) {" $Tags"})

.LICENSEURI$(if ($LicenseUri) {" $LicenseUri"})

.PROJECTURI$(if ($ProjectUri) {" $ProjectUri"})

.ICONURI$(if ($IconUri) {" $IconUri"})

.EXTERNALMODULEDEPENDENCIES$(if ($ExternalModuleDependencies) {" $($ExternalModuleDependencies -join ',')"}) 

.REQUIREDSCRIPTS$(if ($RequiredScripts) {" $($RequiredScripts -join ',')"})

.EXTERNALSCRIPTDEPENDENCIES$(if ($ExternalScriptDependencies) {" $($ExternalScriptDependencies -join ',')"})

.RELEASENOTES
$($ReleaseNotes -join "`r`n")

.PRIVATEDATA$(if ($PrivateData) {" $PrivateData"})

#>
"@
        return $PSScriptInfoString
    }
}
function Get-PublishLocation
{
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [String]
        $Location
    )

    $PublishLocation = $null

    if($Location)
    {
        # For local dir or SMB-share locations, ScriptPublishLocation is PublishLocation.
        if(Microsoft.PowerShell.Management\Test-Path -Path $Location)
        {
            $PublishLocation = $Location
        }
        else
        {
            $tempPublishLocation = $null

            if($Location.EndsWith('/api/v2', [System.StringComparison]::OrdinalIgnoreCase))
            {
                $tempPublishLocation = $Location + '/package/'
            }
            elseif($Location.EndsWith('/api/v2/', [System.StringComparison]::OrdinalIgnoreCase))
            {
                $tempPublishLocation = $Location + 'package/'
            }

            if($tempPublishLocation)
            {
                $PublishLocation = $tempPublishLocation
            }
        }
    }
    return $PublishLocation
}
function Get-RequiresString
{
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [Object[]]
        $RequiredModules
    )

    Process
    {
        if($RequiredModules)
        {
            $RequiredModuleStrings = @()

            foreach($requiredModuleObject in $RequiredModules)
            {
                if($requiredModuleObject.GetType().ToString() -eq 'System.Collections.Hashtable')
                {
                    if(($requiredModuleObject.Keys.Count -eq 1) -and
                        (Microsoft.PowerShell.Utility\Get-Member -InputObject $requiredModuleObject -Name 'ModuleName'))
                    {
                        $RequiredModuleStrings += $requiredModuleObject['ModuleName'].ToString()
                    }
                    else
                    {
                        $moduleSpec = New-Object Microsoft.PowerShell.Commands.ModuleSpecification -ArgumentList $requiredModuleObject
                        if (-not (Microsoft.PowerShell.Utility\Get-Variable -Name moduleSpec -ErrorAction SilentlyContinue))
                        {
                            return
                        }

                        $keyvalueStrings = $requiredModuleObject.Keys | Microsoft.PowerShell.Core\ForEach-Object {"$_ = '$( $requiredModuleObject[$_])'"}
                        $RequiredModuleStrings += "@{$($keyvalueStrings -join '; ')}"
                    }
                }
                elseif(($PSVersionTable.PSVersion -eq '3.0.0') -and
                       ($requiredModuleObject.GetType().ToString() -eq 'Microsoft.PowerShell.Commands.ModuleSpecification'))
                {
                    # ModuleSpecification.ToString() is not implemented on PowerShell 3.0.

                    $optionalString = " "

                    if($requiredModuleObject.Version)
                    {
                        $optionalString += "ModuleVersion = '$($requiredModuleObject.Version.ToString())'; "
                    }

                    if($requiredModuleObject.Guid)
                    {
                        $optionalString += "Guid = '$($requiredModuleObject.Guid.ToString())'; "
                    }

                    if($optionalString.Trim())
                    {
                        $moduleSpecString = "@{ ModuleName = '$($requiredModuleObject.Name.ToString())';$optionalString}"
                    }
                    else
                    {
                        $moduleSpecString = $requiredModuleObject.Name.ToString()
                    }

                    $RequiredModuleStrings += $moduleSpecString
                }
                else
                {
                    $RequiredModuleStrings += $requiredModuleObject.ToString()
                }
            }

            $hashRequiresStrings = $RequiredModuleStrings |
                                       Microsoft.PowerShell.Core\ForEach-Object { "#Requires -Module $_" }

            return $hashRequiresStrings
        }
        else
        {
            return ""
        }
    }
}
function Get-ScriptCommentHelpInfoString
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $Synopsis,

        [Parameter()]
        [string[]]
        $Example,

        [Parameter()]
        [string[]]
        $Inputs,

        [Parameter()]
        [string[]]
        $Outputs,

        [Parameter()]
        [string[]]
        $Notes,

        [Parameter()]
        [string[]]
        $Link,

        [Parameter()]
        [string]
        $Component,

        [Parameter()]
        [string]
        $Role,

        [Parameter()]
        [string]
        $Functionality
    )

    Process
    {
        $ScriptCommentHelpInfoString = "<# `r`n`r`n.DESCRIPTION `r`n $Description `r`n`r`n"

        if("$Synopsis".Trim())
        {
            $ScriptCommentHelpInfoString += ".SYNOPSIS `r`n$Synopsis `r`n`r`n"
        }

        if("$Example".Trim())
        {
            $Example | ForEach-Object {
                           if($_)
                           {
                               $ScriptCommentHelpInfoString += ".EXAMPLE `r`n$_ `r`n`r`n"
                           }
                       }
        }

        if("$Inputs".Trim())
        {
            $Inputs |  ForEach-Object {
                           if($_)
                           {
                               $ScriptCommentHelpInfoString += ".INPUTS `r`n$_ `r`n`r`n"
                           }
                       }
        }

        if("$Outputs".Trim())
        {
            $Outputs |  ForEach-Object {
                           if($_)
                           {
                               $ScriptCommentHelpInfoString += ".OUTPUTS `r`n$_ `r`n`r`n"
                           }
                       }
        }

        if("$Notes".Trim())
        {
            $ScriptCommentHelpInfoString += ".NOTES `r`n$($Notes -join "`r`n") `r`n`r`n"
        }

        if("$Link".Trim())
        {
            $Link |  ForEach-Object {
                         if($_)
                         {
                              $ScriptCommentHelpInfoString += ".LINK `r`n$_ `r`n`r`n"
                         }
                     }
        }

        if("$Component".Trim())
        {
            $ScriptCommentHelpInfoString += ".COMPONENT `r`n$($Component -join "`r`n") `r`n`r`n"
        }

        if("$Role".Trim())
        {
            $ScriptCommentHelpInfoString += ".ROLE `r`n$($Role -join "`r`n") `r`n`r`n"
        }

        if("$Functionality".Trim())
        {
            $ScriptCommentHelpInfoString += ".FUNCTIONALITY `r`n$($Functionality -join "`r`n") `r`n`r`n"
        }

        $ScriptCommentHelpInfoString += "#> `r`n"

        return $ScriptCommentHelpInfoString
    }
}
function Get-ScriptSourceLocation
{
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [String]
        $Location,

        [Parameter()]
        $Credential,

        [Parameter()]
        $Proxy,

        [Parameter()]
        $ProxyCredential
    )

    $scriptLocation = $null

    if($Location)
    {
        # For local dir or SMB-share locations, ScriptSourceLocation is SourceLocation.
        if(Microsoft.PowerShell.Management\Test-Path -Path $Location)
        {
            $scriptLocation = $Location
        }
        else
        {
            $tempScriptLocation = $null

            if($Location.EndsWith('/api/v2', [System.StringComparison]::OrdinalIgnoreCase))
            {
                $tempScriptLocation = $Location + '/items/psscript/'
            }
            elseif($Location.EndsWith('/api/v2/', [System.StringComparison]::OrdinalIgnoreCase))
            {
                $tempScriptLocation = $Location + 'items/psscript/'
            }

            if($tempScriptLocation)
            {
                # Ping and resolve the specified location
                $scriptLocation = Resolve-Location -Location $tempScriptLocation `
                                                   -LocationParameterName 'ScriptSourceLocation' `
                                                   -Credential $Credential `
                                                   -Proxy $Proxy `
                                                   -ProxyCredential $ProxyCredential `
                                                   -ErrorAction SilentlyContinue `
                                                   -WarningAction SilentlyContinue
            }
        }
    }
    return $scriptLocation
}
function Get-SourceLocation
{
    [CmdletBinding()]
    [OutputType("string")]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourceName
    )

    Set-ModuleSourcesVariable

    if($script:PSGetModuleSources.Contains($SourceName))
    {
        return $script:PSGetModuleSources[$SourceName].SourceLocation
    }
    else
    {
        return $SourceName
    }
}
function Get-SourceName {
    [CmdletBinding()]
    [OutputType("string")]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Location
    )

    Set-ModuleSourcesVariable

    foreach ($psModuleSource in $script:PSGetModuleSources.Values) {
        if (($psModuleSource.Name -eq $Location) -or
            (Test-EquivalentLocation -LocationA $psModuleSource.SourceLocation -LocationB $Location) -or
            ((Get-Member -InputObject $psModuleSource -Name $script:ScriptSourceLocation) -and
                (Test-EquivalentLocation -LocationA $psModuleSource.ScriptSourceLocation -LocationB $Location))) {
            return $psModuleSource.Name
        }
    }
}
function Get-UrlFromSwid
{
    param
    (
        [Parameter(Mandatory=$true)]
        $SoftwareIdentity,

        [Parameter(Mandatory=$true)]
        $UrlName
    )

    foreach($link in $SoftwareIdentity.Links)
    {
        if( $link.Relationship -eq $UrlName)
        {
            return $link.HRef
        }
    }

    return $null
}
function Get-ValidModuleLocation
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LocationString,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ParameterName,

        [Parameter()]
        $Credential,

        [Parameter()]
        $Proxy,

        [Parameter()]
        $ProxyCredential
    )

    # Get the actual Uri from the Location
    if(-not (Microsoft.PowerShell.Management\Test-Path $LocationString))
    {
        # Append '/api/v2/' to the $LocationString, return if that URI works.
        if(($LocationString -notmatch 'LinkID') -and
           -not ($LocationString.EndsWith('/nuget/v2', [System.StringComparison]::OrdinalIgnoreCase)) -and
           -not ($LocationString.EndsWith('/nuget/v2/', [System.StringComparison]::OrdinalIgnoreCase)) -and
           -not ($LocationString.EndsWith('/nuget', [System.StringComparison]::OrdinalIgnoreCase)) -and
           -not ($LocationString.EndsWith('/nuget/', [System.StringComparison]::OrdinalIgnoreCase)) -and
           -not ($LocationString.EndsWith('index.json', [System.StringComparison]::OrdinalIgnoreCase)) -and
           -not ($LocationString.EndsWith('index.json/', [System.StringComparison]::OrdinalIgnoreCase)) -and
           -not ($LocationString.EndsWith('/api/v2', [System.StringComparison]::OrdinalIgnoreCase)) -and
           -not ($LocationString.EndsWith('/api/v2/', [System.StringComparison]::OrdinalIgnoreCase))
            )
        {
            $tempLocation = $null

            if($LocationString.EndsWith('/', [System.StringComparison]::OrdinalIgnoreCase))
            {
                $tempLocation = $LocationString + 'api/v2/'
            }
            else
            {
                $tempLocation = $LocationString + '/api/v2/'
            }

            if($tempLocation)
            {
                # Ping and resolve the specified location
                $tempLocation = Resolve-Location -Location $tempLocation `
                                                 -LocationParameterName $ParameterName `
                                                 -Credential $Credential `
                                                 -Proxy $Proxy `
                                                 -ProxyCredential $ProxyCredential `
                                                 -ErrorAction SilentlyContinue `
                                                 -WarningAction SilentlyContinue
                if($tempLocation)
                {
                   return $tempLocation
                }
                # No error if we can't resolve the URL appended with '/api/v2/'
            }
        }

        # Ping and resolve the specified location
        $LocationString = Resolve-Location -Location $LocationString `
                                           -LocationParameterName $ParameterName `
                                           -Credential $Credential `
                                           -Proxy $Proxy `
                                           -ProxyCredential $ProxyCredential `
                                           -CallerPSCmdlet $PSCmdlet
    }

    return $LocationString
}
function HttpClientApisAvailable
{
    $HttpClientApisAvailable = $false
    try
    {
        [System.Net.Http.HttpClient]
        $HttpClientApisAvailable = $true
    }
    catch
    {
    }
    return $HttpClientApisAvailable
}
function Install-NuGetClientBinaries
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet,

        [parameter()]
        [switch]
        $BootstrapNuGetExe,

        [Parameter()]
        $Proxy,

        [Parameter()]
        $ProxyCredential,

        [parameter()]
        [switch]
        $Force
    )

    if ($script:NuGetProvider -and
        ($script:NuGetExeVersion -and ($script:NuGetExeVersion -ge $script:NuGetExeMinRequiredVersion))   -and
         (-not $BootstrapNuGetExe -or
         (($script:NuGetExePath -and (Microsoft.PowerShell.Management\Test-Path -Path $script:NuGetExePath)) -or
          ($script:DotnetCommandPath -and (Microsoft.PowerShell.Management\Test-Path -Path $script:DotnetCommandPath)))))
    {
        return
    }

    $bootstrapNuGetProvider = (-not $script:NuGetProvider)

    if($bootstrapNuGetProvider)
    {
        # Bootstrap the NuGet provider only if it is not available.
        # By default PackageManagement loads the latest version of the NuGet provider.
        $nugetProvider = PackageManagement\Get-PackageProvider -ErrorAction SilentlyContinue -WarningAction SilentlyContinue |
                            Microsoft.PowerShell.Core\Where-Object {
                                                                     $_.Name -eq $script:NuGetProviderName -and
                                                                     $_.Version -ge $script:NuGetProviderVersion
                                                                   }
        if($nugetProvider)
        {
            $script:NuGetProvider = $nugetProvider

            $bootstrapNuGetProvider = $false
        }
        else
        {
            # User might have installed it in an another console or in the same process, check available NuGet providers and import the required provider.
            $availableNugetProviders = PackageManagement\Get-PackageProvider -Name $script:NuGetProviderName `
                                                                             -ListAvailable `
                                                                             -ErrorAction SilentlyContinue `
                                                                             -WarningAction SilentlyContinue |
                                            Microsoft.PowerShell.Core\Where-Object {
                                                                                       $_.Name -eq $script:NuGetProviderName -and
                                                                                       $_.Version -ge $script:NuGetProviderVersion
                                                                                   }
            if($availableNugetProviders)
            {
                # Force import ensures that nuget provider with minimum version got loaded.
                $null = PackageManagement\Import-PackageProvider -Name $script:NuGetProviderName `
                                                                 -MinimumVersion $script:NuGetProviderVersion `
                                                                 -Force

                $nugetProvider = PackageManagement\Get-PackageProvider -ErrorAction SilentlyContinue -WarningAction SilentlyContinue |
                                    Microsoft.PowerShell.Core\Where-Object {
                                                                             $_.Name -eq $script:NuGetProviderName -and
                                                                             $_.Version -ge $script:NuGetProviderVersion
                                                                           }
                if($nugetProvider)
                {
                    $script:NuGetProvider = $nugetProvider

                    $bootstrapNuGetProvider = $false
                }
            }
        }
    }

    if($script:IsWindows -and -not $script:IsNanoServer) {

        if($BootstrapNuGetExe -and 
        (-not $script:NuGetExePath -or
            -not (Microsoft.PowerShell.Management\Test-Path -Path $script:NuGetExePath)) -or 
            ($script:NuGetExeVersion -and ($script:NuGetExeVersion -lt $script:NuGetExeMinRequiredVersion))   )
        {
            $programDataExePath = Microsoft.PowerShell.Management\Join-Path -Path $script:PSGetProgramDataPath -ChildPath $script:NuGetExeName
            $applocalDataExePath = Microsoft.PowerShell.Management\Join-Path -Path $script:PSGetAppLocalPath -ChildPath $script:NuGetExeName

            # Check if NuGet.exe is available under one of the predefined PowerShellGet locations under ProgramData or LocalAppData
            if( (Microsoft.PowerShell.Management\Test-Path -Path $programDataExePath) -and 
                ($programDataExePath | Microsoft.PowerShell.Core\Get-Command).Version -ge $script:NuGetExeMinRequiredVersion )
            {
                $NugetExePath = $programDataExePath
            }
            elseif( (Microsoft.PowerShell.Management\Test-Path -Path $applocalDataExePath) -and 
                ($applocalDataExePath | Microsoft.PowerShell.Core\Get-Command).Version -ge $script:NuGetExeMinRequiredVersion )
            {
                $NugetExePath = $applocalDataExePath
            }
            else
            {
                # Using Get-Command cmdlet, get the location of NuGet.exe if it is available under $env:PATH.
                # NuGet.exe does not work if it is under $env:WINDIR, so skip it from the Get-Command results.
                $nugetCmd = Microsoft.PowerShell.Core\Get-Command -Name $script:NuGetExeName `
                                                                -ErrorAction Ignore `
                                                                -WarningAction SilentlyContinue |
                                Microsoft.PowerShell.Core\Where-Object {
                                    $_.Path -and
                                    ((Microsoft.PowerShell.Management\Split-Path -Path $_.Path -Leaf) -eq $script:NuGetExeName) -and
                                    (-not $_.Path.StartsWith($env:windir, [System.StringComparison]::OrdinalIgnoreCase))
                                } | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

                if($nugetCmd -and $nugetCmd.Path -and $nugetCmd.FileVersionInfo.FileVersion)
                {
                    $NugetExePath = $nugetCmd.Path
                }
            }

            if ($NugetExePath -and (Microsoft.PowerShell.Management\Test-Path -Path $NugetExePath)) {
                $script:NuGetExePath = $NugetExePath
                $script:NuGetExeVersion = (Get-Command $script:NuGetExePath).FileVersionInfo.FileVersion
                        
                # No need to bootstrap the NuGet.exe if there is a NuGet.exe file that is at least the minimum required version found
                if ($script:NuGetExeVersion -and ($script:NuGetExeVersion -ge $script:NuGetExeMinRequiredVersion)) 
                {
                    $BootstrapNuGetExe = $false
                }
            }
        }
        else
        {
            # No need to bootstrap the NuGet.exe when $BootstrapNuGetExe is false or NuGet.exe path is already assigned.
            $BootstrapNuGetExe = $false
        }
    }


    if($BootstrapNuGetExe) {
        $DotnetCmd = Microsoft.PowerShell.Core\Get-Command -Name $script:DotnetCommandName -ErrorAction Ignore -WarningAction SilentlyContinue |
            Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

        if ($DotnetCmd -and $DotnetCmd.Path) {  
            $script:DotnetCommandPath = $DotnetCmd.Path
            $BootstrapNuGetExe = $false
        }
        else {
            if($script:IsWindows) {
                $DotnetCommandPath = Microsoft.PowerShell.Management\Join-Path -Path $env:LocalAppData -ChildPath Microsoft |
                    Microsoft.PowerShell.Management\Join-Path -ChildPath dotnet |
                        Microsoft.PowerShell.Management\Join-Path -ChildPath dotnet.exe

                if($DotnetCommandPath -and
                   -not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $DotnetCommandPath -PathType Leaf)) {
                    $DotnetCommandPath = Microsoft.PowerShell.Management\Join-Path -Path $env:ProgramFiles -ChildPath dotnet |
                        Microsoft.PowerShell.Management\Join-Path -ChildPath dotnet.exe
                }
            }
            else {
                $DotnetCommandPath = '/usr/local/bin/dotnet'
            }

            if($DotnetCommandPath -and (Microsoft.PowerShell.Management\Test-Path -LiteralPath $DotnetCommandPath -PathType Leaf)) {
                $DotnetCommandVersion,$null = (& $DotnetCommandPath '--version') -split '-',2
                if($DotnetCommandVersion -and ($script:MinimumDotnetCommandVersion -le $DotnetCommandVersion)) {
                    $script:DotnetCommandPath = $DotnetCommandPath
                    $BootstrapNuGetExe = $false
                }
            }
        }
    }

    # On non-Windows, dotnet should be installed by the user, throw an error if dotnet is not found using above logic.
    if ($BootstrapNuGetExe -and (-not $script:IsWindows -or $script:IsNanoServer)) {
        $ThrowError_params = @{
            ExceptionName    = 'System.InvalidOperationException'
            ExceptionMessage = ($LocalizedData.CouldNotFindDotnetCommand -f $script:MinimumDotnetCommandVersion, $script:DotnetInstallUrl)
            ErrorId          = 'CouldNotFindDotnetCommand'
            CallerPSCmdlet   = $CallerPSCmdlet
            ErrorCategory    = 'InvalidOperation'
        }

        ThrowError @ThrowError_params
        return
    }

    if(-not $bootstrapNuGetProvider -and -not $BootstrapNuGetExe)
    {
        return
    }


    # We should prompt only once for bootstrapping the NuGet provider and/or NuGet.exes
    if($BootstrapNuGetExe -and $script:NuGetExePath -and $bootstrapNuGetProvider)
    {
        # Should continue message for upgrading NuGet.exe and installing NuGet provider
        $shouldContinueQueryMessage = $LocalizedData.InstallNugetBinariesUpgradeShouldContinueQuery -f @($script:NuGetExeMinRequiredVersion,$script:NuGetProviderVersion,$script:NuGetBinaryProgramDataPath,$script:NuGetBinaryLocalAppDataPath,$script:PSGetProgramDataPath,$script:PSGetAppLocalPath)
        $shouldContinueCaption = $LocalizedData.InstallNuGetBinariesUpgradeShouldContinueCaption
    }
    elseif($BootstrapNuGetExe -and $bootstrapNuGetProvider)
    {
        # Should continue message for installing both NuGet.exe and NuGet provider
        $shouldContinueQueryMessage = $LocalizedData.InstallNuGetBinariesShouldContinueQuery -f @($script:NuGetExeMinRequiredVersion, $script:NuGetProviderVersion, $script:NuGetBinaryProgramDataPath, $script:NuGetBinaryLocalAppDataPath, $script:PSGetProgramDataPath,$script:PSGetAppLocalPath)
        $shouldContinueCaption = $LocalizedData.InstallNuGetBinariesShouldContinueCaption
    }
    elseif($BootstrapNuGetExe -and $script:NuGetExePath)
    {
        # Should continue message for upgrading NuGet.exe
        $shouldContinueQueryMessage = $LocalizedData.InstallNugetExeUpgradeShouldContinueQuery -f @($script:NuGetExeMinRequiredVersion, $script:PSGetProgramDataPath, $script:PSGetAppLocalPath)
        $shouldContinueCaption = $LocalizedData.InstallNuGetExeUpgradeShouldContinueCaption
    }
    elseif($BootstrapNuGetExe)
    {
        # Should continue message for installing NuGet.exe
        $shouldContinueQueryMessage = $LocalizedData.InstallNuGetExeShouldContinueQuery -f @($script:NuGetExeMinRequiredVersion, $script:PSGetProgramDataPath, $script:PSGetAppLocalPath)
        $shouldContinueCaption = $LocalizedData.InstallNuGetExeShouldContinueCaption
    }
    elseif($bootstrapNuGetProvider) {
        # Should continue message for installing NuGet Provider
        $shouldContinueQueryMessage = $LocalizedData.InstallNuGetProviderShouldContinueQuery -f @($script:NuGetProviderVersion,$script:NuGetBinaryProgramDataPath,$script:NuGetBinaryLocalAppDataPath)
        $shouldContinueCaption = $LocalizedData.InstallNuGetProviderShouldContinueCaption
    }


    $AdditionalParams = Get-ParametersHashtable -Proxy $Proxy -ProxyCredential $ProxyCredential

    if($Force -or $psCmdlet.ShouldContinue($shouldContinueQueryMessage, $shouldContinueCaption))
    {
        if($bootstrapNuGetProvider)
        {
            Write-Verbose -Message $LocalizedData.DownloadingNugetProvider

            $scope = 'CurrentUser'
            if(Test-RunningAsElevated)
            {
                $scope = 'AllUsers'
            }

            # Bootstrap the NuGet provider
            $null = PackageManagement\Install-PackageProvider -Name $script:NuGetProviderName `
                                                              -MinimumVersion $script:NuGetProviderVersion `
                                                              -Scope $scope `
                                                              -Force @AdditionalParams

            # Force import ensures that nuget provider with minimum version got loaded.
            $null = PackageManagement\Import-PackageProvider -Name $script:NuGetProviderName `
                                                             -MinimumVersion $script:NuGetProviderVersion `
                                                             -Force

            $nugetProvider = PackageManagement\Get-PackageProvider -Name $script:NuGetProviderName

            if ($nugetProvider)
            {
                $script:NuGetProvider = $nugetProvider
            }
        }

        if($BootstrapNuGetExe -and $script:IsWindows)
        {
            Write-Verbose -Message $LocalizedData.DownloadingNugetExe

            $nugetExeBasePath = $script:PSGetAppLocalPath

            # if the current process is running with elevated privileges,
            # install NuGet.exe to $script:PSGetProgramDataPath
            if(Test-RunningAsElevated)
            {
                $nugetExeBasePath = $script:PSGetProgramDataPath
            }

            if(-not (Microsoft.PowerShell.Management\Test-Path -Path $nugetExeBasePath))
            {
                $null = Microsoft.PowerShell.Management\New-Item -Path $nugetExeBasePath `
                                                                 -ItemType Directory -Force `
                                                                 -ErrorAction SilentlyContinue `
                                                                 -WarningAction SilentlyContinue `
                                                                 -Confirm:$false -WhatIf:$false
            }

            $nugetExeFilePath = Microsoft.PowerShell.Management\Join-Path -Path $nugetExeBasePath -ChildPath $script:NuGetExeName

            # Download the NuGet.exe from https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
            $null = Microsoft.PowerShell.Utility\Invoke-WebRequest -Uri $script:NuGetClientSourceURL `
                                                                   -OutFile $nugetExeFilePath `
                                                                   @AdditionalParams

            if (Microsoft.PowerShell.Management\Test-Path -Path $nugetExeFilePath)
            {
                $script:NuGetExePath = $nugetExeFilePath
                $script:NuGetExeVersion = (Get-Command $nugetExeFilePath).FileVersionInfo.FileVersion
            }
        }
    }

    $message = $null
    $errorId = $null
    $failedToBootstrapNuGetProvider = $false
    $failedToBootstrapNuGetExe = $false


    if($bootstrapNuGetProvider -and -not $script:NuGetProvider)
    {
        $failedToBootstrapNuGetProvider = $true

        $message = $LocalizedData.CouldNotInstallNuGetProvider -f @($script:NuGetProviderVersion)
        $errorId = 'CouldNotInstallNuGetProvider'
    }

    if($BootstrapNuGetExe)
    {
        if(-not $script:NuGetExePath -or
           -not (Microsoft.PowerShell.Management\Test-Path -Path $script:NuGetExePath))
        {
            $failedToBootstrapNuGetExe = $true

            $message = $LocalizedData.CouldNotInstallNuGetExe -f @($script:NuGetExeMinRequiredVersion, $script:MinimumDotnetCommandVersion)
            $errorId = 'CouldNotInstallNuGetExe'
        }
        elseif($script:NuGetExeVersion -and ($script:NuGetExeVersion -lt $script:NuGetExeMinRequiredVersion))
        {
            $failedToBootstrapNuGetExe = $true

            $message = $LocalizedData.CouldNotUpgradeNuGetExe -f @($script:NuGetExeMinRequiredVersion, $script:MinimumDotnetCommandVersion)
            $errorId = 'CouldNotUpgradeNuGetExe'
        }
    }

    # Change the error id and message if both NuGet provider and NuGet.exe are not installed.
    if($failedToBootstrapNuGetProvider -and $failedToBootstrapNuGetExe)
    {
        $message = $LocalizedData.CouldNotInstallNuGetBinaries2 -f @($script:NuGetProviderVersion)
        $errorId = 'CouldNotInstallNuGetBinaries'
    }

    # Throw the error message if one of the above conditions are met
    if($message -and $errorId)
    {
        ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId $errorId `
                    -CallerPSCmdlet $CallerPSCmdlet `
                    -ErrorCategory InvalidOperation
    }
}
function Install-PackageUtility
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FastPackageReference,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Location,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $request
    )

    Set-ModuleSourcesVariable

    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Install-PackageUtility'))

    Write-Debug ($LocalizedData.FastPackageReference -f $fastPackageReference)

    $Force = $false
    $SkipPublisherCheck = $false
    $AllowClobber = $false
    $Debug = $false
    $MinimumVersion = ""
    $RequiredVersion = ""
    $IsSavePackage = $false
    $Scope = $null
    $NoPathUpdate = $false
    $AcceptLicense = $false

    # take the fastPackageReference and get the package object again.
    $parts = $fastPackageReference -Split '[|]'

    if( $parts.Length -eq 5 )
    {
        $providerName = $parts[0]
        $packageName = $parts[1]
        $version = $parts[2]
        $sourceLocation= $parts[3]
        $artifactType = $parts[4]

        $result = ValidateAndGet-VersionPrereleaseStrings -Version $version -CallerPSCmdlet $PSCmdlet
        if (-not $result)
        {
            # ValidateAndGet-VersionPrereleaseStrings throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }
        $galleryItemVersion = $result["Version"]
        $galleryItemPrerelease = $result["Prerelease"]
        $galleryItemFullVersion = $result["FullVersion"]

        # The default destination location for Modules and Scripts is ProgramFiles path
        $scriptDestination = $script:ProgramFilesScriptsPath
        $moduleDestination = $script:programFilesModulesPath
        $Scope = 'AllUsers'

        if($artifactType -eq $script:PSArtifactTypeScript)
        {
            $AdminPrivilegeErrorMessage = $LocalizedData.InstallScriptAdminPrivilegeRequiredForAllUsersScope -f @($script:ProgramFilesScriptsPath, $script:MyDocumentsScriptsPath)
            $AdminPrivilegeErrorId = 'InstallScriptAdminPrivilegeRequiredForAllUsersScope'
        }
        else
        {
            $AdminPrivilegeErrorMessage = $LocalizedData.InstallModuleAdminPrivilegeRequiredForAllUsersScope -f @($script:programFilesModulesPath, $script:MyDocumentsModulesPath)
            $AdminPrivilegeErrorId = 'InstallModuleAdminPrivilegeRequiredForAllUsersScope'
        }

        $installUpdate = $false

        $options = $request.Options

        if($options)
        {
            foreach( $o in $options.Keys )
            {
                Write-Debug ("OPTION: {0} => {1}" -f ($o, $request.Options[$o]) )
            }

            if($options.ContainsKey('Scope'))
            {
                $Scope = $options['Scope']
                Write-Verbose ($LocalizedData.SpecifiedInstallationScope -f $Scope)

                if($Scope -eq "CurrentUser")
                {
                    $scriptDestination = $script:MyDocumentsScriptsPath
                    $moduleDestination = $script:MyDocumentsModulesPath
                }
                elseif($Scope -eq "AllUsers")
                {
                    $scriptDestination = $script:ProgramFilesScriptsPath
                    $moduleDestination = $script:programFilesModulesPath

                    if(-not (Test-RunningAsElevated))
                    {
                        # Throw an error when Install-Module/Script is used as a non-admin user and '-Scope AllUsers'
                        ThrowError -ExceptionName "System.ArgumentException" `
                                    -ExceptionMessage $AdminPrivilegeErrorMessage `
                                    -ErrorId $AdminPrivilegeErrorId `
                                    -CallerPSCmdlet $PSCmdlet `
                                    -ErrorCategory InvalidArgument
                    }
                }
            }
            elseif($Location)
            {
                $IsSavePackage = $true
                $Scope = $null

                $moduleDestination = $Location
                $scriptDestination = $Location
            }
            elseif(-not $script:IsCoreCLR -and (Test-RunningAsElevated))
            {
                # If Windows and elevated default scope will be all users
                $scriptDestination = $script:ProgramFilesScriptsPath
                $moduleDestination = $script:ProgramFilesModulesPath
            }
            else
            {
                # If non-Windows or non-elevated default scope will be current user
                $scriptDestination = $script:MyDocumentsScriptsPath
                $moduleDestination = $script:MyDocumentsModulesPath
            }

            if($options.ContainsKey('SkipPublisherCheck'))
            {
                $SkipPublisherCheck = $options['SkipPublisherCheck']

                if($SkipPublisherCheck.GetType().ToString() -eq 'System.String')
                {
                    if($SkipPublisherCheck -eq 'true')
                    {
                        $SkipPublisherCheck = $true
                    }
                    else
                    {
                        $SkipPublisherCheck = $false
                    }
                }
            }

            if($options.ContainsKey('AllowClobber'))
            {
                $AllowClobber = $options['AllowClobber']

                if($AllowClobber.GetType().ToString() -eq 'System.String')
                {
                    if($AllowClobber -eq 'false')
                    {
                        $AllowClobber = $false
                    }
                    elseif($AllowClobber -eq 'true')
                    {
                        $AllowClobber = $true
                    }
                }
            }

            if($options.ContainsKey('Force'))
            {
                $Force = $options['Force']

                if($Force.GetType().ToString() -eq 'System.String')
                {
                    if($Force -eq 'false')
                    {
                        $Force = $false
                    }
                    elseif($Force -eq 'true')
                    {
                        $Force = $true
                    }
                }
            }

            if($options.ContainsKey('AcceptLicense'))
            {
                $AcceptLicense = $options['AcceptLicense']

                if($AcceptLicense.GetType().ToString() -eq 'System.String')
                {
                    if($AcceptLicense -eq 'false')
                    {
                        $AcceptLicense = $false
                    }
                    elseif($AcceptLicense -eq 'true')
                    {
                        $AcceptLicense = $true
                    }
                }
            }

            if($options.ContainsKey('Debug'))
            {
                $Debug = $options['Debug']

                if($Debug.GetType().ToString() -eq 'System.String')
                {
                    if($Debug -eq 'false')
                    {
                        $Debug = $false
                    }
                    elseif($Debug -eq 'true')
                    {
                        $Debug = $true
                    }
                }
            }

            if($options.ContainsKey('NoPathUpdate'))
            {
                $NoPathUpdate = $options['NoPathUpdate']

                if($NoPathUpdate.GetType().ToString() -eq 'System.String')
                {
                    if($NoPathUpdate -eq 'false')
                    {
                        $NoPathUpdate = $false
                    }
                    elseif($NoPathUpdate -eq 'true')
                    {
                        $NoPathUpdate = $true
                    }
                }
            }

            if($options.ContainsKey('MinimumVersion'))
            {
                $MinimumVersion = $options['MinimumVersion']
            }

            if($options.ContainsKey('RequiredVersion'))
            {
                $RequiredVersion = $options['RequiredVersion']
            }

            if($options.ContainsKey('InstallUpdate'))
            {
                $installUpdate = $options['InstallUpdate']

                if($installUpdate.GetType().ToString() -eq 'System.String')
                {
                    if($installUpdate -eq 'false')
                    {
                        $installUpdate = $false
                    }
                    elseif($installUpdate -eq 'true')
                    {
                        $installUpdate = $true
                    }
                }
            }

            if($Scope -and ($artifactType -eq $script:PSArtifactTypeScript) -and (-not $installUpdate))
            {
                ValidateAndSet-PATHVariableIfUserAccepts -Scope $Scope `
                                                         -ScopePath $scriptDestination `
                                                         -Request $request `
                                                         -NoPathUpdate:$NoPathUpdate `
                                                         -Force:$Force
            }

            if($artifactType -eq $script:PSArtifactTypeModule)
            {
                $message = $LocalizedData.ModuleDestination -f @($moduleDestination)
            }
            else
            {
                $message = $LocalizedData.ScriptDestination -f @($scriptDestination, $moduleDestination)
            }
            Write-Verbose $message
        }

        Write-Debug "ArtifactType is $artifactType"

        if($artifactType -eq $script:PSArtifactTypeModule)
        {
            # Test if module is already installed
            $InstalledModuleInfo = if(-not $IsSavePackage){ Test-ModuleInstalled -Name $packageName -RequiredVersion $RequiredVersion }

            if(-not $Force -and $InstalledModuleInfo)
            {
                $installedModPrerelease = $null
                if ((Get-Member -InputObject $InstalledModuleInfo -Name PrivateData -ErrorAction SilentlyContinue) -and `
                    $InstalledModuleInfo.PrivateData -and `
                    $InstalledModuleInfo.PrivateData.GetType().ToString() -eq "System.Collections.Hashtable" -and `
                    ($InstalledModuleInfo.PrivateData.ContainsKey('PSData')) -and `
                    $InstalledModuleInfo.PrivateData.PSData.GetType().ToString() -eq "System.Collections.Hashtable" -and `
                    ($InstalledModuleInfo.PrivateData.PSData.ContainsKey('Prerelease')))
                {
                    $installedModPrerelease = $InstalledModuleInfo.PrivateData.PSData.Prerelease
                }

                $result = ValidateAndGet-VersionPrereleaseStrings -Version $InstalledModuleInfo.Version -Prerelease $installedModPrerelease -CallerPSCmdlet $PSCmdlet
                if (-not $result)
                {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $installedModuleVersion = $result["Version"]
                $installedModulePrerelease = $result["Prerelease"]
                $installedModuleFullVersion = $result["FullVersion"]

                if($RequiredVersion -and (Test-ModuleSxSVersionSupport))
                {
                    # Check if the module with the required version is already installed otherwise proceed to install/update.
                    if($InstalledModuleInfo)
                    {
                        $message = $LocalizedData.ModuleWithRequiredVersionAlreadyInstalled -f ($InstalledModuleInfo.Version, $InstalledModuleInfo.Name, $InstalledModuleInfo.ModuleBase, $InstalledModuleInfo.Version)
                        Write-Error -Message $message -ErrorId "ModuleWithRequiredVersionAlreadyInstalled" -Category InvalidOperation
                        return
                    }
                }
                else
                {
                    if(-not $installUpdate)
                    {
                        if ($MinimumVersion)
                        {
                            $result = ValidateAndGet-VersionPrereleaseStrings -Version $MinimumVersion -CallerPSCmdlet $PSCmdlet
                            if (-not $result)
                            {
                                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                                return
                            }
                            $minVersion = $result["Version"]
                            $minPrerelease = $result["Prerelease"]
                            $minFullVersion = $result["FullVersion"]
                        }
                        else
                        {
                            $minVersion = $null
                            $minPrerelease = $null
                            $minFullVersion = $null
                        }

                        if( (-not $MinimumVersion -and ($galleryItemFullVersion -ne $InstalledModuleFullVersion)) -or
                            ($MinimumVersion -and (Compare-PrereleaseVersions -FirstItemVersion $installedModuleVersion `
                                                                              -FirstItemPrerelease $installedModulePrerelease `
                                                                              -SecondItemVersion $minVersion `
                                                                              -SecondItemPrerelease $minPrerelease)))
                        {
                            if($PSVersionTable.PSVersion -ge '5.0.0')
                            {
                                $message = $LocalizedData.ModuleAlreadyInstalledSxS -f ($InstalledModuleFullVersion, $InstalledModuleInfo.Name, $InstalledModuleInfo.ModuleBase, $galleryItemFullVersion, $InstalledModuleFullVersion, $galleryItemFullVersion)
                            }
                            else
                            {
                                $message = $LocalizedData.ModuleAlreadyInstalled -f ($InstalledModuleFullVersion, $InstalledModuleInfo.Name, $InstalledModuleInfo.ModuleBase, $InstalledModuleFullVersion, $galleryItemFullVersion)
                            }
                            Write-Error -Message $message -ErrorId "ModuleAlreadyInstalled" -Category InvalidOperation
                        }
                        else
                        {
                            $message = $LocalizedData.ModuleAlreadyInstalledVerbose -f ($InstalledModuleFullVersion, $InstalledModuleInfo.Name, $InstalledModuleInfo.ModuleBase)
                            Write-Verbose $message
                        }

                        return
                    }
                    else
                    {
                        if (Compare-PrereleaseVersions -FirstItemVersion $installedModuleVersion `
                                                       -FirstItemPrerelease $installedModulePrerelease `
                                                       -SecondItemVersion $galleryItemVersion.ToString() `
                                                       -SecondItemPrerelease $galleryItemPrerelease)
                        {
                            $message = $LocalizedData.FoundModuleUpdate -f ($InstalledModuleInfo.Name, $galleryItemFullVersion)
                            Write-Verbose $message
                        }
                        else
                        {
                            $message = $LocalizedData.NoUpdateAvailable -f ($InstalledModuleInfo.Name)
                            Write-Verbose $message
                            return
                        }
                    }
                }
            }
        }

        if($artifactType -eq $script:PSArtifactTypeScript)
        {
            # Test if script is already installed
            $InstalledScriptInfo = if(-not $IsSavePackage){ Test-ScriptInstalled -Name $packageName }

            Write-Debug "InstalledScriptInfo is $InstalledScriptInfo"

            if(-not $Force -and $InstalledScriptInfo)
            {
                $result = ValidateAndGet-VersionPrereleaseStrings -Version $InstalledScriptInfo.Version -CallerPSCmdlet $PSCmdlet
                if (-not $result)
                {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $installedScriptInfoVersion = $result["Version"]
                $installedScriptInfoPrerelease = $result["Prerelease"]
                $installedScriptFullVersion = $result["FullVersion"]

                if(-not $installUpdate)
                {
                    if ($MinimumVersion)
                    {
                        $result = ValidateAndGet-VersionPrereleaseStrings -Version $MinimumVersion -CallerPSCmdlet $PSCmdlet
                        if (-not $result)
                        {
                            # ValidateAndGet-VersionPrereleaseStrings throws the error.
                            # returning to avoid further execution when different values are specified for -ErrorAction parameter
                            return
                        }
                        $minVersion = $result["Version"]
                        $minPrerelease = $result["Prerelease"]
                        $minFullVersion = $result["FullVersion"]
                    }
                    else
                    {
                        $minVersion = $null
                        $minPrerelease = $null
                        $minFullVersion = $null
                    }


                    if( (-not $MinimumVersion -and ($galleryItemFullVersion -ne $installedScriptFullVersion)) -or
                        ($MinimumVersion -and (Compare-PrereleaseVersions -FirstItemVersion $installedScriptInfoVersion `
                                                                          -FirstItemPrerelease $installedScriptInfoPrerelease `
                                                                          -SecondItemVersion $minVersion `
                                                                          -SecondItemPrerelease $minPrerelease) ))
                    {
                        $message = $LocalizedData.ScriptAlreadyInstalled -f ($installedScriptFullVersion, $InstalledScriptInfo.Name, $InstalledScriptInfo.ScriptBase, $installedScriptFullVersion, $galleryItemFullVersion)
                        Write-Error -Message $message -ErrorId "ScriptAlreadyInstalled" -Category InvalidOperation
                    }
                    else
                    {
                        $message = $LocalizedData.ScriptAlreadyInstalledVerbose -f ($installedScriptFullVersion, $InstalledScriptInfo.Name, $InstalledScriptInfo.ScriptBase)
                        Write-Verbose $message
                    }

                    return
                }
                else
                {
                    if (Compare-PrereleaseVersions -FirstItemVersion $installedScriptInfoVersion.ToString() `
                                                   -FirstItemPrerelease $installedScriptInfoPrerelease `
                                                   -SecondItemVersion $galleryItemVersion.ToString() `
                                                   -SecondItemPrerelease $galleryItemPrerelease)
                    {
                        $message = $LocalizedData.FoundScriptUpdate -f ($InstalledScriptInfo.Name, $version)
                        Write-Verbose $message
                    }
                    else
                    {
                        $message = $LocalizedData.NoScriptUpdateAvailable -f ($InstalledScriptInfo.Name)
                        Write-Verbose $message
                        return
                    }
                }
            }

            # Throw an error if there is a command with the same name and -force is not specified.
            if(-not $installUpdate -and
               -not $IsSavePackage -and
               -not $Force)
            {
                $cmd = Microsoft.PowerShell.Core\Get-Command -Name $packageName `
                                                             -ErrorAction Ignore `
                                                             -WarningAction SilentlyContinue
                if($cmd)
                {
                    $message = $LocalizedData.CommandAlreadyAvailable -f ($packageName)
                    Write-Error -Message $message -ErrorId CommandAlreadyAvailableWitScriptName -Category InvalidOperation
                    return
                }
            }
        }

        # create a temp folder and download the module
        $tempDestination = Microsoft.PowerShell.Management\Join-Path -Path $script:TempPath -ChildPath "$(Microsoft.PowerShell.Utility\Get-Random)"
        $null = Microsoft.PowerShell.Management\New-Item -Path $tempDestination -ItemType Directory -Force -Confirm:$false -WhatIf:$false

        try
        {
            $provider = $request.SelectProvider($providerName)
            if(-not $provider)
            {
                Write-Error -Message ($LocalizedData.PackageManagementProviderIsNotAvailable -f $providerName)
                return
            }

            if($request.IsCanceled)
            {
                return
            }

            Write-Verbose ($LocalizedData.SpecifiedLocationAndOGP -f ($provider.ProviderName, $providerName))

            $InstalledItemsList = $null
            $pkg = $script:FastPackRefHashtable[$fastPackageReference]

            # If an item has dependencies, prepare the list of installed items and
            # pass it to the NuGet provider to not download the already installed items.
            if($pkg.Dependencies.count -and
               -not $IsSavePackage -and
               -not $Force)
            {
                $InstalledItemsList = Microsoft.PowerShell.Core\Get-Module -ListAvailable |
                                        Microsoft.PowerShell.Core\ForEach-Object {"$($_.Name)!#!$($_.Version)".ToLower()}

                if($artifactType -eq $script:PSArtifactTypeScript)
                {
                    $InstalledItemsList += $script:PSGetInstalledScripts.GetEnumerator() |
                                               Microsoft.PowerShell.Core\ForEach-Object {
                                                   "$($_.Value.PSGetItemInfo.Name)!#!$($_.Value.PSGetItemInfo.Version)".ToLower()
                                               }
                }

                $InstalledItemsList | Select-Object -Unique -ErrorAction Ignore

                if($Debug)
                {
                    $InstalledItemsList | Microsoft.PowerShell.Core\ForEach-Object { Write-Debug -Message "Locally available Item: $_"}
                }
            }

            $ProviderOptions = @{
                                    Destination=$tempDestination;
                                }

            if($InstalledItemsList)
            {
                $ProviderOptions['InstalledPackages'] = $InstalledItemsList
            }

            $newRequest = $request.CloneRequest( $ProviderOptions, @($SourceLocation), $request.Credential )

            if($artifactType -eq $script:PSArtifactTypeModule)
            {
                $message = $LocalizedData.DownloadingModuleFromGallery -f ($packageName, $galleryItemFullVersion, $sourceLocation)
            }
            else
            {
                $message = $LocalizedData.DownloadingScriptFromGallery -f ($packageName, $galleryItemFullVersion, $sourceLocation)
            }
            Write-Verbose $message

            $installedPkgs = $provider.InstallPackage($script:FastPackRefHashtable[$fastPackageReference], $newRequest)

            $YesToAll = $false
            $NoToAll = $false
           
            foreach($pkg in $installedPkgs)
            {
                if($request.IsCanceled)
                {
                    return
                }

                $result = ValidateAndGet-VersionPrereleaseStrings -Version $pkg.Version -CallerPSCmdlet $PSCmdlet
                if (-not $result)
                {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $pkgVersion = $result["Version"]
                $pkgPrerelease = $result["Prerelease"]
                $pkgFullVersion = $result["FullVersion"]

                $destinationModulePath = Microsoft.PowerShell.Management\Join-Path -Path $moduleDestination -ChildPath $pkg.Name

                # Side-by-Side module version is available on PowerShell 5.0 or later versions only
                # By default, PowerShell module versions will be installed/updated Side-by-Side.
                if(Test-ModuleSxSVersionSupport)
                {
                    $destinationModulePath = Microsoft.PowerShell.Management\Join-Path -Path $destinationModulePath -ChildPath $pkgVersion
                }

                $destinationscriptPath = $scriptDestination

                # Get actual artifact type from the package
                $packageType = $script:PSArtifactTypeModule
                $installLocation = $destinationModulePath
                # Below logic handles the package folder name with version.
                $tempPackagePath = Microsoft.PowerShell.Management\Join-Path -Path $tempDestination -ChildPath "$($pkg.Name).$($pkg.Version)"
                if(-not (Microsoft.PowerShell.Management\Test-Path -Path $tempPackagePath -PathType Container))
                {
                    $message = $LocalizedData.UnableToDownloadThePackage -f ($provider.ProviderName, $pkg.Name, $pkg.Version, $tempPackagePath)
                    Write-Error -Message $message -ErrorId 'UnableToDownloadThePackage' -Category InvalidOperation
                    return
                }

                $packageFiles = Microsoft.PowerShell.Management\Get-ChildItem -Path $tempPackagePath -Recurse -Exclude "*.nupkg","*.nuspec"

                if($packageFiles -and $packageFiles.GetType().ToString() -eq 'System.IO.FileInfo' -and $packageFiles.Name -eq "$($pkg.Name).ps1")
                {
                    $packageType = $script:PSArtifactTypeScript
                    $installLocation = $destinationscriptPath
                }

                $AdditionalParams = @{}

                if(-not $IsSavePackage)
                {
                    # During the install operation:
                    #     InstalledDate should be the current Get-Date value
                    #     UpdatedDate should be null
                    #
                    # During the update operation:
                    #     InstalledDate should be from the previous version's InstalledDate otherwise current Get-Date value
                    #     UpdatedDate should be the current Get-Date value
                    #
                    $InstalledDate = Microsoft.PowerShell.Utility\Get-Date

                    if($installUpdate)
                    {
                        $AdditionalParams['UpdatedDate'] = Microsoft.PowerShell.Utility\Get-Date

                        $InstalledItemDetails = $null
                        if($packageType -eq $script:PSArtifactTypeModule)
                        {
                            $InstalledItemDetails = Get-InstalledModuleDetails -Name $pkg.Name | Select-Object -Last 1 -ErrorAction Ignore
                        }
                        elseif($packageType -eq $script:PSArtifactTypeScript)
                        {
                            $InstalledItemDetails = Get-InstalledScriptDetails -Name $pkg.Name | Select-Object -Last 1 -ErrorAction Ignore
                        }

                        if($InstalledItemDetails -and
                           $InstalledItemDetails.PSGetItemInfo -and
                           (Get-Member -InputObject $InstalledItemDetails.PSGetItemInfo -Name 'InstalledDate') -and
                           $InstalledItemDetails.PSGetItemInfo.InstalledDate)
                        {
                            $InstalledDate = $InstalledItemDetails.PSGetItemInfo.InstalledDate
                        }
                    }

                    $AdditionalParams['InstalledDate'] = $InstalledDate
                }

                # construct the PSGetItemInfo from SoftwareIdentity and persist it
                $psgItemInfo = New-PSGetItemInfo -SoftwareIdentity $pkg `
                                                 -PackageManagementProviderName $provider.ProviderName `
                                                 -SourceLocation $sourceLocation `
                                                 -Type $packageType `
                                                 -InstalledLocation $installLocation `
                                                 @AdditionalParams

                if($packageType -eq $script:PSArtifactTypeModule)
                {
                    if ($psgItemInfo.PowerShellGetFormatVersion -and
                        ($script:SupportedPSGetFormatVersionMajors -notcontains $psgItemInfo.PowerShellGetFormatVersion.Major))
                    {
                        $message = $LocalizedData.NotSupportedPowerShellGetFormatVersion -f ($psgItemInfo.Name, $psgItemInfo.PowerShellGetFormatVersion, $psgItemInfo.Name)
                        Write-Error -Message $message -ErrorId "NotSupportedPowerShellGetFormatVersion" -Category InvalidOperation
                        continue
                    }

                    $sourceModulePath = $tempPackagePath
                    if($psgItemInfo.PowerShellGetFormatVersion -eq "1.0")
                    {
                        $sourceModulePath = Microsoft.PowerShell.Management\Join-Path -Path $sourceModulePath -ChildPath 'Content' |
                            Microsoft.PowerShell.Management\Join-Path -ChildPath '*' |
                                Microsoft.PowerShell.Management\Join-Path -ChildPath $script:ModuleReferences |
                                    Microsoft.PowerShell.Management\Join-Path -ChildPath $pkg.Name
                    }

                    #Prompt if module requires license Acceptance
                    $requireLicenseAcceptance = $false
                    if($psgItemInfo.PowerShellGetFormatVersion -and
                       $psgItemInfo.PowerShellGetFormatVersion -ge $script:PSGetRequireLicenseAcceptanceFormatVersion)
                     {
                        if($psgItemInfo.AdditionalMetadata -and $psgItemInfo.AdditionalMetadata.requireLicenseAcceptance)
                        {
                              $requireLicenseAcceptance = $psgItemInfo.AdditionalMetadata.requireLicenseAcceptance
                        }
                    }

                    if($requireLicenseAcceptance -eq $true)
                    {
                        if($Force -and -not($AcceptLicense))
                        {
                            $message = $LocalizedData.ForceAcceptLicense -f $pkg.Name

                            ThrowError -ExceptionName "System.ArgumentException" `
                                       -ExceptionMessage $message `
                                       -ErrorId "ForceAcceptLicense" `
                                       -CallerPSCmdlet $PSCmdlet `
                                       -ErrorCategory InvalidArgument
                        }

                        If (-not ($YesToAll -or $NoToAll -or $AcceptLicense))
                        {
                            $LicenseFilePath = Join-PathUtility -Path $sourceModulePath -ChildPath 'License.txt' -PathType File
                            if(-not(Test-Path -Path $LicenseFilePath -PathType Leaf))
                            {
                                $message = $LocalizedData.LicenseTxtNotFound

                                ThrowError -ExceptionName "System.ArgumentException" `
                                           -ExceptionMessage $message `
                                           -ErrorId "LicenseTxtNotFound" `
                                           -CallerPSCmdlet $PSCmdlet `
                                           -ErrorCategory ObjectNotFound
                            }
                            $FormattedEula = (Get-Content -Path $LicenseFilePath) -Join "`r`n"
                            $message = $FormattedEula + "`r`n" + ($LocalizedData.AcceptanceLicenseQuery -f $pkg.Name)
                            $title = $LocalizedData.AcceptLicense
                            $result = $request.ShouldContinue($message, $title, [ref]$yesToAll, [ref]$NoToAll)
                            if(($result -eq $false) -or ($NoToAll -eq $true))
                            {
                                Write-Warning -Message $LocalizedData.UserDeclinedLicenseAcceptance
                                return
                            }
                        }
                    }

                    $CurrentModuleInfo = $null

                    # Validate the module
                    if(-not $IsSavePackage)
                    {
                        $CurrentModuleInfo = Test-ValidManifestModule -ModuleBasePath $sourceModulePath `
                                                                      -ModuleName $pkg.Name `
                                                                      -InstallLocation $InstallLocation `
                                                                      -AllowClobber:$AllowClobber `
                                                                      -SkipPublisherCheck:$SkipPublisherCheck `
                                                                      -IsUpdateOperation:$installUpdate

                        if(-not $CurrentModuleInfo)
                        {
                            Write-Verbose -Message ($LocalizedData.ModuleValidationFailed -f $ModuleName,$ModuleBasePath)
                            # This Install-Package provider API gets called once per an item/package/SoftwareIdentity.
                            # Return if there is an error instead of continuing further to install the dependencies or current module.
                            #
                            return
                        }
                    }

                    # Test if module is already installed
                    $InstalledModuleInfo2 = if(-not $IsSavePackage){ Test-ModuleInstalled -Name $pkg.Name -RequiredVersion $pkgFullVersion }

                    if($pkg.Name -ne $packageName)
                    {
                        if(-not $Force -and $InstalledModuleInfo2)
                        {
                            $result = ValidateAndGet-VersionPrereleaseStrings -Version $InstalledModuleInfo2.Version -CallerPSCmdlet $PSCmdlet
                            if (-not $result)
                            {
                                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                                return
                            }
                            $installedModuleVersion = $result["Version"]
                            $installedModulePrerelease = $result["Prerelease"]
                            $installedModuleFullVersion = $result["FullVersion"]

                            if(Test-ModuleSxSVersionSupport)
                            {
                                if($pkgFullVersion -eq $installedModuleFullVersion)
                                {
                                    if(-not $installUpdate)
                                    {
                                        $message = $LocalizedData.ModuleWithRequiredVersionAlreadyInstalled -f ($installedModuleFullVersion, $InstalledModuleInfo2.Name, $InstalledModuleInfo2.ModuleBase, $InstalledModuleFullVersion)
                                    }
                                    else
                                    {
                                        $message = $LocalizedData.NoUpdateAvailable -f ($pkg.Name)
                                    }

                                    Write-Verbose $message
                                    Continue
                                }
                            }
                            else
                            {
                                if(-not $installUpdate)
                                {
                                    $message = $LocalizedData.ModuleAlreadyInstalledVerbose -f ($InstalledModuleFullVersion, $InstalledModuleInfo2.Name, $InstalledModuleInfo2.ModuleBase)
                                    Write-Verbose $message
                                    Continue
                                }
                                else
                                {
                                    if(Compare-PrereleaseVersions -FirstItemVersion $installedModuleVersion.ToString() `
                                                                  -FirstItemPrerelease $installedModPrerelease `
                                                                  -SecondItemVersion $pkgVersion.ToString() `
                                                                  -SecondItemPrerelease $pkgPrerelease)
                                    {
                                        $message = $LocalizedData.FoundModuleUpdate -f ($pkg.Name, $pkgFullVersion)
                                        Write-Verbose $message
                                    }
                                    else
                                    {
                                        $message = $LocalizedData.NoUpdateAvailable -f ($pkg.Name)
                                        Write-Verbose $message
                                        Continue
                                    }
                                }
                            }
                        }

                        if($IsSavePackage)
                        {
                            $DependencyInstallMessage = $LocalizedData.SavingDependencyModule -f ($pkg.Name, $pkgFullVersion, $packageName)
                        }
                        else
                        {
                            $DependencyInstallMessage = $LocalizedData.InstallingDependencyModule -f ($pkg.Name, $pkgFullVersion, $packageName)
                        }

                        Write-Verbose  $DependencyInstallMessage
                    }

                    # check if module is in use
                    if($InstalledModuleInfo2)
                    {
                        $moduleInUse = Test-ModuleInUse -ModuleBasePath $InstalledModuleInfo2.ModuleBase `
                                                        -ModuleName $InstalledModuleInfo2.Name `
                                                        -ModuleVersion $InstalledModuleInfo2.Version `
                                                        -Verbose:$VerbosePreference `
                                                        -WarningAction $WarningPreference `
                                                        -ErrorAction $ErrorActionPreference `
                                                        -Debug:$DebugPreference

                        if($moduleInUse)
                        {
                            $message = $LocalizedData.ModuleIsInUse -f ($psgItemInfo.Name)
                            Write-Verbose $message
                            continue
                        }
                    }

                    # Use the actual module version retrieved from the module manifest.
                    if($CurrentModuleInfo -and (Test-ModuleSxSVersionSupport) -and -not $pkgPrerelease)
                    {
                        $destinationModulePath = Microsoft.PowerShell.Management\Join-Path -Path $moduleDestination -ChildPath $pkg.Name |
                            Microsoft.PowerShell.Management\Join-Path -ChildPath $CurrentModuleInfo.Version
                        $installLocation = $destinationModulePath
                        $psgItemInfo.InstalledLocation = $installLocation
                        $psgItemInfo.Version = $CurrentModuleInfo.Version
                    }

                    Copy-Module -SourcePath $sourceModulePath -DestinationPath $destinationModulePath -PSGetItemInfo $psgItemInfo -IsSavePackage:$IsSavePackage

                    if(-not $IsSavePackage)
                    {
                        # Write warning messages if externally managed module dependencies are not installed.
                        $ExternalModuleDependencies = Get-ExternalModuleDependencies -PSModuleInfo $CurrentModuleInfo
                        foreach($ExternalDependency in $ExternalModuleDependencies)
                        {
                            $depModuleInfo = Test-ModuleInstalled -Name $ExternalDependency

                            if(-not $depModuleInfo)
                            {
                                Write-Warning -Message ($LocalizedData.MissingExternallyManagedModuleDependency -f $ExternalDependency,$pkg.Name,$ExternalDependency)
                            }
                            else
                            {
                                Write-Verbose -Message ($LocalizedData.ExternallyManagedModuleDependencyIsInstalled -f $ExternalDependency)
                            }
                        }
                    }

                    if($IsSavePackage)
                    {
                        $message = $LocalizedData.ModuleSavedSuccessfully -f ($psgItemInfo.Name, $installLocation)
                    }
                    else
                    {
                        $message = $LocalizedData.ModuleInstalledSuccessfully -f ($psgItemInfo.Name, $installLocation)
                    }
                    Write-Verbose $message
                }


                if($packageType -eq $script:PSArtifactTypeScript)
                {
                    if ($psgItemInfo.PowerShellGetFormatVersion -and
                        ($script:SupportedPSGetFormatVersionMajors -notcontains $psgItemInfo.PowerShellGetFormatVersion.Major))
                    {
                        $message = $LocalizedData.NotSupportedPowerShellGetFormatVersionScripts -f ($psgItemInfo.Name, $psgItemInfo.PowerShellGetFormatVersion, $psgItemInfo.Name)
                        Write-Error -Message $message -ErrorId "NotSupportedPowerShellGetFormatVersion" -Category InvalidOperation
                        continue
                    }

                    $sourceScriptPath = Join-PathUtility -Path $tempPackagePath -ChildPath "$($pkg.Name).ps1" -PathType File

                    $currentScriptInfo = $null
                    if(-not $IsSavePackage)
                    {
                        # Validate the script
                        $currentScriptInfo = Test-ScriptFileInfo -Path $sourceScriptPath -ErrorAction SilentlyContinue

                        if(-not $currentScriptInfo)
                        {
                            $message = $LocalizedData.InvalidPowerShellScriptFile -f ($pkg.Name)
                            Write-Error -Message $message -ErrorId "InvalidPowerShellScriptFile" -Category InvalidOperation -TargetObject $pkg.Name
                            continue
                        }

                        # Use the version extracted from the script file.
                        $psgItemInfo.Version = $currentScriptInfo.Version
                    }

                    # Test if script is already installed
                    $InstalledScriptInfo2 = if(-not $IsSavePackage){ Test-ScriptInstalled -Name $pkg.Name }


                    if($pkg.Name -ne $packageName)
                    {
                        if(-not $Force -and $InstalledScriptInfo2)
                        {
                            $result = ValidateAndGet-VersionPrereleaseStrings -Version $InstalledScriptInfo2.Version -CallerPSCmdlet $PSCmdlet
                            if (-not $result)
                            {
                                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                                return
                            }
                            $installedScriptFullVersion = $result["FullVersion"]

                            if(-not $installUpdate)
                            {
                                $message = $LocalizedData.ScriptAlreadyInstalledVerbose -f ($InstalledScriptFullVersion, $InstalledScriptInfo2.Name, $InstalledScriptInfo2.ScriptBase)
                                Write-Verbose $message
                                Continue
                            }
                            else
                            {
                                if(Compare-PrereleaseVersions -FirstItemVersion $installedScriptInfoVersion.ToString() `
                                                              -FirstItemPrerelease $installedScriptInfoPrerelease `
                                                              -SecondItemVersion $pkgVersion `
                                                              -SecondItemPrerelease $pkgPrerelease)
                                {
                                    $message = $LocalizedData.FoundScriptUpdate -f ($pkg.Name, $pkgFullVersion)
                                    Write-Verbose $message
                                }
                                else
                                {
                                    $message = $LocalizedData.NoScriptUpdateAvailable -f ($pkg.Name)
                                    Write-Verbose $message
                                    Continue
                                }
                            }
                        }

                        if($IsSavePackage)
                        {
                            $DependencyInstallMessage = $LocalizedData.SavingDependencyScript -f ($pkg.Name, $pkgFullVersion, $packageName)
                        }
                        else
                        {
                            $DependencyInstallMessage = $LocalizedData.InstallingDependencyScript -f ($pkg.Name, $pkgFullVersion, $packageName)
                        }

                        Write-Verbose  $DependencyInstallMessage
                    }

                    Write-Debug "SourceScriptPath is $sourceScriptPath and DestinationscriptPath is $destinationscriptPath"
                    Copy-ScriptFile -SourcePath $sourceScriptPath -DestinationPath $destinationscriptPath -PSGetItemInfo $psgItemInfo -Scope $Scope

                    if(-not $IsSavePackage)
                    {
                        # Write warning messages if externally managed module dependencies are not installed.
                        foreach($ExternalDependency in $currentScriptInfo.ExternalModuleDependencies)
                        {
                            $depModuleInfo = Test-ModuleInstalled -Name $ExternalDependency

                            if(-not $depModuleInfo)
                            {
                                Write-Warning -Message ($LocalizedData.ScriptMissingExternallyManagedModuleDependency -f $ExternalDependency,$pkg.Name,$ExternalDependency)
                            }
                            else
                            {
                                Write-Verbose -Message ($LocalizedData.ExternallyManagedModuleDependencyIsInstalled -f $ExternalDependency)
                            }
                        }

                        # Write warning messages if externally managed script dependencies are not installed.
                        foreach($ExternalDependency in $currentScriptInfo.ExternalScriptDependencies)
                        {
                            $depScriptInfo = Test-ScriptInstalled -Name $ExternalDependency

                            if(-not $depScriptInfo)
                            {
                                Write-Warning -Message ($LocalizedData.ScriptMissingExternallyManagedScriptDependency -f $ExternalDependency,$pkg.Name,$ExternalDependency)
                            }
                            else
                            {
                                Write-Verbose -Message ($LocalizedData.ScriptExternallyManagedScriptDependencyIsInstalled -f $ExternalDependency)
                            }
                        }
                    }

                    # Remove the old scriptfile if it's path different from the required destination script path when -Force is specified
                    if($Force -and
                        $InstalledScriptInfo2 -and
                        -not $destinationscriptPath.StartsWith($InstalledScriptInfo2.ScriptBase, [System.StringComparison]::OrdinalIgnoreCase))
                    {
                        Microsoft.PowerShell.Management\Remove-Item -Path $InstalledScriptInfo2.Path `
                                                                    -Force `
                                                                    -ErrorAction SilentlyContinue `
                                                                    -WarningAction SilentlyContinue `
                                                                    -Confirm:$false -WhatIf:$false
                    }

                    if($IsSavePackage)
                    {
                        $message = $LocalizedData.ScriptSavedSuccessfully -f ($psgItemInfo.Name, $installLocation)
                    }
                    else
                    {
                        $message = $LocalizedData.ScriptInstalledSuccessfully -f ($psgItemInfo.Name, $installLocation)
                    }
                    Write-Verbose $message
                }

                $sid = New-SoftwareIdentityFromPackage -Package $pkg `
                    -SourceLocation $sourceLocation `
                    -PackageManagementProviderName $provider.ProviderName `
                    -Request $request `
                    -Type $packageType `
                    -InstalledLocation $installLocation `
                    @AdditionalParams

                Write-Output -InputObject $sid
            }
        }
        finally
        {
            Microsoft.PowerShell.Management\Remove-Item $tempDestination -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }
    }
}
function Join-PathUtility
{
    <#
    .DESCRIPTION
        Utility to get the case-sensitive path, if exists.
        Otherwise, returns the output of Join-Path cmdlet.
        This is required for getting the case-sensitive paths on non-Windows platforms.
    #>
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $false)]
        [string]
        $ChildPath,

        [Parameter(Mandatory = $true)]
        [string]
        [ValidateSet('File', 'Directory', 'Any')]
        $PathType = 'Any'
    )

    $JoinedPath = Microsoft.PowerShell.Management\Join-Path -Path $Path -ChildPath $ChildPath
    if(Microsoft.PowerShell.Management\Test-Path -Path $Path -PathType Container) {
        $GetChildItem_params = @{
            Path = $Path
            ErrorAction = 'SilentlyContinue'
            WarningAction = 'SilentlyContinue'
        }
        if($PathType -eq 'File') {
            $GetChildItem_params['File'] = $true
        }
        elseif($PathType -eq 'Directory') {
            $GetChildItem_params['Directory'] = $true
        }

        $FoundPath = Microsoft.PowerShell.Management\Get-ChildItem @GetChildItem_params |
            Where-Object {$_.Name -eq $ChildPath} |
                ForEach-Object {$_.FullName} |
                    Select-Object -First 1 -ErrorAction SilentlyContinue

        if($FoundPath) {
            $JoinedPath = $FoundPath
        }
    }

    return $JoinedPath
}
function Log-ArtifactNotFoundInPSGallery
{
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [string[]]
        $SearchedName,

        [Parameter()]
        [string[]]
        $FoundName,

        [Parameter(Mandatory=$true)]
        [string]
        $operationName
    )

    if (-not $script:TelemetryEnabled)
    {
        return
    }

    if(-not $SearchedName)
    {
        return
    }

    $SearchedNameNoWildCards = @()

    # Ignore wild cards
    foreach ($artifactName in $SearchedName)
    {
        if (-not (Test-WildcardPattern $artifactName))
        {
            $SearchedNameNoWildCards += $artifactName
        }
    }

    # Find artifacts searched, but not found in the specified gallery
    $notFoundArtifacts = @()
    foreach ($element in $SearchedNameNoWildCards)
    {
        if (-not ($FoundName -contains $element))
        {
            $notFoundArtifacts += $element
        }
    }

    # Perform Telemetry only if searched artifacts are not available in specified Gallery
    if ($notFoundArtifacts)
    {
        [Microsoft.PowerShell.Commands.PowerShellGet.Telemetry]::TraceMessageArtifactsNotFound($notFoundArtifacts, $operationName)
    }
}
function Log-NonPSGalleryRegistration
# Function to record non-PSGallery registration for telemetry
# Function consumes the type of registration (i.e hosted (http(s)), non-hosted (file/unc)), locations, installation policy, provider and event name
{
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [string]
        $sourceLocation,

        [Parameter()]
        [string]
        $installationPolicy,

        [Parameter()]
        [string]
        $packageManagementProvider,

        [Parameter()]
        [string]
        $publishLocation,

        [Parameter()]
        [string]
        $scriptSourceLocation,

        [Parameter()]
        [string]
        $scriptPublishLocation,

        [Parameter(Mandatory=$true)]
        [string]
        $operationName
    )

    if (-not $script:TelemetryEnabled)
    {
        return
    }

    # Initialize source location type - this can be hosted (http(s)) or not hosted (unc/file)
    $sourceLocationType = "NON_WEB_HOSTED"
    if (Test-WebUri -uri $sourceLocation)
    {
        $sourceLocationType = "WEB_HOSTED"
    }

    # Create a hash of the source location
    # We cannot log the actual source location, since this might contain PII (Personally identifiable information) data
    $sourceLocationHash = Get-Hash -locationString $sourceLocation
    $publishLocationHash = Get-Hash -locationString $publishLocation
    $scriptSourceLocationHash = Get-Hash -locationString $scriptSourceLocation
    $scriptPublishLocationHash = Get-Hash -locationString $scriptPublishLocation

    # Log the telemetry event
    [Microsoft.PowerShell.Commands.PowerShellGet.Telemetry]::TraceMessageNonPSGalleryRegistration($sourceLocationType, $sourceLocationHash, $installationPolicy, $packageManagementProvider, $publishLocationHash, $scriptSourceLocationHash, $scriptPublishLocationHash, $operationName)
}
function New-FastPackageReference
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $ProviderName,

        [Parameter(Mandatory=$true)]
        [string]
        $PackageName,

        [Parameter(Mandatory=$true)]
        [string]
        $Version,

        [Parameter(Mandatory=$true)]
        [string]
        $Source,

        [Parameter(Mandatory=$true)]
        [string]
        $ArtifactType
    )

    return "$ProviderName|$PackageName|$Version|$Source|$ArtifactType"
}
function New-ModuleSourceFromPackageSource
{
    param
    (
        [Parameter(Mandatory=$true)]
        $PackageSource
    )

    $moduleSource = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
            Name = $PackageSource.Name
            SourceLocation =  $PackageSource.Location
            Trusted=$PackageSource.IsTrusted
            Registered=$PackageSource.IsRegistered
            InstallationPolicy = $PackageSource.Details['InstallationPolicy']
            PackageManagementProvider=$PackageSource.Details['PackageManagementProvider']
            PublishLocation=$PackageSource.Details[$script:PublishLocation]
            ScriptSourceLocation=$PackageSource.Details[$script:ScriptSourceLocation]
            ScriptPublishLocation=$PackageSource.Details[$script:ScriptPublishLocation]
            ProviderOptions = @{}
        })

    $PackageSource.Details.GetEnumerator() | Microsoft.PowerShell.Core\ForEach-Object {
                                                if($_.Key -ne 'PackageManagementProvider' -and
                                                   $_.Key -ne $script:PublishLocation -and
                                                   $_.Key -ne $script:ScriptPublishLocation -and
                                                   $_.Key -ne $script:ScriptSourceLocation -and
                                                   $_.Key -ne 'InstallationPolicy')
                                                {
                                                    $moduleSource.ProviderOptions[$_.Key] = $_.Value
                                                }
                                             }

    $moduleSource.PSTypeNames.Insert(0, "Microsoft.PowerShell.Commands.PSRepository")

    # return the module source object.
    Write-Output -InputObject $moduleSource
}
function New-NugetPackage {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$NuspecPath,

        [Parameter(Mandatory = $true)]
        [string]$NugetPackageRoot,

        [Parameter()]
        [string]$OutputPath = $NugetPackageRoot,

        [Parameter(Mandatory = $true, ParameterSetName = "UseNuget")]
        [string]$NugetExePath,

        [Parameter(ParameterSetName = "UseDotnetCli")]
        [switch]$UseDotnetCli

    )
    Set-StrictMode -Off

    Write-Verbose "Calling New-NugetPackage"

    if (-Not(Test-Path -Path $NuspecPath -PathType Leaf)) {
        throw "A nuspec file does not exist at $NuspecPath, provide valid path to a .nuspec"
    }

    if (-Not(Test-Path -Path $NugetPackageRoot)) {
        throw "NugetPackageRoot $NugetPackageRoot does not exist"
    }

    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo

    if ($PSCmdlet.ParameterSetName -eq "UseNuget") {
        if (-Not(Test-Path -Path $NuGetExePath)) {
            throw "Nuget.exe does not exist at $NugetExePath, provide a valid path to nuget.exe"
        }
        $ProcessName = $NugetExePath

        $ArgumentList = @("pack")
        $ArgumentList += "`"$NuspecPath`""
        $ArgumentList += "-outputdirectory `"$OutputPath`" -noninteractive"

        $tempPath = $null
    }
    else {
        # use Dotnet CLI

        #perform dotnet pack using a temporary project file.
        $ProcessName = (Get-Command -Name "dotnet").Source
        $tempPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid()).Guid
        New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

        $CsprojContent = @"
<Project Sdk="Microsoft.NET.Sdk">
<PropertyGroup>
    <AssemblyName>NotUsed</AssemblyName>
    <Description>Temp project used for creating nupkg file.</Description>
    <TargetFramework>netcoreapp2.0</TargetFramework>
    <IsPackable>true</IsPackable>
</PropertyGroup>
</Project>
"@
        $projectFile = New-Item -ItemType File -Path $tempPath -Name "Temp.csproj"
        Set-Content -Value $CsprojContent -Path $projectFile

        $ArgumentList = @("pack")
        $ArgumentList += "`"$projectFile`""
        $ArgumentList += "/p:NuspecFile=`"$NuspecPath`""
        $ArgumentList += "--output `"$OutputPath`""
    }

    # run the packing program
    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = $ProcessName
    $processStartInfo.Arguments = $ArgumentList
    $processStartInfo.RedirectStandardError = $true
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.UseShellExecute = $false

    Write-Verbose "Calling $ProcessName $($ArgumentList -join ' ')"
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processStartInfo

    $process.Start() | Out-Null

    # read output incrementally, it'll block if it writes too much
    $outputLines = @()
    Write-Verbose "$ProcessName output:"
    while (! $process.HasExited) {
        $output = $process.StandardOutput.ReadLine()
        Write-Verbose "`t$output"
        $outputLines += $output
    }

    # get any remaining output
    $process.WaitForExit()
    $outputLines += $process.StandardOutput.ReadToEnd()

    $stdOut = $outputLines -join "`n"

    Write-Verbose "finished running $($processStartInfo.FileName) with exit code $($process.ExitCode)"

    if (($tempPath -ne $null) -and (Test-Path -Path $tempPath)) {
        Remove-Item -Path $tempPath -Force -Recurse
    }

    if (-Not ($process.ExitCode -eq 0 )) {
        # nuget writes errors to stdErr, dotnet writes them to stdOut
        if ($UseDotnetCli) {
            $errors = $stdOut
        }
        else {
            $errors = $process.StandardError.ReadToEnd()
        }
        throw "$ProcessName failed to pack: error $errors"
    }

    $stdOut -match "Successfully created package '(.*.nupkg)'" | Out-Null
    $nupkgFullFile = $matches[1]

    Write-Verbose "Created Nuget Package $nupkgFullFile"
    Write-Output $nupkgFullFile
}
function New-NuspecFile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string[]]$Authors,

        [Parameter()]
        [string[]]$Owners,

        [Parameter()]
        [string]$ReleaseNotes,

        [Parameter()]
        [bool]$RequireLicenseAcceptance,

        [Parameter()]
        [string]$Copyright,

        [Parameter()]
        [string[]]$Tags,

        [Parameter()]
        [string]$LicenseUrl,

        [Parameter()]
        [string]$ProjectUrl,

        [Parameter()]
        [string]$IconUrl,

        [Parameter()]
        [PSObject[]]$Dependencies,

        [Parameter()]
        [PSObject[]]$Files

    )
    Set-StrictMode -Off

    Write-Verbose "Calling New-NuspecFile"

    $nameSpaceUri = "http://schemas.microsoft.com/packaging/2011/08/nuspec.xsd"
    [xml]$xml = New-Object System.Xml.XmlDocument

    $xmlDeclaration = $xml.CreateXmlDeclaration("1.0", "utf-8", $null)
    $xml.AppendChild($xmlDeclaration) | Out-Null

    #create top-level elements
    $packageElement = $xml.CreateElement("package", $nameSpaceUri)
    $metaDataElement = $xml.CreateElement("metadata", $nameSpaceUri)

    # warn we're over 4000 characters for standard nuget servers
    $tagsString = $Tags -Join " "
    if ($tagsString.Length -gt 4000) {
        Write-Warning -Message "Tag list exceeded 4000 characters and may not be accepted by some Nuget feeds."
    }

    $metaDataElementsHash = [ordered]@{
        id                       = $Id
        version                  = $Version
        description              = $Description
        authors                  = $Authors -Join ","
        owners                   = $Owners -Join ","
        releaseNotes             = $ReleaseNotes
        requireLicenseAcceptance = $RequireLicenseAcceptance.ToString().ToLower()
        copyright                = $Copyright
        tags                     = $tagsString
    }

    if ($LicenseUrl) { $metaDataElementsHash.Add("licenseUrl", $LicenseUrl) }
    if ($ProjectUrl) { $metaDataElementsHash.Add("projectUrl", $ProjectUrl) }
    if ($IconUrl) { $metaDataElementsHash.Add("iconUrl", $IconUrl) }

    foreach ($key in $metaDataElementsHash.Keys) {
        $element = $xml.CreateElement($key, $nameSpaceUri)
        $elementInnerText = $metaDataElementsHash.item($key)
        $element.InnerText = $elementInnerText

        $metaDataElement.AppendChild($element) | Out-Null
    }


    if ($Dependencies) {
        $dependenciesElement = $xml.CreateElement("dependencies", $nameSpaceUri)

        foreach ($dependency in $Dependencies) {
            $element = $xml.CreateElement("dependency", $nameSpaceUri)
            $element.SetAttribute("id", $dependency.id)
            if ($dependency.version) { $element.SetAttribute("version", $dependency.version) }

            $dependenciesElement.AppendChild($element) | Out-Null
        }
        $metaDataElement.AppendChild($dependenciesElement) | Out-Null
    }

    if ($Files) {
        $filesElement = $xml.CreateElement("files", $nameSpaceUri)

        foreach ($file in $Files) {
            $element = $xml.CreateElement("file", $nameSpaceUri)
            $element.SetAttribute("src", $file.src)
            if ($file.target) { $element.SetAttribute("target", $file.target) }
            if ($file.exclude) { $element.SetAttribute("exclude", $file.exclude) }

            $filesElement.AppendChild($element) | Out-Null
        }
    }

    $packageElement.AppendChild($metaDataElement) | Out-Null
    if ($filesElement) { $packageElement.AppendChild($filesElement) | Out-Null }

    $xml.AppendChild($packageElement) | Out-Null

    $nuspecFullName = Join-Path -Path $OutputPath -ChildPath "$Id.nuspec"
    $xml.save($nuspecFullName)

    Write-Output $nuspecFullName
}
function New-PackageSourceFromModuleSource
{
    param
    (
        [Parameter(Mandatory=$true)]
        $ModuleSource
    )

    $ScriptSourceLocation = $null
    if(Get-Member -InputObject $ModuleSource -Name $script:ScriptSourceLocation)
    {
        $ScriptSourceLocation = $ModuleSource.ScriptSourceLocation
    }

    $ScriptPublishLocation = $ModuleSource.PublishLocation
    if(Get-Member -InputObject $ModuleSource -Name $script:ScriptPublishLocation)
    {
        $ScriptPublishLocation = $ModuleSource.ScriptPublishLocation
    }

    $packageSourceDetails = @{}
    $packageSourceDetails["InstallationPolicy"] = $ModuleSource.InstallationPolicy
    $packageSourceDetails["PackageManagementProvider"] = (Get-ProviderName -PSCustomObject $ModuleSource)
    $packageSourceDetails[$script:PublishLocation] = $ModuleSource.PublishLocation
    $packageSourceDetails[$script:ScriptSourceLocation] = $ScriptSourceLocation
    $packageSourceDetails[$script:ScriptPublishLocation] = $ScriptPublishLocation

    $ModuleSource.ProviderOptions.GetEnumerator() | Microsoft.PowerShell.Core\ForEach-Object {
                                                        $packageSourceDetails[$_.Key] = $_.Value
                                                    }

    # create a new package source
    $src =  New-PackageSource -Name $ModuleSource.Name `
                              -Location $ModuleSource.SourceLocation `
                              -Trusted $ModuleSource.Trusted `
                              -Registered $ModuleSource.Registered `
                              -Details $packageSourceDetails

    Write-Verbose ( $LocalizedData.RepositoryDetails -f ($src.Name, $src.Location, $src.IsTrusted, $src.IsRegistered) )

    # return the package source object.
    Write-Output -InputObject $src
}
function New-PSGetItemInfo
{
    param
    (
        [Parameter(Mandatory=$true)]
        $SoftwareIdentity,

        [Parameter()]
        $PackageManagementProviderName,

        [Parameter()]
        [string]
        $SourceLocation,

        [Parameter(Mandatory=$true)]
        [string]
        $Type,

        [Parameter()]
        [string]
        $InstalledLocation,

        [Parameter()]
        [System.DateTime]
        $InstalledDate,

        [Parameter()]
        [System.DateTime]
        $UpdatedDate
    )

    foreach($swid in $SoftwareIdentity)
    {

        if($SourceLocation)
        {
            $sourceName = (Get-SourceName -Location $SourceLocation)
        }
        else
        {
            # First get the source name from the Metadata
            # if not exists, get the source name from $swid.Source
            # otherwise default to $swid.Source
            $sourceName = (Get-First $swid.Metadata["SourceName"])

            if(-not $sourceName)
            {
                $sourceName = (Get-SourceName -Location $swid.Source)
            }

            if(-not $sourceName)
            {
                $sourceName = $swid.Source
            }

            $SourceLocation = Get-SourceLocation -SourceName $sourceName
        }

        $published = (Get-First $swid.Metadata["published"])
        $PublishedDate = New-Object System.DateTime

        $InstalledDateString = (Get-First $swid.Metadata['installeddate'])
        if(-not $InstalledDate -and $InstalledDateString)
        {
            $InstalledDate = New-Object System.DateTime
            if(-not (([System.DateTime]::TryParse($InstalledDateString, [System.Globalization.DateTimeFormatInfo]::InvariantInfo, [System.Globalization.DateTimeStyles]::None, ([ref]$InstalledDate))) -or
                     ([System.DateTime]::TryParse($InstalledDateString, ([ref]$InstalledDate)))))
            {
                $InstalledDate = $null
            }
        }

        $UpdatedDateString = (Get-First $swid.Metadata['updateddate'])
        if(-not $UpdatedDate -and $UpdatedDateString)
        {
            $UpdatedDate = New-Object System.DateTime
            if(-not (([System.DateTime]::TryParse($UpdatedDateString, [System.Globalization.DateTimeFormatInfo]::InvariantInfo, [System.Globalization.DateTimeStyles]::None, ([ref]$UpdatedDate))) -or
                     ([System.DateTime]::TryParse($UpdatedDateString, ([ref]$UpdatedDate)))))
            {
                $UpdatedDate = $null
            }
        }

        $tags = (Get-First $swid.Metadata["tags"]) -split " "
        $userTags = @()

        $exportedDscResources = @()
        $exportedRoleCapabilities = @()
        $exportedCmdlets = @()
        $exportedFunctions = @()
        $exportedWorkflows = @()
        $exportedCommands = @()

        $exportedRoleCapabilities += (Get-First $swid.Metadata['RoleCapabilities']) -split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
        $exportedDscResources += (Get-First $swid.Metadata["DscResources"]) -split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
        $exportedCmdlets += (Get-First $swid.Metadata["Cmdlets"]) -split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
        $exportedFunctions += (Get-First $swid.Metadata["Functions"]) -split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
        $exportedWorkflows += (Get-First $swid.Metadata["Workflows"]) -split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
        $exportedCommands += $exportedCmdlets + $exportedFunctions + $exportedWorkflows
        $PSGetFormatVersion = $null

        ForEach($tag in $tags)
        {
            if(-not $tag.Trim())
            {
                continue
            }

            $parts = $tag -split "_",2
            if($parts.Count -ne 2)
            {
                $userTags += $tag
                continue
            }

            Switch($parts[0])
            {
                $script:Command            { $exportedCommands += $parts[1]; break }
                $script:DscResource        { $exportedDscResources += $parts[1]; break }
                $script:Cmdlet             { $exportedCmdlets += $parts[1]; break }
                $script:Function           { $exportedFunctions += $parts[1]; break }
                $script:Workflow           { $exportedWorkflows += $parts[1]; break }
                $script:RoleCapability     { $exportedRoleCapabilities += $parts[1]; break }
                $script:PSGetFormatVersion { $PSGetFormatVersion = $parts[1]; break }
                $script:Includes           { break }
                Default                    { $userTags += $tag; break }
            }
        }

        $ArtifactDependencies = @()
        Foreach ($dependencyString in $swid.Dependencies)
        {
            [Uri]$packageId = $null
            if([Uri]::TryCreate($dependencyString, [System.UriKind]::Absolute, ([ref]$packageId)))
            {
                $segments = $packageId.Segments
                $Version = $null
                $DependencyName = $null
                if ($segments)
                {
                    $DependencyName = [Uri]::UnescapeDataString($segments[0].Trim('/', '\'))
                    $Version = if($segments.Count -gt 1){[Uri]::UnescapeDataString($segments[1])}
                }

                $dep = [ordered]@{
                            Name=$DependencyName
                        }

                if($Version)
                {
                    # Required/exact version is represented in NuGet as "[2.0]"
                    if ($Version -match "\[+[0-9.]+\]")
                    {
                        $dep["RequiredVersion"] = $Version.Trim('[', ']')
                    }
                    elseif ($Version -match "\[+[0-9., ]+\]")
                    {
                        # Minimum and Maximum version range is represented in NuGet as "[1.0, 2.0]"
                        $versionRange = $Version.Trim('[', ']') -split ',' | Microsoft.PowerShell.Core\Where-Object {$_}
                        if($versionRange -and $versionRange.count -eq 2)
                        {
                            $dep["MinimumVersion"] = $versionRange[0].Trim()
                            $dep["MaximumVersion"] = $versionRange[1].Trim()
                        }
                    }
                    elseif ($Version -match "\(+[0-9., ]+\]")
                    {
                        # Maximum version is represented in NuGet as "(, 2.0]"
                        $maximumVersion = $Version.Trim('(', ']') -split ',' | Microsoft.PowerShell.Core\Where-Object {$_}

                        if($maximumVersion)
                        {
                            $dep["MaximumVersion"] = $maximumVersion.Trim()
                        }
                    }
                    else
                    {
                        $dep['MinimumVersion'] = $Version
                    }
                }

                $dep["CanonicalId"]=$dependencyString

                $ArtifactDependencies += $dep
            }
        }

        $additionalMetadata =  Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{})
        foreach ( $key in $swid.Metadata.Keys.LocalName)
        {
            Microsoft.PowerShell.Utility\Add-Member -InputObject $additionalMetadata `
                                                    -MemberType NoteProperty `
                                                    -Name $key `
                                                    -Value (Get-First $swid.Metadata[$key])
        }

        if (-not (Get-Member -InputObject $additionalMetadata -Name "IsPrerelease") )
        {
            if ($swid.Version -match '-')
            {
                Microsoft.PowerShell.Utility\Add-Member -InputObject $additionalMetadata `
                                                        -MemberType NoteProperty `
                                                        -Name 'IsPrerelease' `
                                                        -Value $true
            }
            else {
                Microsoft.PowerShell.Utility\Add-Member -InputObject $additionalMetadata `
                                                        -MemberType NoteProperty `
                                                        -Name 'IsPrerelease' `
                                                        -Value $false
            }
        }

        if(Get-Member -InputObject $additionalMetadata -Name 'ItemType')
        {
            $Type = $additionalMetadata.'ItemType'
        }
        elseif($userTags -contains 'PSModule')
        {
            $Type = $script:PSArtifactTypeModule
        }
        elseif($userTags -contains 'PSScript')
        {
            $Type = $script:PSArtifactTypeScript
        }


        $PSGetItemInfo = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
                Name = $swid.Name
                Version = $swid.Version
                Type = $Type
                Description = (Get-First $swid.Metadata["description"])
                Author = (Get-EntityName -SoftwareIdentity $swid -Role "author")
                CompanyName = (Get-EntityName -SoftwareIdentity $swid -Role "owner")
                Copyright = (Get-First $swid.Metadata["copyright"])
                PublishedDate = if([System.DateTime]::TryParse($published, ([ref]$PublishedDate))){$PublishedDate};
                InstalledDate = $InstalledDate;
                UpdatedDate = $UpdatedDate;
                LicenseUri = (Get-UrlFromSwid -SoftwareIdentity $swid -UrlName "license")
                ProjectUri = (Get-UrlFromSwid -SoftwareIdentity $swid -UrlName "project")
                IconUri = (Get-UrlFromSwid -SoftwareIdentity $swid -UrlName "icon")
                Tags = $userTags

                Includes = @{
                                DscResource = $exportedDscResources
                                Command     = $exportedCommands
                                Cmdlet      = $exportedCmdlets
                                Function    = $exportedFunctions
                                Workflow    = $exportedWorkflows
                                RoleCapability = $exportedRoleCapabilities
                            }

                PowerShellGetFormatVersion=[Version]$PSGetFormatVersion

                ReleaseNotes = (Get-First $swid.Metadata["releaseNotes"])

                Dependencies = $ArtifactDependencies

                RepositorySourceLocation = $SourceLocation
                Repository = $sourceName
                PackageManagementProvider = if($PackageManagementProviderName) { $PackageManagementProviderName } else { (Get-First $swid.Metadata["PackageManagementProvider"]) }

				AdditionalMetadata = $additionalMetadata
            })

        if(-not $InstalledLocation)
        {
            $InstalledLocation = (Get-First $swid.Metadata[$script:InstalledLocation])
        }

        if($InstalledLocation)
        {
            Microsoft.PowerShell.Utility\Add-Member -InputObject $PSGetItemInfo -MemberType NoteProperty -Name $script:InstalledLocation -Value $InstalledLocation
        }

        $PSGetItemInfo.PSTypeNames.Insert(0, "Microsoft.PowerShell.Commands.PSRepositoryItemInfo")
        $PSGetItemInfo
    }
}
function New-PSScriptInfoObject
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    $PSScriptInfo = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{})
    $script:PSScriptInfoProperties | Microsoft.PowerShell.Core\ForEach-Object {
                                            Microsoft.PowerShell.Utility\Add-Member -InputObject $PSScriptInfo `
                                                                                    -MemberType NoteProperty `
                                                                                    -Name $_ `
                                                                                    -Value $null
                                        }

    $PSScriptInfo.$script:Name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $PSScriptInfo.$script:Path = $Path
    $PSScriptInfo.$script:ScriptBase = (Microsoft.PowerShell.Management\Split-Path -Path $Path -Parent)

    return $PSScriptInfo
}
function New-SoftwareIdentityFromPackage
{
    param
    (
        [Parameter(Mandatory=$true)]
        $Package,

        [Parameter(Mandatory=$true)]
        [string]
        $PackageManagementProviderName,

        [Parameter(Mandatory=$true)]
        [string]
        $SourceLocation,

        [Parameter()]
        [switch]
        $IsFromTrustedSource,

        [Parameter(Mandatory=$true)]
        $request,

        [Parameter(Mandatory=$true)]
        [string]
        $Type,

        [Parameter()]
        [string]
        $InstalledLocation,

        [Parameter()]
        [System.DateTime]
        $InstalledDate,

        [Parameter()]
        [System.DateTime]
        $UpdatedDate
    )

    $fastPackageReference = New-FastPackageReference -ProviderName $PackageManagementProviderName `
                                                     -PackageName $Package.Name `
                                                     -Version $Package.Version `
                                                     -Source $SourceLocation `
                                                     -ArtifactType $Type

    $links = New-Object -TypeName  System.Collections.ArrayList
    foreach($lnk in $Package.Links)
    {
        if( $lnk.Relationship -eq "icon" -or $lnk.Relationship -eq "license" -or $lnk.Relationship -eq "project" )
        {
            $links.Add( (New-Link -Href $lnk.HRef -RelationShip $lnk.Relationship )  )
        }
    }

    $entities = New-Object -TypeName  System.Collections.ArrayList
    foreach( $entity in $Package.Entities )
    {
        if( $entity.Role -eq "author" -or $entity.Role -eq "owner" )
        {
            $entities.Add( (New-Entity -Name $entity.Name -Role $entity.Role -RegId $entity.RegId -Thumbprint $entity.Thumbprint)  )
        }
    }

    $deps = (new-Object -TypeName  System.Collections.ArrayList)
    foreach( $dep in $pkg.Dependencies )
    {
        # Add each dependency and say it's from this provider.
        $newDep = New-Dependency -ProviderName $script:PSModuleProviderName `
                                 -PackageName $request.Services.ParsePackageName($dep) `
                                 -Version $request.Services.ParsePackageVersion($dep) `
                                 -Source $SourceLocation

        $deps.Add( $newDep )
    }


    $details =  New-Object -TypeName  System.Collections.Hashtable

	foreach ( $key in $Package.Metadata.Keys.LocalName)
	{
		if (!$details.ContainsKey($key))
		{
			$details.Add($key, (Get-First $Package.Metadata[$key]) )
		}
	}

    $details.Add( "PackageManagementProvider" , $PackageManagementProviderName )

    if($InstalledLocation)
    {
        $details.Add( $script:InstalledLocation , $InstalledLocation )
    }

    if($InstalledDate)
    {
        $details.Add( 'installeddate' , $InstalledDate.ToString('O', [System.Globalization.DateTimeFormatInfo]::InvariantInfo) )
    }

    if($UpdatedDate)
    {
        $details.Add( 'updateddate' , $UpdatedDate.ToString('O', [System.Globalization.DateTimeFormatInfo]::InvariantInfo) )
    }

    # Initialize package source name to the source location
    $sourceNameForSoftwareIdentity = $SourceLocation

    $sourceName = (Get-SourceName -Location $SourceLocation)

    if($sourceName)
    {
        $details.Add( "SourceName" , $sourceName )

        # Override the source name only if we are able to map source location to source name
        $sourceNameForSoftwareIdentity = $sourceName
    }

    $params = @{FastPackageReference = $fastPackageReference;
                Name = $Package.Name;
                Version = $Package.Version;
                versionScheme  = "MultiPartNumeric";
                Source = $sourceNameForSoftwareIdentity;
                Summary = $Package.Summary;
                SearchKey = $Package.Name;
                FullPath = $Package.FullPath;
                FileName = $Package.Name;
                Details = $details;
                Entities = $entities;
                Links = $links;
                Dependencies = $deps;
               }

    if($IsFromTrustedSource)
    {
        $params["FromTrustedSource"] = $true
    }

    $sid = New-SoftwareIdentity @params

    return $sid
}
function New-SoftwareIdentityFromPSGetItemInfo
{
    param
    (
        [Parameter(Mandatory=$true)]
        $PSGetItemInfo
    )

    $SourceLocation = $psgetItemInfo.RepositorySourceLocation

    if(Get-Member -InputObject $PSGetItemInfo -Name $script:PSArtifactType)
    {
        $artifactType = $psgetItemInfo.Type
    }
    else
    {
        $artifactType = $script:PSArtifactTypeModule
    }

    $fastPackageReference = New-FastPackageReference -ProviderName (Get-ProviderName -PSCustomObject $psgetItemInfo) `
                                                     -PackageName $psgetItemInfo.Name `
                                                     -Version $psgetItemInfo.Version `
                                                     -Source $SourceLocation `
                                                     -ArtifactType $artifactType

    $links = New-Object -TypeName  System.Collections.ArrayList
    if($psgetItemInfo.IconUri)
    {
        $links.Add( (New-Link -Href $psgetItemInfo.IconUri -RelationShip "icon") )
    }

    if($psgetItemInfo.LicenseUri)
    {
        $links.Add( (New-Link -Href $psgetItemInfo.LicenseUri -RelationShip "license") )
    }

    if($psgetItemInfo.ProjectUri)
    {
        $links.Add( (New-Link -Href $psgetItemInfo.ProjectUri -RelationShip "project") )
    }

    $entities = New-Object -TypeName  System.Collections.ArrayList
    if($psgetItemInfo.Author -and $psgetItemInfo.Author.ToString())
    {
        $entities.Add( (New-Entity -Name $psgetItemInfo.Author -Role 'author') )
    }

    if($psgetItemInfo.CompanyName -and $psgetItemInfo.CompanyName.ToString())
    {
        $entities.Add( (New-Entity -Name $psgetItemInfo.CompanyName -Role 'owner') )
    }

    $details =  @{
                    description    = $psgetItemInfo.Description
                    copyright      = $psgetItemInfo.Copyright
                    published      = $psgetItemInfo.PublishedDate.ToString()
                    installeddate  = $null
                    updateddate    = $null
                    tags           = $psgetItemInfo.Tags
                    releaseNotes   = $psgetItemInfo.ReleaseNotes
                    PackageManagementProvider = (Get-ProviderName -PSCustomObject $psgetItemInfo)
                 }

    if((Get-Member -InputObject $psgetItemInfo -Name 'InstalledDate') -and $psgetItemInfo.InstalledDate)
    {
        $details['installeddate'] = $psgetItemInfo.InstalledDate.ToString('O', [System.Globalization.DateTimeFormatInfo]::InvariantInfo)
    }

    if((Get-Member -InputObject $psgetItemInfo -Name 'UpdatedDate') -and $psgetItemInfo.UpdatedDate)
    {
        $details['updateddate'] = $psgetItemInfo.UpdatedDate.ToString('O', [System.Globalization.DateTimeFormatInfo]::InvariantInfo)
    }

    if(Get-Member -InputObject $psgetItemInfo -Name $script:InstalledLocation)
    {
        $details[$script:InstalledLocation] = $psgetItemInfo.InstalledLocation
    }

    $details[$script:PSArtifactType] = $artifactType

    $sourceName = Get-SourceName -Location $SourceLocation
    if($sourceName)
    {
        $details["SourceName"] = $sourceName
    }

    $params = @{
                FastPackageReference = $fastPackageReference;
                Name = $psgetItemInfo.Name;
                Version = $psgetItemInfo.Version;
                versionScheme  = "MultiPartNumeric";
                Source = $SourceLocation;
                Summary = $psgetItemInfo.Description;
                Details = $details;
                Entities = $entities;
                Links = $links
               }

    if($sourceName -and $script:PSGetModuleSources[$sourceName].Trusted)
    {
        $params["FromTrustedSource"] = $true
    }

    $sid = New-SoftwareIdentity @params

    return $sid
}
function Ping-Endpoint
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Endpoint,

        [Parameter()]
        $Credential,

        [Parameter()]
        $Proxy,

        [Parameter()]
        $ProxyCredential,

        [Parameter()]
        [switch]
        $AllowAutoRedirect = $true
    )

    $results = @{}

    $WebProxy = $null
    if($Proxy -and ('Microsoft.PowerShell.Commands.PowerShellGet.InternalWebProxy' -as [Type]))
    {
        $ProxyNetworkCredential = $null
        if($ProxyCredential)
        {
            $ProxyNetworkCredential = $ProxyCredential.GetNetworkCredential()
        }

        $WebProxy = New-Object Microsoft.PowerShell.Commands.PowerShellGet.InternalWebProxy -ArgumentList $Proxy,$ProxyNetworkCredential
    }

    if(HttpClientApisAvailable)
    {
        $response = $null
        try
        {
            $handler = New-Object System.Net.Http.HttpClientHandler

            if($Credential)
            {
                $handler.Credentials = $Credential.GetNetworkCredential()
            }
            else
            {
                $handler.UseDefaultCredentials = $true
            }

            if($WebProxy)
            {
                $handler.Proxy = $WebProxy
            }

            $httpClient = New-Object System.Net.Http.HttpClient -ArgumentList $handler
            $response = $httpclient.GetAsync($endpoint)
        }
        catch
        {
        }

        if ($response -ne $null -and $response.result -ne $null)
        {
            $results.Add($Script:ResponseUri,$response.Result.RequestMessage.RequestUri.AbsoluteUri.ToString())
            $results.Add($Script:StatusCode,$response.result.StatusCode.value__)
        }
    }
    else
    {
        $iss = [System.Management.Automation.Runspaces.InitialSessionState]::Create()
        $iss.types.clear()
        $iss.formats.clear()
        $iss.LanguageMode = "FullLanguage"

        $WebRequestcmd =  @'
            param($Credential, $WebProxy)

            try
            {{
                $request = [System.Net.WebRequest]::Create("{0}")
                $request.Method = 'GET'
                $request.Timeout = 30000
                if($Credential)
                {{
                    $request.Credentials = $Credential.GetNetworkCredential()
                }}
                else
                {{
                    $request.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                }}

                $request.AllowAutoRedirect = ${1}

                if($WebProxy)
                {{
                    $request.Proxy = $WebProxy
                }}

                $response = [System.Net.HttpWebResponse]$request.GetResponse()
                if($response.StatusCode.value__ -eq 302)
                {{
                    $response.Headers["Location"].ToString()
                }}
                else
                {{
                    $response
                }}
                $response.Close()
            }}
            catch [System.Net.WebException]
            {{
                "Error:System.Net.WebException"
            }}
'@ -f $EndPoint, $AllowAutoRedirect

        $ps = [powershell]::Create($iss).AddScript($WebRequestcmd)

        if($WebProxy)
        {
            $null = $ps.AddParameter('WebProxy', $WebProxy)
        }

        if($Credential)
        {
            $null = $ps.AddParameter('Credential', $Credential)
        }

        $response = $ps.Invoke()
        $ps.dispose()
        if ($response -ne "Error:System.Net.WebException")
        {
            if($AllowAutoRedirect)
            {
                $results.Add($Script:ResponseUri,$response.ResponseUri.ToString())
                $results.Add($Script:StatusCode,$response.StatusCode.value__)
            }
            else
            {
                $results.Add($Script:ResponseUri,[String]$response)
            }
        }
    }
    return $results
}
function Publish-NugetPackage {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$NupkgPath,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [string]$NugetApiKey,

        [Parameter(ParameterSetName = "UseNuget")]
        [string]$NugetExePath,

        [Parameter(ParameterSetName = "UseDotnetCli")]
        [switch]$UseDotnetCli
    )
    Set-StrictMode -Off

    Write-Verbose "Calling Publish-NugetPackage -NupkgPath $NupkgPath -Destination $Destination -NugetExePath $NugetExePath -UseDotnetCli:$UseDotnetCli"
    $Destination = $Destination.TrimEnd("\")

    if ($PSCmdlet.ParameterSetName -eq "UseNuget") {
        $ArgumentList = @('push')
        $ArgumentList += "`"$NupkgPath`""
        $ArgumentList += @('-source', "`"$Destination`"")
        $ArgumentList += @('-apikey', "`"$NugetApiKey`"")
        $ArgumentList += '-NonInteractive'

        #use processstartinfo and process objects here as it allows stderr redirection in memory rather than file.
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = $NugetExePath
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.Arguments = $ArgumentList

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        $process.Start() | Out-Null
        $process.WaitForExit()

        if (-Not ($process.ExitCode -eq 0 )) {
            $stdErr = $process.StandardError.ReadToEnd()
            throw "nuget.exe failed to push $stdErr"
        }
    }

    if ($PSCmdlet.ParameterSetName -eq "UseDotnetCli") {
        #perform dotnet pack using a temporary project file.
        $dotnetCliPath = (Get-Command -Name "dotnet").Source

        $ArgumentList = @('nuget')
        $ArgumentList += 'push'
        $ArgumentList += "`"$NupkgPath`""
        $ArgumentList += @('--source', "`"$Destination`"")
        $ArgumentList += @('--api-key', "`"$NugetApiKey`"")

        #use processstartinfo and process objects here as it allows stdout redirection in memory rather than file.
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = $dotnetCliPath
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.Arguments = $ArgumentList

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        $process.Start() | Out-Null
        $process.WaitForExit()

        if (-Not ($process.ExitCode -eq 0)) {
            $stdOut = $process.StandardOutput.ReadToEnd()
            throw "dotnet cli failed to nuget push $stdOut"
        }
    }

    $stdOut = $process.StandardOutput.ReadToEnd()
    Write-Verbose -Message $stdOut
}
function Publish-PSArtifactUtility {
    [CmdletBinding(PositionalBinding = $false)]
    Param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'PublishModule')]
        [ValidateNotNullOrEmpty()]
        [PSModuleInfo]
        $PSModuleInfo,

        [Parameter(Mandatory = $true, ParameterSetName = 'PublishScript')]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]
        $PSScriptInfo,

        [Parameter(Mandatory = $true, ParameterSetName = 'PublishModule')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ManifestPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Destination,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NugetApiKey,

        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NugetPackageRoot,

        [Parameter(ParameterSetName = 'PublishModule')]
        [Version]
        $FormatVersion,

        [Parameter(ParameterSetName = 'PublishModule')]
        [string]
        $ReleaseNotes,

        [Parameter(ParameterSetName = 'PublishModule')]
        [string[]]
        $Tags,

        [Parameter(ParameterSetName = 'PublishModule')]
        [switch]
        $SkipAutomaticTags,

        [Parameter(ParameterSetName = 'PublishModule')]
        [Uri]
        $LicenseUri,

        [Parameter(ParameterSetName = 'PublishModule')]
        [Uri]
        $IconUri,

        [Parameter(ParameterSetName = 'PublishModule')]
        [Uri]
        $ProjectUri,

        [Parameter(ParameterSetName = 'PublishModule')]
        [string[]]
        $Exclude
    )

    Write-Verbose "Calling Publish-PSArtifactUtility"
    Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -BootstrapNuGetExe

    $PSArtifactType = $script:PSArtifactTypeModule
    $Name = $null
    $Description = $null
    $Version = ""
    $Author = $null
    $CompanyName = $null
    $Copyright = $null
    $requireLicenseAcceptance = "false"

    if ($PSModuleInfo) {
        $Name = $PSModuleInfo.Name
        $Description = $PSModuleInfo.Description
        $Version = $PSModuleInfo.Version
        $Author = $PSModuleInfo.Author
        $CompanyName = $PSModuleInfo.CompanyName
        $Copyright = $PSModuleInfo.Copyright

        if ($PSModuleInfo.PrivateData -and
            ($PSModuleInfo.PrivateData.GetType().ToString() -eq "System.Collections.Hashtable") -and
            $PSModuleInfo.PrivateData["PSData"] -and
            ($PSModuleInfo.PrivateData["PSData"].GetType().ToString() -eq "System.Collections.Hashtable")
        ) {
            if ( -not $Tags -and $PSModuleInfo.PrivateData.PSData["Tags"]) {
                $Tags = $PSModuleInfo.PrivateData.PSData.Tags
            }

            if ( -not $ReleaseNotes -and $PSModuleInfo.PrivateData.PSData["ReleaseNotes"]) {
                $ReleaseNotes = $PSModuleInfo.PrivateData.PSData.ReleaseNotes
            }

            if ( -not $LicenseUri -and $PSModuleInfo.PrivateData.PSData["LicenseUri"]) {
                $LicenseUri = $PSModuleInfo.PrivateData.PSData.LicenseUri
            }

            if ( -not $IconUri -and $PSModuleInfo.PrivateData.PSData["IconUri"]) {
                $IconUri = $PSModuleInfo.PrivateData.PSData.IconUri
            }

            if ( -not $ProjectUri -and $PSModuleInfo.PrivateData.PSData["ProjectUri"]) {
                $ProjectUri = $PSModuleInfo.PrivateData.PSData.ProjectUri
            }

            if ($PSModuleInfo.PrivateData.PSData["Prerelease"]) {
                $psmoduleInfoPrereleaseString = $PSModuleInfo.PrivateData.PSData.Prerelease
                if ($psmoduleInfoPrereleaseString -and $psmoduleInfoPrereleaseString.StartsWith("-")) {
                    $Version = [string]$Version + $psmoduleInfoPrereleaseString
                }
                else {
                    $Version = [string]$Version + "-" + $psmoduleInfoPrereleaseString
                }
            }

            if ($PSModuleInfo.PrivateData.PSData["RequireLicenseAcceptance"]) {
                $requireLicenseAcceptance = $PSModuleInfo.PrivateData.PSData.requireLicenseAcceptance.ToString().ToLower()
                if ($requireLicenseAcceptance -eq "true") {
                    if ($FormatVersion -and ($FormatVersion.Major -lt $script:PSGetRequireLicenseAcceptanceFormatVersion.Major)) {
                        $message = $LocalizedData.requireLicenseAcceptanceNotSupported -f ($FormatVersion)
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "requireLicenseAcceptanceNotSupported" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidData
                    }

                    if (-not $LicenseUri) {
                        $message = $LocalizedData.LicenseUriNotSpecified
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "LicenseUriNotSpecified" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidData
                    }

                    $LicenseFilePath = Join-PathUtility -Path $NugetPackageRoot -ChildPath 'License.txt' -PathType File
                    if (-not $LicenseFilePath -or -not (Test-Path -Path $LicenseFilePath -PathType Leaf)) {
                        $message = $LocalizedData.LicenseTxtNotFound
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "LicenseTxtNotFound" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidData
                    }

                    if ((Get-Content -LiteralPath $LicenseFilePath) -eq $null) {
                        $message = $LocalizedData.LicenseTxtEmpty
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "LicenseTxtEmpty" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidData
                    }

                    #RequireLicenseAcceptance is true, License uri and license.txt exist. Bump Up the FormatVersion
                    if (-not $FormatVersion) {
                        $FormatVersion = $script:CurrentPSGetFormatVersion
                    }
                }
                elseif ($requireLicenseAcceptance -ne "false") {
                    $InvalidValueForRequireLicenseAcceptance = $LocalizedData.InvalidValueBoolean -f ($requireLicenseAcceptance, "requireLicenseAcceptance")
                    Write-Warning -Message $InvalidValueForRequireLicenseAcceptance
                }
            }
        }
    }
    else {
        $PSArtifactType = $script:PSArtifactTypeScript

        $Name = $PSScriptInfo.Name
        $Description = $PSScriptInfo.Description
        $Version = $PSScriptInfo.Version
        $Author = $PSScriptInfo.Author
        $CompanyName = $PSScriptInfo.CompanyName
        $Copyright = $PSScriptInfo.Copyright

        if ($PSScriptInfo.'Tags') {
            $Tags = $PSScriptInfo.Tags
        }

        if ($PSScriptInfo.'ReleaseNotes') {
            $ReleaseNotes = $PSScriptInfo.ReleaseNotes
        }

        if ($PSScriptInfo.'LicenseUri') {
            $LicenseUri = $PSScriptInfo.LicenseUri
        }

        if ($PSScriptInfo.'IconUri') {
            $IconUri = $PSScriptInfo.IconUri
        }

        if ($PSScriptInfo.'ProjectUri') {
            $ProjectUri = $PSScriptInfo.ProjectUri
        }
    }

    $nuspecFiles = ""
    if ($Exclude) {
        $nuspecFileExcludePattern = $Exclude -Join ";"
        $nuspecFiles = @{ src = "**/*.*"; exclude = $nuspecFileExcludePattern }
    }

    # Add PSModule and PSGet format version tags
    if (-not $Tags) {
        $Tags = @()
    }

    if ($FormatVersion) {
        $Tags += "$($script:PSGetFormatVersion)_$FormatVersion"
    }

    $DependentModuleDetails = @()

    if ($PSScriptInfo) {
        $Tags += "PSScript"

        if ($PSScriptInfo.DefinedCommands -and -not $SkipAutomaticTags) {
            if ($PSScriptInfo.DefinedFunctions) {
                $Tags += "$($script:Includes)_Function"
                $Tags += $PSScriptInfo.DefinedFunctions | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Function)_$_" }
            }

            if ($PSScriptInfo.DefinedWorkflows) {
                $Tags += "$($script:Includes)_Workflow"
                $Tags += $PSScriptInfo.DefinedWorkflows | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Workflow)_$_" }
            }

            $Tags += $PSScriptInfo.DefinedCommands | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Command)_$_" }
        }

        # Populate the dependencies elements from RequiredModules and RequiredScripts
        #
        $ValidateAndGetScriptDependencies_Params = @{
            Repository          = $Repository
            DependentScriptInfo = $PSScriptInfo
            CallerPSCmdlet      = $PSCmdlet
            Verbose             = $VerbosePreference
            Debug               = $DebugPreference
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $ValidateAndGetScriptDependencies_Params.Add('Credential', $Credential)
        }
        $DependentModuleDetails += ValidateAndGet-ScriptDependencies @ValidateAndGetScriptDependencies_Params
    }
    else {
        $Tags += "PSModule"

        $ModuleManifestHashTable = Get-ManifestHashTable -Path $ManifestPath

        if (-not $SkipAutomaticTags) {
            if ($PSModuleInfo.ExportedCommands.Count) {
                if ($PSModuleInfo.ExportedCmdlets.Count) {
                    $Tags += "$($script:Includes)_Cmdlet"
                    $Tags += $PSModuleInfo.ExportedCmdlets.Keys | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Cmdlet)_$_" }

                    #if CmdletsToExport field in manifest file is "*", we suggest the user to include all those cmdlets for best practice
                    if ($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey('CmdletsToExport') -and ($ModuleManifestHashTable.CmdletsToExport -eq "*")) {
                        $WarningMessage = $LocalizedData.ShouldIncludeCmdletsToExport -f ($ManifestPath)
                        Write-Warning -Message $WarningMessage
                    }
                }

                if ($PSModuleInfo.ExportedFunctions.Count) {
                    $Tags += "$($script:Includes)_Function"
                    $Tags += $PSModuleInfo.ExportedFunctions.Keys | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Function)_$_" }

                    if ($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey('FunctionsToExport') -and ($ModuleManifestHashTable.FunctionsToExport -eq "*")) {
                        $WarningMessage = $LocalizedData.ShouldIncludeFunctionsToExport -f ($ManifestPath)
                        Write-Warning -Message $WarningMessage
                    }
                }

                $Tags += $PSModuleInfo.ExportedCommands.Keys | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Command)_$_" }
            }

            $dscResourceNames = Get-ExportedDscResources -PSModuleInfo $PSModuleInfo
            if ($dscResourceNames) {
                $Tags += "$($script:Includes)_DscResource"

                $Tags += $dscResourceNames | Microsoft.PowerShell.Core\ForEach-Object { "$($script:DscResource)_$_" }

                #If DscResourcesToExport is commented out or "*" is used, we will write-warning
                if ($ModuleManifestHashTable -and
                    ($ModuleManifestHashTable.ContainsKey("DscResourcesToExport") -and
                        $ModuleManifestHashTable.DscResourcesToExport -eq "*") -or
                    -not $ModuleManifestHashTable.ContainsKey("DscResourcesToExport")) {
                    $WarningMessage = $LocalizedData.ShouldIncludeDscResourcesToExport -f ($ManifestPath)
                    Write-Warning -Message $WarningMessage
                }
            }

            $RoleCapabilityNames = Get-AvailableRoleCapabilityName -PSModuleInfo $PSModuleInfo
            if ($RoleCapabilityNames) {
                $Tags += "$($script:Includes)_RoleCapability"

                $Tags += $RoleCapabilityNames | Microsoft.PowerShell.Core\ForEach-Object { "$($script:RoleCapability)_$_" }
            }
        }

        # Populate the module dependencies elements from RequiredModules and
        # NestedModules properties of the current PSModuleInfo
        $GetModuleDependencies_Params = @{
            PSModuleInfo   = $PSModuleInfo
            Repository     = $Repository
            CallerPSCmdlet = $PSCmdlet
            Verbose        = $VerbosePreference
            Debug          = $DebugPreference
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $GetModuleDependencies_Params.Add('Credential', $Credential)
        }
        $DependentModuleDetails = Get-ModuleDependencies @GetModuleDependencies_Params
    }

    $dependencies = @()
    ForEach ($Dependency in $DependentModuleDetails) {
        $ModuleName = $Dependency.Name
        $VersionString = ""

        # Version format in NuSpec:
        # "[2.0]" --> (== 2.0) Required Version
        # "2.0" --> (>= 2.0) Minimum Version
        #
        # When only MaximumVersion is specified in the ModuleSpecification
        # (,1.0]  = x <= 1.0
        #
        # When both Minimum and Maximum versions are specified in the ModuleSpecification
        # [1.0,2.0] = 1.0 <= x <= 2.0

        if ($Dependency.Keys -Contains "RequiredVersion") {
            $VersionString = "[$($Dependency.RequiredVersion)]"
        }
        elseif ($Dependency.Keys -Contains 'MinimumVersion' -and $Dependency.Keys -Contains 'MaximumVersion') {
            $VersionString = "[$($Dependency.MinimumVersion),$($Dependency.MaximumVersion)]"
        }
        elseif ($Dependency.Keys -Contains 'MaximumVersion') {
            $VersionString = "(,$($Dependency.MaximumVersion)]"
        }
        elseif ($Dependency.Keys -Contains 'MinimumVersion') {
            $VersionString = "$($Dependency.MinimumVersion)"
        }

        $props = @{
            id      = $ModuleName
            version = $VersionString
        }

        $dependencyObject = New-Object -TypeName PSCustomObject -Property $props
        $dependencies += $dependencyObject
    }

    $params = @{
        OutputPath               = $NugetPackageRoot
        Id                       = $Name
        Version                  = $Version
        Authors                  = $Author
        Owners                   = $CompanyName
        Description              = $Description
        ReleaseNotes             = $ReleaseNotes
        RequireLicenseAcceptance = ($requireLicenseAcceptance -eq $true)
        Copyright                = $Copyright
        Tags                     = $Tags
        LicenseUrl               = $LicenseUri
        ProjectUrl               = $ProjectUri
        IconUrl                  = $IconUri
        Dependencies             = $dependencies
    }

    if ($nuspecFiles) {
        $params.Add('Files', $nuspecFiles)
    }

    try {
        $NuspecFullName = New-NuspecFile @params
    }
    catch {
        Write-Error -Message "Failed to create nuspec file $_.Exception" -ErrorAction Stop
    }

    try {
        if ($DotnetCommandPath) {
            $NupkgFullName = New-NugetPackage -NuspecPath $NuspecFullName -NugetPackageRoot $NugetPackageRoot -UseDotnetCli -Verbose:$VerbosePreference
        }
        elseif ($NuGetExePath) {
            $NupkgFullName = New-NugetPackage -NuspecPath $NuspecFullName -NugetPackageRoot $NugetPackageRoot -NugetExePath $NuGetExePath -Verbose:$VerbosePreference
        }

        Write-Verbose -Message "Successfully created nuget package at $NupkgFullName"
    }
    catch {
        if ($PSArtifactType -eq $script:PSArtifactTypeModule) {
            $message = $LocalizedData.FailedToCreateCompressedModule -f ($_.Exception.message)
            $errorId = "FailedToCreateCompressedModule"
        }
        else {
            $message = $LocalizedData.FailedToCreateCompressedScript -f ($_.Exception.message)
            $errorId = "FailedToCreateCompressedScript"
        }

        Write-Error -Message $message -ErrorId $errorId -Category InvalidOperation -ErrorAction Stop
    }

    try {
        if ($DotnetCommandPath) {
            Publish-NugetPackage -NupkgPath $NupkgFullName -Destination $Destination -NugetApiKey $NugetApiKey -UseDotnetCli -Verbose:$VerbosePreference
        }
        elseif ($NuGetExePath) {
            Publish-NugetPackage -NupkgPath $NupkgFullName -Destination $Destination -NugetApiKey $NugetApiKey -NugetExePath $NuGetExePath -Verbose:$VerbosePreference
        }

        if ($PSArtifactType -eq "Module") {
            $message = $LocalizedData.PublishedSuccessfully -f ($Name, $Destination, $Name)
        }
        if ($PSArtifactType -eq "Script") {
            $message = $LocalizedData.PublishedScriptSuccessfully -f ($Name, $Destination, $Name)
        }

        Write-Verbose -Message $message
    }
    catch {
        if ( $NugetApiKey -eq "VSTS" -and ($_.Exception.Message -match "Cannot prompt for input in non-interactive mode.")) {
            $message = $LocalizedData.RegisterVSTSFeedAsNuGetPackageSource -f ($Destination, $script:VSTSAuthenticatedFeedsDocUrl)
        }
        else {
            $message = $_.Exception.message
        }

        if ($PSArtifactType -eq "Module") {
            $errorMessage = $LocalizedData.FailedToPublish -f ($Name, $message)
            $errorId = "FailedToPublishTheModule"
        }

        if ($PSArtifactType -eq "Script") {
            $errorMessage = $LocalizedData.FailedToPublishScript -f ($Name, $message)
            $errorId = "FailedToPublishTheScript"
        }

        Write-Error -Message $errorMessage -ErrorId $errorId -Category InvalidOperation -ErrorAction Stop
    }
}
function Resolve-Location
{
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $Location,

        [Parameter(Mandatory=$true)]
        [string]
        $LocationParameterName,

        [Parameter()]
        $Credential,

        [Parameter()]
        $Proxy,

        [Parameter()]
        $ProxyCredential,

        [Parameter()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet
    )

    # Ping and resolve the specified location
    if(-not (Test-WebUri -uri $Location))
    {
        if(Microsoft.PowerShell.Management\Test-Path -LiteralPath $Location)
        {
            return $Location
        }
        elseif($CallerPSCmdlet)
        {
            $message = $LocalizedData.PathNotFound -f ($Location)
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId "PathNotFound" `
                       -CallerPSCmdlet $CallerPSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $Location
        }
    }
    else
    {
        $pingResult = Ping-Endpoint -Endpoint $Location -Credential $Credential -Proxy $Proxy -ProxyCredential $ProxyCredential
        $statusCode = $null
        $exception = $null
        $resolvedLocation = $null
        if($pingResult -and $pingResult.ContainsKey($Script:ResponseUri))
        {
            $resolvedLocation = $pingResult[$Script:ResponseUri]
        }

        if($pingResult -and $pingResult.ContainsKey($Script:StatusCode))
        {
            $statusCode = $pingResult[$Script:StatusCode]
        }

        Write-Debug -Message "Ping-Endpoint: location=$Location, statuscode=$statusCode, resolvedLocation=$resolvedLocation"

        if((($statusCode -eq 200) -or ($statusCode -eq 401) -or ($statusCode -eq 407)) -and $resolvedLocation)
        {
            return $resolvedLocation
        }
        elseif($CallerPSCmdlet)
        {
            $message = $LocalizedData.InvalidWebUri -f ($Location, $LocationParameterName)
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId "InvalidWebUri" `
                       -CallerPSCmdlet $CallerPSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $Location
        }
    }
}
function Resolve-PathHelper
{
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $path,

        [Parameter()]
        [switch]
        $isLiteralPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $callerPSCmdlet
    )

    $resolvedPaths =@()

    foreach($currentPath in $path)
    {
        try
        {
            if($isLiteralPath)
            {
                $currentResolvedPaths = Microsoft.PowerShell.Management\Resolve-Path -LiteralPath $currentPath -ErrorAction Stop
            }
            else
            {
                $currentResolvedPaths = Microsoft.PowerShell.Management\Resolve-Path -Path $currentPath -ErrorAction Stop
            }
        }
        catch
        {
            $errorMessage = ($LocalizedData.PathNotFound -f $currentPath)
            ThrowError  -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $errorMessage `
                        -ErrorId "PathNotFound" `
                        -CallerPSCmdlet $callerPSCmdlet `
                        -ErrorCategory InvalidOperation
        }

        foreach($currentResolvedPath in $currentResolvedPaths)
        {
            $resolvedPaths += $currentResolvedPath.ProviderPath
        }
    }

    $resolvedPaths
}
function Save-ModuleSources
{
    if($script:PSGetModuleSources)
    {
        if(-not (Microsoft.PowerShell.Management\Test-Path $script:PSGetAppLocalPath))
        {
            $null = Microsoft.PowerShell.Management\New-Item -Path $script:PSGetAppLocalPath `
                                                             -ItemType Directory -Force `
                                                             -ErrorAction SilentlyContinue `
                                                             -WarningAction SilentlyContinue `
                                                             -Confirm:$false -WhatIf:$false
        }
        Microsoft.PowerShell.Utility\Out-File -FilePath $script:PSGetModuleSourcesFilePath -Force -InputObject ([System.Management.Automation.PSSerializer]::Serialize($script:PSGetModuleSources))
   }
}
function Save-PSGetSettings
{
    if($script:PSGetSettings)
    {
        if(-not (Microsoft.PowerShell.Management\Test-Path -Path $script:PSGetAppLocalPath))
        {
            $null = Microsoft.PowerShell.Management\New-Item -Path $script:PSGetAppLocalPath `
                                                             -ItemType Directory `
                                                             -Force `
                                                             -ErrorAction SilentlyContinue `
                                                             -WarningAction SilentlyContinue `
                                                             -Confirm:$false `
                                                             -WhatIf:$false
        }

        Microsoft.PowerShell.Utility\Out-File -FilePath $script:PSGetSettingsFilePath -Force `
            -InputObject ([System.Management.Automation.PSSerializer]::Serialize($script:PSGetSettings))

        Write-Debug "In Save-PSGetSettings, persisted the $script:PSGetSettingsFilePath file"
   }
}
function Send-EnvironmentChangeMessage
# Broadcast the Environment variable changes, so that other processes pick changes to Environment variables without having to reboot or logoff/logon.
{
    if($Script:IsWindows)
    {
        if (-not ('Microsoft.PowerShell.Commands.PowerShellGet.Win32.NativeMethods' -as [type]))
        {
            Add-Type -Namespace Microsoft.PowerShell.Commands.PowerShellGet.Win32 `
                     -Name NativeMethods `
                     -MemberDefinition @'
                        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
                        public static extern IntPtr SendMessageTimeout(
                            IntPtr hWnd,
                            uint Msg,
                            UIntPtr wParam,
                            string lParam,
                            uint fuFlags,
                            uint uTimeout,
                            out UIntPtr lpdwResult);
'@
        }

        $HWND_BROADCAST = [System.IntPtr]0xffff
        $WM_SETTINGCHANGE = 0x1a
        $result = [System.UIntPtr]::zero

        $returnValue = [Microsoft.PowerShell.Commands.PowerShellGet.Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST,
                                                                                                            $WM_SETTINGCHANGE,
                                                                                                            [System.UIntPtr]::Zero,
                                                                                                            'Environment',
                                                                                                            2,
                                                                                                            5000,
                                                                                                            [ref]$result)
        if($returnValue)
        {
            Write-Verbose -Message $LocalizedData.SentEnvironmentVariableChangeMessage
        }
        else
        {
            Write-Warning -Message $LocalizedData.UnableToSendEnvironmentVariableChangeMessage
        }
    }
}
function Set-EnvironmentVariable
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [parameter()]
        [String]
        $Value,

        [parameter(Mandatory = $true)]
        [int]
        $Target
    )

    if ($Target -eq $script:EnvironmentVariableTarget.Process)
    {
        [System.Environment]::SetEnvironmentVariable($Name, $Value)

        return
    }
    elseif ($Target -eq $script:EnvironmentVariableTarget.Machine)
    {
        if ($Name.Length -ge $script:SystemEnvironmentVariableMaximumLength)
        {
            $message = $LocalizedData.InvalidEnvironmentVariableName -f ($Name, $script:SystemEnvironmentVariableMaximumLength)
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId 'InvalidEnvironmentVariableName' `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $Name
            return
        }

        $Path = $script:SystemEnvironmentKey
    }
    elseif ($Target -eq $script:EnvironmentVariableTarget.User)
    {
        if ($Name.Length -ge $script:UserEnvironmentVariableMaximumLength)
        {
            $message = $LocalizedData.InvalidEnvironmentVariableName -f ($Name, $script:UserEnvironmentVariableMaximumLength)
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId 'InvalidEnvironmentVariableName' `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $Name
            return
        }

        $Path = $script:UserEnvironmentKey
    }

    if (!$Value)
    {
        Microsoft.PowerShell.Management\Remove-ItemProperty $Path -Name $Name -ErrorAction SilentlyContinue
    }
    else
    {
        Microsoft.PowerShell.Management\Set-ItemProperty $Path -Name $Name -Value $Value
    }

    # Broadcast the Environment variable changes, so that other processes pick changes to Environment variables without having to reboot or logoff/logon.
    Send-EnvironmentChangeMessage
}
function Set-InstalledModulesVariable
{
    # Initialize list of modules installed by the PowerShellGet provider
    $script:PSGetInstalledModules = [ordered]@{}

    $modulePaths = @($script:ProgramFilesModulesPath, $script:MyDocumentsModulesPath)

    foreach ($location in $modulePaths)
    {
        # find all modules installed using PowerShellGet
        $GetChildItemParams = @{
            Path = $location
            Recurse = $true
            Force = $true
            Filter = $script:PSGetItemInfoFileName
            ErrorAction = 'SilentlyContinue'
            WarningAction = 'SilentlyContinue'
        }

        if($script:IsWindows)
        {
            $GetChildItemParams['Attributes'] = 'Hidden'
        }

        $moduleBases = Get-ChildItem @GetChildItemParams | Foreach-Object { $_.Directory }


        foreach ($moduleBase in $moduleBases)
        {
            $PSGetItemInfoPath = Microsoft.PowerShell.Management\Join-Path $moduleBase.FullName $script:PSGetItemInfoFileName

            # Check if this module got installed using PSGet, read its contents to create a SoftwareIdentity object
            if (Microsoft.PowerShell.Management\Test-Path $PSGetItemInfoPath)
            {
                $psgetItemInfo = DeSerialize-PSObject -Path $PSGetItemInfoPath

                # Add InstalledLocation if this module was installed with older version of PowerShellGet
                if(-not (Get-Member -InputObject $psgetItemInfo -Name $script:InstalledLocation))
                {
                    Microsoft.PowerShell.Utility\Add-Member -InputObject $psgetItemInfo `
                                                            -MemberType NoteProperty `
                                                            -Name $script:InstalledLocation `
                                                            -Value $moduleBase.FullName
                }

                $package = New-SoftwareIdentityFromPSGetItemInfo -PSGetItemInfo $psgetItemInfo

                if($package)
                {
                    $script:PSGetInstalledModules["$($psgetItemInfo.Name)$($psgetItemInfo.Version)"] = @{
                                                                                                            SoftwareIdentity = $package
                                                                                                            PSGetItemInfo = $psgetItemInfo
                                                                                                        }
                }
            }
        }
    }
}
function Set-InstalledScriptsVariable
{
    # Initialize list of scripts installed by the PowerShellGet provider
    $script:PSGetInstalledScripts = [ordered]@{}
    $scriptPaths = @($script:ProgramFilesInstalledScriptInfosPath, $script:MyDocumentsInstalledScriptInfosPath)

    foreach ($location in $scriptPaths)
    {
        # find all scripts installed using PowerShellGet
        $scriptInfoFiles = Get-ChildItem -Path $location `
                                         -Filter "*$script:InstalledScriptInfoFileName" `
                                         -ErrorAction SilentlyContinue `
                                         -WarningAction SilentlyContinue

        if($scriptInfoFiles)
        {
            foreach ($scriptInfoFile in $scriptInfoFiles)
            {
                $psgetItemInfo = DeSerialize-PSObject -Path $scriptInfoFile.FullName

                $scriptFilePath = Microsoft.PowerShell.Management\Join-Path -Path $psgetItemInfo.InstalledLocation `
                                                                            -ChildPath "$($psgetItemInfo.Name).ps1"

                # Remove the InstalledScriptInfo.xml file if the actual script file was manually uninstalled by the user
                if(-not (Microsoft.PowerShell.Management\Test-Path -Path $scriptFilePath -PathType Leaf))
                {
                    Microsoft.PowerShell.Management\Remove-Item -Path $scriptInfoFile.FullName -Force -ErrorAction SilentlyContinue

                    continue
                }

                $package = New-SoftwareIdentityFromPSGetItemInfo -PSGetItemInfo $psgetItemInfo

                if($package)
                {
                    $script:PSGetInstalledScripts["$($psgetItemInfo.Name)$($psgetItemInfo.Version)"] = @{
                                                                                                            SoftwareIdentity = $package
                                                                                                            PSGetItemInfo = $psgetItemInfo
                                                                                                        }
                }
            }
        }
    }
}
function Set-ModuleSourcesVariable
{
    [CmdletBinding()]
    param(
        [switch]
        $Force,

        $Proxy,

        $ProxyCredential
    )

    if(-not $script:PSGetModuleSources -or $Force)
    {
        $isPersistRequired = $false
        if(Microsoft.PowerShell.Management\Test-Path $script:PSGetModuleSourcesFilePath)
        {
            $script:PSGetModuleSources = DeSerialize-PSObject -Path $script:PSGetModuleSourcesFilePath
        }
        else
        {
            $script:PSGetModuleSources = [ordered]@{}

            if(-not $script:PSGetModuleSources.Contains($Script:PSGalleryModuleSource))
            {
                $null = Set-PSGalleryRepository -Proxy $Proxy -ProxyCredential $ProxyCredential
            }
        }

        # Already registered repositories may not have the ScriptSourceLocation property, try to populate it from the existing SourceLocation
        # Also populate the PublishLocation and ScriptPublishLocation from the SourceLocation if PublishLocation is empty/null.
        #
        $script:PSGetModuleSources.Keys | Microsoft.PowerShell.Core\ForEach-Object {
                                              $moduleSource = $script:PSGetModuleSources[$_]

                                              if(-not (Get-Member -InputObject $moduleSource -Name $script:ScriptSourceLocation))
                                              {
                                                  $scriptSourceLocation = Get-ScriptSourceLocation -Location $moduleSource.SourceLocation -Proxy $Proxy -ProxyCredential $ProxyCredential

                                                  Microsoft.PowerShell.Utility\Add-Member -InputObject $script:PSGetModuleSources[$_] `
                                                                                          -MemberType NoteProperty `
                                                                                          -Name $script:ScriptSourceLocation `
                                                                                          -Value $scriptSourceLocation

                                                  if(Get-Member -InputObject $moduleSource -Name $script:PublishLocation)
                                                  {
                                                      if(-not $moduleSource.PublishLocation)
                                                      {
                                                          $script:PSGetModuleSources[$_].PublishLocation = Get-PublishLocation -Location $moduleSource.SourceLocation
                                                      }

                                                      Microsoft.PowerShell.Utility\Add-Member -InputObject $script:PSGetModuleSources[$_] `
                                                                                              -MemberType NoteProperty `
                                                                                              -Name $script:ScriptPublishLocation `
                                                                                              -Value $moduleSource.PublishLocation
                                                  }

                                                  $isPersistRequired = $true
                                              }
                                          }

        if($isPersistRequired)
        {
            Save-ModuleSources
        }
    }
}
function Set-PSGalleryRepository
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]
        $Trusted,

        [Parameter()]
        $Proxy,

        [Parameter()]
        $ProxyCredential
    )

    $psgalleryLocation = Resolve-Location -Location $Script:PSGallerySourceUri `
                                          -LocationParameterName 'SourceLocation' `
                                          -Proxy $Proxy `
                                          -ProxyCredential $ProxyCredential `
                                          -ErrorAction SilentlyContinue `
                                          -WarningAction SilentlyContinue

    $scriptSourceLocation = Resolve-Location -Location $Script:PSGalleryScriptSourceUri `
                                             -LocationParameterName 'ScriptSourceLocation' `
                                             -Proxy $Proxy `
                                             -ProxyCredential $ProxyCredential `
                                             -ErrorAction SilentlyContinue `
                                             -WarningAction SilentlyContinue
    if($psgalleryLocation)
    {
        $result = Ping-Endpoint -Endpoint $Script:PSGalleryPublishUri -AllowAutoRedirect:$false -Proxy $Proxy -ProxyCredential $ProxyCredential
        if ($result.ContainsKey($Script:ResponseUri) -and $result[$Script:ResponseUri])
        {
                $script:PSGalleryPublishUri = $result[$Script:ResponseUri]
        }

        $repository = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
                Name = $Script:PSGalleryModuleSource
                SourceLocation =  $psgalleryLocation
                PublishLocation = $Script:PSGalleryPublishUri
                ScriptSourceLocation = $scriptSourceLocation
                ScriptPublishLocation = $Script:PSGalleryPublishUri
                Trusted=$Trusted
                Registered=$true
                InstallationPolicy = if($Trusted) {'Trusted'} else {'Untrusted'}
                PackageManagementProvider=$script:NuGetProviderName
                ProviderOptions = @{}
            })

        $repository.PSTypeNames.Insert(0, "Microsoft.PowerShell.Commands.PSRepository")
        $script:PSGetModuleSources[$Script:PSGalleryModuleSource] = $repository

        Save-ModuleSources

        return $repository
    }
}
function Set-PSGetSettingsVariable
{
    [CmdletBinding()]
    param([switch]$Force)

    if(-not $script:PSGetSettings -or $Force)
    {
        if(Microsoft.PowerShell.Management\Test-Path -Path $script:PSGetSettingsFilePath)
        {
            $script:PSGetSettings = DeSerialize-PSObject -Path $script:PSGetSettingsFilePath
        }
        else
        {
            $script:PSGetSettings = [ordered]@{}
        }
    }
}

# Compare 2 strings, ignoring any trailing slashes or backslashes.
# This is not exactly the same as URL or path equivalence but it should work in practice
function Test-EquivalentLocation {
    [CmdletBinding()]
    [OutputType("bool")]
    param(
        [Parameter(Mandatory = $false)]
        [string]$LocationA,

        [Parameter(Mandatory = $false)]
        [string]$LocationB
    )

    $LocationA = $LocationA.TrimEnd("\/")
    $LocationB = $LocationB.TrimEnd("\/")
    return $LocationA -eq $LocationB
}
function Test-FileInUse
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [string]
        $FilePath
    )

    if(Microsoft.PowerShell.Management\Test-Path -LiteralPath $FilePath -PathType Leaf)
    {
        # Attempts to open a file and handles the exception if the file is already open/locked
        try
        {
            $fileInfo = New-Object System.IO.FileInfo $FilePath
            $fileStream = $fileInfo.Open( [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None )

            if ($fileStream)
            {
                $fileStream.Close()
            }
        }
        catch
        {
            Write-Debug "In Test-FileInUse function, unable to open the $FilePath file in ReadWrite access. $_"
            return $true
        }
    }

    return $false
}
function Test-ItemPrereleaseVersionRequirements
# Returns true if it meets the Required, Minimum, and Maximum version bounds.
{
    [CmdletBinding()]
    param(

        [ValidateNotNullOrEmpty()]
        [string]
        $Version,

        [string]
        $RequiredVersion,

        [string]
        $MinimumVersion,

        [string]
        $MaximumVersion
    )

    $result = ValidateAndGet-VersionPrereleaseStrings -Version $Version -CallerPSCmdlet $PSCmdlet
    if (-not $result)
    {
        # ValidateAndGet-VersionPrereleaseStrings throws the error.
        # returning to avoid further execution when different values are specified for -ErrorAction parameter
        return
    }
    $psgetitemVersion = $result["Version"]
    $psgetitemPrerelease = $result["Prerelease"]
    $psgetitemFullVersion = $result["FullVersion"]

    if($RequiredVersion)
    {
        $reqResult = ValidateAndGet-VersionPrereleaseStrings -Version $RequiredVersion -CallerPSCmdlet $PSCmdlet
        if (-not $reqResult)
        {
            # ValidateAndGet-VersionPrereleaseStrings throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }
        $reqFullVersion = $reqResult["FullVersion"]

        return ($reqFullVersion -eq $psgetitemFullVersion)
    }
    else
    {
        $minimumBoundMet = $false
        if ($MinimumVersion)
        {
            $minResult = ValidateAndGet-VersionPrereleaseStrings -Version $MinimumVersion -CallerPSCmdlet $PSCmdlet
            if (-not $minResult)
            {
                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }
            $minVersion = $minResult["Version"]
            $minPrerelease = $minResult["Prerelease"]

            # minimum bound is met if PSGet item version is greater than or equal to minimum version
            if (-not (Compare-PrereleaseVersions -FirstItemVersion $psgetitemVersion `
                                                 -FirstItemPrerelease $psgetitemPrerelease `
                                                 -SecondItemVersion $minVersion `
                                                 -SecondItemPrerelease $minPrerelease ))
            {
                $minimumBoundMet = $true
            }
        }
        else
        {
            $minimumBoundMet = $true
        }

        $maximumBoundMet = $false
        if ($MaximumVersion)
        {
            $maxResult = ValidateAndGet-VersionPrereleaseStrings -Version $MaximumVersion -CallerPSCmdlet $PSCmdlet
            if (-not $maxResult)
            {
                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }
            $maxVersion = $maxResult["Version"]
            $maxPrerelease = $maxResult["Prerelease"]

            # maximum bound is met if PSGet item version is less than or equal to maximum version
            if (-not (Compare-PrereleaseVersions -FirstItemVersion $maxVersion `
                                                 -FirstItemPrerelease $maxPrerelease `
                                                 -SecondItemVersion $psgetitemVersion `
                                                 -SecondItemPrerelease $psgetitemPrerelease ))
            {
                $maximumBoundMet = $true
            }
        }
        else
        {
            $maximumBoundMet = $true
        }

        return ($minimumBoundMet -and $maximumBoundMet)
    }
}
function Test-MicrosoftCertificate
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Signature]
        $AuthenticodeSignature
    )

    $IsMicrosoftCertificate = $false

    if($AuthenticodeSignature.SignerCertificate -and
       ('Microsoft.PowerShell.Commands.PowerShellGet.Win32Helpers' -as [Type]))
    {
        $X509Chain = $null
        $SafeX509ChainHandle = $null

        try
        {
            $X509Chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
            $null = $X509Chain.Build($AuthenticodeSignature.SignerCertificate)

            if($script:IsSafeX509ChainHandleAvailable)
            {
                $SafeX509ChainHandle = [Microsoft.PowerShell.Commands.PowerShellGet.Win32Helpers]::CertDuplicateCertificateChain($X509Chain.SafeHandle)
            }
            else
            {
                $SafeX509ChainHandle = [Microsoft.PowerShell.Commands.PowerShellGet.Win32Helpers]::CertDuplicateCertificateChain($X509Chain.ChainContext)
            }

            $IsMicrosoftCertificate = [Microsoft.PowerShell.Commands.PowerShellGet.Win32Helpers]::IsMicrosoftCertificate($SafeX509ChainHandle)
        }
        catch
        {
            Write-Debug "Exception in Test-MicrosoftCertificate function:  $_"
        }
        finally
        {
            if($SafeX509ChainHandle) { $SafeX509ChainHandle.Dispose() }

            # On .NET Framework 4.5.2 and earlier versions,
            # the X509Chain class does not implement the IDisposable interface and
            # therefore does not have a Dispose method.
            if($X509Chain -and (Get-Member -InputObject $X509Chain -Name Dispose -ErrorAction SilentlyContinue)) { $X509Chain.Dispose() }
        }
    }

    return $IsMicrosoftCertificate
}
function Test-ModuleInstalled
{
    [CmdletBinding(PositionalBinding=$false)]
    [OutputType("PSModuleInfo")]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $RequiredVersion
    )

    # Check if module is already installed
    $availableModule = Microsoft.PowerShell.Core\Get-Module -ListAvailable -Name $Name -Verbose:$false |
                           Microsoft.PowerShell.Core\Where-Object {
                               -not (Test-ModuleSxSVersionSupport) `
                               -or (-not $RequiredVersion) `
                               -or ($RequiredVersion.Trim() -eq $_.Version.ToString()) `
                               -or (Test-ItemPrereleaseVersionRequirements -Version $_.Version -RequiredVersion $RequiredVersion)
                            } | Microsoft.PowerShell.Utility\Select-Object -Unique -First 1 -ErrorAction Ignore

    return $availableModule
}
function Test-ModuleInUse
{
    [CmdletBinding()]
    [OutputType([bool])]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleBasePath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleVersion
    )

    $FileList = Get-ChildItem -Path $ModuleBasePath `
                              -File `
                              -Recurse `
                              -ErrorAction SilentlyContinue `
                              -WarningAction SilentlyContinue
    $IsModuleInUse = $false

    foreach($file in $FileList)
    {
        $IsModuleInUse = Test-FileInUse -FilePath $file.FullName

        if($IsModuleInUse)
        {
            break
        }
    }

    if($IsModuleInUse)
    {
        $message = $LocalizedData.ModuleVersionInUse -f ($ModuleVersion, $ModuleName)
        Write-Error -Message $message -ErrorId 'ModuleIsInUse' -Category InvalidOperation

        return $true
    }

    return $false
}
function Test-ModuleSxSVersionSupport
{
    # Side-by-Side module version is available on PowerShell 5.0 or later versions only
    # By default, PowerShell module versions will be installed/updated Side-by-Side.
    $PSVersionTable.PSVersion -ge '5.0.0'
}
function Test-RunningAsElevated
# Check if current user is running with elevated privileges
{
    [CmdletBinding()]
    [OutputType([bool])]
    Param()

    if(-not $script:IsRunningAsElevatedTested -and $script:IsRunningAsElevated)
    {
        if($script:IsWindows)
        {
            $wid=[System.Security.Principal.WindowsIdentity]::GetCurrent()
            $prp=new-object System.Security.Principal.WindowsPrincipal($wid)
            $adm=[System.Security.Principal.WindowsBuiltInRole]::Administrator
            $script:IsRunningAsElevated = $prp.IsInRole($adm)
        }
        elseif($script:IsCoreCLR)
        {
            # Permission models on *nix can be very complex, to the point that you could never possibly guess without simply trying what you need to try;
            # This is totally different from Windows where you can know what you can or cannot do with/without admin rights.
            $script:IsRunningAsElevated = $true
        }

        $script:IsRunningAsElevatedTested = $true
    }

    return $script:IsRunningAsElevated
}
function Test-ScriptInstalled
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $RequiredVersion
    )

    $scriptInfo = $null
    $scriptFileName = "$Name.ps1"
    $scriptPaths = @($script:ProgramFilesScriptsPath, $script:MyDocumentsScriptsPath)
    $scriptInfos = @()

    if ($RequiredVersion)
    {
        $reqResult = ValidateAndGet-VersionPrereleaseStrings -Version $RequiredVersion -CallerPSCmdlet $PSCmdlet
        if (-not $reqResult)
        {
            return
        }
        $reqFullVersion = $reqResult["FullVersion"]
    }


    foreach ($location in $scriptPaths)
    {
        $scriptFilePath = Microsoft.PowerShell.Management\Join-Path -Path $location -ChildPath $scriptFileName

        if(Microsoft.PowerShell.Management\Test-Path -Path $scriptFilePath -PathType Leaf)
        {
            $scriptInfo = $null
            try
            {
                $scriptInfo = Test-ScriptFileInfo -Path $scriptFilePath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
            catch
            {
                # Ignore any terminating error from the Test-ScriptFileInfo cmdlet,
                # if it does not contain valid Script metadata
                Write-Verbose -Message "$_"
            }

            if($scriptInfo)
            {
                $scriptInfos += $scriptInfo
            }
            else
            {
                # Since the script file doesn't contain the valid script metadata,
                # create dummy PSScriptInfo object with 0.0 version
                $scriptInfo = New-PSScriptInfoObject -Path $scriptFilePath
                $scriptInfo.$script:Version = [Version]'0.0'

                $scriptInfos += $scriptInfo
            }
        }
    }

    $scriptInfo = $scriptInfos | Microsoft.PowerShell.Core\Where-Object {
                                                                $thisResult = ValidateAndGet-VersionPrereleaseStrings -Version $_.Version -CallerPSCmdlet $PSCmdlet
                                                                if (-not $thisResult)
                                                                {
                                                                    return
                                                                }
                                                                $thisFullVersion = $thisResult["FullVersion"]
                                                                (-not $RequiredVersion) -or ($reqFullVersion -eq $thisFullVersion)
                                                            } | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

    return $scriptInfo
}
function Test-ValidManifestModule
{
    [CmdletBinding()]
    [OutputType([bool])]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleBasePath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InstallLocation,

        [Parameter()]
        [Switch]
        $SkipPublisherCheck,

        [Parameter()]
        [Switch]
        $AllowClobber,

        [Parameter()]
        [Switch]
        $IsUpdateOperation
    )

    Write-Verbose -Message ($LocalizedData.ValidatingTheModule -f $ModuleName,$ModuleBasePath)
    $manifestPath = Join-PathUtility -Path $ModuleBasePath -ChildPath "$ModuleName.psd1" -PathType File
    $PSModuleInfo = $null

    if(-not (Microsoft.PowerShell.Management\Test-Path $manifestPath -PathType Leaf))
    {
        $message = $LocalizedData.PathNotFound -f ($manifestPath)
        ThrowError -ExceptionName 'System.InvalidOperationException' `
                    -ExceptionMessage $message `
                    -ErrorId 'PathNotFound' `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation
    }

    $PSModuleInfo = Microsoft.PowerShell.Core\Test-ModuleManifest -Path $manifestPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    if(-not $PSModuleInfo)
    {
        $message = $LocalizedData.InvalidPSModule -f ($moduleName)
        ThrowError -ExceptionName 'System.InvalidOperationException' `
                    -ExceptionMessage $message `
                    -ErrorId 'InvalidManifestModule' `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation
    }
    else
    {
        Write-Verbose -Message ($LocalizedData.ValidatedModuleManifestFile -f $ModuleBasePath)
    }

    if($script:IsWindows)
    {
        Write-Verbose -Message ($LocalizedData.ValidateModuleAuthenticodeSignature -f $ModuleName)
        $ValidationResult = Validate-ModuleAuthenticodeSignature -CurrentModuleInfo $PSModuleInfo `
                                                                    -InstallLocation $InstallLocation `
                                                                    -IsUpdateOperation:$IsUpdateOperation `
                                                                    -SkipPublisherCheck:$SkipPublisherCheck
        
        if($ValidationResult)
        {
            # Checking for the possible command clobbering.
            Write-Verbose -Message ($LocalizedData.ValidateModuleCommandAlreadyAvailable -f $ModuleName)
            $ValidationResult = Validate-ModuleCommandAlreadyAvailable -CurrentModuleInfo $PSModuleInfo `
                                                                        -InstallLocation $InstallLocation `
                                                                        -AllowClobber:$AllowClobber `
                                                                        -IsUpdateOperation:$IsUpdateOperation
        }

        if(-not $ValidationResult)
        {
            $PSModuleInfo = $null
        }
    }

    return $PSModuleInfo
}
function Test-WebUri
{
    [CmdletBinding()]
    [OutputType([bool])]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $uri
    )

    return ($uri.AbsoluteURI -ne $null) -and ($uri.Scheme -match '[http|https]')
}
function Test-WildcardPattern
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Name
    )

    return [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Name)
}
function ThrowError
# Utility to throw an errorrecord
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionMessage,

        [System.Object]
        $ExceptionObject,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory
    )

    $exception = New-Object $ExceptionName $ExceptionMessage;
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $ErrorId, $ErrorCategory, $ExceptionObject
    $CallerPSCmdlet.ThrowTerminatingError($errorRecord)
}
function Validate-ModuleAuthenticodeSignature
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $CurrentModuleInfo,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InstallLocation,

        [Parameter()]
        [Switch]
        $IsUpdateOperation,

        [Parameter()]
        [Switch]
        $SkipPublisherCheck
    )

    # Skip the publisher check when -SkipPublisherCheck is specified and
    # it is not an update operation.
    if(-not $IsUpdateOperation -and $SkipPublisherCheck)
    {
        $Message = $LocalizedData.SkippingPublisherCheck -f ($CurrentModuleInfo.Version, $CurrentModuleInfo.Name)
        Write-Verbose -Message $message

        return $true
    }

    $InstalledModuleDetails = $null
    $InstalledModuleInfo = Test-ModuleInstalled -Name $CurrentModuleInfo.Name
    if($InstalledModuleInfo)
    {
        $InstalledModuleDetails = Get-InstalledModuleAuthenticodeSignature -InstalledModuleInfo $InstalledModuleInfo `
                                                                           -InstallLocation $InstallLocation
    }

    # Validate the catalog signature for the current module being installed.
    $ev = $null
    $CurrentModuleDetails = ValidateAndGet-AuthenticodeSignature -ModuleInfo $CurrentModuleInfo -ErrorVariable ev

    if($ev)
    {
        Write-Debug "$ev"
        return $false
    }

    if($InstalledModuleInfo)
    {
        $CurrentModuleAuthenticodePublisher = $null
        $CurrentModuleRootCA = $null
        $IsCurrentModuleSignedByMicrosoft = $false

        if($CurrentModuleDetails)
        {
            $CurrentModuleAuthenticodePublisher = $CurrentModuleDetails.Publisher
            $CurrentModuleRootCA = $CurrentModuleDetails.RootCertificateAuthority
            $IsCurrentModuleSignedByMicrosoft = $CurrentModuleDetails.IsMicrosoftCertificate

            $message = $LocalizedData.NewModuleVersionDetailsForPublisherValidation -f ($CurrentModuleInfo.Name,
                                                                                        $CurrentModuleInfo.Version,
                                                                                        $CurrentModuleDetails.Publisher,
                                                                                        $CurrentModuleDetails.RootCertificateAuthority,
                                                                                        $CurrentModuleDetails.IsMicrosoftCertificate)
            Write-Verbose $message
        }

        $InstalledModuleAuthenticodePublisher = $null
        $InstalledModuleRootCA = $null
        $IsInstalledModuleSignedByMicrosoft = $false
        $InstalledModuleVersion = [Version]'0.0'

        if($InstalledModuleDetails)
        {
            $InstalledModuleAuthenticodePublisher = $InstalledModuleDetails.Publisher
            $InstalledModuleRootCA = $InstalledModuleDetails.RootCertificateAuthority
            $IsInstalledModuleSignedByMicrosoft = $InstalledModuleDetails.IsMicrosoftCertificate
            $InstalledModuleVersion = $InstalledModuleDetails.Version

            $message = $LocalizedData.SourceModuleDetailsForPublisherValidation -f ($CurrentModuleInfo.Name,
                                                                                    $InstalledModuleDetails.Version,
                                                                                    $InstalledModuleDetails.ModuleBase,
                                                                                    $InstalledModuleDetails.Publisher,
                                                                                    $InstalledModuleDetails.RootCertificateAuthority,
                                                                                    $InstalledModuleDetails.IsMicrosoftCertificate)
            Write-Verbose $message
        }

        Write-Debug -Message "Previously-installed module publisher: $InstalledModuleAuthenticodePublisher"
        Write-Debug -Message "Current module publisher: $CurrentModuleAuthenticodePublisher"
        Write-Debug -Message "Is previously-installed module signed by Microsoft: $IsInstalledModuleSignedByMicrosoft"
        Write-Debug -Message "Is current module signed by Microsoft: $IsCurrentModuleSignedByMicrosoft"

        if($InstalledModuleAuthenticodePublisher)
        {
            if(-not $CurrentModuleAuthenticodePublisher)
            {
                $Message = $LocalizedData.ModuleIsNotCatalogSigned -f ($CurrentModuleInfo.Version, $CurrentModuleInfo.Name, "$($CurrentModuleInfo.Name).cat", $InstalledModuleAuthenticodePublisher, $InstalledModuleDetails.Version, $InstalledModuleDetails.ModuleBase)
                ThrowError -ExceptionName 'System.InvalidOperationException' `
                            -ExceptionMessage $message `
                            -ErrorId 'ModuleIsNotCatalogSigned' `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation
                return $false
            }
            elseif(($InstalledModuleAuthenticodePublisher -eq $CurrentModuleAuthenticodePublisher) -and
                    $InstalledModuleRootCA -and $CurrentModuleRootCA -and 
                    ($InstalledModuleRootCA -eq $CurrentModuleRootCA))
            {
                $Message = $LocalizedData.AuthenticodeIssuerMatch -f ($CurrentModuleAuthenticodePublisher, $CurrentModuleInfo.Name, $CurrentModuleInfo.Version, $InstalledModuleAuthenticodePublisher, $InstalledModuleInfo.Name, $InstalledModuleVersion)
                Write-Verbose -Message $message
            }
            elseif($IsInstalledModuleSignedByMicrosoft)
            {
                if($IsCurrentModuleSignedByMicrosoft)
                {
                    $Message = $LocalizedData.PublishersMatch -f ($CurrentModuleAuthenticodePublisher, $CurrentModuleInfo.Name, $CurrentModuleInfo.Version, $InstalledModuleAuthenticodePublisher, $InstalledModuleInfo.Name, $InstalledModuleVersion)
                    Write-Verbose -Message $message
                }
                else
                {
                    if (-not $script:WhitelistedModules.ContainsKey($CurrentModuleInfo.Name)) {
                        $Message = $LocalizedData.PublishersMismatch -f ($InstalledModuleInfo.Name, $InstalledModuleVersion, $CurrentModuleInfo.Name, $CurrentModuleAuthenticodePublisher, $CurrentModuleInfo.Version)
                        ThrowError -ExceptionName 'System.InvalidOperationException' `
                                -ExceptionMessage $message `
                                -ErrorId 'PublishersMismatch' `
                                -CallerPSCmdlet $PSCmdlet `
                                -ErrorCategory InvalidOperation

                        return $false
                    }

                    $Message = $LocalizedData.PublishersMismatchAsWarning -f ($InstalledModuleInfo.Name, $InstalledModuleVersion, $InstalledModuleAuthenticodePublisher, $CurrentModuleInfo.Version, $CurrentModuleAuthenticodePublisher)
                    Write-Warning $Message
                    return $true
                }
            }
            else
            {
                $Message = $LocalizedData.AuthenticodeIssuerMismatch -f ($CurrentModuleAuthenticodePublisher, $CurrentModuleInfo.Name, $CurrentModuleInfo.Version, $CurrentModuleRootCA, $InstalledModuleAuthenticodePublisher, $InstalledModuleInfo.Name, $InstalledModuleVersion, $InstalledModuleRootCA)
                ThrowError -ExceptionName 'System.InvalidOperationException' `
                            -ExceptionMessage $message `
                            -ErrorId 'AuthenticodeIssuerMismatch' `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation
                return $false
            }
        }
    }

    return $true
}
function Validate-ModuleCommandAlreadyAvailable
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [PSModuleInfo]
        $CurrentModuleInfo,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InstallLocation,

        [Parameter()]
        [Switch]
        $AllowClobber,

        [Parameter()]
        [Switch]
        $IsUpdateOperation
    )

    <#
        Install-Module must generate an error message when there is a conflict.
        User can specify -AllowClobber to avoid the message.
        Scenario: A large module could be separated into 2 smaller modules.
        Reason 1: the consumer might have to change code (aka: import-module) to use the command from the new module.
        Reason 2: it is too confusing to troubleshoot this problem if the user isn't informed right away.
    #>
    # When new module has some commands, no clobber error if
    # - AllowClobber is specified, or
    # - Installing to the same module base, or
    # - Update operation
    if($CurrentModuleInfo.ExportedCommands.Keys.Count -and
       -not $AllowClobber -and
       -not $IsUpdateOperation)
    {
        # Remove the version folder on 5.0 to get the actual module base folder without version
        if(Test-ModuleSxSVersionSupport)
        {
            $InstallLocation = Microsoft.PowerShell.Management\Split-Path -Path $InstallLocation
        }

        $InstalledModuleInfo = Test-ModuleInstalled -Name $CurrentModuleInfo.Name
        if(-not $InstalledModuleInfo -or -not $InstalledModuleInfo.ModuleBase.StartsWith($InstallLocation, [System.StringComparison]::OrdinalIgnoreCase))
        {
            # Throw an error if there is a command with the same name from a different source.
            $CommandNames = $CurrentModuleInfo.ExportedCommands.Values.Name

            # construct a hash with all of the commands in this module.
            $CommandNameHash = @{}
            $CommandNames | % { $CommandNameHash[$_] = 1 }
            
            $AvailableCommands = Microsoft.PowerShell.Core\Get-Command  `
                                                                      -ErrorAction Ignore `
                                                                      -WarningAction SilentlyContinue |
                                    Microsoft.PowerShell.Core\Where-Object { ($CommandNameHash.ContainsKey($_.Name)) -and
                                                                             ($_.ModuleName -ne $script:PSModuleProviderName) -and
                                                                             ($_.ModuleName -ne 'PSModule') -and
                                                                             ($_.ModuleName -ne $CurrentModuleInfo.Name) }
            if($AvailableCommands)
            {
                $AvailableCommandsList = ($AvailableCommands.Name | Microsoft.PowerShell.Utility\Select-Object -Unique -ErrorAction Ignore) -join ","
                $message = $LocalizedData.ModuleCommandAlreadyAvailable -f ($AvailableCommandsList, $CurrentModuleInfo.Name)
                ThrowError -ExceptionName 'System.InvalidOperationException' `
                           -ExceptionMessage $message `
                           -ErrorId 'CommandAlreadyAvailable' `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation

                return $false
            }
        }
    }

    return $true
}
function Validate-ScriptFileInfoParameters
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]
        $Parameters
    )

    $hasErrors = $false

    $Parameters.Keys | ForEach-Object {

                                    $parameterName = $_

                                    $parameterValue = $($Parameters[$parameterName])

                                    if("$parameterValue" -match '<#' -or "$parameterValue" -match '#>')
                                    {
                                        $message = $LocalizedData.InvalidParameterValue -f ($parameterValue, $parameterName)
                                        Write-Error -Message $message -ErrorId 'InvalidParameterValue' -Category InvalidArgument

                                        $hasErrors = $true
                                    }
                                }
    return (-not $hasErrors)
}
function Validate-VersionParameters
{
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet,

        [Parameter()]
        [String[]]
        $Name,

        [Parameter()]
        [string]
        $MinimumVersion,

        [Parameter()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [string]
        $MaximumVersion,

        [Parameter()]
        [Switch]
        $AllVersions,

        [Parameter()]
        [Switch]
        $AllowPrerelease,

        [Parameter()]
        [Switch]
        $TestWildcardsInName
    )

    if ($MinimumVersion)
    {
        $minResult = ValidateAndGet-VersionPrereleaseStrings -Version $MinimumVersion -CallerPSCmdlet $PSCmdlet
        if (-not $minResult)
        {
            # ValidateAndGet-VersionPrereleaseStrings throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }

        $minimumVersionVer = $minResult["Version"]
        $minimumVersionPrerelease = $minResult["Prerelease"]
    }
    if ($MaximumVersion)
    {
        $maxResult = ValidateAndGet-VersionPrereleaseStrings -Version $MaximumVersion -CallerPSCmdlet $PSCmdlet
        if (-not $maxResult)
        {
            # ValidateAndGet-VersionPrereleaseStrings throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }

        $maximumVersionVer = $maxResult["Version"]
        $maximumVersionPrerelease = $maxResult["Prerelease"]
    }
    if ($RequiredVersion)
    {
        $reqResult = ValidateAndGet-VersionPrereleaseStrings -Version $RequiredVersion -CallerPSCmdlet $PSCmdlet
        if (-not $reqResult)
        {
            # ValidateAndGet-VersionPrereleaseStrings throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }
    }

    if($TestWildcardsInName -and $Name -and (Test-WildcardPattern -Name "$Name"))
    {
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage ($LocalizedData.NameShouldNotContainWildcardCharacters -f "$($Name -join ',')") `
                   -ErrorId 'NameShouldNotContainWildcardCharacters' `
                   -CallerPSCmdlet $CallerPSCmdlet `
                   -ErrorCategory InvalidArgument `
                   -ExceptionObject $Name
    }
    elseif($AllVersions -and ($RequiredVersion -or $MinimumVersion -or $MaximumVersion))
    {
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $LocalizedData.AllVersionsCannotBeUsedWithOtherVersionParameters `
                   -ErrorId 'AllVersionsCannotBeUsedWithOtherVersionParameters' `
                   -CallerPSCmdlet $CallerPSCmdlet `
                   -ErrorCategory InvalidArgument
    }
    elseif($RequiredVersion -and ($MinimumVersion -or $MaximumVersion))
    {
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $LocalizedData.VersionRangeAndRequiredVersionCannotBeSpecifiedTogether `
                   -ErrorId "VersionRangeAndRequiredVersionCannotBeSpecifiedTogether" `
                   -CallerPSCmdlet $CallerPSCmdlet `
                   -ErrorCategory InvalidArgument
    }
    elseif($MinimumVersion -and $MaximumVersion -and (Compare-PrereleaseVersions -FirstItemVersion $maximumVersionVer `
                                                                                 -FirstItemPrerelease $maximumVersionPrerelease `
                                                                                 -SecondItemVersion $minimumVersionVer `
                                                                                 -SecondItemPrerelease $minimumVersionPrerelease))
    {
        $Message = $LocalizedData.MinimumVersionIsGreaterThanMaximumVersion -f ($MinimumVersion, $MaximumVersion)
        ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $Message `
                    -ErrorId "MinimumVersionIsGreaterThanMaximumVersion" `
                    -CallerPSCmdlet $CallerPSCmdlet `
                    -ErrorCategory InvalidArgument
    }
    elseif( (($MinimumVersion -match '-') -or ($MaximumVersion -match '-') -or ($RequiredVersion -match '-')) -and -not $AllowPrerelease)
    {
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $LocalizedData.AllowPrereleaseRequiredToUsePrereleaseStringInVersion `
                   -ErrorId "AllowPrereleaseRequiredToUsePrereleaseStringInVersion" `
                   -CallerPSCmdlet $CallerPSCmdlet `
                   -ErrorCategory InvalidArgument
    }
    elseif($AllVersions -or $AllowPrerelease -or $RequiredVersion -or $MinimumVersion -or $MaximumVersion)
    {
        if(-not $Name -or $Name.Count -ne 1 -or (Test-WildcardPattern -Name $Name[0]))
        {
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $LocalizedData.VersionParametersAreAllowedOnlyWithSingleName `
                       -ErrorId "VersionParametersAreAllowedOnlyWithSingleName" `
                       -CallerPSCmdlet $CallerPSCmdlet `
                       -ErrorCategory InvalidArgument
        }
    }

    return $true
}
function ValidateAndAdd-PSScriptInfoEntry
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]
        $PSScriptInfo,

        [Parameter(Mandatory=$true)]
        [string]
        $PropertyName,

        [Parameter()]
        $PropertyValue,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet
    )

    $Value = $PropertyValue
    $KeyName = $PropertyName

    # return if $KeyName value is not null in $PSScriptInfo
    if(-not $value -or -not $KeyName -or (Get-Member -InputObject $PSScriptInfo -Name $KeyName) -and $PSScriptInfo."$KeyName")
    {
        return
    }

    switch($PropertyName)
    {
        # Validate the property value and also use proper key name as users can specify the property name in any case.
        $script:Version {
                            $KeyName = $script:Version
                            $result = ValidateAndGet-VersionPrereleaseStrings -Version $Value -CallerPSCmdlet $CallerPSCmdlet
                            if (-not $result)
                            {
                                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                                return
                            }
                            $Version = $result["Version"]
                            $Prerelease = $result["Prerelease"]
                            $fullVersion = $result["FullVersion"]
                            $Value = if ($Prerelease) { $fullVersion } else { $Version }
                            break
                        }

        $script:Author  { $KeyName = $script:Author }

        $script:Guid  {
                        $KeyName = $script:Guid

                        [Guid]$guid = [System.Guid]::Empty
                        if([System.Guid]::TryParse($Value, ([ref]$guid)))
                        {
                            $Value = $guid
                        }
                        else
                        {
                            $message = $LocalizedData.InvalidGuid -f ($Value)
                            ThrowError -ExceptionName 'System.ArgumentException' `
                                       -ExceptionMessage $message `
                                       -ErrorId 'InvalidGuid' `
                                       -CallerPSCmdlet $CallerPSCmdlet `
                                       -ErrorCategory InvalidArgument `
                                       -ExceptionObject $Value
                            return
                        }

                        break
                     }

        $script:Description { $KeyName = $script:Description }

        $script:CompanyName { $KeyName = $script:CompanyName }

        $script:Copyright { $KeyName = $script:Copyright }

        $script:Tags {
                        $KeyName = $script:Tags
                        $Value = $Value -split '[,\s+]' | Microsoft.PowerShell.Core\Where-Object {$_}
                        break
                     }

        $script:LicenseUri {
                                $KeyName = $script:LicenseUri
                                if(-not (Test-WebUri -Uri $Value))
                                {
                                    $message = $LocalizedData.InvalidWebUri -f ($LicenseUri, "LicenseUri")
                                    ThrowError -ExceptionName "System.ArgumentException" `
                                                -ExceptionMessage $message `
                                                -ErrorId "InvalidWebUri" `
                                                -CallerPSCmdlet $CallerPSCmdlet `
                                                -ErrorCategory InvalidArgument `
                                                -ExceptionObject $Value
                                    return
                                }

                                $Value = [Uri]$Value
                           }

        $script:ProjectUri {
                                $KeyName = $script:ProjectUri
                                if(-not (Test-WebUri -Uri $Value))
                                {
                                    $message = $LocalizedData.InvalidWebUri -f ($ProjectUri, "ProjectUri")
                                    ThrowError -ExceptionName "System.ArgumentException" `
                                                -ExceptionMessage $message `
                                                -ErrorId "InvalidWebUri" `
                                                -CallerPSCmdlet $CallerPSCmdlet `
                                                -ErrorCategory InvalidArgument `
                                                -ExceptionObject $Value
                                    return
                                }

                                $Value = [Uri]$Value
                           }

        $script:IconUri {
                            $KeyName = $script:IconUri
                            if(-not (Test-WebUri -Uri $Value))
                            {
                                $message = $LocalizedData.InvalidWebUri -f ($IconUri, "IconUri")
                                ThrowError -ExceptionName "System.ArgumentException" `
                                            -ExceptionMessage $message `
                                            -ErrorId "InvalidWebUri" `
                                            -CallerPSCmdlet $CallerPSCmdlet `
                                            -ErrorCategory InvalidArgument `
                                            -ExceptionObject $Value
                                return
                            }

                            $Value = [Uri]$Value
                        }

        $script:ExternalModuleDependencies {
                                               $KeyName = $script:ExternalModuleDependencies
                                               $Value = $Value -split '[,\s+]' | Microsoft.PowerShell.Core\Where-Object {$_}
                                           }

        $script:ReleaseNotes { $KeyName = $script:ReleaseNotes }

        $script:RequiredModules { $KeyName = $script:RequiredModules }

        $script:RequiredScripts {
                                    $KeyName = $script:RequiredScripts
                                    $Value = $Value -split ',(?=[^\[^\(]\w(?!\w+[\)\]]))|\s' | Microsoft.PowerShell.Core\Where-Object {$_}
                                }

        $script:ExternalScriptDependencies {
                                               $KeyName = $script:ExternalScriptDependencies
                                               $Value = $Value -split '[,\s+]' | Microsoft.PowerShell.Core\Where-Object {$_}
                                           }

        $script:DefinedCommands  { $KeyName = $script:DefinedCommands }

        $script:DefinedFunctions { $KeyName = $script:DefinedFunctions }

        $script:DefinedWorkflows { $KeyName = $script:DefinedWorkflows }

		$script:PrivateData { $KeyName = $script:PrivateData }
    }

    Microsoft.PowerShell.Utility\Add-Member -InputObject $PSScriptInfo `
                                            -MemberType NoteProperty `
                                            -Name $KeyName `
                                            -Value $Value `
                                            -Force
}
function ValidateAndGet-AuthenticodeSignature
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [PSModuleInfo]
        $ModuleInfo
    )

    $ModuleDetails = $null
    $AuthenticodeSignature = $null

    $ModuleName = $ModuleInfo.Name
    $ModuleBasePath = $ModuleInfo.ModuleBase
    $ModuleManifestName = "$ModuleName.psd1"
    $CatalogFileName = "$ModuleName.cat"
    $CatalogFilePath = Microsoft.PowerShell.Management\Join-Path -Path $ModuleBasePath -ChildPath $CatalogFileName

    if(Microsoft.PowerShell.Management\Test-Path -Path $CatalogFilePath -PathType Leaf)
    {
        $message = $LocalizedData.CatalogFileFound -f ($CatalogFileName, $ModuleName)
        Write-Verbose -Message $message

        $AuthenticodeSignature = Microsoft.PowerShell.Security\Get-AuthenticodeSignature -FilePath $CatalogFilePath

        if(-not $AuthenticodeSignature -or ($AuthenticodeSignature.Status -ne "Valid"))
        {
            $message = $LocalizedData.InvalidModuleAuthenticodeSignature -f ($ModuleName, $CatalogFileName)
            ThrowError -ExceptionName 'System.InvalidOperationException' `
                        -ExceptionMessage $message `
                        -ErrorId 'InvalidAuthenticodeSignature' `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidOperation

            return
        }

        Write-Verbose -Message ($LocalizedData.ValidAuthenticodeSignature -f @($CatalogFileName, $ModuleName))

        if(Get-Command -Name Test-FileCatalog -Module Microsoft.PowerShell.Security -ErrorAction Ignore)
        {
            Write-Verbose -Message ($LocalizedData.ValidatingCatalogSignature -f @($ModuleName, $CatalogFileName))

            # Skip the PSGetModuleInfo.xml and ModuleName.cat files in the catalog validation
            $TestFileCatalogResult = Microsoft.PowerShell.Security\Test-FileCatalog -Path $ModuleBasePath `
                                                                                    -CatalogFilePath $CatalogFilePath `
                                                                                    -FilesToSkip $script:PSGetItemInfoFileName,'*.cat','*.nupkg','*.nuspec' `
                                                                                    -Detailed `
                                                                                    -ErrorAction SilentlyContinue
            if(-not $TestFileCatalogResult -or
                ($TestFileCatalogResult.Status -ne "Valid") -or
                ($TestFileCatalogResult.Signature.Status -ne "Valid"))
            {
                $message = $LocalizedData.InvalidCatalogSignature -f ($ModuleName, $CatalogFileName)
                ThrowError -ExceptionName 'System.InvalidOperationException' `
                            -ExceptionMessage $message `
                            -ErrorId 'InvalidCatalogSignature' `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation
                return
            }
            else
            {
                Write-Verbose -Message ($LocalizedData.ValidCatalogSignature -f @($CatalogFileName, $ModuleName))
            }
        }
    }
    else
    {
        Write-Verbose -Message ($LocalizedData.CatalogFileNotFoundInNewModule -f ($CatalogFileName, $ModuleName))

        $message = "Using the '{0}' file for getting the authenticode signature." -f ($ModuleManifestName)
        Write-Debug -Message $message

        $AuthenticodeSignature = Microsoft.PowerShell.Security\Get-AuthenticodeSignature -FilePath $ModuleInfo.Path

        if($AuthenticodeSignature)
        {
            if($AuthenticodeSignature.Status -eq "Valid")
            {
                Write-Verbose -Message ($LocalizedData.ValidAuthenticodeSignatureInFile -f @($ModuleManifestName, $ModuleName))
            }
            elseif($AuthenticodeSignature.Status -ne "NotSigned")
            {
                $message = $LocalizedData.InvalidModuleAuthenticodeSignature -f ($ModuleName, $ModuleManifestName)
                ThrowError -ExceptionName 'System.InvalidOperationException' `
                           -ExceptionMessage $message `
                           -ErrorId 'InvalidAuthenticodeSignature' `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation
                return
            }
        }
    }

    if($AuthenticodeSignature)
    {
        $ModuleDetails = @{}
        $ModuleDetails['AuthenticodeSignature'] = $AuthenticodeSignature
        $ModuleDetails['Version'] = $ModuleInfo.Version
        $ModuleDetails['ModuleBase']=$ModuleInfo.ModuleBase
        $ModuleDetails['IsMicrosoftCertificate'] = Test-MicrosoftCertificate -AuthenticodeSignature $AuthenticodeSignature
        $PublisherDetails = Get-AuthenticodePublisher -AuthenticodeSignature $AuthenticodeSignature
        $ModuleDetails['Publisher'] = if($PublisherDetails) {$PublisherDetails.Publisher}
        $ModuleDetails['RootCertificateAuthority'] = if($PublisherDetails) {$PublisherDetails.PublisherRootCA}

        $message = $LocalizedData.NewModuleVersionDetailsForPublisherValidation -f ($ModuleInfo.Name, $ModuleInfo.Version, $ModuleDetails.Publisher, $ModuleDetails.RootCertificateAuthority, $ModuleDetails.IsMicrosoftCertificate)
        Write-Debug $message
    }

    return $ModuleDetails
}
function ValidateAndGet-NuspecVersionString
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Version
    )

    $versionPattern = '^((?<MinRule>[\[\(])?((?<MinVersion>[^:\(\[\)\]\,]+))?((?<Comma>[\,])?(?<MaxVersion>[^:\(\[\)\]\,]+)?)?(?<MaxRule>[\]\)])?)$'
    $VersionInfo = @{}

    if ( -not ($Version -match $versionPattern))
    {
        $message = $LocalizedData.FailedToParseRequiredScriptsVersion -f ('Invalid Version format', $Version, $LocalizedData.RequiredScriptVersoinFormat)
        Write-Verbose $message
        ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "UnableToResolveScriptDependency" `
                    -CallerPSCmdlet $CallerPSCmdlet `
                    -ErrorCategory InvalidOperation
    }

    if ($Matches.Keys -Contains 'MinRule' -xor $Matches.Keys -Contains 'MaxRule')
    {
        $message = $LocalizedData.FailedToParseRequiredScriptsVersion -f ('Minimum and Maximum inclusive/exclusive condition mismatch', $Version, $LocalizedData.RequiredScriptVersoinFormat)
        Write-Verbose $message
        ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "UnableToResolveScriptDependency" `
                    -CallerPSCmdlet $CallerPSCmdlet `
                    -ErrorCategory InvalidOperation
    }

    if (-not ($Matches.Keys -Contains 'MinVersion' -or $Matches.Keys -Contains 'MaxVersion'))
    {
        $message = $LocalizedData.FailedToParseRequiredScriptsVersion -f ('No version.', $Version, $LocalizedData.RequiredScriptVersoinFormat)
        Write-Verbose $message
        ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "UnableToResolveScriptDependency" `
                    -CallerPSCmdlet $CallerPSCmdlet `
                    -ErrorCategory InvalidOperation
    }

    if ((-not ($Matches.Keys -Contains 'MinRule' -and $Matches.Keys -Contains 'MaxRule')) -and $Matches.Keys -Contains 'Comma')
    {
        $message = $LocalizedData.FailedToParseRequiredScriptsVersion -f ('Invalid version format', $Version, $LocalizedData.RequiredScriptVersoinFormat)
        Write-Verbose $message
        ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "UnableToResolveScriptDependency" `
                    -CallerPSCmdlet $CallerPSCmdlet `
                    -ErrorCategory InvalidOperation
    }

    if ($Matches.Keys -Contains 'MaxRule' -and -not ($Matches['MaxRule'] -eq ']') )
    {
        $message = $LocalizedData.FailedToParseRequiredScriptsVersion -f ('Maximum version condition should be inclusive', $Version, $LocalizedData.RequiredScriptVersoinFormat)
        Write-Verbose $message
        ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "UnableToResolveScriptDependency" `
                    -CallerPSCmdlet $CallerPSCmdlet `
                    -ErrorCategory InvalidOperation
    }

    if ($Matches.Keys -Contains 'MinVersion' -and $Matches.Keys -Contains 'MaxVersion')
    {
        if ($Matches.Keys -Contains 'MinRule' -and $Matches.Keys -Contains 'MaxRule')
        {
            if ($Matches['MinRule'] -eq '[')
            {
                $VersionInfo['MinimumVersion'] = $Matches['MinVersion']
                $VersionInfo['MaximumVersion'] = $Matches['MaxVersion']
            }
            else
            {
                $message = $LocalizedData.FailedToParseRequiredScriptsVersion -f ('Minimum version condition should be inclusive', $Version, $LocalizedData.RequiredScriptVersoinFormat)
                Write-Verbose $message
                ThrowError -ExceptionName "System.ArgumentException" `
                            -ExceptionMessage $message `
                            -ErrorId "UnableToResolveScriptDependency" `
                            -CallerPSCmdlet $CallerPSCmdlet `
                            -ErrorCategory InvalidOperation
            }
        }
        else
        {
            $message = $LocalizedData.FailedToParseRequiredScriptsVersion -f ('Minimum and Maximum inclusive/exclusive condition mismatch', $Version, $LocalizedData.RequiredScriptVersoinFormat)
            Write-Verbose $message
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId "UnableToResolveScriptDependency" `
                        -CallerPSCmdlet $CallerPSCmdlet `
                        -ErrorCategory InvalidOperation
        }

        return $VersionInfo
    }

    if ($Matches.Keys -Contains 'MinVersion')
    {
        if ($Matches.Keys -Contains 'MinRule' -and $Matches.Keys -Contains 'MaxRule')
        {
            if (($Matches['MinRule'] -eq '[') -and ($Matches['MaxRule'] -eq ']'))
            {
                $VersionInfo['RequiredVersion'] = $Matches['MinVersion']
                return $VersionInfo
            }
        }
        else
        {
            $VersionInfo['MinimumVersion'] = $Matches['MinVersion']
            return $VersionInfo
        }

        $message = $LocalizedData.FailedToParseRequiredScriptsVersion -f ("Minimum and Maximum version rules should be inclusive for 'RequiredVersion'", $Version, $LocalizedData.RequiredScriptVersoinFormat)
        Write-Verbose $message
        ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "UnableToResolveScriptDependency" `
                    -CallerPSCmdlet $CallerPSCmdlet `
                    -ErrorCategory InvalidOperation
    }

    if ($Matches.Keys -Contains 'MaxVersion')
    {
        $VersionInfo['MaximumVersion'] = $Matches['MaxVersion']
        return $VersionInfo
    }

    $message = $LocalizedData.FailedToParseRequiredScriptsVersion -f ("Failed to parse version string", $Version, $LocalizedData.RequiredScriptVersoinFormat)
    Write-Verbose $message
    ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "UnableToResolveScriptDependency" `
                -CallerPSCmdlet $CallerPSCmdlet `
                -ErrorCategory InvalidOperation
}
function ValidateAndGet-RequiredModuleDetails
{
    param(
        [Parameter()]
        $ModuleManifestRequiredModules,

        [Parameter()]
        [PSModuleInfo[]]
        $RequiredPSModuleInfos,

        [Parameter(Mandatory=$true)]
        [string]
        $Repository,

        [Parameter(Mandatory=$true)]
        [PSModuleInfo]
        $DependentModuleInfo,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet,

        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )

    $RequiredModuleDetails = @()

    if(-not $RequiredPSModuleInfos)
    {
        return $RequiredModuleDetails
    }

    if($ModuleManifestRequiredModules)
    {
        ForEach($RequiredModule in $ModuleManifestRequiredModules)
        {
            $ModuleName = $null
            $VersionString = $null

            $ReqModuleInfo = @{}

            $FindModuleArguments = @{
                                        Repository = $Repository
                                        Verbose = $VerbosePreference
                                        ErrorAction = 'SilentlyContinue'
                                        WarningAction = 'SilentlyContinue'
                                        Debug = $DebugPreference
                                    }
            if ($PSBoundParameters.ContainsKey('Credential'))
            {
                $FindModuleArguments.Add('Credential',$Credential)
            }

            # ModuleSpecification case
            if($RequiredModule.GetType().ToString() -eq 'System.Collections.Hashtable')
            {
                $ModuleName = $RequiredModule.ModuleName

                # Version format in NuSpec:
                # "[2.0]" --> (== 2.0) Required Version
                # "2.0" --> (>= 2.0) Minimum Version
                if($RequiredModule.Keys -Contains "RequiredVersion")
                {
                    $FindModuleArguments['RequiredVersion'] = $RequiredModule.RequiredVersion
                    $ReqModuleInfo['RequiredVersion'] = $RequiredModule.RequiredVersion
                }
                elseif($RequiredModule.Keys -Contains "ModuleVersion")
                {
                    $FindModuleArguments['MinimumVersion'] = $RequiredModule.ModuleVersion
                    $ReqModuleInfo['MinimumVersion'] = $RequiredModule.ModuleVersion
                }

                if($RequiredModule.Keys -Contains 'MaximumVersion' -and $RequiredModule.MaximumVersion)
                {
                    # * can be specified in the MaximumVersion of a ModuleSpecification to convey that maximum possible value of that version part.
                    # like 1.0.0.* --> 1.0.0.99999999
                    # replace * with 99999999, PowerShell core takes care validating the * to be the last character in the version string.
                    $maximumVersion = $RequiredModule.MaximumVersion -replace '\*','99999999'

                    $FindModuleArguments['MaximumVersion'] = $maximumVersion
                    $ReqModuleInfo['MaximumVersion'] = $maximumVersion
                }
            }
            else
            {
                # Just module name was specified
                $ModuleName = $RequiredModule.ToString()
            }

            if((Get-ExternalModuleDependencies -PSModuleInfo $DependentModuleInfo) -contains $ModuleName)
            {
                Write-Verbose -Message ($LocalizedData.SkippedModuleDependency -f $ModuleName)

                continue
            }

            # Skip this module name if it's name is not in $RequiredPSModuleInfos.
            # This is required when a ModuleName is part of the NestedModules list of the actual module.
            # $ModuleName is packaged as part of the actual module When $RequiredPSModuleInfos doesn't contain it's name.
            if($RequiredPSModuleInfos.Name -notcontains $ModuleName)
            {
                continue
            }

            $ReqModuleInfo['Name'] = $ModuleName

            # Add the dependency only if the module is available on the gallery
            # Otherwise Module installation will fail as all required modules need to be available on
            # the same Repository
            $FindModuleArguments['Name'] = $ModuleName

            $psgetItemInfo = Find-Module @FindModuleArguments  |
                                        Microsoft.PowerShell.Core\Where-Object {$_.Name -eq $ModuleName} |
                                            Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore

            if(-not $psgetItemInfo)
            {
                $message = $LocalizedData.UnableToResolveModuleDependency -f ($ModuleName, $DependentModuleInfo.Name, $Repository, $ModuleName, $Repository, $ModuleName, $ModuleName)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "UnableToResolveModuleDependency" `
                            -CallerPSCmdlet $CallerPSCmdlet `
                            -ErrorCategory InvalidOperation
            }

            $RequiredModuleDetails += $ReqModuleInfo
        }
    }
    else
    {
        # If Import-LocalizedData cmdlet was failed to read the .psd1 contents
        # use provided $RequiredPSModuleInfos (PSModuleInfo.RequiredModules or PSModuleInfo.NestedModules of the actual dependent module)

        $FindModuleArguments = @{
                                    Repository = $Repository
                                    Verbose = $VerbosePreference
                                    ErrorAction = 'SilentlyContinue'
                                    WarningAction = 'SilentlyContinue'
                                    Debug = $DebugPreference
                                }
        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $FindModuleArguments.Add('Credential',$Credential)
        }

        ForEach($RequiredModuleInfo in $RequiredPSModuleInfos)
        {
            $ModuleName = $requiredModuleInfo.Name

            if((Get-ExternalModuleDependencies -PSModuleInfo $DependentModuleInfo) -contains $ModuleName)
            {
                Write-Verbose -Message ($LocalizedData.SkippedModuleDependency -f $ModuleName)

                continue
            }

            $FindModuleArguments['Name'] = $ModuleName
            $FindModuleArguments['MinimumVersion'] = $requiredModuleInfo.Version

            $psgetItemInfo = Find-Module @FindModuleArguments |
                                        Microsoft.PowerShell.Core\Where-Object {$_.Name -eq $ModuleName} |
                                            Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore

            if(-not $psgetItemInfo)
            {
                $message = $LocalizedData.UnableToResolveModuleDependency -f ($ModuleName, $DependentModuleInfo.Name, $Repository, $ModuleName, $Repository, $ModuleName, $ModuleName)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "UnableToResolveModuleDependency" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation
            }

            $RequiredModuleDetails += @{
                                            Name=$_.Name
                                            MinimumVersion=$_.Version
                                       }
        }
    }

    return $RequiredModuleDetails
}
function ValidateAndGet-ScriptDependencies
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Repository,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]
        $DependentScriptInfo,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet,

        [Parameter()]
        [PSCredential]
        $Credential
    )

    $DependenciesDetails = @()

    # Validate dependent modules
    $RequiredModuleSpecification = $DependentScriptInfo.RequiredModules
    if($RequiredModuleSpecification)
    {
        ForEach($moduleSpecification in $RequiredModuleSpecification)
        {
            $ModuleName = $moduleSpecification.Name

            $FindModuleArguments = @{
                                        Repository = $Repository
                                        Verbose = $VerbosePreference
                                        ErrorAction = 'SilentlyContinue'
                                        WarningAction = 'SilentlyContinue'
                                        Debug = $DebugPreference
                                    }
            if ($PSBoundParameters.ContainsKey('Credential'))
            {
                $FindModuleArguments.Add('Credential',$Credential)
            }

            if($DependentScriptInfo.ExternalModuleDependencies -contains $ModuleName)
            {
                Write-Verbose -Message ($LocalizedData.SkippedModuleDependency -f $ModuleName)

                continue
            }

            $FindModuleArguments['Name'] = $ModuleName
            $ReqModuleInfo = @{}
            $ReqModuleInfo['Name'] = $ModuleName

            if($moduleSpecification.Version)
            {
                $FindModuleArguments['MinimumVersion'] = $moduleSpecification.Version
                $ReqModuleInfo['MinimumVersion'] = $moduleSpecification.Version
            }
            elseif((Get-Member -InputObject $moduleSpecification -Name RequiredVersion) -and $moduleSpecification.RequiredVersion)
            {
                $FindModuleArguments['RequiredVersion'] = $moduleSpecification.RequiredVersion
                $ReqModuleInfo['RequiredVersion'] = $moduleSpecification.RequiredVersion
            }

            if((Get-Member -InputObject $moduleSpecification -Name MaximumVersion) -and $moduleSpecification.MaximumVersion)
            {
                # * can be specified in the MaximumVersion of a ModuleSpecification to convey that maximum possible value of that version part.
                # like 1.0.0.* --> 1.0.0.99999999
                # replace * with 99999999, PowerShell core takes care validating the * to be the last character in the version string.
                $maximumVersion = $moduleSpecification.MaximumVersion -replace '\*','99999999'
                $FindModuleArguments['MaximumVersion'] = $maximumVersion
                $ReqModuleInfo['MaximumVersion'] = $maximumVersion
            }

            $psgetItemInfo = Find-Module @FindModuleArguments  |
                                        Microsoft.PowerShell.Core\Where-Object {$_.Name -eq $ModuleName} |
                                            Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore

            if(-not $psgetItemInfo)
            {
                $message = $LocalizedData.UnableToResolveScriptDependency -f ('module', $ModuleName, $DependentScriptInfo.Name, $Repository, 'ExternalModuleDependencies')
                ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "UnableToResolveScriptDependency" `
                            -CallerPSCmdlet $CallerPSCmdlet `
                            -ErrorCategory InvalidOperation
            }

            $DependenciesDetails += $ReqModuleInfo
        }
    }

    # Validate dependent scrips
    $RequiredScripts = $DependentScriptInfo.RequiredScripts
    if($RequiredScripts)
    {
        ForEach($requiredScript in $RequiredScripts)
        {
            $FindScriptArguments = @{
                                        Repository = $Repository
                                        Verbose = $VerbosePreference
                                        ErrorAction = 'SilentlyContinue'
                                        WarningAction = 'SilentlyContinue'
                                        Debug = $DebugPreference
                                    }
            $ReqScriptInfo = @{}

            if ($PSBoundParameters.ContainsKey('Credential'))
            {
                $FindScriptArguments.Add('Credential',$Credential)
            }

            if (-not ($requiredScript -match '^(?<ScriptName>[^:]+)(:(?<Version>[^:\s]+))?$'))
            {
                $message = $LocalizedData.FailedToParseRequiredScripts -f ($requiredScript)

                ThrowError `
                    -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "FailedToParseRequiredScripts" `
                    -CallerPSCmdlet $CallerPSCmdlet `
                    -ErrorCategory InvalidOperation
            }

            $scriptName = $Matches['ScriptName']
            if ($DependentScriptInfo.ExternalScriptDependencies -contains $scriptName)
            {
                Write-Verbose -Message ($LocalizedData.SkippedScriptDependency -f $scriptName)

                continue
            }

            if ($Matches.Keys -Contains 'Version')
            {
                $ReqScriptInfo = ValidateAndGet-NuspecVersionString -Version $Matches['Version']

                if($ReqScriptInfo.Keys -Contains 'RequiredVersion')
                {
                    $FindScriptArguments['RequiredVersion'] = $ReqScriptInfo['RequiredVersion']
                }
                elseif($ReqScriptInfo.Keys -Contains 'MinimumVersion')
                {
                    $FindScriptArguments['MinimumVersion'] = $ReqScriptInfo['MinimumVersion']
                }
                if($ReqScriptInfo.Keys -Contains 'MaximumVersion')
                {
                    $FindScriptArguments['MaximumVersion'] = $ReqScriptInfo['MaximumVersion']
                }
            }

            $ReqScriptInfo['Name'] = $scriptName
            $FindScriptArguments['Name'] = $scriptName
            $psgetItemInfo = Find-Script @FindScriptArguments  |
                                        Microsoft.PowerShell.Core\Where-Object {$_.Name -eq $scriptName} |
                                            Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore

            if(-not $psgetItemInfo)
            {
                $message = $LocalizedData.UnableToResolveScriptDependency -f ('script', $scriptName, $DependentScriptInfo.Name, $Repository, 'ExternalScriptDependencies')
                ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "UnableToResolveScriptDependency" `
                            -CallerPSCmdlet $CallerPSCmdlet `
                            -ErrorCategory InvalidOperation
            }

            $DependenciesDetails += $ReqScriptInfo
        }
    }

    return $DependenciesDetails
}
function ValidateAndGet-VersionPrereleaseStrings
# Separates Version from Prerelease string (if needed) and validates each.
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Version,

        [string]
        $Prerelease,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet
    )

    # Scripts scenario
    if ($Version -match '-' -and -not $Prerelease)
    {
        $Version,$Prerelease = $Version -split '-',2
    }

    # Remove leading hyphen (if present) and trim whitespace
    if ($Prerelease -and $Prerelease.StartsWith('-') )
    {
        $Prerelease = $Prerelease -split '-',2 | Select-Object -Skip 1
    }
    if ($Prerelease)
    {
        $Prerelease = $Prerelease.Trim()
    }

    # only these characters are allowed in a prerelease string
    $validCharacters = "^[a-zA-Z0-9]+$"
    $prereleaseStringValid = $Prerelease -match $validCharacters
    if ($Prerelease -and -not $prereleaseStringValid)
    {
        $message = $LocalizedData.InvalidCharactersInPrereleaseString -f $Prerelease
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $message `
                   -ErrorId "InvalidCharactersInPrereleaseString" `
                   -CallerPSCmdlet $CallerPSCmdlet `
                   -ErrorCategory InvalidOperation `
                   -ExceptionObject $Prerelease
    }

    # Validate that Version contains exactly 3 parts
    if ($Prerelease -and -not ($Version.ToString().Split('.').Count -eq 3))
    {
        $message = $LocalizedData.IncorrectVersionPartsCountForPrereleaseStringUsage -f $Version
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $message `
                   -ErrorId "IncorrectVersionPartsCountForPrereleaseStringUsage" `
                   -CallerPSCmdlet $CallerPSCmdlet `
                   -ErrorCategory InvalidOperation `
                   -ExceptionObject $Version
    }

    # try parsing version string
    [Version]$VersionVersion = $null
    if (-not ( [System.Version]::TryParse($Version, [ref]$VersionVersion) ))
    {
        $message = $LocalizedData.InvalidVersion -f ($Version)
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $message `
                   -ErrorId "InvalidVersion" `
                   -CallerPSCmdlet $CallerPSCmdlet `
                   -ErrorCategory InvalidArgument `
                   -ExceptionObject $Version
    }

    $fullVersion = if ($Prerelease) { "$VersionVersion-$Prerelease" } else { "$VersionVersion" }

    $results = @{
        Version = "$VersionVersion"
        Prerelease = $Prerelease
        FullVersion = $fullVersion
    }
    return $results
}
function ValidateAndSet-PATHVariableIfUserAccepts
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $Scope,

        [Parameter(Mandatory=$true)]
        [string]
        $ScopePath,

        [Parameter()]
        [Switch]
        $NoPathUpdate,

        [Parameter()]
        [Switch]
        $Force,

        [Parameter()]
        $Request
    )

    if(-not $script:IsWindows)
    {
        return
    }

    Set-PSGetSettingsVariable

    # Check and add the scope path to PATH environment variable if USER accepts the prompt.
    if($Scope -eq 'AllUsers')
    {
        $envVariableTarget = $script:EnvironmentVariableTarget.Machine
        $scriptPATHPromptQuery=$LocalizedData.ScriptPATHPromptQuery -f $ScopePath
        $scopeSpecificKey = 'AllUsersScope_AllowPATHChangeForScripts'
    }
    else
    {
        $envVariableTarget = $script:EnvironmentVariableTarget.User
        $scriptPATHPromptQuery=$LocalizedData.ScriptPATHPromptQuery -f $ScopePath
        $scopeSpecificKey = 'CurrentUserScope_AllowPATHChangeForScripts'
    }

    $AlreadyPromptedForScope = $script:PSGetSettings.Contains($scopeSpecificKey)
    Write-Debug "Already prompted for the current scope:$AlreadyPromptedForScope"

    if(-not $AlreadyPromptedForScope)
    {
        # Read the file contents once again to ensure that it was not set in another PowerShell Session
        Set-PSGetSettingsVariable -Force

        $AlreadyPromptedForScope = $script:PSGetSettings.Contains($scopeSpecificKey)
        Write-Debug "After reading contents of PowerShellGetSettings.xml file, the Already prompted for the current scope:$AlreadyPromptedForScope"

        if($AlreadyPromptedForScope)
        {
            return
        }

        $userResponse = $false

        if(-not $NoPathUpdate)
        {
            $scopePathEndingWithBackSlash = "$scopePath\"

            # Check and add the $scopePath to $env:Path value
            if( (($env:PATH -split ';') -notcontains $scopePath) -and
                (($env:PATH -split ';') -notcontains $scopePathEndingWithBackSlash))
            {
                if($Force)
                {
                    $userResponse = $true
                }
                else
                {
                    $scriptPATHPromptCaption = $LocalizedData.ScriptPATHPromptCaption

                    if($Request)
                    {
                        $userResponse = $Request.ShouldContinue($scriptPATHPromptQuery, $scriptPATHPromptCaption)
                    }
                    else
                    {
                        $userResponse = $PSCmdlet.ShouldContinue($scriptPATHPromptQuery, $scriptPATHPromptCaption)
                    }
                }

                if($userResponse)
                {
                    $currentPATHValue = Get-EnvironmentVariable -Name 'PATH' -Target $envVariableTarget

                    if((($currentPATHValue -split ';') -notcontains $scopePath) -and
                       (($currentPATHValue -split ';') -notcontains $scopePathEndingWithBackSlash))
                    {
                        # To ensure that the installed script is immediately usable,
                        # we need to add the scope path to the PATH enviroment variable.
                        Set-EnvironmentVariable -Name 'PATH' `
                                                -Value "$currentPATHValue;$scopePath" `
                                                -Target $envVariableTarget

                        Write-Verbose ($LocalizedData.AddedScopePathToPATHVariable -f ($scopePath,$Scope))
                    }

                    # Process specific PATH
                    # Check and add the $scopePath to $env:Path value of current process
                    # so that installed scripts can be used in the current process.
                    $target = $script:EnvironmentVariableTarget.Process
                    $currentPATHValue = Get-EnvironmentVariable -Name 'PATH' -Target $target

                    if((($currentPATHValue -split ';') -notcontains $scopePath) -and
                       (($currentPATHValue -split ';') -notcontains $scopePathEndingWithBackSlash))
                    {
                        # To ensure that the installed script is immediately usable,
                        # we need to add the scope path to the PATH enviroment variable.
                        Set-EnvironmentVariable -Name 'PATH' `
                                                -Value "$currentPATHValue;$scopePath" `
                                                -Target $target

                        Write-Verbose ($LocalizedData.AddedScopePathToProcessSpecificPATHVariable -f ($scopePath,$Scope))
                    }
                }
            }
        }

        # Add user's response to the PowerShellGet.settings file
        $script:PSGetSettings[$scopeSpecificKey] = $userResponse

        Save-PSGetSettings
    }
}

#endregion

#region Public Functions
function Find-Command
{
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=733636')]
    [outputtype('PSCustomObject[]')]
    Param
    (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleName,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [switch]
        $AllVersions,

        [Parameter()]
        [switch]
        $AllowPrerelease,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $Tag,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $Filter,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository
    )


    Process
    {
        if($PSBoundParameters.ContainsKey('Name'))
        {
            $PSBoundParameters['Command'] = $Name
            $null = $PSBoundParameters.Remove('Name')
        }
        else
        {
            $PSBoundParameters['Includes'] = @('Cmdlet','Function')
        }

        if($PSBoundParameters.ContainsKey('ModuleName'))
        {
            $PSBoundParameters['Name'] = $ModuleName
            $null = $PSBoundParameters.Remove('ModuleName')
        }


        PowerShellGet\Find-Module @PSBoundParameters |
            Microsoft.PowerShell.Core\ForEach-Object {
                $psgetModuleInfo = $_
                $psgetModuleInfo.Includes.Command | Microsoft.PowerShell.Core\ForEach-Object {
                    if(($_ -eq "*") -or ($Name -and ($Name -notcontains $_)))
                    {
                        return
                    }

                    $psgetCommandInfo = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
                            Name            = $_
                            Version         = $psgetModuleInfo.Version
                            ModuleName      = $psgetModuleInfo.Name
                            Repository      = $psgetModuleInfo.Repository
                            PSGetModuleInfo = $psgetModuleInfo
                    })

                    $psgetCommandInfo.PSTypeNames.Insert(0, 'Microsoft.PowerShell.Commands.PSGetCommandInfo')
                    $psgetCommandInfo
                }
            }
    }
}
function Find-DscResource
{
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=517196')]
    [outputtype('PSCustomObject[]')]
    Param
    (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleName,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [switch]
        $AllVersions,

        [Parameter()]
        [switch]
        $AllowPrerelease,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $Tag,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $Filter,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository
    )


    Process
    {
        $PSBoundParameters['Includes'] = 'DscResource'

        if($PSBoundParameters.ContainsKey('Name'))
        {
            $PSBoundParameters['DscResource'] = $Name
            $null = $PSBoundParameters.Remove('Name')
        }

        if($PSBoundParameters.ContainsKey('ModuleName'))
        {
            $PSBoundParameters['Name'] = $ModuleName
            $null = $PSBoundParameters.Remove('ModuleName')
        }

        PowerShellGet\Find-Module @PSBoundParameters |
        Microsoft.PowerShell.Core\ForEach-Object {
            $psgetModuleInfo = $_
            $psgetModuleInfo.Includes.DscResource | Microsoft.PowerShell.Core\ForEach-Object {
                if($Name -and ($Name -notcontains $_))
                {
                    return
                }

                $psgetDscResourceInfo = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
                        Name            = $_
                        Version         = $psgetModuleInfo.Version
                        ModuleName      = $psgetModuleInfo.Name
                        Repository      = $psgetModuleInfo.Repository
                        PSGetModuleInfo = $psgetModuleInfo
                })

                $psgetDscResourceInfo.PSTypeNames.Insert(0, 'Microsoft.PowerShell.Commands.PSGetDscResourceInfo')
                $psgetDscResourceInfo
            }
        }
    }
}
function Find-Module {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=398574')]
    [outputtype("PSCustomObject[]")]
    Param
    (
        [Parameter(ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [switch]
        $AllVersions,

        [Parameter()]
        [switch]
        $IncludeDependencies,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $Filter,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $Tag,

        [Parameter()]
        [ValidateNotNull()]
        [ValidateSet('DscResource', 'Cmdlet', 'Function', 'RoleCapability')]
        [string[]]
        $Includes,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $DscResource,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $RoleCapability,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $Command,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [switch]
        $AllowPrerelease
    )

    Begin {
        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential
    }

    Process {
        $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
            -Name $Name `
            -MinimumVersion $MinimumVersion `
            -MaximumVersion $MaximumVersion `
            -RequiredVersion $RequiredVersion `
            -AllVersions:$AllVersions `
            -AllowPrerelease:$AllowPrerelease

        if (-not $ValidationResult) {
            # Validate-VersionParameters throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }

        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeModule
        if ($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")

        if ($PSBoundParameters.ContainsKey("Repository")) {
            $PSBoundParameters["Source"] = $Repository
            $null = $PSBoundParameters.Remove("Repository")

            $ev = $null
            $null = Get-PSRepository -Name $Repository -ErrorVariable ev -verbose:$false
            if ($ev) { return }
        }

        $PSBoundParameters["MessageResolver"] = $script:PackageManagementMessageResolverScriptBlock

        $modulesFoundInPSGallery = @()

        # No Telemetry must be performed if PSGallery is not in the supplied list of Repositories
        $isRepositoryNullOrPSGallerySpecified = $false
        if ($Repository -and ($Repository -Contains $Script:PSGalleryModuleSource)) {
            $isRepositoryNullOrPSGallerySpecified = $true
        }
        elseif (-not $Repository) {
            $psgalleryRepo = Get-PSRepository -Name $Script:PSGalleryModuleSource `
                -ErrorAction SilentlyContinue `
                -WarningAction SilentlyContinue
            if ($psgalleryRepo) {
                $isRepositoryNullOrPSGallerySpecified = $true
            }
        }

        PackageManagement\Find-Package @PSBoundParameters | Microsoft.PowerShell.Core\ForEach-Object {

            $psgetItemInfo = New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeModule

            if ($psgetItemInfo.Type -eq $script:PSArtifactTypeModule) {
                if ($AllVersions -and -not $AllowPrerelease) {
                    # If AllVersions is specified but not AllowPrerelease, we should only return stable release versions.
                    # PackageManagement returns ALL versions (including prerelease) when AllVersions is specified, regardless of the value of AllowPrerelease.
                    # Filtering results returned from PackageManagement based on flags.
                    if ($psgetItemInfo.AdditionalMetadata -and $psgetItemInfo.AdditionalMetadata.IsPrerelease -eq 'false') {
                        $psgetItemInfo
                    }
                }
                else {
                    $psgetItemInfo
                }
            } elseif ($PSBoundParameters['Name'] -and -not (Test-WildcardPattern -Name ($Name | Microsoft.PowerShell.Core\Where-Object { $psgetItemInfo.Name -like $_ }))) {
                $message = $LocalizedData.MatchInvalidType -f ($psgetItemInfo.Name, $psgetItemInfo.Type, $script:PSArtifactTypeModule)
                Write-Error -Message $message `
                            -ErrorId 'MatchInvalidType' `
                            -Category InvalidArgument `
                            -TargetObject $Name
            }

            if ($psgetItemInfo -and
                $isRepositoryNullOrPSGallerySpecified -and
                $script:TelemetryEnabled -and
                ($psgetItemInfo.Repository -eq $Script:PSGalleryModuleSource)) {
                $modulesFoundInPSGallery += $psgetItemInfo.Name
            }
        }


        # Perform Telemetry if Repository is not supplied or Repository contains PSGallery
        # We are only interested in finding modules not in PSGallery
        if ($isRepositoryNullOrPSGallerySpecified) {
            Log-ArtifactNotFoundInPSGallery -SearchedName $Name -FoundName $modulesFoundInPSGallery -operationName 'PSGET_FIND_MODULE'
        }
    }
}
function Find-RoleCapability
{
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=718029')]
    [outputtype('PSCustomObject[]')]
    Param
    (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleName,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [switch]
        $AllVersions,

        [Parameter()]
        [switch]
        $AllowPrerelease,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $Tag,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $Filter,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository
    )


    Process
    {
        $PSBoundParameters['Includes'] = 'RoleCapability'

        if($PSBoundParameters.ContainsKey('Name'))
        {
            $PSBoundParameters['RoleCapability'] = $Name
            $null = $PSBoundParameters.Remove('Name')
        }

        if($PSBoundParameters.ContainsKey('ModuleName'))
        {
            $PSBoundParameters['Name'] = $ModuleName
            $null = $PSBoundParameters.Remove('ModuleName')
        }

        PowerShellGet\Find-Module @PSBoundParameters |
            Microsoft.PowerShell.Core\ForEach-Object {
                $psgetModuleInfo = $_
                $psgetModuleInfo.Includes.RoleCapability | Microsoft.PowerShell.Core\ForEach-Object {
                    if($Name -and ($Name -notcontains $_))
                    {
                        return
                    }

                    $psgetRoleCapabilityInfo = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
                            Name            = $_
                            Version         = $psgetModuleInfo.Version
                            ModuleName      = $psgetModuleInfo.Name
                            Repository      = $psgetModuleInfo.Repository
                            PSGetModuleInfo = $psgetModuleInfo
                    })

                    $psgetRoleCapabilityInfo.PSTypeNames.Insert(0, 'Microsoft.PowerShell.Commands.PSGetRoleCapabilityInfo')
                    $psgetRoleCapabilityInfo
                }
            }
    }
}
function Find-Script {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619785')]
    [outputtype("PSCustomObject[]")]
    Param
    (
        [Parameter(ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [switch]
        $AllVersions,

        [Parameter()]
        [switch]
        $IncludeDependencies,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $Filter,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $Tag,

        [Parameter()]
        [ValidateNotNull()]
        [ValidateSet('Function', 'Workflow')]
        [string[]]
        $Includes,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $Command,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [switch]
        $AllowPrerelease
    )

    Begin {
        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential
    }

    Process {
        $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
            -Name $Name `
            -MinimumVersion $MinimumVersion `
            -MaximumVersion $MaximumVersion `
            -RequiredVersion $RequiredVersion `
            -AllVersions:$AllVersions `
            -AllowPrerelease:$AllowPrerelease

        if (-not $ValidationResult) {
            # Validate-VersionParameters throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }

        $PSBoundParameters['Provider'] = $script:PSModuleProviderName
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeScript
        if ($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")

        if ($PSBoundParameters.ContainsKey("Repository")) {
            $PSBoundParameters["Source"] = $Repository
            $null = $PSBoundParameters.Remove("Repository")

            $ev = $null
            $repositories = Get-PSRepository -Name $Repository -ErrorVariable ev -verbose:$false
            if ($ev) { return }

            $RepositoriesWithoutScriptSourceLocation = $false
            foreach ($repo in $repositories) {
                if (-not $repo.ScriptSourceLocation) {
                    $message = $LocalizedData.ScriptSourceLocationIsMissing -f ($repo.Name)
                    Write-Error -Message $message `
                        -ErrorId 'ScriptSourceLocationIsMissing' `
                        -Category InvalidArgument `
                        -TargetObject $repo.Name `
                        -Exception 'System.ArgumentException'

                    $RepositoriesWithoutScriptSourceLocation = $true
                }
            }

            if ($RepositoriesWithoutScriptSourceLocation) {
                return
            }
        }

        $PSBoundParameters["MessageResolver"] = $script:PackageManagementMessageResolverScriptBlockForScriptCmdlets

        $scriptsFoundInPSGallery = @()

        # No Telemetry must be performed if PSGallery is not in the supplied list of Repositories
        $isRepositoryNullOrPSGallerySpecified = $false
        if ($Repository -and ($Repository -Contains $Script:PSGalleryModuleSource)) {
            $isRepositoryNullOrPSGallerySpecified = $true
        }
        elseif (-not $Repository) {
            $psgalleryRepo = Get-PSRepository -Name $Script:PSGalleryModuleSource `
                -ErrorAction SilentlyContinue `
                -WarningAction SilentlyContinue
            # And check for IsDefault?
            if ($psgalleryRepo) {
                $isRepositoryNullOrPSGallerySpecified = $true
            }
        }

        PackageManagement\Find-Package @PSBoundParameters | Microsoft.PowerShell.Core\ForEach-Object {
            $psgetItemInfo = New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeScript

            if ($psgetItemInfo.Type -eq $script:PSArtifactTypeScript) {
                if ($AllVersions -and -not $AllowPrerelease) {
                    # If AllVersions is specified but not AllowPrerelease, we should only return stable release versions.
                    # PackageManagement returns ALL versions (including prerelease) when AllVersions is specified, regardless of the value of AllowPrerelease.
                    # Filtering results returned from PackageManagement based on flags.
                    if ($psgetItemInfo.AdditionalMetadata -and $psgetItemInfo.AdditionalMetadata.IsPrerelease -eq $false) {
                        $psgetItemInfo
                    }
                }
                else {
                    $psgetItemInfo
                }
            } elseif ($PSBoundParameters['Name'] -and -not (Test-WildcardPattern -Name ($Name | Microsoft.PowerShell.Core\Where-Object { $psgetItemInfo.Name -like $_ }))) {
                $message = $LocalizedData.MatchInvalidType -f ($psgetItemInfo.Name, $psgetItemInfo.Type, $script:PSArtifactTypeScript)
                Write-Error -Message $message `
                            -ErrorId 'MatchInvalidType' `
                            -Category InvalidArgument `
                            -TargetObject $Name
            }

            if ($psgetItemInfo -and
                $isRepositoryNullOrPSGallerySpecified -and
                $script:TelemetryEnabled -and
                ($psgetItemInfo.Repository -eq $Script:PSGalleryModuleSource)) {
                $scriptsFoundInPSGallery += $psgetItemInfo.Name
            }
        }

        # Perform Telemetry if Repository is not supplied or Repository contains PSGallery
        # We are only interested in finding artifacts not in PSGallery
        if ($isRepositoryNullOrPSGallerySpecified) {
            Log-ArtifactNotFoundInPSGallery -SearchedName $Name -FoundName $scriptsFoundInPSGallery -operationName PSGET_FIND_SCRIPT
        }
    }
}

function Get-CredsFromCredentialProvider {
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $SourceLocation,

        [Parameter()]
        [bool]
        $isRetry = $false
    )


    Write-Verbose "PowerShellGet Calling 'CallCredProvider' on $SourceLocation"
    # Example query: https://pkgs.dev.azure.com/onegettest/_packaging/onegettest/nuget/v2
    $regex = [regex] '^(\S*pkgs.dev.azure.com\S*/v2)$|^(\S*pkgs.visualstudio.com\S*/v2)$'

    if (!($SourceLocation -match $regex)) {
        return $null;
    }

    # Find credential provider
    # Option 1. Use env var 'NUGET_PLUGIN_PATHS' to find credential provider
    # See: https://docs.microsoft.com/en-us/nuget/reference/extensibility/nuget-cross-platform-plugins#plugin-installation-and-discovery
    # Note: OSX and Linux can only use option 1
    # Nuget prioritizes credential providers stored in the NUGET_PLUGIN_PATHS env var
    $credProviderPath = $null
    $defaultEnvPath = "NUGET_PLUGIN_PATHS"
    $nugetPluginPath = Get-Childitem env:$defaultEnvPath -ErrorAction SilentlyContinue
    $callDotnet = $true;

    if ($nugetPluginPath -and $nugetPluginPath.value) {
        # Obtion 1a) The environment variable NUGET_PLUGIN_PATHS should contain a full path to the executable,
        # .exe in the .NET Framework case and .dll in the .NET Core case
        $credProviderPath = $nugetPluginPath.value
        $extension = $credProviderPath.Substring($credProviderPath.get_Length() - 4)
        if ($extension -eq ".exe") {
            $callDotnet = $false
        }
    }
    else {
        # Option 1b) Find User-location - The NuGet Home location - %UserProfile%/.nuget/plugins/
        $path = "$($env:UserProfile)/.nuget/plugins/netcore/CredentialProvider.Microsoft/CredentialProvider.Microsoft.dll";

        if ($script:IsLinux -or $script:IsMacOS) {
            $path = "$($HOME)/.nuget/plugins/netcore/CredentialProvider.Microsoft/CredentialProvider.Microsoft.dll";
        }
        if (Test-Path $path -PathType Leaf) {
            $credProviderPath = $path
        }
    }

    # Option 2. Use Visual Studio path to find credential provider
    # Visual Studio comes pre-installed with the Azure Artifacts credential provider, so we'll search for that file using vswhere.exe
    # If Windows (ie not unix), we'll use vswhere.exe to find installation path of VsWhere
    # If credProviderPath is already set we can skip option 2
    if (!$credProviderPath -and $script:IsWindows) {
        if (${Env:ProgramFiles(x86)}) {
            $programFiles = ${Env:ProgramFiles(x86)}
        }
        elseif ($Env:Programfiles) {
            $programFiles = $Env:Programfiles
        }
        else {
            return $null
        }

        $vswhereExePath = "$($programFiles)\\Microsoft Visual Studio\\Installer\\vswhere.exe"
        if (!(Test-Path $vswhereExePath -PathType Leaf)) {
            return $null
        }

        $RedirectedOutput = Join-Path ([System.IO.Path]::GetTempPath()) 'RedirectedOutput.txt'
        Start-Process $vswhereExePath `
            -Wait `
            -WorkingDirectory $PSHOME `
            -RedirectStandardOutput $RedirectedOutput `
            -NoNewWindow

        $content = Get-Content $RedirectedOutput
        Remove-Item $RedirectedOutput -Force -Recurse -ErrorAction SilentlyContinue

        $vsInstallationPath = ""
        if ([System.Text.RegularExpressions.Regex]::IsMatch($content, "installationPath")) {
            $vsInstallationPath = [System.Text.RegularExpressions.Regex]::Match($content, "(?<=installationPath: ).*(?= installationVersion:)");
            $vsInstallationPath = $vsInstallationPath.ToString()
        }

        # Then use the installation path discovered by vswhere.exe to create the path to search for credential provider
        # ex: "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise" + "\Common7\IDE\CommonExtensions\Microsoft\NuGet\Plugins\CredentialProvider.Microsoft\CredentialProvider.Microsoft.exe"
        if ($vsInstallationPath) {
            $credProviderPath = ($vsInstallationPath + '\Common7\IDE\CommonExtensions\Microsoft\NuGet\Plugins\CredentialProvider.Microsoft\CredentialProvider.Microsoft.exe')
            if (!(Test-Path $credProviderPath -PathType Leaf)) {
                return $null
            }
            $callDotnet = $false;
        }
    }

    if (!(Test-Path $credProviderPath -PathType Leaf)) {
        return $null
    }

    $filename = $credProviderPath
    $arguments = "-U $SourceLocation"
    if ($callDotnet) {
        $filename = "dotnet"
        $arguments = "$credProviderPath $arguments"
    }
    $argumentsNoRetry = $arguments
    if ($isRetry) {
        $arguments = "$arguments -I";
        Write-Debug "Credential provider is re-running with -IsRetry"
    }

    Write-Debug "Credential provider path is: $credProviderPath"
    # Using a process to run CredentialProvider.Microsoft.exe with arguments -V verbose -U query (and -IsRetry when appropriate)
    # See: https://github.com/Microsoft/artifacts-credprovider
    Start-Process $filename -ArgumentList "$arguments -V minimal" `
        -Wait `
        -WorkingDirectory $PSHOME `
        -NoNewWindow

    # This should never run IsRetry
    $RedirectedOutput = Join-Path ([System.IO.Path]::GetTempPath()) 'RedirectedOutput.txt'
    Start-Process $filename -ArgumentList "$argumentsNoRetry -V verbose" `
        -Wait `
        -WorkingDirectory $PSHOME `
        -RedirectStandardOutput $RedirectedOutput `
        -NoNewWindow

    $content = Get-Content $RedirectedOutput
    Remove-Item $RedirectedOutput -Force -Recurse -ErrorAction SilentlyContinue

    $username = [System.Text.RegularExpressions.Regex]::Match($content, '(?<=Username: )\S*')
    $password = [System.Text.RegularExpressions.Regex]::Match($content, '(?<=Password: ).*')

    if ($username -and $password) {
        $secstr = ConvertTo-SecureString $password -AsPlainText -Force
        $credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr

        return $credential
    }

    return $null
}
function Get-InstalledModule
{
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(HelpUri='https://go.microsoft.com/fwlink/?LinkId=526863')]
    Param
    (
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Name,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter()]
        [switch]
        $AllVersions,

        [Parameter()]
        [switch]
        $AllowPrerelease
    )

    Process
    {
        $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
                                                       -Name $Name `
                                                       -MinimumVersion $MinimumVersion `
                                                       -MaximumVersion $MaximumVersion `
                                                       -RequiredVersion $RequiredVersion `
                                                       -AllVersions:$AllVersions `
                                                       -AllowPrerelease:$AllowPrerelease

        if(-not $ValidationResult)
        {
            # Validate-VersionParameters throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }

        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementMessageResolverScriptBlock
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeModule
        if($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")

        PackageManagement\Get-Package @PSBoundParameters | Microsoft.PowerShell.Core\ForEach-Object {New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeModule}
    }
}
function Get-InstalledScript
{
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(HelpUri='https://go.microsoft.com/fwlink/?LinkId=619790')]
    Param
    (
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Name,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter()]
        [Switch]
        $AllowPrerelease
    )

    Process
    {
        $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
                                                       -Name $Name `
                                                       -MinimumVersion $MinimumVersion `
                                                       -MaximumVersion $MaximumVersion `
                                                       -RequiredVersion $RequiredVersion `
                                                       -AllowPrerelease:$AllowPrerelease

        if(-not $ValidationResult)
        {
            # Validate-VersionParameters throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }

        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementMessageResolverScriptBlockForScriptCmdlets
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeScript
        if($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")

        PackageManagement\Get-Package @PSBoundParameters | Microsoft.PowerShell.Core\ForEach-Object {New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeScript}
    }
}
function Get-PSRepository {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=517127')]
    Param
    (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name
    )

    Begin {
    }

    Process {
        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementMessageResolverScriptBlock

        if ($Name) {
            foreach ($sourceName in $Name) {
                $PSBoundParameters["Name"] = $sourceName

                $packageSources = PackageManagement\Get-PackageSource @PSBoundParameters

                $packageSources | Microsoft.PowerShell.Core\ForEach-Object { New-ModuleSourceFromPackageSource -PackageSource $_ }
            }
        }
        else {
            $packageSources = PackageManagement\Get-PackageSource @PSBoundParameters

            $packageSources | Microsoft.PowerShell.Core\ForEach-Object { New-ModuleSourceFromPackageSource -PackageSource $_ }
        }
    }
}
function Install-Module {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(DefaultParameterSetName = 'NameParameterSet',
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=398573',
        SupportsShouldProcess = $true)]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'InputObject')]
        [ValidateNotNull()]
        [PSCustomObject[]]
        $InputObject,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter(ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [ValidateSet("CurrentUser", "AllUsers")]
        [string]
        $Scope,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter()]
        [switch]
        $AllowClobber,

        [Parameter()]
        [switch]
        $SkipPublisherCheck,

        [Parameter()]
        [switch]
        $Force,

        [Parameter(ParameterSetName = 'NameParameterSet')]
        [switch]
        $AllowPrerelease,

        [Parameter()]
        [switch]
        $AcceptLicense,

        [Parameter()]
        [switch]
        $PassThru
    )

    Begin {
        if ($Scope -eq "AllUsers" -and -not (Test-RunningAsElevated)) {
            # Throw an error when Install-Module is used as a non-admin user and '-Scope AllUsers'
            $message = $LocalizedData.InstallModuleAdminPrivilegeRequiredForAllUsersScope -f @($script:programFilesModulesPath, $script:MyDocumentsModulesPath)

            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "InstallModuleAdminPrivilegeRequiredForAllUsersScope" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument
        }

        # If no scope is specified, default installation will be to AllUsers only
        # If running admin on Windows with PowerShell less than v6.
        if (-not $Scope) {
            $Scope = "CurrentUser"
            if (-not $script:IsCoreCLR -and (Test-RunningAsElevated)) {
                $Scope = "AllUsers"
            }
        }

        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential

        # Module names already tried in the current pipeline for InputObject parameterset
        $moduleNamesInPipeline = @()
        $YesToAll = $false
        $NoToAll = $false
        $SourceSGrantedTrust = @()
        $SourcesDeniedTrust = @()
    }

    Process {
        $RepositoryIsNotTrusted = $LocalizedData.RepositoryIsNotTrusted
        $QueryInstallUntrustedPackage = $LocalizedData.QueryInstallUntrustedPackage
        $PackageTarget = $LocalizedData.InstallModulewhatIfMessage

        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementInstallModuleMessageResolverScriptBlock
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeModule
        $PSBoundParameters['Scope'] = $Scope
        if ($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")
        $null = $PSBoundParameters.Remove("PassThru")

        if ($PSCmdlet.ParameterSetName -eq "NameParameterSet") {
            $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
                -Name $Name `
                -TestWildcardsInName `
                -MinimumVersion $MinimumVersion `
                -MaximumVersion $MaximumVersion `
                -RequiredVersion $RequiredVersion `
                -AllowPrerelease:$AllowPrerelease

            if (-not $ValidationResult) {
                # Validate-VersionParameters throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }

            if ($PSBoundParameters.ContainsKey("Repository")) {
                $PSBoundParameters["Source"] = $Repository
                $null = $PSBoundParameters.Remove("Repository")

                $ev = $null
                $null = Get-PSRepository -Name $Repository -ErrorVariable ev -verbose:$false
                if ($ev) { return }
            }

            $installedPackages = PackageManagement\Install-Package @PSBoundParameters

            if ($PassThru) {
                $installedPackages | Microsoft.PowerShell.Core\ForEach-Object { New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeModule }
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "InputObject") {
            $null = $PSBoundParameters.Remove("InputObject")

            foreach ($inputValue in $InputObject) {
                if (($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSRepositoryItemInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSRepositoryItemInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSGetCommandInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSGetCommandInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSGetDscResourceInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSGetDscResourceInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSGetRoleCapabilityInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSGetRoleCapabilityInfo")) {
                    ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $LocalizedData.InvalidInputObjectValue `
                        -ErrorId "InvalidInputObjectValue" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $inputValue
                }

                if ( ($inputValue.PSTypeNames -contains "Microsoft.PowerShell.Commands.PSGetDscResourceInfo") -or
                    ($inputValue.PSTypeNames -contains "Deserialized.Microsoft.PowerShell.Commands.PSGetDscResourceInfo") -or
                    ($inputValue.PSTypeNames -contains "Microsoft.PowerShell.Commands.PSGetCommandInfo") -or
                    ($inputValue.PSTypeNames -contains "Deserialized.Microsoft.PowerShell.Commands.PSGetCommandInfo") -or
                    ($inputValue.PSTypeNames -contains "Microsoft.PowerShell.Commands.PSGetRoleCapabilityInfo") -or
                    ($inputValue.PSTypeNames -contains "Deserialized.Microsoft.PowerShell.Commands.PSGetRoleCapabilityInfo")) {
                    $psgetModuleInfo = $inputValue.PSGetModuleInfo
                }
                else {
                    $psgetModuleInfo = $inputValue
                }

                # Skip the module name if it is already tried in the current pipeline
                if ($moduleNamesInPipeline -contains $psgetModuleInfo.Name) {
                    continue
                }

                $moduleNamesInPipeline += $psgetModuleInfo.Name

                if ($psgetModuleInfo.PowerShellGetFormatVersion -and
                    ($script:SupportedPSGetFormatVersionMajors -notcontains $psgetModuleInfo.PowerShellGetFormatVersion.Major)) {
                    $message = $LocalizedData.NotSupportedPowerShellGetFormatVersion -f ($psgetModuleInfo.Name, $psgetModuleInfo.PowerShellGetFormatVersion, $psgetModuleInfo.Name)
                    Write-Error -Message $message -ErrorId "NotSupportedPowerShellGetFormatVersion" -Category InvalidOperation
                    continue
                }

                $PSBoundParameters["Name"] = $psgetModuleInfo.Name
                $PSBoundParameters["RequiredVersion"] = $psgetModuleInfo.Version
                if (($psgetModuleInfo.AdditionalMetadata) -and
                    (Get-Member -InputObject $psgetModuleInfo.AdditionalMetadata -Name "IsPrerelease") -and
                    ($psgetModuleInfo.AdditionalMetadata.IsPrerelease -eq "true")) {
                    $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
                }
                elseif ($PSBoundParameters.ContainsKey($script:AllowPrereleaseVersions)) {
                    $null = $PSBoundParameters.Remove($script:AllowPrereleaseVersions)
                }
                $PSBoundParameters['Source'] = $psgetModuleInfo.Repository
                $PSBoundParameters["PackageManagementProvider"] = (Get-ProviderName -PSCustomObject $psgetModuleInfo)

                #Check if module is already installed
                $InstalledModuleInfo = Test-ModuleInstalled -Name $psgetModuleInfo.Name -RequiredVersion $psgetModuleInfo.Version
                if (-not $Force -and $null -ne $InstalledModuleInfo) {
                    $message = $LocalizedData.ModuleAlreadyInstalledVerbose -f ($InstalledModuleInfo.Version, $InstalledModuleInfo.Name, $InstalledModuleInfo.ModuleBase)
                    Write-Verbose -Message $message
                }
                else {
                    $source = $psgetModuleInfo.Repository
                    $installationPolicy = (Get-PSRepository -Name $source).InstallationPolicy
                    $ShouldProcessMessage = $PackageTarget -f ($psgetModuleInfo.Name, $psgetModuleInfo.Version)

                    if ($psCmdlet.ShouldProcess($ShouldProcessMessage)) {
                        if ($installationPolicy.Equals("Untrusted", [StringComparison]::OrdinalIgnoreCase)) {
                            if (-not($YesToAll -or $NoToAll -or $SourceSGrantedTrust.Contains($source) -or $sourcesDeniedTrust.Contains($source) -or $Force)) {
                                $message = $QueryInstallUntrustedPackage -f ($psgetModuleInfo.Name, $psgetModuleInfo.RepositorySourceLocation)
                                if ($PSVersionTable.PSVersion -ge '5.0.0') {
                                    $sourceTrusted = $psCmdlet.ShouldContinue("$message", "$RepositoryIsNotTrusted", $true, [ref]$YesToAll, [ref]$NoToAll)
                                }
                                else {
                                    $sourceTrusted = $psCmdlet.ShouldContinue("$message", "$RepositoryIsNotTrusted", [ref]$YesToAll, [ref]$NoToAll)
                                }

                                if ($sourceTrusted) {
                                    $SourceSGrantedTrust += $source
                                }
                                else {
                                    $SourcesDeniedTrust += $source
                                }
                            }
                        }

                        if ($installationPolicy.Equals("trusted", [StringComparison]::OrdinalIgnoreCase) -or $SourceSGrantedTrust.Contains($source) -or $YesToAll -or $Force) {
                            $PSBoundParameters["Force"] = $true
                            $installedPackages = PackageManagement\Install-Package @PSBoundParameters

                            if ($PassThru) {
                                $installedPackages | Microsoft.PowerShell.Core\ForEach-Object { New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeModule }
                            }
                        }
                    }
                }
            }
        }
    }
}
function Install-Script {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(DefaultParameterSetName = 'NameParameterSet',
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619784',
        SupportsShouldProcess = $true)]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'InputObject')]
        [ValidateNotNull()]
        [PSCustomObject[]]
        $InputObject,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter(ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository,

        [Parameter()]
        [ValidateSet("CurrentUser", "AllUsers")]
        [string]
        $Scope,

        [Parameter()]
        [Switch]
        $NoPathUpdate,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [switch]
        $Force,

        [Parameter(ParameterSetName = 'NameParameterSet')]
        [switch]
        $AllowPrerelease,

        [Parameter()]
        [switch]
        $AcceptLicense,

        [Parameter()]
        [switch]
        $PassThru
    )

    Begin {
        if ($Scope -eq "AllUsers" -and -not (Test-RunningAsElevated)) {
            # Throw an error when Install-Script is used as a non-admin user and '-Scope AllUsers'
            $message = $LocalizedData.InstallScriptAdminPrivilegeRequiredForAllUsersScope -f @($script:ProgramFilesScriptsPath, $script:MyDocumentsScriptsPath)

            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "InstallScriptAdminPrivilegeRequiredForAllUsersScope" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument
        }

        # If no scope is specified, default installation will be to AllUsers only
        # If running admin on Windows with PowerShell less than v6.
        if (-not $Scope) {
            $Scope = "CurrentUser"
            if (-not $script:IsCoreCLR -and (Test-RunningAsElevated)) {
                $Scope = "AllUsers"
            }
        }

        # Check and add the scope path to PATH environment variable
        if ($Scope -eq 'AllUsers') {
            $scopePath = $script:ProgramFilesScriptsPath
        }
        else {
            $scopePath = $script:MyDocumentsScriptsPath
        }

        ValidateAndSet-PATHVariableIfUserAccepts -Scope $Scope `
            -ScopePath $scopePath `
            -NoPathUpdate:$NoPathUpdate `
            -Force:$Force

        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential

        # Script names already tried in the current pipeline for InputObject parameterset
        $scriptNamesInPipeline = @()

        $YesToAll = $false
        $NoToAll = $false
        $SourceSGrantedTrust = @()
        $SourcesDeniedTrust = @()
    }

    Process {
        $RepositoryIsNotTrusted = $LocalizedData.RepositoryIsNotTrusted
        $QueryInstallUntrustedPackage = $LocalizedData.QueryInstallUntrustedScriptPackage
        $PackageTarget = $LocalizedData.InstallScriptwhatIfMessage

        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementInstallScriptMessageResolverScriptBlock
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeScript
        $PSBoundParameters['Scope'] = $Scope
        if ($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")
        $null = $PSBoundParameters.Remove("PassThru")

        if ($PSCmdlet.ParameterSetName -eq "NameParameterSet") {
            $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
                -Name $Name `
                -TestWildcardsInName `
                -MinimumVersion $MinimumVersion `
                -MaximumVersion $MaximumVersion `
                -RequiredVersion $RequiredVersion `
                -AllowPrerelease:$AllowPrerelease

            if (-not $ValidationResult) {
                # Validate-VersionParameters throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }

            if ($PSBoundParameters.ContainsKey("Repository")) {
                $PSBoundParameters["Source"] = $Repository
                $null = $PSBoundParameters.Remove("Repository")

                $ev = $null
                $repositories = Get-PSRepository -Name $Repository -ErrorVariable ev -verbose:$false
                if ($ev) { return }

                $RepositoriesWithoutScriptSourceLocation = $false
                foreach ($repo in $repositories) {
                    if (-not $repo.ScriptSourceLocation) {
                        $message = $LocalizedData.ScriptSourceLocationIsMissing -f ($repo.Name)
                        Write-Error -Message $message `
                            -ErrorId 'ScriptSourceLocationIsMissing' `
                            -Category InvalidArgument `
                            -TargetObject $repo.Name `
                            -Exception 'System.ArgumentException'

                        $RepositoriesWithoutScriptSourceLocation = $true
                    }
                }

                if ($RepositoriesWithoutScriptSourceLocation) {
                    return
                }
            }

            if (-not $Force) {
                foreach ($scriptName in $Name) {
                    # Throw an error if there is a command with the same name and -force is not specified.
                    $cmd = Microsoft.PowerShell.Core\Get-Command -Name $scriptName `
                        -ErrorAction Ignore `
                        -WarningAction SilentlyContinue
                    if ($cmd) {
                        # Check if this script was already installed, may be with -Force
                        $InstalledScriptInfo = Test-ScriptInstalled -Name $scriptName `
                            -ErrorAction SilentlyContinue `
                            -WarningAction SilentlyContinue
                        if (-not $InstalledScriptInfo) {
                            $message = $LocalizedData.CommandAlreadyAvailable -f ($scriptName)
                            Write-Error -Message $message -ErrorId CommandAlreadyAvailableWitScriptName -Category InvalidOperation

                            # return if only single name is specified
                            if ($scriptName -eq $Name) {
                                return
                            }
                        }
                    }
                }
            }

            $installedPackages = PackageManagement\Install-Package @PSBoundParameters

            if ($PassThru) {
                $installedPackages | Microsoft.PowerShell.Core\ForEach-Object { New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeScript }
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "InputObject") {
            $null = $PSBoundParameters.Remove("InputObject")

            foreach ($inputValue in $InputObject) {

                if (($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSRepositoryItemInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSRepositoryItemInfo")) {
                    ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $LocalizedData.InvalidInputObjectValue `
                        -ErrorId "InvalidInputObjectValue" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $inputValue
                }

                $psRepositoryItemInfo = $inputValue

                # Skip the script name if it is already tried in the current pipeline
                if ($scriptNamesInPipeline -contains $psRepositoryItemInfo.Name) {
                    continue
                }

                $scriptNamesInPipeline += $psRepositoryItemInfo.Name

                if ($psRepositoryItemInfo.PowerShellGetFormatVersion -and
                    ($script:SupportedPSGetFormatVersionMajors -notcontains $psRepositoryItemInfo.PowerShellGetFormatVersion.Major)) {
                    $message = $LocalizedData.NotSupportedPowerShellGetFormatVersionScripts -f ($psRepositoryItemInfo.Name, $psRepositoryItemInfo.PowerShellGetFormatVersion, $psRepositoryItemInfo.Name)
                    Write-Error -Message $message -ErrorId "NotSupportedPowerShellGetFormatVersion" -Category InvalidOperation
                    continue
                }

                $PSBoundParameters["Name"] = $psRepositoryItemInfo.Name
                $PSBoundParameters["RequiredVersion"] = $psRepositoryItemInfo.Version
                if (($psRepositoryItemInfo.AdditionalMetadata) -and
                    (Get-Member -InputObject $psRepositoryItemInfo.AdditionalMetadata -Name "IsPrerelease") -and
                    ($psRepositoryItemInfo.AdditionalMetadata.IsPrerelease -eq "true")) {
                    $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
                }
                elseif ($PSBoundParameters.ContainsKey($script:AllowPrereleaseVersions)) {
                    $null = $PSBoundParameters.Remove($script:AllowPrereleaseVersions)
                }
                $PSBoundParameters['Source'] = $psRepositoryItemInfo.Repository
                $PSBoundParameters["PackageManagementProvider"] = (Get-ProviderName -PSCustomObject $psRepositoryItemInfo)

                $InstalledScriptInfo = Test-ScriptInstalled -Name $psRepositoryItemInfo.Name
                if (-not $Force -and $InstalledScriptInfo) {
                    $message = $LocalizedData.ScriptAlreadyInstalledVerbose -f ($InstalledScriptInfo.Version, $InstalledScriptInfo.Name, $InstalledScriptInfo.ScriptBase)
                    Write-Verbose -Message $message
                }
                else {
                    # Throw an error if there is a command with the same name and -force is not specified.
                    if (-not $Force) {
                        $cmd = Microsoft.PowerShell.Core\Get-Command -Name $psRepositoryItemInfo.Name `
                            -ErrorAction Ignore `
                            -WarningAction SilentlyContinue
                        if ($cmd) {
                            $message = $LocalizedData.CommandAlreadyAvailable -f ($psRepositoryItemInfo.Name)
                            Write-Error -Message $message -ErrorId CommandAlreadyAvailableWitScriptName -Category InvalidOperation

                            continue
                        }
                    }

                    $source = $psRepositoryItemInfo.Repository
                    $installationPolicy = (Get-PSRepository -Name $source).InstallationPolicy
                    $ShouldProcessMessage = $PackageTarget -f ($psRepositoryItemInfo.Name, $psRepositoryItemInfo.Version)

                    if ($psCmdlet.ShouldProcess($ShouldProcessMessage)) {
                        if ($installationPolicy.Equals("Untrusted", [StringComparison]::OrdinalIgnoreCase)) {
                            if (-not($YesToAll -or $NoToAll -or $SourceSGrantedTrust.Contains($source) -or $sourcesDeniedTrust.Contains($source) -or $Force)) {
                                $message = $QueryInstallUntrustedPackage -f ($psRepositoryItemInfo.Name, $psRepositoryItemInfo.RepositorySourceLocation)

                                if ($PSVersionTable.PSVersion -ge '5.0.0') {
                                    $sourceTrusted = $psCmdlet.ShouldContinue("$message", "$RepositoryIsNotTrusted", $true, [ref]$YesToAll, [ref]$NoToAll)
                                }
                                else {
                                    $sourceTrusted = $psCmdlet.ShouldContinue("$message", "$RepositoryIsNotTrusted", [ref]$YesToAll, [ref]$NoToAll)
                                }

                                if ($sourceTrusted) {
                                    $SourcesGrantedTrust += $source
                                }
                                else {
                                    $SourcesDeniedTrust += $source
                                }
                            }
                        }
                    }
                    if ($installationPolicy.Equals("trusted", [StringComparison]::OrdinalIgnoreCase) -or $SourcesGrantedTrust.Contains($source) -or $YesToAll -or $Force) {
                        $PSBoundParameters["Force"] = $true
                        $installedPackages = PackageManagement\Install-Package @PSBoundParameters

                        if ($PassThru) {
                            $installedPackages | Microsoft.PowerShell.Core\ForEach-Object { New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeScript }
                        }
                    }
                }
            }
        }
    }
}
function New-ScriptFileInfo
{
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(PositionalBinding=$false,
                   SupportsShouldProcess=$true,
                   HelpUri='https://go.microsoft.com/fwlink/?LinkId=619792')]
    Param
    (
        [Parameter(Mandatory=$false,
                   Position=0,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Version,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Author,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Description,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Guid]
        $Guid,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $CompanyName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Copyright,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Object[]]
        $RequiredModules,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ExternalModuleDependencies,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $RequiredScripts,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ExternalScriptDependencies,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Tags,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $ProjectUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $LicenseUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $IconUri,

        [Parameter()]
        [string[]]
        $ReleaseNotes,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
        [string]
        $PrivateData,

        [Parameter()]
        [switch]
        $PassThru,

        [Parameter()]
        [switch]
        $Force
    )

    Process
    {
        if($Path)
        {
            if(-not $Path.EndsWith('.ps1', [System.StringComparison]::OrdinalIgnoreCase))
            {
                $errorMessage = ($LocalizedData.InvalidScriptFilePath -f $Path)
                ThrowError  -ExceptionName 'System.ArgumentException' `
                            -ExceptionMessage $errorMessage `
                            -ErrorId 'InvalidScriptFilePath' `
                            -CallerPSCmdlet $PSCmdlet `
                            -ExceptionObject $Path `
                            -ErrorCategory InvalidArgument
                return
            }

            if(-not $Force -and (Microsoft.PowerShell.Management\Test-Path -Path $Path))
            {
                $errorMessage = ($LocalizedData.ScriptFileExist -f $Path)
                ThrowError  -ExceptionName 'System.ArgumentException' `
                            -ExceptionMessage $errorMessage `
                            -ErrorId 'ScriptFileExist' `
                            -CallerPSCmdlet $PSCmdlet `
                            -ExceptionObject $Path `
                            -ErrorCategory InvalidArgument
                return
            }
        }
        elseif(-not $PassThru)
        {
            ThrowError  -ExceptionName 'System.ArgumentException' `
                        -ExceptionMessage $LocalizedData.MissingTheRequiredPathOrPassThruParameter `
                        -ErrorId 'MissingTheRequiredPathOrPassThruParameter' `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument
            return
        }

        if(-not $Version)
        {
            $Version = '1.0'
        }
        else
        {
            $result = ValidateAndGet-VersionPrereleaseStrings -Version $Version -CallerPSCmdlet $PSCmdlet
            if (-not $result)
            {
                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }
        }

        if(-not $Author)
        {
            if($script:IsWindows)
            {
                $Author = (Get-EnvironmentVariable -Name 'USERNAME' -Target $script:EnvironmentVariableTarget.Process -ErrorAction SilentlyContinue)
            }
            else
            {
                $Author = $env:USER
            }
        }

        if(-not $Guid)
        {
            $Guid = [System.Guid]::NewGuid()
        }

        $params = @{
            Version = $Version
            Author = $Author
            Guid = $Guid
            CompanyName = $CompanyName
            Copyright = $Copyright
            ExternalModuleDependencies = $ExternalModuleDependencies
            RequiredScripts = $RequiredScripts
            ExternalScriptDependencies = $ExternalScriptDependencies
            Tags = $Tags
            ProjectUri = $ProjectUri
            LicenseUri = $LicenseUri
            IconUri = $IconUri
            ReleaseNotes = $ReleaseNotes
			PrivateData = $PrivateData
        }

        if(-not (Validate-ScriptFileInfoParameters -parameters $params))
        {
            return
        }

        if("$Description" -match '<#' -or "$Description" -match '#>')
        {
            $message = $LocalizedData.InvalidParameterValue -f ($Description, 'Description')
            Write-Error -Message $message -ErrorId 'InvalidParameterValue' -Category InvalidArgument

            return
        }

        $PSScriptInfoString = Get-PSScriptInfoString @params

        $requiresStrings = Get-RequiresString -RequiredModules $RequiredModules

        $ScriptCommentHelpInfoString = Get-ScriptCommentHelpInfoString -Description $Description

        $ScriptMetadataString = $PSScriptInfoString
        $ScriptMetadataString += "`r`n"

        if("$requiresStrings".Trim())
        {
            $ScriptMetadataString += "`r`n"
            $ScriptMetadataString += $requiresStrings -join "`r`n"
            $ScriptMetadataString += "`r`n"
        }

        $ScriptMetadataString += "`r`n"
        $ScriptMetadataString += $ScriptCommentHelpInfoString
        $ScriptMetadataString += "Param()`r`n`r`n"

        $tempScriptFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:TempPath -ChildPath "$(Get-Random).ps1"

        try
        {
            Microsoft.PowerShell.Management\Set-Content -Value $ScriptMetadataString -Path $tempScriptFilePath -Force -WhatIf:$false -Confirm:$false

            $scriptInfo = Test-ScriptFileInfo -Path $tempScriptFilePath

            if(-not $scriptInfo)
            {
                # Above Test-ScriptFileInfo cmdlet writes the errors
                return
            }

    	    if($Path -and ($Force -or $PSCmdlet.ShouldProcess($Path, ($LocalizedData.NewScriptFileInfowhatIfMessage -f $Path) )))
    	    {
                Microsoft.PowerShell.Management\Copy-Item -Path $tempScriptFilePath -Destination $Path -Force -WhatIf:$false -Confirm:$false
            }

            if($PassThru)
            {
                Write-Output -InputObject $ScriptMetadataString
            }
        }
        finally
        {
            Microsoft.PowerShell.Management\Remove-Item -Path $tempScriptFilePath -Force -WhatIf:$false -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
}
function Publish-Module {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(SupportsShouldProcess = $true,
        PositionalBinding = $false,
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=398575',
        DefaultParameterSetName = "ModuleNameParameterSet")]
    Param
    (
        [Parameter(Mandatory = $true,
            ParameterSetName = "ModuleNameParameterSet",
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true,
            ParameterSetName = "ModulePathParameterSet",
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(ParameterSetName = "ModuleNameParameterSet")]
        [ValidateNotNullOrEmpty()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $NuGetApiKey,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository = $Script:PSGalleryModuleSource,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [ValidateSet("2.0")]
        [Version]
        $FormatVersion,

        [Parameter()]
        [string[]]
        $ReleaseNotes,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Tags,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $LicenseUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $IconUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $ProjectUri,

        [Parameter(ParameterSetName = "ModuleNameParameterSet")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Exclude,

        [Parameter()]
        [switch]
        $Force,

        [Parameter(ParameterSetName = "ModuleNameParameterSet")]
        [switch]
        $AllowPrerelease,

        [Parameter()]
        [switch]
        $SkipAutomaticTags
    )

    Begin {
        if ($LicenseUri -and -not (Test-WebUri -uri $LicenseUri)) {
            $message = $LocalizedData.InvalidWebUri -f ($LicenseUri, "LicenseUri")
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "InvalidWebUri" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $LicenseUri
        }

        if ($IconUri -and -not (Test-WebUri -uri $IconUri)) {
            $message = $LocalizedData.InvalidWebUri -f ($IconUri, "IconUri")
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "InvalidWebUri" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $IconUri
        }

        if ($ProjectUri -and -not (Test-WebUri -uri $ProjectUri)) {
            $message = $LocalizedData.InvalidWebUri -f ($ProjectUri, "ProjectUri")
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "InvalidWebUri" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $ProjectUri
        }

        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -BootstrapNuGetExe -Force:$Force
    }

    Process {
        if ($Repository -eq $Script:PSGalleryModuleSource) {
            $moduleSource = Get-PSRepository -Name $Repository -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            if (-not $moduleSource) {
                $message = $LocalizedData.PSGalleryNotFound -f ($Repository)
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId 'PSGalleryNotFound' `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Repository
                return
            }
        }
        else {
            $ev = $null
            $moduleSource = Get-PSRepository -Name $Repository -ErrorVariable ev
            if ($ev) { return }
        }

        $DestinationLocation = $moduleSource.PublishLocation

        if (-not $DestinationLocation -or
            (-not (Microsoft.PowerShell.Management\Test-Path $DestinationLocation) -and
                -not (Test-WebUri -uri $DestinationLocation))) {
            $message = $LocalizedData.PSGalleryPublishLocationIsMissing -f ($Repository, $Repository)
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "PSGalleryPublishLocationIsMissing" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $Repository
        }

        $message = $LocalizedData.PublishLocation -f ($DestinationLocation)
        Write-Verbose -Message $message

        if (-not $NuGetApiKey.Trim()) {
            if (Microsoft.PowerShell.Management\Test-Path -Path $DestinationLocation) {
                $NuGetApiKey = "$(Get-Random)"
            }
            else {
                $message = $LocalizedData.NuGetApiKeyIsRequiredForNuGetBasedGalleryService -f ($Repository, $DestinationLocation)
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "NuGetApiKeyIsRequiredForNuGetBasedGalleryService" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument
            }
        }

        $providerName = Get-ProviderName -PSCustomObject $moduleSource
        if ($providerName -ne $script:NuGetProviderName) {
            $message = $LocalizedData.PublishModuleSupportsOnlyNuGetBasedPublishLocations -f ($moduleSource.PublishLocation, $Repository, $Repository)
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "PublishModuleSupportsOnlyNuGetBasedPublishLocations" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $Repository
        }

        $moduleName = $null

        if ($Name) {
            if ($RequiredVersion) {
                $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
                    -Name $Name `
                    -RequiredVersion $RequiredVersion `
                    -AllowPrerelease:$AllowPrerelease
                if (-not $ValidationResult) {
                    # Validate-VersionParameters throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }

                $reqResult = ValidateAndGet-VersionPrereleaseStrings -Version $RequiredVersion -CallerPSCmdlet $PSCmdlet
                if (-not $reqResult) {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $reqVersion = $reqResult["Version"]
                $reqPrerelease = $reqResult["Prerelease"]
            }
            else {
                $reqVersion = $null
                $reqPrerelease = $null
            }

            # Find the module to be published locally, search by name and RequiredVersion
            $module = Microsoft.PowerShell.Core\Get-Module -ListAvailable -Name $Name -Verbose:$false |
                Microsoft.PowerShell.Core\Where-Object {
                $modInfoPrerelease = $null
                if ($_.PrivateData -and
                    $_.PrivateData.GetType().ToString() -eq "System.Collections.Hashtable" -and
                    $_.PrivateData["PSData"] -and
                    $_.PrivateData.PSData.GetType().ToString() -eq "System.Collections.Hashtable" -and
                    $_.PrivateData.PSData["Prerelease"]) {
                    $modInfoPrerelease = $_.PrivateData.PSData.Prerelease
                }
                (-not $RequiredVersion) -or ( ($reqVersion -eq $_.Version) -and ($reqPrerelease -match $modInfoPrerelease) )
            }

            if (-not $module) {
                if ($RequiredVersion) {
                    $message = $LocalizedData.ModuleWithRequiredVersionNotAvailableLocally -f ($Name, $RequiredVersion)
                }
                else {
                    $message = $LocalizedData.ModuleNotAvailableLocally -f ($Name)
                }

                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "ModuleNotAvailableLocallyToPublish" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Name

            }
            elseif ($module.GetType().ToString() -ne "System.Management.Automation.PSModuleInfo") {
                $message = $LocalizedData.AmbiguousModuleName -f ($Name)
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "AmbiguousModuleNameToPublish" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Name
            }

            $moduleName = $module.Name
            $Path = $module.ModuleBase
        }
        else {
            $resolvedPath = Resolve-PathHelper -Path $Path -CallerPSCmdlet $PSCmdlet | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $resolvedPath -or
                -not (Microsoft.PowerShell.Management\Test-Path -Path $resolvedPath -PathType Container)) {
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage ($LocalizedData.PathIsNotADirectory -f ($Path)) `
                    -ErrorId "PathIsNotADirectory" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Path
                return
            }

            $moduleName = Microsoft.PowerShell.Management\Split-Path -Path $resolvedPath -Leaf
            $modulePathWithVersion = $false

            # if the Leaf of the $resolvedPath is a version, use its parent folder name as the module name
            [Version]$ModuleVersion = $null
            if ([System.Version]::TryParse($moduleName, ([ref]$ModuleVersion))) {
                $moduleName = Microsoft.PowerShell.Management\Split-Path -Path (Microsoft.PowerShell.Management\Split-Path $resolvedPath -Parent) -Leaf
                $modulePathWithVersion = $true
            }

            $manifestPath = Join-PathUtility -Path $resolvedPath -ChildPath "$moduleName.psd1" -PathType File
            $module = $null

            if (Microsoft.PowerShell.Management\Test-Path -Path $manifestPath -PathType Leaf) {
                $ev = $null
                $module = Microsoft.PowerShell.Core\Test-ModuleManifest -Path $manifestPath `
                    -ErrorVariable ev `
                    -Verbose:$VerbosePreference
                if ($ev) {
                    # Above Test-ModuleManifest cmdlet should write an errors to the Errors stream and Console.
                    return
                }
            }
            elseif (-not $modulePathWithVersion -and ($PSVersionTable.PSVersion -ge '5.0.0')) {
                $module = Microsoft.PowerShell.Core\Get-Module -Name $resolvedPath -ListAvailable -ErrorAction SilentlyContinue -Verbose:$false
            }

            if (-not $module) {
                $message = $LocalizedData.InvalidModulePathToPublish -f ($Path)

                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId 'InvalidModulePathToPublish' `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Path
            }
            elseif ($module.GetType().ToString() -ne "System.Management.Automation.PSModuleInfo") {
                $message = $LocalizedData.AmbiguousModulePath -f ($Path)
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId 'AmbiguousModulePathToPublish' `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Path
            }

            if ($module -and (-not $module.Path.EndsWith('.psd1', [System.StringComparison]::OrdinalIgnoreCase))) {
                $message = $LocalizedData.InvalidModuleToPublish -f ($module.Name)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "InvalidModuleToPublish" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $module.Name
            }

            $moduleName = $module.Name
            $Path = $module.ModuleBase
        }

        $message = $LocalizedData.PublishModuleLocation -f ($moduleName, $Path)
        Write-Verbose -Message $message

        #If users are providing tags using -Tags while running PS 5.0, will show warning messages
        if ($Tags) {
            $message = $LocalizedData.TagsShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }

        if ($ReleaseNotes) {
            $message = $LocalizedData.ReleaseNotesShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }

        if ($LicenseUri) {
            $message = $LocalizedData.LicenseUriShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }

        if ($IconUri) {
            $message = $LocalizedData.IconUriShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }

        if ($ProjectUri) {
            $message = $LocalizedData.ProjectUriShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }


        # Copy the source module to temp location to publish
        $tempModulePath = Microsoft.PowerShell.Management\Join-Path -Path $script:TempPath `
            -ChildPath "$(Microsoft.PowerShell.Utility\Get-Random)\$moduleName"


        if ($FormatVersion -eq "1.0") {
            $tempModulePathForFormatVersion = Microsoft.PowerShell.Management\Join-Path $tempModulePath "Content\Deployment\$script:ModuleReferences\$moduleName"
        }
        else {
            $tempModulePathForFormatVersion = $tempModulePath
        }

        $null = Microsoft.PowerShell.Management\New-Item -Path $tempModulePathForFormatVersion -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false

        # Copy-Item -Recurse -Force includes hidden items like .git directories, which we don't want
        # This finds all the items without force (leaving out hidden files and dirs) then copies them
        Microsoft.PowerShell.Management\Get-ChildItem $Path -recurse |
            Microsoft.PowerShell.Management\Copy-Item -Force -Confirm:$false -WhatIf:$false -Destination {
            if ($_.PSIsContainer) {
                Join-Path $tempModulePathForFormatVersion $_.Parent.FullName.substring($path.length)
            }
            else {
                join-path $tempModulePathForFormatVersion $_.FullName.Substring($path.Length)
            }
        }

        try {
            $manifestPath = Join-PathUtility -Path $tempModulePathForFormatVersion -ChildPath "$moduleName.psd1" -PathType File

            if (-not (Microsoft.PowerShell.Management\Test-Path $manifestPath)) {
                $message = $LocalizedData.InvalidModuleToPublish -f ($moduleName)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "InvalidModuleToPublish" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $moduleName
            }

            $ev = $null
            $moduleInfo = Microsoft.PowerShell.Core\Test-ModuleManifest -Path $manifestPath `
                -ErrorVariable ev `
                -Verbose:$VerbosePreference
            if ($ev) {
                # Above Test-ModuleManifest cmdlet should write an errors to the Errors stream and Console.
                return
            }

            if (-not $moduleInfo -or
                -not $moduleInfo.Author -or
                -not $moduleInfo.Description) {
                $message = $LocalizedData.MissingRequiredManifestKeys -f ($moduleName)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "MissingRequiredModuleManifestKeys" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $moduleName
            }

            # Validate Prerelease string
            $moduleInfoPrerelease = $null
            if ($moduleInfo.PrivateData -and
                $moduleInfo.PrivateData.GetType().ToString() -eq "System.Collections.Hashtable" -and
                $moduleInfo.PrivateData["PSData"] -and
                $moduleInfo.PrivateData.PSData.GetType().ToString() -eq "System.Collections.Hashtable" -and
                $moduleInfo.PrivateData.PSData["Prerelease"]) {
                $moduleInfoPrerelease = $moduleInfo.PrivateData.PSData.Prerelease
            }

            $result = ValidateAndGet-VersionPrereleaseStrings -Version $moduleInfo.Version -Prerelease $moduleInfoPrerelease -CallerPSCmdlet $PSCmdlet
            if (-not $result) {
                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }
            $moduleInfoVersion = $result["Version"]
            $moduleInfoPrerelease = $result["Prerelease"]
            $moduleInfoFullVersion = $result["FullVersion"]

            $FindParameters = @{
                Name            = $moduleName
                Repository      = $Repository
                Tag             = 'PSScript'
                AllowPrerelease = $true
                Verbose         = $VerbosePreference
                ErrorAction     = 'SilentlyContinue'
                WarningAction   = 'SilentlyContinue'
                Debug           = $DebugPreference
            }

            if ($Credential) {
                $FindParameters[$script:Credential] = $Credential
            }

            # Check if the specified module name is already used for a script on the specified repository
            # Use Find-Script to check if that name is already used as scriptname
            $scriptPSGetItemInfo = Find-Script @FindParameters |
                Microsoft.PowerShell.Core\Where-Object {$_.Name -eq $moduleName} |
                Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore
            if ($scriptPSGetItemInfo) {
                $message = $LocalizedData.SpecifiedNameIsAlearyUsed -f ($moduleName, $Repository, 'Find-Script')
                ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "SpecifiedNameIsAlearyUsed" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $moduleName
            }

            $null = $FindParameters.Remove('Tag')
            $currentPSGetItemInfo = Find-Module @FindParameters |
                Microsoft.PowerShell.Core\Where-Object {$_.Name -eq $moduleInfo.Name} |
                Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore

            if ($currentPSGetItemInfo) {
                $result = ValidateAndGet-VersionPrereleaseStrings -Version $currentPSGetItemInfo.Version -CallerPSCmdlet $PSCmdlet
                if (-not $result) {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $currentPSGetItemVersion = $result["Version"]
                $currentPSGetItemPrereleaseString = $result["Prerelease"]
                $currentPSGetItemFullVersion = $result["FullVersion"]

                if ($currentPSGetItemVersion -eq $moduleInfoVersion) {
                    # Compare Prerelease strings
                    if (-not $currentPSGetItemPrereleaseString -and -not $moduleInfoPrerelease) {
                        $message = $LocalizedData.ModuleVersionIsAlreadyAvailableInTheGallery -f ($moduleInfo.Name, $moduleInfoFullVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                        ThrowError -ExceptionName 'System.InvalidOperationException' `
                            -ExceptionMessage $message `
                            -ErrorId 'ModuleVersionIsAlreadyAvailableInTheGallery' `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation
                    }
                    elseif (-not $Force -and (-not $currentPSGetItemPrereleaseString -and $moduleInfoPrerelease)) {
                        # User is trying to publish a new Prerelease version AFTER publishing the stable version.
                        $message = $LocalizedData.ModuleVersionShouldBeGreaterThanGalleryVersion -f ($moduleInfo.Name, $moduleInfoFullVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "ModuleVersionShouldBeGreaterThanGalleryVersion" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation
                    }

                    # elseif ($currentPSGetItemPrereleaseString -and -not $moduleInfoPrerelease) --> allow publish
                    # User is attempting to publish a stable version after publishing a Prerelease version (allowed).

                    elseif ($currentPSGetItemPrereleaseString -and $moduleInfoPrerelease) {
                        if ($currentPSGetItemPrereleaseString -eq $moduleInfoPrerelease) {
                            $message = $LocalizedData.ModuleVersionIsAlreadyAvailableInTheGallery -f ($moduleInfo.Name, $moduleInfoFullVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                            ThrowError -ExceptionName 'System.InvalidOperationException' `
                                -ExceptionMessage $message `
                                -ErrorId 'ModuleVersionIsAlreadyAvailableInTheGallery' `
                                -CallerPSCmdlet $PSCmdlet `
                                -ErrorCategory InvalidOperation
                        }

                        elseif (-not $Force -and ($currentPSGetItemPrereleaseString -gt $moduleInfoPrerelease)) {
                            $message = $LocalizedData.ModuleVersionShouldBeGreaterThanGalleryVersion -f ($moduleInfo.Name, $moduleInfoFullVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                            ThrowError -ExceptionName "System.InvalidOperationException" `
                                -ExceptionMessage $message `
                                -ErrorId "ModuleVersionShouldBeGreaterThanGalleryVersion" `
                                -CallerPSCmdlet $PSCmdlet `
                                -ErrorCategory InvalidOperation
                        }

                        # elseif ($currentPSGetItemPrereleaseString -lt $moduleInfoPrerelease) --> allow publish
                    }
                }
                elseif (-not $Force -and (Compare-PrereleaseVersions -FirstItemVersion $moduleInfoVersion `
                            -FirstItemPrerelease $moduleInfoPrerelease `
                            -SecondItemVersion $currentPSGetItemVersion `
                            -SecondItemPrerelease $currentPSGetItemPrereleaseString)) {
                    $message = $LocalizedData.ModuleVersionShouldBeGreaterThanGalleryVersion -f ($moduleInfo.Name, $moduleInfoVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                    ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId "ModuleVersionShouldBeGreaterThanGalleryVersion" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidOperation
                }

                # else ($currentPSGetItemVersion -lt $moduleInfoVersion) --> allow publish
            }

            $shouldProcessMessage = $LocalizedData.PublishModulewhatIfMessage -f ($moduleInfo.Version, $moduleInfo.Name)
            if ($Force -or $PSCmdlet.ShouldProcess($shouldProcessMessage, "Publish-Module")) {
                $PublishPSArtifactUtility_Params = @{
                    PSModuleInfo      = $moduleInfo
                    ManifestPath      = $manifestPath
                    NugetApiKey       = $NuGetApiKey
                    Destination       = $DestinationLocation
                    Repository        = $Repository
                    NugetPackageRoot  = $tempModulePath
                    FormatVersion     = $FormatVersion
                    ReleaseNotes      = $($ReleaseNotes -join "`r`n")
                    Tags              = $Tags
                    SkipAutomaticTags = $SkipAutomaticTags
                    LicenseUri        = $LicenseUri
                    IconUri           = $IconUri
                    ProjectUri        = $ProjectUri
                    Verbose           = $VerbosePreference
                    WarningAction     = $WarningPreference
                    ErrorAction       = $ErrorActionPreference
                    Debug             = $DebugPreference
                }
                if ($PSBoundParameters.Containskey('Credential')) {
                    $PublishPSArtifactUtility_Params.Add('Credential', $Credential)
                }
                if ($Exclude) {
                    $PublishPSArtifactUtility_Params.Add('Exclude', $Exclude)
                }
                Publish-PSArtifactUtility @PublishPSArtifactUtility_Params
            }
        }
        finally {
            Microsoft.PowerShell.Management\Remove-Item $tempModulePath -Force -Recurse -ErrorAction Ignore -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }
    }
}
function Publish-Script {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(SupportsShouldProcess = $true,
        PositionalBinding = $false,
        DefaultParameterSetName = 'PathParameterSet',
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619788')]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'PathParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'LiteralPathParameterSet')]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [string]
        $LiteralPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $NuGetApiKey,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository = $Script:PSGalleryModuleSource,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [switch]
        $Force
    )

    Begin {
        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -BootstrapNuGetExe -Force:$Force
    }

    Process {
        $scriptFilePath = $null
        if ($Path) {
            $scriptFilePath = Resolve-PathHelper -Path $Path -CallerPSCmdlet $PSCmdlet |
            Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $scriptFilePath -or
                -not (Microsoft.PowerShell.Management\Test-Path -Path $scriptFilePath -PathType Leaf)) {
                $errorMessage = ($LocalizedData.PathNotFound -f $Path)
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $errorMessage `
                    -ErrorId "PathNotFound" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ExceptionObject $Path `
                    -ErrorCategory InvalidArgument
            }
        }
        else {
            $scriptFilePath = Resolve-PathHelper -Path $LiteralPath -IsLiteralPath -CallerPSCmdlet $PSCmdlet |
            Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $scriptFilePath -or
                -not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $scriptFilePath -PathType Leaf)) {
                $errorMessage = ($LocalizedData.PathNotFound -f $LiteralPath)
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $errorMessage `
                    -ErrorId "PathNotFound" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ExceptionObject $LiteralPath `
                    -ErrorCategory InvalidArgument
            }
        }

        if (-not $scriptFilePath.EndsWith('.ps1', [System.StringComparison]::OrdinalIgnoreCase)) {
            $errorMessage = ($LocalizedData.InvalidScriptFilePath -f $scriptFilePath)
            ThrowError  -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $errorMessage `
                -ErrorId "InvalidScriptFilePath" `
                -CallerPSCmdlet $PSCmdlet `
                -ExceptionObject $scriptFilePath `
                -ErrorCategory InvalidArgument
            return
        }

        if ($Repository -eq $Script:PSGalleryModuleSource) {
            $repo = Get-PSRepository -Name $Repository -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            if (-not $repo) {
                $message = $LocalizedData.PSGalleryNotFound -f ($Repository)
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId 'PSGalleryNotFound' `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Repository
                return
            }
        }
        else {
            $ev = $null
            $repo = Get-PSRepository -Name $Repository -ErrorVariable ev
            # Checking for the $repo object as well as terminating errors are not captured into ev on downlevel PowerShell versions.
            if ($ev -or (-not $repo)) { return }
        }

        $DestinationLocation = $null

        if (Get-Member -InputObject $repo -Name $script:ScriptPublishLocation) {
            $DestinationLocation = $repo.ScriptPublishLocation
        }

        if (-not $DestinationLocation -or
            (-not (Microsoft.PowerShell.Management\Test-Path -Path $DestinationLocation) -and
                -not (Test-WebUri -uri $DestinationLocation))) {
            $message = $LocalizedData.PSRepositoryScriptPublishLocationIsMissing -f ($Repository, $Repository)
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "PSRepositoryScriptPublishLocationIsMissing" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $Repository
        }

        $message = $LocalizedData.PublishLocation -f ($DestinationLocation)
        Write-Verbose -Message $message

        if (-not $NuGetApiKey.Trim()) {
            if (Microsoft.PowerShell.Management\Test-Path -Path $DestinationLocation) {
                $NuGetApiKey = "$(Get-Random)"
            }
            else {
                $message = $LocalizedData.NuGetApiKeyIsRequiredForNuGetBasedGalleryService -f ($Repository, $DestinationLocation)
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "NuGetApiKeyIsRequiredForNuGetBasedGalleryService" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument
            }
        }

        $providerName = Get-ProviderName -PSCustomObject $repo
        if ($providerName -ne $script:NuGetProviderName) {
            $message = $LocalizedData.PublishScriptSupportsOnlyNuGetBasedPublishLocations -f ($DestinationLocation, $Repository, $Repository)
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "PublishScriptSupportsOnlyNuGetBasedPublishLocations" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $Repository
        }

        if ($Path) {
            $PSScriptInfo = Test-ScriptFileInfo -Path $scriptFilePath
        }
        else {
            $PSScriptInfo = Test-ScriptFileInfo -LiteralPath $scriptFilePath
        }

        if (-not $PSScriptInfo) {
            # Test-ScriptFileInfo throws the actual error
            return
        }

        $scriptName = $PSScriptInfo.Name

        $result = ValidateAndGet-VersionPrereleaseStrings -Version $PSScriptInfo.Version -CallerPSCmdlet $PSCmdlet
        if (-not $result) {
            # ValidateAndGet-VersionPrereleaseStrings throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }
        $scriptVersion = $result["Version"]
        $scriptPrerelease = $result["Prerelease"]
        $scriptFullVersion = $result["FullVersion"]

        # Copy the source script file to temp location to publish
        $tempScriptPath = Microsoft.PowerShell.Management\Join-Path -Path $script:TempPath -ChildPath "$(Get-Random)" |
        Microsoft.PowerShell.Management\Join-Path -ChildPath $scriptName

        $null = Microsoft.PowerShell.Management\New-Item -Path $tempScriptPath -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        if ($Path) {
            Microsoft.PowerShell.Management\Copy-Item -Path $scriptFilePath -Destination $tempScriptPath -Force -Recurse -Confirm:$false -WhatIf:$false
        }
        else {
            Microsoft.PowerShell.Management\Copy-Item -LiteralPath $scriptFilePath -Destination $tempScriptPath -Force -Recurse -Confirm:$false -WhatIf:$false
        }

        try {
            $FindParameters = @{
                Name            = $scriptName
                Repository      = $Repository
                Tag             = 'PSModule'
                AllowPrerelease = $true
                Verbose         = $VerbosePreference
                ErrorAction     = 'SilentlyContinue'
                WarningAction   = 'SilentlyContinue'
                Debug           = $DebugPreference
            }

            if ($Credential) {
                $FindParameters[$script:Credential] = $Credential
            }

            # Check if the specified script name is already used for a module on the specified repository
            # Use Find-Module to check if that name is already used as module name
            $modulePSGetItemInfo = Find-Module @FindParameters |
            Microsoft.PowerShell.Core\Where-Object { $_.Name -eq $scriptName } |
            Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore
            if ($modulePSGetItemInfo) {
                $message = $LocalizedData.SpecifiedNameIsAlearyUsed -f ($scriptName, $Repository, 'Find-Module')
                ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "SpecifiedNameIsAlearyUsed" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $scriptName
            }

            $null = $FindParameters.Remove('Tag')

            $currentPSGetItemInfo = $null
            $currentPSGetItemInfo = Find-Script @FindParameters |
            Microsoft.PowerShell.Core\Where-Object { $_.Name -eq $scriptName } |
            Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore

            if ($currentPSGetItemInfo) {
                $result = ValidateAndGet-VersionPrereleaseStrings -Version $currentPSGetItemInfo.Version -CallerPSCmdlet $PSCmdlet
                if (-not $result) {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $galleryScriptVersion = $result["Version"]
                $galleryScriptPrerelease = $result["Prerelease"]
                $galleryScriptFullVersion = $result["FullVersion"]

                if ($galleryScriptFullVersion -eq $scriptFullVersion) {
                    $message = $LocalizedData.ScriptVersionIsAlreadyAvailableInTheGallery -f ($scriptName,
                        $scriptFullVersion,
                        $galleryScriptFullVersion,
                        $currentPSGetItemInfo.RepositorySourceLocation)
                    ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId 'ScriptVersionIsAlreadyAvailableInTheGallery' `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidOperation
                }

                if ($galleryScriptVersion -eq $scriptVersion -and -not $Force) {
                    # Prerelease strings will not both be null, otherwise would have terminated already above

                    if (-not $Force -and (-not $galleryScriptPrerelease -and $scriptPrerelease)) {
                        # User is trying to publish a new Prerelease version AFTER publishing the stable version.
                        $message = $LocalizedData.ScriptPrereleaseStringShouldBeGreaterThanGalleryPrereleaseString -f ($scriptName,
                            $scriptVersion,
                            $scriptPrerelease,
                            $galleryScriptPrerelease,
                            $currentPSGetItemInfo.RepositorySourceLocation)
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "ScriptPrereleaseStringShouldBeGreaterThanGalleryPrereleaseString" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation
                    }

                    # elseif ($galleryScriptPrerelease -and -not $scriptPrerelease) --> allow publish
                    # User is attempting to publish a stable version after publishing a prerelease version (allowed).

                    elseif ($galleryScriptPrerelease -and $scriptPrerelease) {
                        # if ($galleryScriptPrerelease -eq $scriptPrerelease) --> not reachable, would have terminated already above.

                        if (-not $Force -and ($galleryScriptPrerelease -gt $scriptPrerelease)) {
                            # User is trying to publish a lower prerelease version.
                            $message = $LocalizedData.ScriptPrereleaseStringShouldBeGreaterThanGalleryPrereleaseString -f ($scriptName,
                                $scriptVersion,
                                $scriptPrerelease,
                                $galleryScriptPrerelease,
                                $currentPSGetItemInfo.RepositorySourceLocation)
                            ThrowError -ExceptionName "System.InvalidOperationException" `
                                -ExceptionMessage $message `
                                -ErrorId "ScriptPrereleaseStringShouldBeGreaterThanGalleryPrereleaseString" `
                                -CallerPSCmdlet $PSCmdlet `
                                -ErrorCategory InvalidOperation
                        }

                        # elseif ($galleryScriptPrerelease -lt $scriptPrerelease) --> allow publish
                        # User is trying to publish a newer prerelease version (allowed)
                    }
                }
                elseif (-not $Force -and (Compare-PrereleaseVersions -FirstItemVersion $scriptVersion `
                            -FirstItemPrerelease $scriptPrerelease `
                            -SecondItemVersion $galleryScriptVersion `
                            -SecondItemPrerelease $galleryScriptPrerelease)) {
                    $message = $LocalizedData.ScriptVersionShouldBeGreaterThanGalleryVersion -f ($scriptName,
                        $scriptVersion,
                        $galleryScriptVersion,
                        $currentPSGetItemInfo.RepositorySourceLocation)
                    ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId "ScriptVersionShouldBeGreaterThanGalleryVersion" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidOperation
                }

                # else ($galleryScriptVersion -lt $scriptVersion) --> allow publish
                # User is trying to publish a newer stable version (allowed)
            }

            $shouldProcessMessage = $LocalizedData.PublishScriptwhatIfMessage -f ($PSScriptInfo.Version, $scriptName)
            if ($Force -or $PSCmdlet.ShouldProcess($shouldProcessMessage, "Publish-Script")) {
                $PublishPSArtifactUtility_Params = @{
                    PSScriptInfo     = $PSScriptInfo
                    NugetApiKey      = $NuGetApiKey
                    Destination      = $DestinationLocation
                    Repository       = $Repository
                    NugetPackageRoot = $tempScriptPath
                    Verbose          = $VerbosePreference
                    WarningAction    = $WarningPreference
                    ErrorAction      = $ErrorActionPreference
                    Debug            = $DebugPreference
                }
                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $PublishPSArtifactUtility_Params.Add('Credential', $Credential)
                }
                Publish-PSArtifactUtility @PublishPSArtifactUtility_Params
            }
        }
        finally {
            Microsoft.PowerShell.Management\Remove-Item $tempScriptPath -Force -Recurse -ErrorAction Ignore -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }
    }
}
function Register-PSRepository {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(DefaultParameterSetName = 'NameParameterSet',
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=517129')]
    Param
    (
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true,
            Position = 1,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $SourceLocation,

        [Parameter(ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $PublishLocation,

        [Parameter(ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $ScriptSourceLocation,

        [Parameter(ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $ScriptPublishLocation,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameParameterSet')]
        [PSCredential]
        $Credential,

        [Parameter(Mandatory = $true,
            ParameterSetName = 'PSGalleryParameterSet')]
        [Switch]
        $Default,

        [Parameter()]
        [ValidateSet('Trusted', 'Untrusted')]
        [string]
        $InstallationPolicy = 'Untrusted',

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter(ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string]
        $PackageManagementProvider
    )

    DynamicParam {
        if (Get-Variable -Name SourceLocation -ErrorAction SilentlyContinue) {
            Set-Variable -Name selectedProviderName -value $null -Scope 1

            if (Get-Variable -Name PackageManagementProvider -ErrorAction SilentlyContinue) {
                $selectedProviderName = $PackageManagementProvider
                $null = Get-DynamicParameters -Location $SourceLocation -PackageManagementProvider ([REF]$selectedProviderName)
            }
            else {
                $dynamicParameters = Get-DynamicParameters -Location $SourceLocation -PackageManagementProvider ([REF]$selectedProviderName)
                Set-Variable -Name PackageManagementProvider -Value $selectedProviderName -Scope 1
                $null = $dynamicParameters
            }
        }
    }

    Begin {
        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential

        if ($PackageManagementProvider) {
            $providers = PackageManagement\Get-PackageProvider | Where-Object { $_.Name -ne $script:PSModuleProviderName -and $_.Features.ContainsKey($script:SupportsPSModulesFeatureName) }

            if (-not $providers -or $providers.Name -notcontains $PackageManagementProvider) {
                $possibleProviderNames = $script:NuGetProviderName

                if ($providers) {
                    $possibleProviderNames = ($providers.Name -join ',')
                }

                $message = $LocalizedData.InvalidPackageManagementProviderValue -f ($PackageManagementProvider, $possibleProviderNames, $script:NuGetProviderName)
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "InvalidPackageManagementProviderValue" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $PackageManagementProvider
                return
            }
        }
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'PSGalleryParameterSet') {
            if (-not $Default) {
                return
            }

            $PSBoundParameters['Name'] = $Script:PSGalleryModuleSource
            $null = $PSBoundParameters.Remove('Default')
        }
        else {
            if ($Name -eq $Script:PSGalleryModuleSource) {
                $message = $LocalizedData.UseDefaultParameterSetOnRegisterPSRepository
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId 'UseDefaultParameterSetOnRegisterPSRepository' `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Name
                return
            }

            # Ping and resolve the specified location
            $SourceLocation = Resolve-Location -Location (Get-LocationString -LocationUri $SourceLocation) `
                -LocationParameterName 'SourceLocation' `
                -Credential $Credential `
                -Proxy $Proxy `
                -ProxyCredential $ProxyCredential `
                -CallerPSCmdlet $PSCmdlet
            if (-not $SourceLocation) {
                # Above Resolve-Location function throws an error when it is not able to resolve a location
                return
            }

            $pingResult = Ping-Endpoint -Endpoint (Get-LocationString -LocationUri $SourceLocation) -Credential $Credential -Proxy $Proxy -ProxyCredential $ProxyCredential

            $retrievedCredential = $null
            if (!$Credential -and $pingResult -and $pingResult.ContainsKey($Script:StatusCode) `
                    -and ($pingResult[$Script:StatusCode] -eq 401)) {

                # Try pulling credentials from credential provider
                $retrievedCredential = Get-CredsFromCredentialProvider -SourceLocation $SourceLocation

                # Ping and resolve the specified location
                $SourceLocation = Resolve-Location -Location (Get-LocationString -LocationUri $SourceLocation) `
                    -LocationParameterName 'SourceLocation' `
                    -Credential $retrievedCredential `
                    -Proxy $Proxy `
                    -ProxyCredential $ProxyCredential `
                    -CallerPSCmdlet $PSCmdlet
                if (-not $SourceLocation) {
                    # Above Resolve-Location function throws an error when it is not able to resolve a location
                    return
                }

                $pingResult = Ping-Endpoint -Endpoint (Get-LocationString -LocationUri $SourceLocation) -Credential $retrievedCredential -Proxy $Proxy -ProxyCredential $ProxyCredential

                if (!$retrievedCredential -or ($pingResult -and $pingResult.ContainsKey($Script:StatusCode) `
                            -and ($pingResult[$Script:StatusCode] -eq 401))) {

                    # Try again
                    $retriedRetrievedCredential = Get-CredsFromCredentialProvider -SourceLocation $SourceLocation -IsRetry $true

                    # Ping and resolve the specified location
                    $SourceLocation = Resolve-Location -Location (Get-LocationString -LocationUri $SourceLocation) `
                        -LocationParameterName 'SourceLocation' `
                        -Credential $retriedRetrievedCredential `
                        -Proxy $Proxy `
                        -ProxyCredential $ProxyCredential `
                        -CallerPSCmdlet $PSCmdlet

                    if (-not $SourceLocation) {
                        # Above Resolve-Location function throws an error when it is not able to resolve a location
                        return
                    }

                    $pingResult = Ping-Endpoint -Endpoint (Get-LocationString -LocationUri $SourceLocation) -Credential $retrievedCredential -Proxy $Proxy -ProxyCredential $ProxyCredential

                    if (!$retriedRetrievedCredential -or ($pingResult -and $pingResult.ContainsKey($Script:StatusCode) `
                                -and ($pingResult[$Script:StatusCode] -eq 401))) {

                        $message = $LocalizedData.RepositoryCannotBeRegistered -f ($Name)
                        Write-Error -Message $message -ErrorId "RepositoryCannotBeRegistered" -Category InvalidOperation

                        return
                    }
                }
            }

            $providerName = $null

            if ($PackageManagementProvider) {
                $providerName = $PackageManagementProvider
            }
            elseif ($selectedProviderName) {
                $providerName = $selectedProviderName
            }
            else {
                $providerName = Get-PackageManagementProviderName -Location $SourceLocation
            }

            if ($providerName) {
                $PSBoundParameters[$script:PackageManagementProviderParam] = $providerName
            }

            if ($PublishLocation) {
                $PSBoundParameters[$script:PublishLocation] = Get-LocationString -LocationUri $PublishLocation
            }

            if ($ScriptPublishLocation) {
                $PSBoundParameters[$script:ScriptPublishLocation] = Get-LocationString -LocationUri $ScriptPublishLocation
            }

            if ($ScriptSourceLocation) {
                $PSBoundParameters[$script:ScriptSourceLocation] = Get-LocationString -LocationUri $ScriptSourceLocation
            }

            $PSBoundParameters["Location"] = Get-LocationString -LocationUri $SourceLocation
            $null = $PSBoundParameters.Remove("SourceLocation")
        }

        if ($InstallationPolicy -eq "Trusted") {
            $PSBoundParameters['Trusted'] = $true
        }
        $null = $PSBoundParameters.Remove("InstallationPolicy")

        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementMessageResolverScriptBlock

        $null = PackageManagement\Register-PackageSource @PSBoundParameters

        # add nuget based repo as a nuget source
        $nugetCmd = Microsoft.PowerShell.Core\Get-Command -Name $script:NuGetExeName `
            -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        if ($nugetCmd) {
            $nugetSourceExists = nuget sources list | where-object { $_.Trim() -in $SourceLocation }
            if (!$nugetSourceExists) {
                nuget sources add -name $Name -source $SourceLocation
            }
        }
    }
}
function Save-Module {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(DefaultParameterSetName = 'NameAndPathParameterSet',
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=531351',
        SupportsShouldProcess = $true)]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'InputObjectAndPathParameterSet')]
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'InputObjectAndLiteralPathParameterSet')]
        [ValidateNotNull()]
        [PSCustomObject[]]
        $InputObject,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository,

        [Parameter(Mandatory = $true,
            Position = 1,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(Mandatory = $true,
            Position = 1,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'InputObjectAndPathParameterSet')]
        [string]
        $Path,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'InputObjectAndLiteralPathParameterSet')]
        [Alias('PSPath')]
        [string]
        $LiteralPath,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [switch]
        $Force,

        [Parameter(ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [switch]
        $AllowPrerelease,

        [Parameter()]
        [switch]
        $AcceptLicense
    )

    Begin {
        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential

        # Module names already tried in the current pipeline for InputObject parameterset
        $moduleNamesInPipeline = @()
    }

    Process {
        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementSaveModuleMessageResolverScriptBlock
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeModule
        if ($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")

        # When -Force is specified, Path will be created if not available.
        if (-not $Force) {
            if ($Path) {
                $destinationPath = Resolve-PathHelper -Path $Path -CallerPSCmdlet $PSCmdlet | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

                if (-not $destinationPath -or -not (Microsoft.PowerShell.Management\Test-path $destinationPath)) {
                    $errorMessage = ($LocalizedData.PathNotFound -f $Path)
                    ThrowError  -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $errorMessage `
                        -ErrorId "PathNotFound" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ExceptionObject $Path `
                        -ErrorCategory InvalidArgument
                }

                $PSBoundParameters['Path'] = $destinationPath
            }
            else {
                $destinationPath = Resolve-PathHelper -Path $LiteralPath -IsLiteralPath -CallerPSCmdlet $PSCmdlet | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

                if (-not $destinationPath -or -not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $destinationPath)) {
                    $errorMessage = ($LocalizedData.PathNotFound -f $LiteralPath)
                    ThrowError  -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $errorMessage `
                        -ErrorId "PathNotFound" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ExceptionObject $LiteralPath `
                        -ErrorCategory InvalidArgument
                }

                $PSBoundParameters['LiteralPath'] = $destinationPath
            }
        }

        if ($Name) {
            $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
                -Name $Name `
                -TestWildcardsInName `
                -MinimumVersion $MinimumVersion `
                -MaximumVersion $MaximumVersion `
                -RequiredVersion $RequiredVersion `
                -AllowPrerelease:$AllowPrerelease

            if (-not $ValidationResult) {
                # Validate-VersionParameters throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }

            if ($PSBoundParameters.ContainsKey("Repository")) {
                $PSBoundParameters["Source"] = $Repository
                $null = $PSBoundParameters.Remove("Repository")

                $ev = $null
                $null = Get-PSRepository -Name $Repository -ErrorVariable ev -verbose:$false
                if ($ev) { return }
            }

            $null = PackageManagement\Save-Package @PSBoundParameters
        }
        elseif ($InputObject) {
            $null = $PSBoundParameters.Remove("InputObject")

            foreach ($inputValue in $InputObject) {
                if (($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSRepositoryItemInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSRepositoryItemInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSGetCommandInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSGetCommandInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSGetDscResourceInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSGetDscResourceInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSGetRoleCapabilityInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSGetRoleCapabilityInfo")) {
                    ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $LocalizedData.InvalidInputObjectValue `
                        -ErrorId "InvalidInputObjectValue" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $inputValue
                }

                if ( ($inputValue.PSTypeNames -contains "Microsoft.PowerShell.Commands.PSGetDscResourceInfo") -or
                    ($inputValue.PSTypeNames -contains "Deserialized.Microsoft.PowerShell.Commands.PSGetDscResourceInfo") -or
                    ($inputValue.PSTypeNames -contains "Microsoft.PowerShell.Commands.PSGetCommandInfo") -or
                    ($inputValue.PSTypeNames -contains "Deserialized.Microsoft.PowerShell.Commands.PSGetCommandInfo") -or
                    ($inputValue.PSTypeNames -contains "Microsoft.PowerShell.Commands.PSGetRoleCapabilityInfo") -or
                    ($inputValue.PSTypeNames -contains "Deserialized.Microsoft.PowerShell.Commands.PSGetRoleCapabilityInfo")) {
                    $psgetModuleInfo = $inputValue.PSGetModuleInfo
                }
                else {
                    $psgetModuleInfo = $inputValue
                }

                # Skip the module name if it is already tried in the current pipeline
                if ($moduleNamesInPipeline -contains $psgetModuleInfo.Name) {
                    continue
                }

                $moduleNamesInPipeline += $psgetModuleInfo.Name

                if ($psgetModuleInfo.PowerShellGetFormatVersion -and
                    ($script:SupportedPSGetFormatVersionMajors -notcontains $psgetModuleInfo.PowerShellGetFormatVersion.Major)) {
                    $message = $LocalizedData.NotSupportedPowerShellGetFormatVersion -f ($psgetModuleInfo.Name, $psgetModuleInfo.PowerShellGetFormatVersion, $psgetModuleInfo.Name)
                    Write-Error -Message $message -ErrorId "NotSupportedPowerShellGetFormatVersion" -Category InvalidOperation
                    continue
                }

                $PSBoundParameters["Name"] = $psgetModuleInfo.Name
                $PSBoundParameters["RequiredVersion"] = $psgetModuleInfo.Version
                if (($psgetModuleInfo.AdditionalMetadata) -and
                    (Get-Member -InputObject $psgetModuleInfo.AdditionalMetadata -Name "IsPrerelease") -and
                    ($psgetModuleInfo.AdditionalMetadata.IsPrerelease -eq "true")) {
                    $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
                }
                elseif ($PSBoundParameters.ContainsKey($script:AllowPrereleaseVersions)) {
                    $null = $PSBoundParameters.Remove($script:AllowPrereleaseVersions)
                }
                $PSBoundParameters['Source'] = $psgetModuleInfo.Repository
                $PSBoundParameters["PackageManagementProvider"] = (Get-ProviderName -PSCustomObject $psgetModuleInfo)

                $null = PackageManagement\Save-Package @PSBoundParameters
            }
        }
    }
}
function Save-Script {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(DefaultParameterSetName = 'NameAndPathParameterSet',
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619786',
        SupportsShouldProcess = $true)]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'InputObjectAndPathParameterSet')]
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'InputObjectAndLiteralPathParameterSet')]
        [ValidateNotNull()]
        [PSCustomObject[]]
        $InputObject,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1,
            ParameterSetName = 'NameAndPathParameterSet')]

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1,
            ParameterSetName = 'InputObjectAndPathParameterSet')]
        [string]
        $Path,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'InputObjectAndLiteralPathParameterSet')]
        [Alias('PSPath')]
        [string]
        $LiteralPath,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [switch]
        $Force,

        [Parameter(ParameterSetName = 'NameAndPathParameterSet')]
        [Parameter(ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [switch]
        $AllowPrerelease,

        [Parameter()]
        [switch]
        $AcceptLicense
    )

    Begin {
        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential

        # Script names already tried in the current pipeline for InputObject parameterset
        $scriptNamesInPipeline = @()
    }

    Process {
        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementSaveScriptMessageResolverScriptBlock
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeScript
        if ($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")

        # When -Force is specified, Path will be created if not available.
        if (-not $Force) {
            if ($Path) {
                $destinationPath = Resolve-PathHelper -Path $Path -CallerPSCmdlet $PSCmdlet |
                Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

                if (-not $destinationPath -or -not (Microsoft.PowerShell.Management\Test-path $destinationPath)) {
                    $errorMessage = ($LocalizedData.PathNotFound -f $Path)
                    ThrowError  -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $errorMessage `
                        -ErrorId "PathNotFound" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ExceptionObject $Path `
                        -ErrorCategory InvalidArgument
                }

                $PSBoundParameters['Path'] = $destinationPath
            }
            else {
                $destinationPath = Resolve-PathHelper -Path $LiteralPath -IsLiteralPath -CallerPSCmdlet $PSCmdlet |
                Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

                if (-not $destinationPath -or -not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $destinationPath)) {
                    $errorMessage = ($LocalizedData.PathNotFound -f $LiteralPath)
                    ThrowError  -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $errorMessage `
                        -ErrorId "PathNotFound" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ExceptionObject $LiteralPath `
                        -ErrorCategory InvalidArgument
                }

                $PSBoundParameters['LiteralPath'] = $destinationPath
            }
        }

        if ($Name) {
            $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
                -Name $Name `
                -TestWildcardsInName `
                -MinimumVersion $MinimumVersion `
                -MaximumVersion $MaximumVersion `
                -RequiredVersion $RequiredVersion `
                -AllowPrerelease:$AllowPrerelease

            if (-not $ValidationResult) {
                # Validate-VersionParameters throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }

            if ($PSBoundParameters.ContainsKey("Repository")) {
                $PSBoundParameters["Source"] = $Repository
                $null = $PSBoundParameters.Remove("Repository")

                $ev = $null
                $repositories = Get-PSRepository -Name $Repository -ErrorVariable ev -verbose:$false
                if ($ev) { return }

                $RepositoriesWithoutScriptSourceLocation = $false
                foreach ($repo in $repositories) {
                    if (-not $repo.ScriptSourceLocation) {
                        $message = $LocalizedData.ScriptSourceLocationIsMissing -f ($repo.Name)
                        Write-Error -Message $message `
                            -ErrorId 'ScriptSourceLocationIsMissing' `
                            -Category InvalidArgument `
                            -TargetObject $repo.Name `
                            -Exception 'System.ArgumentException'

                        $RepositoriesWithoutScriptSourceLocation = $true
                    }
                }

                if ($RepositoriesWithoutScriptSourceLocation) {
                    return
                }
            }

            $null = PackageManagement\Save-Package @PSBoundParameters
        }
        elseif ($InputObject) {
            $null = $PSBoundParameters.Remove("InputObject")

            foreach ($inputValue in $InputObject) {
                if (($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSRepositoryItemInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSRepositoryItemInfo")) {
                    ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $LocalizedData.InvalidInputObjectValue `
                        -ErrorId "InvalidInputObjectValue" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $inputValue
                }

                $psRepositoryItemInfo = $inputValue

                # Skip the script name if it is already tried in the current pipeline
                if ($scriptNamesInPipeline -contains $psRepositoryItemInfo.Name) {
                    continue
                }

                $scriptNamesInPipeline += $psRepositoryItemInfo.Name

                if ($psRepositoryItemInfo.PowerShellGetFormatVersion -and
                    ($script:SupportedPSGetFormatVersionMajors -notcontains $psRepositoryItemInfo.PowerShellGetFormatVersion.Major)) {
                    $message = $LocalizedData.NotSupportedPowerShellGetFormatVersionScripts -f ($psRepositoryItemInfo.Name, $psRepositoryItemInfo.PowerShellGetFormatVersion, $psRepositoryItemInfo.Name)
                    Write-Error -Message $message -ErrorId "NotSupportedPowerShellGetFormatVersion" -Category InvalidOperation
                    continue
                }

                $PSBoundParameters["Name"] = $psRepositoryItemInfo.Name
                $PSBoundParameters["RequiredVersion"] = $psRepositoryItemInfo.Version
                if (($psRepositoryItemInfo.AdditionalMetadata) -and
                    (Get-Member -InputObject $psRepositoryItemInfo.AdditionalMetadata -Name "IsPrerelease") -and
                    ($psRepositoryItemInfo.AdditionalMetadata.IsPrerelease -eq "true")) {
                    $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
                }
                elseif ($PSBoundParameters.ContainsKey($script:AllowPrereleaseVersions)) {
                    $null = $PSBoundParameters.Remove($script:AllowPrereleaseVersions)
                }
                $PSBoundParameters['Source'] = $psRepositoryItemInfo.Repository
                $PSBoundParameters["PackageManagementProvider"] = (Get-ProviderName -PSCustomObject $psRepositoryItemInfo)

                $null = PackageManagement\Save-Package @PSBoundParameters
            }
        }
    }
}
function Set-PSRepository {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(PositionalBinding = $false,
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=517128')]
    Param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $SourceLocation,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $PublishLocation,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $ScriptSourceLocation,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $ScriptPublishLocation,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [ValidateSet('Trusted', 'Untrusted')]
        [string]
        $InstallationPolicy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $PackageManagementProvider
    )

    DynamicParam {
        if (Get-Variable -Name Name -ErrorAction SilentlyContinue) {
            $moduleSource = Get-PSRepository -Name $Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            if ($moduleSource) {
                $providerName = (Get-ProviderName -PSCustomObject $moduleSource)

                $loc = $moduleSource.SourceLocation

                if (Get-Variable -Name SourceLocation -ErrorAction SilentlyContinue) {
                    $loc = $SourceLocation
                }

                if (Get-Variable -Name PackageManagementProvider -ErrorAction SilentlyContinue) {
                    $providerName = $PackageManagementProvider
                }

                $null = Get-DynamicParameters -Location $loc -PackageManagementProvider ([REF]$providerName)
            }
        }
    }

    Begin {
        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential

        if ($PackageManagementProvider) {
            $providers = PackageManagement\Get-PackageProvider | Where-Object { $_.Name -ne $script:PSModuleProviderName -and $_.Features.ContainsKey($script:SupportsPSModulesFeatureName) }

            if (-not $providers -or $providers.Name -notcontains $PackageManagementProvider) {
                $possibleProviderNames = $script:NuGetProviderName

                if ($providers) {
                    $possibleProviderNames = ($providers.Name -join ',')
                }

                $message = $LocalizedData.InvalidPackageManagementProviderValue -f ($PackageManagementProvider, $possibleProviderNames, $script:NuGetProviderName)
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "InvalidPackageManagementProviderValue" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $PackageManagementProvider
                return
            }
        }
    }

    Process {
        # Ping and resolve the specified location
        if ($SourceLocation) {
            # Ping and resolve the specified location
            $SourceLocation = Resolve-Location -Location (Get-LocationString -LocationUri $SourceLocation) `
                -LocationParameterName 'SourceLocation' `
                -Credential $Credential `
                -Proxy $Proxy `
                -ProxyCredential $ProxyCredential `
                -CallerPSCmdlet $PSCmdlet
            if (-not $SourceLocation) {
                # Above Resolve-Location function throws an error when it is not able to resolve a location
                return
            }
        }

        $ModuleSource = Get-PSRepository -Name $Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        if (-not $ModuleSource) {
            $message = $LocalizedData.RepositoryNotFound -f ($Name)

            ThrowError -ExceptionName "System.InvalidOperationException" `
                -ExceptionMessage $message `
                -ErrorId "RepositoryNotFound" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidOperation `
                -ExceptionObject $Name
        }

        if (-not $PackageManagementProvider) {
            $PackageManagementProvider = (Get-ProviderName -PSCustomObject $ModuleSource)
        }

        $Trusted = $ModuleSource.Trusted
        if ($InstallationPolicy) {
            if ($InstallationPolicy -eq "Trusted") {
                $Trusted = $true
            }
            else {
                $Trusted = $false
            }

            $null = $PSBoundParameters.Remove("InstallationPolicy")
        }

        if ($PublishLocation) {
            $PSBoundParameters[$script:PublishLocation] = Get-LocationString -LocationUri $PublishLocation
        }

        if ($ScriptPublishLocation) {
            $PSBoundParameters[$script:ScriptPublishLocation] = Get-LocationString -LocationUri $ScriptPublishLocation
        }

        if ($ScriptSourceLocation) {
            $PSBoundParameters[$script:ScriptSourceLocation] = Get-LocationString -LocationUri $ScriptSourceLocation
        }

        if ($SourceLocation) {
            $PSBoundParameters["NewLocation"] = Get-LocationString -LocationUri $SourceLocation

            $null = $PSBoundParameters.Remove("SourceLocation")
        }

        $PSBoundParameters[$script:PackageManagementProviderParam] = $PackageManagementProvider
        $PSBoundParameters["Trusted"] = $Trusted
        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementMessageResolverScriptBlock

        $null = PackageManagement\Set-PackageSource @PSBoundParameters
    }
}
function Test-ScriptFileInfo {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(PositionalBinding = $false,
        DefaultParameterSetName = 'PathParameterSet',
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619791')]
    Param
    (
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'PathParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'LiteralPathParameterSet')]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [string]
        $LiteralPath
    )

    Process {
        $scriptFilePath = $null
        if ($Path) {
            $scriptFilePath = Resolve-PathHelper -Path $Path -CallerPSCmdlet $PSCmdlet | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $scriptFilePath -or -not (Microsoft.PowerShell.Management\Test-Path -Path $scriptFilePath -PathType Leaf)) {
                $errorMessage = ($LocalizedData.PathNotFound -f $Path)
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $errorMessage `
                    -ErrorId "PathNotFound" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ExceptionObject $Path `
                    -ErrorCategory InvalidArgument
                return
            }
        }
        else {
            $scriptFilePath = Resolve-PathHelper -Path $LiteralPath -IsLiteralPath -CallerPSCmdlet $PSCmdlet | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $scriptFilePath -or -not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $scriptFilePath -PathType Leaf)) {
                $errorMessage = ($LocalizedData.PathNotFound -f $LiteralPath)
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $errorMessage `
                    -ErrorId "PathNotFound" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ExceptionObject $LiteralPath `
                    -ErrorCategory InvalidArgument
                return
            }
        }

        if (-not $scriptFilePath.EndsWith('.ps1', [System.StringComparison]::OrdinalIgnoreCase)) {
            $errorMessage = ($LocalizedData.InvalidScriptFilePath -f $scriptFilePath)
            ThrowError  -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $errorMessage `
                -ErrorId "InvalidScriptFilePath" `
                -CallerPSCmdlet $PSCmdlet `
                -ExceptionObject $scriptFilePath `
                -ErrorCategory InvalidArgument
            return
        }

        $PSScriptInfo = New-PSScriptInfoObject -Path $scriptFilePath

        [System.Management.Automation.Language.Token[]]$tokens = $null;
        [System.Management.Automation.Language.ParseError[]]$errors = $null;
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFilePath, ([ref]$tokens), ([ref]$errors))


        $notSupportedOnNanoErrorIds = @('WorkflowNotSupportedInPowerShellCore',
            'ConfigurationNotSupportedInPowerShellCore')
        $errorsAfterSkippingOneCoreErrors = $errors | Microsoft.PowerShell.Core\Where-Object { $notSupportedOnNanoErrorIds -notcontains $_.ErrorId }

        if ($errorsAfterSkippingOneCoreErrors) {
            $errorMessage = ($LocalizedData.ScriptParseError -f $scriptFilePath)
            ThrowError  -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $errorMessage `
                -ErrorId "ScriptParseError" `
                -CallerPSCmdlet $PSCmdlet `
                -ExceptionObject $errorsAfterSkippingOneCoreErrors `
                -ErrorCategory InvalidArgument
            return
        }

        if ($ast) {
            # Get the block/group comment beginning with <#PSScriptInfo
            $CommentTokens = $tokens | Microsoft.PowerShell.Core\Where-Object { $_.Kind -eq 'Comment' }

            $psscriptInfoComments = $CommentTokens |
            Microsoft.PowerShell.Core\Where-Object { $_.Extent.Text -match "<#PSScriptInfo" } |
            Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $psscriptInfoComments) {
                $errorMessage = ($LocalizedData.MissingPSScriptInfo -f $scriptFilePath)
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $errorMessage `
                    -ErrorId "MissingPSScriptInfo" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ExceptionObject $scriptFilePath `
                    -ErrorCategory InvalidArgument
                return
            }

            # $psscriptInfoComments.Text will have the multiline PSScriptInfo comment,
            # split them into multiple lines to parse for the PSScriptInfo metadata properties.
            $commentLines = [System.Text.RegularExpressions.Regex]::Split($psscriptInfoComments.Text, "[\r\n]")

            $KeyName = $null
            $Value = ""

            # PSScriptInfo comment will be in following format:
            <#PSScriptInfo

                .VERSION 1.0

                .GUID 544238e3-1751-4065-9227-be105ff11636

                .AUTHOR manikb

                .COMPANYNAME Microsoft Corporation

                .COPYRIGHT (c) 2015 Microsoft Corporation. All rights reserved.

                .TAGS Tag1 Tag2 Tag3

                .LICENSEURI https://contoso.com/License

                .PROJECTURI https://contoso.com/

                .ICONURI https://contoso.com/Icon

                .EXTERNALMODULEDEPENDENCIES ExternalModule1

                .REQUIREDSCRIPTS Start-WFContosoServer,Stop-ContosoServerScript

                .EXTERNALSCRIPTDEPENDENCIES Stop-ContosoServerScript

                .RELEASENOTES
                contoso script now supports following features
                Feature 1
                Feature 2
                Feature 3
                Feature 4
                Feature 5

                #>
            # If comment line count is not more than two, it doesn't have the any metadata property
            # First line is <#PSScriptInfo
            # Last line #>
            #
            if ($commentLines.Count -gt 2) {
                for ($i = 1; $i -lt ($commentLines.count - 1); $i++) {
                    $line = $commentLines[$i]

                    if (-not $line) {
                        continue
                    }

                    # A line is starting with . conveys a new metadata property
                    # __NEWLINE__ is used for replacing the value lines while adding the value to $PSScriptInfo object
                    #
                    if ($line.trim().StartsWith('.')) {
                        $parts = $line.trim() -split '[.\s+]', 3 | Microsoft.PowerShell.Core\Where-Object { $_ }

                        if ($KeyName -and $Value) {
                            if ($keyName -eq $script:ReleaseNotes) {
                                $Value = $Value.Trim() -split '__NEWLINE__'
                            }
                            elseif ($keyName -eq $script:DESCRIPTION) {
                                $Value = $Value -split '__NEWLINE__'
                                $Value = ($Value -join "`r`n").Trim()
                            }
                            else {
                                $Value = $Value -split '__NEWLINE__' | Microsoft.PowerShell.Core\Where-Object { $_ }

                                if ($Value -and $Value.GetType().ToString() -eq "System.String") {
                                    $Value = $Value.Trim()
                                }
                            }

                            ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                                -PropertyName $KeyName `
                                -PropertyValue $Value `
                                -CallerPSCmdlet $PSCmdlet
                        }

                        $KeyName = $null
                        $Value = ""

                        if ($parts.GetType().ToString() -eq "System.String") {
                            $KeyName = $parts
                        }
                        else {
                            $KeyName = $parts[0];
                            $Value = $parts[1]
                        }
                    }
                    else {
                        if ($Value) {
                            # __NEWLINE__ is used for replacing the value lines while adding the value to $PSScriptInfo object
                            $Value += '__NEWLINE__'
                        }

                        $Value += $line
                    }
                }

                if ($KeyName -and $Value) {
                    if ($keyName -eq $script:ReleaseNotes) {
                        $Value = $Value.Trim() -split '__NEWLINE__'
                    }
                    elseif ($keyName -eq $script:DESCRIPTION) {
                        $Value = $Value -split '__NEWLINE__'
                        $Value = ($Value -join "`r`n").Trim()
                    }
                    else {
                        $Value = $Value -split '__NEWLINE__' | Microsoft.PowerShell.Core\Where-Object { $_ }

                        if ($Value -and $Value.GetType().ToString() -eq "System.String") {
                            $Value = $Value.Trim()
                        }
                    }

                    ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                        -PropertyName $KeyName `
                        -PropertyValue $Value `
                        -CallerPSCmdlet $PSCmdlet

                    $KeyName = $null
                    $Value = ""
                }
            }

            $helpContent = $ast.GetHelpContent()
            if ($helpContent -and $helpContent.Description) {
                ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                    -PropertyName $script:DESCRIPTION `
                    -PropertyValue $helpContent.Description.Trim() `
                    -CallerPSCmdlet $PSCmdlet

            }

            # Handle RequiredModules
            if ((Microsoft.PowerShell.Utility\Get-Member -InputObject $ast -Name 'ScriptRequirements') -and
                $ast.ScriptRequirements -and
                (Microsoft.PowerShell.Utility\Get-Member -InputObject $ast.ScriptRequirements -Name 'RequiredModules') -and
                $ast.ScriptRequirements.RequiredModules) {
                ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                    -PropertyName $script:RequiredModules `
                    -PropertyValue $ast.ScriptRequirements.RequiredModules `
                    -CallerPSCmdlet $PSCmdlet
            }

            # Get all defined functions and populate DefinedCommands, DefinedFunctions and DefinedWorkflows
            $allCommands = $ast.FindAll( { param($i) return ($i.GetType().Name -eq 'FunctionDefinitionAst') }, $true)

            if ($allCommands) {
                $allCommandNames = $allCommands | ForEach-Object { $_.Name } | Select-Object -Unique -ErrorAction Ignore
                ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                    -PropertyName $script:DefinedCommands `
                    -PropertyValue $allCommandNames `
                    -CallerPSCmdlet $PSCmdlet

                $allFunctionNames = $allCommands | Where-Object { -not $_.IsWorkflow } | ForEach-Object { $_.Name } | Select-Object -Unique -ErrorAction Ignore
                ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                    -PropertyName $script:DefinedFunctions `
                    -PropertyValue $allFunctionNames `
                    -CallerPSCmdlet $PSCmdlet


                $allWorkflowNames = $allCommands | Where-Object { $_.IsWorkflow } | ForEach-Object { $_.Name } | Select-Object -Unique -ErrorAction Ignore
                ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                    -PropertyName $script:DefinedWorkflows `
                    -PropertyValue $allWorkflowNames `
                    -CallerPSCmdlet $PSCmdlet
            }
        }

        # Ensure that the script file has the required metadata properties.
        if (-not $PSScriptInfo.Version -or -not $PSScriptInfo.Guid -or -not $PSScriptInfo.Author -or -not $PSScriptInfo.Description) {
            $errorMessage = ($LocalizedData.MissingRequiredPSScriptInfoProperties -f $scriptFilePath)
            ThrowError  -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $errorMessage `
                -ErrorId "MissingRequiredPSScriptInfoProperties" `
                -CallerPSCmdlet $PSCmdlet `
                -ExceptionObject $Path `
                -ErrorCategory InvalidArgument
            return
        }

        if ($PSScriptInfo.Version -match '-') {
            $result = ValidateAndGet-VersionPrereleaseStrings -Version $PSScriptInfo.Version  -CallerPSCmdlet $PSCmdlet
            if (-not $result) {
                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }
        }

        $PSScriptInfo = Get-OrderedPSScriptInfoObject -PSScriptInfo $PSScriptInfo

        return $PSScriptInfo
    }
}
function Uninstall-Module
{
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(DefaultParameterSetName='NameParameterSet',
                   SupportsShouldProcess=$true,
                   HelpUri='https://go.microsoft.com/fwlink/?LinkId=526864')]
    Param
    (
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   Mandatory=$true,
                   Position=0,
                   ParameterSetName='NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Name,

        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0,
                   ParameterSetName='InputObject')]
        [ValidateNotNull()]
        [PSCustomObject[]]
        $InputObject,

        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter(ParameterSetName='NameParameterSet')]
        [switch]
        $AllVersions,

        [Parameter()]
        [Switch]
        $Force,

        [Parameter(ParameterSetName='NameParameterSet')]
        [switch]
        $AllowPrerelease
    )

    Process
    {
        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementUnInstallModuleMessageResolverScriptBlock
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeModule

        if($PSCmdlet.ParameterSetName -eq "InputObject")
        {
            $null = $PSBoundParameters.Remove("InputObject")

            foreach($inputValue in $InputObject)
            {
                if (($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSRepositoryItemInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSRepositoryItemInfo"))
                {
                    ThrowError -ExceptionName "System.ArgumentException" `
                                -ExceptionMessage $LocalizedData.InvalidInputObjectValue `
                                -ErrorId "InvalidInputObjectValue" `
                                -CallerPSCmdlet $PSCmdlet `
                                -ErrorCategory InvalidArgument `
                                -ExceptionObject $inputValue
                }

                $PSBoundParameters["Name"] = $inputValue.Name
                $PSBoundParameters["RequiredVersion"] = $inputValue.Version
                if (($inputValue.AdditionalMetadata) -and
                    (Get-Member -InputObject $inputValue.AdditionalMetadata -Name "IsPrerelease") -and
                    ($inputValue.AdditionalMetadata.IsPrerelease -eq "true")) {
                    $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
                }
                elseif ($PSBoundParameters.ContainsKey($script:AllowPrereleaseVersions)) {
                    $null = $PSBoundParameters.Remove($script:AllowPrereleaseVersions)
                }

                $null = PackageManagement\Uninstall-Package @PSBoundParameters
            }
        }
        else
        {
            $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
                                                           -Name $Name `
                                                           -TestWildcardsInName `
                                                           -MinimumVersion $MinimumVersion `
                                                           -MaximumVersion $MaximumVersion `
                                                           -RequiredVersion $RequiredVersion `
                                                           -AllVersions:$AllVersions `
                                                           -AllowPrerelease:$AllowPrerelease

            if(-not $ValidationResult)
            {
                # Validate-VersionParameters throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }

            $null = PackageManagement\Uninstall-Package @PSBoundParameters
        }
    }
}
function Uninstall-Script
{
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(DefaultParameterSetName='NameParameterSet',
                   SupportsShouldProcess=$true,
                   HelpUri='https://go.microsoft.com/fwlink/?LinkId=619789')]
    Param
    (
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   Mandatory=$true,
                   Position=0,
                   ParameterSetName='NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Name,

        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0,
                   ParameterSetName='InputObject')]
        [ValidateNotNull()]
        [PSCustomObject[]]
        $InputObject,

        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter(ValueFromPipelineByPropertyName=$true,
                   ParameterSetName='NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter()]
        [Switch]
        $Force,

        [Parameter(ParameterSetName='NameParameterSet')]
        [Switch]
        $AllowPrerelease
    )

    Process
    {
        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementUnInstallScriptMessageResolverScriptBlock
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeScript
        if($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")

        if($PSCmdlet.ParameterSetName -eq "InputObject")
        {
            $null = $PSBoundParameters.Remove("InputObject")

            foreach($inputValue in $InputObject)
            {
                if (($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSRepositoryItemInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSRepositoryItemInfo"))
                {
                    ThrowError -ExceptionName "System.ArgumentException" `
                                -ExceptionMessage $LocalizedData.InvalidInputObjectValue `
                                -ErrorId "InvalidInputObjectValue" `
                                -CallerPSCmdlet $PSCmdlet `
                                -ErrorCategory InvalidArgument `
                                -ExceptionObject $inputValue
                }

                $PSBoundParameters["Name"] = $inputValue.Name
                $PSBoundParameters["RequiredVersion"] = $inputValue.Version
                if (($inputValue.AdditionalMetadata) -and
                    (Get-Member -InputObject $inputValue.AdditionalMetadata -Name "IsPrerelease") -and
                    ($inputValue.AdditionalMetadata.IsPrerelease -eq "true")) {
                    $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
                }
                elseif ($PSBoundParameters.ContainsKey($script:AllowPrereleaseVersions)) {
                    $null = $PSBoundParameters.Remove($script:AllowPrereleaseVersions)
                }

                $null = PackageManagement\Uninstall-Package @PSBoundParameters
            }
        }
        else
        {
            $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
                                                           -Name $Name `
                                                           -TestWildcardsInName `
                                                           -MinimumVersion $MinimumVersion `
                                                           -MaximumVersion $MaximumVersion `
                                                           -RequiredVersion $RequiredVersion `
                                                           -AllowPrerelease:$AllowPrerelease

            if(-not $ValidationResult)
            {
                # Validate-VersionParameters throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }

            $null = PackageManagement\Uninstall-Package @PSBoundParameters
        }
    }
}
function Unregister-PSRepository {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=517130')]
    Param
    (
        [Parameter(ValueFromPipelineByPropertyName = $true,
            Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name
    )

    Begin {
    }

    Process {
        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementMessageResolverScriptBlock

        $null = $PSBoundParameters.Remove("Name")

        foreach ($moduleSourceName in $Name) {
            # Check if $moduleSourceName contains any wildcards
            if (Test-WildcardPattern $moduleSourceName) {
                $message = $LocalizedData.RepositoryNameContainsWildCards -f ($moduleSourceName)
                Write-Error -Message $message -ErrorId "RepositoryNameContainsWildCards" -Category InvalidOperation
                continue
            }

            $PSBoundParameters["Source"] = $moduleSourceName

            $null = PackageManagement\Unregister-PackageSource @PSBoundParameters

            $nugetCmd = Microsoft.PowerShell.Core\Get-Command -Name $script:NuGetExeName `
                -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            if ($nugetCmd){
                # remove nuget based repo as a nuget source
                $nugetSourceExists = nuget source list | where-object { $_.Contains($Name) }
                if ($nugetSourceExists) {
                    nuget sources remove -name $Name
                }
            }
        }
    }
}
function Update-Module {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(SupportsShouldProcess = $true,
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=398576')]
    Param
    (
        [Parameter(ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Name,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [ValidateSet("CurrentUser", "AllUsers")]
        [string]
        $Scope,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter()]
        [Switch]
        $Force,

        [Parameter()]
        [Switch]
        $AllowPrerelease,

        [Parameter()]
        [switch]
        $AcceptLicense,

        [Parameter()]
        [switch]
        $PassThru
    )

    Begin {
        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential

        if ($Scope -eq "AllUsers" -and -not (Test-RunningAsElevated)) {
            # Throw an error when Update-Module is used as a non-admin user and '-Scope AllUsers'
            $message = $LocalizedData.UpdateModuleAdminPrivilegeRequiredForAllUsersScope -f @($script:programFilesModulesPath, $script:MyDocumentsModulesPath)

            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "UpdateModuleAdminPrivilegeRequiredForAllUsersScope" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument
        }

        # Module names already tried in the current pipeline
        $moduleNamesInPipeline = @()
    }

    Process {
        $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
            -Name $Name `
            -MaximumVersion $MaximumVersion `
            -RequiredVersion $RequiredVersion `
            -AllowPrerelease:$AllowPrerelease

        if (-not $ValidationResult) {
            # Validate-VersionParameters throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }

        $GetPackageParameters = @{ }
        $GetPackageParameters[$script:PSArtifactType] = $script:PSArtifactTypeModule
        $GetPackageParameters["Provider"] = $script:PSModuleProviderName
        $GetPackageParameters["MessageResolver"] = $script:PackageManagementMessageResolverScriptBlock
        $GetPackageParameters['ErrorAction'] = 'SilentlyContinue'
        $GetPackageParameters['WarningAction'] = 'SilentlyContinue'
        if ($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")
        $null = $PSBoundParameters.Remove("PassThru")

        $PSGetItemInfos = @()

        if (-not $Name) {
            $Name = @('*')
        }

        foreach ($moduleName in $Name) {
            $GetPackageParameters['Name'] = $moduleName
            $installedPackages = PackageManagement\Get-Package @GetPackageParameters

            if (-not $installedPackages -and -not (Test-WildcardPattern -Name $moduleName)) {
                $availableModules = Get-Module -ListAvailable $moduleName -Verbose:$false | Microsoft.PowerShell.Utility\Select-Object -Unique -ErrorAction Ignore

                if (-not $availableModules) {
                    $message = $LocalizedData.ModuleNotInstalledOnThisMachine -f ($moduleName)
                    Write-Error -Message $message -ErrorId 'ModuleNotInstalledOnThisMachine' -Category InvalidOperation -TargetObject $moduleName
                }
                else {
                    $message = $LocalizedData.ModuleNotInstalledUsingPowerShellGet -f ($moduleName)
                    Write-Error -Message $message -ErrorId 'ModuleNotInstalledUsingInstallModuleCmdlet' -Category InvalidOperation -TargetObject $moduleName
                }

                continue
            }

            $installedPackages |
            Microsoft.PowerShell.Core\ForEach-Object { New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeModule } |
            Microsoft.PowerShell.Core\ForEach-Object { $PSGetItemInfos += $_ }
        }

        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeModule

        foreach ($psgetItemInfo in $PSGetItemInfos) {
            # Skip the module name if it is already tried in the current pipeline
            if ($moduleNamesInPipeline -contains $psgetItemInfo.Name) {
                continue
            }

            $moduleNamesInPipeline += $psgetItemInfo.Name

            $message = $LocalizedData.CheckingForModuleUpdate -f ($psgetItemInfo.Name)
            Write-Verbose -Message $message

            $providerName = Get-ProviderName -PSCustomObject $psgetItemInfo
            if (-not $providerName) {
                $providerName = $script:NuGetProviderName
            }

            $PSBoundParameters["MessageResolver"] = $script:PackageManagementUpdateModuleMessageResolverScriptBlock
            $PSBoundParameters["Name"] = $psgetItemInfo.Name
            $PSBoundParameters['Source'] = $psgetItemInfo.Repository

            $PSBoundParameters["PackageManagementProvider"] = $providerName
            $PSBoundParameters["InstallUpdate"] = $true

            if (-not $Scope) {
                $Scope = Get-InstallationScope -PreviousInstallLocation $psgetItemInfo.InstalledLocation -CurrentUserPath $script:MyDocumentsModulesPath
            }

            $PSBoundParameters["Scope"] = $Scope

            $sid = PackageManagement\Install-Package @PSBoundParameters

            if ($PassThru) {
                $sid | Microsoft.PowerShell.Core\ForEach-Object { New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeModule }
            }
        }
    }
}
function Update-ModuleManifest
{
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(SupportsShouldProcess=$true,
                   PositionalBinding=$false,
                   HelpUri='https://go.microsoft.com/fwlink/?LinkId=619311')]
    Param
    (
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [ValidateNotNullOrEmpty()]
        [Object[]]
        $NestedModules,

        [ValidateNotNullOrEmpty()]
        [Guid]
        $Guid,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Author,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $CompanyName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Copyright,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $RootModule,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Version]
        $ModuleVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Description,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Reflection.ProcessorArchitecture]
        $ProcessorArchitecture,

        [Parameter()]
        [ValidateSet('Desktop','Core')]
        [string[]]
        $CompatiblePSEditions,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Version]
        $PowerShellVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Version]
        $ClrVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Version]
        $DotNetFrameworkVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $PowerShellHostName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Version]
        $PowerShellHostVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Object[]]
        $RequiredModules,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $TypesToProcess,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $FormatsToProcess,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $ScriptsToProcess,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $RequiredAssemblies,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $FileList,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [object[]]
        $ModuleList,

        [Parameter()]
        [string[]]
        $FunctionsToExport,

        [Parameter()]
        [string[]]
        $AliasesToExport,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $VariablesToExport,

        [Parameter()]
        [string[]]
        $CmdletsToExport,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $DscResourcesToExport,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $PrivateData,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Tags,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $ProjectUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $LicenseUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $IconUri,

        [Parameter()]
        [string[]]
        $ReleaseNotes,

        [Parameter()]
        [string]
        $Prerelease,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $HelpInfoUri,

        [Parameter()]
        [switch]
        $PassThru,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $DefaultCommandPrefix,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ExternalModuleDependencies,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $PackageManagementProviders,

        [Parameter()]
        [switch]
        $RequireLicenseAcceptance


    )

    if(-not (Microsoft.PowerShell.Management\Test-Path -Path $Path -PathType Leaf))
    {
        $message = $LocalizedData.UpdateModuleManifestPathCannotFound -f ($Path)
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $message `
                   -ErrorId "InvalidModuleManifestFilePath" `
                   -ExceptionObject $Path `
                   -CallerPSCmdlet $PSCmdlet `
                   -ErrorCategory InvalidArgument
    }

    $ModuleManifestHashTable = $null

    try
    {
        $ModuleManifestHashTable = Get-ManifestHashTable -Path $Path -CallerPSCmdlet $PSCmdlet
    }
    catch
    {
        $message = $LocalizedData.TestModuleManifestFail -f ($_.Exception.Message)
        ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "InvalidModuleManifestFile" `
                    -ExceptionObject $Path `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument
        return
    }

    #Get the original module manifest and migrate all the fields to the new module manifest, including the specified parameter values
    $moduleInfo = $null

    try
    {
        $moduleInfo = Microsoft.PowerShell.Core\Test-ModuleManifest -Path $Path -ErrorAction Stop
    }
    catch
    {
        # Throw an error only if Test-ModuleManifest did not return the PSModuleInfo object.
        # This enables the users to use Update-ModuleManifest cmdlet to update the metadata.
        if(-not $moduleInfo)
        {
            $message = $LocalizedData.TestModuleManifestFail -f ($_.Exception.Message)
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId "InvalidModuleManifestFile" `
                       -ExceptionObject $Path `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument
            return
        }
    }

    #Params to pass to New-ModuleManifest module
    $params = @{}

    #NestedModules is read-only property
    if($NestedModules)
    {
        $params.Add("NestedModules",$NestedModules)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("NestedModules"))
    {
        $params.Add("NestedModules",$ModuleManifestHashtable.NestedModules)
    }

    #Guid is read-only property
    if($Guid)
    {
        $params.Add("Guid",$Guid)
    }
    elseif($moduleInfo.Guid)
    {
        $params.Add("Guid",$moduleInfo.Guid)
    }

    if($Author)
    {
        $params.Add("Author",$Author)
    }
    elseif($moduleInfo.Author)
    {
        $params.Add("Author",$moduleInfo.Author)
    }

    if($CompanyName)
    {
        $params.Add("CompanyName",$CompanyName)
    }
    elseif($moduleInfo.CompanyName)
    {
        $params.Add("CompanyName",$moduleInfo.CompanyName)
    } 
    else  
    {
        #Creating a unique disposable company name to later be replaced by ''
        #Work-around to deal with New-ModuleManifest changing '' to 'Unknown'
        $params.Add("CompanyName", '__UPDATEDCOMPANYNAMETOBEREPLACEDINFUNCTION__')
    }

    if($Copyright)
    {
        $params.Add("CopyRight",$Copyright)
    }
    elseif($moduleInfo.Copyright)
    {
        $params.Add("Copyright",$moduleInfo.Copyright)
    }

    if($RootModule)
    {
        $params.Add("RootModule",$RootModule)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("RootModule") -and $moduleInfo.RootModule)
    {
        $params.Add("RootModule",$ModuleManifestHashTable.RootModule)
    }

    if($ModuleVersion)
    {
        $params.Add("ModuleVersion",$ModuleVersion)
    }
    elseif($moduleInfo.Version)
    {
        $params.Add("ModuleVersion",$moduleInfo.Version)
    }

    if($Description)
    {
        $params.Add("Description",$Description)
    }
    elseif($moduleInfo.Description)
    {
        $params.Add("Description",$moduleInfo.Description)
    }

    if($ProcessorArchitecture)
    {
        $params.Add("ProcessorArchitecture",$ProcessorArchitecture)
    }
    #Check if ProcessorArchitecture has a value and is not 'None' on lower version PS
    elseif($moduleInfo.ProcessorArchitecture -and $moduleInfo.ProcessorArchitecture -ne 'None')
    {
        $params.Add("ProcessorArchitecture",$moduleInfo.ProcessorArchitecture)
    }

    if($PowerShellVersion)
    {
        $params.Add("PowerShellVersion",$PowerShellVersion)
    }
    elseif($moduleinfo.PowerShellVersion)
    {
        $params.Add("PowerShellVersion",$moduleinfo.PowerShellVersion)
    }

    if($ClrVersion)
    {
        $params.Add("ClrVersion",$ClrVersion)
    }
    elseif($moduleInfo.ClrVersion)
    {
        $params.Add("ClrVersion",$moduleInfo.ClrVersion)
    }

    if($DotNetFrameworkVersion)
    {
        $params.Add("DotNetFrameworkVersion",$DotNetFrameworkVersion)
    }
    elseif($moduleInfo.DotNetFrameworkVersion)
    {
        $params.Add("DotNetFrameworkVersion",$moduleInfo.DotNetFrameworkVersion)
    }

    if($PowerShellHostName)
    {
        $params.Add("PowerShellHostName",$PowerShellHostName)
    }
    elseif($moduleInfo.PowerShellHostName)
    {
        $params.Add("PowerShellHostName",$moduleInfo.PowerShellHostName)
    }

    if($PowerShellHostVersion)
    {
        $params.Add("PowerShellHostVersion",$PowerShellHostVersion)
    }
    elseif($moduleInfo.PowerShellHostVersion)
    {
        $params.Add("PowerShellHostVersion",$moduleInfo.PowerShellHostVersion)
    }

    if($RequiredModules)
    {
        $params.Add("RequiredModules",$RequiredModules)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("RequiredModules") -and $moduleInfo.RequiredModules)
    {
        $params.Add("RequiredModules",$ModuleManifestHashtable.RequiredModules)
    }

    if($TypesToProcess)
    {
        $params.Add("TypesToProcess",$TypesToProcess)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("TypesToProcess") -and $moduleInfo.ExportedTypeFiles)
    {
        $params.Add("TypesToProcess",$ModuleManifestHashTable.TypesToProcess)
    }

    if($FormatsToProcess)
    {
        $params.Add("FormatsToProcess",$FormatsToProcess)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("FormatsToProcess") -and $moduleInfo.ExportedFormatFiles)
    {
        $params.Add("FormatsToProcess",$ModuleManifestHashTable.FormatsToProcess)
    }

    if($ScriptsToProcess)
    {
        $params.Add("ScriptsToProcess",$ScriptstoProcess)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("ScriptsToProcess") -and $moduleInfo.Scripts)
    {
        $params.Add("ScriptsToProcess",$ModuleManifestHashTable.ScriptsToProcess)
    }

    if($RequiredAssemblies)
    {
        $params.Add("RequiredAssemblies",$RequiredAssemblies)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("RequiredAssemblies") -and $moduleInfo.RequiredAssemblies)
    {
        $params.Add("RequiredAssemblies",$moduleInfo.RequiredAssemblies)
    }

    if($FileList)
    {
        $params.Add("FileList",$FileList)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("FileList") -and $moduleInfo.FileList)
    {
        $params.Add("FileList",$ModuleManifestHashTable.FileList)
    }

    #Make sure every path defined under FileList is within module base
    $moduleBase = $moduleInfo.ModuleBase
    foreach($file in $params["FileList"])
    {
        #If path is not root path, append the module base to it and check if the file exists
        if(-not [System.IO.Path]::IsPathRooted($file))
        {
            $combinedPath = Join-Path $moduleBase -ChildPath $file
        }
        else
        {
            $combinedPath = $file
        }
        if(-not (Microsoft.PowerShell.Management\Test-Path -Type Leaf -LiteralPath $combinedPath))
        {
            $message = $LocalizedData.FilePathInFileListNotWithinModuleBase -f ($file,$moduleBase)
            ThrowError -ExceptionName "System.ArgumentException" `
               -ExceptionMessage $message `
               -ErrorId "FilePathInFileListNotWithinModuleBase" `
               -ExceptionObject $file `
               -CallerPSCmdlet $PSCmdlet `
               -ErrorCategory InvalidArgument

            return
        }
    }

    if($ModuleList)
    {
        $params.Add("ModuleList",$ModuleList)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("ModuleList") -and $moduleInfo.ModuleList)
    {
        $params.Add("ModuleList",$ModuleManifestHashtable.ModuleList)
    }

    if($FunctionsToExport -or $FunctionsToExport -is [array])
    {
        $params.Add("FunctionsToExport",$FunctionsToExport)
    }
    elseif($moduleInfo.ExportedFunctions)
    {
        #Get the original module info from ManifestHashTable
        if($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("FunctionsToExport") -and $ModuleManifestHashTable['FunctionsToExport'] -eq '*' `
            -and $moduleInfo.ExportedFunctions.Keys.Count -eq 0)
        {
            $params.Add("FunctionsToExport", $ModuleManifestHashTable['FunctionsToExport'])
        }
        elseif($moduleInfo.Prefix)
        {
            #Earlier call to Test-ModuleManifest adds prefix to functions, now those prefixes need to be remove
            #Prefixes are affixed to the beginning of function, or after '-'
            $originalFunctions = $moduleInfo.ExportedFunctions.Keys | 
                foreach-object { $parts = $_ -split '-', 2; $parts[-1] = $parts[-1] -replace "^$($moduleInfo.Prefix)"; $parts -join '-' }
            $params.Add("FunctionsToExport", $originalFunctions)
        }
        else 
        {
            $params.Add("FunctionsToExport",($moduleInfo.ExportedFunctions.Keys -split ' '))
        }
    }
    elseif ($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("FunctionsToExport"))
    {
        $params.Add("FunctionsToExport", $ModuleManifestHashTable['FunctionsToExport'])
    }

    if($AliasesToExport -or $AliasesToExport -is [array])
    {
        $params.Add("AliasesToExport",$AliasesToExport)
    }
    elseif($moduleInfo.ExportedAliases)
    {
        #Get the original module info from ManifestHashTable
        if($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("AliasesToExport") -and $ModuleManifestHashTable['AliasesToExport'] -eq '*' `
            -and $moduleInfo.ExportedAliases.Keys.Count -eq 0)
        {
            $params.Add("AliasesToExport", $ModuleManifestHashTable['AliasesToExport'])
        }
        elseif($moduleInfo.Prefix)
        {
            #Earlier call to Test-ModuleManifest adds prefix to aliases, now those prefixes need to be removed
            #Prefixes are affixed to the beginning of function, or after '-'
            $originalAliases = $moduleInfo.ExportedAliases.Keys | 
                ForEach-Object { $parts = $_ -split '-', 2; $parts[-1] = $parts[-1] -replace "^$($moduleInfo.Prefix)"; $parts -join '-' }
            $params.Add("AliasesToExport", $originalAliases)   
        }
        else 
        {
            $params.Add("AliasesToExport",($moduleInfo.ExportedAliases.Keys -split ' '))
        }
    }
    elseif ($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("AliasesToExport"))
    {
        $params.Add("AliasesToExport", $ModuleManifestHashTable['AliasesToExport'])
    }

    if($VariablesToExport)
    {
        $params.Add("VariablesToExport",$VariablesToExport)
    }
    elseif($moduleInfo.ExportedVariables)
    {
         #Get the original module info from ManifestHashTable
        if($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("VariablesToExport") -and $ModuleManifestHashTable['VariablesToExport'] -eq '*' `
            -and $moduleInfo.ExportedVariables.Keys.Count -eq 0)
        {
            $params.Add("VariablesToExport", $ModuleManifestHashTable['VariablesToExport'])
        }
        else {
            #Since $moduleInfo.ExportedAliases is a hashtable, we need to take the name of the
            #variables and make them into a list
            $params.Add("VariablesToExport",($moduleInfo.ExportedVariables.Keys -split ' '))
        }
    }

    if($CmdletsToExport -or $CmdletsToExport -is [array])
    {
        $params.Add("CmdletsToExport", $CmdletsToExport)
    }
    elseif($moduleInfo.ExportedCmdlets)
    {
        #Get the original module info from ManifestHashTable
        if($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("CmdletsToExport") -and $ModuleManifestHashTable['CmdletsToExport'] -eq '*' `
          -and $moduleInfo.ExportedCmdlets.Count -eq 0)
        {
            $params.Add("CmdletsToExport", $ModuleManifestHashTable['CmdletsToExport'])
        }
        elseif($moduleInfo.Prefix)
        {
            #Earlier call to Test-ModuleManifest adds prefix to cmdlets, now those prefixes need to be removed
            #Prefixes are affixed to the beginning of function, or after '-'
            $originalCmdlets = $moduleInfo.ExportedCmdlets.Keys | 
                ForEach-Object { $parts = $_ -split '-', 2; $parts[-1] = $parts[-1] -replace "^$($moduleInfo.Prefix)"; $parts -join '-' }
            $params.Add("CmdletsToExport", $originalCmdlets)
        }
        else
        {
            $params.Add("CmdletsToExport",($moduleInfo.ExportedCmdlets.Keys -split ' '))
        }
    }
    elseif ($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("CmdletsToExport"))
    {
        $params.Add("CmdletsToExport", $ModuleManifestHashTable['CmdletsToExport'])
    }

    if($DscResourcesToExport)
    {
        #DscResourcesToExport field is not available in PowerShell version lower than 5.0

        if  (($PSVersionTable.PSVersion -lt '5.0.0') -or ($PowerShellVersion -and $PowerShellVersion -lt '5.0') `
             -or (-not $PowerShellVersion -and $moduleInfo.PowerShellVersion -and $moduleInfo.PowerShellVersion -lt '5.0') `
             -or (-not $PowerShellVersion -and -not $moduleInfo.PowerShellVersion))
        {
                ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $LocalizedData.ExportedDscResourcesNotSupportedOnLowerPowerShellVersion `
                   -ErrorId "ExportedDscResourcesNotSupported" `
                   -ExceptionObject $DscResourcesToExport `
                   -CallerPSCmdlet $PSCmdlet `
                   -ErrorCategory InvalidArgument
                return
        }

        $params.Add("DscResourcesToExport",$DscResourcesToExport)
    }
    elseif(Microsoft.PowerShell.Utility\Get-Member -InputObject $moduleInfo -name "ExportedDscResources")
    {
        if($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("DscResourcesToExport") -and $ModuleManifestHashTable['DscResourcesToExport'] -eq '*' `
                -and $moduleInfo.ExportedDscResources.Count -eq 0)
        {
            $params.Add("DscResourcesToExport", $ModuleManifestHashTable['DscResourcesToExport']) 
        }
        else 
        {
            $params.Add("DscResourcesToExport", $moduleInfo.ExportedDscResources)
        }
    }

    if($CompatiblePSEditions)
    {
        # CompatiblePSEditions field is not available in PowerShell version lower than 5.1
        #
        if  (($PSVersionTable.PSVersion -lt '5.1.0') -or ($PowerShellVersion -and $PowerShellVersion -lt '5.1') `
             -or (-not $PowerShellVersion -and $moduleInfo.PowerShellVersion -and $moduleInfo.PowerShellVersion -lt '5.1') `
             -or (-not $PowerShellVersion -and -not $moduleInfo.PowerShellVersion))
        {
                ThrowError -ExceptionName 'System.ArgumentException' `
                           -ExceptionMessage $LocalizedData.CompatiblePSEditionsNotSupportedOnLowerPowerShellVersion `
                           -ErrorId 'CompatiblePSEditionsNotSupported' `
                           -ExceptionObject $CompatiblePSEditions `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument
                return
        }

        $params.Add('CompatiblePSEditions', $CompatiblePSEditions)
    }
    elseif( (Microsoft.PowerShell.Utility\Get-Member -InputObject $moduleInfo -name 'CompatiblePSEditions') -and
            $moduleInfo.CompatiblePSEditions)
    {
        $params.Add('CompatiblePSEditions', $moduleInfo.CompatiblePSEditions)
    }

    if($HelpInfoUri)
    {
        $params.Add("HelpInfoUri",$HelpInfoUri)
    }
    elseif($moduleInfo.HelpInfoUri)
    {
        $params.Add("HelpInfoUri",$moduleInfo.HelpInfoUri)
    }

    if($DefaultCommandPrefix)
    {
        $params.Add("DefaultCommandPrefix",$DefaultCommandPrefix)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("DefaultCommandPrefix") -and $ModuleManifestHashTable.DefaultCommandPrefix)
    {
        $params.Add("DefaultCommandPrefix",$ModuleManifestHashTable.DefaultCommandPrefix)
    }

    #Create a temp file within the directory and generate a new temporary manifest with the input
    $tempPath = Microsoft.PowerShell.Management\Join-Path -Path $moduleInfo.ModuleBase -ChildPath "PSGet_$($moduleInfo.Name).psd1"
    $params.Add("Path",$tempPath)

    try
    {
        #Terminates if there is error creating new module manifest
        try{
            Microsoft.PowerShell.Core\New-ModuleManifest @params -Confirm:$false -WhatIf:$false
            #If company name is the disposable name created for the new module manifest, it will be changed back to ''
            (Get-Content -Path $tempPath) | ForEach-Object {$_ -Replace '__UPDATEDCOMPANYNAMETOBEREPLACEDINFUNCTION__', ''} | Set-Content -Path $tempPath -Confirm:$false -WhatIf:$false
        }
        catch
        {
            $ErrorMessage = $LocalizedData.UpdatedModuleManifestNotValid -f ($Path, $_.Exception.Message)
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $ErrorMessage `
                       -ErrorId "NewModuleManifestFailure" `
                       -ExceptionObject $params `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument
            return
        }

        #Manually update the section in PrivateData since New-ModuleManifest works differently on different PS version
        $PrivateDataInput = ""
        $ExistingData = $moduleInfo.PrivateData
        $Data = @{}
        if($ExistingData)
        {
            foreach($key in $ExistingData.Keys)
            {
                if($key -ne "PSData"){
                    $Data.Add($key,$ExistingData[$key])
                }
                else
                {
                    $PSData = $ExistingData["PSData"]
                    foreach($entry in $PSData.Keys)
                    {
                        $Data.Add($entry,$PSData[$Entry])
                    }
                }
            }
        }

        if($PrivateData)
        {
            foreach($key in $PrivateData.Keys)
            {
                #if user provides PSData within PrivateData, we will parse through the PSData
                if($key -ne "PSData")
                {
                    $Data[$key] = $PrivateData[$Key]
                }

                else
                {
                    $PSData = $ExistingData["PSData"]
                    foreach($entry in $PSData.Keys)
                    {
                        $Data[$entry] = $PSData[$entry]
                    }
                }
            }
        }

        #Tags is a read-only property
        if($Tags)
        {
           $Data["Tags"] = $Tags
        }

        #The following Uris and ReleaseNotes cannot be empty
        if($ProjectUri)
        {
            $Data["ProjectUri"] = $ProjectUri
        }

        if($LicenseUri)
        {
            $Data["LicenseUri"] = $LicenseUri
        }

        if($IconUri)
        {
            $Data["IconUri"] = $IconUri
        }
        if($RequireLicenseAcceptance)
        {
            $Data["RequireLicenseAcceptance"] = $RequireLicenseAcceptance
        }

        if($ReleaseNotes)
        {
            #If value is provided as an array, we append the string.
            $Data["ReleaseNotes"] = $($ReleaseNotes -join "`r`n")
        }

        if ($Prerelease)
        {
            $result = ValidateAndGet-VersionPrereleaseStrings -Version $params["ModuleVersion"] -Prerelease $Prerelease -CallerPSCmdlet $PSCmdlet
            if (-not $result)
            {
                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }
            $validatedPrerelease = $result["Prerelease"]
            $Data[$script:Prerelease] = $validatedPrerelease
        }

        if($ExternalModuleDependencies)
        {
            #ExternalModuleDependencies have to be specified either under $RequiredModules or $NestedModules
            #Extract all the module names specified in the moduleInfo of NestedModules and RequiredModules
            $DependentModuleNames = @()
            foreach($moduleInfo in $params["NestedModules"])
            {
                if($moduleInfo.GetType() -eq [System.Collections.Hashtable])
                {
                    $DependentModuleNames += $moduleInfo.ModuleName
                }
            }

            foreach($moduleInfo in $params["RequiredModules"])
            {
                if($moduleInfo.GetType() -eq [System.Collections.Hashtable])
                {
                    $DependentModuleNames += $moduleInfo.ModuleName
                }
            }

            foreach($dependency in $ExternalModuleDependencies)
            {
                if($params["NestedModules"] -notcontains $dependency -and
                $params["RequiredModules"] -notContains $dependency -and
                $DependentModuleNames -notcontains $dependency)
                {
                    $message = $LocalizedData.ExternalModuleDependenciesNotSpecifiedInRequiredOrNestedModules -f ($dependency)
                    ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId "InvalidExternalModuleDependencies" `
                        -ExceptionObject $Exception `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument
                        return
                    }
            }
            if($Data.ContainsKey("ExternalModuleDependencies"))
            {
                $Data["ExternalModuleDependencies"] = $ExternalModuleDependencies
            }
            else
            {
                $Data.Add("ExternalModuleDependencies", $ExternalModuleDependencies)
            }
        }
        if($PackageManagementProviders)
        {
            #Check if the provided value is within the relative path
            $ModuleBase = Microsoft.PowerShell.Management\Split-Path $Path -Parent
            $Files = Microsoft.PowerShell.Management\Get-ChildItem -Path $ModuleBase
            foreach($provider in $PackageManagementProviders)
            {
                if ($Files.Name -notcontains $provider)
                {
                    $message = $LocalizedData.PackageManagementProvidersNotInModuleBaseFolder -f ($provider,$ModuleBase)
                    ThrowError -ExceptionName "System.ArgumentException" `
                               -ExceptionMessage $message `
                               -ErrorId "InvalidPackageManagementProviders" `
                               -ExceptionObject $PackageManagementProviders `
                               -CallerPSCmdlet $PSCmdlet `
                               -ErrorCategory InvalidArgument
                    return
                }
            }

            $Data["PackageManagementProviders"] = $PackageManagementProviders
        }
        $PrivateDataInput = Get-PrivateData -PrivateData $Data

        #Replace the PrivateData section by first locating the linenumbers of start line and endline.
        $PrivateDataBegin = Select-String -Path $tempPath -Pattern "PrivateData ="
        $PrivateDataBeginLine = $PrivateDataBegin.LineNumber

        $newManifest = Microsoft.PowerShell.Management\Get-Content -Path $tempPath
        #Look up the endline of PrivateData section by finding the matching brackets since private data could
        #consist of multiple pairs of brackets.
        $PrivateDataEndLine=0
        if($PrivateDataBegin -match "@{")
        {
            $leftBrace = 0
            $EndLineOfFile = $newManifest.Length-1

            For($i = $PrivateDataBeginLine;$i -lt $EndLineOfFile; $i++)
            {
                if($newManifest[$i] -match "{")
                {
                    $leftBrace ++
                }
                elseif($newManifest[$i] -match "}")
                {
                    if($leftBrace -gt 0)
                    {
                        $leftBrace --
                    }
                    else
                    {
                       $PrivateDataEndLine = $i
                       break
                    }
                }
            }
        }


        try
        {
            if($PrivateDataEndLine -ne 0)
            {
                #If PrivateData section has more than one line, we will remove the old content and insert the new PrivataData
                $newManifest  | where {$_.readcount -le $PrivateDataBeginLine -or $_.readcount -gt $PrivateDataEndLine+1} `
                | ForEach-Object {
                    $_
                    if($_ -match "PrivateData = ")
                    {
                        $PrivateDataInput
                    }
                  } | Set-Content -Path $tempPath -Confirm:$false -WhatIf:$false
            }

            #In lower version, PrivateData is just a single line
            else
            {
                $PrivateDataForDownlevelPS = "PrivateData = @{ `n"+$PrivateDataInput

                $newManifest  | where {$_.readcount -le $PrivateDataBeginLine -or $_.readcount -gt $PrivateDataBeginLine } `
                | ForEach-Object {
                    $_
                    if($_ -match "PrivateData = ")
                    {
                       $PrivateDataForDownlevelPS
                    }
                } | Set-Content -Path $tempPath -Confirm:$false -WhatIf:$false
            }

            #Verify the new module manifest is valid
            $testModuleInfo = Microsoft.PowerShell.Core\Test-ModuleManifest -Path $tempPath `
                                                                        -Verbose:$VerbosePreference ` -ErrorAction Stop
        }
        #Catch the exceptions from Test-ModuleManifest
        catch
        {
            $message = $LocalizedData.UpdatedModuleManifestNotValid -f ($Path, $_.Exception.Message)

            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId "UpdateManifestFileFail" `
                       -ExceptionObject $_.Exception `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument
            return
        }


        $newContent = Microsoft.PowerShell.Management\Get-Content -Path $tempPath

        #Remove the PSGet_ prepended to the original manifest name due to the temp file name
        $newContent[1] = $newContent[1] -replace "'PSGet_", "'"

        try
        {
            #Ask for confirmation of the new manifest before replacing the original one
            if($PSCmdlet.ShouldProcess($Path,$LocalizedData.UpdateManifestContentMessage+$newContent))
            {
                Microsoft.PowerShell.Management\Set-Content -Path $Path -Value $newContent -Confirm:$false -WhatIf:$false
            }

            #Return the new content if -PassThru is specified
            if($PassThru)
            {
                return $newContent
            }
        }
        catch
        {
            $message = $LocalizedData.ManifestFileReadWritePermissionDenied -f ($Path)
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId "ManifestFileReadWritePermissionDenied" `
                        -ExceptionObject $Path `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument
        }
    }
    finally
    {
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
    }
}
function Update-Script {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(SupportsShouldProcess = $true,
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619787')]
    Param
    (
        [Parameter(ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Name,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [Switch]
        $Force,

        [Parameter()]
        [Switch]
        $AllowPrerelease,

        [Parameter()]
        [switch]
        $AcceptLicense,

        [Parameter()]
        [switch]
        $PassThru
    )

    Begin {
        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential

        # Script names already tried in the current pipeline
        $scriptNamesInPipeline = @()
    }

    Process {
        $scriptFilePathsToUpdate = @()

        $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
            -Name $Name `
            -MaximumVersion $MaximumVersion `
            -RequiredVersion $RequiredVersion `
            -AllowPrerelease:$AllowPrerelease

        if (-not $ValidationResult) {
            # Validate-VersionParameters throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }

        if (-not $Name) {
            $Name = @('*')
        }

        if ($Name) {
            foreach ($scriptName in $Name) {
                $availableScriptPaths = Get-AvailableScriptFilePath -Name $scriptName -Verbose:$false

                if (-not $availableScriptPaths -and -not (Test-WildcardPattern -Name $scriptName)) {
                    $message = $LocalizedData.ScriptNotInstalledOnThisMachine -f ($scriptName, $script:MyDocumentsScriptsPath, $script:ProgramFilesScriptsPath)
                    Write-Error -Message $message -ErrorId "ScriptNotInstalledOnThisMachine" -Category InvalidOperation -TargetObject $scriptName
                    continue
                }

                foreach ($scriptFilePath in $availableScriptPaths) {
                    # Check if this script got installed with PowerShellGet
                    $installedScriptFilePath = Get-InstalledScriptFilePath -Name ([System.IO.Path]::GetFileNameWithoutExtension($scriptFilePath)) |
                    Microsoft.PowerShell.Core\Where-Object { $_ -eq $scriptFilePath }

                    if ($installedScriptFilePath) {
                        $scriptFilePathsToUpdate += $installedScriptFilePath
                    }
                    else {
                        if (-not (Test-WildcardPattern -Name $scriptName)) {
                            $message = $LocalizedData.ScriptNotInstalledUsingPowerShellGet -f ($scriptName)
                            Write-Error -Message $message -ErrorId "ScriptNotInstalledUsingPowerShellGet" -Category InvalidOperation -TargetObject $scriptName
                        }
                        continue
                    }
                }
            }
        }

        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeScript
        $PSBoundParameters["InstallUpdate"] = $true

        foreach ($scriptFilePath in $scriptFilePathsToUpdate) {
            $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFilePath)

            $installedScriptInfoFilePath = $null
            $installedScriptInfoFileName = "$($scriptName)_$script:InstalledScriptInfoFileName"

            if ($scriptFilePath.ToString().StartsWith($script:MyDocumentsScriptsPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $installedScriptInfoFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsInstalledScriptInfosPath `
                    -ChildPath $installedScriptInfoFileName
            }
            elseif ($scriptFilePath.ToString().StartsWith($script:ProgramFilesScriptsPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $installedScriptInfoFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:ProgramFilesInstalledScriptInfosPath `
                    -ChildPath $installedScriptInfoFileName

            }

            $psgetItemInfo = $null
            if ($installedScriptInfoFilePath -and (Microsoft.PowerShell.Management\Test-Path -Path $installedScriptInfoFilePath -PathType Leaf)) {
                $psgetItemInfo = DeSerialize-PSObject -Path $installedScriptInfoFilePath
            }

            # Skip the script name if it is already tried in the current pipeline
            if (-not $psgetItemInfo -or ($scriptNamesInPipeline -contains $psgetItemInfo.Name)) {
                continue
            }


            $scriptFilePath = Microsoft.PowerShell.Management\Join-Path -Path $psgetItemInfo.InstalledLocation `
                -ChildPath "$($psgetItemInfo.Name).ps1"

            # Remove the InstalledScriptInfo.xml file if the actual script file was manually uninstalled by the user
            if (-not (Microsoft.PowerShell.Management\Test-Path -Path $scriptFilePath -PathType Leaf)) {
                Microsoft.PowerShell.Management\Remove-Item -Path $installedScriptInfoFilePath -Force -ErrorAction SilentlyContinue

                continue
            }

            $scriptNamesInPipeline += $psgetItemInfo.Name

            $message = $LocalizedData.CheckingForScriptUpdate -f ($psgetItemInfo.Name)
            Write-Verbose -Message $message

            $providerName = Get-ProviderName -PSCustomObject $psgetItemInfo
            if (-not $providerName) {
                $providerName = $script:NuGetProviderName
            }

            $PSBoundParameters["MessageResolver"] = $script:PackageManagementUpdateScriptMessageResolverScriptBlock
            $PSBoundParameters["PackageManagementProvider"] = $providerName
            $PSBoundParameters["Name"] = $psgetItemInfo.Name
            $PSBoundParameters['Source'] = $psgetItemInfo.Repository
            if ($AllowPrerelease) {
                $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
            }
            $null = $PSBoundParameters.Remove("AllowPrerelease")
            $null = $PSBoundParameters.Remove("PassThru")

            $PSBoundParameters["Scope"] = Get-InstallationScope -PreviousInstallLocation $scriptFilePath -CurrentUserPath $script:MyDocumentsScriptsPath
            $sid = PackageManagement\Install-Package @PSBoundParameters

            if ($PassThru) {
                $sid | Microsoft.PowerShell.Core\ForEach-Object { New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeScript }
            }
        }
    }
}
function Update-ScriptFileInfo {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(PositionalBinding = $false,
        DefaultParameterSetName = 'PathParameterSet',
        SupportsShouldProcess = $true,
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619793')]
    Param
    (
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'PathParameterSet',
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'LiteralPathParameterSet',
            ValueFromPipelineByPropertyName = $true)]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [string]
        $LiteralPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Version,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Author,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Guid]
        $Guid,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Description,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $CompanyName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Copyright,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Object[]]
        $RequiredModules,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ExternalModuleDependencies,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $RequiredScripts,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ExternalScriptDependencies,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Tags,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $ProjectUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $LicenseUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $IconUri,

        [Parameter()]
        [string[]]
        $ReleaseNotes,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $PrivateData,

        [Parameter()]
        [switch]
        $PassThru,

        [Parameter()]
        [switch]
        $Force
    )

    Process {
        # Resolve the script path
        $scriptFilePath = $null
        if ($Path) {
            $scriptFilePath = Resolve-PathHelper -Path $Path -CallerPSCmdlet $PSCmdlet |
            Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $scriptFilePath -or
                -not (Microsoft.PowerShell.Management\Test-Path -Path $scriptFilePath -PathType Leaf)) {
                $errorMessage = ($LocalizedData.PathNotFound -f $Path)
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $errorMessage `
                    -ErrorId "PathNotFound" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ExceptionObject $Path `
                    -ErrorCategory InvalidArgument
            }
        }
        else {
            $scriptFilePath = Resolve-PathHelper -Path $LiteralPath -IsLiteralPath -CallerPSCmdlet $PSCmdlet |
            Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $scriptFilePath -or
                -not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $scriptFilePath -PathType Leaf)) {
                $errorMessage = ($LocalizedData.PathNotFound -f $LiteralPath)
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $errorMessage `
                    -ErrorId "PathNotFound" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ExceptionObject $LiteralPath `
                    -ErrorCategory InvalidArgument
            }
        }

        if (-not $scriptFilePath.EndsWith('.ps1', [System.StringComparison]::OrdinalIgnoreCase)) {
            $errorMessage = ($LocalizedData.InvalidScriptFilePath -f $scriptFilePath)
            ThrowError  -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $errorMessage `
                -ErrorId "InvalidScriptFilePath" `
                -CallerPSCmdlet $PSCmdlet `
                -ExceptionObject $scriptFilePath `
                -ErrorCategory InvalidArgument
            return
        }

        # Obtain script info
        $psscriptInfo = $null
        try {
            $psscriptInfo = Test-ScriptFileInfo -LiteralPath $scriptFilePath
        }
        catch {
            if (-not $Force) {
                throw $_
                return
            }
        }

        if (-not $psscriptInfo) {
            if (-not $Description) {
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $LocalizedData.DescriptionParameterIsMissingForAddingTheScriptFileInfo `
                    -ErrorId 'DescriptionParameterIsMissingForAddingTheScriptFileInfo' `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument
                return
            }

            if (-not $Version) {
                $Version = '1.0'
            }
            else {
                $result = ValidateAndGet-VersionPrereleaseStrings -Version $Version -CallerPSCmdlet $PSCmdlet
                if (-not $result) {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
            }

            if (-not $Author) {
                if ($script:IsWindows) {
                    $Author = (Get-EnvironmentVariable -Name 'USERNAME' -Target $script:EnvironmentVariableTarget.Process -ErrorAction SilentlyContinue)
                }
                else {
                    $Author = $env:USER
                }
            }

            if (-not $Guid) {
                $Guid = [System.Guid]::NewGuid()
            }
        }
        else {
            # Use existing values if any of the parameters are not specified during Update-ScriptFileInfo
            if (-not $Version -and $psscriptInfo.Version) {
                $Version = $psscriptInfo.Version
            }

            if (-not $Guid -and $psscriptInfo.Guid) {
                $Guid = $psscriptInfo.Guid
            }

            if (-not $Author -and $psscriptInfo.Author) {
                $Author = $psscriptInfo.Author
            }

            if (-not $CompanyName -and $psscriptInfo.CompanyName) {
                $CompanyName = $psscriptInfo.CompanyName
            }

            if (-not $Copyright -and $psscriptInfo.Copyright) {
                $Copyright = $psscriptInfo.Copyright
            }

            if (-not $RequiredModules -and $psscriptInfo.RequiredModules) {
                $RequiredModules = $psscriptInfo.RequiredModules
            }

            if (-not $ExternalModuleDependencies -and $psscriptInfo.ExternalModuleDependencies) {
                $ExternalModuleDependencies = $psscriptInfo.ExternalModuleDependencies
            }

            if (-not $RequiredScripts -and $psscriptInfo.RequiredScripts) {
                $RequiredScripts = $psscriptInfo.RequiredScripts
            }

            if (-not $ExternalScriptDependencies -and $psscriptInfo.ExternalScriptDependencies) {
                $ExternalScriptDependencies = $psscriptInfo.ExternalScriptDependencies
            }

            if (-not $Tags -and $psscriptInfo.Tags) {
                $Tags = $psscriptInfo.Tags
            }

            if (-not $ProjectUri -and $psscriptInfo.ProjectUri) {
                $ProjectUri = $psscriptInfo.ProjectUri
            }

            if (-not $LicenseUri -and $psscriptInfo.LicenseUri) {
                $LicenseUri = $psscriptInfo.LicenseUri
            }

            if (-not $IconUri -and $psscriptInfo.IconUri) {
                $IconUri = $psscriptInfo.IconUri
            }

            if (-not $ReleaseNotes -and $psscriptInfo.ReleaseNotes) {
                $ReleaseNotes = $psscriptInfo.ReleaseNotes
            }

            if (-not $PrivateData -and $psscriptInfo.PrivateData) {
                $PrivateData = $psscriptInfo.PrivateData
            }
        }

        $params = @{
            Version                    = $Version
            Author                     = $Author
            Guid                       = $Guid
            CompanyName                = $CompanyName
            Copyright                  = $Copyright
            ExternalModuleDependencies = $ExternalModuleDependencies
            RequiredScripts            = $RequiredScripts
            ExternalScriptDependencies = $ExternalScriptDependencies
            Tags                       = $Tags
            ProjectUri                 = $ProjectUri
            LicenseUri                 = $LicenseUri
            IconUri                    = $IconUri
            ReleaseNotes               = $ReleaseNotes
            PrivateData                = $PrivateData
        }

        # Ensure no fields contain '<#' or '#>' (would break comment section)
        if (-not (Validate-ScriptFileInfoParameters -parameters $params)) {
            return
        }

        if ("$Description" -match '<#' -or "$Description" -match '#>') {
            $message = $LocalizedData.InvalidParameterValue -f ($Description, 'Description')
            Write-Error -Message $message -ErrorId 'InvalidParameterValue' -Category InvalidArgument

            return
        }

        $PSScriptInfoString = Get-PSScriptInfoString @params

        $requiresStrings = Get-RequiresString -RequiredModules $RequiredModules

        $DescriptionValue = if ($Description) { $Description } else { $psscriptInfo.Description }
        $ScriptCommentHelpInfoString = Get-ScriptCommentHelpInfoString -Description $DescriptionValue

        $ScriptMetadataString = $PSScriptInfoString
        $ScriptMetadataString += "`r`n"

        if ("$requiresStrings".Trim()) {
            $ScriptMetadataString += "`r`n"
            $ScriptMetadataString += $requiresStrings -join "`r`n"
            $ScriptMetadataString += "`r`n"
        }

        $ScriptMetadataString += "`r`n"
        $ScriptMetadataString += $ScriptCommentHelpInfoString
        $ScriptMetadataString += "`r`nParam()`r`n`r`n"

        $tempScriptFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:TempPath -ChildPath "$(Get-Random).ps1"

        try {
            # First create a new script file with new script metadata to ensure that updated values are valid.
            Microsoft.PowerShell.Management\Set-Content -Value $ScriptMetadataString -Path $tempScriptFilePath -Force -WhatIf:$false -Confirm:$false

            $scriptInfo = Test-ScriptFileInfo -Path $tempScriptFilePath

            if (-not $scriptInfo) {
                # Above Test-ScriptFileInfo cmdlet writes the error
                return
            }

            $scriptFileContents = Microsoft.PowerShell.Management\Get-Content -LiteralPath $scriptFilePath

            # If -Force is specified and script file doesnt have a valid PSScriptInfo
            # Prepend the PSScriptInfo and Check if the Test-ScriptFileInfo returns a valid script info without any errors
            if ($Force -and -not $psscriptInfo) {
                # Add the script file contents to the temp file with script metadata
                Microsoft.PowerShell.Management\Set-Content -LiteralPath $tempScriptFilePath `
                    -Value $ScriptMetadataString, $scriptFileContents `
                    -Force `
                    -WhatIf:$false `
                    -Confirm:$false

                $tempScriptInfo = $null
                try {
                    $tempScriptInfo = Test-ScriptFileInfo -LiteralPath $tempScriptFilePath
                }
                catch {
                    $errorMessage = ($LocalizedData.UnableToAddPSScriptInfo -f $scriptFilePath)
                    ThrowError  -ExceptionName 'System.InvalidOperationException' `
                        -ExceptionMessage $errorMessage `
                        -ErrorId 'UnableToAddPSScriptInfo' `
                        -CallerPSCmdlet $PSCmdlet `
                        -ExceptionObject $scriptFilePath `
                        -ErrorCategory InvalidOperation
                    return
                }
            }
            else {
                [System.Management.Automation.Language.Token[]]$tokens = $null;
                [System.Management.Automation.Language.ParseError[]]$errors = $null;
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFilePath, ([ref]$tokens), ([ref]$errors))

                # Update PSScriptInfo and #Requires
                $CommentTokens = $tokens | Microsoft.PowerShell.Core\Where-Object { $_.Kind -eq 'Comment' }

                $psscriptInfoComments = $CommentTokens |
                Microsoft.PowerShell.Core\Where-Object { $_.Extent.Text -match "<#PSScriptInfo" } |
                Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

                if (-not $psscriptInfoComments) {
                    $errorMessage = ($LocalizedData.MissingPSScriptInfo -f $scriptFilePath)
                    ThrowError  -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $errorMessage `
                        -ErrorId "MissingPSScriptInfo" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ExceptionObject $scriptFilePath `
                        -ErrorCategory InvalidArgument
                    return
                }

                # Ensure that metadata is replaced at the correct location and should not corrupt the existing script file.

                # Remove the lines between below lines and add the new PSScriptInfo and new #Requires statements
                # ($psscriptInfoComments.Extent.StartLineNumber - 1)
                # ($psscriptInfoComments.Extent.EndLineNumber - 1)
                $tempContents = @()
                $IsNewPScriptInfoAdded = $false

                for ($i = 0; $i -lt $scriptFileContents.Count; $i++) {
                    $line = $scriptFileContents[$i]
                    if (($i -ge ($psscriptInfoComments.Extent.StartLineNumber - 1)) -and
                        ($i -le ($psscriptInfoComments.Extent.EndLineNumber - 1))) {
                        if (-not $IsNewPScriptInfoAdded) {
                            $PSScriptInfoString = $PSScriptInfoString.TrimStart()
                            $requiresStrings = $requiresStrings.TrimEnd()

                            $tempContents += "$PSScriptInfoString `r`n`r`n$($requiresStrings -join "`r`n")"
                            $IsNewPScriptInfoAdded = $true
                        }
                    }
                    elseif ($line -notmatch "\s*#Requires\s+-Module") {
                        # Add the existing lines if they are not part of PSScriptInfo comment or not containing #Requires -Module statements.
                        $tempContents += $line
                    }
                }

                Microsoft.PowerShell.Management\Set-Content -Value $tempContents -Path $tempScriptFilePath -Force -WhatIf:$false -Confirm:$false

                $scriptInfo = Test-ScriptFileInfo -Path $tempScriptFilePath

                if (-not $scriptInfo) {
                    # Above Test-ScriptFileInfo cmdlet writes the error
                    return
                }

                # Now update the Description value if a new is specified.
                if ($Description) {
                    $tempContents = @()
                    $IsDescriptionAdded = $false

                    $IsDescriptionBeginFound = $false
                    $scriptFileContents = Microsoft.PowerShell.Management\Get-Content -Path $tempScriptFilePath

                    for ($i = 0; $i -lt $scriptFileContents.Count; $i++) {
                        $line = $scriptFileContents[$i]

                        if (-not $IsDescriptionAdded) {
                            if (-not $IsDescriptionBeginFound) {
                                if ($line.Trim().StartsWith(".DESCRIPTION", [System.StringComparison]::OrdinalIgnoreCase)) {
                                    $IsDescriptionBeginFound = $true
                                }
                                else {
                                    $tempContents += $line
                                }
                            }
                            else {
                                # Description begin has found
                                # Skip the old description lines until description end is found

                                if ($line.Trim().StartsWith("#>", [System.StringComparison]::OrdinalIgnoreCase) -or
                                    $line.Trim().StartsWith(".", [System.StringComparison]::OrdinalIgnoreCase)) {
                                    $tempContents += ".DESCRIPTION `r`n$($Description -join "`r`n")`r`n"
                                    $IsDescriptionAdded = $true
                                    $tempContents += $line
                                }
                            }
                        }
                        else {
                            $tempContents += $line
                        }
                    }

                    Microsoft.PowerShell.Management\Set-Content -Value $tempContents -Path $tempScriptFilePath -Force -WhatIf:$false -Confirm:$false

                    $scriptInfo = Test-ScriptFileInfo -Path $tempScriptFilePath

                    if (-not $scriptInfo) {
                        # Above Test-ScriptFileInfo cmdlet writes the error
                        return
                    }
                }
            }

            if ($Force -or $PSCmdlet.ShouldProcess($scriptFilePath, ($LocalizedData.UpdateScriptFileInfowhatIfMessage -f $Path) )) {
                Microsoft.PowerShell.Management\Copy-Item -Path $tempScriptFilePath -Destination $scriptFilePath -Force -WhatIf:$false -Confirm:$false

                if ($PassThru) {
                    $ScriptMetadataString
                }
            }
        }
        finally {
            Microsoft.PowerShell.Management\Remove-Item -Path $tempScriptFilePath -Force -WhatIf:$false -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
}

function Add-PackageSource
{
    [CmdletBinding()]
    param
    (
        [string]
        $Name,

        [string]
        $Location,

        [bool]
        $Trusted
    )

    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Add-PackageSource'))

    if(-not $Name)
    {
        return
    }

    $Credential = $request.Credential

    $IsNewModuleSource = $false
    $Options = $request.Options

    foreach( $o in $Options.Keys )
    {
        Write-Debug ( "OPTION: {0} => {1}" -f ($o, $Options[$o]) )
    }

    $Proxy = $null
    if($Options.ContainsKey($script:Proxy))
    {
        $Proxy = $Options[$script:Proxy]

        if(-not (Test-WebUri -Uri $Proxy))
        {
            $message = $LocalizedData.InvalidWebUri -f ($Proxy, $script:Proxy)
            ThrowError -ExceptionName 'System.ArgumentException' `
                        -ExceptionMessage $message `
                        -ErrorId 'InvalidWebUri' `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $Proxy
        }
    }

    $ProxyCredential = $null
    if($Options.ContainsKey($script:ProxyCredential))
    {
        $ProxyCredential = $Options[$script:ProxyCredential]
    }

    Set-ModuleSourcesVariable -Force -Proxy $Proxy -ProxyCredential $ProxyCredential

    if($Options.ContainsKey('IsNewModuleSource'))
    {
        $IsNewModuleSource = $Options['IsNewModuleSource']

        if($IsNewModuleSource.GetType().ToString() -eq 'System.String')
        {
            if($IsNewModuleSource -eq 'false')
            {
                $IsNewModuleSource = $false
            }
            elseif($IsNewModuleSource -eq 'true')
            {
                $IsNewModuleSource = $true
            }
        }
    }

    $IsUpdatePackageSource = $false
    if($Options.ContainsKey('IsUpdatePackageSource'))
    {
        $IsUpdatePackageSource = $Options['IsUpdatePackageSource']

        if($IsUpdatePackageSource.GetType().ToString() -eq 'System.String')
        {
            if($IsUpdatePackageSource -eq 'false')
            {
                $IsUpdatePackageSource = $false
            }
            elseif($IsUpdatePackageSource -eq 'true')
            {
                $IsUpdatePackageSource = $true
            }
        }
    }

    $PublishLocation = $null
    if($Options.ContainsKey($script:PublishLocation))
    {
        if($Name -eq $Script:PSGalleryModuleSource)
        {
            $message = $LocalizedData.ParameterIsNotAllowedWithPSGallery -f ('PublishLocation')
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId 'ParameterIsNotAllowedWithPSGallery' `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $PublishLocation
        }

        $PublishLocation = $Options[$script:PublishLocation]

        if(-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $PublishLocation) -and
           -not (Test-WebUri -uri $PublishLocation))
        {
            $PublishLocationUri = [Uri]$PublishLocation
            if($PublishLocationUri.Scheme -eq 'file')
            {
                $message = $LocalizedData.PathNotFound -f ($PublishLocation)
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "PathNotFound" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $PublishLocation
            }
            else
            {
                $message = $LocalizedData.InvalidWebUri -f ($PublishLocation, "PublishLocation")
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "InvalidWebUri" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $PublishLocation
            }
        }
    }

    $ScriptSourceLocation = $null
    if($Options.ContainsKey($script:ScriptSourceLocation))
    {
        if($Name -eq $Script:PSGalleryModuleSource)
        {
            $message = $LocalizedData.ParameterIsNotAllowedWithPSGallery -f ('ScriptSourceLocation')
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId 'ParameterIsNotAllowedWithPSGallery' `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $ScriptSourceLocation
        }

        $ScriptSourceLocation = $Options[$script:ScriptSourceLocation]

        if(-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $ScriptSourceLocation) -and
           -not (Test-WebUri -uri $ScriptSourceLocation))
        {
            $ScriptSourceLocationUri = [Uri]$ScriptSourceLocation
            if($ScriptSourceLocationUri.Scheme -eq 'file')
            {
                $message = $LocalizedData.PathNotFound -f ($ScriptSourceLocation)
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "PathNotFound" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $ScriptSourceLocation
            }
            else
            {
                $message = $LocalizedData.InvalidWebUri -f ($ScriptSourceLocation, "ScriptSourceLocation")
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "InvalidWebUri" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $ScriptSourceLocation
            }
        }
    }

    $ScriptPublishLocation = $null
    if($Options.ContainsKey($script:ScriptPublishLocation))
    {
        if($Name -eq $Script:PSGalleryModuleSource)
        {
            $message = $LocalizedData.ParameterIsNotAllowedWithPSGallery -f ('ScriptPublishLocation')
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId 'ParameterIsNotAllowedWithPSGallery' `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $ScriptPublishLocation
        }

        $ScriptPublishLocation = $Options[$script:ScriptPublishLocation]

        if(-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $ScriptPublishLocation) -and
           -not (Test-WebUri -uri $ScriptPublishLocation))
        {
            $ScriptPublishLocationUri = [Uri]$ScriptPublishLocation
            if($ScriptPublishLocationUri.Scheme -eq 'file')
            {
                $message = $LocalizedData.PathNotFound -f ($ScriptPublishLocation)
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "PathNotFound" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $ScriptPublishLocation
            }
            else
            {
                $message = $LocalizedData.InvalidWebUri -f ($ScriptPublishLocation, "ScriptPublishLocation")
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "InvalidWebUri" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $ScriptPublishLocation
            }
        }
    }

    $currentSourceObject = $null

    # Check if Name is already registered
    if($script:PSGetModuleSources.Contains($Name))
    {
        $currentSourceObject = $script:PSGetModuleSources[$Name]
    }

    # Location is not allowed for PSGallery source
    # However OneGet passes Location value during Set-PackageSource cmdlet,
    # that's why ensuring that Location value is same as the current SourceLocation
    #
    if(($Name -eq $Script:PSGalleryModuleSource) -and
       $Location -and
       ((-not $IsUpdatePackageSource) -or ($currentSourceObject -and $currentSourceObject.SourceLocation -ne $Location)))
    {
        $message = $LocalizedData.ParameterIsNotAllowedWithPSGallery -f ('Location, NewLocation or SourceLocation')
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $message `
                   -ErrorId 'ParameterIsNotAllowedWithPSGallery' `
                   -CallerPSCmdlet $PSCmdlet `
                   -ErrorCategory InvalidArgument `
                   -ExceptionObject $Location
    }

    if($Name -eq $Script:PSGalleryModuleSource)
    {
        # Add or update the PSGallery repository
        $repository = Set-PSGalleryRepository -Trusted:$Trusted

        if($repository)
        {
            # return the package source object.
            Write-Output -InputObject (New-PackageSourceFromModuleSource -ModuleSource $repository)
        }

        return
    }

    if($Location)
    {
        # Ping and resolve the specified location
        $Location = Resolve-Location -Location $Location `
                                     -LocationParameterName 'Location' `
                                     -Credential $Credential `
                                     -Proxy $Proxy `
                                     -ProxyCredential $ProxyCredential `
                                     -CallerPSCmdlet $PSCmdlet
    }

    if(-not $Location)
    {
        # Above Resolve-Location function throws an error when it is not able to resolve a location
        return
    }

    if(-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $Location) -and
       -not (Test-WebUri -uri $Location) )
    {
        $LocationUri = [Uri]$Location
        if($LocationUri.Scheme -eq 'file')
        {
            $message = $LocalizedData.PathNotFound -f ($Location)
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId "PathNotFound" `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $Location
        }
        else
        {
            $message = $LocalizedData.InvalidWebUri -f ($Location, "Location")
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId "InvalidWebUri" `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $Location
        }
    }

    if(Test-WildcardPattern $Name)
    {
        $message = $LocalizedData.RepositoryNameContainsWildCards -f ($Name)
        ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "RepositoryNameContainsWildCards" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Name
    }

    $LocationString = Get-ValidModuleLocation -LocationString $Location -ParameterName "Location" -Proxy $Proxy -ProxyCredential $ProxyCredential -Credential $Credential

    # Check if Location is already registered with another Name
    $existingSourceName = Get-SourceName -Location $LocationString

    if($existingSourceName -and
       ($Name -ne $existingSourceName) -and
       -not $IsNewModuleSource)
    {
        $message = $LocalizedData.RepositoryAlreadyRegistered -f ($existingSourceName, $Location, $Name)
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $message `
                   -ErrorId "RepositoryAlreadyRegistered" `
                   -CallerPSCmdlet $PSCmdlet `
                   -ErrorCategory InvalidArgument
    }

    if(-not $PublishLocation -and $currentSourceObject -and $currentSourceObject.PublishLocation)
    {
        $PublishLocation = $currentSourceObject.PublishLocation
    }

    if((-not $ScriptPublishLocation) -and
       $currentSourceObject -and
       (Get-Member -InputObject $currentSourceObject -Name $script:ScriptPublishLocation) -and
       $currentSourceObject.ScriptPublishLocation)
    {
        $ScriptPublishLocation = $currentSourceObject.ScriptPublishLocation
    }

    if((-not $ScriptSourceLocation) -and
       $currentSourceObject -and
       (Get-Member -InputObject $currentSourceObject -Name $script:ScriptSourceLocation) -and
       $currentSourceObject.ScriptSourceLocation)
    {
        $ScriptSourceLocation = $currentSourceObject.ScriptSourceLocation
    }

    $IsProviderSpecified = $false;
    if ($Options.ContainsKey($script:PackageManagementProviderParam))
    {
        $SpecifiedProviderName = $Options[$script:PackageManagementProviderParam]

        $IsProviderSpecified = $true

        Write-Verbose ($LocalizedData.SpecifiedProviderName -f $SpecifiedProviderName)
        if ($SpecifiedProviderName -eq $script:PSModuleProviderName)
        {
            $message = $LocalizedData.InvalidPackageManagementProviderValue -f ($SpecifiedProviderName, $script:NuGetProviderName, $script:NuGetProviderName)
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId "InvalidPackageManagementProviderValue" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $SpecifiedProviderName
            return
        }
    }
    else
    {
        $SpecifiedProviderName = $script:NuGetProviderName
        Write-Verbose ($LocalizedData.ProviderNameNotSpecified -f $SpecifiedProviderName)
    }

    $packageSource = $null

    $selProviders = $request.SelectProvider($SpecifiedProviderName)

    if(-not $selProviders -and $IsProviderSpecified)
    {
        $message = $LocalizedData.SpecifiedProviderNotAvailable -f $SpecifiedProviderName
        ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "SpecifiedProviderNotAvailable" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $SpecifiedProviderName
    }

    # Try with user specified provider or NuGet provider
    foreach($SelectedProvider in $selProviders)
    {
        if($request.IsCanceled)
        {
            return
        }

        if($SelectedProvider -and $SelectedProvider.Features.ContainsKey($script:SupportsPSModulesFeatureName))
        {
            $NewRequest = $request.CloneRequest( $null, @($LocationString), $request.Credential )
            $packageSource = $SelectedProvider.ResolvePackageSources( $NewRequest )
        }
        else
        {
            $message = $LocalizedData.SpecifiedProviderDoesnotSupportPSModules -f $SelectedProvider.ProviderName
            ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId "SpecifiedProviderDoesnotSupportPSModules" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidOperation `
                        -ExceptionObject $SelectedProvider.ProviderName
        }

        if($packageSource)
        {
            break
        }
    }

    # Poll other package provider when NuGet provider doesn't resolves the specified location
    if(-not $packageSource -and -not $IsProviderSpecified)
    {
        Write-Verbose ($LocalizedData.PollingPackageManagementProvidersForLocation -f $LocationString)

        $moduleProviders = $request.SelectProvidersWithFeature($script:SupportsPSModulesFeatureName)

        foreach($provider in $moduleProviders)
        {
            if($request.IsCanceled)
            {
                return
            }

            # Skip already tried $SpecifiedProviderName and PowerShellGet provider
            if($provider.ProviderName -eq $SpecifiedProviderName -or
               $provider.ProviderName -eq $script:PSModuleProviderName)
            {
                continue
            }

            Write-Verbose ($LocalizedData.PollingSingleProviderForLocation -f ($LocationString, $provider.ProviderName))
            $NewRequest = $request.CloneRequest( @{}, @($LocationString), $request.Credential )
            $packageSource = $provider.ResolvePackageSources($NewRequest)

            if($packageSource)
            {
                Write-Verbose ($LocalizedData.FoundProviderForLocation -f ($provider.ProviderName, $Location))
                $SelectedProvider = $provider
                break
            }
        }
    }

    if(-not $packageSource)
    {
        $message = $LocalizedData.SpecifiedLocationCannotBeRegistered -f $Location
        ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "SpecifiedLocationCannotBeRegistered" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $Location
    }

    $ProviderOptions = @{}

    $SelectedProvider.DynamicOptions | Microsoft.PowerShell.Core\ForEach-Object {
                                            if($options.ContainsKey($_.Name) )
                                            {
                                                $ProviderOptions[$_.Name] = $options[$_.Name]
                                            }
                                       }

    # Keep the existing provider options if not specified in Set-PSRepository
    if($currentSourceObject)
    {
        $currentSourceObject.ProviderOptions.GetEnumerator() | Microsoft.PowerShell.Core\ForEach-Object {
                                                                   if (-not $ProviderOptions.ContainsKey($_.Key) )
                                                                   {
                                                                       $ProviderOptions[$_.Key] = $_.Value
                                                                   }
                                                               }
    }

    if(-not $PublishLocation)
    {
        $PublishLocation = Get-PublishLocation -Location $LocationString
    }

    # Use the PublishLocation for the scripts when ScriptPublishLocation is not specified by the user
    if(-not $ScriptPublishLocation)
    {
        $ScriptPublishLocation = $PublishLocation

        # ScriptPublishLocation and PublishLocation should be equal in case of SMB Share or Local directory paths
        if($Options.ContainsKey($script:ScriptPublishLocation) -and
           (Microsoft.PowerShell.Management\Test-Path -LiteralPath $ScriptPublishLocation))
        {
            if($ScriptPublishLocation -ne $PublishLocation)
            {
                $message = $LocalizedData.PublishLocationPathsForModulesAndScriptsShouldBeEqual -f ($LocationString, $ScriptSourceLocation)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "PublishLocationPathsForModulesAndScriptsShouldBeEqual" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation `
                            -ExceptionObject $Location
            }
        }
    }

    if(-not $ScriptSourceLocation)
    {
        $ScriptSourceLocation = Get-ScriptSourceLocation -Location $LocationString -Proxy $Proxy -ProxyCredential $ProxyCredential -Credential $Credential
    }
    elseif($Options.ContainsKey($script:ScriptSourceLocation))
    {
        # ScriptSourceLocation and SourceLocation should be equal for SMB Share or Local directory paths
        if(Microsoft.PowerShell.Management\Test-Path -LiteralPath $ScriptSourceLocation)
        {
            if($ScriptSourceLocation -ne $LocationString)
            {
                $message = $LocalizedData.SourceLocationPathsForModulesAndScriptsShouldBeEqual -f ($LocationString, $ScriptSourceLocation)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "SourceLocationPathsForModulesAndScriptsShouldBeEqual" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation `
                            -ExceptionObject $Location
            }
        }
    }

    # no error so we can safely remove the source
    if($script:PSGetModuleSources.Contains($Name))
    {
        $null = $script:PSGetModuleSources.Remove($Name)
    }

    # Add new module source
    $moduleSource = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
            Name = $Name
            SourceLocation = $LocationString
            PublishLocation = $PublishLocation
            ScriptSourceLocation = $ScriptSourceLocation
            ScriptPublishLocation = $ScriptPublishLocation
            Trusted=$Trusted
            Registered= (-not $IsNewModuleSource)
            InstallationPolicy = if($Trusted) {'Trusted'} else {'Untrusted'}
            PackageManagementProvider = $SelectedProvider.ProviderName
            ProviderOptions = $ProviderOptions
        })

    #region telemetry - Capture non-PSGallery registrations as telemetry events
    if ($script:TelemetryEnabled)
    {

        Log-NonPSGalleryRegistration -sourceLocation $moduleSource.SourceLocation `
                                     -installationPolicy $moduleSource.InstallationPolicy `
                                     -packageManagementProvider $moduleSource.PackageManagementProvider `
                                     -publishLocation $moduleSource.PublishLocation `
                                     -scriptSourceLocation $moduleSource.ScriptSourceLocation `
                                     -scriptPublishLocation $moduleSource.ScriptPublishLocation `
                                     -operationName PSGET_NONPSGALLERY_REGISTRATION `
                                     -ErrorAction SilentlyContinue `
                                     -WarningAction SilentlyContinue

    }
    #endregion

    $moduleSource.PSTypeNames.Insert(0, "Microsoft.PowerShell.Commands.PSRepository")

    # Persist the repositories only when Register-PSRepository cmdlet is used
    if(-not $IsNewModuleSource)
    {
        $script:PSGetModuleSources.Add($Name, $moduleSource)

        $message = $LocalizedData.RepositoryRegistered -f ($Name, $LocationString)
        Write-Verbose $message

        # Persist the module sources
        Save-ModuleSources
    }

    # return the package source object.
    Write-Output -InputObject (New-PackageSourceFromModuleSource -ModuleSource $moduleSource)
}
function Download-Package
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FastPackageReference,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Location
    )

    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Download-Package'))

    Install-PackageUtility -FastPackageReference $FastPackageReference -Request $Request -Location $Location
}
function Find-Package
{
    [CmdletBinding()]
    param
    (
        [string[]]
        $names,

        [string]
        $requiredVersion,

        [string]
        $minimumVersion,

        [string]
        $maximumVersion
    )

    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Find-Package'))

    Set-ModuleSourcesVariable

    if($RequiredVersion -and $MinimumVersion)
    {
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $LocalizedData.VersionRangeAndRequiredVersionCannotBeSpecifiedTogether `
                   -ErrorId "VersionRangeAndRequiredVersionCannotBeSpecifiedTogether" `
                   -CallerPSCmdlet $PSCmdlet `
                   -ErrorCategory InvalidArgument
    }

    if($RequiredVersion -or $MinimumVersion)
    {
        if(-not $names -or $names.Count -ne 1 -or (Test-WildcardPattern -Name $names[0]))
        {
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $LocalizedData.VersionParametersAreAllowedOnlyWithSingleName `
                       -ErrorId "VersionParametersAreAllowedOnlyWithSingleName" `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument
        }
    }

    $options = $request.Options

    foreach( $o in $options.Keys )
    {
        Write-Debug ( "OPTION: {0} => {1}" -f ($o, $options[$o]) )
    }

	# When using -Name, we don't send PSGet-specific properties to the server - we will filter it ourselves
	$postFilter = New-Object -TypeName  System.Collections.Hashtable
	if($options.ContainsKey("Name"))
	{
		if($options.ContainsKey("Includes"))
		{
			$postFilter["Includes"] = $options["Includes"]
			$null = $options.Remove("Includes")
		}

		if($options.ContainsKey("DscResource"))
		{
			$postFilter["DscResource"] = $options["DscResource"]
			$null = $options.Remove("DscResource")
		}

		if($options.ContainsKey('RoleCapability'))
		{
			$postFilter['RoleCapability'] = $options['RoleCapability']
			$null = $options.Remove('RoleCapability')
		}

		if($options.ContainsKey("Command"))
		{
			$postFilter["Command"] = $options["Command"]
			$null = $options.Remove("Command")
		}
	}

    $LocationOGPHashtable = [ordered]@{}
    if($options -and $options.ContainsKey('Source'))
    {
        $SourceNames = $($options['Source'])

        Write-Verbose ($LocalizedData.SpecifiedSourceName -f ($SourceNames))

        foreach($sourceName in $SourceNames)
        {
            if($script:PSGetModuleSources.Contains($sourceName))
            {
                $ModuleSource = $script:PSGetModuleSources[$sourceName]
                $LocationOGPHashtable[$ModuleSource.SourceLocation] = (Get-ProviderName -PSCustomObject $ModuleSource)
            }
            else
            {
                $sourceByLocation = Get-SourceName -Location $sourceName

                if ($sourceByLocation)
                {
                    $ModuleSource = $script:PSGetModuleSources[$sourceByLocation]
                    $LocationOGPHashtable[$ModuleSource.SourceLocation] = (Get-ProviderName -PSCustomObject $ModuleSource)
                }
                else
                {
                    $message = $LocalizedData.RepositoryNotFound -f ($sourceName)
                    Write-Error -Message $message `
                                -ErrorId 'RepositoryNotFound' `
                                -Category InvalidArgument `
                                -TargetObject $sourceName
                }
            }
        }
    }
    elseif($options -and
           $options.ContainsKey($script:PackageManagementProviderParam) -and
           $options.ContainsKey('Location'))
    {
        $Location = $options['Location']
        $PackageManagementProvider = $options['PackageManagementProvider']

        Write-Verbose ($LocalizedData.SpecifiedLocationAndOGP -f ($Location, $PackageManagementProvider))

        $LocationOGPHashtable[$Location] = $PackageManagementProvider
    }
    else
    {
        Write-Verbose $LocalizedData.NoSourceNameIsSpecified

        $script:PSGetModuleSources.Values | Microsoft.PowerShell.Core\ForEach-Object { $LocationOGPHashtable[$_.SourceLocation] = (Get-ProviderName -PSCustomObject $_) }
    }

    $artifactTypes = $script:PSArtifactTypeModule
    if($options.ContainsKey($script:PSArtifactType))
    {
        $artifactTypes = $options[$script:PSArtifactType]
    }

    if($artifactTypes -eq $script:All)
    {
        $artifactTypes = @($script:PSArtifactTypeModule,$script:PSArtifactTypeScript)
    }

    $providerOptions = @{}

    if($options.ContainsKey($script:AllVersions))
    {
        $providerOptions[$script:AllVersions] = $options[$script:AllVersions]
    }

    if ($options.Contains($script:AllowPrereleaseVersions))
    {
        $providerOptions[$script:AllowPrereleaseVersions] = $options[$script:AllowPrereleaseVersions]
    }

    if($options.ContainsKey($script:Filter))
    {
        $Filter = $options[$script:Filter]
        $providerOptions['Contains'] = $Filter
    }

    if($options.ContainsKey($script:Tag))
    {
        $userSpecifiedTags = $options[$script:Tag] | Microsoft.PowerShell.Utility\Select-Object -Unique -ErrorAction Ignore
    }
    else
    {
        $userSpecifiedTags = @($script:NotSpecified)
    }

    $specifiedDscResources = @()
    if($options.ContainsKey('DscResource'))
    {
        $specifiedDscResources = $options['DscResource'] |
                                    Microsoft.PowerShell.Utility\Select-Object -Unique -ErrorAction Ignore |
                                        Microsoft.PowerShell.Core\ForEach-Object {"$($script:DscResource)_$_"}
    }

    $specifiedRoleCapabilities = @()
    if($options.ContainsKey('RoleCapability'))
    {
        $specifiedRoleCapabilities = $options['RoleCapability'] |
                                        Microsoft.PowerShell.Utility\Select-Object -Unique -ErrorAction Ignore |
                                            Microsoft.PowerShell.Core\ForEach-Object {"$($script:RoleCapability)_$_"}
    }

    $specifiedCommands = @()
    if($options.ContainsKey('Command'))
    {
        $specifiedCommands = $options['Command'] |
                                Microsoft.PowerShell.Utility\Select-Object -Unique -ErrorAction Ignore |
                                    Microsoft.PowerShell.Core\ForEach-Object {"$($script:Command)_$_"}
    }

    $specifiedIncludes = @()
    if($options.ContainsKey('Includes'))
    {
        $includes = $options['Includes'] |
                        Microsoft.PowerShell.Utility\Select-Object -Unique -ErrorAction Ignore |
                            Microsoft.PowerShell.Core\ForEach-Object {"$($script:Includes)_$_"}

        # Add PSIncludes_DscResource to $specifiedIncludes iff -DscResource names are not specified
        # Add PSIncludes_RoleCapability to $specifiedIncludes iff -RoleCapability names are not specified
        # Add PSIncludes_Cmdlet or PSIncludes_Function to $specifiedIncludes iff -Command names are not specified
        # otherwise $script:NotSpecified will be added to $specifiedIncludes
        if($includes)
        {
            if(-not $specifiedDscResources -and ($includes -contains "$($script:Includes)_DscResource") )
            {
               $specifiedIncludes += "$($script:Includes)_DscResource"
            }

            if(-not $specifiedRoleCapabilities -and ($includes -contains "$($script:Includes)_RoleCapability") )
            {
               $specifiedIncludes += "$($script:Includes)_RoleCapability"
            }

            if(-not $specifiedCommands)
            {
               if($includes -contains "$($script:Includes)_Cmdlet")
               {
                   $specifiedIncludes += "$($script:Includes)_Cmdlet"
               }

               if($includes -contains "$($script:Includes)_Function")
               {
                   $specifiedIncludes += "$($script:Includes)_Function"
               }

               if($includes -contains "$($script:Includes)_Workflow")
               {
                   $specifiedIncludes += "$($script:Includes)_Workflow"
               }
            }
        }
    }

    if(-not $specifiedDscResources)
    {
        $specifiedDscResources += $script:NotSpecified
    }

    if(-not $specifiedRoleCapabilities)
    {
        $specifiedRoleCapabilities += $script:NotSpecified
    }

    if(-not $specifiedCommands)
    {
        $specifiedCommands += $script:NotSpecified
    }

    if(-not $specifiedIncludes)
    {
        $specifiedIncludes += $script:NotSpecified
    }

    $providerSearchTags = @{}

    foreach($tag in $userSpecifiedTags)
    {
        foreach($include in $specifiedIncludes)
        {
            foreach($command in $specifiedCommands)
            {
                foreach($resource in $specifiedDscResources)
                {
                    foreach($roleCapability in $specifiedRoleCapabilities)
                    {
                        $providerTags = @()
                        if($resource -ne $script:NotSpecified)
                        {
                            $providerTags += $resource
                        }

                        if($roleCapability -ne $script:NotSpecified)
                        {
                            $providerTags += $roleCapability
                        }

                        if($command -ne $script:NotSpecified)
                        {
                            $providerTags += $command
                        }

                        if($include -ne $script:NotSpecified)
                        {
                            $providerTags += $include
                        }

                        if($tag -ne $script:NotSpecified)
                        {
                            $providerTags += $tag
                        }

                        if($providerTags)
                        {
                            $providerSearchTags["$tag $resource $roleCapability $command $include"] = $providerTags
                        }
                    }
                }
            }
        }
    }

    $InstallationPolicy = "Untrusted"
    if($options.ContainsKey('InstallationPolicy'))
    {
        $InstallationPolicy = $options['InstallationPolicy']
    }

    $streamedResults = @()

    foreach($artifactType in $artifactTypes)
    {
        foreach($kvPair in $LocationOGPHashtable.GetEnumerator())
        {
            if($request.IsCanceled)
            {
                return
            }

            $Location = $kvPair.Key
            if($artifactType -eq $script:PSArtifactTypeScript)
            {
                $sourceName = Get-SourceName -Location $Location

                if($SourceName)
                {
                    $ModuleSource = $script:PSGetModuleSources[$SourceName]

                    # Skip source if no ScriptSourceLocation is available.
                    if(-not $ModuleSource.ScriptSourceLocation)
                    {
                        if($options.ContainsKey('Source'))
                        {
                            $message = $LocalizedData.ScriptSourceLocationIsMissing -f ($ModuleSource.Name)
                            Write-Error -Message $message `
                                        -ErrorId 'ScriptSourceLocationIsMissing' `
                                        -Category InvalidArgument `
                                        -TargetObject $ModuleSource.Name
                        }

                        continue
                    }

                    $Location = $ModuleSource.ScriptSourceLocation
                }
            }

            $ProviderName = $kvPair.Value

            Write-Verbose ($LocalizedData.GettingPackageManagementProviderObject -f ($ProviderName))

	        $provider = $request.SelectProvider($ProviderName)

            if(-not $provider)
            {
                Write-Error -Message ($LocalizedData.PackageManagementProviderIsNotAvailable -f $ProviderName)

                Continue
            }

            Write-Verbose ($LocalizedData.SpecifiedLocationAndOGP -f ($Location, $provider.ProviderName))

            if($providerSearchTags.Values.Count)
            {
                $tagList = $providerSearchTags.Values
            }
            else
            {
                $tagList = @($script:NotSpecified)
            }

            $namesParameterEmpty = ($names.Count -eq 1) -and ($names[0] -eq '')

            foreach($providerTag in $tagList)
            {
                if($request.IsCanceled)
                {
                    return
                }

                $FilterOnTag = @()

                if($providerTag -ne $script:NotSpecified)
                {
                    $FilterOnTag = $providerTag
                }

                if(Microsoft.PowerShell.Management\Test-Path -Path $Location)
                {
                    if($artifactType -eq $script:PSArtifactTypeScript)
                    {
                        $FilterOnTag += 'PSScript'
                    }
                    elseif($artifactType -eq $script:PSArtifactTypeModule)
                    {
                        $FilterOnTag += 'PSModule'
                    }
                }

                if($FilterOnTag)
                {
                    $providerOptions["FilterOnTag"] = $FilterOnTag
                }
                elseif($providerOptions.ContainsKey('FilterOnTag'))
                {
                    $null = $providerOptions.Remove('FilterOnTag')
                }

                if($request.Options.ContainsKey($script:FindByCanonicalId))
                {
                    $providerOptions[$script:FindByCanonicalId] = $request.Options[$script:FindByCanonicalId]
                }

                $providerOptions["Headers"] = 'PSGalleryClientVersion=1.1'

                $NewRequest = $request.CloneRequest( $providerOptions, @($Location), $request.Credential )

                $pkgs = $provider.FindPackages($names,
                                               $requiredVersion,
                                               $minimumVersion,
                                               $maximumVersion,
                                               $NewRequest )

                foreach($pkg in  $pkgs)
                {
                    if($request.IsCanceled)
                    {
                        return
                    }

                    # $pkg.Name has to match any of the supplied names, using PowerShell wildcards
                    if ($namesParameterEmpty -or ($names | Foreach-Object { if ($pkg.Name -like $_){return $true; break} } -End {return $false}))
                    {
						$includePackage = $true

						# If -Name was provided, we need to post-filter
						# Filtering has AND semantics between different parameters and OR within a parameter (each parameter is potentially an array)
						if($options.ContainsKey("Name") -and $postFilter.Count -gt 0)
						{
							if ($pkg.Metadata["DscResources"].Count -gt 0)
							{
								$pkgDscResources = $pkg.Metadata["DscResources"] -Split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
							}
							else
							{
								$pkgDscResources = $pkg.Metadata["tags"] -Split " " `
									| Microsoft.PowerShell.Core\Where-Object { $_.Trim() } `
									| Microsoft.PowerShell.Core\Where-Object { $_.StartsWith($script:DscResource, [System.StringComparison]::OrdinalIgnoreCase) } `
									| Microsoft.PowerShell.Core\ForEach-Object { $_.Substring($script:DscResource.Length + 1) }
							}

							if ($pkg.Metadata['RoleCapabilities'].Count -gt 0)
							{
								$pkgRoleCapabilities = $pkg.Metadata['RoleCapabilities'] -Split ' ' | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
							}
							else
							{
								$pkgRoleCapabilities = $pkg.Metadata["tags"] -Split ' ' `
									| Microsoft.PowerShell.Core\Where-Object { $_.Trim() } `
									| Microsoft.PowerShell.Core\Where-Object { $_.StartsWith($script:RoleCapability, [System.StringComparison]::OrdinalIgnoreCase) } `
									| Microsoft.PowerShell.Core\ForEach-Object { $_.Substring($script:RoleCapability.Length + 1) }
							}

							if ($pkg.Metadata["Functions"].Count -gt 0)
							{
								$pkgFunctions = $pkg.Metadata["Functions"] -Split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
							}
							else
							{
								$pkgFunctions = $pkg.Metadata["tags"] -Split " " `
									| Microsoft.PowerShell.Core\Where-Object { $_.Trim() } `
									| Microsoft.PowerShell.Core\Where-Object { $_.StartsWith($script:Function, [System.StringComparison]::OrdinalIgnoreCase) } `
									| Microsoft.PowerShell.Core\ForEach-Object { $_.Substring($script:Function.Length + 1) }
							}

							if ($pkg.Metadata["Cmdlets"].Count -gt 0)
							{
								$pkgCmdlets = $pkg.Metadata["Cmdlets"] -Split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
							}
							else
							{
								$pkgCmdlets = $pkg.Metadata["tags"] -Split " " `
									| Microsoft.PowerShell.Core\Where-Object { $_.Trim() } `
									| Microsoft.PowerShell.Core\Where-Object { $_.StartsWith($script:Cmdlet, [System.StringComparison]::OrdinalIgnoreCase) } `
									| Microsoft.PowerShell.Core\ForEach-Object { $_.Substring($script:Cmdlet.Length + 1) }
							}

							if ($pkg.Metadata["Workflows"].Count -gt 0)
							{
								$pkgWorkflows = $pkg.Metadata["Workflows"] -Split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
							}
							else
							{
								$pkgWorkflows = $pkg.Metadata["tags"] -Split " " `
									| Microsoft.PowerShell.Core\Where-Object { $_.Trim() } `
									| Microsoft.PowerShell.Core\Where-Object { $_.StartsWith($script:Workflow, [System.StringComparison]::OrdinalIgnoreCase) } `
									| Microsoft.PowerShell.Core\ForEach-Object { $_.Substring($script:Workflow.Length + 1) }
							}

							foreach ($key in $postFilter.Keys)
							{
								switch ($key)
								{
									"DscResource" {
										$values = $postFilter[$key]

										$includePackage = $false

										foreach ($value in $values)
										{
											$wildcardPattern = New-Object System.Management.Automation.WildcardPattern $value,$script:wildcardOptions

											$pkgDscResources | Microsoft.PowerShell.Core\ForEach-Object {
												if ($wildcardPattern.IsMatch($_))
												{
													$includePackage = $true
													break
												}
											}
										}

										if (-not $includePackage)
										{
											break
										}
									}

									'RoleCapability' {
										$values = $postFilter[$key]

										$includePackage = $false

										foreach ($value in $values)
										{
											$wildcardPattern = New-Object System.Management.Automation.WildcardPattern $value,$script:wildcardOptions

											$pkgRoleCapabilities | Microsoft.PowerShell.Core\ForEach-Object {
												if ($wildcardPattern.IsMatch($_))
												{
													$includePackage = $true
													break
												}
											}
										}

										if (-not $includePackage)
										{
											break
										}
									}

									"Command" {
										$values = $postFilter[$key]

										$includePackage = $false

										foreach ($value in $values)
										{
											$wildcardPattern = New-Object System.Management.Automation.WildcardPattern $value,$script:wildcardOptions

											$pkgFunctions | Microsoft.PowerShell.Core\ForEach-Object {
												if ($wildcardPattern.IsMatch($_))
												{
													$includePackage = $true
													break
												}
											}

											$pkgCmdlets | Microsoft.PowerShell.Core\ForEach-Object {
												if ($wildcardPattern.IsMatch($_))
												{
													$includePackage = $true
													break
												}
											}

											$pkgWorkflows | Microsoft.PowerShell.Core\ForEach-Object {
												if ($wildcardPattern.IsMatch($_))
												{
													$includePackage = $true
													break
												}
											}
										}

										if (-not $includePackage)
										{
											break
										}
									}

									"Includes" {
										$values = $postFilter[$key]

										$includePackage = $false

										foreach ($value in $values)
										{
											switch ($value)
											{
												"Cmdlet" { if ($pkgCmdlets ) { $includePackage = $true } }
												"Function" { if ($pkgFunctions ) { $includePackage = $true } }
												"DscResource" { if ($pkgDscResources ) { $includePackage = $true } }
												"RoleCapability" { if ($pkgRoleCapabilities ) { $includePackage = $true } }
												"Workflow" { if ($pkgWorkflows ) { $includePackage = $true } }
											}
										}

										if (-not $includePackage)
										{
											break
										}
									}
								}
							}
						}

						if ($includePackage)
						{
							$fastPackageReference = New-FastPackageReference -ProviderName $provider.ProviderName `
																			-PackageName $pkg.Name `
																			-Version $pkg.Version `
																			-Source $Location `
																			-ArtifactType $artifactType

							if($streamedResults -notcontains $fastPackageReference)
							{
								$streamedResults += $fastPackageReference

								$FromTrustedSource = $false

								$ModuleSourceName = Get-SourceName -Location $Location

								if($ModuleSourceName)
								{
									$FromTrustedSource = $script:PSGetModuleSources[$ModuleSourceName].Trusted
								}
								elseif($InstallationPolicy -eq "Trusted")
								{
									$FromTrustedSource = $true
								}

								$sid = New-SoftwareIdentityFromPackage -Package $pkg `
																	-PackageManagementProviderName $provider.ProviderName `
																	-SourceLocation $Location `
																	-IsFromTrustedSource:$FromTrustedSource `
																	-Type $artifactType `
																	-request $request

								$script:FastPackRefHashtable[$fastPackageReference] = $pkg

								Write-Output -InputObject $sid
							}
						}
                    }
                }
            }
        }
    }
}
function Get-DynamicOptions
{
    param
    (
        [Microsoft.PackageManagement.MetaProvider.PowerShell.OptionCategory]
        $category
    )

    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Get-DynamicOptions'))

    Write-Output -InputObject (New-DynamicOption -Category $category -Name $script:PackageManagementProviderParam -ExpectedType String -IsRequired $false)

    switch($category)
    {
        Package {
                    Write-Output -InputObject (New-DynamicOption -Category $category `
                                                                 -Name $script:PSArtifactType `
                                                                 -ExpectedType String `
                                                                 -IsRequired $false `
                                                                 -PermittedValues @($script:PSArtifactTypeModule,$script:PSArtifactTypeScript, $script:All))
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name $script:Filter -ExpectedType String -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name $script:Tag -ExpectedType StringArray -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name Includes -ExpectedType StringArray -IsRequired $false -PermittedValues $script:IncludeValidSet)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name DscResource -ExpectedType StringArray -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name RoleCapability -ExpectedType StringArray -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name 'AllowPrereleaseVersions' -ExpectedType Switch -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name Command -ExpectedType StringArray -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name 'AcceptLicense' -ExpectedType Switch -IsRequired $false)
                }

        Source  {
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name $script:PublishLocation -ExpectedType String -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name $script:ScriptSourceLocation -ExpectedType String -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name $script:ScriptPublishLocation -ExpectedType String -IsRequired $false)
                }

        Install
                {
                    Write-Output -InputObject (New-DynamicOption -Category $category `
                                                                 -Name $script:PSArtifactType `
                                                                 -ExpectedType String `
                                                                 -IsRequired $false `
                                                                 -PermittedValues @($script:PSArtifactTypeModule,$script:PSArtifactTypeScript, $script:All))
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name "Scope" -ExpectedType String -IsRequired $false -PermittedValues @("CurrentUser","AllUsers"))
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name 'AllowClobber' -ExpectedType Switch -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name 'SkipPublisherCheck' -ExpectedType Switch -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name "InstallUpdate" -ExpectedType Switch -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name 'NoPathUpdate' -ExpectedType Switch -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name 'AllowPrereleaseVersions' -ExpectedType Switch -IsRequired $false)
                }
    }
}
function Get-Feature
{
    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Get-Feature'))
    Write-Output -InputObject (New-Feature $script:SupportsPSModulesFeatureName )
}
function Get-InstalledPackage
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [string]
        $MinimumVersion,

        [Parameter()]
        [string]
        $MaximumVersion
    )

    Write-Debug -Message ($LocalizedData.ProviderApiDebugMessage -f ('Get-InstalledPackage'))

    $options = $request.Options

    foreach( $o in $options.Keys )
    {
        Write-Debug ( "OPTION: {0} => {1}" -f ($o, $options[$o]) )
    }

    $artifactTypes = $script:PSArtifactTypeModule
    if($options.ContainsKey($script:PSArtifactType))
    {
        $artifactTypes = $options[$script:PSArtifactType]
    }

    if($artifactTypes -eq $script:All)
    {
        $artifactTypes = @($script:PSArtifactTypeModule,$script:PSArtifactTypeScript)
    }

    if($artifactTypes -contains $script:PSArtifactTypeModule)
    {
        Get-InstalledModuleDetails -Name $Name `
                                   -RequiredVersion $RequiredVersion `
                                   -MinimumVersion $MinimumVersion `
                                   -MaximumVersion $MaximumVersion | Microsoft.PowerShell.Core\ForEach-Object {$_.SoftwareIdentity}
    }

    if($artifactTypes -contains $script:PSArtifactTypeScript)
    {
        Get-InstalledScriptDetails -Name $Name `
                                   -RequiredVersion $RequiredVersion `
                                   -MinimumVersion $MinimumVersion `
                                   -MaximumVersion $MaximumVersion | Microsoft.PowerShell.Core\ForEach-Object {$_.SoftwareIdentity}
    }
}
function Get-PackageProviderName
{
    return $script:PSModuleProviderName
}
function Initialize-Provider
{
    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Initialize-Provider'))
}
function Install-Package
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FastPackageReference
    )

    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Install-Package'))

    Install-PackageUtility -FastPackageReference $FastPackageReference -Request $Request
}
function Remove-PackageSource
{
    param
    (
        [string]
        $Name
    )

    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Remove-PackageSource'))

    Set-ModuleSourcesVariable -Force

    $ModuleSourcesToBeRemoved = @()

    foreach ($moduleSourceName in $Name)
    {
        if($request.IsCanceled)
        {
            return
        }

        # Check if $Name contains any wildcards
        if(Test-WildcardPattern $moduleSourceName)
        {
            $message = $LocalizedData.RepositoryNameContainsWildCards -f ($moduleSourceName)
            Write-Error -Message $message -ErrorId "RepositoryNameContainsWildCards" -Category InvalidOperation -TargetObject $moduleSourceName
            continue
        }

        # Check if the specified module source name is in the registered module sources
        if(-not $script:PSGetModuleSources.Contains($moduleSourceName))
        {
            $message = $LocalizedData.RepositoryNotFound -f ($moduleSourceName)
            Write-Error -Message $message -ErrorId "RepositoryNotFound" -Category InvalidOperation -TargetObject $moduleSourceName
            continue
        }

        $ModuleSourcesToBeRemoved += $moduleSourceName
        $message = $LocalizedData.RepositoryUnregistered -f ($moduleSourceName)
        Write-Verbose $message
    }

    # Remove the module source
    $ModuleSourcesToBeRemoved | Microsoft.PowerShell.Core\ForEach-Object { $null = $script:PSGetModuleSources.Remove($_) }

    # Persist the module sources
    Save-ModuleSources
}
function Resolve-PackageSource
{
    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Resolve-PackageSource'))

    Set-ModuleSourcesVariable

    $SourceName = $request.PackageSources

    if(-not $SourceName)
    {
        $SourceName = "*"
    }

    foreach($moduleSourceName in $SourceName)
    {
        if($request.IsCanceled)
        {
            return
        }

        $wildcardPattern = New-Object System.Management.Automation.WildcardPattern $moduleSourceName,$script:wildcardOptions
        $moduleSourceFound = $false

        $script:PSGetModuleSources.GetEnumerator() |
            Microsoft.PowerShell.Core\Where-Object {$wildcardPattern.IsMatch($_.Key)} |
                Microsoft.PowerShell.Core\ForEach-Object {

                    $moduleSource = $script:PSGetModuleSources[$_.Key]

                    $packageSource = New-PackageSourceFromModuleSource -ModuleSource $moduleSource

                    Write-Output -InputObject $packageSource

                    $moduleSourceFound = $true
                }

        if(-not $moduleSourceFound)
        {
            $sourceName  = Get-SourceName -Location $moduleSourceName

            if($sourceName)
            {
                $moduleSource = $script:PSGetModuleSources[$sourceName]

                $packageSource = New-PackageSourceFromModuleSource -ModuleSource $moduleSource

                Write-Output -InputObject $packageSource
            }
            elseif( -not (Test-WildcardPattern $moduleSourceName))
            {
                $message = $LocalizedData.RepositoryNotFound -f ($moduleSourceName)

                Write-Error -Message $message -ErrorId "RepositoryNotFound" -Category InvalidOperation -TargetObject $moduleSourceName
            }
        }
    }
}
function Uninstall-Package
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $fastPackageReference
    )

    Write-Debug -Message ($LocalizedData.ProviderApiDebugMessage -f ('Uninstall-Package'))

    Write-Debug -Message ($LocalizedData.FastPackageReference -f $fastPackageReference)

    # take the fastPackageReference and get the package object again.
    $parts = $fastPackageReference -Split '[|]'
    $Force = $false

    $options = $request.Options
    if($options)
    {
        foreach( $o in $options.Keys )
        {
            Write-Debug -Message ("OPTION: {0} => {1}" -f ($o, $request.Options[$o]) )
        }
    }

    if($parts.Length -eq 5)
    {
        $providerName = $parts[0]
        $packageName = $parts[1]
        $version = $parts[2]
        $sourceLocation= $parts[3]
        $artifactType = $parts[4]

        if($request.IsCanceled)
        {
            return
        }

        if($options.ContainsKey('Force'))
        {
            $Force = $options['Force']

            if($Force.GetType().ToString() -eq 'System.String')
            {
                if($Force -eq 'false')
                {
                    $Force = $false
                }
                elseif($Force -eq 'true')
                {
                    $Force = $true
                }
            }
        }

        if($artifactType -eq $script:PSArtifactTypeModule)
        {
            $moduleName = $packageName
            $InstalledModuleInfo = $script:PSGetInstalledModules["$($moduleName)$($version)"]

            if(-not $InstalledModuleInfo)
            {
                $message = $LocalizedData.ModuleUninstallationNotPossibleAsItIsNotInstalledUsingPowerShellGet -f $moduleName

                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "ModuleUninstallationNotPossibleAsItIsNotInstalledUsingPowerShellGet" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument

                return
            }

            $moduleBase = $InstalledModuleInfo.PSGetItemInfo.InstalledLocation

            if(-not (Test-RunningAsElevated) -and $moduleBase.StartsWith($script:programFilesModulesPath, [System.StringComparison]::OrdinalIgnoreCase))
            {
                $message = $LocalizedData.AdminPrivilegesRequiredForUninstall -f ($moduleName, $moduleBase)

                ThrowError -ExceptionName "System.InvalidOperationException" `
                           -ExceptionMessage $message `
                           -ErrorId "AdminPrivilegesRequiredForUninstall" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation

                return
            }

            $dependentModuleScript = {
                                param ([string] $moduleName)
                                Microsoft.PowerShell.Core\Get-Module -ListAvailable |
                                Microsoft.PowerShell.Core\Where-Object {
                                    ($moduleName -ne $_.Name) -and (
                                    ($_.RequiredModules -and $_.RequiredModules.Name -contains $moduleName) -or
                                    ($_.NestedModules -and $_.NestedModules.Name -contains $moduleName))
                                }
                            }
            $dependentModulesJob =  Microsoft.PowerShell.Core\Start-Job -ScriptBlock $dependentModuleScript -ArgumentList $moduleName
            Microsoft.PowerShell.Core\Wait-Job -job $dependentModulesJob
            $dependentModules = Microsoft.PowerShell.Core\Receive-Job -job $dependentModulesJob -ErrorAction Ignore

            if(-not $Force -and $dependentModules)
            {
                $message = $LocalizedData.UnableToUninstallAsOtherModulesNeedThisModule -f ($moduleName, $version, $moduleBase, $(($dependentModules.Name | Select-Object -Unique -ErrorAction Ignore) -join ','), $moduleName)

                ThrowError -ExceptionName "System.InvalidOperationException" `
                           -ExceptionMessage $message `
                           -ErrorId "UnableToUninstallAsOtherModulesNeedThisModule" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation

                return
            }

            $moduleInUse = Test-ModuleInUse -ModuleBasePath $moduleBase `
                                            -ModuleName $InstalledModuleInfo.PSGetItemInfo.Name`
                                            -ModuleVersion $InstalledModuleInfo.PSGetItemInfo.Version `
                                            -Verbose:$VerbosePreference `
                                            -WarningAction $WarningPreference `
                                            -ErrorAction $ErrorActionPreference `
                                            -Debug:$DebugPreference

            if($moduleInUse)
            {
                $message = $LocalizedData.ModuleIsInUse -f ($moduleName)

                ThrowError -ExceptionName "System.InvalidOperationException" `
                           -ExceptionMessage $message `
                           -ErrorId "ModuleIsInUse" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation

                return
            }

            $ModuleBaseFolderToBeRemoved = $moduleBase

            # With SxS version support, more than one version of the module can be installed.
            # - Remove the parent directory of the module version base when only one version is installed
            # - Don't remove the modulebase when it was installed before SxS version support and
            #   other versions are installed under the module base folder
            #
            if(Test-ModuleSxSVersionSupport)
            {
                $ModuleBaseWithoutVersion = $moduleBase
                $IsModuleInstalledAsSxSVersion = $false

                if($moduleBase.EndsWith("$version", [System.StringComparison]::OrdinalIgnoreCase))
                {
                    $IsModuleInstalledAsSxSVersion = $true
                    $ModuleBaseWithoutVersion = Microsoft.PowerShell.Management\Split-Path -Path $moduleBase -Parent
                }

                $InstalledVersionsWithSameModuleBase = @()
                Get-Module -Name $moduleName -ListAvailable |
                    Microsoft.PowerShell.Core\ForEach-Object {
                        if($_.ModuleBase.StartsWith($ModuleBaseWithoutVersion, [System.StringComparison]::OrdinalIgnoreCase))
                        {
                            $InstalledVersionsWithSameModuleBase += $_.ModuleBase
                        }
                    }

                # Remove ..\ModuleName directory when only one module is installed with the same ..\ModuleName path
                # like ..\ModuleName\1.0 or ..\ModuleName
                if($InstalledVersionsWithSameModuleBase.Count -eq 1)
                {
                    $ModuleBaseFolderToBeRemoved = $ModuleBaseWithoutVersion
                }
                elseif($ModuleBaseWithoutVersion -eq $moduleBase)
                {
                    # There are version specific folders under the same module base dir
                    # Throw an error saying uninstall other versions then uninstall this current version
                    $message = $LocalizedData.UnableToUninstallModuleVersion -f ($moduleName, $version, $moduleBase)

                    ThrowError -ExceptionName "System.InvalidOperationException" `
                               -ExceptionMessage $message `
                               -ErrorId "UnableToUninstallModuleVersion" `
                               -CallerPSCmdlet $PSCmdlet `
                               -ErrorCategory InvalidOperation

                    return
                }
                # Otherwise specified version folder will be removed as current module base is assigned to $ModuleBaseFolderToBeRemoved
            }

            Microsoft.PowerShell.Management\Remove-Item -Path $ModuleBaseFolderToBeRemoved `
                                                        -Force -Recurse `
                                                        -ErrorAction SilentlyContinue `
                                                        -WarningAction SilentlyContinue `
                                                        -Confirm:$false -WhatIf:$false

            $message = $LocalizedData.ModuleUninstallationSucceeded -f $moduleName, $moduleBase
            Write-Verbose  $message

            Write-Output -InputObject $InstalledModuleInfo.SoftwareIdentity
        }
        elseif($artifactType -eq $script:PSArtifactTypeScript)
        {
            $scriptName = $packageName
            $InstalledScriptInfo = $script:PSGetInstalledScripts["$($scriptName)$($version)"]

            if(-not $InstalledScriptInfo)
            {
                $message = $LocalizedData.ScriptUninstallationNotPossibleAsItIsNotInstalledUsingPowerShellGet -f $scriptName
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "ScriptUninstallationNotPossibleAsItIsNotInstalledUsingPowerShellGet" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument

                return
            }

            $scriptBase = $InstalledScriptInfo.PSGetItemInfo.InstalledLocation
            $installedScriptInfoPath = $script:MyDocumentsInstalledScriptInfosPath

            if($scriptBase.StartsWith($script:ProgramFilesScriptsPath, [System.StringComparison]::OrdinalIgnoreCase))
            {
                if(-not (Test-RunningAsElevated))
                {
                    $message = $LocalizedData.AdminPrivilegesRequiredForScriptUninstall -f ($scriptName, $scriptBase)

                    ThrowError -ExceptionName "System.InvalidOperationException" `
                               -ExceptionMessage $message `
                               -ErrorId "AdminPrivilegesRequiredForUninstall" `
                               -CallerPSCmdlet $PSCmdlet `
                               -ErrorCategory InvalidOperation

                    return
                }

                $installedScriptInfoPath = $script:ProgramFilesInstalledScriptInfosPath
            }

            # Check if there are any dependent scripts
            $dependentScriptDetails = $script:PSGetInstalledScripts.Values |
                                          Microsoft.PowerShell.Core\Where-Object {
                                              $_.PSGetItemInfo.Dependencies -contains $scriptName
                                          }

            $dependentScriptNames = $dependentScriptDetails |
                                        Microsoft.PowerShell.Core\ForEach-Object { $_.PSGetItemInfo.Name }

            if(-not $Force -and $dependentScriptNames)
            {
                $message = $LocalizedData.UnableToUninstallAsOtherScriptsNeedThisScript -f
                               ($scriptName,
                                $version,
                                $scriptBase,
                                $(($dependentScriptNames | Select-Object -Unique -ErrorAction Ignore) -join ','),
                                $scriptName)

                ThrowError -ExceptionName 'System.InvalidOperationException' `
                           -ExceptionMessage $message `
                           -ErrorId 'UnableToUninstallAsOtherScriptsNeedThisScript' `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation
                return
            }

            $scriptFilePath = Microsoft.PowerShell.Management\Join-Path -Path $scriptBase `
                                                                        -ChildPath "$($scriptName).ps1"

            $installedScriptInfoFilePath = Microsoft.PowerShell.Management\Join-Path -Path $installedScriptInfoPath `
                                                                                      -ChildPath "$($scriptName)_$($script:InstalledScriptInfoFileName)"

            # Remove the script file and it's corresponding InstalledScriptInfo.xml
            if(Microsoft.PowerShell.Management\Test-Path -Path $scriptFilePath -PathType Leaf)
            {
                Microsoft.PowerShell.Management\Remove-Item -Path $scriptFilePath `
                                                            -Force `
                                                            -ErrorAction SilentlyContinue `
                                                            -WarningAction SilentlyContinue `
                                                            -Confirm:$false -WhatIf:$false
            }

            if(Microsoft.PowerShell.Management\Test-Path -Path $installedScriptInfoFilePath -PathType Leaf)
            {
                Microsoft.PowerShell.Management\Remove-Item -Path $installedScriptInfoFilePath `
                                                            -Force `
                                                            -ErrorAction SilentlyContinue `
                                                            -WarningAction SilentlyContinue `
                                                            -Confirm:$false -WhatIf:$false
            }

            $message = $LocalizedData.ScriptUninstallationSucceeded -f $scriptName, $scriptBase
            Write-Verbose $message

            Write-Output -InputObject $InstalledScriptInfo.SoftwareIdentity
        }
    }
}

#endregion

Export-ModuleMember -Function Add-PackageSource,Download-Package,Find-Package,Get-DynamicOptions,Get-Feature,Get-InstalledPackage,Get-PackageProviderName,Initialize-Provider,Install-Package,Remove-PackageSource,Resolve-PackageSource,Uninstall-Package,Find-Command,Find-DSCResource,Find-Module,Find-RoleCapability,Find-Script,Get-CredsFromCredentialProvider,Get-InstalledModule,Get-InstalledScript,Get-PSRepository,Install-Module,Install-Script,New-ScriptFileInfo,Publish-Module,Publish-Script,Register-PSRepository,Save-Module,Save-Script,Set-PSRepository,Test-ScriptFileInfo,Uninstall-Module,Uninstall-Script,Unregister-PSRepository,Update-Module,Update-ModuleManifest,Update-Script,Update-ScriptFileInfo

# Create install locations for scripts if they are not already created
if (-not (Microsoft.PowerShell.Management\Test-Path -Path $script:ProgramFilesInstalledScriptInfosPath) -and (Test-RunningAsElevated)) {
    $ev = $null
    $null = Microsoft.PowerShell.Management\New-Item -Path $script:ProgramFilesInstalledScriptInfosPath `
        -ItemType Directory `
        -Force `
        -ErrorVariable ev `
        -ErrorAction SilentlyContinue `
        -WarningAction SilentlyContinue `
        -Confirm:$false `
        -WhatIf:$false

    if ($ev) {
        $script:IsRunningAsElevated = $false
    }
}

if (-not (Microsoft.PowerShell.Management\Test-Path -Path $script:MyDocumentsInstalledScriptInfosPath)) {
    $null = Microsoft.PowerShell.Management\New-Item -Path $script:MyDocumentsInstalledScriptInfosPath `
        -ItemType Directory `
        -Force `
        -Confirm:$false `
        -WhatIf:$false
}

# allow -repository params to be tab-completed
$commandsWithRepositoryParameter = @(
    "Find-Command"
    "Find-DscResource"
    "Find-Module"
    "Find-RoleCapability"
    "Find-Script"
    "Install-Module"
    "Install-Script"
    "Publish-Module"
    "Publish-Script"
    "Save-Module"
    "Save-Script")

$commandsWithRepositoryAsName = @(
    "Get-PSRepository",
    "Register-PSRepository"
    "Unregister-PSRepository"
)

Add-ArgumentCompleter -Cmdlets $commandsWithRepositoryParameter -ParameterName "Repository"
Add-ArgumentCompleter -Cmdlets $commandsWithRepositoryAsName -ParameterName "Name"

try {
    if (Get-Command -Name Register-ArgumentCompleter -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -CommandName Publish-Module -ParameterName Name -ScriptBlock {
            param ($commandName, $parameterName, $wordToComplete)

            Get-Module -Name $wordToComplete* -ListAvailable -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Foreach-Object {
                [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Name)
            }
        }
    }
}
catch {
    # All this functionality is optional, so suppress errors
    Write-Debug -Message "Error registering argument completer: $_"
}

Set-Alias -Name fimo -Value Find-Module
Set-Alias -Name inmo -Value Install-Module
Set-Alias -Name upmo -Value Update-Module
Set-Alias -Name pumo -Value Publish-Module
Set-Alias -Name uimo -Value Uninstall-Module

Export-ModuleMember -Alias fimo, inmo, upmo, pumo, uimo -Variable PSGetPath

# SIG # Begin signature block
# MIIkXAYJKoZIhvcNAQcCoIIkTTCCJEkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCACUCBRlNMtVGiZ
# iEkp0JUj5G63RdmMm+kCM/yx36cKZ6CCDYUwggYDMIID66ADAgECAhMzAAABUptA
# n1BWmXWIAAAAAAFSMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTkwNTAyMjEzNzQ2WhcNMjAwNTAyMjEzNzQ2WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCxp4nT9qfu9O10iJyewYXHlN+WEh79Noor9nhM6enUNbCbhX9vS+8c/3eIVazS
# YnVBTqLzW7xWN1bCcItDbsEzKEE2BswSun7J9xCaLwcGHKFr+qWUlz7hh9RcmjYS
# kOGNybOfrgj3sm0DStoK8ljwEyUVeRfMHx9E/7Ca/OEq2cXBT3L0fVnlEkfal310
# EFCLDo2BrE35NGRjG+/nnZiqKqEh5lWNk33JV8/I0fIcUKrLEmUGrv0CgC7w2cjm
# bBhBIJ+0KzSnSWingXol/3iUdBBy4QQNH767kYGunJeY08RjHMIgjJCdAoEM+2mX
# v1phaV7j+M3dNzZ/cdsz3oDfAgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQU3f8Aw1sW72WcJ2bo/QSYGzVrRYcw
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzQ1NDEzNjAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AJTwROaHvogXgixWjyjvLfiRgqI2QK8GoG23eqAgNjX7V/WdUWBbs0aIC3k49cd0
# zdq+JJImixcX6UOTpz2LZPFSh23l0/Mo35wG7JXUxgO0U+5drbQht5xoMl1n7/TQ
# 4iKcmAYSAPxTq5lFnoV2+fAeljVA7O43szjs7LR09D0wFHwzZco/iE8Hlakl23ZT
# 7FnB5AfU2hwfv87y3q3a5qFiugSykILpK0/vqnlEVB0KAdQVzYULQ/U4eFEjnis3
# Js9UrAvtIhIs26445Rj3UP6U4GgOjgQonlRA+mDlsh78wFSGbASIvK+fkONUhvj8
# B8ZHNn4TFfnct+a0ZueY4f6aRPxr8beNSUKn7QW/FQmn422bE7KfnqWncsH7vbNh
# G929prVHPsaa7J22i9wyHj7m0oATXJ+YjfyoEAtd5/NyIYaE4Uu0j1EhuYUo5VaJ
# JnMaTER0qX8+/YZRWrFN/heps41XNVjiAawpbAa0fUa3R9RNBjPiBnM0gvNPorM4
# dsV2VJ8GluIQOrJlOvuCrOYDGirGnadOmQ21wPBoGFCWpK56PxzliKsy5NNmAXcE
# x7Qb9vUjY1WlYtrdwOXTpxN4slzIht69BaZlLIjLVWwqIfuNrhHKNDM9K+v7vgrI
# bf7l5/665g0gjQCDCN6Q5sxuttTAEKtJeS/pkpI+DbZ/MIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCFi0wghYpAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAAFSm0CfUFaZdYgAAAAA
# AVIwDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIB7C
# i0xlnywoW5QWSaHp7WP943aKE7ZeefU2CeheJbRFMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEALstZt9xeHbCoWBHsVLSzYMvLvyNddsge+DU5
# HUtUXf4wCV4X4j1dOSVpd7lq2uVCQxTsb6j2easA1tveeVmuRV85rfCB996IUv6c
# QVrugLc9UuOKiM4sUckUlsoij209OAj1S+Fx1ERg/oE9L1m2HdKZUrWHSWhjxsOG
# byoBieTwpuW0sjwJPdCkglggrq4IgP3jqbOab1tWXI4sKAh5XnFKP5qz4uQXbo0X
# 4Z4IdNIcsxDOHZjDYkQs29sTdguQxbt91MQBhVKg00iP97om0zOCw+9tKsQGNj5S
# mkpQEvfWy2cNIG1g1r7mKEQ1WyiogmmMCHqru83ig5tZnH4IIqGCE7cwghOzBgor
# BgEEAYI3AwMBMYITozCCE58GCSqGSIb3DQEHAqCCE5AwghOMAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFYBgsqhkiG9w0BCRABBKCCAUcEggFDMIIBPwIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCBY8QpEnpgRfU/TVMKdbNxV/qXkafzpkkWz
# BHnL7zMGOQIGXfpkHKHNGBMyMDE5MTIyMzIwMDMwNi41NjdaMAcCAQGAAgH0oIHU
# pIHRMIHOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYD
# VQQLEyBNaWNyb3NvZnQgT3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMd
# VGhhbGVzIFRTUyBFU046NzI4RC1DNDVGLUY5RUIxJTAjBgNVBAMTHE1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFNlcnZpY2Wggg8fMIIE9TCCA92gAwIBAgITMwAAAQQJAXUI
# WIctKQAAAAABBDANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0EgMjAxMDAeFw0xOTA5MDYyMDQxMThaFw0yMDEyMDQyMDQxMThaMIHOMQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNyb3Nv
# ZnQgT3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046NzI4RC1DNDVGLUY5RUIxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFNlcnZpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDILQegEboY
# ZpaU4WD8FoJrTtqDVU02ch4GEAXNxh/ydcOm4YE3IKTYmZxmXtpL9QG8oOwAUj+n
# pIKUYVqQcseYDnjsaZZT15AsaYjJShRcfvkZ8YNDdWBTdmgLFY/RkTFnN0eoTyrY
# BTB11Cz8Y4t37ug04I3zotqYoea/zvnKdTovCr3U/vKeSZUTpNf/OZ7E4IBPNArn
# T/zYboiK0r5gzSlZjjBd2n1FlLMFT+r+rfXBo0lhtxjBjWXvBQd1VTi/qTbQm0Vf
# N6oULZMiMgPB7xmnIgH612Yv0A+Qv7yu13L6Hh24s4e4+ZV1A9z4h9H36h7zKefJ
# bFPwI6aq+WRnAgMBAAGjggEbMIIBFzAdBgNVHQ4EFgQUmNVe38JEGg4XAYvxmdPD
# IrDomuowHwYDVR0jBBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8w
# TTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVj
# dHMvTWljVGltU3RhUENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBK
# BggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9N
# aWNUaW1TdGFQQ0FfMjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUE
# DDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOCAQEAPRXUs3dpfDQDF9e0RXli
# 4TqpzgIMlyIx/LXVtcgPeGXc8p/DXrpHI8iC+/z5I/EeyhLRFC9HH0Z3bOiiE2jw
# V8ZaLM9YvpDIX3eneJEoJz1ptKqANeH6sSVDOj+X2X1kRlK7ZDSYWujfCHdQorso
# m6uytNxJ0y4JYtxF9S15cwTsssozN4QxlcYD5PQ+wcOYpIFY7vmKpfrV444Bv6Bc
# Plib8ATe2Lp2kVdOiSmcLGBj7DmANasnPFVwaMnihhSoSNqE4U/z+yDN4QsSzXOH
# 4sd7C2inuDWbWtK43bLGPCs/meLK/E/XWl0hWu5FKSlcOdu+/tEBQnOm5Kx45Sgf
# 5TCCBnEwggRZoAMCAQICCmEJgSoAAAAAAAIwDQYJKoZIhvcNAQELBQAwgYgxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jv
# c29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTEwMDcwMTIx
# MzY1NVoXDTI1MDcwMTIxNDY1NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTAwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCpHQ28dxGKOiDs/BOX
# 9fp/aZRrdFQQ1aUKAIKF++18aEssX8XD5WHCdrc+Zitb8BVTJwQxH0EbGpUdzgkT
# jnxhMFmxMEQP8WCIhFRDDNdNuDgIs0Ldk6zWczBXJoKjRQ3Q6vVHgc2/JGAyWGBG
# 8lhHhjKEHnRhZ5FfgVSxz5NMksHEpl3RYRNuKMYa+YaAu99h/EbBJx0kZxJyGiGK
# r0tkiVBisV39dx898Fd1rL2KQk1AUdEPnAY+Z3/1ZsADlkR+79BL/W7lmsqxqPJ6
# Kgox8NpOBpG2iAg16HgcsOmZzTznL0S6p/TcZL2kAcEgCZN4zfy8wMlEXV4WnAEF
# TyJNAgMBAAGjggHmMIIB4jAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU1WM6
# XIoxkPNDe3xGG8UzaFqFbVUwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYD
# VR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxi
# aNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3Nv
# ZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMu
# Y3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNy
# b3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQw
# gaAGA1UdIAEB/wSBlTCBkjCBjwYJKwYBBAGCNy4DMIGBMD0GCCsGAQUFBwIBFjFo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vUEtJL2RvY3MvQ1BTL2RlZmF1bHQuaHRt
# MEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAFAAbwBsAGkAYwB5AF8AUwB0
# AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQAH5ohRDeLG4Jg/
# gXEDPZ2joSFvs+umzPUxvs8F4qn++ldtGTCzwsVmyWrf9efweL3HqJ4l4/m87WtU
# VwgrUYJEEvu5U4zM9GASinbMQEBBm9xcF/9c+V4XNZgkVkt070IQyK+/f8Z/8jd9
# Wj8c8pl5SpFSAK84Dxf1L3mBZdmptWvkx872ynoAb0swRCQiPM/tA6WWj1kpvLb9
# BOFwnzJKJ/1Vry/+tuWOM7tiX5rbV0Dp8c6ZZpCM/2pif93FSguRJuI57BlKcWOd
# eyFtw5yjojz6f32WapB4pm3S4Zz5Hfw42JT0xqUKloakvZ4argRCg7i1gJsiOCC1
# JeVk7Pf0v35jWSUPei45V3aicaoGig+JFrphpxHLmtgOR5qAxdDNp9DvfYPw4Ttx
# Cd9ddJgiCGHasFAeb73x4QDf5zEHpJM692VHeOj4qEir995yfmFrb3epgcunCaw5
# u+zGy9iCtHLNHfS4hQEegPsbiSpUObJb2sgNVZl6h3M7COaYLeqN4DMuEin1wC9U
# JyH3yKxO2ii4sanblrKnQqLJzxlBTeCG+SqaoxFmMNO7dDJL32N79ZmKLxvHIa9Z
# ta7cRDyXUHHXodLFVeNp3lfB0d4wwP3M5k37Db9dT+mdHhk4L7zPWAUu7w2gUDXa
# 7wknHNWzfjUeCLraNtvTX4/edIhJEqGCA60wggKVAgEBMIH+oYHUpIHRMIHOMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNy
# b3NvZnQgT3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhhbGVzIFRT
# UyBFU046NzI4RC1DNDVGLUY5RUIxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2WiJQoBATAJBgUrDgMCGgUAAxUAs0Yef0dI8yhMiFS2cxh4FtwV
# Cn2ggd4wgdukgdgwgdUxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMScw
# JQYDVQQLEx5uQ2lwaGVyIE5UUyBFU046NERFOS0wQzVFLTNFMDkxKzApBgNVBAMT
# Ik1pY3Jvc29mdCBUaW1lIFNvdXJjZSBNYXN0ZXIgQ2xvY2swDQYJKoZIhvcNAQEF
# BQACBQDhq3BDMCIYDzIwMTkxMjI0MDA1NjM1WhgPMjAxOTEyMjUwMDU2MzVaMHQw
# OgYKKwYBBAGEWQoEATEsMCowCgIFAOGrcEMCAQAwBwIBAAICA5IwBwIBAAICFtww
# CgIFAOGswcMCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAaAKMAgC
# AQACAxbjYKEKMAgCAQACAwehIDANBgkqhkiG9w0BAQUFAAOCAQEAc9SQ2qWX1xyH
# t68Vm/IzK72Rcrqj6+aIayfvexDP3ItvoP2eqzSonFL8sQmeEfZNeOiIg3hmYMHM
# FTjw99PAuLsY9+ViRKFTIooG8wkWQZMsNPO0qThMQij8V93mBZBA2+WZsgw7wVe+
# WoziuR+Lzry5VS/czQbQQSTZIzb2h9HLBLisxfAjN9MLlvbFTps/RaQfsDjdlu89
# f49lRruJNodhd7uTpK7qdKsWmDwU9f1FOvsBZY5XGJwKhNdYZ+k0NUA+sWHQ7glx
# a7XfVVALpnm6nMxUrxReXCn1mInRO3q71we4azz//RybN/JjENJ7L2cpUB6RAF/h
# /0BWEjLB+zGCAvUwggLxAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAy
# MDEwAhMzAAABBAkBdQhYhy0pAAAAAAEEMA0GCWCGSAFlAwQCAQUAoIIBMjAaBgkq
# hkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIBYElNwZc7+t
# qfQCHFZ717ehr7BcsckGHu1hJ+rV1zSYMIHiBgsqhkiG9w0BCRACDDGB0jCBzzCB
# zDCBsQQUs0Yef0dI8yhMiFS2cxh4FtwVCn0wgZgwgYCkfjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAQQJAXUIWIctKQAAAAABBDAWBBQztikrxzti
# LYumQPi31b5M/VDG0zANBgkqhkiG9w0BAQsFAASCAQCKxTL12s46Z6/z5C13ivn3
# +ll7D78kO/RUgY35StQjv7tx5QQYJ1Atg8PS29udBJYFZespzhhEdwvo9tGNEFwU
# kcuDS0i3nVTp+7t9ftx7EMUbhlyJ3i4UOZZwBXiGGHYcdTpiVczk9RJlkIFuvtPv
# fSl2OU1Jc50yN6zcEvY+s56hNXHvzMfCZnGbGgbSWluUb2yFMIb8bUfx2qHRL4Ap
# SiC4BmOv6qgd611CyCNo+mq3zUHqSUb3WqALkdSlssHMfRUsiMfv0K18Vq+HRGJo
# XW4owlwuq5tVfN4BNfpKFFA+Uh0yabKNoppMDu6rSKEhUQCiUAecSdet6Pa5yejJ
# SIG # End signature block
