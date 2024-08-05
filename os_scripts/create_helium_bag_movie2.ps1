# Set the path to the directory containing the images
$imagesDirectory = "B:\Jul-01-2024\pictures"

# Set the output file name (without extension)
$outputFileName = "output"

# Set the output file extension (e.g., mp4)
$outputFileExtension = "mp4"

# Set the frame rate (frames per second) for the output video
$frameRate = 60

# Set the path to ffmpeg executable
$ffmpegPath = "C:\ffmpeg\bin\ffmpeg.exe"

# Change to the directory containing the images - one above to make a good filename
Set-Location $imagesDirectory\..
$outputFileName = ((Get-Location) | Get-Item).Name
Set-Location $imagesDirectory

# Get a list of image files in the directory and sort them alphabetically
$imageFiles = Get-ChildItem -Path $imagesDirectory | Where-Object { $_.Extension -match ".jpg|.jpeg|.png|.gif" } | Sort-Object -Property Name

# Create a list of filenames with alphabetically sorted image files
$imageFilenames = $imageFiles.Name

# Generate a list file containing the filenames of the images
$listFilePath = Join-Path $imagesDirectory "image_list.txt"
$imageFilenames | ForEach-Object { "file '$_'`r`n" } | Out-File -FilePath $listFilePath -Encoding ascii -Append -NoNewline

# Construct the ffmpeg command
cd $imagesDirectory
$ffmpegCommand = "$ffmpegPath -f concat -safe 0 -i ""$listFilePath"" -c:v libx264 -framerate $frameRate  ""..\$outputFileName.$outputFileExtension"""
#$ffmpegCommand = "$ffmpegPath -f concat -safe 0 -i ""$listFilePath"" -c copy -framerate $frameRate  ""$outputFileName.$outputFileExtension"""
#$ffmpegCommand = "$ffmpegPath -y -framerate $frameRate -f concat -safe 0 -i image_list.txt -c:v libx264 -r $frameRate -pix_fmt yuv420p -s $videoResolution ""$outputFileName.$outputFileExtension"""
echo $ffmpegCommand

#ffmpeg -f concat -i image_list.txt -c copy -framerate 60 output.mkv
# Execute the ffmpeg command
Invoke-Expression -Command $ffmpegCommand

# Clean up: delete the temporary image list file
#Remove-Item $listFilePath