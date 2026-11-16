# Voces de Control de misión con la síntesis de voz de Windows (System.Speech).
# Lee game/data/events/radio_lines.json y genera <id>_en.wav (voz Microsoft David)
# y <id>_es.wav (voz Microsoft Sabina, español latinoamericano) en la carpeta $out.
# Después: tools/generate_voice_radio.py -- <carpeta> les da el efecto de radio.
param([string]$out = "$env:TEMP\spatium_voice_raw")
Add-Type -AssemblyName System.Speech
New-Item -ItemType Directory -Force $out | Out-Null
$root = Split-Path -Parent $PSScriptRoot
$json = Get-Content -Raw -Encoding UTF8 (Join-Path $root "game\data\events\radio_lines.json") | ConvertFrom-Json
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
$voices = @{ "en" = "Microsoft David Desktop"; "es" = "Microsoft Sabina Desktop" }
foreach ($p in $json.lines.PSObject.Properties) {
  foreach ($lang in @("en", "es")) {
    $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $s.SelectVoice($voices[$lang])
    $s.Rate = -1
    $s.SetOutputToWaveFile("$out\$($p.Name)_$lang.wav", $fmt)
    $s.Speak($p.Value.$lang)
    $s.Dispose()
  }
}
Get-ChildItem $out | Measure-Object | ForEach-Object { "archivos: " + $_.Count }
