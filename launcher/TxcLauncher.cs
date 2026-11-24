// Txcmatheo Vision — lanzador con actualización automática (GPL-3.0, parte de Txcmatheo Vision).
//
// Estructura instalada:
//   Txcmatheo Vision\Txcmatheo Vision.exe   <- este lanzador
//   Txcmatheo Vision\app\                   <- la app (PushFPS + Veyra + diseño Txcmatheo)
//   Txcmatheo Vision\app\txc-version.json   <- {"version": "...", "base": "..."}
//
// Al abrirse: lee latest.json de la última release del repositorio; si hay versión nueva descarga el
// parche (si la base instalada coincide) o el paquete completo, comprueba su SHA-256, lo instala sin
// tocar los ajustes del usuario (app\runtime_local\user-data-*, app\logs) y abre la app. Sin internet
// o ante cualquier error, abre la app tal cual. Compilado con el csc de .NET Framework 4 (C# 5).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Security.Cryptography;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

[assembly: System.Reflection.AssemblyTitle("Txcmatheo Vision")]
[assembly: System.Reflection.AssemblyProduct("Txcmatheo Vision")]
[assembly: System.Reflection.AssemblyDescription("Txcmatheo Vision")]
[assembly: System.Reflection.AssemblyCopyright("GPL-3.0. Basado en PushFPS (DosukaSOL) y Veyra (Likely7)")]
[assembly: System.Reflection.AssemblyVersion("1.0.0.0")]

static class TxcLauncher
{
    const string ManifestUrl = "https://github.com/__OWNER__/txcmatheo-vision/releases/latest/download/latest.json";
    static string Root = Path.GetDirectoryName(Application.ExecutablePath);
    static string App = Path.Combine(Root, "app");
    static string Log = Path.Combine(Root, "actualizador.log");

    [STAThread]
    static void Main(string[] args)
    {
        try { File.WriteAllText(Log, DateTime.Now.ToString("s") + " inicio\r\n"); } catch { }
        CleanOldLauncher();
        bool skip = Array.IndexOf(args, "--sin-actualizar") >= 0 || AppRunning();
        if (!skip)
        {
            try { TryUpdate(); }
            catch (Exception e) { Note("error: " + e.Message); }
        }
        StartApp(args);
    }

    static void Note(string s) { try { File.AppendAllText(Log, DateTime.Now.ToString("s") + " " + s + "\r\n"); } catch { } }

    static bool AppRunning()
    {
        string exe = Path.GetFullPath(Path.Combine(App, "Txcmatheo Vision.exe"));
        foreach (var p in Process.GetProcessesByName("Txcmatheo Vision"))
        {
            try { if (string.Equals(Path.GetFullPath(p.MainModule.FileName), exe, StringComparison.OrdinalIgnoreCase)) return true; }
            catch { }
        }
        return false;
    }

    static void StartApp(string[] args)
    {
        string exe = Path.Combine(App, "Txcmatheo Vision.exe");
        if (!File.Exists(exe)) { MessageBox.Show("No se encontró la app en:\n" + exe, "Txcmatheo Vision"); return; }
        var psi = new ProcessStartInfo(exe);
        psi.WorkingDirectory = App;
        var pass = new List<string>();
        foreach (var a in args) if (a != "--sin-actualizar") pass.Add("\"" + a.Replace("\"", "") + "\"");
        psi.Arguments = string.Join(" ", pass.ToArray());
        psi.UseShellExecute = false;
        Process.Start(psi);
    }

    // Un lanzador nuevo llega como "Txcmatheo Vision.exe.new": el que corre se renombra a .old y el
    // nuevo ocupa su sitio; el .old se borra en el siguiente arranque.
    static void CleanOldLauncher()
    {
        try { string old = Application.ExecutablePath + ".old"; if (File.Exists(old)) File.Delete(old); } catch { }
        try
        {
            string nw = Application.ExecutablePath + ".new";
            if (File.Exists(nw))
            {
                File.Move(Application.ExecutablePath, Application.ExecutablePath + ".old");
                File.Move(nw, Application.ExecutablePath);
                Note("lanzador actualizado");
            }
        }
        catch (Exception e) { Note("no se pudo cambiar el lanzador: " + e.Message); }
    }

