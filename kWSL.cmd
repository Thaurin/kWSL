@ECHO OFF
SET GITORG=Thaurin
SET GITPRJ=kWSL
SET BRANCH=master
SET BASE=https://github.com/%GITORG%/%GITPRJ%/raw/%BRANCH%

REM ## UAC Check 
NET SESSION >NUL 2>&1
 if %errorLevel% == 0 (
      echo Administrative permissions confirmed...
  ) else (
      echo You need to run this command with administrative rights.  User Account Control enabled?
      pause
      goto ENDSCRIPT
  )

REM ## Enable WSL
POWERSHELL.EXE -command "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
CLS && SET RUNSTART=%date% @ %time%

REM ## Determine ideal DPI
IF NOT EXIST %TEMP%\dpi.ps1 POWERSHELL.EXE -ExecutionPolicy Bypass -Command "wget %BASE%/dpi.ps1 -UseBasicParsing -OutFile %TEMP%\dpi.ps1"
FOR /f "delims=" %%a in ('powershell -ExecutionPolicy bypass -command "%TEMP%\dpi.ps1" ') do set "LINDPI=%%a"

REM ## Get installation parameters
ECHO kWSL Installer
ECHO:

:DI
SET DISTRO=kWSL& SET /p DISTRO=Enter a unique name for the distro or hit Enter to use default [kWSL]: 
IF EXIST %DISTRO% GOTO DI
                 SET /p LINDPI=Set custom DPI scale or hit Enter to use Windows value [%LINDPI%]: 
SET RDPPRT=3399& SET /p RDPPRT=Port number for xRDP traffic or hit Enter to use default [3399]: 
SET SSHPRT=3322& SET /p SSHPRT=Port number for SSHd traffic or hit Enter to use default [3322]: 
SET DEFEXL=NONO& SET /p DEFEXL=[Not recommended!] Type X to eXclude %DISTRO% from Windows Defender: 

REM ## Download distro base
IF /I %CD%==C:\Windows\System32 CD %HOMEPATH%
SET DISTROFULL=%CD%\%DISTRO%
SET _rlt=%DISTROFULL:~2,2%
IF "%_rlt%"=="\\" SET DISTROFULL=%CD%%DISTRO%
SET GO=%DISTROFULL%\LxRunOffline.exe r -n %DISTRO% -c 
ECHO %DISTRO% to be installed in %DISTROFULL% && ECHO Downloading... (or using local copy if available)
IF NOT EXIST %TEMP%\Debian.zip POWERSHELL.EXE -Command "Start-BitsTransfer -source https://aka.ms/wsl-debian-gnulinux -destination %TEMP%\Debian.zip"
POWERSHELL.EXE -command "Expand-Archive -Path %TEMP%\Debian.zip -DestinationPath %TEMP% -force

REM ## Install Distro with LxRunOffline / https://github.com/DDoSolitary/LxRunOffline
IF NOT EXIST %TEMP%\LxRunOffline.exe POWERSHELL.EXE -Command "wget %BASE%/LxRunOffline.exe -UseBasicParsing -OutFile %TEMP%\LxRunOffline.exe"
%TEMP%\LxRunOffline.exe  i -n %DISTRO% -d .\%DISTRO% -f %TEMP%\install.tar.gz
%TEMP%\LxRunOffline.exe sd -n %DISTRO%
COPY %TEMP%\LxRunOffline.* %DISTROFULL% > NUL

REM ## Add exclusions in Windows Defender if requested
IF NOT EXIST %TEMP%\excludeWSL.ps1 POWERSHELL.EXE -Command "wget %BASE%/excludeWSL.ps1 -UseBasicParsing -OutFile %TEMP%\excludeWSL.ps1"
IF %DEFEXL%==X POWERSHELL.EXE -ExecutionPolicy bypass -command "%TEMP%\excludeWSL.ps1 '%DISTROFULL%'"

