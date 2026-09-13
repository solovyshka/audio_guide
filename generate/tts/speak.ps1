param(
  [Parameter(Mandatory = $true)][string]$TextFile,
  [Parameter(Mandatory = $true)][string]$Dest,
  [string]$Voice = "Microsoft Irina Desktop",
  [int]$Rate = -1
)

Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
  try {
    $synth.SelectVoice($Voice)
  } catch {
    $ru = $synth.GetInstalledVoices() |
      Where-Object { $_.VoiceInfo.Culture.Name -like "ru*" } |
      Select-Object -First 1
    if (-not $ru) {
      throw "На этой Windows нет русского голоса SAPI."
    }
    $synth.SelectVoice($ru.VoiceInfo.Name)
  }
  $synth.Rate = $Rate
  $synth.Volume = 100
  $dir = Split-Path $Dest -Parent
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  if (Test-Path $Dest) {
    Remove-Item $Dest -Force
  }
  $text = [IO.File]::ReadAllText((Resolve-Path $TextFile), [Text.UTF8Encoding]::new($false))
  $synth.SetOutputToWaveFile($Dest)
  $synth.Speak($text)
  $synth.SetOutputToNull()
} finally {
  $synth.Dispose()
}
