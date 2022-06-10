<#
  .Synopsis
    Start UWP App in Fullscreen mode

  .DESCRIPTION
    Stat an UWP app and sends Windows keys, left shift, return keystroke to active the Window

  .NOTES
    Name: Start-UWPAppFullScreen
    Author: R. Mens - LazyAdmin.nl
    Version: 1.1
    DateCreated: 30 may 2017
    Purpose/Change: Retype script, lost orignal code

  .LINK
    https://lazyadmin.nl

  .EXAMPLE
    Start Edge and open LayzAdmin.nl

    .\StartUWPAppFullScreen.ps1 -app msedge -value 'https://lazyadmin.nl'

  .EXAMPLE
	  Start Microsoft Video

    .\StartUWPAppFullScreen.ps1 -app microsoftvideo
#>

[CmdletBinding()]
param(
  [Parameter(
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true,
      Mandatory=$true)]
  [string]$app,

  [Parameter(
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true,
      Mandatory=$false)]
  [string]$value
)

#src : https://github.com/stefanstranger/PowerShell/blob/master/WinKeys.ps1
$source = @"
using System;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
using System.Windows.Forms;
namespace KeySends
{
    public class KeySend
    {
        [DllImport("user32.dll")]
        public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, int dwExtraInfo);
        private const int KEYEVENTF_EXTENDEDKEY = 1;
        private const int KEYEVENTF_KEYUP = 2;
        public static void KeyDown(Keys vKey)
        {
            keybd_event((byte)vKey, 0, KEYEVENTF_EXTENDEDKEY, 0);
        }
        public static void KeyUp(Keys vKey)
        {
            keybd_event((byte)vKey, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
        }
    }
}
"@
Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Windows.Forms"

#Add-Type -AssemblyName System.Windows.Forms

Function Fullscreen ()
{
    [KeySends.KeySend]::KeyDown("LWin")
    [KeySends.KeySend]::KeyDown("LShiftKey")
    [KeySends.KeySend]::KeyDown("Return")
    [KeySends.KeySend]::KeyUp("LWin")
    [KeySends.KeySend]::KeyUp("LShiftKey")
    [KeySends.KeySend]::KeyUp("Return")
}

# Start the app
Start $app -ArgumentList $value

# Wait 2 sec and send keystoke$app
Start-Sleep 2
Fullscreen