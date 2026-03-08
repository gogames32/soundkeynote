# ---------------------------------------------------------
# listener.ps1 – Global hook for keyboard + left/right mouse click
# ---------------------------------------------------------

# ---------------------------------------------------------
# 1️⃣  URL of the MP3 that will be played on every event
# ---------------------------------------------------------
$mp3Url = "https://github.com/gogames32/soundkeynote/raw/refs/heads/main/sound.mp3"
# <-- EDIT: put your actual raw‑github URL for sound.mp3 here

# ---------------------------------------------------------
# 2️⃣  Load the Windows Audio API (same code you used before)
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
# 4️⃣  C# low‑level hook class (keyboard + mouse)
# ---------------------------------------------------------
Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Hook {
    // Delegate signature for the hook callback
    public delegate IntPtr LowLevelProc(int nCode, IntPtr wParam, IntPtr lParam);

    // Win32 API imports
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr SetWindowsHookEx(int idHook, LowLevelProc lpfn,
                                                IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    public static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode,
                                               IntPtr wParam, IntPtr lParam);

    // Hook IDs
    public const int WH_KEYBOARD_LL = 13;
    public const int WH_MOUSE_LL    = 14;

    // Messages we care about
    public const int WM_KEYDOWN    = 0x0100;
    public const int WM_LBUTTONDOWN = 0x0201;
    public const int WM_RBUTTONDOWN = 0x0204;

    // Handles for the installed hooks
    private static IntPtr _kbdHook = IntPtr.Zero;
    private static IntPtr _mouseHook = IntPtr.Zero;

    // The callback that will be called for EVERY key or mouse click
    public static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int msg = wParam.ToInt32();
            if (msg == WM_KEYDOWN || msg == WM_LBUTTONDOWN || msg == WM_RBUTTONDOWN) {
                // 1️⃣ Force master volume to 100 %
                Audio.SetVolume(1.0f);
                // 2️⃣ Play (or restart) the MP3 from the URL
                $player.URL = $mp3Url;
                $player.controls.play();
            }
        }
        // Pass the event to the next hook in the chain
        return CallNextHookEx(_kbdHook, nCode, wParam, lParam);
    }

    // Install both hooks (keyboard + mouse)
    public static void Install() {
        LowLevelProc proc = HookCallback;
        _kbdHook   = SetWindowsHookEx(WH_KEYBOARD_LL, proc, IntPtr.Zero, 0);
        _mouseHook = SetWindowsHookEx(WH_MOUSE_LL,    proc, IntPtr.Zero, 0);
    }

    // Remove the hooks (optional – called when you stop the script)
    public static void Uninstall() {
        if (_kbdHook   != IntPtr.Zero) UnhookWindowsHookEx(_kbdHook);
        if (_mouseHook != IntPtr.Zero) UnhookWindowsHookEx(_mouseHook);
    }
}
"@

# ---------------------------------------------------------
# 5️⃣  Install the hooks and keep the process alive
# ---------------------------------------------------------
[Hook]::Install()
Write-Host "Hook installed – every key press, left‑click, or right‑click will force volume to 100 % and play the MP3."

# The script must stay alive; a simple endless sleep loop does the job.
while ($true) { Start-Sleep -Seconds 5 }

# ---------------------------------------------------------
# 6️⃣  (Optional) Clean‑up – never reached unless you break out of the loop
# ---------------------------------------------------------
[Hook]::Uninstall()
