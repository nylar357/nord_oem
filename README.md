Tested Successfully on : Tmobile Nord N10 5g (billie) on Oxygen 11.0.1 BE2028

I discovered this debloat on xda: 
https://forum.xda-developers.com/t/found-a-chink-in-the-armor-just-enabled-oem-unlocking-after-11-update.4306687/

As you can see below, the carrier is stil locked.  

![preview](img/Screenshot_20210916-221027.jpg)

Now you'll also see that the bootloader is unlocked & the phone is rooted.


![preview](img/Screenshot_20210916-221017.jpg)


![preview](img/Screenshot_20210916-221007.jpg)

These are the packages being uninstalled, I started with the nord applications and somewhere along the way it broke the security stopping the oem unlock feature.  I haven't narrowed it down yet.  I'm fairly certain its one of the *.oem or *.oneplus packages.  Also the Shim service is associated with the Tmobile Carrier Unlock app.  I would use the list of services in this order but its totally up to you.  I can tell you however it will work.


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

Bootloader Unlock :

Request your unlock token here, there is full instructions : https://www.oneplus.com/unlock_token
This will take the whole 7 days unforunately and I tried several crypto methods but got no where.
Once you've obtained your unlock token 

```fastboot flash cust-unlock unlock_code.bin```
```fastboot flashing unlock```
