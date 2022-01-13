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
$extension = ".mp3"
$rootFolder = Split-Path -Path ($path) -Leaf
$archiveFiles = $path + "*" + $extension
$archiveFile = $path + $rootFolder + ".zip"

$files = Get-ChildItem -Path $path | Where-Object {$_.extension -in $extension}

# Convert .mp3 to .m4a
$files | ForEach-Object {
    $originalFile = $_.FullName
    $newFile = $path + $_.BaseName + ".m4a"


    $lyrics = Write-Output (ffprobe -hide_banner -show_entries format_tags=UNSYNCEDLYRICS $originalFile)
    $lyrics = $lyrics -replace ".*UNSYNCEDLYRICS=" -replace ".*FORMAT]" -replace "`"", "'" -replace "`“", "'"
    $lyrics = $lyrics.Trim()
    
    if ($lyrics -notmatch "\S") {
        ffmpeg -hide_banner -i $originalFile -c:v copy -c:a alac $newFile
    }
    else {
        # Set lyrics metadata
        ffmpeg -hide_banner -i $originalFile -metadata lyrics="$lyrics" -c:v copy -c:a alac $newFile
    }
}

# Compress the .mp3 files
Compress-Archive -Path $archiveFiles -DestinationPath $archiveFile

if (Test-Path $archiveFile) {
    Remove-Item $archiveFiles
}