REM ## Configure
CD %DISTROFULL%
%GO% "cd /tmp ; wget -q http://deb.devuan.org/devuan/pool/main/d/devuan-keyring/devuan-keyring_2017.10.03_all.deb ; wget -q http://ftp.us.debian.org/debian/pool/main/c/ca-certificates/ca-certificates_20200601~deb9u1_all.deb ; wget -q http://ftp.us.debian.org/debian/pool/main/o/openssl/openssl_1.1.0l-1~deb9u1_amd64.deb ; wget -q http://ftp.us.debian.org/debian/pool/main/o/openssl/libssl1.1_1.1.0l-1~deb9u1_amd64.deb"
%GO% "cd /tmp ; dpkg -i --force-all ./devuan-keyring_2017.10.03_all.deb ./ca-certificates_20200601~deb9u1_all.deb ./openssl_1.1.0l-1~deb9u1_amd64.deb ./libssl1.1_1.1.0l-1~deb9u1_amd64.deb" > NUL
%GO% "echo deb     http://deb.devuan.org/merged chimaera main >  /etc/apt/sources.list" 
%GO% "echo deb-src http://deb.devuan.org/merged chimaera main >> /etc/apt/sources.list"
%GO% "cd /tmp ; apt-get update ; touch /etc/mtab ; wget -q %BASE%/deb/libc6_2.30-8_amd64.deb ; wget -q %BASE%/deb/libc-bin_2.30-8_amd64.deb ; wget -q %BASE%/deb/libc6-dev_2.30-8_amd64.deb ; wget -q %BASE%/deb/libc-dev-bin_2.30-8_amd64.deb ; apt-get -qq install ./libc6_2.30-8_amd64.deb ./libc-bin_2.30-8_amd64.deb ./libc-dev-bin_2.30-8_amd64.deb ./libc6-dev_2.30-8_amd64.deb  ; apt-mark hold libc6"
%GO% "cd /tmp ; apt-get -y install base-files dirmngr git ssh --no-install-recommends ; wget -q %BASE%/deb/locales_2.30-8_all.deb ; apt-get -y install ./locales_2.30-8_all.deb"
%GO% "DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade --no-install-recommends"
%GO% "update-locale LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LANG=en_US.UTF-8 ; dpkg-reconfigure --frontend noninteractive locales"

REM ## Download kWSL overlay
%GO% "cd /tmp ; git clone -b %BRANCH% --depth=1 https://github.com/%GITORG%/%GITPRJ%.git"
%GO% "mkdir -p /root/.local/share ; apt-get -y remove rsyslog ; apt-get update"

REM ## Install local packages
%GO% "DEBIAN_FRONTEND=noninteractive apt-get -y install /tmp/kWSL/deb/fonts-cascadia-code_2005.15-1_all.deb /tmp/kWSL/deb/gksu_2.1.0_amd64.deb /tmp/kWSL/deb/libgksu2-0_2.1.0_amd64.deb /tmp/kWSL/deb/libgnome-keyring0_3.12.0-1+b2_amd64.deb /tmp/kWSL/deb/libgnome-keyring-common_3.12.0-1_all.deb /tmp/kWSL/deb/multiarch-support_2.27-3ubuntu1_amd64.deb /tmp/kWSL/deb/xrdp_0.9.13.1-2_amd64.deb /tmp/kWSL/deb/xorgxrdp_0.2.12-1_amd64.deb /tmp/kWSL/deb/plata-theme_0.9.8-0ubuntu1~focal1_all.deb /tmp/kWSL/deb/libjpeg8_8d-1.deb /tmp/kWSL/deb/libfdk-aac1_0.1.6-1_amd64.deb --no-install-recommends ; adduser xrdp ssl-cert"

REM ## Install dependencies for desktop environments
%GO% "DEBIAN_FRONTEND=noninteractive apt-get -y install x11-apps x11-session-utils x11-xserver-utils pulseaudio pulseaudio-utils dialog distro-info-data lsb-release dumb-init inetutils-syslogd xdg-utils avahi-daemon libnss-mdns binutils putty synaptic pulseaudio-utils mesa-utils bzip2 p7zip-full unar unzip zip libatkmm-1.6-1v5 libcairomm-1.0-1v5 libcanberra-gtk3-0 libcanberra-gtk3-module libglibmm-2.4-1v5 libgtkmm-3.0-1v5 libpangomm-1.4-1v5 libsigc++-2.0-0v5 dbus-x11 libdbus-glib-1-2 libqt5core5a hardinfo distro-info-data --no-install-recommends"

