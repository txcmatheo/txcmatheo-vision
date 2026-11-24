// Txcmatheo Vision — firma de las publicaciones (GPL-3.0).
//
//   TxcSign keygen            crea la clave (RSA 3072) si no existe y muestra la pública (XML)
//   TxcSign pub               muestra la clave pública
//   TxcSign sign <archivo>    escribe <archivo>.sig (RSA-SHA256, base64)
//   TxcSign verify <archivo>  comprueba <archivo>.sig con la clave pública
//
// La clave privada se guarda en %APPDATA%\Txcmatheo\firma-actualizaciones.key cifrada con DPAPI
// (solo este usuario de Windows en este PC puede usarla). Nunca va al repositorio.
using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

static class TxcSign
{
    static string Dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Txcmatheo");
    static string KeyFile = Path.Combine(Dir, "firma-actualizaciones.key");
    static byte[] Entropy = Encoding.UTF8.GetBytes("txcmatheo-vision-updates");

    static RSACryptoServiceProvider Load()
    {
        var xml = Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(KeyFile), Entropy, DataProtectionScope.CurrentUser));
        var rsa = new RSACryptoServiceProvider(); rsa.FromXmlString(xml); return rsa;
    }

    static int Main(string[] a)
    {
        try
        {
            if (a.Length >= 1 && a[0] == "keygen")
            {
                if (File.Exists(KeyFile)) { Console.Error.WriteLine("la clave ya existe: " + KeyFile); Console.WriteLine(Load().ToXmlString(false)); return 0; }
                Directory.CreateDirectory(Dir);
                using (var rsa = new RSACryptoServiceProvider(3072))
                {
                    rsa.PersistKeyInCsp = false;
                    File.WriteAllBytes(KeyFile, ProtectedData.Protect(Encoding.UTF8.GetBytes(rsa.ToXmlString(true)), Entropy, DataProtectionScope.CurrentUser));
                    Console.WriteLine(rsa.ToXmlString(false));
                }
                return 0;
            }
            if (a.Length >= 1 && a[0] == "pub") { Console.WriteLine(Load().ToXmlString(false)); return 0; }
            if (a.Length >= 2 && a[0] == "sign")
            {
                using (var rsa = Load())
                {
                    var sig = rsa.SignData(File.ReadAllBytes(a[1]), CryptoConfig.MapNameToOID("SHA256"));
                    File.WriteAllText(a[1] + ".sig", Convert.ToBase64String(sig));
                }
                return 0;
            }
            if (a.Length >= 2 && a[0] == "verify")
            {
                using (var rsa = Load())
                {
                    bool ok = rsa.VerifyData(File.ReadAllBytes(a[1]), CryptoConfig.MapNameToOID("SHA256"),
                                             Convert.FromBase64String(File.ReadAllText(a[1] + ".sig").Trim()));
                    Console.WriteLine(ok ? "firma correcta" : "FIRMA INCORRECTA");
                    return ok ? 0 : 2;
                }
            }
            Console.Error.WriteLine("uso: TxcSign keygen | pub | sign <archivo> | verify <archivo>");
            return 1;
        }
        catch (Exception e) { Console.Error.WriteLine("error: " + e.Message); return 1; }
    }
}
