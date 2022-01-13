# This script takes in an audio file that you want to break up into individual 
# tracks saves them as individual audio tracks based on the input track list
[System.Console]::OutputEncoding = [System.Console]::InputEncoding = [System.Text.Encoding]::UTF8

# TODO: Regex that removes random characters between "-" and ".m4a" --> (?=-).*(?=.m4a)

# Parameter(s)
$file = $args[0]

if ([string]::IsNullOrWhiteSpace($file)) {
    "File not specified...assuming single audio source file already in directory."
    $file = Get-Childitem *.m4a
}

$trackListFileName = "setlist.txt"

# Constants
$workingDirectory = Split-Path -Path ($file)
if ($workingDirectory -notmatch "\\$") {
    "The working directory is missing a trailing '\'.  Adding it automatically..."
    $workingDirectory += "\"
}

$trackList = $workingDirectory + $trackListFileName
$album = Split-Path -Path (Get-Location) -Leaf
$artist = Get-Location | Split-Path | Split-Path -Leaf

# Variables
$trackNumber = 0

foreach($line in Get-Content $trackList) {
    $trackNumber += 1

    try {
        $track = $trackNumber.ToString()
        $splitLine = $line.Split(" ")

        $msg = "Processing track #" + $track
        Write-Host $msg
        
        $startTime = $splitLine[0]
        $endTime = $splitLine[1]

        $trackName = $workingDirectory + $line.Substring($line.indexOf(($splitLine.Split(" ")[3])) - 3) + ".m4a"
        # Metadata
        $title = $line.Substring($line.indexOf(($splitLine.Split(" ")[4])))

        ffmpeg -hide_banner -i $file -ss $startTime -to $endTime -metadata title="$title" -metadata artist="$artist" -metadata album_artist="$artist" -metadata album="$album" -metadata track=$track -c copy $trackName
    }
    catch {
        $msg = "Error extracting audio from line " + $trackNumber.ToString()
        Write-Error $msg
    }
}

# Compress the source file
$rootFolder = Split-Path -Path ($file) -Leaf
$archiveFile = $rootFolder + ".zip"
Compress-Archive -Path $file -DestinationPath $archiveFile

if (Test-Path $file) {
    Remove-Item $file
}