REM ## Install XFCE4
REM ## %GO% "DEBIAN_FRONTEND=noninteractive apt-get -y install /tmp/kWSL/deb/papirus-icon-theme_20200901-4672+pkg21~ubuntu20.04.1_all.deb xfce4-terminal xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin pavucontrol xfwm4 xfce4-panel xfce4-session xfce4-settings thunar thunar-volman thunar-archive-plugin xfdesktop4 xfce4-screenshooter libsmbclient gigolo gvfs-fuse gvfs-backends gvfs-bin mousepad evince xarchiver lhasa lrzip lzip lzop ncompress zip unzip dmz-cursor-theme adapta-gtk-theme gconf-defaults-service xfce4-taskmanager -- no-install-recommends" 

REM ## Install KDE and Patch out shm 
%GO% "DEBIAN_FRONTEND=noninteractive apt-get -y install xdg-utils kde-plasma-desktop kinfocenter kwin-x11 avahi-daemon libnss-mdns binutils systemsettings putty mousepad kde-config-gtk-style-preview breeze-gtk-theme kmix mesa-utils ntp ksysguard ksysguard-data kmenuedit kde-config-gtk-style ark bzip2 p7zip-full unar unzip zip flameshot kolourpaint --no-install-recommends"
%GO% "dpkg -i --force-all /tmp/kWSL/deb/libkf5activitiesstats1_5.70.0-1_amd64.deb /tmp/kWSL/deb/kactivitymanagerd_5.17.5-2_amd64.deb /tmp/kWSL/deb/libkscreenlocker5_5.17.5-9wsl_amd64.deb /tmp/kWSL/deb/kde-config-screenlocker_5.17.5-9wsl_amd64.deb ; apt-mark hold kactivitymanagerd libkf5activitiesstats1 libkscreenlocker5 kde-config-screenlocker"

REM ## Install Seamonkey Browser
%GO% "echo deb http://downloads.sourceforge.net/project/ubuntuzilla/mozilla/apt all main >> /etc/apt/sources.list"
%GO% "apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 2667CA5C ; apt-get update ; apt-get -y install seamonkey-mozilla-build"
%GO% "update-alternatives --install /usr/bin/www-browser www-browser /usr/bin/seamonkey 100 ; update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/seamonkey 100 ; update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/seamonkey 100"

REM ## Install Media Player
%GO% "DEBIAN_FRONTEND=noninteractive apt-get -y install parole"

REM ## Additional items to install can go here...
REM ## %GO% "cd /tmp ; wget https://files.multimc.org/downloads/multimc_1.4-1.deb"
REM ## %GO% "apt-get -y install extremetuxracer tilix /tmp/multimc_1.4-1.deb"

REM ## Remove un-needed packages
%GO% "apt-get -qq purge cryptsetup cryptsetup-bin cryptsetup-initramfs cryptsetup-run irqbalance multipath-tools apparmor snapd squashfs-tools plymouth  open-vm-tools cloud-init isc-dhcp-* gnustep* lvm2* mdadm apport open-iscsi powermgmt-base popularity-contest fwupd libfwupd2 ; apt-get -qq autoremove ; apt-get -qq clean" > NUL

