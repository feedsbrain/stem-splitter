// Thin PATH-installable launcher. Forwards straight to this project's venv
// Python + main.py, without going through cmd.exe (which mis-tokenizes URL
// arguments containing '=', '&', ',', ';' - see README/run.ps1 for details).
// Built by build.bat; the project root is read from a sibling
// stem-splitter.root.txt written at build time, so the venv is never
// bundled/copied - this exe just finds and drives the existing one.
using System;
using System.Diagnostics;
using System.IO;
using System.Text;

internal static class Launcher
{
    private static int Main(string[] args)
    {
        string exeDir = AppDomain.CurrentDomain.BaseDirectory;
        string rootFile = Path.Combine(exeDir, "stem-splitter.root.txt");

        if (!File.Exists(rootFile))
        {
            Console.Error.WriteLine("[ERROR] " + rootFile + " not found. Rebuild with build.bat from the project root.");
            return 1;
        }

        string projectRoot = File.ReadAllText(rootFile).Trim();
        string pythonExe = Path.Combine(projectRoot, @"venv\Scripts\python.exe");
        string mainPy = Path.Combine(projectRoot, "main.py");

        if (!File.Exists(pythonExe))
        {
            Console.Error.WriteLine("[ERROR] Environment not set up yet. Run: " + Path.Combine(projectRoot, "run.ps1") + " --setup");
            return 1;
        }

        var psi = new ProcessStartInfo
        {
            FileName = pythonExe,
            Arguments = BuildArgumentString(mainPy, args),
            UseShellExecute = false,
            WorkingDirectory = projectRoot,
        };

        using (Process proc = Process.Start(psi))
        {
            proc.WaitForExit();
            return proc.ExitCode;
        }
    }

    private static string BuildArgumentString(string mainPy, string[] args)
    {
        var sb = new StringBuilder();
        AppendArgument(sb, mainPy);
        foreach (string arg in args)
        {
            sb.Append(' ');
            AppendArgument(sb, arg);
        }
        return sb.ToString();
    }

    // Implements the Win32/CRT argv quoting rules (the same ones
    // CommandLineToArgvW expects), so args survive intact without relying on
    // any shell's tokenizer.
    private static void AppendArgument(StringBuilder sb, string arg)
    {
        bool needsQuotes = arg.Length == 0;
        foreach (char c in arg)
        {
            if (c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '"')
            {
                needsQuotes = true;
                break;
            }
        }

        if (!needsQuotes)
        {
            sb.Append(arg);
            return;
        }

        sb.Append('"');
        int i = 0;
        while (i < arg.Length)
        {
            int backslashes = 0;
            while (i < arg.Length && arg[i] == '\\')
            {
                backslashes++;
                i++;
            }

            if (i == arg.Length)
            {
                sb.Append('\\', backslashes * 2);
                break;
            }
            else if (arg[i] == '"')
            {
                sb.Append('\\', backslashes * 2 + 1);
                sb.Append('"');
                i++;
            }
            else
            {
                sb.Append('\\', backslashes);
                sb.Append(arg[i]);
                i++;
            }
        }
        sb.Append('"');
    }
}
