# ---------------------------------------------------------
# listener.ps1  –  Full key‑listener that forces volume 100%
#                and streams the MP3 from a public URL.
# ---------------------------------------------------------

# ---- 1️⃣  MP3 URL (replace with your own) ----
$mp3 = "https://github.com/gogames32/soundkeynote/raw/refs/heads/main/sound.mp3"

# ---- 2️⃣  Load Windows Audio API (same as before) ----
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {int SetMasterVolumeLevelScalar(float fLevel, System.Guid pguidEventContext);int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, System.Guid pguidEventContext);}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {int Activate(ref Guid iid, int clsCtx, int activationParams, out IAudioEndpointVolume aev);}
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumerator {}
public class Audio {public static void SetVolume(float level){var enumerator = new MMDeviceEnumerator() as IMMDeviceEnumerator;enumerator.GetDefaultAudioEndpoint(0,1,out IMMDevice dev);Guid iid=typeof(IAudioEndpointVolume).GUID;dev.Activate(ref iid,23,0,out IAudioEndpointVolume epv);epv.SetMasterVolumeLevelScalar(level,Guid.Empty);epv.SetMute(false,Guid.Empty);}}
"@

# ---- 3️⃣  Player (stream from URL) ----
$player = New-Object -ComObject WMPlayer.OCX
$player.settings.volume = 100

# ---- 4️⃣  Infinite key‑poll loop ----
while ($true) {
    $pressed = $false
    foreach ($k in [Enum]::GetValues([System.Windows.Forms.Keys])) {
        if ([System.Windows.Forms.Control]::IsKeyDown($k)) { $pressed = $true; break }
    }
    if ($pressed) {
        [Audio]::SetVolume(1.0)   # force 100 % system volume
        $player.URL = $mp3        # stream MP3 from cloud
        $player.controls.play()
    }
    Start-Sleep -Milliseconds 80

}
