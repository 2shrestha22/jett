package com.sangamshrestha.jett

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager

fun getApkPath(context: Context, packageName: String){
    context.packageManager.getApplicationInfo(packageName, 0)
}