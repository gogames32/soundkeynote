# ---------------------------------------------------------
# listener.ps1 – Global keyboard + mouse hook → force volume 100% → play MP3
# ---------------------------------------------------------

# ---------------------------------------------------------
# 1️⃣  URL of the sound you want to hear on every input event
# ---------------------------------------------------------
$mp3Url = "https://github.com/gogames32/soundkeynote/raw/refs/heads/main/sound.mp3"   # <-- edit

# ---------------------------------------------------------
# 2️⃣  Load the Windows Audio API (same code you already used)
# ---------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
    int SetMasterVolumeLevelScalar(float fLevel, System.Guid pguidEventContext);
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, System.Guid pguidEventContext);
}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    int Activate(ref Guid iid, int clsCtx, int activationParams, out IAudioEndpointVolume aev);
}
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumerator {}
public class Audio {
    public static void SetVolume(float level) {
        var enumerator = new MMDeviceEnumerator() as IMMDeviceEnumerator;
        enumerator.GetDefaultAudioEndpoint(0, 1, out IMMDevice dev);
        Guid iid = typeof(IAudioEndpointVolume).GUID;
        dev.Activate(ref iid, 23, 0, out IAudioEndpointVolume epv);
        epv.SetMasterVolumeLevelScalar(level, Guid.Empty);
        epv.SetMute(false, Guid.Empty);
    }
}
"@

# ---------------------------------------------------------
# 3️⃣  Media player that streams the MP3 directly from the URL
# ---------------------------------------------------------
$player = New-Object -ComObject WMPlayer.OCX
$player.settings.volume = 100   # keep WMPlayer’s internal volume at max

# ---------------------------------------------------------
# 4️⃣  Hook helper – C# class compiled on‑the‑fly inside PowerShell
# ---------------------------------------------------------
Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
public class Hook {
    // Delegate for hook callbacks
    public delegate IntPtr LowLevelProc(int nCode, IntPtr wParam, IntPtr lParam);
    // Import needed Win32 functions
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr SetWindowsHookEx(int idHook, LowLevelProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    public static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    // Constants
    public const int WH_KEYBOARD_LL = 13;
    public const int WH_MOUSE_LL    = 14;
    public const int WM_KEYDOWN    = 0x0100;
    public const int WM_LBUTTONDOWN = 0x0201;
    public const int WM_RBUTTONDOWN = 0x0204;
    // Hook handles
    public static IntPtr kHook = IntPtr.Zero;
    public static IntPtr mHook = IntPtr.Zero;
    // Callback for both keyboard and mouse
    public static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int msg = wParam.ToInt32();
            if (msg == WM_KEYDOWN || msg == WM_LBUTTONDOWN || msg == WM_RBUTTONDOWN) {
                // Force volume to 100%
                Audio.SetVolume(1.0f);
                // Play (or restart) the MP3 from the URL
                $player.URL = $mp3Url;
                $player.controls.play();
            }
        }
        return CallNextHookEx(kHook, nCode, wParam, lParam);
    }
    // Install both hooks
    public static void Install() {
        LowLevelProc proc = HookCallback;
        kHook = SetWindowsHookEx(WH_KEYBOARD_LL, proc, IntPtr.Zero, 0);
        mHook = SetWindowsHookEx(WH_MOUSE_LL,    proc, IntPtr.Zero, 0);
    }
    // Remove hooks (cleanup)
    public static void Uninstall() {
        if (kHook != IntPtr.Zero) UnhookWindowsHookEx(kHook);
        if (mHook != IntPtr.Zero) UnhookWindowsHookEx(mHook);
    }
}
"@

# ---------------------------------------------------------
# 5️⃣  Install hooks – the script now runs forever
# ---------------------------------------------------------
[Hook]::Install()
Write-Host "Hook installed – every key press or left/right mouse click will force volume 100% and play the MP3."

# Keep the script alive until the user closes the PowerShell window (or kills the process)
while ($true) { Start-Sleep -Seconds 5 }

# ---------------------------------------------------------
# 6️⃣  Cleanup (never reached unless you stop the script manually)
# ---------------------------------------------------------
[Hook]::Uninstall()
