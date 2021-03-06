# bootstrap.ps1 -- install the dwiw2015 Vim distribution

# See the Github page (https://github.com/mkropat/vim-dwiw2015) for details

# It should be safe to run -- even on an existing Vim set up.  Re-running the
# `bootstrap.ps1` script is safe — it simply resumes the installation and
# checks for updates on any plug-ins already installed.

$myvimrc_path      = Join-Path $env:UserProfile _vimrc
$myvimfiles_path   = Join-Path $env:UserProfile vimfiles
$myvimfiles_tlde   = '~/vimfiles'
$loader_file_path  = Join-Path $myvimfiles_path dwiw-loader.vim
$loader_file_tlde  = "$myvimfiles_tlde/dwiw-loader.vim"
$bundles_file_path = Join-Path $myvimfiles_path bundles.vim
$bundles_file_tlde = "$myvimfiles_tlde/bundles.vim"
$bundle_path       = Join-Path $myvimfiles_path bundle
$bundle_tlde       = "$myvimfiles_tlde/bundle"
$vundle_path       = Join-Path $bundle_path vundle
$vundle_tlde       = "$bundle_tlde/vundle"

function main {
    EnsureInstalled-Vundle

    # Create `$env:UserProfile\vim\dwiw-loader.vim` script to load Vundle and
    # then call `bundles.vim`. Do not modify the loader file.
    EnsureCreated-LoaderFile

    # Create `$env:UserProfile\vim\bundles.vim` script, which contains a list
    # of Vundle plug-ins. Feel free to make local modifications to this file.
    EnsurePopulated-BundlesFile

    # Prepand a one-line hook in `$env:UserProfile/_vimrc` to call
    # `dwiw-loader.vim`.
    EnsureAdded-VimrcHook

    InstallOrUpdate-Bundles
}

function EnsureInstalled-Vundle {
    if (Test-Path -LiteralPath (Join-Path $vundle_path '.git') -PathType Container) {
        return
    }

    if (! (Get-Command -Name git -CommandType Application -ErrorAction SilentlyContinue)) {
        throw "Unable to locate git.exe"
    }

    Write-Output "Installing Vundle into $vundle_path"

    New-Item -Path $bundle_path -Type Directory -Force | Out-Null
    Push-Location $bundle_path
    try {
        & git clone --quiet https://github.com/gmarik/vundle.git vundle
    } finally {
        Pop-Location
    }
}

$loader_version = '1.1'
$dwiw_loader_script = @"
" dwiw-loader.vim - Load Vundle and tell it about bundles
" Version: $loader_version
set nocompatible
filetype off
set rtp+=$vundle_tlde/
call vundle#rc("$bundle_tlde")
source $bundles_file_tlde
filetype plugin indent on
runtime! plugin/sensible.vim
runtime! plugin/dwiw2015.vim
"@

function EnsureCreated-LoaderFile {
    if (! (Test-Path -LiteralPath $loader_file_path)) {
        Write-Output "Creating loader script at $loader_file_path"
        $dwiw_loader_script | Out-File -Encoding ascii $loader_file_path
    } elseif ((Get-ScriptVersion $loader_file_path) -ne '1.1') {
        Write-Output "Updating loader script at $loader_file_path to version $loader_version"
        $dwiw_loader_script | Out-File -Encoding ascii $loader_file_path
    }
}

function EnsurePopulated-BundlesFile {
    try {
        $old_lines = Get-Content $bundles_file_path -ErrorAction Stop
    } catch {
        Write-Output "Creating bundles file at $bundles_file_path"
        $old_lines = @()
    }
    $bundles =
        'gmarik/vundle',
        'tpope/vim-sensible',
        'mkropat/vim-dwiw2015',
        'bling/vim-airline',
        'kien/ctrlp.vim',
        'rking/ag.vim',
        'scrooloose/nerdcommenter',
        'tpope/vim-sleuth'
    $lines_to_add = $bundles | %{ "Bundle '$_'" }
    $lines = $old_lines + $lines_to_add | Select-Object -Unique
    [System.IO.File]::WriteAllLines($bundles_file_path, $lines) # Vim chokes on BOM outputted by Out-File
}

function EnsureAdded-VimrcHook {
    try {
        $lines = Get-Content $myvimrc_path -ErrorAction Stop
    } catch {
        Write-Output "Adding hook to $myvimrc_path"
        $lines = @()
    }
    if (! ($lines | Select-String -Pattern "source $loader_file_tlde")) {
        $lines = ,"source $loader_file_tlde" + $lines
        [System.IO.File]::WriteAllLines($myvimrc_path, $lines) # Vim chokes on BOM written by Out-File
    }
}

function InstallOrUpdate-Bundles {
    Write-Output "Calling Vundle's :BundleInstall!"
    try {
        # Try to find gvim.exe in $env:Path or in App Paths
        Start-Process gvim -ArgumentList "-u,$loader_file_path,+BundleInstall!,+qall"
    } catch {
        try {
            # Failing that, try to locate it manually
            Start-Process (Get-GvimExePath) -ArgumentList "-u,$loader_file_path,+BundleInstall!,+qall"
        } catch {
            throw "Unable to locate gvim.exe"
        }
    }
}

function Get-GvimExePath {
    # Find Vim directory from the *Cream* Vim Installer's UninstallString
    $is64bit = [IntPtr]::size -eq 8
    if ($is64bit) {
        $hklmSoftwareWindows = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion'
    } else {
        $hklmSoftwareWindows = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion'
    }
    $uninstallVim = Join-Path $hklmSoftwareWindows 'Uninstall\Vim'
    $uninstallString = (Get-ItemProperty $uninstallVim UninstallString).UninstallString
    $installDir = Split-Path -Parent $uninstallString
    return Join-Path $installDir 'gvim.exe'
}

function Get-ScriptVersion($script_path) {
    return Get-Content $script_path -ErrorAction SilentlyContinue |
        Select-String '^" Version: (.*)' |
        select -First 1 -ExpandProperty Matches |
        select -ExpandProperty Groups |
        select -Index 1 |
        select -ExpandProperty Value
}

main
