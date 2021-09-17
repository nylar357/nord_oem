Tested Successfully on : Tmobile Nord N10 5g (billie) on Oxygen 11.0.1 BE2028

I discovered this debloat on xda: 
[XDA Tweak Post "Chink in the Armor"](https://forum.xda-developers.com/t/found-a-chink-in-the-armor-just-enabled-oem-unlocking-after-11-update.4306687/)

As you can see below, the carrier is stil locked.  

![preview](img/Screenshot_20210916-221027.jpg)

Now you'll also see that the bootloader is unlocked & the phone is rooted.


![preview](img/Screenshot_20210916-221017.jpg)


![preview](img/Screenshot_20210916-221007.jpg)

These are the packages being uninstalled, I started with the nord applications and somewhere along the way it broke the security stopping the oem unlock feature.  I haven't narrowed it down yet.  I'm fairly certain its one of the *.oem or *.oneplus packages.  Also the Shim service is associated with the Tmobile Carrier Unlock app.  I would use the list of services in this order but its totally up to you.  I can tell you however it will work.

```
com.oem.oemlogkit   com.oem.rftoolkit   cn.oneplus.oemtcma    com.oem.logkitsdservice
cn.oneplus.oemtcma  com.oneplus.setupwizard   com.oneplus.factorymode
net.oneplus.odm     net.oneplus.odm.provider  cn.oneplus.nvbackup
com.oneplus.account net.oneplus.push    com.oneplus.brickmode   com.qualcomm.qti.uceShimService
com.android.ons
com.example.tmo
com.qualcomm.qti.remoteSimlockAuth
com.qualcomm.qti.uim
com.qualcomm.qti.uimGbaApp  org.ifaa.aidl.manager
com.google.android.apps.setupwizard.searchselector
com.qualcomm.qti.seccamservice
com.android.traceur
com.android.managedprovisioning
```
Bootloader Unlock :

[Request your unlock token here, there is full instructions](https://www.oneplus.com/unlock_token)
This will take the whole 7 days unforunately and I tried several crypto methods but got no where.
Once you've obtained your unlock token 

```fastboot flash cust-unlock unlock_code.bin```
```fastboot flashing unlock```

Rooting :

[Oxygen 11.0.1 Extracted Boot Image](https://forum.xda-developers.com/attachments/11-0-1-be88cb-boot-img-unpatched-zip.5400901/)

[Oxygen 11.0.1 Magisk Patched Boot Image](https://forum.xda-developers.com/attachments/11-0-1-be88cb-magisk_patched-img-zip.5401133/)

[Magisk Manager 23.0](https://github.com/topjohnwu/Magisk/releases)

Install the Magisk APK either thru a traditional install or ```adb install apk_path```
Patch the supplied boot image with magisk manager app: ```Install > Select and Patch a File```
Select the unpatched image, make note of the patched name, and move it to your adb device (laptop/desktop)
from your computer 
```fastboot flash boot patched_image_path``` 
```fastboot reboot```

Do not interfere with the booting, in other words don't pause it by accidently pressing the power button or anything.
Once your N10 has booted up, you don't have to but I reccommend jumping back into magisk and using the Direct Install method
just to be sure your root is permanant.

Voila your now bootloader unlocked & Rooted, without ever having to payoff your phone or wait for a bumbling tmobile 
employee to unlock your device.  I would shut off Auto System Updates.  I've also included a Ktweak script & magisk module.  You can use the KTweak script
by setting it up on boot with EXKernel Manager or Franco Kernel Manager, but the Magisk Module has been working just fine for me.  This will tweak your CPU,
Memory, ect for optimum battery & performance gains.  I've been running Ktweak on several phones and amoung the universal tweaks out there is is FAR superior.

[KTweak Github page](https://github.com/tytydraco/KTweak)