REM ## Customize
SET /A SESMAN = %RDPPRT% - 50
IF %LINDPI% GEQ 288 ( %GO% "sed -i 's/HISCALE/3/g' /tmp/kWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" )
IF %LINDPI% GEQ 192 ( %GO% "sed -i 's/HISCALE/2/g' /tmp/kWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" )
IF %LINDPI% GEQ 192 ( %GO% "sed -i 's/Default-hdpi/Default-xhdpi/g' /tmp/kWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" )
IF %LINDPI% GEQ 192 ( %GO% "sed -i 's/Segoe UI Semi-Bold 11/Segoe UI Semi-Bold 22/g' /tmp/kWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" )
IF %LINDPI% GEQ 192 ( %GO% "sed -i 's/QQQ/96/g' /tmp/kWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" )
IF %LINDPI% LSS 192 ( %GO% "sed -i 's/QQQ/%LINDPI%/g' /tmp/kWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" )
IF %LINDPI% LSS 192 ( %GO% "sed -i 's/HISCALE/1/g' /tmp/kWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" )
IF %LINDPI% LSS 120 ( %GO% "sed -i 's/Default-hdpi/Default/g' /tmp/kWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" )
%GO% "sed -i 's/forceFontDPI=0/forceFontDPI=%LINDPI%/g' /tmp/kWSL/dist/etc/skel/.config/kcmfonts"
%GO% "sed -i 's/ListenPort=3350/ListenPort=%SESMAN%/g' /etc/xrdp/sesman.ini"
%GO% "sed -i 's/thinclient_drives/.kWSL/g' /etc/xrdp/sesman.ini"
%GO% "sed -i 's/port=3389/port=%RDPPRT%/g' /tmp/kWSL/dist/etc/xrdp/xrdp.ini ; cp /tmp/kWSL/dist/etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini"
%GO% "sed -i 's/#Port 22/Port %SSHPRT%/g' /etc/ssh/sshd_config"
%GO% "sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config"
%GO% "sed -i 's/kWSLINSTANCENAME/%DISTRO%/g' /tmp/kWSL/dist/usr/local/bin/initWSL"
%GO% "sed -i 's/#enable-dbus=yes/enable-dbus=no/g' /etc/avahi/avahi-daemon.conf ; sed -i 's/#host-name=foo/host-name=%COMPUTERNAME%-%DISTRO%/g' /etc/avahi/avahi-daemon.conf"
%GO% "cp /mnt/c/Windows/Fonts/*.ttf /usr/share/fonts/truetype ; rm -rf /usr/share/icons/breeze_cursors ; rm -rf /usr/share/icons/Breeze_Snow/cursors"
%GO% "mv /usr/bin/pkexec /usr/bin/pkexec.orig ; echo gksudo -k -S -g \$1 > /usr/bin/pkexec ; chmod 755 /usr/bin/pkexec"
%GO% "chmod 644 /tmp/kWSL/dist/var/lib/xrdp-pulseaudio-installer/*.so ; chmod 644 /tmp/kWSL/dist/etc/wsl.conf ; chmod 700 /tmp/kWSL/dist/usr/local/bin/initWSL ; chmod 7700 /tmp/kWSL/dist/etc/skel/.config ; chmod 7700 /tmp/kWSL/dist/etc/skel/.local ; chmod 700 /tmp/kWSL/dist/etc/skel/.gconf ; chmod 700 /tmp/kWSL/dist/etc/skel/.mozilla ; chmod 644 /tmp/kWSL/dist/etc/profile.d/WinNT.sh ; chmod 644 /tmp/kWSL/dist/etc/xrdp/xrdp.ini ; chmod 755 /tmp/kWSL/dist/etc/xrdp/startwm.sh"
%GO% "cp -rp /tmp/kWSL/dist/* /"
%GO% "ssh-keygen -A ; strip --remove-section=.note.ABI-tag /usr/lib/x86_64-linux-gnu/libQt5Core.so.5"

