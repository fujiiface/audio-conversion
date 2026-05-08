# Audio Conversion

PowerShell scripts that use FFMPEG to batch convert audio files to M4A and extract individual tracks from a single audio file.

## Scripts

**`convert.ps1`** — Converts a folder of MP3, FLAC, WAV, M4A, or WMA files to M4A. Automatically tags each file with artist, album, title, and track number parsed from the filename. Runs up to 5 conversions in parallel, then archives the originals into a ZIP.

**`extract-audio-section-m4a.ps1`** — Splits a single audio file into individual M4A tracks using a `setlist.txt` file that defines start/end times and track names. Archives the source file after extraction.

## Setup

### 1. Install FFMPEG

Download from [ffmpeg.org](https://ffmpeg.org/download.html), extract it, and add the `bin` folder to your system PATH:

1. Right-click **This PC** → Properties → Advanced system settings → Environment Variables
2. Under **System variables**, find `Path`, click Edit, and add your FFMPEG bin path (e.g. `C:\ffmpeg\bin`)
3. Restart PowerShell and verify with: `ffmpeg -version`

### 2. Clone the repo

```powershell
git clone https://github.com/fujiiface/audio-conversion.git
cd audio-conversion
```

### 3. Allow script execution (if needed)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Usage

### Convert a folder of audio files

```powershell
.\convert.ps1 -path "C:\Music\MyAlbum" -artist "Artist Name" -album "Album Name"
```

All three parameters are optional — the script defaults to the current directory and infers artist/album from folder names.

**Supported filename formats:**
- `Artist - Album - 01 Track Title.mp3` (Bandcamp pattern)
- `01_Track_Title.mp3` (Underscore separated)
- `01 Track Title.mp3` (Default pattern)

### Extract tracks from a single file 

Create a `setlist.txt` in your working directory:

```
00:00 03:45 01 First Track
03:45 07:20 02 Second Track
07:20 11:00 03 Third Track
```

Format: `START END TRACK# TITLE` (times in `MM:SS` or `HH:MM:SS`)

Then run:

```powershell
.\extract-audio-section-m4a.ps1 -Path "C:\Music\source.m4a"
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `ffmpeg` not recognized | Add FFMPEG's `bin` folder to PATH and restart PowerShell |
| "Execution of scripts is disabled" | Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| Conversion errors | Check that source files aren't corrupted and that you have enough disk space |
| Wrong track metadata | Ensure filenames match one of the three supported formats listed above |