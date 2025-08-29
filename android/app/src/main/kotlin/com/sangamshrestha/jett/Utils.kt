package com.sangamshrestha.jett

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns


fun getFileNameAndSizeFromUri(context: Context, uri: Uri): Pair<String?, Long?> {
    var fileName: String? = null
    var fileSize: Long? = null

    context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
        if (cursor.moveToFirst()) {
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)

            if (nameIndex != -1) {
                fileName = cursor.getString(nameIndex)
            }
            if (sizeIndex != -1) {
                fileSize = cursor.getLong(sizeIndex)
            }
        }
    }
    return Pair(fileName, fileSize)
}
