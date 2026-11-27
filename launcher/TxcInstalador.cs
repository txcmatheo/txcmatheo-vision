// Txcmatheo Vision — instalador de un solo archivo (GPL-3.0, parte de Txcmatheo Vision).
//
// El .exe es este programa con el zip "para amigos" pegado al final:
//   [instalador][zip][8 bytes: tamaño del zip][8 bytes: "TXCSFX01"]
// Al abrirlo copia lo del zip a la carpeta elegida (por defecto %LOCALAPPDATA%\Programs\Txcmatheo Vision:
// no pide administrador y así el lanzador puede actualizarse solo), crea los accesos directos y lo
// registra en "Aplicaciones instaladas". Si ya estaba instalado ahí, conserva los ajustes y perfiles
// (app\runtime_local\user-data-*, app\logs), igual que el lanzador al actualizar.
// Sin zip pegado (o con --desinstalar) es el desinstalador: se copia a la carpeta instalada como
// "Desinstalar Txcmatheo Vision.exe" y manda esa carpeta a la Papelera.
// Para pruebas: --silencioso --carpeta "<dir>" instala solo los archivos (sin accesos ni registro).
// Lo arma tools/make-friend-zip.py con el csc de .NET Framework 4 (C# 5).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("Instalador de Txcmatheo Vision")]
[assembly: AssemblyProduct("Txcmatheo Vision")]
[assembly: AssemblyDescription("Instalador de Txcmatheo Vision")]
[assembly: AssemblyCopyright("GPL-3.0. Basado en PushFPS (DosukaSOL) y Veyra (Likely7)")]
[assembly: AssemblyVersion("1.0.0.0")]

static class TxcInstalador
{
    public const string Magic = "TXCSFX01";
    public const string Prefix = "Txcmatheo Vision/";
    public const string AppName = "Txcmatheo Vision";
    public const string UninstallerName = "Desinstalar Txcmatheo Vision.exe";
    public const string RegKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\TxcmatheoVision";

    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();

