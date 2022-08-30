$registryPath = "HKCU:\Control Panel\Mouse"
$Name = "MouseSensitivity"
$value = "19"

Set-ItemProperty -Path $registryPath -Name $name -Value $value -Force | Out-Null


Add-Type @"
using System.Runtime.InteropServices;
public class PInvoke {
    [DllImport("user32.dll")] public static extern int SystemParametersInfo(int uiAction, int uiParam, int[] pvParam, int fWinIni);
    [DllImport("user32.dll")] public static extern int SystemParametersInfo(int uiAction, int uiParam, System.IntPtr pvParam, int fWinIni);
}
"@

$mouse = Get-ItemProperty 'HKCU:\Control Panel\Mouse'

# DoubleClickHeight -> SPI_SETDOUBLECLKHEIGHT
[PInvoke]::SystemParametersInfo(0x001E, $mouse.DoubleClickHeight, $null, 0)

# DoubleClickSpeed -> SPI_SETDOUBLECLICKTIME
[PInvoke]::SystemParametersInfo(0x0020, $mouse.DoubleClickSpeed, $null, 0)

# DoubleClickWidth -> SPI_SETDOUBLECLKWIDTH
[PInvoke]::SystemParametersInfo(0x001D, $mouse.DoubleClickWidth, $null, 0)

# MouseHoverHeight -> SPI_SETMOUSEHOVERHEIGHT
[PInvoke]::SystemParametersInfo(0x0065, $mouse.MouseHoverHeight, $null, 0)

# MouseHoverTime -> SPI_SETMOUSEHOVERTIME
[PInvoke]::SystemParametersInfo(0x0067, $mouse.MouseHoverTime, $null, 0)

# MouseHoverWidth -> SPI_SETMOUSEHOVERWIDTH
[PInvoke]::SystemParametersInfo(0x0063, $mouse.MouseHoverWidth, $null, 0)

# MouseSensitivity -> SPI_SETMOUSESPEED
[PInvoke]::SystemParametersInfo(0x0071, 0, [IntPtr][int]$mouse.MouseSensitivity, 0)

# MouseThreshold1, MouseThreshold2, MouseSpeed -> SPI_SETMOUSE
[PInvoke]::SystemParametersInfo(0x0004, 0, [int[]]($mouse.MouseThreshold1, $mouse.MouseThreshold2, $mouse.MouseSpeed), 0)

# MouseTrails -> SPI_SETMOUSETRAILS
[PInvoke]::SystemParametersInfo(0x005D, $mouse.MouseTrails, $null, 0)

# SnapToDefaultButton -> SPI_SETSNAPTODEFBUTTON
[PInvoke]::SystemParametersInfo(0x0060, $mouse.SnapToDefaultButton, $null, 0)

# SwapMouseButtons -> SPI_SETMOUSEBUTTONSWAP
[PInvoke]::SystemParametersInfo(0x0021, $mouse.SwapMouseButtons, $null, 2)