    static Dictionary<string, object> ReadJson(string text)
    {
        return new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(text);
    }
    static string Str(Dictionary<string, object> d, string k) { object v; return d != null && d.TryGetValue(k, out v) && v != null ? v.ToString() : ""; }
    static Dictionary<string, object> Obj(Dictionary<string, object> d, string k) { object v; return d != null && d.TryGetValue(k, out v) ? v as Dictionary<string, object> : null; }

    static void TryUpdate()
    {
        ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072; // TLS 1.2
        var local = File.Exists(Path.Combine(App, "txc-version.json"))
            ? ReadJson(File.ReadAllText(Path.Combine(App, "txc-version.json"))) : new Dictionary<string, object>();
        string text;
        // Solo para pruebas locales: TXC_MANIFEST_URL apunta a otro latest.json.
        string mu = Environment.GetEnvironmentVariable("TXC_MANIFEST_URL");
        if (string.IsNullOrEmpty(mu)) mu = ManifestUrl;
        using (var wc = new TimeoutClient(8000)) text = wc.DownloadString(mu);
        var m = ReadJson(text);
        string version = Str(m, "version");
        Note("instalada=" + Str(local, "version") + " base=" + Str(local, "base") + " ultima=" + version);
        if (version.Length == 0 || version == Str(local, "version")) return;

        var patch = Obj(m, "patch");
        var full = Obj(m, "full");
        bool usePatch = patch != null && Str(patch, "base").Length > 0 && Str(patch, "base") == Str(local, "base");
        var pkg = usePatch ? patch : full;
        if (pkg == null) return;
        long size = 0; long.TryParse(Str(pkg, "size"), out size);

        var form = new UpdateForm(version, usePatch, size);
        string zip = Path.Combine(Path.GetTempPath(), "txcmatheo-update-" + version + ".zip");
        string error = null;
        var worker = new Thread(() =>
        {
            try
            {
                Download(Str(pkg, "url"), zip, size, form);
                form.SetText("Comprobando la firma…", -1);
                if (!string.Equals(Sha256(zip), Str(pkg, "sha256"), StringComparison.OrdinalIgnoreCase))
                    throw new Exception("la firma SHA-256 no coincide; no se instala");
                form.SetText("Instalando…", -1);
                Install(zip, usePatch);
                var v = new Dictionary<string, object>();
                v["version"] = version;
                v["base"] = usePatch ? Str(local, "base") : Str(full, "base");
                File.WriteAllText(Path.Combine(App, "txc-version.json"), new JavaScriptSerializer().Serialize(v));
                Note("actualizado a " + version + (usePatch ? " (parche)" : " (completo)"));
            }
            catch (Exception e) { error = e.Message; Note("fallo: " + e.Message); }
            finally { try { File.Delete(zip); } catch { } form.Done(); }
        });
        worker.IsBackground = true;
        worker.Start();
        Application.EnableVisualStyles();
        Application.Run(form);
        if (form.Cancelled) Note("cancelado por el usuario");
        if (error != null && !form.Cancelled)
            MessageBox.Show("No se pudo actualizar (" + error + ").\nSe abre la versión que ya tienes.", "Txcmatheo Vision",
                            MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    static void Download(string url, string to, long size, UpdateForm form)
    {
        var req = (HttpWebRequest)WebRequest.Create(url);
        req.UserAgent = "TxcmatheoVision-Launcher";
        req.Timeout = 20000; req.ReadWriteTimeout = 30000;
        using (var resp = req.GetResponse())
        using (var src = resp.GetResponseStream())
        using (var dst = File.Create(to))
        {
            if (size <= 0) size = resp.ContentLength;
            var buf = new byte[1 << 16]; long got = 0; int n;
            while ((n = src.Read(buf, 0, buf.Length)) > 0)
            {
                if (form.Cancelled) throw new Exception("cancelado");
                dst.Write(buf, 0, n); got += n;
                form.SetText(string.Format("Descargando… {0:0} de {1:0} MB", got / 1048576.0, size / 1048576.0),
                             size > 0 ? (int)(got * 100 / size) : -1);
            }
        }
    }

    static string Sha256(string file)
    {
        using (var s = File.OpenRead(file)) using (var h = SHA256.Create())
            return BitConverter.ToString(h.ComputeHash(s)).Replace("-", "");
    }

    // Los archivos del paquete van en "app/..." y, si trae lanzador nuevo, "Txcmatheo Vision.exe" en la raíz.
    static bool Protected(string rel)
    {
        rel = rel.Replace('\\', '/').ToLowerInvariant();
        return rel.StartsWith("app/runtime_local/user-data") || rel.StartsWith("app/logs/");
    }
    static void Install(string zip, bool patch)
    {
        using (var z = ZipFile.OpenRead(zip))
        {
            foreach (var e in z.Entries)
            {
                string rel = e.FullName.Replace('\\', '/');
                if (rel.EndsWith("/") || rel.Contains("..")) continue;
                if (Protected(rel)) continue;
                string dest = Path.Combine(Root, rel.Replace('/', Path.DirectorySeparatorChar));
                if (string.Equals(Path.GetFullPath(dest), Path.GetFullPath(Application.ExecutablePath), StringComparison.OrdinalIgnoreCase))
                    dest = Application.ExecutablePath + ".new";
                Directory.CreateDirectory(Path.GetDirectoryName(dest));
                e.ExtractToFile(dest, true);
            }
            // Ajustes de partida solo si el amigo todavía no tiene los suyos.
            string ud = Path.Combine(App, "runtime_local", "user-data-2.0.0");
            if (!Directory.Exists(ud))
                foreach (var e in z.Entries)
                {
                    string rel = e.FullName.Replace('\\', '/');
                    if (!rel.StartsWith("app/runtime_local/user-data-2.0.0/") || rel.EndsWith("/")) continue;
                    string dest = Path.Combine(Root, rel.Replace('/', Path.DirectorySeparatorChar));
                    Directory.CreateDirectory(Path.GetDirectoryName(dest));
                    e.ExtractToFile(dest, true);
                }
        }
    }
}

class TimeoutClient : WebClient
{
    int ms; public TimeoutClient(int ms) { this.ms = ms; Headers.Add("User-Agent", "TxcmatheoVision-Launcher"); Encoding = System.Text.Encoding.UTF8; }
    protected override WebRequest GetWebRequest(Uri a) { var r = base.GetWebRequest(a); r.Timeout = ms; return r; }
}

class UpdateForm : Form
{
    Label label = new Label(); ProgressBar bar = new ProgressBar(); Button cancel = new Button();
    public volatile bool Cancelled;
    public UpdateForm(string version, bool patch, long size)
    {
        Text = "Txcmatheo Vision"; Width = 460; Height = 170; FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false; MinimizeBox = false; StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(23, 23, 28); ForeColor = Color.FromArgb(246, 244, 250);
        try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
        var title = new Label { Text = "Actualizando a la versión " + version + (patch ? "" : " (paquete completo)"),
                                Left = 16, Top = 14, Width = 420, Font = new Font("Segoe UI", 10f, FontStyle.Bold) };
        label.SetBounds(16, 42, 420, 20); label.Font = new Font("Segoe UI", 9f); label.Text = "Preparando…";
        bar.SetBounds(16, 66, 412, 16); bar.Style = ProgressBarStyle.Marquee;
        cancel.SetBounds(338, 92, 90, 28); cancel.Text = "Más tarde"; cancel.FlatStyle = FlatStyle.Flat;
        cancel.ForeColor = ForeColor; cancel.Click += (s, e) => { Cancelled = true; label.Text = "Cancelando…"; };
        Controls.Add(title); Controls.Add(label); Controls.Add(bar); Controls.Add(cancel);
    }
    public void SetText(string t, int pct)
    {
        if (!IsHandleCreated) return;
        BeginInvoke((Action)(() =>
        {
            label.Text = t;
            if (pct < 0) bar.Style = ProgressBarStyle.Marquee;
            else { bar.Style = ProgressBarStyle.Continuous; bar.Value = Math.Max(0, Math.Min(100, pct)); }
        }));
    }
    public void Done()
    {
        if (IsHandleCreated) BeginInvoke((Action)(() => Close()));
        else Load += (s, e) => Close();
    }
}
