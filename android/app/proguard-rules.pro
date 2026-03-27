# Gson rules - κρατάμε generics και annotations
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

# Κρατάμε όλες τις κλάσεις του Gson
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * extends com.google.gson.TypeAdapter
-keep class * extends com.google.gson.TypeAdapterFactory

# Flutter Local Notifications - κρατάμε όλο το plugin
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.**$* { *; }

# Επιπλέον για Scheduled Notifications
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotification** { *; }
-keep class com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin** { *; }