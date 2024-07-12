[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)][string]$path,
    [Parameter(Mandatory=$false)][string]$artist,
    [Parameter(Mandatory=$false)][string]$album
)

[System.Console]::OutputEncoding = [System.Console]::InputEncoding = [System.Text.Encoding]::UTF8

# TODO: Regex that removes random characters between "-" and ".m4a" --> (?=-).*(?=.m4a)

if ([string]::IsNullOrWhiteSpace($path)) {
    "Directory path was empty...defaulting to the current directory."
    $path = $PWD.Path
}

if ($path -notmatch "\\$") {
    "Directory path '$path' is missing a trailing '\'.  Adding it automatically..."
    $path += "\"
}

if ([string]::IsNullOrWhiteSpace($artist)) {
    "Artist was not provided...defaulting to the current directory's parent folder name."
    $artist = Get-Location | Split-Path | Split-Path -Leaf
}

if ([string]::IsNullOrWhiteSpace($album)) {
    "Album was not provided...defaulting to the current directory's name."
    $album = Split-Path -Path (Get-Location) -Leaf
}

# Constants
$extension = ".mp3", ".flac", ".wav", ".m4a", ".wma"
$rootFolder = Split-Path -Path ($path) -Leaf
$archiveFile = $path + $rootFolder + ".zip"

$files = Get-ChildItem -Path $path | Where-Object {$_.extension -in $extension}

# Convert to .m4a
(Measure-Command {
try {    
    $files | ForEach-Object -Parallel {
        param($artist, $album)
        $originalFile = $_.FullName
        $newFile = $_.BaseName

        $newFile = $newFile -replace "(\D+) - "
    
        $title = $newFile.Substring($newFile.indexOf(" ") + 1)
        # "Title: " + $title

        $newFile = $newFile + ".m4a"
        
        $track = [int]$newFile.Substring(0, $newFile.indexOf(" "))
        # "Track: " + $track

        $lyrics = Write-Output (ffprobe -hide_banner -show_entries format_tags=UNSYNCEDLYRICS $originalFile)
        $lyrics = $lyrics -replace ".*UNSYNCEDLYRICS=" -replace ".*FORMAT]" -replace "`"", "'" -replace "`“", "'"
        $lyrics = $lyrics.Trim()

        # Artist and Album variables have to be passed with "using:" because they are not in the scope of the ForEach-Object block
        # Reference: https://devblogs.microsoft.com/powershell/powershell-foreach-object-parallel-feature/
        if ([string]::IsNullOrEmpty($lyrics)) {
            ffmpeg -hide_banner -i $originalFile -metadata title="$title" -metadata artist="$using:artist" -metadata album_artist="$using:artist" -metadata album="$using:album" -metadata track=$track -c:v copy -c:a alac $newFile
        }
        else {
            # Set lyrics metadata
            ffmpeg -hide_banner -i $originalFile -metadata title="$title" -metadata artist="$using:artist" -metadata album_artist="$using:artist" -metadata album="$using:album" -metadata lyrics="$lyrics" -metadata track=$track -c:v copy -c:a alac $newFile
        }
    } -ThrottleLimit 5
}
catch {
    Write-Warning "Failed to convert file '$originalFile': $_"
}}).TotalMilliseconds

# Compress the files
$status = "Compressing files..."
Write-Progress -Activity $status -Status $status -PercentComplete 0
Compress-Archive -Path $files -DestinationPath $archiveFile

if (Test-Path $files) {
    $status = "Deleting original files..."
    Write-Progress -Activity $status -Status $status -PercentComplete 0
    Remove-Item -Force $files
}