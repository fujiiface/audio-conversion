[System.Console]::OutputEncoding = [System.Console]::InputEncoding = [System.Text.Encoding]::UTF8

# Parameter(s)
$path = $args[0]

if ([string]::IsNullOrWhiteSpace($path)) {
    "Directory path was empty...defaulting to the current directory."
    $path = (Get-Location).ToString()
}

if ($path -notmatch "\\$") {
    "Directory path '$path' is missing a trailing '\'.  Adding it automatically..."
    $path += "\"
}

# Constants
$extension = ".wav"
$rootFolder = Split-Path -Path ($path) -Leaf
$archiveFiles = $path + "*" + $extension
$archiveFile = $path + $rootFolder + ".zip"

$files = Get-ChildItem -Path $path | Where-Object {$_.extension -in $extension}

$album = Split-Path -Path (Get-Location) -Leaf
$artist = Get-Location | Split-Path | Split-Path -Leaf

# Convert .wav to .m4a
$files | ForEach-Object {
    $originalFile = $_.FullName
    $newFile = $path + $_.BaseName + ".m4a"

    $_ | Where-Object { $_.Attributes -like '*Hidden*' }

    $lyrics = Write-Output (ffprobe -hide_banner -show_entries format_tags=UNSYNCEDLYRICS $originalFile)
    $lyrics = $lyrics -replace ".*UNSYNCEDLYRICS=" -replace ".*FORMAT]" -replace "`"", "'" -replace "`“", "'"
    $lyrics = $lyrics.Trim()

    $title = $_.BaseName.Substring($_.BaseName.indexOf(" ") + 1)
    $track = [int]$_.BaseName.Substring(0, $_.BaseName.indexOf(" "))

    if ([string]::IsNullOrEmpty($lyrics)) {
        ffmpeg -hide_banner -i $originalFile -metadata title="$title" -metadata artist="$artist" -metadata album_artist="$artist" -metadata album="$album" -metadata track=$track -c:v copy -c:a alac $newFile
    }
    else {
        # Set lyrics metadata
        ffmpeg -hide_banner -i $originalFile -metadata title="$title" -metadata artist="$artist" -metadata album_artist="$artist" -metadata album="$album" -metadata lyrics="$lyrics" -metadata track=$track -c:v copy -c:a alac $newFile
    }
}

# Compress the .wav files
Compress-Archive -Path $archiveFiles -DestinationPath $archiveFile

if (Test-Path $archiveFile) {
    Remove-Item $archiveFiles
}