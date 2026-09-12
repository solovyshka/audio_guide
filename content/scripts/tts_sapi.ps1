# Oзвучка пакета гида голосом Windows (Microsoft Irina).
# Нужен только PowerShell. Для более живого голоса позже: Python + edge-tts.

param(
  [string]$GuidePath = (Join-Path $PSScriptRoot "..\guides\kolomna\guide.json")
)

Add-Type -AssemblyName System.Speech

$guidePath = (Resolve-Path $GuidePath).Path
$root = Split-Path $guidePath -Parent
$data = Get-Content -Raw -Encoding UTF8 $guidePath | ConvertFrom-Json

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SelectVoice("Microsoft Irina Desktop")
$synth.Rate = -1
$synth.Volume = 100

function Speak-ToWav([string]$text, [string]$dest) {
  $dir = Split-Path $dest -Parent
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  if (Test-Path $dest) {
    Remove-Item $dest -Force
  }
  $synth.SetOutputToWaveFile($dest)
  $synth.Speak($text)
  $synth.SetOutputToNull()
  $bytes = (Get-Item $dest).Length
  # PCM wav: 44-byte header, 16-bit mono 22050 or 44100. Duration from riff fmt.
  $fs = [IO.File]::OpenRead($dest)
  $br = New-Object IO.BinaryReader($fs)
  try {
    $null = $br.ReadBytes(24)
    $sampleRate = $br.ReadInt32()
    $byteRate = $br.ReadInt32()
    $fs.Close()
    if ($byteRate -gt 0) {
      return [int][math]::Round(($bytes - 44) / $byteRate)
    }
  } finally {
    $br.Dispose()
  }
  return 0
}

$total = 0
$introDest = Join-Path $root $data.intro.audioPath
$data.intro.durationSec = Speak-ToWav $data.intro.text $introDest
$total += $data.intro.durationSec
Write-Host ("intro`t{0}s`t{1}" -f $data.intro.durationSec, (Split-Path $introDest -Leaf))

foreach ($stop in $data.stops) {
  $dest = Join-Path $root $stop.audioPath
  $stop.durationSec = Speak-ToWav $stop.text $dest
  $total += $stop.durationSec
  Write-Host ("{0:d2}`t{1}s`t{2}" -f [int]$stop.order, $stop.durationSec, (Split-Path $dest -Leaf))
}

$synth.Dispose()
Write-Host ("total`t{0}s" -f $total)
Write-Host "Durations printed above; update durationSec in guide.json and catalog.json."