    [STAThread]
    static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        try { SetProcessDPIAware(); } catch { }
        int u = Array.IndexOf(args, "--desinstalar");
        Payload p = null;
        if (u < 0)
        {
            try { p = Payload.Open(Application.ExecutablePath); }
            catch (Exception e)
            {
                Msg("El instalador está dañado (" + e.Message + ").\nVuelve a descargarlo.", MessageBoxIcon.Error);
                return 1;
            }
        }
        if (p == null)
        {
            string dir = u >= 0 && u + 1 < args.Length && !args[u + 1].StartsWith("--") ? args[u + 1]
                       : Path.GetDirectoryName(Application.ExecutablePath);
            return Uninstall(dir, Array.IndexOf(args, "--confirmado") >= 0);
        }
        using (p)
        {
            int c = Array.IndexOf(args, "--carpeta");
            if (Array.IndexOf(args, "--silencioso") >= 0 && c >= 0 && c + 1 < args.Length)
            {
                try { new Installer(p, args[c + 1]).Run(null, false); return 0; }
                catch (Exception e)
                {
                    try { File.WriteAllText(Path.Combine(Path.GetTempPath(), "txc-instalador-error.txt"), e.ToString()); } catch { }
                    return 2;
                }
            }
            Application.Run(new InstallForm(p));
        }
        return 0;
    }

    public static void Msg(string text, MessageBoxIcon icon)
    {
        MessageBox.Show(text, AppName, MessageBoxButtons.OK, icon);
    }

    public static string DefaultDir()
    {
        try
        {
            using (var k = Registry.CurrentUser.OpenSubKey(RegKey))
            {
                string d = k == null ? null : k.GetValue("InstallLocation") as string;
                if (!string.IsNullOrEmpty(d) && Directory.Exists(d)) return d;
            }
        }
        catch { }
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", AppName);
    }

    // Procesos de Txcmatheo Vision (lanzador, app, renombrador, desinstalador) que corren desde dir.
    public static List<Process> RunningIn(string dir, params string[] names)
    {
        string d = Path.GetFullPath(dir).TrimEnd('\\') + "\\";
        var found = new List<Process>();
        foreach (var n in names)
            foreach (var p in Process.GetProcessesByName(n))
            {
                try
                {
                    if (Path.GetFullPath(p.MainModule.FileName).StartsWith(d, StringComparison.OrdinalIgnoreCase)) found.Add(p);
                }
                catch { }
            }
        return found;
    }

    public static bool AppOpen(string dir) { return RunningIn(dir, AppName).Count > 0; }

    // El renombrador sigue vivo unos segundos después de cerrar la app; su exe estaría bloqueado.
    public static void StopRenamer(string dir)
    {
        foreach (var p in RunningIn(dir, "txc-renombrador")) { try { p.Kill(); p.WaitForExit(5000); } catch { } }
    }

    // ---- Accesos directos (WScript.Shell por COM) ----
    public static void MakeShortcut(string lnk, string target, string workDir)
    {
        Type t = Type.GetTypeFromProgID("WScript.Shell");
        object sh = Activator.CreateInstance(t);
        object sc = t.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, sh, new object[] { lnk });
        Type st = sc.GetType();
        st.InvokeMember("TargetPath", BindingFlags.SetProperty, null, sc, new object[] { target });
        st.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, sc, new object[] { workDir });
        st.InvokeMember("IconLocation", BindingFlags.SetProperty, null, sc, new object[] { target + ",0" });
        st.InvokeMember("Description", BindingFlags.SetProperty, null, sc, new object[] { AppName });
        st.InvokeMember("Save", BindingFlags.InvokeMethod, null, sc, null);
        Marshal.FinalReleaseComObject(sc); Marshal.FinalReleaseComObject(sh);
    }
    public static string ShortcutTarget(string lnk)
    {
        try
        {
            Type t = Type.GetTypeFromProgID("WScript.Shell");
            object sh = Activator.CreateInstance(t);
            object sc = t.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, sh, new object[] { lnk });
            string target = sc.GetType().InvokeMember("TargetPath", BindingFlags.GetProperty, null, sc, null) as string;
            Marshal.FinalReleaseComObject(sc); Marshal.FinalReleaseComObject(sh);
            return target ?? "";
        }
        catch { return ""; }
    }
    public static string DesktopLink() { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), AppName + ".lnk"); }
    public static string StartLink() { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), AppName + ".lnk"); }

    // ---- Desinstalar ----
    static int Uninstall(string dir, bool confirmed)
    {
        dir = Path.GetFullPath(dir).TrimEnd('\\');
        // Solo se borra una carpeta que de verdad es una instalación de Txcmatheo Vision.
        if (!File.Exists(Path.Combine(dir, AppName + ".exe")) || !File.Exists(Path.Combine(dir, "app", "txc-version.json"))
            || Path.GetPathRoot(dir).TrimEnd('\\') == dir)
        {
            Msg("No encuentro una instalación de Txcmatheo Vision en:\n" + dir, MessageBoxIcon.Information);
            return 1;
        }
        if (!confirmed && MessageBox.Show(
                "¿Desinstalar Txcmatheo Vision?\n\n" + dir + "\n\nLa carpeta, con tus ajustes y perfiles, irá a la Papelera.\n" +
                "Tus grabaciones y capturas no se tocan.\n",AppName, MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
            return 1;
        // Desde dentro de la carpeta no se puede borrar a sí mismo: se copia a %TEMP% y sigue desde ahí.
        string self = Path.GetFullPath(Application.ExecutablePath);
        if (self.StartsWith(dir + "\\", StringComparison.OrdinalIgnoreCase))
        {
            string tmp = Path.Combine(Path.GetTempPath(), "txc-desinstalar.exe");
            File.Copy(self, tmp, true);
            var psi = new ProcessStartInfo(tmp, "--desinstalar \"" + dir + "\" --confirmado");
            psi.UseShellExecute = false;
            Process.Start(psi);
            return 0;
        }
        for (int i = 0; i < 50 && RunningIn(dir, Path.GetFileNameWithoutExtension(UninstallerName)).Count > 0; i++) Thread.Sleep(200);
        if (AppOpen(dir)) { Msg("Txcmatheo Vision está abierto. Ciérralo y vuelve a desinstalar.", MessageBoxIcon.Information); return 1; }
        StopRenamer(dir);
        foreach (var lnk in new[] { DesktopLink(), StartLink() })
        {
            try
            {
                if (File.Exists(lnk) && ShortcutTarget(lnk).StartsWith(dir + "\\", StringComparison.OrdinalIgnoreCase)) File.Delete(lnk);
            }
            catch { }
        }
        try
        {
            string loc = null;
            using (var k = Registry.CurrentUser.OpenSubKey(RegKey)) if (k != null) loc = k.GetValue("InstallLocation") as string;
            if (loc != null && string.Equals(Path.GetFullPath(loc).TrimEnd('\\'), dir, StringComparison.OrdinalIgnoreCase))
                Registry.CurrentUser.DeleteSubKeyTree(RegKey, false);
        }
        catch { }
        try
        {
            Microsoft.VisualBasic.FileIO.FileSystem.DeleteDirectory(dir, Microsoft.VisualBasic.FileIO.UIOption.OnlyErrorDialogs,
                                                                    Microsoft.VisualBasic.FileIO.RecycleOption.SendToRecycleBin);
        }
        catch (OperationCanceledException) { return 1; }
        catch (Exception e) { Msg("No se pudo quitar la carpeta (" + e.Message + ").", MessageBoxIcon.Warning); return 1; }
        Msg("Txcmatheo Vision se desinstaló. La carpeta está en la Papelera.", MessageBoxIcon.Information);
        return 0;
    }
}

// El zip pegado al final del propio .exe.
class Payload : IDisposable
{
    public FileStream Stream; public ZipArchive Zip; public long StubLength; public string Version = "";

    // null si no lleva zip (es el desinstalador); excepción si lo lleva pero está dañado.
    public static Payload Open(string exe)
    {
        var fs = new FileStream(exe, FileMode.Open, FileAccess.Read, FileShare.Read);
        try
        {
            if (fs.Length < 16) { fs.Dispose(); return null; }
            var tail = new byte[16];
            fs.Seek(-16, SeekOrigin.End);
            int got = 0; while (got < 16) { int n = fs.Read(tail, got, 16 - got); if (n <= 0) break; got += n; }
            if (got < 16 || Encoding.ASCII.GetString(tail, 8, 8) != TxcInstalador.Magic) { fs.Dispose(); return null; }
            long len = BitConverter.ToInt64(tail, 0), start = fs.Length - 16 - len;
            if (len <= 0 || start <= 0) throw new Exception("tamaño incorrecto");
            var p = new Payload();
            p.Stream = fs; p.StubLength = start;
            p.Zip = new ZipArchive(new SubStream(fs, start, len), ZipArchiveMode.Read);
            var v = p.Zip.GetEntry(TxcInstalador.Prefix + "app/txc-version.json") ?? p.Zip.GetEntry("app/txc-version.json");
            if (v == null) throw new Exception("falta app/txc-version.json");
            using (var r = new StreamReader(v.Open()))
            {
                var d = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(r.ReadToEnd());
                object o; if (d != null && d.TryGetValue("version", out o) && o != null) p.Version = o.ToString();
            }
            return p;
        }
        catch { fs.Dispose(); throw; }
    }

    public static string Rel(ZipArchiveEntry e)
    {
        string r = e.FullName.Replace('\\', '/');
        return r.StartsWith(TxcInstalador.Prefix) ? r.Substring(TxcInstalador.Prefix.Length) : r;
    }

    // El desinstalador es este mismo programa sin el zip.
    public void WriteStub(string to)
    {
        var buf = new byte[1 << 16];
        using (var dst = File.Create(to))
        {
            Stream.Position = 0; long left = StubLength;
            while (left > 0)
            {
                int n = Stream.Read(buf, 0, (int)Math.Min(buf.Length, left));
                if (n <= 0) throw new EndOfStreamException();
                dst.Write(buf, 0, n); left -= n;
            }
        }
    }

    public void Dispose() { if (Zip != null) Zip.Dispose(); Stream.Dispose(); }
}

class SubStream : Stream
{
    Stream s; long start, len, pos;
    public SubStream(Stream s, long start, long len) { this.s = s; this.start = start; this.len = len; }
    public override bool CanRead { get { return true; } }
    public override bool CanSeek { get { return true; } }
    public override bool CanWrite { get { return false; } }
    public override long Length { get { return len; } }
    public override long Position { get { return pos; } set { pos = value; } }
    public override void Flush() { }
    public override int Read(byte[] b, int o, int c)
    {
        long left = len - pos; if (left <= 0) return 0;
        if (c > left) c = (int)left;
        s.Position = start + pos;
        int n = s.Read(b, o, c); pos += n; return n;
    }
    public override long Seek(long off, SeekOrigin o)
    {
        pos = o == SeekOrigin.Begin ? off : o == SeekOrigin.Current ? pos + off : len + off;
        return pos;
    }
    public override void SetLength(long v) { throw new NotSupportedException(); }
    public override void Write(byte[] b, int o, int c) { throw new NotSupportedException(); }
}

class Installer
{
    Payload p; string root;
    public long Total;
    List<KeyValuePair<ZipArchiveEntry, string>> files = new List<KeyValuePair<ZipArchiveEntry, string>>();

    public Installer(Payload p, string dir)
    {
        this.p = p;
        root = Path.GetFullPath(dir).TrimEnd('\\');
        string rootSlash = root + "\\";
        bool keepSettings = Directory.Exists(Path.Combine(root, "app", "runtime_local", "user-data-2.0.0"));
        foreach (var e in p.Zip.Entries)
        {
            string rel = Payload.Rel(e);
            if (rel.Length == 0 || rel.EndsWith("/")) continue;
            string full = Path.GetFullPath(Path.Combine(root, rel.Replace('/', '\\')));
            // Ningún archivo puede caer fuera de la carpeta elegida.
            if (rel.Contains(":") || rel.StartsWith("/") || !full.StartsWith(rootSlash, StringComparison.OrdinalIgnoreCase))
                throw new Exception("el paquete trae una ruta no permitida: " + rel);
            string low = rel.ToLowerInvariant();
            if (low.StartsWith("app/logs/")) continue;
            if (keepSettings && low.StartsWith("app/runtime_local/user-data")) continue;
            files.Add(new KeyValuePair<ZipArchiveEntry, string>(e, full));
            Total += e.Length;
        }
    }

    public bool Update { get { return File.Exists(Path.Combine(root, "app", "txc-version.json")); } }

    // progress(bytes copiados, total); fullSetup: accesos directos y "Aplicaciones instaladas".
    public void Run(Action<long, long> progress, bool fullSetup, bool desktopLink = false)
    {
        try
        {
            var drive = new DriveInfo(Path.GetPathRoot(root));
            if (drive.AvailableFreeSpace < Total + (200L << 20))
                throw new Exception(string.Format(CultureInfo.GetCultureInfo("es-ES"),
                    "no hay espacio: hacen falta {0:0.0} GB libres en {1}", (Total + (200L << 20)) / 1e9, drive.Name));
        }
        catch (ArgumentException) { }   // carpetas de red: sin comprobar
        TxcInstalador.StopRenamer(root);
        Directory.CreateDirectory(root);
        var buf = new byte[1 << 20]; long done = 0;
        foreach (var kv in files)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(kv.Value));
            using (var src = kv.Key.Open())
            using (var dst = new FileStream(kv.Value, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 16))
            {
                int n;
                while ((n = src.Read(buf, 0, buf.Length)) > 0) { dst.Write(buf, 0, n); done += n; if (progress != null) progress(done, Total); }
            }
            try { File.SetLastWriteTime(kv.Value, kv.Key.LastWriteTime.DateTime); } catch { }
        }
        string launcher = Path.Combine(root, TxcInstalador.AppName + ".exe");
        string unins = Path.Combine(root, TxcInstalador.UninstallerName);
        p.WriteStub(unins);
        if (!fullSetup) return;
        try { Directory.CreateDirectory(Path.GetDirectoryName(TxcInstalador.StartLink())); TxcInstalador.MakeShortcut(TxcInstalador.StartLink(), launcher, root); } catch { }
        if (desktopLink) { try { TxcInstalador.MakeShortcut(TxcInstalador.DesktopLink(), launcher, root); } catch { } }
        using (var k = Registry.CurrentUser.CreateSubKey(TxcInstalador.RegKey))
        {
            k.SetValue("DisplayName", TxcInstalador.AppName);
            k.SetValue("DisplayIcon", launcher);
            k.SetValue("InstallLocation", root);
            k.SetValue("UninstallString", "\"" + unins + "\"");
            k.SetValue("Publisher", "Txcmatheo");
            k.SetValue("EstimatedSize", (int)(Total / 1024), RegistryValueKind.DWord);
            k.SetValue("NoModify", 1, RegistryValueKind.DWord);
            k.SetValue("NoRepair", 1, RegistryValueKind.DWord);
        }
    }
}

