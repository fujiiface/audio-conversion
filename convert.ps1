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

$extensions = ".mp3", ".flac", ".wav", ".m4a", ".wma"
$files = Get-ChildItem -Path $path | Where-Object {$_.Extension -in $extensions}

# Collection for tracking conversion errors
$errors = [System.Collections.Concurrent.ConcurrentBag[string]]::new()

# Convert to .m4a
(Measure-Command {
try {
    $files | ForEach-Object -Parallel {
        $originalFile = $_.FullName
        $newFile = $_.BaseName

        if ($newFile -match "(.+) - (.+) - ([0-9]{1,2}) (.+)") {
            # Bandcamp format
            Write-Warning "Matched pattern: Bandcamp"
            $track = [int]$Matches[3]
            $title = $matches[4]
            if ([string]::IsNullOrWhiteSpace($title)) {
                ($using:errors).Add("Missing title: '$($_.Name)' - Bandcamp format requires title")
                return
            }
            if ($track -le 9) {
                $track = "0" + $track
            }
        }
        elseif ($newFile -match "^([0-9]{1,2})_(.+)") {
            # Underscore-separated format: ##_Song_Title
            Write-Warning "Matched pattern: Underscore-separated"
            $track = [int]$Matches[1]
            $title = $Matches[2] -replace "_", " "
            # Convert to title case (capitalize each word)
            $title = (Get-Culture).TextInfo.ToTitleCase($title.ToLower())
            if ([string]::IsNullOrWhiteSpace($title)) {
                ($using:errors).Add("Missing title: '$($_.Name)' - Underscore format requires title")
                return
            }
            if ($track -le 9) {
                $track = "0" + $track
            }
        }
        else {
            # Default pattern of "## SongTitle"
            Write-Warning "Matched pattern: Default"
            $filename = $newFile -replace "(\D+) - "

            # Check if file has proper format with track number
            $spaceIndex = $filename.indexOf(" ")
            if ($spaceIndex -le 0) {
                ($using:errors).Add("Missing track number: '$($_.Name)' - Expected format '## SongTitle'")
                return
            }

            $trackString = $filename.Substring(0, $spaceIndex)
            try {
                $track = [int]$trackString
                if ($track -le 9) {
                    $track = "0" + $track
                }   
                $title = $filename.Substring($spaceIndex + 1)
            }
            catch {
                ($using:errors).Add("Invalid track number: '$($_.Name)' - Cannot convert '$trackString' to number")
                return
            }
        }

        # Reconstruct filename with proper track number format
        $newFile = "$track $title.m4a"

        $lyrics = Write-Output (ffprobe -hide_banner -show_entries format_tags=UNSYNCEDLYRICS $originalFile)
        $lyrics = $lyrics -replace ".*UNSYNCEDLYRICS=" -replace ".*FORMAT]" -replace "`"", "'" -replace "`“", "'"
        $lyrics = $lyrics.Trim()

        # Artist and Album variables have to be passed with "using:" because they are not in the scope of the ForEach-Object block
        # Reference: https://devblogs.microsoft.com/powershell/powershell-foreach-object-parallel-feature/
        if ([string]::IsNullOrEmpty($lyrics)) {
            ffmpeg -hide_banner -i $originalFile -metadata title="$title" -metadata artist="$using:artist" -metadata album_artist="$using:artist" -metadata album="$using:album" -metadata track=$track -c:v copy -c:a alac $newFile -y
        }
        else {
            # Set lyrics metadata
            ffmpeg -hide_banner -i $originalFile -metadata title="$title" -metadata artist="$using:artist" -metadata album_artist="$using:artist" -metadata album="$using:album" -metadata lyrics="$lyrics" -metadata track=$track -c:v copy -c:a alac $newFile -y
        }
    } -ThrottleLimit 5
}
catch {
    Write-Warning "Failed to convert file '$originalFile': $_"
}}).TotalMilliseconds

# Output conversion errors summary
if ($errors.Count -gt 0) {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "CONVERSION ERRORS SUMMARY" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "  - $err" -ForegroundColor Yellow
    }
    Write-Host "========================================`n" -ForegroundColor Red
}

# Compress the files
$rootFolder = Split-Path -Path ($path) -Leaf
$archiveFile = $path + $rootFolder + ".zip"
if (-not (Test-Path $archiveFile)) {
    $status = "Compressing files..."
    Write-Progress -Activity $status -Status $status -PercentComplete 0
    Compress-Archive -Path $files -DestinationPath $archiveFile
}

if (Test-Path $files) {
    $status = "Deleting original files..."
    Write-Progress -Activity $status -Status $status -PercentComplete 0
    Remove-Item -Force $files
}