REM ## Setup user access 
SET RUNEND=%date% @ %time%
CD %DISTROFULL% 
ECHO:
ECHO:
SET /p XU=Enter name of %DISTRO% user: 
BASH -c "useradd -m -p nulltemp -s /bin/bash %XU%"
POWERSHELL -Command $prd = read-host "Enter password" -AsSecureString ; $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($prd) ; [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) > .tmp & set /p PWO=<.tmp
BASH -c "echo %XU%:%PWO% | chpasswd"
%GO% "sed -i 's/PLACEHOLDER/%XU%/g' /tmp/kWSL/kWSL.rdp"
%GO% "sed -i 's/COMPY/%COMPUTERNAME%/g' /tmp/kWSL/kWSL.rdp"
%GO% "sed -i 's/RDPPRT/%RDPPRT%/g' /tmp/kWSL/kWSL.rdp"
%GO% "cp /tmp/kWSL/kWSL.rdp ./kWSL._"
ECHO $prd = Get-Content .tmp > .tmp.ps1
ECHO ($prd ^| ConvertTo-SecureString -AsPlainText -Force) ^| ConvertFrom-SecureString ^| Out-File .tmp  >> .tmp.ps1
POWERSHELL -ExecutionPolicy Bypass -Command .tmp.ps1 
TYPE .tmp>.tmpsec.txt
COPY /y /b %DISTROFULL%\kWSL._+.tmpsec.txt "%DISTROFULL%\%DISTRO% (%XU%) Desktop.rdp" > NUL
DEL /Q  kWSL._ .tmp*.* > NUL
BASH -c "echo '%XU% ALL=(ALL:ALL) ALL' >> /etc/sudoers"

REM ## Open Firewall Ports
NETSH AdvFirewall Firewall add rule name="%DISTRO% xRDP" dir=in action=allow protocol=TCP localport=%RDPPRT% > NUL
NETSH AdvFirewall Firewall add rule name="%DISTRO% Secure Shell" dir=in action=allow protocol=TCP localport=%SSHPRT% > NUL
NETSH AdvFirewall Firewall add rule name="%DISTRO% Avahi Multicast DNS" dir=in action=allow program="%DISTROFULL%\rootfs\usr\sbin\avahi-daemon" enable=yes > NUL

REM ## Build RDP, Console, Init Links, Scheduled Task...
ECHO @WSLCONFIG /t %DISTRO% > "%DISTROFULL%\Init.cmd"
ECHO @WSL ~ -u root -d %DISTRO% -e initWSL 2 >> "%DISTROFULL%\Init.cmd"
ECHO @WSL ~ -u %XU% -d %DISTRO% >  "%DISTROFULL%\%DISTRO% (%XU%) Console.cmd"
COPY /Y "%DISTROFULL%\%DISTRO% (%XU%) Console.cmd" "%USERPROFILE%\Desktop\%DISTRO% (%XU%) Console.cmd" > NUL
COPY /Y "%DISTROFULL%\%DISTRO% (%XU%) Desktop.rdp" "%USERPROFILE%\Desktop\%DISTRO% (%XU%) Desktop.rdp" > NUL
START /MIN "%DISTRO% Init" WSL ~ -u root -d %DISTRO% -e initWSL 2
POWERSHELL -C "$WAI = (whoami) ; (Get-Content .\rootfs\tmp\kWSL\kWSL.xml).replace('AAAA', $WAI) | Set-Content .\rootfs\tmp\kWSL\kWSL.xml"
POWERSHELL -C "$WAC = (pwd)    ; (Get-Content .\rootfs\tmp\kWSL\kWSL.xml).replace('QQQQ', $WAC) | Set-Content .\rootfs\tmp\kWSL\kWSL.xml"
SCHTASKS /Create /TN:%distro% /XML .\rootfs\tmp\kWSL\kWSL.xml /F
ECHO:
ECHO:      Start: %RUNSTART%
ECHO:        End: %RUNEND%
%GO%  "echo -ne '   Packages:'\   ; dpkg-query -l | grep "^ii" | wc -l "
ECHO: 
ECHO:  - xRDP Server listening on port %RDPPRT% and SSHd on port %SSHPRT%.
ECHO: 
ECHO:  - Links for GUI and Console sessions have been placed on your desktop.
ECHO: 
ECHO:  - (Re)launch init from the Task Scheduler or by running the following command: 
ECHO:    schtasks /run /tn %DISTRO%
ECHO: 
ECHO: %DISTRO% Installation Complete!  GUI will start in a few seconds...  
PING -n 6 LOCALHOST > NUL 
START "Remote Desktop Connection" "MSTSC.EXE" "/V" "%DISTROFULL%\%DISTRO% (%XU%) Desktop.rdp"
ECHO: 
:ENDSCRIPT