class Bar : Control
{
    public double Value;
    public Bar() { DoubleBuffered = true; SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer, true); }
    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.Clear(Color.FromArgb(38, 38, 46));
        int w = (int)(Width * Math.Max(0, Math.Min(1, Value)));
        if (w > 0)
            using (var b = new LinearGradientBrush(new Rectangle(0, 0, Width, Height), Color.FromArgb(124, 77, 255), Color.FromArgb(224, 140, 255), 0f))
                e.Graphics.FillRectangle(b, 0, 0, w, Height);
    }
}

class InstallForm : Form
{
    static readonly Color Bg = Color.FromArgb(23, 23, 28), Card = Color.FromArgb(38, 38, 46), Fg = Color.FromArgb(246, 244, 250),
                          Dim = Color.FromArgb(160, 156, 172), Accent = Color.FromArgb(124, 77, 255);
    Payload payload;
    TextBox dir = new TextBox(); Button change = new Button(), go = new Button(), cancel = new Button();
    CheckBox desktop = new CheckBox(); Label info = new Label(), status = new Label(); Bar bar = new Bar();
    float k = 1f;
    volatile bool busy; bool finished; string installedDir;

    int S(int v) { return (int)Math.Round(v * k); }

    public InstallForm(Payload p)
    {
        payload = p;
        using (var g = CreateGraphics()) k = g.DpiX / 96f;
        Text = "Instalar Txcmatheo Vision " + p.Version;
        FormBorderStyle = FormBorderStyle.FixedDialog; MaximizeBox = false; MinimizeBox = true;
        StartPosition = FormStartPosition.CenterScreen; AutoScaleMode = AutoScaleMode.None;
        ClientSize = new Size(S(540), S(304));
        BackColor = Bg; ForeColor = Fg; Font = new Font("Segoe UI", 9f);
        try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

        var logo = new PictureBox { SizeMode = PictureBoxSizeMode.Zoom };
        logo.SetBounds(S(24), S(22), S(56), S(56));
        try { logo.Image = Image.FromStream(Assembly.GetExecutingAssembly().GetManifestResourceStream("logo.png")); } catch { }
        var title = new Label { Text = "Txcmatheo Vision", Font = new Font("Segoe UI", 16f, FontStyle.Bold), AutoSize = true };
        title.Location = new Point(S(92), S(20));
        var sub = new Label { Text = "Instalador · versión " + p.Version, ForeColor = Dim, AutoSize = true, Font = new Font("Segoe UI", 9.5f) };
        sub.Location = new Point(S(95), S(56));

        var lbl = new Label { Text = "Carpeta de instalación", AutoSize = true, ForeColor = Dim };
        lbl.Location = new Point(S(24), S(100));
        dir.SetBounds(S(24), S(122), S(400), S(26));
        dir.BackColor = Card; dir.ForeColor = Fg; dir.BorderStyle = BorderStyle.FixedSingle; dir.Font = new Font("Segoe UI", 10f);
        dir.Text = TxcInstalador.DefaultDir();
        Flat(change, "Cambiar…", Card); change.SetBounds(S(432), S(121), S(84), S(28));
        change.Click += (s, e) => PickFolder();

        desktop.Text = "Crear acceso directo en el escritorio"; desktop.Checked = true; desktop.AutoSize = true;
        desktop.Location = new Point(S(24), S(160));

        var installer = new Installer(p, dir.Text);
        info.SetBounds(S(24), S(188), S(492), S(36)); info.ForeColor = Dim; info.Font = new Font("Segoe UI", 8.5f);
        info.Text = string.Format(CultureInfo.GetCultureInfo("es-ES"),
            "Ocupa unos {0:0.0} GB y no pide permisos de administrador. Si ya lo tenías instalado ahí, " +
            "se conservan tus ajustes y perfiles. Después se actualiza solo al abrirlo.", installer.Total / 1e9);

        status.SetBounds(S(24), S(226), S(492), S(20)); status.ForeColor = Fg; status.Visible = false;
        bar.SetBounds(S(24), S(248), S(492), S(6)); bar.Visible = false;

        Flat(cancel, "Cancelar", Card); cancel.SetBounds(S(316), S(262), S(96), S(32));
        cancel.Click += (s, e) => Close();
        Flat(go, "Instalar", Accent); go.SetBounds(S(420), S(262), S(96), S(32)); go.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
        go.Click += (s, e) => { if (finished) Launch(); else Start(); };
        AcceptButton = go;

        Controls.AddRange(new Control[] { logo, title, sub, lbl, dir, change, desktop, info, status, bar, cancel, go });
        FormClosing += (s, e) => { if (busy) e.Cancel = true; };
    }

