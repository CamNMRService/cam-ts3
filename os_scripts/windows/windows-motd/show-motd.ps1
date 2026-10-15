<#
.SYNOPSIS
Displays the Message Of The Day (MOTD) from a global text file.
Converts Markdown to HTML to display in a WebBrowser control.
#>

$motdFilePath = "C:\ProgramData\WindowsMOTD\motd.md"

if (-not (Test-Path $motdFilePath)) {
    # If the file doesn't exist, we just exit silently.
    exit
}

$motdText = Get-Content -Path $motdFilePath -Raw

# -------------------------------------------------------------
# Basic Markdown to HTML Converter
# -------------------------------------------------------------
function Convert-MarkdownToHtml {
    param([string]$Markdown)
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="X-UA-Compatible" content="IE=edge" />
<style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 20px; color: #111; background-color: #fdfdfd; }
    h1, h2, h3 { color: #004b87; border-bottom: 1px solid #ccc; padding-bottom: 5px; }
    ul { margin-bottom: 15px; }
    li { margin-bottom: 5px; }
    p { margin-bottom: 10px; line-height: 1.5; }
    strong { color: #000; }
</style>
</head>
<body>
"@

    $lines = $Markdown -split "`r`n|`n"
    $inList = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        
        # Bold
        $trimmed = [regex]::Replace($trimmed, '\*\*(.*?)\*\*', '<strong>$1</strong>')
        # Italics
        $trimmed = [regex]::Replace($trimmed, '\b_(.*?)_\b', '<em>$1</em>')
        
        # Headers
        if ($trimmed -match "^(#+)\s+(.*)") {
            if ($inList) { $html += "</ul>`n"; $inList = $false }
            $level = $matches[1].Length
            $text = $matches[2]
            $html += "<h$level>$text</h$level>`n"
        }
        # Unordered Lists (bullet points)
        elseif ($trimmed -match "^[-*]\s+(.*)") {
            if (-not $inList) { $html += "<ul>`n"; $inList = $true }
            $text = $matches[1]
            $html += "<li>$text</li>`n"
        }
        # Empty lines
        elseif ([string]::IsNullOrWhiteSpace($trimmed)) {
            if ($inList) { $html += "</ul>`n"; $inList = $false }
        }
        # Paragraphs
        else {
            if ($inList) { $html += "</ul>`n"; $inList = $false }
            $html += "<p>$trimmed</p>`n"
        }
    }

    if ($inList) { $html += "</ul>`n" }

    $html += "</body></html>"
    return $html
}

$htmlContent = Convert-MarkdownToHtml -Markdown $motdText

# -------------------------------------------------------------
# Display the Form
# -------------------------------------------------------------

# Load Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Message of the Day"
$form.Size = New-Object System.Drawing.Size(650, 450)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true

# Create the WebBrowser control
$webBrowser = New-Object System.Windows.Forms.WebBrowser
$webBrowser.Dock = "Fill"
$webBrowser.DocumentText = $htmlContent
$webBrowser.IsWebBrowserContextMenuEnabled = $false
$webBrowser.WebBrowserShortcutsEnabled = $false
$webBrowser.AllowWebBrowserDrop = $false

# Create an OK button to dismiss
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$okButton.Dock = "Bottom"
$okButton.Height = 40
$okButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Add controls to the form
$form.Controls.Add($webBrowser)
$form.Controls.Add($okButton)

# Set the accept button
$form.AcceptButton = $okButton

# Show the form and wait for the user to close it
$form.ShowDialog()
