// Txcmatheo Vision — renombrador de grabaciones y capturas (GPL-3.0).
//
// El motor (PushFPS/Veyra, compilado) nombra los archivos "PushFPS-fecha.mp4", "pushfps-fecha.png" y
// añade "_veyra" a lo exportado. Este programa invisible lo arranca la propia app (Main.qml)
// y, mientras la app esté abierta, renombra cada archivo nuevo en cuanto termina de escribirse:
//   PushFPS-... -> Txcmatheo-...   pushfps-... / veyra-... -> txcmatheo-...   ..._veyra.mp4 -> ..._mejorado.mp4
// Vigila las carpetas de grabación y de capturas (preferencias recordDir y screenshotDir, o las de
// siempre). Se cierra solo poco después de cerrar la app. Una sola copia a la vez.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading;

[assembly: System.Reflection.AssemblyTitle("Txcmatheo Vision - renombrador")]
[assembly: System.Reflection.AssemblyProduct("Txcmatheo Vision")]

static class TxcRenombrador
{
    static string AppDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
    static string Log = Path.Combine(AppDir, "logs", "txcmatheo-renombrador.log");

    static void Note(string s) { try { File.AppendAllText(Log, DateTime.Now.ToString("s") + " " + s + "\r\n"); } catch { } }

    static int Main()
    {
        bool created;
        using (var mutex = new Mutex(true, "Local\\TxcmatheoVisionRenombrador", out created))
        {
            if (!created) return 0;
            Note("inicio");
            int sinApp = 0;
            while (true)
            {
                foreach (var d in Folders()) Scan(d);
                if (AppRunning()) sinApp = 0; else if (++sinApp >= 5) break;   // ~15 s sin la app
                Thread.Sleep(3000);
            }
            foreach (var d in Folders()) Scan(d);
            Note("fin");
        }
        return 0;
    }

    static bool AppRunning()
    {
        string exe = Path.Combine(AppDir, "Txcmatheo Vision.exe");
        foreach (var p in Process.GetProcessesByName("Txcmatheo Vision"))
        {
            try { if (string.Equals(p.MainModule.FileName, exe, StringComparison.OrdinalIgnoreCase)) return true; }
            catch { return true; }
        }
        return false;
    }

    static List<string> Folders()
    {
        var list = new List<string>();
        string user = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        string prefs = Path.Combine(AppDir, "runtime_local", "user-data-2.0.0", "qml-preferences.v1.json");
        try
        {
            string t = File.ReadAllText(prefs);
            foreach (string key in new[] { "recordDir", "screenshotDir" })
            {
                var m = Regex.Match(t, "\"" + key + "\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"");
                if (m.Success) list.Add(Regex.Unescape(m.Groups[1].Value));
            }
        }
        catch { }
        foreach (string sub in new[] { @"Videos\Txcmatheo Vision", @"Pictures\Txcmatheo Vision", @"Videos\PushFPS", @"Pictures\PushFPS" })
            list.Add(Path.Combine(user, sub));
        var outList = new List<string>();
        foreach (var d in list)
            if (!string.IsNullOrEmpty(d) && Directory.Exists(d) && !outList.Exists(x => string.Equals(x, d, StringComparison.OrdinalIgnoreCase)))
                outList.Add(d);
        return outList;
    }

    static string NewName(string name)
    {
        string n = name;
        if (n.StartsWith("PushFPS-", StringComparison.Ordinal)) n = "Txcmatheo-" + n.Substring(8);
        else if (n.StartsWith("pushfps-", StringComparison.Ordinal)) n = "txcmatheo-" + n.Substring(8);
        else if (n.StartsWith("veyra-", StringComparison.Ordinal)) n = "txcmatheo-" + n.Substring(6);
        n = n.Replace("_veyra", "_mejorado");
        return n;
    }

    static void Scan(string dir)
    {
        string[] files;
        try { files = Directory.GetFiles(dir); } catch { return; }
        foreach (var f in files)
        {
            string name = Path.GetFileName(f);
            // Los temporales del motor (".partial", ".tmp") se dejan en paz: el motor los renombra él
            // mismo al terminar y, si se los movemos, deja un resto vacío.
            if (name.IndexOf(".partial", StringComparison.OrdinalIgnoreCase) >= 0 ||
                name.EndsWith(".tmp", StringComparison.OrdinalIgnoreCase)) continue;
            string nn = NewName(name);
            if (nn == name) continue;
            try
            {
                if ((DateTime.Now - File.GetLastWriteTime(f)).TotalSeconds < 4) continue;      // todavía escribiéndose
                using (File.Open(f, FileMode.Open, FileAccess.ReadWrite, FileShare.None)) { }   // nadie lo tiene abierto
                string dest = Path.Combine(dir, nn);
                for (int i = 2; File.Exists(dest); i++)
                    dest = Path.Combine(dir, Path.GetFileNameWithoutExtension(nn) + " (" + i + ")" + Path.GetExtension(nn));
                File.Move(f, dest);
                Note(name + " -> " + Path.GetFileName(dest));
            }
            catch { }
        }
    }
}