    void Flat(Button b, string text, Color back)
    {
        b.Text = text; b.FlatStyle = FlatStyle.Flat; b.BackColor = back; b.ForeColor = Fg;
        b.FlatAppearance.BorderSize = 0; b.Cursor = Cursors.Hand;
    }

    // Siempre en una subcarpeta "Txcmatheo Vision": si eligen el Escritorio no se mezcla con lo demás
    // (y el desinstalador nunca borraría el Escritorio entero).
    void PickFolder()
    {
        using (var f = new FolderBrowserDialog())
        {
            f.Description = "Elige dónde instalar Txcmatheo Vision (se crea una carpeta \"Txcmatheo Vision\" dentro).";
            f.ShowNewFolderButton = true;
            if (f.ShowDialog(this) != DialogResult.OK) return;
            string d = f.SelectedPath;
            if (!string.Equals(Path.GetFileName(d.TrimEnd('\\')), TxcInstalador.AppName, StringComparison.OrdinalIgnoreCase))
                d = Path.Combine(d, TxcInstalador.AppName);
            dir.Text = d;
        }
    }

    void Start()
    {
        string d = dir.Text.Trim();
        if (d.Length == 0 || !Path.IsPathRooted(d)) { TxcInstalador.Msg("Elige una carpeta válida.", MessageBoxIcon.Information); return; }
        d = Path.GetFullPath(d).TrimEnd('\\');
        if (!string.Equals(Path.GetFileName(d), TxcInstalador.AppName, StringComparison.OrdinalIgnoreCase)) d = Path.Combine(d, TxcInstalador.AppName);
        dir.Text = d;
        if (TxcInstalador.AppOpen(d)) { TxcInstalador.Msg("Txcmatheo Vision está abierto. Ciérralo y pulsa Instalar otra vez.", MessageBoxIcon.Information); return; }
        Installer inst;
        try { inst = new Installer(payload, d); }
        catch (Exception e) { TxcInstalador.Msg("No se puede instalar: " + e.Message, MessageBoxIcon.Error); return; }
        bool wantDesktop = desktop.Checked, update = inst.Update;
        busy = true;
        foreach (Control c in new Control[] { dir, change, desktop, go, cancel }) c.Enabled = false;
        info.Visible = false; status.Visible = bar.Visible = true;
        status.Text = update ? "Actualizando…" : "Instalando…";
        int last = -1;
        var t = new Thread(() =>
        {
            string error = null;
            try
            {
                inst.Run((done, total) =>
                {
                    int pct = total > 0 ? (int)(done * 100 / total) : 0;
                    if (pct == last) return;
                    last = pct;
                    BeginInvoke((Action)(() => { bar.Value = pct / 100.0; bar.Invalidate(); status.Text = (update ? "Actualizando… " : "Instalando… ") + pct + " %"; }));
                }, true, wantDesktop);
            }
            catch (Exception e) { error = e.Message; }
            BeginInvoke((Action)(() => Finish(d, error)));
        });
        t.SetApartmentState(ApartmentState.STA);   // accesos directos por COM
        t.IsBackground = true;
        t.Start();
    }

    void Finish(string d, string error)
    {
        busy = false;
        cancel.Enabled = true;
        if (error != null)
        {
            status.Text = "No se pudo instalar.";
            TxcInstalador.Msg("No se pudo instalar: " + error + "\n\nSi elegiste una carpeta del sistema (como Archivos de programa), " +
                              "elige otra tuya.", MessageBoxIcon.Error);
            foreach (Control c in new Control[] { dir, change, desktop, go }) c.Enabled = true;
            cancel.Text = "Cerrar";
            return;
        }
        finished = true; installedDir = d;
        bar.Value = 1; bar.Invalidate();
        status.Text = "Listo. Instalado en " + d;
        go.Text = "Abrir"; go.Enabled = true; go.Focus();
        cancel.Text = "Cerrar";
    }

    void Launch()
    {
        try
        {
            var psi = new ProcessStartInfo(Path.Combine(installedDir, TxcInstalador.AppName + ".exe"));
            psi.WorkingDirectory = installedDir; psi.UseShellExecute = false;
            Process.Start(psi);
        }
        catch (Exception e) { TxcInstalador.Msg("No se pudo abrir: " + e.Message, MessageBoxIcon.Warning); }
        Close();
    }
}
